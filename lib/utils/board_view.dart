// 무드보드를 **어떻게 보여줄 것인가**를 계산하는 함수들입니다. (확대·축소·이동)
//
// ── board_layout.dart와 무엇이 다른가 ──
//   board_layout.dart — 카드가 판의 **어디에 놓이는가** (사람이 옮기는 것)
//   이 파일           — 그 판을 **어느 배율로 어디를 보고 있는가** (보는 창)
//
// 카드를 옮겨도 보는 창은 그대로고, 확대해도 카드가 놓인 자리는 안 바뀝니다.
// 성격이 달라서 나눠뒀습니다. "카드가 엉뚱한 데 놓인다"와 "화면이 엉뚱한 데를
// 비춘다"를 각각 다른 파일에서 찾을 수 있습니다.
//
// 여기 있는 것도 전부 **순수한 함수**입니다. 앱을 안 띄우고 숫자만으로
// 확인할 수 있습니다. (test/utils/board_view_test.dart)

import 'dart:math';
import 'dart:ui';

import '../theme/app_metrics.dart';

// ── 화면 좌표와 판 좌표 ──
// 카드의 x, y는 **판 좌표**입니다. 판의 왼쪽 위가 (0, 0)이고, 확대해도 줄여도
// 안 바뀝니다. 화면에 실제로 그려지는 자리는 여기에 배율과 이동을 더해 구합니다.
//
//   화면 위치 = 이동(offset) + 판 위치 × 배율(scale)
//
// 이 한 줄만 붙잡고 있으면 아래 계산들이 전부 이 식을 뒤집은 것에 지나지 않습니다.

/// **카드 전부가 화면에 들어오는 배율**을 구합니다. (⛶ 버튼)
///
/// 가로·세로 중 **더 빡빡한 쪽**에 맞춰야 전부 들어옵니다.
///
/// ── 1보다 크게는 안 만듭니다 ──
/// 카드가 한 장뿐이면 계산상 5배 같은 값이 나오는데, 그러면 그림을 억지로
/// 늘리는 셈이라 흐려집니다. 그럴 때는 원래 크기로 두는 편이 낫습니다.
///
/// [bounds]는 카드들이 놓인 범위입니다(board_layout.dart의 boardContentBounds).
/// 비어 있으면 1배입니다 — 맞출 것이 없습니다.
double fitAllScale(Rect bounds, Size viewport) {
  if (bounds.width <= 0 || bounds.height <= 0) {
    return 1.0;
  }

  // 가장자리에 딱 붙으면 답답해서 조금 띄웁니다.
  final double usableWidth = max(1, viewport.width - fitAllPadding * 2);
  final double usableHeight = max(1, viewport.height - fitAllPadding * 2);

  final double byWidth = usableWidth / bounds.width;
  final double byHeight = usableHeight / bounds.height;

  return clampBoardScale(min(1.0, min(byWidth, byHeight)));
}

/// 카드 전부가 **화면 가운데** 오도록 하는 이동값을 구합니다. (⛶ 버튼)
///
/// 배율은 [fitAllScale]로 따로 구해서 넘겨줍니다. 둘을 한 함수에서 같이
/// 돌려주면 "배율만 알고 싶을 때"도 이동까지 계산하게 됩니다.
Offset fitAllOffset(Rect bounds, Size viewport, double scale) {
  if (bounds.width <= 0 || bounds.height <= 0) {
    return Offset.zero;
  }

  // 맨 위 식(화면 = 이동 + 판×배율)을 뒤집습니다.
  // 범위의 한가운데가 화면 한가운데에 오려면 이동값이 얼마여야 하는가.
  return Offset(
    viewport.width / 2 - bounds.center.dx * scale,
    viewport.height / 2 - bounds.center.dy * scale,
  );
}

/// 배율이 너무 작거나 크지 않도록 붙잡아둡니다.
///
/// 전에는 "판 전체가 보이는 배율"이 최솟값이었습니다. 판에 끝이 없어져서
/// 그 기준이 사라졌으므로 이제는 정해둔 숫자를 씁니다.
/// (app_metrics.dart의 minBoardScale)
double clampBoardScale(double scale) {
  return scale.clamp(minBoardScale, maxBoardScale);
}

