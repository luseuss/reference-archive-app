// 유튜브에서 제목과 썸네일을 가져오는 부분을 확인하는 테스트입니다.
//
// 진짜 유튜브를 부르지 않습니다. http.Client 자리에 "정해둔 답을 주는 가짜"를
// 넣어서, 유튜브가 404를 줄 때·한글 제목을 줄 때·아예 응답이 없을 때를
// 마음대로 만들어 시험합니다.
//
// 여기서 가장 중요하게 보는 것: **가져오기가 실패해도 저장은 되어야 한다**는 점입니다.
// 인터넷이 끊겨 있다고 영상을 못 넣게 하면 안 됩니다.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reference_archive_app/services/youtube_info_source.dart';

void main() {
  const String videoId = 'dQw4w9WgXcQ';

  /// 썸네일인 척하는 가짜 그림 데이터입니다. 내용은 상관없습니다.
  final List<int> fakeImageBytes = <int>[1, 2, 3, 4, 5];

  /// oEmbed가 주는 것과 같은 모양의 JSON 응답을 만듭니다.
  ///
  /// ── `http.Response('글자', 200)`을 쓰지 않는 이유 ──
  /// 그렇게 만들면 **글자를 latin-1로 바꿔서** 담습니다(HTTP 규격의 기본값).
  /// 한글이 들어가면 그 시점에 이미 깨져서, 앱 코드가 아무리 제대로 읽어도
  /// 소용이 없습니다. 진짜 유튜브는 UTF-8로 주므로 여기서도 그렇게 만듭니다.
  ///
  /// 실제로 이걸 안 지켜서 테스트 하나가 엉뚱하게 실패했었습니다.
  http.Response jsonResponse(Map<String, Object> body) {
    return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
  }

  /// 주소에 따라 정해둔 답을 주는 가짜 서버를 만듭니다.
  ///
  /// [onRequest]가 그 주소에 대한 답을 정합니다.
  NetworkYoutubeInfoSource sourceThatAnswers(
    http.Response Function(http.Request request) onRequest,
  ) {
    return NetworkYoutubeInfoSource(
      client: MockClient((http.Request request) async => onRequest(request)),
    );
  }

  group('제목 가져오기', () {
    test('oEmbed가 주는 제목을 읽는다', () async {
      final NetworkYoutubeInfoSource source = sourceThatAnswers((
        http.Request request,
      ) {
        if (request.url.host == 'www.youtube.com') {
          return jsonResponse(<String, Object>{'title': 'Never Gonna Give You Up'});
        }
        return http.Response.bytes(fakeImageBytes, 200);
      });

      final YoutubeVideoInfo info = await source.fetch(videoId);

      expect(info.title, 'Never Gonna Give You Up');
      expect(info.videoId, videoId);
    });

    test('한글 제목이 안 깨진다', () async {
      // 유튜브가 인코딩을 안 알려주면 latin-1로 읽혀서 한글이 깨집니다.
      // 그래서 코드에서 UTF-8로 직접 읽고 있는데, 그게 지켜지는지 봅니다.
      const String koreanTitle = '노을 지는 바닷가 영상';

      final NetworkYoutubeInfoSource source = sourceThatAnswers((
        http.Request request,
      ) {
        if (request.url.host == 'www.youtube.com') {
          // bodyBytes로 직접 UTF-8 바이트를 줍니다. 인코딩 정보는 안 줍니다.
          return http.Response.bytes(
            utf8.encode(jsonEncode(<String, Object>{'title': koreanTitle})),
            200,
          );
        }
        return http.Response.bytes(fakeImageBytes, 200);
      });

      final YoutubeVideoInfo info = await source.fetch(videoId);

      expect(info.title, koreanTitle);
    });

    test('비공개·삭제된 영상이어도 저장은 되게 빈 제목으로 넘어간다', () async {
      final NetworkYoutubeInfoSource source = sourceThatAnswers((
        http.Request request,
      ) {
        if (request.url.host == 'www.youtube.com') {
          return http.Response('Unauthorized', 401);
        }
        return http.Response.bytes(fakeImageBytes, 200);
      });

      final YoutubeVideoInfo info = await source.fetch(videoId);

      expect(info.title, '');
      // 제목이 없어도 영상 번호와 썸네일은 살아 있어야 합니다.
      expect(info.videoId, videoId);
      expect(info.thumbnailBytes, isNotNull);
    });

    test('답이 JSON이 아니어도 죽지 않는다', () async {
      final NetworkYoutubeInfoSource source = sourceThatAnswers((
        http.Request request,
      ) {
        if (request.url.host == 'www.youtube.com') {
          return http.Response('<html>오류 페이지</html>', 200);
        }
        return http.Response.bytes(fakeImageBytes, 200);
      });

      final YoutubeVideoInfo info = await source.fetch(videoId);

      expect(info.title, '');
    });

    test('인터넷이 없어도 죽지 않는다', () async {
      final NetworkYoutubeInfoSource source = NetworkYoutubeInfoSource(
        client: MockClient((http.Request request) async {
          throw const SocketExceptionLike();
        }),
      );

      final YoutubeVideoInfo info = await source.fetch(videoId);

      // 아무것도 못 가져왔지만 영상 번호는 그대로입니다. 저장할 수 있습니다.
      expect(info.videoId, videoId);
      expect(info.title, '');
      expect(info.thumbnailBytes, isNull);
    });
  });

  group('썸네일 가져오기', () {
    test('큰 썸네일이 있으면 그걸 쓴다', () async {
      String? requestedPath;

      final NetworkYoutubeInfoSource source = sourceThatAnswers((
        http.Request request,
      ) {
        if (request.url.host == 'img.youtube.com') {
          requestedPath = request.url.path;
          return http.Response.bytes(fakeImageBytes, 200);
        }
        return jsonResponse(<String, Object>{'title': 'T'});
      });

      final YoutubeVideoInfo info = await source.fetch(videoId);

      expect(info.thumbnailBytes, isNotNull);
      expect(requestedPath, contains('maxresdefault'));
    });

    test('큰 썸네일이 없으면 기본 크기로 다시 시도한다', () async {
      // maxresdefault는 모든 영상에 있지는 않습니다. 오래된 영상은 404입니다.
      // 여기서 포기하면 멀쩡한 영상이 썸네일 없이 들어갑니다.
      final List<String> requestedPaths = <String>[];

      final NetworkYoutubeInfoSource source = sourceThatAnswers((
        http.Request request,
      ) {
        if (request.url.host == 'img.youtube.com') {
          requestedPaths.add(request.url.path);

          if (request.url.path.contains('maxresdefault')) {
            return http.Response('Not Found', 404);
          }
          return http.Response.bytes(fakeImageBytes, 200);
        }
        return jsonResponse(<String, Object>{'title': 'T'});
      });

      final YoutubeVideoInfo info = await source.fetch(videoId);

      expect(info.thumbnailBytes, isNotNull);
      expect(requestedPaths.length, 2);
      expect(requestedPaths.first, contains('maxresdefault'));
      expect(requestedPaths.last, contains('hqdefault'));
    });

    test('둘 다 없으면 null이지만 제목은 살아 있다', () async {
      final NetworkYoutubeInfoSource source = sourceThatAnswers((
        http.Request request,
      ) {
        if (request.url.host == 'img.youtube.com') {
          return http.Response('Not Found', 404);
        }
        return jsonResponse(<String, Object>{'title': '제목은 있음'});
      });

      final YoutubeVideoInfo info = await source.fetch(videoId);

      expect(info.thumbnailBytes, isNull);
      expect(info.title, '제목은 있음');
    });

    test('빈 응답은 썸네일로 치지 않는다', () async {
      // 빈 데이터를 그대로 넘기면 저장 단계에서 "그림이 아니다"로 실패하는데,
      // 그때는 원인이 어디였는지 알기 어렵습니다. 여기서 걸러둡니다.
      final NetworkYoutubeInfoSource source = sourceThatAnswers((
        http.Request request,
      ) {
        if (request.url.host == 'img.youtube.com') {
          return http.Response.bytes(<int>[], 200);
        }
        return jsonResponse(<String, Object>{'title': 'T'});
      });

      final YoutubeVideoInfo info = await source.fetch(videoId);

      expect(info.thumbnailBytes, isNull);
    });
  });
}

/// 인터넷이 끊긴 상황을 흉내내는 오류입니다.
///
/// 진짜 SocketException을 쓰려면 dart:io를 들여와야 하는데, 테스트에서
/// 필요한 것은 "뭔가 예외가 난다"는 사실뿐이라 간단한 것으로 대신합니다.
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}
