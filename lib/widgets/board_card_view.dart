// 무드보드 판 위에 놓인 카드 한 장의 생김새입니다.
//
// ── 목록의 카드(reference_card.dart)와 왜 다른가 ──
// 목록 카드는 제목·폴더·태그·메모·날짜를 전부 보여줍니다. 찾기 위한 화면이기 때문입니다.
// 무드보드는 **분위기를 보는 곳**이라 글자가 많으면 오히려 방해가 됩니다.
// 그래서 평소에는 그림만 보이고, 마우스를 올렸을 때만 제목·내리기 버튼·크기 조절
// 손잡이가 나타납니다.
//
// 이 위젯은 자리(x, y)를 모릅니다. 어디에 놓을지는 판(board_canvas.dart)이 정하고,
// 여기는 "한 장이 어떻게 생겼는가"만 책임집니다. 크기도 직접 바꾸지 않고
// "손잡이를 이만큼 끌었다"고 알리기만 합니다.

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/reference_item.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';
import '../utils/board_card_actions.dart' show BoardResizeCorner;

/// 크기 조절 손잡이의 한 변 길이입니다.
///
/// 너무 작으면 못 잡고, 너무 크면 그림을 가립니다. 20이면 마우스로 집기에
/// 무리가 없으면서 카드 구석에 얌전히 들어갑니다.
const double boardResizeHandleSize = 20;

/// 무드보드 위의 카드 한 장입니다.
class BoardCardView extends StatefulWidget {
  const BoardCardView({
    super.key,
    required this.item,
    required this.imagePath,
    required this.onRemove,
    required this.onMeasured,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
    this.isActive = false,
    this.isSelected = false,
    this.isGrouped = false,
  });

  /// 이 카드가 보여주는 레퍼런스입니다.
  final ReferenceItem item;

  /// 이미지 파일의 전체 경로입니다. 아직 못 구했으면 null입니다.
  ///
  /// 유튜브도 여기로 옵니다. 썸네일을 내려받아 파일로 저장해두기 때문입니다.
  final String? imagePath;

  /// 판에서 내리기 버튼을 눌렀을 때 실행할 동작입니다.
  ///
  /// 카드가 직접 내리지 않고 "눌렸다"고 알리기만 합니다.
  /// 실제로 내리는 일은 화면(board_screen.dart)이 합니다.
  final VoidCallback onRemove;

  /// 크기 조절 손잡이를 잡았을 때, **지금 이 카드의 실제 크기**를 알려줍니다.
  ///
  /// 카드 높이는 보통 저장돼 있지 않습니다(= 그림 비율대로). 그래서 지금 높이가
  /// 얼마인지는 **실제로 그려진 것을 재봐야** 알 수 있고, 재는 일은 카드 자신만
  /// 할 수 있습니다.
  /// 이 카드가 **실제로 몇 픽셀로 그려졌는지** 알려줍니다.
  ///
  /// ── 왜 필요한가 ──
  /// 카드 높이는 보통 저장돼 있지 않습니다(= 그림 비율대로). 그래서 판은
  /// 카드가 세로로 얼마나 긴지 **모릅니다.** 전에는 4:3이라고 어림잡았는데,
  /// 세로 사진이면 128픽셀이나 어긋났습니다. 스냅이 붙는 거리가 8픽셀이니
  /// **눈에 보이지도 않는 자리에 붙는** 셈이었습니다.
  ///
  /// 재는 일은 카드 자신만 할 수 있어서 여기서 알려줍니다.
  /// 크기가 바뀌었을 때만 부릅니다. 매번 부르면 화면이 계속 다시 그려집니다.
  final void Function(Size size) onMeasured;

  /// [corner]는 어느 손잡이를 잡았는지입니다. 네 모서리 중 하나입니다.
  final void Function(Size currentSize, BoardResizeCorner corner) onResizeStart;

  /// 손잡이를 끄는 동안 움직인 만큼을 알려줍니다.
  final ValueChanged<Offset> onResizeUpdate;

  /// 손잡이에서 손을 뗐을 때 알려줍니다.
  final VoidCallback onResizeEnd;

  /// 지금 이 카드를 끌거나 크기를 바꾸고 있는 중인지 여부입니다.
  ///
  /// 살짝 들어 올려서 "지금 잡고 있는 것이 이것"임을 보여줍니다.
  /// 표시가 없으면 여러 장이 겹쳐 있을 때 무엇이 따라오는지 알기 어렵습니다.
  final bool isActive;

