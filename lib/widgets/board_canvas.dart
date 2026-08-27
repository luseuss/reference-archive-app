// 무드보드 판 그 자체입니다. 카드들을 놓인 자리에 그리고, 끌어서 옮기게 해줍니다.
//
// ── 이 파일이 하는 일과 안 하는 일 ──
//   한다  — 카드를 좌표대로 배치하고, 끌기 동작을 알아채서 화면에 알려줍니다.
//   안 한다 — 저장하지 않습니다. 위치를 직접 고치지도 않습니다.
//
// 저장은 화면(board_screen.dart)이 합니다. 판이 직접 저장하면 "끄는 도중에도
// 계속 저장"하게 되기 쉬운데, 그러면 1초에 수십 번 데이터베이스에 쓰게 됩니다.
//
// ── 판 전체를 화면에 맞춰 줄여서 보여줍니다 (스크롤이 없습니다) ──
// 판은 1920×1200으로 정해져 있고, 창이 그보다 작으면 통째로 줄여서 다 보여줍니다.
//
// 처음에는 스크롤로 만들었다가 바꿨습니다. 이유가 둘입니다.
//   1. **카드를 잃어버리지 않습니다.** 스크롤이면 카드가 화면 밖에 있을 수 있어서
//      "분명히 올렸는데 안 보인다"가 생깁니다. 다 보이면 그럴 일이 없습니다.
//   2. **끌기와 스크롤이 서로 싸우지 않습니다.** 카드를 끌려는 것인지 판을
//      스크롤하려는 것인지 Flutter가 판단해야 하는데, 실제로 만들어보니
//      스크롤이 이겨서 카드가 잡히지 않았습니다(테스트로 잡았습니다).
//      스크롤이 없으면 이 문제 자체가 없습니다.
//
// 대신 창이 작으면 카드도 함께 작아집니다. 크게 보는 것은 2단계(줌·팬)에서 붙입니다.

import 'dart:math';

import 'package:flutter/material.dart';

import '../models/board.dart';
import '../models/reference_item.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import 'board_card_view.dart';

/// 카드를 자유롭게 늘어놓는 판입니다.
class BoardCanvas extends StatelessWidget {
  const BoardCanvas({
    super.key,
    required this.cards,
    required this.itemsById,
    required this.imagePaths,
    required this.draggingCardId,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onRemoveCard,
  });

  /// 판에 놓인 카드들입니다. **아래에 깔린 것부터** 순서대로 들어있어야 합니다.
  ///
  /// Stack은 목록의 뒤쪽에 있는 것을 위에 그립니다. 그래서 이 순서가 곧 겹침 순서입니다.
  final List<BoardCard> cards;

  /// 레퍼런스 번호로 레퍼런스를 찾는 표입니다. (referenceId → ReferenceItem)
  ///
  /// 카드에는 번호만 들어있어서, 제목과 그림을 보여주려면 짝을 지어야 합니다.
  /// 판이 직접 데이터베이스를 뒤지면 카드를 그릴 때마다 조회가 일어나 버벅입니다.
  final Map<String, ReferenceItem> itemsById;

  /// 레퍼런스 번호로 이미지 파일 경로를 찾는 표입니다. (referenceId → 전체 경로)
  final Map<String, String?> imagePaths;

  /// 지금 끌고 있는 카드의 번호입니다. 아무것도 안 끌고 있으면 null입니다.
  final String? draggingCardId;

  /// 카드를 잡았을 때 알려줍니다.
  final ValueChanged<BoardCard> onDragStart;

  /// 카드를 끄는 동안 **움직인 만큼**(delta)을 알려줍니다.
  ///
  /// 최종 위치가 아니라 "이번 순간에 얼마나 움직였는지"입니다. 화면 쪽에서
  /// 지금 위치에 더해 쓰면 됩니다. 손가락/마우스의 절대 좌표를 넘기면 카드를
  /// 잡은 지점이 무시되어, 끌기 시작하는 순간 카드가 커서 가운데로 튑니다.
  ///
  /// 값은 **판 좌표**입니다. 판을 줄여서 보여주고 있어도 화면에서 잰 거리가
  /// 아니라 판에서의 거리로 옵니다. Flutter가 알아서 되돌려주기 때문에,
  /// 화면 쪽에서 축소 비율을 나눠줄 필요가 없습니다.
  final void Function(BoardCard card, Offset delta) onDragUpdate;

  /// 카드에서 손을 뗐을 때 알려줍니다. 저장은 이때 합니다.
  final ValueChanged<BoardCard> onDragEnd;

  /// 카드를 판에서 내릴 때 알려줍니다.
  final ValueChanged<BoardCard> onRemoveCard;

  /// 판의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    // LayoutBuilder = "지금 내가 쓸 수 있는 자리가 얼마나 되는지" 알려주는 위젯입니다.
    // 창 크기가 바뀌면 다시 실행되므로, 창을 줄이면 판도 따라서 작아집니다.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 가로·세로 중 **더 빡빡한 쪽**에 맞춥니다. 그래야 판이 통째로 들어갑니다.
        final double scale = min(
          constraints.maxWidth / boardWidth,
          constraints.maxHeight / boardHeight,
        );

        return Center(
          child: Container(
            // 줄인 뒤의 크기입니다. 판의 가로세로 비율이 그대로 유지됩니다.
            width: boardWidth * scale,
            height: boardHeight * scale,

            decoration: BoxDecoration(
              color: palette.background,
              border: Border.all(color: palette.border),
            ),

            // FittedBox = 안쪽 내용을 바깥 상자 크기에 맞춰 늘리거나 줄이는 위젯입니다.
            // 바깥 상자를 이미 같은 비율로 만들어뒀으므로 fill로 꽉 채웁니다.
            //
            // 좌표를 직접 환산하지 않아도 되는 것이 이 방식의 장점입니다.
            // Flutter가 화면의 손가락 위치를 판 좌표로 알아서 되돌려줍니다.
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: boardWidth,
                height: boardHeight,
                child: Stack(
                  children: <Widget>[
                    for (final BoardCard card in cards)
                      _buildPositionedCard(card),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 카드 한 장을 제자리에 놓고, 끌 수 있게 감싸 돌려줍니다.
  Widget _buildPositionedCard(BoardCard card) {
    final ReferenceItem? item = itemsById[card.referenceId];

    // 짝이 되는 레퍼런스를 못 찾으면 아무것도 그리지 않습니다.
    // 레퍼런스를 목록에서 지운 직후에 이런 상태가 잠깐 생길 수 있는데,
    // 빈 상자를 그리는 것보다 안 보이는 편이 낫습니다.
    if (item == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: card.x,
      top: card.y,
      width: card.width,

      // ── height에 null이 들어가는 경우가 있습니다 ──
      // card.height가 null이면 카드의 높이를 **그림이 정하게** 됩니다.
      // 세로 사진은 길쭉하게, 가로 사진은 납작하게 원본 비율 그대로 놓입니다.
      height: card.height,

      child: GestureDetector(
        onPanStart: (DragStartDetails details) => onDragStart(card),

        // delta = 지난 순간부터 지금까지 움직인 거리입니다.
        onPanUpdate: (DragUpdateDetails details) =>
            onDragUpdate(card, details.delta),

        onPanEnd: (DragEndDetails details) => onDragEnd(card),

        child: BoardCardView(
          item: item,
          imagePath: imagePaths[card.referenceId],
          isDragging: draggingCardId == card.id,
          onRemove: () => onRemoveCard(card),
        ),
      ),
    );
  }
}
