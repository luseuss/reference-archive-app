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
