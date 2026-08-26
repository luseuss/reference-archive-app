// 재생기 페이지를 띄워주는 임시 서버를 확인하는 테스트입니다.
//
// ── 왜 이걸 테스트하는가 ──
// 이 서버는 유튜브 오류 153을 고치려고 만든 것입니다. 세 번 만에 찾은 해법이라
// 다시 잃어버리면 안 됩니다. 특히 두 가지는 반드시 지켜져야 합니다.
//
//   1. **내 컴퓨터 밖에서는 접속할 수 없어야 합니다.** 아무 데나 열어두면
//      같은 와이파이에 있는 사람이 들여다볼 수 있게 됩니다.
//   2. **끄면 정말 꺼져야 합니다.** 안 그러면 영상 볼 때마다 서버가 쌓입니다.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/services/local_player_server.dart';

void main() {
  late LocalPlayerServer server;

  setUp(() {
    server = LocalPlayerServer();
  });

  tearDown(() async {
    // 테스트가 실패해도 서버가 남지 않도록 언제나 정리합니다.
    await server.stop();
  });

  /// 주소에서 글자를 받아옵니다. 실패하면 예외가 납니다.
  Future<String> fetch(String url) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(Uri.parse(url));
      final HttpClientResponse response = await request.close();
      return await response.transform(utf8.decoder).join();
    } finally {
      client.close();
    }
  }

  test('켜면 넣어준 HTML을 그대로 돌려준다', () async {
    const String html = '<html><body>재생기</body></html>';

    final String? url = await server.start(html);

    expect(url, isNotNull);
    expect(await fetch(url!), html);
  });

  test('내 컴퓨터 안에서만 열린다', () async {
    // 이게 깨지면 같은 와이파이의 다른 사람이 접근할 수 있게 됩니다.
    final String? url = await server.start('<html></html>');

    expect(url, startsWith('http://127.0.0.1:'));
  });

  test('포트는 그때그때 비어 있는 번호를 받는다', () async {
    // 8080처럼 고정해두면 다른 프로그램이 쓰고 있을 때 실패합니다.
    final String? url = await server.start('<html></html>');

    final int port = Uri.parse(url!).port;
    expect(port, greaterThan(0));
    // 0은 "아무거나 골라줘"라는 요청값입니다. 실제로 받은 번호가 들어있어야 합니다.
    expect(port, isNot(0));
  });

  test('경로가 무엇이든 재생기 페이지를 돌려준다', () async {
    // 파일을 여러 개 다룰 일이 없어서 경로를 따지지 않습니다.
    const String html = '<html>ok</html>';
    final String? url = await server.start(html);

    const String somePath = '아무거나/경로';

    expect(await fetch(url!), html);
    expect(await fetch('$url$somePath'), html);
  });

  test('끄면 더 이상 접속되지 않는다', () async {
    // 안 꺼지면 영상을 볼 때마다 서버가 하나씩 쌓입니다.
    final String? url = await server.start('<html></html>');

    await server.stop();

    expect(() => fetch(url!), throwsA(isA<SocketException>()));
  });

  test('두 번 켜면 앞의 것은 저절로 꺼진다', () async {
    // 같은 화면에서 영상을 바꿔 틀 때 서버가 쌓이면 안 됩니다.
    final String? firstUrl = await server.start('<html>첫 번째</html>');
    final String? secondUrl = await server.start('<html>두 번째</html>');

    // 새 서버는 새 번호를 받으므로 주소가 달라집니다.
    expect(secondUrl, isNot(firstUrl));

    expect(await fetch(secondUrl!), '<html>두 번째</html>');
    expect(() => fetch(firstUrl!), throwsA(isA<SocketException>()));
  });

  test('켠 적 없이 꺼도 아무 일도 안 일어난다', () async {
    // 화면을 열자마자 닫는 경우입니다. 여기서 예외가 나면 앱이 죽습니다.
    await server.stop();
    await server.stop();
  });
}
