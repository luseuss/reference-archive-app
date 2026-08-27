// 무드보드에서 "카드를 판의 어디에 둘 것인가"를 계산하는 함수들입니다.
//
// ── 왜 화면 파일에서 빼냈나 ──
// 이 계산들은 화면 없이도 맞는지 확인할 수 있는 순수한 셈입니다. 화면 코드 안에
// 섞여 있으면 확인하려고 매번 앱을 띄우고 카드를 끌어봐야 하지만, 이렇게 빼두면
// 테스트로 숫자만 맞춰볼 수 있습니다. (test/utils/board_layout_test.dart)
//
// 순수한 함수 = 같은 값을 넣으면 언제나 같은 값이 나오고, 바깥의 무엇도 건드리지 않는 함수.

import 'dart:math';
import 'dart:ui';

import '../models/board.dart';
import '../theme/app_metrics.dart';

/// 카드의 세로 크기를 **어림잡아** 돌려줍니다.
///
/// ── 왜 어림잡나 (정확한 값을 못 구하나) ──
/// 무드보드 카드의 높이는 그림의 원본 비율이 정합니다(사진을 잘라내지 않으려고).
/// 그런데 그림의 비율은 파일을 다 읽어봐야 알 수 있고, 그 전에는 알 수 없습니다.
///
/// 이 값이 필요한 이유는 딱 하나, **카드를 판 밖으로 끌어내지 못하게 막기 위해서**
/// 입니다. 그 용도라면 어림값으로 충분합니다. 조금 넉넉하게 잡아두면 실제 카드가
/// 더 길더라도 윗부분은 반드시 판 안에 남아서 다시 잡을 수 있습니다.
///
/// [BoardCard.height]에 값이 들어있으면(직접 크기를 조절한 카드) 그건 정확한 값이라
/// 그대로 씁니다.
double estimatedBoardCardHeight(BoardCard card) {
  final double? exactHeight = card.height;
  if (exactHeight != null) {
    return exactHeight;
  }

  // 4:3 그림 + 아래 여유. 세로 사진은 이보다 길지만, 위에서 설명한 대로
  // 넉넉히 잡는 쪽이 안전합니다.
  return card.width * 3 / 4;
}

/// 카드가 판 밖으로 나가지 않도록 위치를 판 안쪽으로 끌어당깁니다.
///
/// ── 왜 막나 ──
/// 막지 않으면 카드를 판 바깥으로 끌어다 놓을 수 있습니다. 판 바깥은 화면에
/// 그려지지 않는 자리라, **눈에 안 보이는데 지울 수도 없는 상태**가 됩니다.
/// 사용자 입장에서는 사진이 사라진 것과 같습니다.
Offset clampToBoard(double x, double y, BoardCard card) {
  // max(0, ...)로 한 번 더 감싸는 이유: 카드가 판보다 큰 극단적인 경우
  // 최댓값이 음수가 되어 clamp가 "최솟값이 최댓값보다 크다"며 오류를 냅니다.
  final double maxX = max(0, boardWidth - card.width);
  final double maxY = max(0, boardHeight - estimatedBoardCardHeight(card));

  return Offset(x.clamp(0, maxX), y.clamp(0, maxY));
}

/// 판에 새로 올리는 [index]번째 카드를 어디에 둘지 정해 돌려줍니다.
///
/// 왼쪽 위에서 시작해 오른쪽으로 늘어놓고, 한 줄이 차면 아래 줄로 넘어갑니다.
///
/// ── 빈자리를 찾아주지 않는 이유 ──
/// 이미 옮겨둔 카드와 겹칠 수 있습니다. "빈 곳을 찾아 넣기"를 하려면 놓인
/// 카드를 전부 살펴봐야 하는데, 카드가 늘수록 느려지고 결과도 사용자가
/// 예측하기 어렵습니다. 겹치면 끌어서 옮기면 되는 일이라, 늘 같은 자리에서
/// 시작하는 단순한 규칙이 낫습니다.
Offset initialCardPosition(int index) {
  final double step = defaultBoardCardWidth + boardPlacementSpacing;

  // 한 줄에 몇 장이 들어가는지 셉니다. 최소 1장은 보장합니다.
  final int columns = max(
    1,
    ((boardWidth - boardPlacementMargin * 2 + boardPlacementSpacing) / step)
        .floor(),
  );

  final int column = index % columns;
  final int row = index ~/ columns;

  // 줄 간격은 어림 높이를 씁니다. 위의 estimatedBoardCardHeight와 같은 사정입니다.
  final double rowStep = defaultBoardCardWidth * 3 / 4 + boardPlacementSpacing;

  return Offset(
    boardPlacementMargin + column * step,
    boardPlacementMargin + row * rowStep,
  );
}

