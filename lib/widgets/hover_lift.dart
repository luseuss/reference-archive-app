// 마우스를 올렸는지 기억했다가 알려주는 작은 도우미 위젯입니다.
//
// ── 왜 따로 만들었나 ──
// reference_card.dart의 카드는 "마우스를 올리면 살짝 떠오르는" 것 말고는
// 상태가 없습니다. 그것 하나 때문에 카드 전체를 StatefulWidget으로 바꾸면
// 코드가 길어집니다. 그래서 **호버를 기억하는 일만 하는** 작은 위젯을
// 따로 두고, 카드는 지금 올라와 있는지(`isHovered`)만 받아서 그리기만
// 합니다. (CLAUDE.md "밀린 정리거리"가 짚어둔 대로 reference_card.dart
// 파일에서 뺐습니다 — 카드 하나에만 매인 것이 아니라 다른 카드 종류가
// 생겨도 그대로 쓸 수 있는 범용 도우미라 별도 파일로 옮겼습니다)

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 마우스가 올라오면 [builder]에 `isHovered: true`를 넘겨 다시 그리게
/// 합니다.
class HoverLift extends StatefulWidget {
  const HoverLift({super.key, required this.builder, this.onHoverChanged});

  /// 지금 마우스가 올라와 있는지를 받아 화면을 만들어주는 함수입니다.
  final Widget Function(BuildContext context, bool isHovered) builder;

  /// 바깥에도 호버를 알려야 할 때 씁니다. (유튜브 미리보기)
  ///
  /// null이면 알리지 않고, 떠오르는 효과만 냅니다.
  final ValueChanged<bool>? onHoverChanged;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  /// 지금 마우스가 이 위에 올라와 있는지 여부입니다.
  bool _isHovered = false;

  /// 마우스가 들어오거나 나갔을 때 기억해두고 바깥에도 알립니다.
  void _setHovered(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
    widget.onHoverChanged?.call(isHovered);
  }

  @override
  Widget build(BuildContext context) {
    // MouseRegion = 마우스가 이 영역에 들어오고 나가는 것을 알려주는 위젯입니다.
    // 손가락 터치로는 아무 일도 일어나지 않아서, 폰에서는 저절로 조용합니다.
    return MouseRegion(
      onEnter: (PointerEnterEvent event) => _setHovered(true),
      onExit: (PointerExitEvent event) => _setHovered(false),
      child: widget.builder(context, _isHovered),
    );
  }
}
