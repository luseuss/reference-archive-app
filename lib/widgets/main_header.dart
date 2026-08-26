// 본문 맨 위의 머리줄입니다. 의뢰인이 정해준 목업의 ④입니다.
//
//   왼쪽  — 화면 이름과 몇 개인지
//   가운데 — 검색창
//   오른쪽 — 추가 버튼들
//
// 기존 웹앱의 헤더와 같은 구성입니다. 추가 버튼이 여기 있는 것도 원본과 같습니다.
// (예전에는 오른쪽 아래 떠 있는 버튼이었는데 의뢰인이 이리로 옮기기로 정했습니다)

import 'package:flutter/material.dart';

import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';
import 'reference_search_field.dart';

/// 본문 위쪽 머리줄입니다.
class MainHeader extends StatelessWidget {
  const MainHeader({
    super.key,
    required this.itemCount,
    required this.searchController,
    required this.hasSearchText,
    required this.onClearSearch,
    required this.isAdding,
    required this.onAddImages,
    required this.onAddYoutube,
    required this.onOpenMenu,
  });

  /// 지금 목록에 보이는 개수입니다. 제목 아래에 보여줍니다.
  final int itemCount;

  /// 검색 입력창을 다루는 도구입니다.
  final TextEditingController searchController;

  /// 지금 검색어가 들어있는지 여부입니다.
  final bool hasSearchText;

  /// 검색어 지우기를 눌렀을 때 실행할 동작입니다.
  final VoidCallback onClearSearch;

  /// 지금 무언가를 추가하는 중인지 여부입니다. 켜져 있으면 버튼이 잠깁니다.
  final bool isAdding;

  /// 이미지 추가를 눌렀을 때 실행할 동작입니다.
  final VoidCallback onAddImages;

  /// 유튜브 추가를 눌렀을 때 실행할 동작입니다.
  final VoidCallback onAddYoutube;

  /// 사이드바를 꺼내는 메뉴 버튼을 눌렀을 때 실행할 동작입니다.
  ///
  /// null이면 버튼을 안 보여줍니다. 사이드바가 이미 펼쳐져 있는
  /// 넓은 창에서는 필요 없기 때문입니다.
  final VoidCallback? onOpenMenu;

  /// 머리줄의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: screenPaddingHorizontal,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),

      // Wrap을 쓰면 창이 좁아졌을 때 다음 줄로 넘어갑니다.
      // Row로 만들면 폰처럼 좁은 화면에서 화면 밖으로 삐져나가며 오류가 납니다.
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          _buildTitleBlock(context, palette),
          _buildSearchBlock(context),
          _buildAddButtons(),
        ],
      ),
    );
  }

  /// 화면 이름과 개수입니다.
  Widget _buildTitleBlock(BuildContext context, AppPalette palette) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 좁은 창에서만 나오는 사이드바 열기 버튼입니다.
        if (onOpenMenu != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              onPressed: onOpenMenu,
              icon: const Icon(Icons.menu),
              tooltip: '메뉴 열기',
            ),
          ),

        // 제목 왼쪽의 굵은 세로선입니다. 기존 웹앱 헤더에 있던 표시입니다.
        Container(
          width: 4,
          height: 34,
          decoration: BoxDecoration(
            color: palette.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '레퍼런스 아카이브',
              style: AppText.screenTitle.copyWith(color: palette.text),
            ),
            Text(
              '$itemCount개',
              style: AppText.countRow.copyWith(color: palette.accent),
            ),
          ],
        ),
      ],
    );
  }

  /// 가운데 검색창입니다.
  Widget _buildSearchBlock(BuildContext context) {
    // 창 크기에 따라 검색창 너비를 정합니다.
    // 늘 같은 너비로 두면 좁은 창에서 삐져나가고, 넓은 창에서는 허전합니다.
    final double available = MediaQuery.sizeOf(context).width;
    final double searchWidth = available < 700 ? available - 80 : 420;

    return SizedBox(
      width: searchWidth.clamp(180, 520),
      child: ReferenceSearchField(
        controller: searchController,
        hasText: hasSearchText,
        onClear: onClearSearch,
      ),
    );
  }

  /// 오른쪽 추가 버튼들입니다.
  Widget _buildAddButtons() {
    // 추가하는 중에는 null을 넣어 버튼을 잠급니다.
    // Flutter에서는 onPressed가 null이면 버튼이 자동으로 비활성화됩니다.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: isAdding ? null : onAddYoutube,
          icon: const Icon(Icons.smart_display_outlined, size: 18),
          label: const Text('유튜브'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: isAdding ? null : onAddImages,
          icon: isAdding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: Text(isAdding ? '추가하는 중...' : '이미지 추가'),
        ),
      ],
    );
  }
}