  /// 지금 이 카드가 **마퀴로 골라져 있는지** 여부입니다. (5단계 마퀴 다중선택)
  ///
  /// ── isActive와 무엇이 다른가 ──
  /// isActive는 "지금 이 카드가 끌리고 있다"는 뜻이라 손을 떼면 사라집니다.
  /// isSelected는 "여러 장을 함께 다루려고 골라뒀다"는 뜻이라, 손을 떼도
  /// **마우스를 올리지 않아도** 계속 보여야 합니다. 안 그러면 뭘 골랐는지
  /// 잊어버립니다.
  final bool isSelected;

  /// 지금 이 카드가 **그룹에 속해 있는지** 여부입니다. (그룹화)
  ///
  /// isSelected와는 다릅니다. isSelected는 "지금 당장 골라뒀다"는 임시
  /// 상태이고, isGrouped는 "묶어두기로 저장했다"는 계속 남는 상태입니다.
  /// 아무것도 안 골랐어도, 어느 카드가 그룹에 속해 있는지는 늘 보여야
  /// 합니다 — 안 그러면 눌러보기 전까지 그룹인 줄 모릅니다.
  final bool isGrouped;

  @override
  State<BoardCardView> createState() => _BoardCardViewState();
}

class _BoardCardViewState extends State<BoardCardView> {
  /// 마지막으로 바깥에 알려준 크기입니다. 같은 값을 또 알리지 않으려고 둡니다.
  Size? _reportedSize;

  /// 지금 마우스가 이 카드 위에 올라와 있는지 여부입니다.
  ///
  /// 카드마다 따로 기억합니다. 판 전체가 기억하면 카드 하나에 마우스가 스칠 때마다
  /// 판에 놓인 카드를 전부 다시 그리게 됩니다.
  bool _isHovered = false;

  /// 손잡이를 잡는 순간 카드의 실제 크기를 재서 바깥에 알려줍니다.
  ///
  /// `context.size`는 **지금 화면에 그려진 이 카드의 크기**입니다.
  /// 판 좌표 기준이라, 판을 확대해서 보고 있어도 값은 그대로입니다.
  void _reportResizeStart(BoardResizeCorner corner) {
    final Size? size = context.size;
    if (size == null) {
      return;
    }
    widget.onResizeStart(size, corner);
  }

