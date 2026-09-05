// 레퍼런스를 메이슨리(벽돌 쌓기) 격자로 늘어놓는 곳입니다.
//
// home_screen.dart에서 뺐습니다(CLAUDE.md "밀린 정리거리" 참고). 카드 하나를
// 어떻게 그리는지는 reference_card.dart가 이미 알고 있고, 이 파일은
// "카드를 몇 칸으로, 어떤 순서로 늘어놓을지"만 압니다.

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../models/enums.dart';
import '../models/reference_item.dart';
import '../screens/home_hover_preview_controller.dart' show supportsHoverPreview;
import '../theme/app_metrics.dart';
import 'reference_card.dart';

/// 레퍼런스 목록을 메이슨리 격자로 보여줍니다.
class ReferenceGrid extends StatelessWidget {
  const ReferenceGrid({
    super.key,
    required this.items,
    required this.imagePaths,
    required this.taxonomyNames,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.previewingItemId,
    required this.previewUrl,
    required this.onDelete,
    required this.onTap,
    required this.onSelectToggle,
    required this.onPlay,
    required this.onHoverChanged,
  });

  /// 보여줄 레퍼런스 목록입니다.
  final List<ReferenceItem> items;

  /// 각 레퍼런스의 이미지 파일 전체 경로입니다. (레퍼런스 id → 경로)
  final Map<String, String> imagePaths;

  /// 분류 항목 id를 이름으로 바꿔주는 표입니다. (id → 이름)
  final Map<String, String> taxonomyNames;

  /// 지금 여러 장 고르는 중인지 여부입니다.
  final bool isSelectionMode;

  /// 지금 골라둔 레퍼런스들의 id입니다.
  final Set<String> selectedIds;

  /// 지금 미리보기 영상을 틀고 있는 카드의 id입니다. 없으면 null입니다.
  final String? previewingItemId;

  /// 미리보기 영상을 띄울 주소입니다. 없으면 null입니다.
  final String? previewUrl;

  /// 카드의 삭제 버튼을 눌렀을 때 실행할 동작입니다.
  final ValueChanged<ReferenceItem> onDelete;

  /// 카드를 눌렀을 때 실행할 동작입니다. (편집 화면 열기)
  final ValueChanged<ReferenceItem> onTap;

  /// 카드를 고르거나 고르기를 취소할 때 실행할 동작입니다.
  final ValueChanged<ReferenceItem> onSelectToggle;

  /// 재생 버튼을 눌렀을 때 실행할 동작입니다.
  final ValueChanged<ReferenceItem> onPlay;

  /// 마우스가 카드에 올라오거나 벗어났을 때 실행할 동작입니다.
  final void Function(ReferenceItem item, bool isHovering) onHoverChanged;

  @override
  Widget build(BuildContext context) {
    // ── 왜 메이슨리(벽돌 쌓기) 격자인가 ──
    // 보통의 격자는 칸 크기가 정해져 있어서 사진을 그 크기에 맞춰 **잘라냅니다.**
    // 레퍼런스를 모으는 앱에서 사진을 네모로 잘라버리면 구도가 사라집니다.
    //
    // 메이슨리는 칸의 **너비만** 정하고 높이는 사진이 정합니다. 그래서 세로
    // 사진은 길쭉하게, 가로 사진은 납작하게 원본 비율 그대로 쌓입니다.
    // 기존 웹앱이 `column-count`로 하던 것과 같은 모양입니다.
    return MasonryGridView.extent(
      // 아래쪽 여백을 크게 준 이유: 안 그러면 마지막 줄의 카드가
      // 오른쪽 아래 떠 있는 추가 버튼에 가려집니다.
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),

      // maxCrossAxisExtent = "칸 하나의 최대 너비".
      // 개수를 고정하지 않고 너비를 정하면, 창을 넓히면 칸이 늘어나고
      // 폰처럼 좁은 화면에서는 저절로 줄어듭니다. 화면 크기별로 따로
      // 만들지 않아도 되어서 데스크톱과 모바일을 함께 지원하기 좋습니다.
      //
      // 기존 웹앱은 1240px에서 4칸이었습니다. 300px로 잡으면 얼추 같아집니다.
      maxCrossAxisExtent: gridMaxCrossAxisExtent,
      crossAxisSpacing: gridSpacing,
      mainAxisSpacing: gridSpacing,

      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final ReferenceItem item = items[index];
        // 호버 미리보기는 **유튜브 카드**에만, **데스크톱에서만** 붙입니다.
        // null을 넘기면 카드가 호버를 아예 살피지 않습니다.
        final bool canPreview =
            supportsHoverPreview && item.type == ReferenceType.youtube;

        return ReferenceCard(
          item: item,
          imagePath: imagePaths[item.id],
          onDelete: () => onDelete(item),
          onTap: () => onTap(item),
          isSelectionMode: isSelectionMode,
          isSelected: selectedIds.contains(item.id),
          onSelectToggle: () => onSelectToggle(item),
          onPlay: () => onPlay(item),
          onHoverChanged: canPreview
              ? (bool isHovering) => onHoverChanged(item, isHovering)
              : null,
          isPreviewPlaying: previewingItemId == item.id,
          previewUrl: previewUrl,
          taxonomyNames: taxonomyNames,
        );
      },
    );
  }
}
