// 판 위의 카드 목록을 "옮기고, 크기를 바꾸고, 맨 위로 올리는" 규칙입니다.
//
// ── 왜 화면 파일에서 빼냈나 ──
// board_layout.dart를 빼둔 것과 같은 이유입니다. 이 규칙들은 화면 없이도 맞는지
// 확인할 수 있습니다. 화면 코드에 섞여 있으면 "카드를 잡으면 맨 위로 오는가"를
// 확인하려고 매번 앱을 띄우고 카드를 끌어봐야 합니다.
//
// ── 목록을 고치지 않고 새 목록을 돌려줍니다 ──
// 받은 목록을 직접 뜯어고치면, 부른 쪽에서 "언제 바뀐 거지?" 하고 헤매게 됩니다.
// 여기서는 **바뀐 사본**을 만들어 돌려주고, 화면이 그것으로 갈아끼웁니다.
// 이 앱의 모델들이 copyWith로 사본을 만드는 것과 같은 방식입니다.

import 'dart:ui';

import '../models/board.dart';
import 'board_layout.dart';

/// 목록에서 이 번호를 가진 카드가 몇 번째인지 찾습니다. 없으면 -1입니다.
int indexOfCard(List<BoardCard> cards, String cardId) {
  return cards.indexWhere((BoardCard card) => card.id == cardId);
}

/// 판에서 가장 위에 있는 카드의 zOrder를 돌려줍니다. 카드가 없으면 0입니다.
///
/// 데이터베이스에 묻지 않고 손에 든 목록에서 셉니다. 카드를 잡을 때마다
/// 물어보면 끄는 동작이 시작될 때마다 잠깐씩 걸립니다.
int topZOrderOf(List<BoardCard> cards) {
  int top = 0;
  for (final BoardCard card in cards) {
    if (card.zOrder > top) {
      top = card.zOrder;
    }
  }
  return top;
}

/// 이 카드를 맨 위로 올린 새 목록을 돌려줍니다.
///
/// ── 왜 필요한가 ──
/// 아래 깔린 카드를 꺼내려고 끌었는데 여전히 다른 카드에 덮인 채 따라오면,
/// 무엇을 잡았는지 보이지 않습니다.
///
/// 두 가지를 함께 합니다.
///   1. zOrder를 가장 큰 값보다 하나 크게 (저장되는 겹침 순서)
///   2. 목록의 맨 뒤로 옮기기 (지금 화면에서의 겹침 순서)
///
/// 2번이 필요한 이유: 화면은 목록 순서대로 겹쳐 그립니다. zOrder만 바꾸면
/// **다시 읽어올 때까지** 화면에서는 그대로 깔려 있습니다.
List<BoardCard> raiseCardToTop(List<BoardCard> cards, String cardId) {
  final int index = indexOfCard(cards, cardId);
  if (index == -1) {
    return cards;
  }

  final BoardCard raised = cards[index].copyWith(
    zOrder: topZOrderOf(cards) + 1,
  );

  return <BoardCard>[
    ...cards.sublist(0, index),
    ...cards.sublist(index + 1),
    raised,
  ];
}

/// 이 카드를 [delta]만큼 옮긴 새 목록을 돌려줍니다.
///
/// **어느 쪽으로도 붙잡지 않습니다.** 판에 사방으로 끝이 없습니다.
///
/// 음수 자리도 괜찮습니다. 그리는 자리가 카드를 따라 움직여서 클릭이
/// 계속 닿습니다. (board_layout.dart의 boardCanvasRect 설명 참고)
List<BoardCard> moveCard(
  List<BoardCard> cards,
  String cardId,
  Offset delta,
) {
  final int index = indexOfCard(cards, cardId);
  if (index == -1) {
    return cards;
  }

  final BoardCard current = cards[index];

  return <BoardCard>[
    ...cards.sublist(0, index),
    current.copyWith(x: current.x + delta.dx, y: current.y + delta.dy),
    ...cards.sublist(index + 1),
  ];
}

/// 이 카드의 크기를 바꾼 새 목록을 돌려줍니다.
///
/// [startSize]는 **손잡이를 잡던 순간** 카드가 실제로 그려져 있던 크기이고,
/// [movedSoFar]는 그 뒤로 지금까지 끈 거리의 합입니다.
///
/// ── 매번 처음 크기부터 다시 계산하는 이유 ──
/// 매 순간의 움직임을 카드 크기에 바로바로 더하면, 조금씩 어긋난 값이 쌓여서
/// 손가락과 카드 모서리가 점점 벌어집니다. "처음 크기 + 지금까지의 합"으로
/// 매번 새로 구하면 어긋날 일이 없습니다.
///
/// ── 가로세로 비율을 고정합니다 ──
/// 가로만 늘리고 세로는 그대로 두면 그림이 찌그러집니다. 무드보드는 **그림을
/// 있는 그대로 보려고** 만든 판이라, 찌그러진 그림이 놓이면 판을 만든 이유가
/// 없어집니다. 그래서 가로를 얼마나 끌었든 세로는 처음 비율대로 따라갑니다.
///
/// 세로로 끈 거리(`movedSoFar.dy`)는 일부러 안 씁니다. 가로세로를 함께 보면
/// 어느 쪽을 따를지 정해야 하는데, 어느 쪽으로 정해도 다른 쪽으로 끌 때
/// 손가락과 모서리가 어긋납니다. 가로 하나만 보는 편이 훨씬 예측하기 쉽습니다.
List<BoardCard> resizeCard(
  List<BoardCard> cards,
  String cardId, {
  required Size startSize,
  required Offset movedSoFar,
}) {
  final int index = indexOfCard(cards, cardId);

  // 가로가 0이면 비율을 구할 수 없습니다(0으로 나누게 됩니다).
  // 그림이 아직 안 읽혀서 크기를 못 잰 경우입니다.
  if (index == -1 || startSize.width <= 0) {
    return cards;
  }

  final BoardCard current = cards[index];

  // 세로 ÷ 가로. 크기를 바꾸는 내내 이 비율을 그대로 지킵니다.
  final double heightPerWidth = startSize.height / startSize.width;

  // 가로를 먼저 정하고 세로는 비율대로 따라갑니다.
  // 판에 끝이 없어서 이제 최소·최대 크기만 봅니다.
  // (자세한 이유는 board_layout.dart의 clampResizedCardWidth 설명을 보세요)
  final double width = clampResizedCardWidth(startSize.width + movedSoFar.dx);

  final double height = width * heightPerWidth;

  return <BoardCard>[
    ...cards.sublist(0, index),
    current.copyWith(width: width, height: height),
    ...cards.sublist(index + 1),
  ];
}
