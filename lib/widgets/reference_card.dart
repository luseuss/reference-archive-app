// 목록에 보이는 레퍼런스 카드 한 장입니다.
//
// 화면(screens/) 파일이 너무 길어지지 않도록 카드 한 장의 생김새는 여기로 뺐습니다.
// 나중에 카드에 즐겨찾기 별표나 태그 표시를 붙일 때도 이 파일만 보면 됩니다.
//
// 이 파일 자체도 300줄 기준을 넘어서(CLAUDE.md "밀린 정리거리" 참고),
// 그림 부분은 reference_card_thumbnail.dart로, 아래쪽 글자 부분은
// reference_card_body.dart로, 호버 효과는 hover_lift.dart로 뺐습니다.
// 이 파일에는 이제 카드 본체(테두리·그림자·클릭) 조립만 남아 있습니다.

import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../models/reference_item.dart';
import '../services/board_window_sync.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../utils/reference_drag_payload.dart';
import 'hover_lift.dart';
import 'reference_card_body.dart';
import 'reference_card_thumbnail.dart';

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
    this.onHoverChanged,
    this.isPreviewPlaying = false,
    this.previewUrl,
    this.taxonomyNames = const <String, String>{},
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

  /// 마우스가 이 카드에 올라오거나 벗어났을 때 알려줍니다.
  ///
  /// null이면 호버를 아예 살피지 않습니다. 폰·태블릿에는 마우스가 없어서
  /// 화면 쪽에서 null을 넘깁니다.
  final ValueChanged<bool>? onHoverChanged;

  /// 지금 이 카드에서 미리보기 영상을 틀고 있는지 여부입니다.
  final bool isPreviewPlaying;

  /// 분류 항목 id를 이름으로 바꿔주는 표입니다. (id → 이름)
  ///
  /// 레퍼런스에는 폴더·카테고리·태그가 **id로만** 들어있습니다. 카드가 직접
  /// 데이터베이스를 뒤져 이름을 찾으면, 카드를 그릴 때마다 조회가 일어나
  /// 목록이 버벅입니다. 그래서 화면이 한 번 만들어 넘겨줍니다.
  final Map<String, String> taxonomyNames;

  /// 미리보기 영상을 띄울 주소입니다. 없으면 null입니다.
  ///
  /// 카드가 주소를 직접 만들지 않습니다. 어느 카드에서 틀지 정하는 일은
  /// 화면(home_screen.dart)이 하고, 카드는 받은 것을 보여주기만 합니다.
  final String? previewUrl;

  /// 카드의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    // 마우스를 올렸는지는 카드마다 따로 기억합니다. 화면 전체가 기억하면
    // 카드 하나에 마우스가 스칠 때마다 목록 전체를 다시 그리게 됩니다.
    return HoverLift(
      onHoverChanged: onHoverChanged,
      builder: (BuildContext context, bool isHovered) {
        return _buildCard(context, isHovered);
      },
    );
  }

  /// 카드 본체를 만듭니다.
  ///
  /// ── Card 위젯을 안 쓰고 직접 그리는 이유 ──
  /// 기존 웹앱의 카드는 **얇은 테두리 + 두 겹 그림자**입니다. Flutter의 Card는
  /// elevation 하나로 그림자를 만들기 때문에 이 모양이 안 나옵니다.
  /// 그래서 Container에 테두리와 그림자를 직접 그립니다.
  Widget _buildCard(BuildContext context, bool isHovered) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppPalette palette = AppPalette.of(context);

    final Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,

      // 마우스를 올리면 살짝 떠오릅니다. 기존 웹앱의 translateY(-2px)와 같습니다.
      transform: Matrix4.translationValues(0, isHovered ? -2 : 0, 0),

      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(appCornerRadius),

        // 골라둔 카드는 강조색 테두리로 한눈에 구분되게 합니다.
        // 체크박스만으로는 카드가 많을 때 어느 걸 골랐는지 알아보기 어렵습니다.
        border: Border.all(
          color: isSelected ? colors.primary : palette.border,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isHovered ? palette.cardShadowHovered : palette.cardShadow,
      ),

      // 그림이 둥근 모서리 밖으로 삐져나오지 않게 잘라냅니다.
      clipBehavior: Clip.antiAlias,

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

          // ── 카드 높이는 내용이 정합니다 ──
          // 예전에는 카드 높이를 격자가 정해주고 그림을 Expanded로 늘렸습니다.
          // 지금은 반대입니다. **그림이 원본 비율대로 높이를 정하고**, 카드가
          // 거기에 맞춰집니다. 그래서 세로 사진은 길쭉한 카드가 됩니다.
          mainAxisSize: MainAxisSize.min,

          children: <Widget>[
            ReferenceCardThumbnail(
              item: item,
              imagePath: imagePath,
              isSelectionMode: isSelectionMode,
              isSelected: isSelected,
              onSelectToggle: onSelectToggle,
              onPlay: onPlay,
              isPreviewPlaying: isPreviewPlaying,
              previewUrl: previewUrl,
            ),

            ReferenceCardBody(
              item: item,
              taxonomyNames: taxonomyNames,
              isSelectionMode: isSelectionMode,
              onDelete: onDelete,
            ),
          ],
        ),
      ),
    );

    // 무드보드로 끌어다 놓는 것은 데스크톱에서만 됩니다 — 팝업 창이
    // 있어야 놓을 대상이 생기고, 폰·태블릿은 그 개념 자체가 없습니다
    // (services/board_window_sync.dart의 supportsBoardPopupWindow).
    //
    // 고르기 모드 중에는 감싸지 않습니다. 고르기 모드에서 카드를 누르면
    // "고르기"가 되어야 하는데, 드래그 인식기까지 끼면 살짝 끄는 것만으로
    // 고르기가 씹힐 위험이 생깁니다 — 고르기 모드는 여러 장을 빠르게
    // 토글하는 동작이라 그 위험을 감수할 이유가 없습니다.
    if (!supportsBoardPopupWindow || isSelectionMode) {
      return card;
    }

    return DragItemWidget(
      dragItemProvider: (DragItemRequest request) async {
        final DragItem dragItem = DragItem();
        dragItem.add(Formats.plainText(encodeReferenceDragPayload(item.id)));
        return dragItem;
      },
      allowedOperations: () => <DropOperation>[DropOperation.copy],
      child: DraggableWidget(child: card),
    );
  }
}
