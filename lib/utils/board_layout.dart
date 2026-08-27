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

/// 카드 한 장이 차지하는 네모를 돌려줍니다.
Rect boardCardRect(BoardCard card) {
  return Rect.fromLTWH(
    card.x,
    card.y,
    card.width,
    estimatedBoardCardHeight(card),
  );
}

/// **카드들이 놓인 범위**를 돌려줍니다.
///
/// 판에 끝이 없어졌기 때문에(4단계 3번), "판 전체"라는 것이 없습니다.
/// 대신 지금 놓인 카드들을 전부 감싸는 네모를 그때그때 구해서 씁니다.
/// ⛶ 버튼이 이 범위에 화면을 맞춥니다.
///
/// 카드가 하나도 없으면 **빈 네모(0 크기)**를 돌려줍니다. 부르는 쪽에서
/// "비어 있으면 이렇게 하자"를 정하게 두는 편이, 여기서 억지로 기본값을
/// 지어내는 것보다 헷갈리지 않습니다.
Rect boardContentBounds(List<BoardCard> cards) {
  if (cards.isEmpty) {
    return Rect.zero;
  }

  Rect bounds = boardCardRect(cards.first);
  for (final BoardCard card in cards.skip(1)) {
    bounds = bounds.expandToInclude(boardCardRect(card));
  }
  return bounds;
}

/// 카드를 그릴 **자리**를 돌려줍니다. (판 좌표 기준의 네모)
///
/// ── 이 함수가 사방 무한을 가능하게 합니다 ──
/// 카드의 x, y는 **음수여도 됩니다.** 그런데 Flutter는 상자 **바깥**의 클릭을
/// 자식에게 안 내려보내기 때문에, 상자를 (0, 0)에 고정해두면 음수 자리에 놓인
/// 카드가 **화면에 보이는데도 안 잡힙니다.** PR #18에서 손잡이가 판 밖으로
/// 나갔을 때 실제로 겪은 문제입니다.
///
/// 그래서 상자를 고정하지 않고 **카드를 따라 움직이게** 합니다. 카드가 왼쪽
/// 위로 가면 상자의 시작점도 함께 왼쪽 위로 갑니다. 상자 안에서 보면 모든
/// 카드가 0 이상이라 클릭이 정상적으로 닿습니다.
///
/// ── 상자가 움직여도 화면은 안 흔들립니다 ──
/// 그리는 쪽에서 이렇게 계산하기 때문입니다.
///
///   화면 위치 = 이동 + 원점×배율 + (카드 − 원점)×배율
///             = 이동 + 카드×배율          ← 원점이 사라집니다
///
/// 원점이 얼마든 카드의 화면 위치는 같습니다. 그래서 한 장을 왼쪽으로 끌어도
/// 나머지 카드가 밀려 보이지 않습니다.
/// (board_viewport.dart와 board_canvas.dart가 이 식을 나눠 맡습니다)
///
/// ── 사방으로 여유를 둡니다 ──
/// 카드가 상자 끝에 딱 붙어 있으면 그쪽으로 더 밀 자리가 없습니다.
/// 어느 방향으로든 계속 끌 수 있도록 둘레에 [canvasBreathingRoom]을 둡니다.
Rect boardCanvasRect(List<BoardCard> cards) {
  final Rect bounds = boardContentBounds(cards);

  // 카드가 없으면 기본 크기의 자리를 왼쪽 위에 둡니다.
  if (bounds.isEmpty) {
    return const Rect.fromLTWH(0, 0, minCanvasWidth, minCanvasHeight);
  }

  return bounds.inflate(canvasBreathingRoom);
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
    ((boardPlacementRowWidth -
                boardPlacementMargin * 2 +
                boardPlacementSpacing) /
            step)
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

/// 크기 조절 중인 카드의 가로 크기를 붙잡아둡니다.
///
/// ── 판 끝을 안 보게 됐습니다 (4단계 3번) ──
/// 전에는 판의 오른쪽·아래 끝을 넘지 않게 막았습니다. 안 막으면 카드가 판
/// 밖으로 나가면서 **오른쪽 아래에 있는 크기 조절 손잡이도 같이 나가서,
/// 다시 잡아 줄일 수가 없었습니다.**
///
/// 이제 판에 끝이 없으므로 떨어져 나갈 곳이 없습니다. 남는 것은 최소·최대
/// 크기뿐입니다. 아주 크게 키워서 화면 밖으로 나가더라도 축소하거나 ⛶를
/// 누르면 다시 보입니다.
double clampResizedCardWidth(double width) {
  return width.clamp(minBoardCardWidth, maxBoardCardWidth);
}
