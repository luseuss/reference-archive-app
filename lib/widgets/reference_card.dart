// 목록에 보이는 레퍼런스 카드 한 장입니다.
//
// 화면(screens/) 파일이 너무 길어지지 않도록 카드 한 장의 생김새는 여기로 뺐습니다.
// 나중에 카드에 즐겨찾기 별표나 태그 표시를 붙일 때도 이 파일만 보면 됩니다.
//
// 이 파일 자체도 300줄 기준을 넘어서(CLAUDE.md "밀린 정리거리" 참고),
// 그림 부분은 reference_card_thumbnail.dart로, 호버 효과는 hover_lift.dart로
// 뺐습니다. 이 파일에는 카드 본체 조립과 제목·폴더·태그·메모·날짜가 있는
// 아래쪽 글자 부분(_buildBody)만 남아 있습니다.

import 'package:flutter/material.dart';

import '../models/reference_item.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';
import '../utils/date_format.dart';
import '../utils/rich_text_memo.dart';
import 'hover_lift.dart';
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

    return AnimatedContainer(
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

            _buildBody(palette),
          ],
        ),
      ),
    );
  }

  /// 카드의 그림 아래쪽, 글자로 된 부분을 통째로 만듭니다.
  ///
  /// 위에서부터 제목 → 폴더 → 카테고리 → 태그 → 메모 → 날짜·삭제 순입니다.
  /// **없는 항목은 아예 자리를 차지하지 않습니다.** 폴더도 태그도 메모도 없는
  /// 레퍼런스가 흔한데, 빈 줄이 남으면 카드마다 높이가 들쭉날쭉해집니다.
  Widget _buildBody(AppPalette palette) {
    // 메모는 서식이 붙은 Delta(JSON)일 수 있습니다. 카드 미리보기는
    // 글자만 보여주면 되므로 서식을 뺀 plainTextFromMemo를 거칩니다
    // (utils/rich_text_memo.dart). 아래에서 "보여줄지 말지"와 "무엇을
    // 보여줄지" 둘 다에 쓰이므로 한 번만 계산해 변수에 담아둡니다.
    final String memoPreview = plainTextFromMemo(item.memo);

    return Padding(
      // 기존 웹앱의 `.card-body { padding: 13px 14px 14px; }` 와 같습니다.
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildTitleRow(palette),

          // 폴더는 옅게, 카테고리는 강조색으로 보여줍니다.
          // 기존 웹앱이 그렇게 구분해뒀습니다 — 카테고리가 더 중요한 분류입니다.
          if (_nameOf(item.folderId) != null)
            _bodyGap(
              Text(
                '📁 ${_nameOf(item.folderId)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.cardFolder.copyWith(color: palette.textDim),
              ),
            ),

          if (_nameOf(item.categoryId) != null)
            _bodyGap(
              Text(
                '🏷 ${_nameOf(item.categoryId)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.cardCategory.copyWith(color: palette.accent),
              ),
            ),

          if (_tagNames().isNotEmpty) _bodyGap(_buildTags(palette)),

          if (memoPreview.isNotEmpty)
            _bodyGap(
              Text(
                memoPreview,
                // 메모가 길어도 카드가 한없이 길어지지 않게 세 줄로 자릅니다.
                // 전체는 편집 화면에서 봅니다.
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.cardMemo.copyWith(color: palette.textDim),
              ),
            ),

          _buildFoot(palette),
        ],
      ),
    );
  }

  /// 본문 항목 사이의 간격을 붙여줍니다. (웹앱의 `gap: 7px`)
  ///
  /// 항목마다 `SizedBox(height: 7)`를 손으로 넣으면, 항목이 없을 때 빈칸만
  /// 남거나 반대로 붙어버리는 실수를 하게 됩니다. 여기서 한 번에 처리합니다.
  Widget _bodyGap(Widget child) {
    return Padding(padding: const EdgeInsets.only(top: 7), child: child);
  }

  /// 제목 줄입니다. 고정·즐겨찾기 표시가 있으면 앞에 붙습니다.
  Widget _buildTitleRow(AppPalette palette) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 고정·즐겨찾기 표시는 켜져 있을 때만 보입니다.
        if (item.isPinned)
          Padding(
            padding: const EdgeInsets.only(right: 4, top: 2),
            child: Icon(Icons.push_pin, size: 14, color: palette.accent),
          ),
        if (item.isFavorite)
          Padding(
            padding: const EdgeInsets.only(right: 4, top: 2),
            child: Icon(Icons.star, size: 14, color: palette.accent),
          ),
        Expanded(
          child: Text(
            item.title.isEmpty ? '(제목 없음)' : item.title,

            // 제목이 길면 카드를 밀어내지 않고 두 줄까지만 보여줍니다.
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.cardTitle.copyWith(color: palette.text),
          ),
        ),
      ],
    );
  }

  /// 태그들을 작은 알약 모양으로 늘어놓습니다.
  Widget _buildTags(AppPalette palette) {
    // Wrap = 한 줄에 다 못 들어가면 다음 줄로 넘겨주는 배치입니다.
    // Row로 하면 태그가 많을 때 화면 밖으로 넘쳐 오류가 납니다.
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: <Widget>[
        for (final String name in _tagNames())
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: palette.tagBackground,
              borderRadius: BorderRadius.circular(tagCornerRadius),
            ),
            child: Text(
              '#$name',
              style: AppText.tag.copyWith(color: palette.textDim),
            ),
          ),
      ],
    );
  }

  /// 카드 맨 아래 줄입니다. 왼쪽에 날짜, 오른쪽에 삭제입니다.
  Widget _buildFoot(AppPalette palette) {
    return Container(
      margin: const EdgeInsets.only(top: 11),
      padding: const EdgeInsets.only(top: 8),

      // 위쪽에 실선 하나로 본문과 나눕니다. (웹앱의 `.card-foot` 테두리)
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            formatCardDate(item.createdAt),
            style: AppText.meta.copyWith(color: palette.textDim),
          ),

          // 고르기 모드에서는 낱장 삭제 버튼을 숨깁니다.
          // 여러 장을 고르는 중에 실수로 한 장만 지우면 당황스럽고,
          // 지우는 방법은 아래 작업 막대에 이미 있습니다.
          if (!isSelectionMode)
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  '삭제',
                  style: AppText.meta.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.textDim,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 분류 항목 id를 이름으로 바꿉니다. 없으면 null입니다.
  ///
  /// 레퍼런스에는 id만 들어있어서 그대로 보여줄 수 없습니다.
  /// 이름 목록은 화면에서 만들어 넘겨줍니다.
  String? _nameOf(String? taxonomyItemId) {
    if (taxonomyItemId == null) {
      return null;
    }
    return taxonomyNames[taxonomyItemId];
  }

  /// 이 레퍼런스에 붙은 태그 이름들을 돌려줍니다.
  ///
  /// 이름을 못 찾은 것은 건너뜁니다. 분류를 지운 직후처럼 잠깐 어긋날 수
  /// 있는데, 그때 빈 알약이 뜨는 것보다 안 보이는 편이 낫습니다.
  List<String> _tagNames() {
    final List<String> names = <String>[];

    for (final String tagId in item.tagIds) {
      final String? name = taxonomyNames[tagId];
      if (name != null) {
        names.add(name);
      }
    }

    return names;
  }
}