  /// 다 그려진 뒤에 실제 크기를 재서 바깥에 알려줍니다.
  ///
  /// ── 왜 build가 끝난 뒤인가 ──
  /// build를 하는 도중에는 아직 크기가 안 정해져 있습니다. 그림을 읽어와
  /// 비율을 알아야 높이가 나오기 때문입니다. addPostFrameCallback은
  /// "이번에 다 그리고 나면 불러줘"라는 뜻입니다.
  ///
  /// 값이 바뀌었을 때만 알립니다. 매번 알리면 화면이 끝없이 다시 그려집니다.
  void _measureAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) {
        return;
      }

      final Size? size = context.size;
      if (size == null) {
        return;
      }
      if (size == _reportedSize) {
        return;
      }

      _reportedSize = size;
      widget.onMeasured(size);
    });
  }

  /// 카드 한 장의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;

    _measureAfterBuild();

    // 잡고 있거나 마우스를 올렸으면 도드라지게 합니다.
    final bool isRaised = widget.isActive || _isHovered;

    // 테두리·그림자는 raised와 selected 둘 중 하나만 있어도 보입니다.
    // 마우스를 안 올려도 "무엇을 골라뒀는지"가 계속 보여야 하기 때문입니다.
    final bool isHighlighted = isRaised || widget.isSelected;

    return MouseRegion(
      // 손가락 터치로는 아무 일도 일어나지 않아서 폰에서는 저절로 조용합니다.
      onEnter: (PointerEnterEvent event) => setState(() => _isHovered = true),
      onExit: (PointerExitEvent event) => setState(() => _isHovered = false),

      // 마우스를 올리면 커서가 "잡을 수 있는 손" 모양이 됩니다.
      // 끌 수 있다는 것을 알려주는 가장 익숙한 방법입니다.
      cursor: SystemMouseCursors.grab,

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,

        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(appCornerRadius),
          border: Border.all(
            color: isHighlighted ? colors.primary : palette.border,
            width: isHighlighted ? 2 : 1,
          ),
          boxShadow: isHighlighted
              ? palette.cardShadowHovered
              : palette.cardShadow,
        ),

        // 그림이 둥근 모서리 밖으로 삐져나오지 않게 잘라냅니다.
        clipBehavior: Clip.antiAlias,

        child: Stack(
          children: <Widget>[
            // ── 이 그림이 Stack의 크기를 정합니다 ──
            // Positioned.fill로 감싸면 크기를 정해주는 자식이 하나도 없게 되어
            // "높이를 알 수 없다"는 오류가 납니다. 겹치는 것들만 Positioned로 얹습니다.
            _buildImage(colors),

            // 제목·내리기·크기 조절은 마우스를 올렸을 때만 나타납니다.
            // 평소에도 떠 있으면 그림 여러 장을 늘어놓고 볼 때 눈이 어지럽습니다.
            if (isRaised) ...<Widget>[
              _buildTitleBar(colors),
              for (final BoardResizeCorner corner in BoardResizeCorner.values)
                _buildResizeHandle(colors, corner),
            ],

            // 골라진 표시는 마우스를 안 올려도 항상 보입니다. 여러 장을
            // 골라뒀을 때, 마우스를 하나하나 올려보지 않고도 한눈에
            // "이만큼 골랐다"를 알 수 있어야 합니다.
            if (widget.isSelected) _buildSelectedBadge(colors),
          ],
        ),
      ),
    );
  }

  /// 카드의 그림 부분입니다.
  ///
  /// ── 크기를 정해뒀는지에 따라 다르게 그립니다 ──
  /// 아직 크기를 안 바꾼 카드는 **원본 비율 그대로** 둡니다. 무드보드에서 사진을
  /// 네모로 잘라버리면 구도가 사라져서, 애초에 이 판을 만든 이유가 없어집니다.
  ///
  /// 크기를 바꾼 카드는 정해진 높이에 맞춰야 하는데, 이때도 비율은 지켜집니다.
  /// 크기 조절이 **가로세로 비율을 고정한 채** 이뤄지기 때문입니다
  /// (board_screen.dart의 `_onResizeUpdate` 설명 참고).
  Widget _buildImage(ColorScheme colors) {
    final String? path = widget.imagePath;

    if (path == null) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: _buildPlaceholder(colors, Icons.image_outlined),
      );
    }

    return Image.file(
      File(path),
      width: double.infinity,
      fit: BoxFit.fitWidth,

      // 아직 안 읽힌 그림은 높이가 0이라 카드가 납작해집니다.
      // 그러면 위에 얹은 버튼들이 카드 밖으로 밀려나 눌리지 않습니다.
      // 읽히기 전까지 4:3 자리를 잡아두고, 다 읽히면 원본 비율로 바뀝니다.
      frameBuilder:
          (
            BuildContext context,
            Widget child,
            int? frame,
            bool wasSynchronouslyLoaded,
          ) {
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }
            return AspectRatio(
              aspectRatio: 4 / 3,
              child: _buildPlaceholder(colors, Icons.image_outlined),
            );
          },

      // 파일이 지워졌거나 깨졌을 때 판 전체가 빨간 오류 화면이 되지 않게 막습니다.
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        return AspectRatio(
          aspectRatio: 4 / 3,
          child: _buildPlaceholder(colors, Icons.broken_image_outlined),
        );
      },
    );
  }

  /// 마우스를 올렸을 때 카드 아래쪽에 뜨는 제목 띠입니다.
  ///
  /// **내리기(×) 버튼도 여기에 들어있습니다.** 손잡이가 네 모서리 전부로
  /// 늘어나면서 오른쪽 위가 더는 비어있지 않아, 예전처럼 오른쪽 위에 따로
  /// 떠 있는 버튼으로 두면 오른쪽 위 손잡이와 겹칩니다. 제목 띠 안에
  /// 나란히 두면 겹칠 자리가 없습니다.
  Widget _buildTitleBar(ColorScheme colors) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        // 왼쪽 아래·오른쪽 아래 둘 다 크기 조절 손잡이 자리라 양쪽 다
        // 그만큼 비워둡니다. 안 비우면 제목 띠가 손잡이를 덮어서 잡을 수
        // 없게 됩니다. (카드는 이보다 작아지지 않으므로 — minBoardCardWidth —
        // 아무리 좁아져도 이 너비 안에 글자·버튼이 들어갑니다)
        padding: const EdgeInsets.symmetric(
          horizontal: boardResizeHandleSize,
          vertical: 6,
        ),

        // 밝은 사진 위에서도 글씨가 보이도록 검은 반투명 바탕을 깝니다.
        color: Colors.black.withValues(alpha: 0.55),

        child: Row(
          children: <Widget>[
            // 그룹에 속한 카드에만 붙는 작은 사슬 표시입니다. 마우스를
            // 올렸을 때만 보이지만(제목 띠 자체가 그때만 뜨므로), 지금은
            // "그룹인 걸 알아채는 방법" 중 가장 방해가 적은 자리입니다 —
            // 늘 떠 있는 배지를 새로 만들면 네 모서리 손잡이와 자리
            // 다툼이 생깁니다.
            if (widget.isGrouped)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.link, size: 12, color: Colors.white70),
              ),

            Expanded(
              child: Text(
                widget.item.title.isEmpty ? '(제목 없음)' : widget.item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.meta.copyWith(color: Colors.white),
              ),
            ),

            // **레퍼런스를 지우는 버튼이 아닙니다.** 판에서만 내려가고
            // 목록에는 그대로 남습니다. 그래서 아이콘도 휴지통(🗑)이 아니라
            // 닫기(✕)를 씁니다. 휴지통을 쓰면 사진이 영영 지워지는 줄 알고
            // 누르기를 무서워하게 됩니다.
            InkWell(
              onTap: widget.onRemove,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(1),
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// [corner]가 가리키는 커서 모양입니다. 반대쪽 대각선끼리 같은 모양을
  /// 씁니다(왼쪽 위·오른쪽 아래는 "↖↘", 오른쪽 위·왼쪽 아래는 "↗↙").
  MouseCursor _cursorFor(BoardResizeCorner corner) {
    switch (corner) {
      case BoardResizeCorner.topLeft:
      case BoardResizeCorner.bottomRight:
        return SystemMouseCursors.resizeUpLeftDownRight;
      case BoardResizeCorner.topRight:
      case BoardResizeCorner.bottomLeft:
        return SystemMouseCursors.resizeUpRightDownLeft;
    }
  }

  /// 네 모서리 중 하나에 놓는 크기 조절 손잡이입니다.
  ///
  /// ── 왜 카드 안쪽 구석인가 (바깥으로 튀어나온 점이 아니라) ──
  /// 밖으로 튀어나오게 하려면 카드가 실제 크기보다 커야 하는데, 그러면 카드끼리
  /// 겹칠 때 보이지 않는 여백이 옆 카드를 가려서 **잘 보이는 카드가 안 잡히는**
  /// 일이 생깁니다. 안쪽 구석에 두면 그림을 조금 가리는 대신 그런 문제가 없습니다.
  ///
  /// ── 이 손잡이의 끌기가 카드 옮기기와 안 섞이는 이유 ──
  /// 이 GestureDetector가 카드 전체의 것보다 **안쪽에** 있습니다. Flutter는 손가락이
  /// 닿은 지점에서 가장 안쪽 것부터 챙기기 때문에, 손잡이 위에서 시작한 끌기는
  /// 손잡이가 가져가고 카드는 안 움직입니다.
  ///
  /// ── 이름표(Key)를 붙여둡니다 ──
  /// 손잡이가 네 개라 아이콘만으로는 테스트에서 어느 것이 어느 모서리인지
  /// 구분할 수 없습니다. `resize-handle-topLeft` 식으로 모서리 이름을 넣어둡니다.
  Widget _buildResizeHandle(ColorScheme colors, BoardResizeCorner corner) {
    return Positioned(
      left: corner.isLeft ? 0 : null,
      right: corner.isLeft ? null : 0,
      top: corner.isTop ? 0 : null,
      bottom: corner.isTop ? null : 0,
      child: MouseRegion(
        // 커서를 대각선 화살표로 바꿔 "여기를 끌면 크기가 바뀐다"를 알립니다.
        cursor: _cursorFor(corner),
        child: GestureDetector(
          key: ValueKey<String>('resize-handle-${corner.name}'),

          // 처음 몇 픽셀이 버려지지 않게 합니다.
          // (왜인지는 board_canvas.dart의 같은 줄 설명을 보세요)
          dragStartBehavior: DragStartBehavior.down,

          onPanStart: (DragStartDetails details) => _reportResizeStart(corner),
          onPanUpdate: (DragUpdateDetails details) =>
              widget.onResizeUpdate(details.delta),
          onPanEnd: (DragEndDetails details) => widget.onResizeEnd(),

          child: Container(
            width: boardResizeHandleSize,
            height: boardResizeHandleSize,
            color: colors.primary.withValues(alpha: 0.85),
            child: Icon(
              // 대각선 두 방향 화살표. 크기 조절 손잡이의 흔한 표시입니다.
              Icons.open_in_full,
              size: 12,
              color: colors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }

  /// 카드 위쪽 가운데에 뜨는 "골라짐" 표시입니다. (5단계 마퀴 다중선택)
  ///
  /// ── 왜 구석이 아니라 가운데인가 ──
  /// 네 구석 전부 크기 조절 손잡이 자리라, 어느 구석에 둬도 마우스를 올렸을
  /// 때(=손잡이가 함께 뜰 때) 겹칩니다. 손잡이가 없는 위쪽 가운데로 옮겼습니다.
  Widget _buildSelectedBadge(ColorScheme colors) {
    return Positioned(
      top: 4,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: colors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: colors.surface, width: 1.5),
          ),
          child: Icon(Icons.check, size: 14, color: colors.onPrimary),
        ),
      ),
    );
  }

  /// 그림을 못 보여줄 때 대신 띄우는 회색 상자입니다.
  Widget _buildPlaceholder(ColorScheme colors, IconData icon) {
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(icon, size: 32, color: colors.onSurfaceVariant),
      ),
    );
  }
}
