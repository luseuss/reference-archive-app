// 우클릭(또는 길게 누르기)으로 여는 메뉴를 어디서든 똑같은 방식으로
// 쓸 수 있게 만든 공용 부품입니다.
//
// ── 왜 항목을 미리 만들지 않고 함수로 받나 ──
// [ContextMenuAction]을 미리 리스트로 만들어두면, 메뉴를 열 때마다
// 그 시점의 상태(예: "지금 즐겨찾기인가?")가 아니라 위젯이 마지막으로
// 그려졌을 때의 상태를 보여줄 위험이 있습니다. 그래서 메뉴를 **여는
// 순간**에 [buildActions]를 한 번 불러서 항목을 새로 만듭니다 — "즐겨찾기
// 켜기"↔"즐겨찾기 끄기"처럼 상태에 따라 글자가 바뀌는 항목에 특히
// 중요합니다.
//
// ── 데스크톱은 우클릭, 모바일·태블릿은 길게 누르기 ──
// CLAUDE.md의 기존 방침("우클릭 컨텍스트 메뉴 → 모바일은 롱프레스로
// 동일 메뉴")을 그대로 따릅니다. `enableLongPress`를 끄면 우클릭만
// 받습니다 — 그 자리에 이미 다른 뜻의 길게 누르기가 있을 때
// (예: reference_card.dart의 "길게 누르면 고르기 모드") 씁니다.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 메뉴 항목 하나입니다.
class ContextMenuAction {
  const ContextMenuAction({
    required this.label,
    required this.onSelected,
    this.icon,
    this.isDestructive = false,
  });

  /// 메뉴에 보일 글자입니다.
  final String label;

  /// 왼쪽에 곁들일 아이콘입니다. 없으면 아이콘 없이 글자만 보입니다.
  final IconData? icon;

  /// 눌렀을 때 실행할 동작입니다.
  final VoidCallback onSelected;

  /// 삭제처럼 되돌리기 어려운 동작이면 참으로 둡니다. 글자가 위험색으로 보입니다.
  final bool isDestructive;
}

/// [child]를 우클릭하거나(데스크톱) 길게 누르면(모바일·태블릿) 메뉴를 띄웁니다.
class ContextMenuRegion extends StatelessWidget {
  const ContextMenuRegion({
    super.key,
    required this.buildActions,
    required this.child,
    this.enableLongPress = true,
    this.avoidGestureArena = false,
  });

  /// 메뉴를 열 때 보여줄 항목들을 만듭니다. 빈 목록을 돌려주면 메뉴가 안 뜹니다.
  final List<ContextMenuAction> Function() buildActions;

  /// 메뉴를 씌울 실제 내용입니다.
  final Widget child;

  /// 길게 누르기로도 열리게 할지 여부입니다.
  final bool enableLongPress;

  /// **끌기(드래그)가 이미 걸려 있는 자리에서만 켭니다.**
  ///
  /// 이 위젯의 우클릭 인식기(GestureDetector)는 평소엔 문제가 없지만,
  /// 이미 다른 GestureDetector(예: 카드 끌기)가 같은 자리를 덮고 있으면
  /// **제스처 아레나에 경쟁자가 하나 더 늘어납니다.** 경쟁자가 둘 이상이면
  /// Flutter는 "실제로 그만큼 움직였는지"(터치 여유값 초과)를 확인한
  /// 뒤에야 끌기를 인정합니다 — 혼자였을 때는 그 확인 없이 바로
  /// 인정됩니다. 그 결과 **아주 살짝만 끄는 경우 끌기 자체가 하나도
  /// 안 먹히는** 회귀가 생깁니다(무드보드 카드에서 실제로 겪었습니다 —
  /// board_canvas.dart 위쪽 설명이 경고해온 바로 그 문제입니다).
  ///
  /// 이 값을 켜면 GestureDetector 대신 `Listener`로 우클릭(마우스 오른쪽
  /// 버튼 누름)만 원시 신호로 잡습니다. `Listener`는 아레나에 안 끼어서
  /// 끌기 인식에 전혀 영향을 안 줍니다 — 대신 [enableLongPress]는
  /// 무시됩니다(길게 누르기는 원시 신호로 흉내내기 까다로워서, 이
  /// 모드에서는 데스크톱 우클릭만 지원합니다).
  final bool avoidGestureArena;

  /// [position] 자리에 메뉴를 띄우고, 고른 항목의 동작을 실행합니다.
  Future<void> _open(BuildContext context, Offset position) async {
    final List<ContextMenuAction> actions = buildActions();
    if (actions.isEmpty) {
      return;
    }

    // Overlay 기준 상대 좌표로 바꿔야 메뉴가 화면 밖으로 안 나갑니다.
    final RenderBox overlayBox =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final RelativeRect menuPosition = RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      overlayBox.size.width - position.dx,
      overlayBox.size.height - position.dy,
    );

    final ContextMenuAction? picked = await showMenu<ContextMenuAction>(
      context: context,
      position: menuPosition,
      items: <PopupMenuEntry<ContextMenuAction>>[
        for (final ContextMenuAction action in actions)
          PopupMenuItem<ContextMenuAction>(
            value: action,
            child: Row(
              children: <Widget>[
                if (action.icon != null) ...<Widget>[
                  Icon(
                    action.icon,
                    size: 18,
                    color: action.isDestructive
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  action.label,
                  style: action.isDestructive
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
                      : null,
                ),
              ],
            ),
          ),
      ],
    );

    // 메뉴가 닫힌 뒤에 실행합니다. showMenu 안에서 바로 실행하면, 그
    // 동작이 또 다른 대화상자를 여는 경우 두 대화상자가 겹칩니다.
    picked?.onSelected();
  }

  @override
  Widget build(BuildContext context) {
    if (avoidGestureArena) {
      return Listener(
        // 테스트가 이 Listener를 정확히 짚을 수 있게 이름표를 답니다.
        // (Scaffold 등 조상 위젯도 자기만의 Listener를 여럿 쓰기 때문에,
        // 이름표 없이 타입만으로 찾으면 여러 개가 걸립니다)
        key: const ValueKey<String>('context-menu-region-listener'),

        // opaque = 아무것도 안 그려진 자리(카드 사이 여백, 짧은 글자
        // 옆의 남는 자리 등)를 눌러도 반응합니다. 기본값(deferToChild)은
        // 자식이 실제로 그림을 그린 자리만 반응해서, "줄 전체 아무 데나
        // 눌러도 메뉴가 뜬다"는 기대와 어긋납니다.
        behavior: HitTestBehavior.opaque,
        onPointerDown: (PointerDownEvent event) {
          if (event.kind == PointerDeviceKind.mouse &&
              event.buttons == kSecondaryMouseButton) {
            _open(context, event.position);
          }
        },
        child: child,
      );
    }

    return GestureDetector(
      // 위 Listener 분기와 같은 이유로 opaque를 씁니다.
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (TapUpDetails details) =>
          _open(context, details.globalPosition),
      onLongPressStart: enableLongPress
          ? (LongPressStartDetails details) =>
              _open(context, details.globalPosition)
          : null,
      child: child,
    );
  }
}
