// 선택된 카드 여러 장을 나란히 맞추는 계산입니다. (4단계 6번 정렬·분배 툴바)
//
// ── 왜 화면 파일에서 빼냈나 ──
// board_card_actions.dart를 빼둔 것과 같은 이유입니다. 이 계산들은 화면
// 없이도 맞는지 확인할 수 있습니다. (test/utils/board_align_test.dart)
//
// ── 목록을 고치지 않고 새 목록을 돌려줍니다 ──
// board_card_actions.dart와 같은 방식입니다.

import 'dart:ui';

import '../models/board.dart';
import 'board_card_actions.dart';
import 'board_layout.dart';

/// 가로·세로 정렬 방향입니다.
enum BoardAlignMode {
  /// 선택 범위의 가장 왼쪽에 맞춥니다.
  left,

  /// 선택 범위의 가로 가운데에 맞춥니다.
  hcenter,

  /// 선택 범위의 가장 오른쪽에 맞춥니다.
  right,

  /// 선택 범위의 가장 위에 맞춥니다.
  top,

  /// 선택 범위의 세로 가운데에 맞춥니다.
  vcenter,

  /// 선택 범위의 가장 아래에 맞춥니다.
  bottom,
}

/// [ids]에 든 카드들을 [mode] 방향으로 나란히 맞춘 새 목록을 돌려줍니다.
///
/// ── 기준은 "선택 전체를 감싸는 범위"입니다 ──
/// 카드 하나를 골라 그것에 맞추는 것이 아니라, 선택된 카드들을 전부 감싸는
/// 네모를 구해서 그 네모의 왼쪽·가운데·오른쪽(또는 위·가운데·아래)에
/// 맞춥니다. 디자인 도구에서 흔히 쓰는 방식입니다 — 카드를 하나 더
/// 고르거나 빼면 기준도 그만큼 넓어지거나 좁아져서 예측하기 쉽습니다.
///
/// ── 그룹 여부와 상관없이 카드마다 따로 옮깁니다 ──
/// (아직 그룹 자체가 없습니다 — 5단계에서 다음으로 미뤄뒀습니다)
///
/// 선택이 **한 장뿐이면 그대로 둡니다.** 정렬은 "여럿을 나란히 맞추는"
/// 동작이라 기준으로 삼을 다른 카드가 없으면 뜻이 없습니다.
List<BoardCard> alignSelectedCards(
  List<BoardCard> cards,
  Set<String> ids,
  BoardAlignMode mode, {
  Map<String, double> measuredHeights = const <String, double>{},
}) {
  if (ids.length < 2) {
    return cards;
  }

  final Rect? bounds = _boundsOf(cards, ids, measuredHeights);
  if (bounds == null) {
    return cards;
  }

  return <BoardCard>[
    for (final BoardCard card in cards)
      if (ids.contains(card.id))
        _aligned(card, mode, bounds, measuredHeights)
      else
        card,
  ];
}

/// 카드 한 장을 [mode] 방향으로 [bounds] 기준에 맞춘 사본을 돌려줍니다.
BoardCard _aligned(
  BoardCard card,
  BoardAlignMode mode,
  Rect bounds,
  Map<String, double> measuredHeights,
) {
  final double height = boardCardHeight(card, measuredHeights: measuredHeights);

  switch (mode) {
    case BoardAlignMode.left:
      return card.copyWith(x: bounds.left);
    case BoardAlignMode.hcenter:
      return card.copyWith(x: bounds.center.dx - card.width / 2);
    case BoardAlignMode.right:
      return card.copyWith(x: bounds.right - card.width);
    case BoardAlignMode.top:
      return card.copyWith(y: bounds.top);
    case BoardAlignMode.vcenter:
      return card.copyWith(y: bounds.center.dy - height / 2);
    case BoardAlignMode.bottom:
      return card.copyWith(y: bounds.bottom - height);
  }
}

/// [referenceId] 카드의 크기로 [ids]에 든 나머지 카드들의 크기를 맞춘
/// 새 목록을 돌려줍니다. **자리(x, y)는 건드리지 않습니다.**
///
/// ── 왜 자리는 그대로 두나 ──
/// "크기를 맞춘다"와 "자리를 맞춘다"는 다른 일입니다. 자리를 맞추고
/// 싶으면 [alignSelectedCards]를 따로 씁니다. 한 번에 둘 다 하면
/// 사용자가 "왜 자리도 바뀌었지" 하고 놀랍니다.
///
/// [referenceId]가 [ids]에 없거나 목록에 없으면 아무 일도 안 합니다.
List<BoardCard> matchSizeSelectedCards(
  List<BoardCard> cards,
  Set<String> ids,
  String referenceId, {
  Map<String, double> measuredHeights = const <String, double>{},
}) {
  final int referenceIndex = indexOfCard(cards, referenceId);
  if (referenceIndex == -1 || !ids.contains(referenceId)) {
    return cards;
  }

  final BoardCard reference = cards[referenceIndex];
  final double width = reference.width;
  final double height = boardCardHeight(
    reference,
    measuredHeights: measuredHeights,
  );

  return <BoardCard>[
    for (final BoardCard card in cards)
      if (ids.contains(card.id) && card.id != referenceId)
        card.copyWith(width: width, height: height)
      else
        card,
  ];
}

/// [ids]에 든 카드들을 전부 감싸는 네모를 구합니다. 하나도 없으면 null입니다.
Rect? _boundsOf(
  List<BoardCard> cards,
  Set<String> ids,
  Map<String, double> measuredHeights,
) {
  Rect? bounds;

  for (final BoardCard card in cards) {
    if (!ids.contains(card.id)) {
      continue;
    }

    final Rect rect = boardCardRect(card, measuredHeights: measuredHeights);
    bounds = bounds == null ? rect : bounds.expandToInclude(rect);
  }

  return bounds;
}
