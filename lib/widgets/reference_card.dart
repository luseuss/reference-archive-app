// 목록에 보이는 레퍼런스 카드 한 장입니다.
//
// 화면(screens/) 파일이 너무 길어지지 않도록 카드 한 장의 생김새는 여기로 뺐습니다.
// 나중에 카드에 즐겨찾기 별표나 태그 표시를 붙일 때도 이 파일만 보면 됩니다.

import 'dart:io';

import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/reference_item.dart';

/// 레퍼런스 한 건을 보여주는 카드입니다.
class ReferenceCard extends StatelessWidget {
  const ReferenceCard({
    super.key,
    required this.item,
    required this.imagePath,
    required this.onDelete,
    required this.onTap,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onSelectToggle,
    required this.onPlay,
  });

  /// 보여줄 레퍼런스
  final ReferenceItem item;

  /// 이미지 파일의 전체 경로입니다.
  ///
  /// 데이터베이스에는 파일 이름만 들어있어서, 화면에 띄우려면 실제 경로가 필요합니다.
  /// 경로를 아직 못 구했으면 null입니다.
  final String? imagePath;

  /// 삭제 버튼을 눌렀을 때 실행할 동작입니다.
  ///
  /// 카드가 직접 지우지 않고 "눌렸다"고 알리기만 합니다.
  /// 실제로 지우는 일은 화면(home_screen.dart)이 합니다.
  /// 카드는 생김새만 책임지게 두는 편이 나중에 고치기 쉽습니다.
  final VoidCallback onDelete;

  /// 카드를 눌렀을 때 실행할 동작입니다. (편집 화면 열기)
  ///
  /// 고르기 모드에서는 이걸 부르지 않고 [onSelectToggle]을 부릅니다.
  final VoidCallback onTap;

  /// 지금 여러 장 고르는 중인지 여부입니다.
  ///
  /// 켜져 있으면 카드에 체크박스가 생기고, 카드를 눌러도 편집 화면이 열리지 않습니다.
  /// 고르려고 누른 것인데 화면이 열려버리면 여러 장 고르기가 아예 불가능합니다.
  final bool isSelectionMode;

  /// 이 카드가 지금 골라져 있는지 여부입니다.
  final bool isSelected;

  /// 이 카드를 고르거나 고르기를 취소할 때 실행할 동작입니다.
  final VoidCallback onSelectToggle;

  /// 재생 버튼을 눌렀을 때 실행할 동작입니다. (유튜브 카드에만 보입니다)
  ///
  /// 카드 본체를 누르면 편집 화면, 재생 버튼을 누르면 재생 화면으로 갈라집니다.
  /// 삭제 버튼이 카드 안에 있으면서 자기 동작을 갖는 것과 같은 방식입니다.
  final VoidCallback onPlay;

  /// 카드의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,

