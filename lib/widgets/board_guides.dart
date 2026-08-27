// 카드가 다른 카드에 착 붙었을 때 잠깐 보이는 **안내선**입니다.
//
// ── 왜 필요한가 ──
// 스냅은 눈에 안 보이는 기능입니다. 붙었는지 안 붙었는지 알 수가 없으면
// "왜 여기서 멈추지?" 하고 답답해집니다. 선을 하나 그어주면 **무엇에
// 맞춰졌는지**가 바로 보입니다.
//
// ── 클릭을 받으면 안 됩니다 ──
// 이 선은 판 위에 얹히기 때문에, 그냥 두면 **빈 곳을 끌 때 이 선이 클릭을
// 가로채서 판이 안 움직입니다.** board_canvas.dart가 바탕을 안 그리는 것과
// 같은 이유입니다. 그래서 IgnorePointer로 감쌉니다.
//
// ── 격자에 붙었을 때는 안 그립니다 ──
// 격자는 눈에 안 보이는 것이라, 아무것도 없는 자리에 선이 뜨면 "저 선은
// 뭐지?" 하게 됩니다. 카드끼리 붙었을 때만 보여줍니다.
// (board_snap.dart의 BoardSnapResult 설명 참고)

import 'package:flutter/material.dart';

/// 안내선의 굵기입니다.
///
/// 1픽셀은 확대·축소하면 사라져 보이고, 두꺼우면 그림을 가립니다.
const double boardGuideThickness = 1.5;

/// 스냅 안내선을 그리는 겹입니다.
class BoardGuides extends StatelessWidget {
  const BoardGuides({
    super.key,
    required this.canvasRect,
    required this.guideX,
    required this.guideY,
  });

  /// 카드를 그리는 자리입니다. 선을 이 끝에서 저 끝까지 긋습니다.
  ///
  /// 판 좌표라서, 그릴 때는 왼쪽 위 모서리만큼 빼야 합니다.
  /// (board_canvas.dart가 카드를 놓을 때 하는 것과 같습니다)
  final Rect canvasRect;

  /// 세로 선을 그을 자리입니다(판 좌표 x). 없으면 null입니다.
  final double? guideX;

  /// 가로 선을 그을 자리입니다(판 좌표 y). 없으면 null입니다.
  final double? guideY;

  /// 안내선을 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.primary;

    return IgnorePointer(
      child: Stack(
        children: <Widget>[
          if (guideX != null)
            Positioned(
              left: guideX! - canvasRect.left - boardGuideThickness / 2,
              top: 0,
              bottom: 0,
              width: boardGuideThickness,
              child: ColoredBox(color: color),
            ),
          if (guideY != null)
            Positioned(
              top: guideY! - canvasRect.top - boardGuideThickness / 2,
              left: 0,
              right: 0,
              height: boardGuideThickness,
              child: ColoredBox(color: color),
            ),
        ],
      ),
    );
  }
}
