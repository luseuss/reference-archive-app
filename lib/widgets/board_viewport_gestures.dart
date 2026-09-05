// board_viewport.dart의 "빈 곳 끌기" 손잡이가 쓰는 작은 도우미 둘입니다.
//
// ── 왜 board_viewport.dart에서 뺐나 ──
// CLAUDE.md "밀린 정리거리"가 짚어둔 대로입니다. 판 이동·확대(줌·팬)와
// 성격이 다른 별개의 관심사(클릭인지 끌기인지 가리기, 마퀴 네모의 자리)라
// 나눌 수 있었습니다.
//
// ── ChangeNotifier로 만들지 않은 이유 ──
// 다른 컨트롤러(home_selection_controller.dart 등)와 달리 이 둘은
// board_viewport.dart 한 파일 안에서만 쓰는, 화면과 무관한 순수 상태
// 보관함입니다. 그 파일의 State가 이미 pan·zoom 때문에 setState를 쓰고
// 있어서, 여기서 또 다른 "다시 그려라" 체계(notifyListeners)를 두면
// 오히려 헷갈립니다. 그래서 그냥 값만 들고 있고, **언제 다시 그릴지는
// 여전히 board_viewport.dart가 setState로 정합니다.**

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// 빈 곳을 눌렀다 뗄 때까지 "클릭인지 끌기인지"와 "어느 버튼이었는지"를
/// 가리는 데 필요한 값들을 담습니다.
///
/// `PointerDownEvent.buttons`는 [kPrimaryButton](왼쪽) / [kMiddleMouseButton]
/// (휠 버튼) / [kSecondaryButton](오른쪽)을 비트로 담고 있습니다. 터치는
/// 늘 kPrimaryButton으로 옵니다 — 손가락에는 "가운데 버튼"이 없습니다.
class EmptyPointerGesture {
  /// 눌린 순간의 화면 좌표입니다. 아직 안 눌렸으면 null입니다.
  Offset? downAt;

  /// 눌린 뒤로 조금이라도 움직였는지 여부입니다.
  bool moved = false;

  /// 지금 눌려 있는 마우스 버튼입니다.
  int buttons = kPrimaryButton;

  /// 마우스 휠 버튼(가운데 버튼)으로 눌렀는지 여부입니다.
  /// 참이면 판 이동, 거짓이면(왼쪽 버튼·터치) 마퀴입니다.
  bool get isPanning => buttons & kMiddleMouseButton != 0;

  /// 눌렸을 때 부릅니다. 시작점과 버튼을 기억해둡니다.
  void onDown(PointerDownEvent event) {
    downAt = event.position;
    moved = false;
    buttons = event.buttons;
  }

  /// 눌린 채로 움직이는 동안 부릅니다.
  ///
  /// `kTouchSlop`은 Flutter가 "진짜 움직인 것"으로 쳐주는 최소 거리입니다.
  /// 그보다 짧으면 손이 살짝 떨린 것으로 보고 클릭 판정을 유지합니다.
  void onMove(PointerMoveEvent event) {
    final Offset? start = downAt;
    if (start == null) {
      return;
    }

    if ((event.position - start).distance > kTouchSlop) {
      moved = true;
    }
  }
}

/// 마퀴(다중선택 네모)가 화면의 어디서 어디까지 그려지는지를 담습니다.
///
/// **화면 좌표만 압니다.** 판 좌표로 바꾸는 것은 이 클래스가 하지
/// 않습니다 — 그러려면 배율·이동 값을 알아야 하는데, 그건
/// board_viewport.dart의 `_scaleFor`/`_offsetFor`만 압니다(CLAUDE.md가
/// 미리 남겨둔 주의사항). 그래서 판 좌표 변환은 여전히 그 파일이 하고,
/// 이 클래스는 "지금 마퀴가 화면 어디에 있는지"만 기억합니다.
class MarqueeState {
  /// 마퀴를 그리는 중인지 여부입니다.
  bool active = false;

  /// 마퀴의 시작점입니다. (화면 좌표)
  Offset? start;

  /// 마퀴의 지금 위치입니다. (화면 좌표)
  Offset? current;

  /// 지금 그릴 사각형입니다. 시작·끝이 아직 없으면 null입니다.
  Rect? get rect {
    final Offset? s = start;
    final Offset? c = current;
    if (s == null || c == null) {
      return null;
    }
    return Rect.fromPoints(s, c);
  }

  /// 마퀴를 시작합니다.
  void begin(Offset localPosition) {
    active = true;
    start = localPosition;
    current = localPosition;
  }

  /// 마퀴 끝점을 [delta]만큼 옮깁니다.
  void moveBy(Offset delta) {
    current = (current ?? Offset.zero) + delta;
  }

  /// 마퀴를 끝냅니다. 다음에 다시 시작할 수 있도록 값을 비웁니다.
  void finish() {
    active = false;
    start = null;
    current = null;
  }
}
