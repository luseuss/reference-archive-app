// 판 위에 카드들을 놓인 자리대로 그리고, 끌기·크기 조절을 알아채는 곳입니다.
//
// ── 이 파일이 하는 일과 안 하는 일 ──
//   한다  — 카드를 좌표대로 배치하고, 조작을 알아채서 화면에 알려줍니다.
//   안 한다 — 저장하지 않습니다. 위치나 크기를 직접 고치지도 않습니다.
//            확대·축소도 모릅니다. 그건 board_viewport.dart가 합니다.
//
// 저장은 화면(board_screen.dart)이 합니다. 여기서 저장하면 "끄는 도중에도
// 계속 저장"하게 되기 쉬운데, 그러면 1초에 수십 번 데이터베이스에 쓰게 됩니다.
//
// ── 바탕을 그리지 않습니다 ──
// 판의 바탕색과 테두리는 board_viewport.dart가 그립니다. 여기서 바탕을 깔면
// **빈 곳을 끌어도 판이 안 움직입니다** — 바탕이 클릭을 가로채기 때문입니다.
// 그래서 이 파일은 카드만 그리고 빈 자리는 비워둡니다.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/board.dart';
import '../models/reference_item.dart';
import 'board_card_view.dart';

/// 카드를 자유롭게 늘어놓는 판입니다.
class BoardCanvas extends StatelessWidget {
  const BoardCanvas({
    super.key,
    required this.cards,
    required this.canvasOrigin,
    required this.itemsById,
    required this.imagePaths,
    required this.activeCardId,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
    required this.onRemoveCard,
  });

  /// 판에 놓인 카드들입니다. **아래에 깔린 것부터** 순서대로 들어있어야 합니다.
  ///
  /// Stack은 목록의 뒤쪽에 있는 것을 위에 그립니다. 그래서 이 순서가 곧 겹침 순서입니다.
  final List<BoardCard> cards;

  /// 그리는 자리의 **왼쪽 위 모서리**입니다. (판 좌표)
  ///
  /// 카드는 음수 자리에도 놓일 수 있습니다. 그런데 화면 조각은 상자 안에서
  /// 0 이상이어야 클릭이 닿습니다. 그래서 카드를 놓을 때 이 값을 빼서
  /// **상자 안쪽 좌표로 옮겨** 놓습니다.
  ///
  /// 뺀 만큼은 board_viewport.dart가 상자를 놓을 때 도로 더합니다.
  /// 그래서 화면에서 카드가 움직이지는 않습니다.
  /// (board_layout.dart의 boardCanvasRect 설명 참고)
  final Offset canvasOrigin;

  /// 레퍼런스 번호로 레퍼런스를 찾는 표입니다. (referenceId → ReferenceItem)
  ///
  /// 카드에는 번호만 들어있어서, 제목과 그림을 보여주려면 짝을 지어야 합니다.
  /// 판이 직접 데이터베이스를 뒤지면 카드를 그릴 때마다 조회가 일어나 버벅입니다.
  final Map<String, ReferenceItem> itemsById;

  /// 레퍼런스 번호로 이미지 파일 경로를 찾는 표입니다. (referenceId → 전체 경로)
  final Map<String, String?> imagePaths;

  /// 지금 끌거나 크기를 바꾸고 있는 카드의 번호입니다. 없으면 null입니다.
  final String? activeCardId;

  /// 카드를 잡았을 때 알려줍니다.
  final ValueChanged<BoardCard> onDragStart;

  /// 카드를 끄는 동안 **움직인 만큼**(delta)을 알려줍니다.
  ///
  /// 최종 위치가 아니라 "이번 순간에 얼마나 움직였는지"입니다. 화면 쪽에서
  /// 지금 위치에 더해 쓰면 됩니다. 손가락의 절대 좌표를 넘기면 카드를 잡은
  /// 지점이 무시되어, 끌기 시작하는 순간 카드가 커서 가운데로 튑니다.
  ///
  /// 값은 **판 좌표**입니다. 판을 확대·축소해서 보고 있어도 화면에서 잰 거리가
  /// 아니라 판에서의 거리로 옵니다. Flutter가 알아서 되돌려주기 때문에,
  /// 화면 쪽에서 배율을 나눠줄 필요가 없습니다.
  final void Function(BoardCard card, Offset delta) onDragUpdate;

  /// 카드에서 손을 뗐을 때 알려줍니다. 저장은 이때 합니다.
  final ValueChanged<BoardCard> onDragEnd;

  /// 크기 조절 손잡이를 잡았을 때, **지금 이 카드가 실제로 몇 픽셀인지** 알려줍니다.
  ///
  /// ── 왜 크기를 같이 넘기나 ──
  /// 카드 높이는 보통 비어 있습니다(= 그림 비율대로). 그래서 "지금 높이가 얼마인지"는
  /// 저장된 값만 봐서는 알 수 없고, **실제로 그려진 것을 재봐야** 알 수 있습니다.
  /// 그 재는 일은 카드 자신만 할 수 있어서 여기서 알려줍니다.
  final void Function(BoardCard card, Size currentSize) onResizeStart;

