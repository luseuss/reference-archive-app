// 무드보드 판 위에서 유튜브 카드를 "그 자리에서 바로" 재생하는 상태를
// 담습니다.
//
// ── 메인 목록의 호버 미리보기와 무엇이 다른가 ──
// home_hover_preview_controller.dart는 마우스를 올리면 **저절로**,
// 소리 없이, 잠깐 스쳐 지나가는 용도로 켜집니다. 이건 그와 달리
// **재생 버튼을 눌러야** 켜지고, 소리와 유튜브 기본 조작 버튼이 그대로
// 나옵니다 — 판을 보면서 실제로 영상을 챙겨 보려는 용도라 다릅니다.
// 그래서 따로 뒀습니다.
//
// ── ChangeNotifier가 무엇인가 ──
// home_hover_preview_controller.dart와 같은 방식입니다. 재생이 켜지거나
// 꺼지면 notifyListeners()가 불리고, 화면이 저절로 다시 그려집니다.

import 'package:flutter/foundation.dart';

import '../services/local_player_server.dart';
import '../services/youtube_url.dart';

/// 판 위 유튜브 카드의 "그 자리 재생" 상태와 동작을 담습니다.
class BoardVideoPlaybackController extends ChangeNotifier {
  /// 재생기 페이지를 띄워주는 임시 서버입니다.
  ///
  /// 전체화면 재생 화면(youtube_player_screen.dart)이 쓰는 것과 같은
  /// 도구입니다. 유튜브 재생기는 진짜 주소를 가진 페이지 안에 있어야
  /// 하기 때문입니다(local_player_server.dart 참고 — 안 그러면 "오류
  /// 153"이 납니다).
  final LocalPlayerServer _server = LocalPlayerServer();

  /// 지금 이 자리에서 재생 중인 카드의 번호입니다. 없으면 null입니다.
  ///
  /// **판 안에서 한 번에 하나만 재생됩니다.** 레퍼런스 번호가 아니라
  /// 카드 번호(BoardCard.id)로 구분합니다 — 같은 레퍼런스가 한 판에
  /// 여러 장 놓일 수 있어서(board_interaction_controller.dart의
  /// addCardAt 설명 참고), 레퍼런스 번호로 구분하면 두 장이 동시에
  /// "재생 중"으로 잘못 표시될 수 있습니다.
  String? get playingCardId => _playingCardId;
  String? _playingCardId;

  /// 재생기 웹뷰가 열어야 할 주소입니다. 재생 중이 아니면 null입니다.
  String? get playerUrl => _playerUrl;
  String? _playerUrl;

  /// 이 컨트롤러가 이미 dispose됐는지 여부입니다.
  ///
  /// 서버를 켜는 사이에 화면이 닫혔으면 notifyListeners()를 부르면
  /// 안 되므로 여기서 막습니다(home_hover_preview_controller.dart와
  /// 같은 이유).
  bool _disposed = false;

  /// [cardId] 카드에서 [videoId] 영상을 그 자리에 바로 재생합니다.
  ///
  /// 이미 다른 카드가 재생 중이었다면 그건 자동으로 멈춥니다
  /// (LocalPlayerServer.start()가 내부적으로 먼저 stop()을 부릅니다).
  Future<void> play(String cardId, String videoId) async {
    // 어느 카드가 재생될지 먼저 정해둡니다. 서버가 켜지는 사이에
    // 다른 카드를 또 누르면, 나중에 도착한 요청이 이겨야 합니다.
    _playingCardId = cardId;
    notifyListeners();

    final String? url = await _server.start(
      // muted를 안 주면 기본값(false)이라 소리와 조작 버튼이 그대로
      // 나옵니다 — 전체화면 재생 화면과 똑같은 모습입니다.
      youtubePlayerHtml(videoId),
    );

    if (_disposed) {
      return;
    }

    // 서버를 켜는 사이에 사용자가 다른 카드를 눌렀으면(또는 재생을
    // 그만뒀으면) 이 응답은 무시합니다. 안 그러면 방금 누른 카드가
    // 아니라 예전에 누른 카드가 재생됩니다.
    if (_playingCardId != cardId) {
      return;
    }

    if (url == null) {
      // 재생기를 못 띄웠습니다. 재생 중 표시를 지워 다시 썸네일로
      // 돌아가게 합니다 — 켜지지도 않은 채로 "재생 중" 표시만 남으면
      // 안 됩니다.
      _playingCardId = null;
      _playerUrl = null;
      notifyListeners();
      return;
    }

    _playerUrl = url;
    notifyListeners();
  }

  /// 재생을 멈추고 그 카드를 다시 썸네일로 되돌립니다.
  void stop() {
    if (_playingCardId == null) {
      return;
    }

    _playingCardId = null;
    _playerUrl = null;
    notifyListeners();

    // 서버는 끄는 데 시간이 걸리므로 기다리지 않습니다. 화면은 이미
    // 썸네일로 돌아갔고, 서버는 뒤에서 정리되면 됩니다.
    _server.stop();
  }

  /// [cardId] 카드가 판에서 내려갈 때 부릅니다. 그 카드가 지금 재생
  /// 중이었다면 함께 멈춥니다 — 안 그러면 화면에서 사라진 카드의
  /// 영상이 소리만 계속 나게 됩니다.
  void stopIfPlaying(String cardId) {
    if (_playingCardId == cardId) {
      stop();
    }
  }

  /// 화면이 사라질 때 켜둔 서버를 정리합니다.
  @override
  void dispose() {
    _disposed = true;
    _server.stop();
    super.dispose();
  }
}
