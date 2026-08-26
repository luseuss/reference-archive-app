// 여러 장을 골랐을 때 화면 아래에 뜨는 작업 막대입니다.
//
// 고른 것들을 한꺼번에 폴더로 옮기거나, 태그를 붙이거나, 지웁니다.
//
// 이 막대는 **버튼만 그리고 실제 일은 하지 않습니다.** 눌렀다는 사실만
// 화면(home_screen.dart)에 알려주고, 데이터를 고치는 일은 화면이 합니다.
// 카드(reference_card.dart)와 같은 방식입니다 — 생김새와 하는 일을 갈라두면
// 나중에 어느 한쪽만 고치기 쉽습니다.

import 'package:flutter/material.dart';

/// 고른 항목들에 대한 일괄 작업 막대입니다.
class BulkActionBar extends StatelessWidget {
  const BulkActionBar({
    super.key,
    required this.selectedCount,
    required this.onMoveToFolder,
    required this.onAddTag,
    required this.onDelete,
  });

  /// 지금 고른 개수입니다. 0이면 버튼들이 잠깁니다.
  final int selectedCount;

  /// "폴더 이동"을 눌렀을 때 실행할 동작입니다.
  final VoidCallback onMoveToFolder;

  /// "태그 추가"를 눌렀을 때 실행할 동작입니다.
  final VoidCallback onAddTag;

  /// "삭제"를 눌렀을 때 실행할 동작입니다.
  final VoidCallback onDelete;

  /// 작업 막대의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    // 하나도 안 골랐으면 눌러봐야 할 일이 없으므로 버튼을 잠급니다.
    // Flutter에서는 onPressed에 null을 넣으면 버튼이 저절로 흐려지고 안 눌립니다.
    final bool hasSelection = selectedCount > 0;

    return Material(
      color: colors.surfaceContainerHighest,

      // 그림자를 조금 줘서 목록 위에 떠 있는 막대처럼 보이게 합니다.
      elevation: 8,

      // SafeArea = 폰의 홈 바나 노치에 버튼이 가려지지 않게 하는 여백입니다.
      // 데스크톱에서는 여백이 0이라 아무 영향이 없습니다.
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: <Widget>[
              _buildAction(
                context: context,
                icon: Icons.drive_file_move_outlined,
                label: '폴더 이동',
                onPressed: hasSelection ? onMoveToFolder : null,
              ),
              _buildAction(
                context: context,
                icon: Icons.new_label_outlined,
                label: '태그 추가',
                onPressed: hasSelection ? onAddTag : null,
              ),
              _buildAction(
                context: context,
                icon: Icons.delete_outline,
                label: '삭제',
                onPressed: hasSelection ? onDelete : null,

                // 삭제는 되돌리기 번거로운 동작이라 색으로 구분해둡니다.
                color: colors.error,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 막대 안의 버튼 하나를 만듭니다.
  ///
  /// 아이콘을 위, 글자를 아래에 두는 이유: 폰처럼 좁은 화면에서 셋을 가로로
  /// 늘어놓으면 "폴더 이동" 같은 글자가 잘립니다.
  Widget _buildAction({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    // Expanded로 감싸면 세 버튼이 가로 폭을 똑같이 나눠 가집니다.
    return Expanded(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(foregroundColor: color),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
