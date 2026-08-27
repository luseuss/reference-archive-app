// 무드보드 판 위에 놓인 카드 한 장의 생김새입니다.
//
// ── 목록의 카드(reference_card.dart)와 왜 다른가 ──
// 목록 카드는 제목·폴더·태그·메모·날짜를 전부 보여줍니다. 찾기 위한 화면이기 때문입니다.
// 무드보드는 **분위기를 보는 곳**이라 글자가 많으면 오히려 방해가 됩니다.
// 그래서 평소에는 그림만 보이고, 마우스를 올렸을 때만 제목과 내리기 버튼이 나타납니다.
//
// 이 위젯은 자리(x, y)를 모릅니다. 어디에 놓을지는 판(board_canvas.dart)이 정하고,
// 여기는 "한 장이 어떻게 생겼는가"만 책임집니다.

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/reference_item.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';

/// 무드보드 위의 카드 한 장입니다.
class BoardCardView extends StatefulWidget {
  const BoardCardView({
    super.key,
    required this.item,
    required this.imagePath,
    required this.onRemove,
    this.isDragging = false,
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

  /// 지금 이 카드를 끌고 있는 중인지 여부입니다.
  ///
  /// 끄는 동안 살짝 들어 올려서 "지금 잡고 있는 것이 이것"임을 보여줍니다.
  /// 표시가 없으면 여러 장이 겹쳐 있을 때 무엇이 따라오는지 알기 어렵습니다.
  final bool isDragging;

  @override
  State<BoardCardView> createState() => _BoardCardViewState();
}

class _BoardCardViewState extends State<BoardCardView> {
  /// 지금 마우스가 이 카드 위에 올라와 있는지 여부입니다.
  ///
  /// 카드마다 따로 기억합니다. 판 전체가 기억하면 카드 하나에 마우스가 스칠 때마다
  /// 판에 놓인 카드를 전부 다시 그리게 됩니다.
  bool _isHovered = false;

  /// 카드 한 장의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;

    // 끌고 있거나 마우스를 올렸으면 도드라지게 합니다.
    final bool isActive = widget.isDragging || _isHovered;

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
            color: isActive ? colors.primary : palette.border,
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive ? palette.cardShadowHovered : palette.cardShadow,
        ),

        // 그림이 둥근 모서리 밖으로 삐져나오지 않게 잘라냅니다.
        clipBehavior: Clip.antiAlias,

        child: Stack(
          children: <Widget>[
            // ── 이 그림이 Stack의 크기를 정합니다 ──
            // Positioned.fill로 감싸면 크기를 정해주는 자식이 하나도 없게 되어
            // "높이를 알 수 없다"는 오류가 납니다. 겹치는 것들만 Positioned로 얹습니다.
            _buildImage(colors),

            // 제목과 내리기 버튼은 마우스를 올렸을 때만 나타납니다.
            // 평소에도 떠 있으면 그림 여러 장을 늘어놓고 볼 때 눈이 어지럽습니다.
            if (_isHovered) ...<Widget>[
              _buildTitleBar(),
              _buildRemoveButton(colors),
            ],
          ],
        ),
      ),
    );
  }

  /// 카드의 그림 부분입니다.
  ///
  /// 원본 비율 그대로 둡니다. 무드보드에서 사진을 네모로 잘라버리면
  /// 구도가 사라져서, 애초에 이 판을 만든 이유가 없어집니다.
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
      // 그러면 위에 얹은 내리기 버튼이 카드 밖으로 밀려나 눌리지 않습니다.
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
  Widget _buildTitleBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

        // 밝은 사진 위에서도 글씨가 보이도록 검은 반투명 바탕을 깝니다.
        color: Colors.black.withValues(alpha: 0.55),

        child: Text(
          widget.item.title.isEmpty ? '(제목 없음)' : widget.item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.meta.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  /// 마우스를 올렸을 때 오른쪽 위에 뜨는 "판에서 내리기" 버튼입니다.
  ///
  /// **레퍼런스를 지우는 버튼이 아닙니다.** 판에서만 내려가고 목록에는 그대로
  /// 남습니다. 그래서 아이콘도 휴지통(🗑)이 아니라 닫기(✕)를 씁니다.
  /// 휴지통을 쓰면 사진이 영영 지워지는 줄 알고 누르기를 무서워하게 됩니다.
  Widget _buildRemoveButton(ColorScheme colors) {
    return Positioned(
      top: 4,
      right: 4,
      child: Material(
        color: colors.surface.withValues(alpha: 0.9),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onRemove,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.close, size: 18, color: colors.onSurface),
          ),
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
