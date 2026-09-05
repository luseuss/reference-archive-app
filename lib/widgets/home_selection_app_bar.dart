// 목록 화면에서 "여러 장 고르기" 중일 때 나오는 위쪽 막대입니다.
//
// home_screen.dart에서 뺐습니다(CLAUDE.md "밀린 정리거리" 참고). 상태
// 없이 값(선택 개수·전체 개수)과 콜백만 받는 순수한 조각이라 그대로
// 옮길 수 있었습니다.

import 'package:flutter/material.dart';

/// 고르는 중일 때의 위쪽 막대입니다.
///
/// 색과 내용을 통째로 바꿔서 "지금은 평소와 다른 모드"임을 분명히 합니다.
class HomeSelectionAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const HomeSelectionAppBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.onExit,
    required this.onToggleSelectAll,
  });

  /// 지금 골라둔 개수입니다.
  final int selectedCount;

  /// 지금 보이는 레퍼런스 전체 개수입니다. 전체선택/해제 버튼 판정에 씁니다.
  final int totalCount;

  /// 왼쪽 X 버튼(고르기 끝내기)을 눌렀을 때 실행할 동작입니다.
  final VoidCallback onExit;

  /// 오른쪽 전체선택/해제 버튼을 눌렀을 때 실행할 동작입니다.
  ///
  /// 보이는 레퍼런스가 하나도 없으면 이 버튼 자체가 잠깁니다(null과
  /// 같은 뜻이 아니라, 화면이 `totalCount == 0`일 때 이 콜백을 부르지
  /// 않는 것으로 처리합니다 — 아래 build() 참고).
  final VoidCallback onToggleSelectAll;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    final bool allSelected = totalCount > 0 && selectedCount == totalCount;

    return AppBar(
      backgroundColor: colors.primaryContainer,
      foregroundColor: colors.onPrimaryContainer,

      // 왼쪽 X 버튼으로 고르기를 끝냅니다.
      leading: IconButton(
        onPressed: onExit,
        icon: const Icon(Icons.close),
        tooltip: '고르기 끝내기',
      ),

      title: Text(
        selectedCount == 0 ? '고를 카드를 눌러주세요' : '$selectedCount장 선택',
      ),

      actions: <Widget>[
        IconButton(
          onPressed: totalCount == 0 ? null : onToggleSelectAll,
          icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
          tooltip: allSelected ? '전체 해제' : '전체 선택',
        ),
      ],
    );
  }
}
