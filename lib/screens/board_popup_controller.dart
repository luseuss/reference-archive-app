// 무드보드 판을 별도 OS 창(팝업)으로 띄우고 관리합니다.
//
// ── 왜 싱글턴인가 ──
// "팝업은 한 번에 하나만"이라는 규칙(CLAUDE.md, 설계 스펙)을 지키려면
// 지금 팝업이 떠 있는지·어느 창인지를 앱 전체에서 하나만 알고 있어야
// 합니다. 무드보드 화면(board_screen.dart)을 열 때마다 새로 만들면
// 이 정보가 흩어집니다.
//
// ── 메인 창을 닫을 때도 이걸 씁니다 ──
// lib/main.dart가 메인 창의 닫기를 가로챌 때 이 컨트롤러의
// closeIfOpen()을 불러 팝업부터 정리합니다.

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';

import '../services/board_window_sync.dart';

/// [WindowController]에는 원래 `close()`가 없습니다(0.3.1 기준 `show()`/
/// `hide()`만 있습니다). 그래서 패키지 README가 권하는 대로, "닫아라"는
/// 신호를 상대 창에 보내고 그 창이 스스로 window_manager로 닫게 만드는
/// 확장을 둡니다. [registerPopupWindowCloseHandler]가 받는 쪽,
/// [requestClose]가 보내는 쪽입니다.
extension PopupWindowControl on WindowController {
  /// 이 창에게 "스스로를 닫아라"고 요청합니다.
  ///
  /// [registerPopupWindowCloseHandler]를 먼저 불러둔 창만 실제로
  /// 닫힙니다 — 팝업 창(board_popup_app.dart)이 시작할 때 불러둡니다.
  Future<void> requestClose() => invokeMethod('window_close');
}

/// 이 창이 [PopupWindowControl.requestClose] 요청을 받으면 스스로
/// 닫히도록 준비합니다.
///
/// 팝업 창(board_popup_app.dart)이 시작할 때 한 번 불러야 합니다 —
/// **이 창 자신의 엔진 안에서** 불러야 뜻이 있습니다(창마다 자기
/// 창을 닫는 것은 자기 자신만 할 수 있습니다).
Future<void> registerPopupWindowCloseHandler() async {
  final WindowController self = await WindowController.fromCurrentEngine();
  await self.setWindowMethodHandler((call) async {
    if (call.method == 'window_close') {
      await windowManager.close();
    }
    return null;
  });
}

/// 무드보드 팝업 창을 열고 닫는 일을 맡습니다.
class BoardPopupController {
  BoardPopupController._();

  /// 앱 전체에서 하나만 씁니다.
  static final BoardPopupController instance = BoardPopupController._();

  WindowController? _popup;

  /// 지금 팝업이 떠 있는지 여부입니다.
  bool get isOpen => _popup != null;

  /// 팝업으로 [boardId]를 보여줍니다.
  ///
  /// 이미 팝업이 떠 있으면 새로 열지 않고, 그 팝업에게 "이 판을
  /// 보여줘"라고 신호만 보냅니다(한 번에 하나만 띄운다는 규칙).
  Future<void> showBoard(String boardId) async {
    final WindowController? existing = _popup;
    if (existing != null) {
      await BoardWindowSync.notifyShowBoard(boardId);
      await existing.show();
      return;
    }

    // arguments는 그냥 판 번호(boardId) 문자열입니다. 이 앱은 팝업 창이
    // 딱 한 종류(무드보드)뿐이라, 여러 창 종류를 가리는 JSON 값을
    // 만들 필요가 없습니다.
    final WindowController created = await WindowController.create(
      WindowConfiguration(hiddenAtLaunch: true, arguments: boardId),
    );
    _popup = created;
    await created.show();
  }

  /// 떠 있는 팝업을 닫습니다. 없으면 아무 일도 안 합니다.
  Future<void> closeIfOpen() async {
    final WindowController? popup = _popup;
    _popup = null;
    if (popup == null) {
      return;
    }

    try {
      await popup.requestClose();
    } catch (_) {
      // 이미 닫혔거나(사용자가 직접 닫음) 창을 못 찾으면 무시합니다.
    }
  }
}
