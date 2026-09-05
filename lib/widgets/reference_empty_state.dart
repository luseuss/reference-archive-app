// 레퍼런스가 하나도 안 보일 때(목록이 비었거나 필터에 걸린 것이 없을 때)
// 보여주는 안내입니다.
//
// home_screen.dart에서 뺐습니다(CLAUDE.md "밀린 정리거리" 참고). 상태
// 없이 "지금 필터가 걸려 있는지"와 콜백 하나만 받는 순수한 안내
// 화면이라 그대로 옮길 수 있었습니다.

import 'package:flutter/material.dart';

import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';

/// 보여줄 레퍼런스가 없을 때의 안내입니다.
///
/// **"아직 아무것도 없음"과 "조건에 맞는 게 없음"을 구분해서 보여줍니다.**
/// 사진이 100장 있는데 "아직 없습니다"라고 하면 사용자가 데이터가 날아간 줄 알고,
/// 반대로 하나도 없는데 "조건에 맞는 게 없다"고 하면 있지도 않은 조건을
/// 지우려고 헤매게 됩니다.
class ReferenceEmptyState extends StatelessWidget {
  const ReferenceEmptyState({
    super.key,
    required this.isFiltered,
    required this.onClearFilter,
  });

  /// 지금 검색어·필터가 하나라도 걸려 있는지 여부입니다.
  final bool isFiltered;

  /// "조건 지우기" 버튼을 눌렀을 때 실행할 동작입니다. [isFiltered]가
  /// 거짓이면 이 버튼 자체가 안 보이므로 안 불립니다.
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(screenPaddingHorizontal),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              isFiltered ? Icons.search_off : Icons.photo_library_outlined,
              size: 64,

              // 아이콘까지 강조색이면 시선을 너무 끕니다. 안내는 거들 뿐이라
              // 옅게 두고, 눌러야 할 버튼만 또렷하게 남깁니다.
              color: palette.textDim,
            ),
            const SizedBox(height: 24),
            Text(
              isFiltered ? '조건에 맞는 레퍼런스가 없습니다' : '아직 모아둔 레퍼런스가 없습니다',
              style: AppText.emptyTitle.copyWith(color: palette.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isFiltered ? '검색어나 필터를 바꿔보세요.' : '오른쪽 아래 버튼으로 이미지를 추가해보세요.',
              style: AppText.emptyBody.copyWith(color: palette.textDim),
              textAlign: TextAlign.center,
            ),
            if (isFiltered) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onClearFilter,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('조건 지우기'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