// ── 여기서부터는 줌·팬(확대·이동) 계산입니다 (4단계 2번) ──
//
// ── 화면 좌표와 판 좌표 ──
// 카드의 x, y는 **판 좌표**입니다. 판의 왼쪽 위가 (0, 0)이고, 확대해도 줄여도
// 안 바뀝니다. 화면에 실제로 그려지는 자리는 여기에 배율과 이동을 더해 구합니다.
//
//   화면 위치 = 이동(offset) + 판 위치 × 배율(scale)
//
// 이 한 줄만 붙잡고 있으면 아래 계산들이 전부 이 식을 뒤집은 것에 지나지 않습니다.

/// 판 전체가 화면에 딱 들어오는 배율을 구합니다.
///
/// 가로·세로 중 **더 빡빡한 쪽**에 맞춰야 판이 통째로 들어옵니다.
///
/// ── 1보다 크게는 안 만듭니다 ──
/// 화면이 판보다 크면 계산상 1.2배 같은 값이 나오는데, 그러면 그림을 억지로
/// 늘리는 셈이라 흐려집니다. 그럴 때는 원래 크기로 가운데에 두는 편이 낫습니다.
double fitBoardScale(Size viewport) {
  final double byWidth = viewport.width / boardWidth;
  final double byHeight = viewport.height / boardHeight;

  return min(1.0, min(byWidth, byHeight));
}

/// 배율이 너무 작거나 크지 않도록 붙잡아둡니다.
///
/// 가장 작은 값은 "판 전체가 보이는 배율"입니다. 그보다 더 줄이면 판 주위의
/// 빈 공간만 넓어질 뿐 보이는 것이 늘지 않습니다.
double clampBoardScale(double scale, Size viewport) {
  final double smallest = fitBoardScale(viewport);

  // 화면이 아주 작으면 smallest가 maxBoardScale보다 클 수도 있습니다.
  // 그대로 두면 clamp가 "최솟값이 최댓값보다 크다"며 오류를 냅니다.
  final double largest = max(smallest, maxBoardScale);

  return scale.clamp(smallest, largest);
}

/// 판이 화면 밖으로 너무 밀려나지 않도록 이동값을 붙잡아둡니다.
///
/// 두 경우로 나뉩니다.
///   - 판이 화면보다 **작으면** → 가운데에 둡니다. 구석에 치우쳐 있으면 어색합니다.
///   - 판이 화면보다 **크면** → 가장자리 밖으로는 못 밀게 합니다. 안 막으면
///     판을 화면 밖으로 완전히 밀어내고 빈 화면만 보게 됩니다.
Offset clampBoardOffset(Offset offset, double scale, Size viewport) {
  return Offset(
    _clampAxis(offset.dx, boardWidth * scale, viewport.width),
    _clampAxis(offset.dy, boardHeight * scale, viewport.height),
  );
}

/// 한 축(가로 또는 세로)의 이동값을 붙잡습니다. clampBoardOffset이 씁니다.
double _clampAxis(double value, double scaledSize, double viewportSize) {
  if (scaledSize <= viewportSize) {
    // 남는 공간을 양쪽에 똑같이 나눠 가운데에 둡니다.
    return (viewportSize - scaledSize) / 2;
  }

  // 0 = 판의 왼쪽(위쪽) 끝이 화면 끝에 붙은 상태.
  // viewportSize - scaledSize = 판의 오른쪽(아래쪽) 끝이 화면 끝에 붙은 상태.
  return value.clamp(viewportSize - scaledSize, 0.0);
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

/// 크기 조절 중인 카드의 가로 크기를 붙잡아둡니다.
///
/// 두 가지를 함께 봅니다.
///   1. 너무 작거나 크지 않게 (minBoardCardWidth ~ maxBoardCardWidth)
///   2. **판 오른쪽 끝을 넘지 않게** — 넘어가면 카드의 일부가 판 밖으로 나가서
///      보이지 않게 됩니다. 카드를 옮길 때 막는 것과 같은 이유입니다.
///
/// [cardX]는 카드의 왼쪽 끝 위치입니다. 크기를 키울 때 왼쪽 위는 그대로 두고
/// 오른쪽 아래로만 늘어나므로, 남은 자리는 여기서부터 판 끝까지입니다.
double clampResizedCardWidth(double width, double cardX) {
  // 판 끝에 바짝 붙은 카드는 남은 자리가 최소 크기보다 작을 수 있습니다.
  // 그대로 두면 clamp가 "최솟값이 최댓값보다 크다"며 오류를 냅니다.
  final double room = max(minBoardCardWidth, boardWidth - cardX);

  return width.clamp(minBoardCardWidth, min(maxBoardCardWidth, room));
}
