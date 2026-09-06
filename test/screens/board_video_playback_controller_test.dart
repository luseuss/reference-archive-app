// 무드보드 판 위에서 유튜브 카드를 그 자리에 바로 재생하는 상태
// (BoardVideoPlaybackController)를 확인하는 테스트입니다.
//
// ── 이 테스트가 확인하지 못하는 것 ──
// 재생기 웹뷰가 실제로 화면에 뜨는지는 여기서 알 수 없습니다. 테스트
// 환경에서는 웹뷰 부품이 안 켜지기 때문입니다(재생 화면과 같은 사정 —
// home_hover_preview_test.dart 참고). 그건 `flutter run -d windows`로
// 직접 봐야 합니다.
//
// 대신 여기서는 자동으로 확인할 수 있는 것을 확실히 잡아둡니다 —
// LocalPlayerServer는 순수 dart:io라 테스트 환경에서도 실제로 켜지고
// 켜지므로(local_player_server_test.dart 참고), 그 위에 얹은 "한 번에
// 하나만 재생된다"는 규칙을 직접 확인할 수 있습니다.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/screens/board_video_playback_controller.dart';

void main() {
  late BoardVideoPlaybackController controller;

  setUp(() {
    controller = BoardVideoPlaybackController();
  });

  tearDown(() {
    // 테스트가 실패해도 서버가 남지 않도록 언제나 정리합니다.
    controller.dispose();
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

  test('처음에는 재생 중인 카드가 없다', () {
    expect(controller.playingCardId, isNull);
    expect(controller.playerUrl, isNull);
  });

  test('재생하면 그 카드 번호와 주소가 채워진다', () async {
    await controller.play('card-1', 'videoIdAAAA');

    expect(controller.playingCardId, 'card-1');
    expect(controller.playerUrl, isNotNull);
    expect(await fetch(controller.playerUrl!), contains('videoIdAAAA'));
  });

  test('다른 카드를 재생하면 앞서 틀던 것은 멈춘다 (한 번에 하나만)', () async {
    await controller.play('card-1', 'videoIdAAAA');
    final String firstUrl = controller.playerUrl!;

    await controller.play('card-2', 'videoIdBBBB');

    expect(controller.playingCardId, 'card-2');
    expect(await fetch(controller.playerUrl!), contains('videoIdBBBB'));

    // 앞서 틀던 서버는 꺼져서 더 이상 접속되지 않아야 합니다.
    expect(() => fetch(firstUrl), throwsA(isA<SocketException>()));
  });

  test('stop을 부르면 재생 중인 카드가 없어진다', () async {
    await controller.play('card-1', 'videoIdAAAA');

    controller.stop();

    expect(controller.playingCardId, isNull);
    expect(controller.playerUrl, isNull);
  });

  test('stopIfPlaying은 그 카드가 재생 중일 때만 멈춘다', () async {
    await controller.play('card-1', 'videoIdAAAA');

    // 다른 카드 번호로 부르면 아무 일도 안 일어납니다.
    controller.stopIfPlaying('card-2');
    expect(controller.playingCardId, 'card-1');

    // 재생 중인 카드 번호로 부르면 멈춥니다.
    controller.stopIfPlaying('card-1');
    expect(controller.playingCardId, isNull);
  });

  test('재생 중 알림(notifyListeners)이 켜고 끌 때 정확히 나간다', () async {
    int notifyCount = 0;
    controller.addListener(() => notifyCount++);

    await controller.play('card-1', 'videoIdAAAA');
    expect(notifyCount, greaterThan(0));

    final int afterPlay = notifyCount;
    controller.stop();
    expect(notifyCount, greaterThan(afterPlay));
  });
}
