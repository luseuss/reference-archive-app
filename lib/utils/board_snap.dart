// 카드를 옮기거나 크기를 바꿀 때 **다른 카드에 착 붙게** 하는 계산입니다.
//
// ── 왜 필요한가 ──
// 무드보드는 늘어놓는 판입니다. 그런데 손으로만 맞추면 3픽셀씩 어긋나서
// 줄이 안 맞고, 그걸 눈으로 잡아내기도 어렵습니다. 가까이 가면 알아서
// 붙여주면 훨씬 빨리 정돈됩니다.
//
// ── 두 가지가 있습니다 ──
//   카드끼리 — 다른 카드의 가장자리·중심선에 맞춥니다. **항상 켜져 있습니다.**
//   격자     — 20픽셀 눈금에 맞춥니다. **켜고 끌 수 있습니다.**
//
// 격자는 **카드끼리 맞는 것이 하나도 없을 때만** 씁니다. 순서를 반대로 하면
// 격자를 켜둔 동안 카드끼리는 절대 안 맞게 됩니다. 격자에 먼저 붙어버려서
// 카드 가장자리까지 갈 일이 없기 때문입니다.
//
// ── 이 파일은 카드가 뭔지 모릅니다 ──
// 네모(Rect)만 주고받습니다. board_view.dart와 같은 이유입니다. 덕분에
// 앱을 안 띄우고 숫자만으로 확인할 수 있습니다. (test/utils/board_snap_test.dart)


import 'dart:ui';

import '../theme/app_metrics.dart';

/// 스냅한 결과입니다. 얼마나 보정할지와, 안내선을 어디에 그릴지입니다.
class BoardSnapResult {
  const BoardSnapResult({this.offset = Offset.zero, this.guideX, this.guideY});

  /// 아무 데도 안 붙은 상태입니다.
  static const BoardSnapResult none = BoardSnapResult();

  /// 원래 자리에 이만큼 더하면 붙습니다. (0, 0)이면 안 붙은 것입니다.
  final Offset offset;

  /// 세로 안내선을 그릴 자리입니다(판 좌표 x). 안 붙었으면 null입니다.
  ///
  /// **격자에 붙었을 때도 null입니다.** 격자는 눈에 안 보이는 것이라
  /// 안내선을 그리면 "저 선은 뭐지?" 하게 됩니다. 카드끼리 붙었을 때만
  /// "이 카드에 맞췄다"를 보여줍니다.
  final double? guideX;

  /// 가로 안내선을 그릴 자리입니다(판 좌표 y).
  final double? guideY;
}

/// 한 축(가로 또는 세로)에서 붙일 자리를 찾은 결과입니다.
class _AxisSnap {
  const _AxisSnap(this.offset, this.guide);

  static const _AxisSnap none = _AxisSnap(0, null);

  final double offset;
  final double? guide;
}

/// 한 축에서 가장 가까운 붙을 자리를 찾습니다.
///
/// [points]는 **내 기준점들**입니다. 옮길 때는 왼쪽·가운데·오른쪽 셋을 넣고,
/// 크기를 바꿀 때는 오른쪽 하나만 넣습니다.
///
/// [candidates]는 붙을 수 있는 자리들입니다(다른 카드들의 가장자리·중심선).
///
/// [gridBase]는 격자에 맞출 때 기준이 되는 값입니다. 보통 내 왼쪽(또는 위)
/// 입니다. 격자는 [useGrid]가 참이고 **카드끼리 안 맞았을 때만** 씁니다.
_AxisSnap _snapAxis({
  required List<double> points,
  required List<double> candidates,
  required double gridBase,
  required bool useGrid,
}) {
  double? bestOffset;
  double bestDistance = boardSnapThreshold;
  double? guide;

  for (final double point in points) {
    for (final double candidate in candidates) {
      final double distance = (candidate - point).abs();

      if (distance < bestDistance) {
        bestDistance = distance;
        bestOffset = candidate - point;
        guide = candidate;
      }
    }
  }

  if (bestOffset != null) {
    return _AxisSnap(bestOffset, guide);
  }

  // 카드끼리 맞는 것이 없을 때만 격자를 봅니다.
  if (useGrid) {
    final double snapped = (gridBase / boardGridSize).round() * boardGridSize;

    if ((snapped - gridBase).abs() <= boardSnapThreshold) {
      // 격자에는 안내선을 안 그립니다. (guide가 null)
      return _AxisSnap(snapped - gridBase, null);
    }
  }

  return _AxisSnap.none;
}