  /// 크기 조절 손잡이를 끄는 동안 움직인 만큼을 알려줍니다. (판 좌표)
  final void Function(BoardCard card, Offset delta) onResizeUpdate;

  /// 크기 조절 손잡이에서 손을 뗐을 때 알려줍니다. 저장은 이때 합니다.
  final ValueChanged<BoardCard> onResizeEnd;

  /// 카드를 판에서 내릴 때 알려줍니다.
  final ValueChanged<BoardCard> onRemoveCard;

  /// 판 안의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    return Stack(
      // 바탕이 없습니다. 카드가 없는 자리는 클릭이 그대로 통과해서
      // 아래층(board_viewport.dart의 판 옮기기)까지 내려갑니다.
      children: <Widget>[
        for (final BoardCard card in cards) _buildPositionedCard(card),
      ],
    );
  }

  /// 카드 한 장을 제자리에 놓고, 끌 수 있게 감싸 돌려줍니다.
  ///
  /// ── 카드마다 이름표(Key)를 꼭 붙입니다 ──
  /// 카드를 잡으면 그 카드가 목록 맨 뒤로 옮겨집니다(맨 위에 그리려고).
  /// 이름표가 없으면 Flutter는 화면 조각을 **순서(몇 번째)로만** 짝지어서,
  /// 순서가 바뀌는 순간 **끌기를 붙잡고 있던 자리에 다른 카드가 들어옵니다.**
  /// 그러면 잡은 카드는 가만히 있고 엉뚱한 카드가 커서를 따라다닙니다.
  ///
  /// 이름표를 붙이면 순서가 바뀌어도 "번호가 같은 것끼리" 짝지어집니다.
  /// (test/screens/board_screen_test.dart의 '여러 장이 놓여 있어도...' 참고)
  Widget _buildPositionedCard(BoardCard card) {
    final ReferenceItem? item = itemsById[card.referenceId];

    // 짝이 되는 레퍼런스를 못 찾으면 아무것도 그리지 않습니다.
    // 레퍼런스를 목록에서 지운 직후에 이런 상태가 잠깐 생길 수 있는데,
    // 빈 상자를 그리는 것보다 안 보이는 편이 낫습니다.
    //
    // 이때도 이름표를 붙입니다. 안 붙이면 이 빈 상자 때문에 뒤에 오는
    // 카드들의 순서가 밀려서 위와 똑같은 문제가 생깁니다.
    if (item == null) {
      return SizedBox.shrink(key: ValueKey<String>(card.id));
    }

    return Positioned(
      key: ValueKey<String>(card.id),

      // 판 좌표를 상자 안쪽 좌표로 옮깁니다. (위 canvasOrigin 설명 참고)
      left: card.x - canvasOrigin.dx,
      top: card.y - canvasOrigin.dy,
      width: card.width,

      // ── height에 null이 들어가는 경우가 있습니다 ──
      // card.height가 null이면 카드의 높이를 **그림이 정하게** 됩니다.
      // 세로 사진은 길쭉하게, 가로 사진은 납작하게 원본 비율 그대로 놓입니다.
      // 사용자가 크기를 조절하면 그때 값이 채워집니다.
      height: card.height,

      child: GestureDetector(
        // ── dragStartBehavior를 down으로 두는 이유 ──
        // Flutter는 "진짜 끄는 것인지" 확인하려고 처음 몇 픽셀을 지켜본 뒤에야
        // 끌기로 인정합니다. 기본값(start)은 그 몇 픽셀을 **버립니다.** 그러면
        // 카드가 손가락보다 조금씩 뒤처져서, 끌 때마다 어긋난 자리에 놓입니다.
        // down은 누른 자리부터 세기 때문에 버려지는 거리가 없습니다.
        dragStartBehavior: DragStartBehavior.down,

        onPanStart: (DragStartDetails details) => onDragStart(card),

        // delta = 지난 순간부터 지금까지 움직인 거리입니다.
        onPanUpdate: (DragUpdateDetails details) =>
            onDragUpdate(card, details.delta),

        onPanEnd: (DragEndDetails details) => onDragEnd(card),

        child: BoardCardView(
          item: item,
          imagePath: imagePaths[card.referenceId],
          isActive: activeCardId == card.id,
          onRemove: () => onRemoveCard(card),
          onResizeStart: (Size currentSize) => onResizeStart(card, currentSize),
          onResizeUpdate: (Offset delta) => onResizeUpdate(card, delta),
          onResizeEnd: () => onResizeEnd(card),
        ),
      ),
    );
  }
}
