// 레퍼런스 카드의 그림 아래쪽, 글자로 된 부분입니다.
//
// reference_card.dart에서 뺐습니다(CLAUDE.md "밀린 정리거리" 참고).
// 카드 조립·그림 부분과는 성격이 다른 관심사(제목·폴더·카테고리·태그·
// 메모·날짜를 어떻게 늘어놓을지)라 나눌 수 있었습니다.

import 'package:flutter/material.dart';

import '../models/reference_item.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';
import '../utils/date_format.dart';
import '../utils/rich_text_memo.dart';

/// 카드의 그림 아래쪽, 글자로 된 부분을 통째로 만듭니다.
///
/// 위에서부터 제목 → 폴더 → 카테고리 → 태그 → 메모 → 날짜·삭제 순입니다.
/// **없는 항목은 아예 자리를 차지하지 않습니다.** 폴더도 태그도 메모도 없는
/// 레퍼런스가 흔한데, 빈 줄이 남으면 카드마다 높이가 들쭉날쭉해집니다.
class ReferenceCardBody extends StatelessWidget {
  const ReferenceCardBody({
    super.key,
    required this.item,
    required this.taxonomyNames,
    required this.isSelectionMode,
    required this.onDelete,
  });

  /// 보여줄 레퍼런스입니다.
  final ReferenceItem item;

  /// 분류 항목 id를 이름으로 바꿔주는 표입니다. (id → 이름)
  final Map<String, String> taxonomyNames;

  /// 지금 여러 장 고르는 중인지 여부입니다.
  ///
  /// 고르는 중에는 낱장 삭제 버튼을 숨깁니다. 여러 장을 고르는 중에
  /// 실수로 한 장만 지우면 당황스럽고, 지우는 방법은 아래 작업 막대에
  /// 이미 있습니다.
  final bool isSelectionMode;

  /// 삭제 버튼을 눌렀을 때 실행할 동작입니다.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

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
