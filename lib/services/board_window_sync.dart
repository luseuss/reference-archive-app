// 무드보드 메인 창과 팝업 창이 서로 "이 판이 바뀌었다"/"이 판을
// 보여줘"라는 신호를 주고받는 통로입니다.
//
// ── 왜 필요한가 ──
// 두 창은 desktop_multi_window로 만들어진 서로 다른 Flutter 엔진이라
// 메모리(변수)를 안 나눕니다. drift의 자동 갱신(watch())도 같은
// 프로세스의 같은 연결 안에서만 작동해서 창 사이에는 안 통합니다.
// 그래서 한쪽이 카드를 저장하면(board_interaction_controller.dart의
// onSaved), 상대 창에게 "다시 읽어라"고 명시적으로 알려야 합니다.
//
// ── 창 하나에 신호 받는 곳이 왜 하나뿐인가 ──
// WindowMethodChannel.setMethodCallHandler는 창(엔진) 하나에 핸들러를
// 하나만 등록합니다(다시 부르면 갈아치웁니다). 이 창에서 지금 어떤
// BoardScreen이 열려 있든 신호를 받아야 하므로, 여기서 핸들러를 한 번만
// 등록해두고(ensureInitialized) 실제 화면들은 리스너 자리에 자기
// 콜백을 꽂았다 빼기만 합니다.

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 메인 ↔ 팝업 두 창끼리만 주고받는 채널입니다. bidirectional이라
/// 정확히 둘만 서로를 부를 수 있습니다 — 팝업은 한 번에 하나뿐이므로
/// 딱 맞습니다.
const WindowMethodChannel _channel = WindowMethodChannel(
  'board_popup_sync',
  mode: ChannelMode.bidirectional,
);

/// 이 기기에서 무드보드 팝업 창을 쓸 수 있는지 여부입니다.
///
/// 창이 있는 데스크톱(Windows/macOS/Linux)에서만 뜻이 있습니다.
/// board_window_controller.dart의 supportsAlwaysOnTopWindow와 같은
/// 판정입니다 — 이 기능 전용으로 따로 둡니다(이 프로젝트가 지금까지
/// 플랫폼 판정을 그 기능이 있는 파일마다 따로 두는 방식과 같습니다).
bool get supportsBoardPopupWindow {
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

/// 무드보드 메인 창과 팝업 창 사이의 신호를 주고받습니다.
class BoardWindowSync {
  BoardWindowSync._();

  static bool _initialized = false;
  static void Function(String boardId)? _onCardsChanged;
  static void Function(String boardId)? _onShowBoard;

  /// 이 창(엔진)에서 신호를 받을 준비를 합니다. 여러 번 불러도
  /// 안전합니다(두 번째부터는 조용히 넘어갑니다).
  static void ensureInitialized() {
    if (_initialized) {
      return;
    }
    _initialized = true;

    _channel.setMethodCallHandler((MethodCall call) async {
      final String boardId = call.arguments as String;
      switch (call.method) {
        case 'cardsChanged':
          _onCardsChanged?.call(boardId);
        case 'showBoard':
          _onShowBoard?.call(boardId);
      }
      return null;
    });
  }

  /// "이 판이 바뀌었다"는 신호를 받을 콜백을 꽂습니다. null을 넘기면 뺍니다.
  ///
  /// 지금 열려 있는 BoardScreen이 initState에서 꽂고 dispose에서 뺍니다.
  static void setCardsChangedListener(void Function(String boardId)? listener) {
    _onCardsChanged = listener;
  }

  /// "이 판을 보여줘"라는 신호를 받을 콜백을 꽂습니다. 팝업 창의 바깥
  /// 껍데기(board_popup_app.dart)만 씁니다 — 메인 창은 이 신호를
  /// 받을 일이 없습니다.
  static void setShowBoardListener(void Function(String boardId)? listener) {
    _onShowBoard = listener;
  }

  /// 상대 창에게 "이 판이 바뀌었으니 다시 읽어라"고 알립니다.
  ///
  /// 상대 창이 없으면(팝업을 안 띄웠으면) 조용히 실패합니다 — 알릴
  /// 상대가 없는 것은 오류가 아닙니다.
  static Future<void> notifyCardsChanged(String boardId) =>
      _invoke('cardsChanged', boardId);

  /// 팝업에게 "이 판을 보여줘"라고 알립니다. (메인 → 팝업 전용)
  static Future<void> notifyShowBoard(String boardId) =>
      _invoke('showBoard', boardId);

  static Future<void> _invoke(String method, String boardId) async {
    ensureInitialized();
    try {
      await _channel.invokeMethod(method, boardId);
    } catch (_) {
      // 상대 창이 없거나 아직 준비되지 않았습니다. 조용히 넘어갑니다.
    }
  }
}