      // 골라둔 카드는 테두리를 둘러 한눈에 구분되게 합니다.
      // 체크박스만으로는 카드가 많을 때 어느 걸 골랐는지 알아보기 어렵습니다.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: colors.primary, width: 2)
            : BorderSide.none,
      ),

      // InkWell로 감싸면 누를 수 있게 되고, 누를 때 물결 효과도 함께 나옵니다.
      // 삭제 버튼은 이 안에 있지만 자기 동작이 따로 있어서 카드 열기와 섞이지 않습니다.
      child: InkWell(
        // 고르기 모드에서는 누르는 것이 "고르기"가 됩니다.
        onTap: isSelectionMode ? onSelectToggle : onTap,

        // 길게 누르면 고르기 모드로 들어갑니다.
        // 폰에는 우클릭이 없어서, 길게 누르기가 "여러 개 고르기"의 표준 방법입니다.
        onLongPress: onSelectToggle,

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 카드의 그림 부분입니다. 남는 공간을 전부 차지하도록 Expanded로 감쌉니다.
            Expanded(child: _buildThumbnailArea(colors)),

            // 카드 아래쪽 제목과 표시들, 삭제 버튼입니다.
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
              child: Row(
                children: <Widget>[
                  // 고정·즐겨찾기 표시는 켜져 있을 때만 보입니다.
                  if (item.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.push_pin, size: 14, color: colors.primary),
                    ),
                  if (item.isFavorite)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.star, size: 14, color: colors.primary),
                    ),
                  Expanded(
                    child: Text(
                      item.title.isEmpty ? '(제목 없음)' : item.title,
                      // 제목이 길면 카드를 밀어내지 않고 ...으로 줄입니다.
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  // 고르기 모드에서는 낱장 삭제 버튼을 숨깁니다.
                  // 여러 장을 고르는 중에 실수로 한 장만 지우면 당황스럽고,
                  // 지우는 방법은 아래 작업 막대에 이미 있습니다.
                  if (!isSelectionMode)
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      tooltip: '삭제',
                      iconSize: 20,
                      color: colors.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 카드의 그림 부분을 만듭니다.
  ///
  /// 상황에 따라 그림 위에 두 가지가 얹힙니다.
  ///   - 유튜브면 재생 버튼 (누르면 편집 화면이 아니라 바로 재생)
  ///   - 고르기 모드면 체크박스
  Widget _buildThumbnailArea(ColorScheme colors) {
    final bool isYoutube = item.type == ReferenceType.youtube;

    // 아무것도 얹을 게 없으면 그림만 돌려줍니다.
    if (!isSelectionMode && !isYoutube) {
      return _buildThumbnail(colors);
    }

    // Stack = 위젯을 겹쳐 쌓는 것입니다.
    return Stack(
      children: <Widget>[
        Positioned.fill(child: _buildThumbnail(colors)),

        // 재생 버튼은 고르기 모드가 아닐 때만 보입니다.
        // 여러 장 고르는 중에 영상이 재생되기 시작하면 곤란합니다.
        if (isYoutube && !isSelectionMode)
          Positioned.fill(
            child: Center(
              child: Material(
                // 투명한 Material 위에 InkWell을 두면 누를 때 물결이 나옵니다.
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPlay,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.play_circle_fill,
                      size: 48,
                      // 썸네일이 밝든 어둡든 보이도록 흰색에 그림자를 줍니다.
                      color: Colors.white.withValues(alpha: 0.92),
                      shadows: const <Shadow>[
                        Shadow(color: Colors.black54, blurRadius: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        if (isSelectionMode)
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              // 밝은 사진 위에 흰 체크박스가 놓이면 안 보입니다.
              // 반투명 바탕을 깔아 어떤 그림 위에서도 보이게 합니다.
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              child: Checkbox(
                value: isSelected,

                // 체크박스를 눌렀을 때도 카드를 눌렀을 때와 똑같이 동작합니다.
                // 값 자체는 안 쓰지만 Checkbox가 넘겨주기 때문에 받아만 둡니다.
                onChanged: (bool? _) => onSelectToggle(),
              ),
            ),
          ),
      ],
    );
  }

  /// 카드의 그림만 만듭니다.
  ///
  /// 유튜브도 이미지와 같은 길을 지납니다. 썸네일을 **내려받아 파일로 저장해두기**
  /// 때문입니다. 그래서 인터넷이 끊겨도 목록은 그대로 보입니다.
  Widget _buildThumbnail(ColorScheme colors) {
    // 경로를 아직 못 구했거나 파일 이름이 없으면 자리표시자를 보여줍니다.
    // 유튜브인데 썸네일을 못 받아온 경우도 여기로 옵니다.
    if (item.type == ReferenceType.youtube && imagePath == null) {
      return _buildPlaceholder(colors, Icons.smart_display_outlined);
    }

    if (imagePath == null) {
      return _buildPlaceholder(colors, Icons.image_outlined);
    }

    return Image.file(
      File(imagePath!),
      fit: BoxFit.cover,

      // 파일이 지워졌거나 깨졌을 때 앱이 죽지 않도록 대비합니다.
      // 이게 없으면 파일 하나가 잘못돼도 목록 전체가 빨간 오류 화면이 됩니다.
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        return _buildPlaceholder(colors, Icons.broken_image_outlined);
      },
    );
  }

  /// 그림을 못 보여줄 때 대신 띄우는 회색 상자입니다.
  Widget _buildPlaceholder(ColorScheme colors, IconData icon) {
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(icon, size: 40, color: colors.onSurfaceVariant),
      ),
    );
  }
}