/// 판이 화면 밖으로 **완전히** 밀려나지 않도록 이동값을 붙잡아둡니다.
///
/// ── 전과 무엇이 다른가 ──
/// 전에는 "판이 화면보다 작으면 가운데에 고정"이었습니다. 그래서 판이 다
/// 보이는 동안에는 **빈 곳을 끌어도 아무 일이 안 일어났습니다.**
///
/// 이제는 가운데로 잡아끌지 않습니다. **카드가 놓인 범위가 화면에 조금이라도
/// 걸쳐 있기만** 하면 어디로든 옮길 수 있습니다. 자유롭게 움직이면서도
/// 빈 우주로 날아가 카드를 잃어버리지는 않습니다.
///
/// [content]는 카드들이 놓인 범위(판 좌표)입니다. 비어 있으면 붙잡지
/// 않습니다 — 잡아둘 카드가 없습니다.
Offset clampCanvasOffset(
  Offset offset,
  double scale,
  Size viewport,
  Rect content,
) {
  if (content.width <= 0 || content.height <= 0) {
    return offset;
  }

  return Offset(
    _clampAxis(
      offset.dx,
      content.left * scale,
      content.right * scale,
      viewport.width,
    ),
    _clampAxis(
      offset.dy,
      content.top * scale,
      content.bottom * scale,
      viewport.height,
    ),
  );
}

/// 한 축(가로 또는 세로)의 이동값을 붙잡습니다. clampCanvasOffset이 씁니다.
///
/// [scaledStart]와 [scaledEnd]는 카드 범위의 양 끝을 배율까지 곱한 값입니다.
/// 이 범위가 화면 안에 [canvasKeepVisible]만큼은 남아 있게 합니다.
double _clampAxis(
  double value,
  double scaledStart,
  double scaledEnd,
  double viewportSize,
) {
  // 범위의 끝이 화면 왼쪽(위쪽)에서 이만큼은 안쪽에 있어야 합니다.
  final double lowest = canvasKeepVisible - scaledEnd;

  // 범위의 시작이 화면 오른쪽(아래쪽)에서 이만큼은 안쪽에 있어야 합니다.
  final double highest = viewportSize - canvasKeepVisible - scaledStart;

  // 화면보다 범위가 아주 작으면 두 값이 뒤집힐 수 있습니다.
  // 그대로 두면 clamp가 "최솟값이 최댓값보다 크다"며 오류를 냅니다.
  if (lowest > highest) {
    return value;
  }

  return value.clamp(lowest, highest);
}

/// **손가락(마우스) 밑에 있던 지점이 그대로 있도록** 확대·축소한 뒤의 이동값을 구합니다.
///
/// ── 왜 이런 계산이 필요한가 ──
/// 그냥 배율만 바꾸면 판이 왼쪽 위를 기준으로 커집니다. 그러면 확대할 때마다
/// 보고 있던 곳이 화면 밖으로 밀려나서, 확대하고 다시 찾아가고를 반복하게 됩니다.
///
/// 가리키고 있는 곳을 붙잡아두면 "그 자리를 확대한다"가 되어 훨씬 자연스럽습니다.
///
/// [focalPoint]는 **화면 좌표**입니다. 마우스 커서 자리나, 버튼으로 확대할 때는
/// 화면 한가운데를 넘기면 됩니다.
Offset zoomAroundPoint({
  required Offset focalPoint,
  required Offset offset,
  required double fromScale,
  required double toScale,
}) {
  // 맨 위 식(화면 = 이동 + 판×배율)을 뒤집어, 지금 손가락 밑에 있는
  // **판 좌표**를 먼저 구합니다.
  final Offset boardPoint = (focalPoint - offset) / fromScale;

  // 그 판 좌표가 새 배율에서도 같은 화면 자리에 오도록 이동값을 되맞춥니다.
  return focalPoint - boardPoint * toScale;
}

