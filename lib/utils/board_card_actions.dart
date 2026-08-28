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
import 'board_snap.dart';

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

/// 카드를 옮기거나 크기를 바꾼 결과입니다.
///
/// ── 왜 목록만 돌려주지 않나 ──
/// 스냅이 붙었을 때 **어디에 붙었는지**를 화면이 알아야 안내선을 그립니다.
/// 목록만 돌려주면 "붙었는지 아닌지"를 화면에서 다시 계산해야 하고,
/// 그러면 규칙이 두 군데로 갈라집니다.
class BoardCardsUpdate {
  const BoardCardsUpdate(this.cards, {this.guideX, this.guideY});

  /// 바뀐 카드 목록입니다.
  final List<BoardCard> cards;

  /// 세로 안내선을 그릴 자리입니다(판 좌표 x). 안 붙었으면 null입니다.
  final double? guideX;

  /// 가로 안내선을 그릴 자리입니다(판 좌표 y). 안 붙었으면 null입니다.
  final double? guideY;
}

/// 이 카드를 [delta]만큼 옮긴 결과를 돌려줍니다.
///
/// [cardId] 한 장만 옮깁니다. 여러 장을 함께 끄는 중이면 [moveCards]를
/// 쓰세요. 이 함수는 `moveCards(cards, <String>[cardId], primaryId: cardId, ...)`
/// 를 부르는 것과 같습니다 — 한 장짜리 특별한 경우일 뿐입니다.
BoardCardsUpdate moveCard(
  List<BoardCard> cards,
  String cardId,
  Offset delta, {
  bool snap = true,
  bool useGrid = false,

  /// 화면에 그려진 카드들이 재서 알려준 실제 높이입니다.
  /// 스냅이 눈에 보이는 자리에 붙으려면 이게 있어야 합니다.
  /// (board_layout.dart의 boardCardHeight 설명 참고)
  Map<String, double> measuredHeights = const <String, double>{},
}) {
  return moveCards(
    cards,
    <String>[cardId],
    primaryId: cardId,
    delta: delta,
    snap: snap,
    useGrid: useGrid,
    measuredHeights: measuredHeights,
  );
}

/// [ids]에 든 카드들을 함께 [delta]만큼 옮긴 결과를 돌려줍니다.
///
/// ── 왜 필요한가 (5단계 마퀴 다중선택) ──
/// 여러 장을 골라 함께 끌 때, 각 카드를 따로따로 옮기면 서로 다른 카드에
/// 스냅되어 **골라둔 카드들끼리 흩어집니다.** 그래서 [primaryId] 카드
/// 하나만 스냅을 계산하고, 나머지는 **정확히 같은 보정값**만큼 따라갑니다.
/// 기존 웹앱도 같은 방식이었습니다.
///
/// **어느 쪽으로도 붙잡지 않습니다.** 판에 사방으로 끝이 없습니다(PR #22).
/// 음수 자리도 괜찮습니다. 그리는 자리가 카드를 따라 움직여서 클릭이
/// 계속 닿습니다. (board_layout.dart의 boardCanvasRect 설명 참고)
///
/// 같은 delta를 묶음 전체에 그대로 더하기만 하므로, 붙잡는 규칙이 없어도
/// 묶음 안 카드들의 상대 위치는 저절로 지켜집니다.
///
/// [snap]이 참이면 다른 카드에 착 붙습니다. 평소에는 거짓이고, 사용자가
/// Alt를 누르고 있을 때만 참으로 넘어옵니다.
///
/// [useGrid]는 격자 스냅입니다. **카드끼리 안 맞았을 때만** 쓰입니다.
/// (board_snap.dart 설명 참고)
BoardCardsUpdate moveCards(
  List<BoardCard> cards,
  List<String> ids, {
  required String primaryId,
  required Offset delta,
  bool snap = true,
  bool useGrid = false,
  Map<String, double> measuredHeights = const <String, double>{},
}) {
  if (ids.isEmpty || indexOfCard(cards, primaryId) == -1) {
    return BoardCardsUpdate(cards);
  }

  final Set<String> idSet = ids.toSet();

  // 먼저 손이 움직인 만큼 전부 그대로 옮깁니다. 같은 delta를 더하기만
  // 하므로 이 시점에서 묶음의 상대 위치는 그대로 유지됩니다.
  final Map<String, BoardCard> moved = <String, BoardCard>{
    for (final BoardCard card in cards)
      if (idSet.contains(card.id))
        card.id: card.copyWith(x: card.x + delta.dx, y: card.y + delta.dy),
  };

  double? guideX;
  double? guideY;

  if (snap) {
    final BoardCard? primary = moved[primaryId];

    if (primary != null) {
      final BoardSnapResult result = snapMovingCard(
        moving: boardCardRect(primary, measuredHeights: measuredHeights),
        // 묶음 전체를 후보에서 빼야 합니다. 안 빼면 묶음 안의 카드끼리
        // 서로 스냅되어 상대 위치가 틀어집니다.
        others: _rectsExcludingIds(cards, idSet, measuredHeights),
        useGrid: useGrid,
      );

      guideX = result.guideX;
      guideY = result.guideY;

      if (result.offset != Offset.zero) {
        moved.updateAll(
          (String id, BoardCard card) => card.copyWith(
            x: card.x + result.offset.dx,
            y: card.y + result.offset.dy,
          ),
        );
      }
    }
  }

  return BoardCardsUpdate(
    <BoardCard>[
      for (final BoardCard card in cards) moved[card.id] ?? card,
    ],
    guideX: guideX,
    guideY: guideY,
  );
}

