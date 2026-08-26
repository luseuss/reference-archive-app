// 유튜브에서 영상의 제목과 썸네일을 가져오는 파일입니다.
//
// ── API 키가 왜 필요 없는가 ──
// 유튜브 영상 정보를 가져오는 흔한 방법은 YouTube Data API인데, 구글 계정을 만들고
// API 키를 발급받아 앱에 넣어야 합니다. 키를 앱에 넣으면 누구나 꺼내 쓸 수 있고,
// 하루 사용량 제한도 걸립니다. 의뢰인이 관리해야 할 것이 하나 더 늘어납니다.
//
// 대신 **oEmbed**를 씁니다. 유튜브가 "이 영상 제목이 뭔지" 정도는 키 없이 알려주는
// 공개 창구입니다. 제목과 채널 이름만 필요한 우리에게는 이걸로 충분합니다.
//
//   https://www.youtube.com/oembed?url=<영상 주소>&format=json
//
// 썸네일은 아예 창구가 필요 없습니다. img.youtube.com에 영상 번호만 넣으면
// 그림이 그대로 나옵니다.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'youtube_url.dart';

/// 유튜브에서 가져오기를 포기하는 시간입니다.
///
/// 응답이 없는데 무한정 기다리면 사용자는 앱이 멈춘 줄 압니다.
/// 제목을 못 가져와도 영상 저장 자체는 되어야 하므로 짧게 잡습니다.
const Duration youtubeFetchTimeout = Duration(seconds: 10);

/// 유튜브 영상 하나에 대해 알아낸 것들입니다.
///
/// **하나도 못 알아내도 실패가 아닙니다.** 인터넷이 없거나 유튜브가 막혀 있어도
/// 영상 번호만 있으면 저장은 되어야 하고, 나중에 열어볼 수도 있습니다.
/// 제목은 사용자가 편집 화면에서 직접 고칠 수 있습니다.
class YoutubeVideoInfo {
  const YoutubeVideoInfo({
    required this.videoId,
    this.title = '',
    this.thumbnailBytes,
  });

  /// 영상 번호입니다. 이것만은 반드시 있습니다.
  final String videoId;

  /// 영상 제목입니다. 못 가져왔으면 빈 글자입니다.
  final String title;

  /// 썸네일 그림 데이터입니다. 못 가져왔으면 null입니다.
  final Uint8List? thumbnailBytes;
}

/// 유튜브 영상 정보를 가져오는 방법에 대한 약속입니다.
///
/// 약속으로 두는 이유는 ImageSource와 같습니다 — 테스트에서 진짜 유튜브를
/// 부르지 않고 가짜로 갈아끼우기 위해서입니다. 진짜를 쓰면 테스트가 느리고,
/// 인터넷이 없으면 실패하고, 유튜브 사정에 따라 결과가 달라집니다.
abstract class YoutubeInfoSource {
  /// 영상 번호로 제목과 썸네일을 가져옵니다.
  ///
  /// 못 가져온 것은 비워서 돌려줍니다. 예외를 던지지 않습니다.
  Future<YoutubeVideoInfo> fetch(String videoId);
}

/// 진짜 유튜브에 물어보는 구현체입니다.
class NetworkYoutubeInfoSource implements YoutubeInfoSource {
  NetworkYoutubeInfoSource({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// 영상 번호로 제목과 썸네일을 가져옵니다.
  ///
  /// 제목과 썸네일을 **따로 가져오고, 각각 실패해도 나머지는 살립니다.**
  /// 하나가 안 된다고 둘 다 버리면, 썸네일은 멀쩡한데 제목만 없는 흔한 경우에
  /// 아무것도 못 보여주게 됩니다.
  @override
  Future<YoutubeVideoInfo> fetch(String videoId) async {
    final String title = await _fetchTitle(videoId);
    final Uint8List? thumbnail = await fetchThumbnail(videoId);

    return YoutubeVideoInfo(
      videoId: videoId,
      title: title,
      thumbnailBytes: thumbnail,
    );
  }

  /// 영상 제목을 가져옵니다. 못 가져오면 빈 글자입니다.
  Future<String> _fetchTitle(String videoId) async {
    // oEmbed에 넘길 주소는 우리가 직접 만듭니다. 사용자가 넣은 주소를 그대로
    // 넘기면 쇼츠나 짧은 주소일 때 유튜브가 못 알아듣는 경우가 있습니다.
    final Uri uri = Uri.parse(
      'https://www.youtube.com/oembed'
      '?url=${Uri.encodeComponent(youtubeWatchUrl(videoId))}'
      '&format=json',
    );

    try {
      final http.Response response = await _client
          .get(uri)
          .timeout(youtubeFetchTimeout);

      if (response.statusCode != 200) {
        // 비공개 영상이나 삭제된 영상이면 401/404가 옵니다.
        // 그래도 저장은 되게 해야 하므로 조용히 넘어갑니다.
        debugPrint('[유튜브] 제목 가져오기 실패 (${response.statusCode}): $videoId');
        return '';
      }

      // 한글 제목이 깨지지 않도록 UTF-8로 직접 읽습니다.
      // response.body는 서버가 알려준 인코딩을 따르는데, 유튜브가 그걸
      // 안 알려주면 latin-1로 읽어서 한글이 깨집니다.
      final String decoded = utf8.decode(response.bodyBytes);
      final Object? parsed = jsonDecode(decoded);

      if (parsed is! Map<String, dynamic>) {
        return '';
      }

      final Object? title = parsed['title'];
      if (title is String) {
        return title;
      }

      return '';
    } catch (error) {
      // 인터넷이 없거나 시간이 초과된 경우입니다.
      debugPrint('[유튜브] 제목 가져오기 오류: $error');
      return '';
    }
  }

  /// 썸네일 그림을 내려받습니다. 못 가져오면 null입니다.
  ///
  /// ── 왜 두 번 시도하나 ──
  /// `maxresdefault.jpg`가 가장 큰 그림(1280×720)이지만 **모든 영상에 있지는
  /// 않습니다.** 오래된 영상이나 화질이 낮은 영상은 아예 만들어지지 않아서
  /// 404가 옵니다. 반면 `hqdefault.jpg`(480×360)는 언제나 있습니다.
  ///
  /// 그래서 큰 것을 먼저 시도하고, 없으면 작은 것으로 내려갑니다.
  /// 처음부터 작은 것만 쓰면 무드보드에 크게 놨을 때 흐릿해집니다.
  Future<Uint8List?> fetchThumbnail(String videoId) async {
    final Uint8List? highest = await _download(
      youtubeThumbnailUrl(videoId, preferHighest: true),
    );

    if (highest != null) {
      return highest;
    }

    debugPrint('[유튜브] 큰 썸네일이 없어 기본 크기로 다시 시도: $videoId');

    return _download(youtubeThumbnailUrl(videoId, preferHighest: false));
  }

  /// 주소 하나를 내려받습니다. 실패하면 null입니다.
  Future<Uint8List?> _download(String url) async {
    try {
      final http.Response response = await _client
          .get(Uri.parse(url))
          .timeout(youtubeFetchTimeout);

      if (response.statusCode != 200) {
        return null;
      }

      // 빈 응답을 그대로 넘기면 저장 단계에서 "그림이 아니다"로 실패합니다.
      // 여기서 걸러두면 원인을 찾기 쉽습니다.
      if (response.bodyBytes.isEmpty) {
        return null;
      }

      return response.bodyBytes;
    } catch (error) {
      debugPrint('[유튜브] 썸네일 내려받기 오류: $error');
      return null;
    }
  }
}