/// 가로 방향으로 붙을 수 있는 자리들을 모읍니다.
///
/// 카드 하나마다 **왼쪽 / 가운데 / 오른쪽** 셋을 냅니다. 가운데를 넣어야
/// "가운데 맞추기"가 됩니다. 가장자리만 있으면 두 카드의 중심을 못 맞춥니다.
List<double> snapCandidatesX(List<Rect> others) {
  final List<double> candidates = <double>[];
  for (final Rect rect in others) {
    candidates.addAll(<double>[rect.left, rect.center.dx, rect.right]);
  }
  return candidates;
}

/// 세로 방향으로 붙을 수 있는 자리들을 모읍니다. (위 / 가운데 / 아래)
List<double> snapCandidatesY(List<Rect> others) {
  final List<double> candidates = <double>[];
  for (final Rect rect in others) {
    candidates.addAll(<double>[rect.top, rect.center.dy, rect.bottom]);
  }
  return candidates;
}

/// **옮기는 중인** 카드를 다른 카드에 붙입니다.
///
/// [moving]은 지금 끌고 있는 카드의 네모, [others]는 나머지 카드들입니다.
/// **자기 자신은 [others]에 넣지 마세요.** 자기한테 붙으면 안 움직입니다.
///
/// 가로·세로를 따로 봅니다. 그래야 "왼쪽만 맞고 위아래는 자유"가 됩니다.
BoardSnapResult snapMovingCard({
  required Rect moving,
  required List<Rect> others,
  required bool useGrid,
}) {
  final _AxisSnap x = _snapAxis(
    points: <double>[moving.left, moving.center.dx, moving.right],
    candidates: snapCandidatesX(others),
    gridBase: moving.left,
    useGrid: useGrid,
  );

  final _AxisSnap y = _snapAxis(
    points: <double>[moving.top, moving.center.dy, moving.bottom],
    candidates: snapCandidatesY(others),
    gridBase: moving.top,
    useGrid: useGrid,
  );

  return BoardSnapResult(
    offset: Offset(x.offset, y.offset),
    guideX: x.guide,
    guideY: y.guide,
  );
}

/// **크기를 바꾸는 중인** 카드의 오른쪽 모서리를 다른 카드에 붙입니다.
///
/// ── 왜 오른쪽만 보나 ──
/// 이 앱의 크기 조절은 **가로세로 비율을 고정**합니다. 세로는 가로를 따라
/// 정해지므로, 아래 모서리를 따로 붙이면 비율이 깨집니다. 사용자가 실제로
/// 끄는 것도 가로 방향이라, 오른쪽만 보는 편이 예측하기 쉽습니다.
///
/// 아래 모서리를 맞추고 싶을 때는 6번(정렬·분배 툴바)을 쓰게 됩니다.
///
/// 돌려주는 [BoardSnapResult.offset]의 dx는 **가로 크기에 더할 값**입니다.
/// 자리를 옮기는 값이 아닙니다. dy는 언제나 0입니다.
BoardSnapResult snapResizingCard({
  required Rect resizing,
  required List<Rect> others,
  required bool useGrid,
}) {
  final _AxisSnap x = _snapAxis(
    points: <double>[resizing.right],
    candidates: snapCandidatesX(others),
    gridBase: resizing.right,
    useGrid: useGrid,
  );

  return BoardSnapResult(offset: Offset(x.offset, 0), guideX: x.guide);
}