/// 카드 크기 조절 손잡이가 **어느 모서리**에 있는지입니다.
///
/// 손잡이를 잡은 모서리의 **반대쪽 모서리는 고정된 채** 크기가 바뀝니다.
/// 오른쪽 아래를 끌면 왼쪽 위가, 왼쪽 위를 끌면 오른쪽 아래가 그 자리에
/// 그대로 남습니다.
enum BoardResizeCorner {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight;

  /// 이 손잡이가 카드의 **왼쪽**에 있는지 여부입니다.
  bool get isLeft => this == topLeft || this == bottomLeft;

  /// 이 손잡이가 카드의 **위쪽**에 있는지 여부입니다.
  bool get isTop => this == topLeft || this == topRight;
}

/// 이 카드의 크기를 바꾼 결과를 돌려줍니다.
///
/// [startSize]와 [startPosition]은 **손잡이를 잡던 순간** 카드가 실제로
/// 그려져 있던 크기·자리이고, [movedSoFar]는 그 뒤로 지금까지 끈 거리의
/// 합입니다. [corner]는 어느 손잡이를 잡았는지입니다.
///
/// ── 매번 처음 크기·자리부터 다시 계산하는 이유 ──
/// 매 순간의 움직임을 카드에 바로바로 더하면, 조금씩 어긋난 값이 쌓여서
/// 손가락과 카드 모서리가 점점 벌어집니다. "처음 값 + 지금까지의 합"으로
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
/// 왼쪽 손잡이는 왼쪽으로 끌수록(가로가 줄수록) 커지므로, 그쪽은 부호를
/// 뒤집어서 씁니다.
///
/// ── 반대쪽 모서리를 고정합니다 ──
/// [corner]의 반대쪽 모서리(가만히 있어야 할 쪽)를 [startSize]와
/// [startPosition]에서 구해두고, 크기가 정해지면 그 반대쪽 모서리를
/// 기준으로 [corner] 쪽 자리를 다시 계산합니다.
///
/// 스냅은 [corner]가 있는 쪽(왼쪽 손잡이면 왼쪽 모서리, 오른쪽 손잡이면
/// 오른쪽 모서리)만 봅니다. 세로가 비율을 따라오기 때문입니다.
/// (board_snap.dart의 snapResizingCard 설명 참고)
BoardCardsUpdate resizeCard(
  List<BoardCard> cards,
  String cardId, {
  required Size startSize,
  required Offset startPosition,
  required BoardResizeCorner corner,
  required Offset movedSoFar,
  bool snap = true,
  bool useGrid = false,

  /// 화면에 그려진 카드들이 재서 알려준 실제 높이입니다.
  /// 스냅이 눈에 보이는 자리에 붙으려면 이게 있어야 합니다.
  /// (board_layout.dart의 boardCardHeight 설명 참고)
  Map<String, double> measuredHeights = const <String, double>{},
}) {
  final int index = indexOfCard(cards, cardId);

  // 가로가 0이면 비율을 구할 수 없습니다(0으로 나누게 됩니다).
  // 그림이 아직 안 읽혀서 크기를 못 잰 경우입니다.
  if (index == -1 || startSize.width <= 0) {
    return BoardCardsUpdate(cards);
  }

  final BoardCard current = cards[index];

  // 세로 ÷ 가로. 크기를 바꾸는 내내 이 비율을 그대로 지킵니다.
  final double heightPerWidth = startSize.height / startSize.width;

  // 고정돼야 할 반대쪽 모서리의 판 좌표입니다. 예를 들어 오른쪽 아래
  // 손잡이를 잡았으면 반대쪽인 왼쪽 위(startPosition)가 그대로 고정됩니다.
  final double anchorX = corner.isLeft
      ? startPosition.dx + startSize.width // 반대쪽(오른쪽) 모서리
      : startPosition.dx; // 반대쪽(왼쪽) 모서리
  final double anchorY = corner.isTop
      ? startPosition.dy + startSize.height // 반대쪽(아래) 모서리
      : startPosition.dy; // 반대쪽(위) 모서리

  // 가로를 먼저 정하고 세로는 비율대로 따라갑니다.
  // 왼쪽 손잡이는 왼쪽으로 끌수록(dx가 음수일수록) 커지므로 부호를 뒤집습니다.
  // 판에 끝이 없어서 이제 최소·최대 크기만 봅니다.
  // (자세한 이유는 board_layout.dart의 clampResizedCardWidth 설명을 보세요)
  final double rawWidth = corner.isLeft
      ? startSize.width - movedSoFar.dx
      : startSize.width + movedSoFar.dx;
  double width = clampResizedCardWidth(rawWidth);

  double? guideX;

  if (snap) {
    // 지금 손잡이가 있는 자리(움직이는 모서리)를 구해서 스냅 후보와 견줍니다.
    final double movingEdgeX = corner.isLeft ? anchorX - width : anchorX + width;
    final double movingEdgeY = corner.isTop
        ? anchorY - width * heightPerWidth
        : anchorY;

    final BoardSnapResult result = snapResizingCard(
      resizing: Rect.fromLTWH(
        corner.isLeft ? movingEdgeX : anchorX,
        corner.isTop ? movingEdgeY : anchorY,
        width,
        width * heightPerWidth,
      ),
      others: _rectsExcept(cards, cardId, measuredHeights),
      useGrid: useGrid,
      onLeftEdge: corner.isLeft,
    );

    // snapResizingCard가 돌려주는 offset.dx는 "그 모서리를 얼마나 밀어야
    // 하는지"입니다. 오른쪽 모서리가 밀리면 그만큼 넓어지고, 왼쪽 모서리가
    // 밀리면 그만큼 좁아집니다(반대 부호). (board_snap.dart 설명 참고)
    final double widthOffset = corner.isLeft
        ? -result.offset.dx
        : result.offset.dx;
    width = clampResizedCardWidth(width + widthOffset);
    guideX = result.guideX;
  }

  final double height = width * heightPerWidth;

  // 반대쪽 모서리는 그대로 두고, 손잡이 쪽 모서리 위치를 새 크기로 다시 구합니다.
  final double x = corner.isLeft ? anchorX - width : anchorX;
  final double y = corner.isTop ? anchorY - height : anchorY;

  return BoardCardsUpdate(
    <BoardCard>[
      ...cards.sublist(0, index),
      current.copyWith(x: x, y: y, width: width, height: height),
      ...cards.sublist(index + 1),
    ],
    guideX: guideX,
  );
}

/// 이 카드를 뺀 나머지 카드들의 네모를 모읍니다. 스냅 후보로 씁니다.
List<Rect> _rectsExcept(
  List<BoardCard> cards,
  String cardId,
  Map<String, double> measuredHeights,
) {
  return _rectsExcludingIds(cards, <String>{cardId}, measuredHeights);
}

/// [excludeIds]에 든 카드들을 뺀 나머지의 네모를 모읍니다. 스냅 후보로 씁니다.
List<Rect> _rectsExcludingIds(
  List<BoardCard> cards,
  Set<String> excludeIds,
  Map<String, double> measuredHeights,
) {
  final List<Rect> rects = <Rect>[];
  for (final BoardCard card in cards) {
    if (!excludeIds.contains(card.id)) {
      rects.add(boardCardRect(card, measuredHeights: measuredHeights));
    }
  }
  return rects;
}
