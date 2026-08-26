// 주소에서 이미지를 내려받는 부분이 제대로 동작하는지 확인하는 테스트입니다.
//
// ── 진짜 인터넷을 쓰지 않습니다 ──
// 실제로 인터넷에 접속하는 테스트는 느리고, 연결이 없으면 실패하고,
// 남의 서버 사정에 따라 결과가 달라집니다. 그래서 http.Client 자리에
// **미리 정해둔 답을 돌려주는 가짜**를 끼워 넣습니다.
//
// 덕분에 "서버가 404를 주면 어떻게 되는가" 같은, 실제로는 만들기 어려운
// 상황도 마음대로 시험해볼 수 있습니다.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reference_archive_app/services/image_source.dart';
import 'package:reference_archive_app/services/network_image_source.dart';

void main() {
  /// 정해둔 답을 돌려주는 가짜 http 클라이언트를 만듭니다.
  http.Client fakeClient({
    int statusCode = 200,
    List<int>? body,
    Object? throwError,
  }) {
    return MockClient((http.Request request) async {
      if (throwError != null) {
        throw throwError;
      }
      return http.Response.bytes(body ?? <int>[1, 2, 3], statusCode);
    });
  }

  group('주소 형식 확인', () {
    test('http로 시작하지 않으면 거절한다', () async {
      final NetworkImageSource source = NetworkImageSource(client: fakeClient());

      final ImageFetchResult result = await source.fetchFromUrl('그냥 글자');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('http로 시작하는 주소'));
    });

    test('file: 주소는 거절한다', () async {
      // 파일 주소를 그대로 받아들이면 엉뚱한 곳을 읽으려 할 수 있습니다.
      final NetworkImageSource source = NetworkImageSource(client: fakeClient());

      final ImageFetchResult result =
          await source.fetchFromUrl('file:///C:/secret.txt');

      expect(result.isSuccess, isFalse);
    });

    test('빈 글자는 거절한다', () async {
      final NetworkImageSource source = NetworkImageSource(client: fakeClient());

      expect((await source.fetchFromUrl('')).isSuccess, isFalse);
    });
  });

  group('내려받기', () {
    test('정상이면 데이터를 돌려준다', () async {
      final NetworkImageSource source =
          NetworkImageSource(client: fakeClient(body: <int>[9, 8, 7]));

      final ImageFetchResult result =
          await source.fetchFromUrl('https://example.com/a.jpg');

      expect(result.isSuccess, isTrue);
      expect(result.bytes, Uint8List.fromList(<int>[9, 8, 7]));
    });

    test('주소에서 제목을 뽑아준다', () async {
      final NetworkImageSource source = NetworkImageSource(client: fakeClient());

      final ImageFetchResult result =
          await source.fetchFromUrl('https://example.com/photos/sunset-view.jpg');

      expect(result.suggestedTitle, 'sunset-view');
    });

    test('404면 "그 주소에 이미지가 없다"고 알려준다', () async {
      final NetworkImageSource source =
          NetworkImageSource(client: fakeClient(statusCode: 404));

      final ImageFetchResult result =
          await source.fetchFromUrl('https://example.com/a.jpg');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('이미지가 없습니다'));
    });

    test('403이면 복사해서 붙여넣으라고 안내한다', () async {
      // 사이트가 막는 경우입니다. 사용자가 할 수 있는 다른 방법을 알려줘야
      // "안 되네" 하고 포기하지 않습니다.
      final NetworkImageSource source =
          NetworkImageSource(client: fakeClient(statusCode: 403));

      final ImageFetchResult result =
          await source.fetchFromUrl('https://example.com/a.jpg');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('복사해서 붙여넣어'));
    });

    test('너무 크면 거절한다', () async {
      final List<int> tooBig = List<int>.filled(maxDownloadBytes + 1, 0);
      final NetworkImageSource source =
          NetworkImageSource(client: fakeClient(body: tooBig));

      final ImageFetchResult result =
          await source.fetchFromUrl('https://example.com/big.jpg');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('너무 큽니다'));
    });

    test('빈 응답이면 거절한다', () async {
      final NetworkImageSource source =
          NetworkImageSource(client: fakeClient(body: <int>[]));

      final ImageFetchResult result =
          await source.fetchFromUrl('https://example.com/a.jpg');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('빈 파일'));
    });

    test('연결이 안 되면 앱이 죽지 않고 안내만 한다', () async {
      // 인터넷이 끊긴 상황입니다. 오류가 그대로 위로 올라가면 앱이 꺼집니다.
      final NetworkImageSource source = NetworkImageSource(
        client: fakeClient(throwError: const SocketExceptionStub()),
      );

      final ImageFetchResult result =
          await source.fetchFromUrl('https://example.com/a.jpg');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('인터넷 연결'));
    });
  });

  group('주소에서 제목 뽑기', () {
    test('확장자를 뗀다', () {
      expect(titleFromUrl(Uri.parse('https://a.com/sunset.jpg')), 'sunset');
    });

    test('쿼리는 무시한다', () {
      expect(
        titleFromUrl(Uri.parse('https://a.com/sunset.jpg?w=800&h=600')),
        'sunset',
      );
    });

    test('확장자가 없어도 된다', () {
      expect(titleFromUrl(Uri.parse('https://a.com/photo')), 'photo');
    });

    test('한글 주소도 읽는다', () {
      expect(
        titleFromUrl(Uri.parse('https://a.com/%EB%85%B8%EC%9D%84.jpg')),
        '노을',
      );
    });

    test('뽑아낼 게 없으면 null', () {
      expect(titleFromUrl(Uri.parse('https://a.com/')), isNull);
      expect(titleFromUrl(Uri.parse('https://a.com')), isNull);
    });
  });
}

/// 인터넷 연결 실패를 흉내내는 예외입니다.
///
/// 실제 SocketException을 만들려면 dart:io를 가져와야 하는데,
/// 이 테스트에는 그 외에 dart:io가 필요 없어서 간단한 대역을 씁니다.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
