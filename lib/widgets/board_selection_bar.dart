// 무드보드에서 여러 장을 골랐을 때 화면 아래에 뜨는 작은 띠입니다.
// (5단계 마퀴 다중선택)
//
// "몇 장 골랐는지"와 "선택 삭제" 버튼만 있습니다. 정렬·분배·그룹화는
// 다음 단계 몫이라 여기 없습니다.

import 'package:flutter/material.dart';

import '../theme/app_metrics.dart';
import '../theme/app_text.dart';

/// 무드보드 선택 상태를 보여주는 띠입니다.
class BoardSelectionBar extends StatelessWidget {
  const BoardSelectionBar({
    super.key,
    required this.count,
    required this.onRemoveSelected,
    required this.onClearSelection,
  });

  /// 지금 골라진 카드 수입니다. 0이면 이 위젯을 아예 안 그리는 것이
  /// 부르는 쪽(board_screen.dart)의 책임입니다.
  final int count;

  /// "선택 삭제"를 눌렀을 때 실행할 동작입니다.
  final VoidCallback onRemoveSelected;

  /// "×"(선택 지우기)를 눌렀을 때 실행할 동작입니다.
  ///
  /// 판에서 카드를 내리는 것이 아니라, **고른 것만 풀어주는** 버튼입니다.
  /// 빈 곳을 클릭해도 같은 일이 일어나지만, 마우스를 옮기지 않고 바로
  /// 누를 수 있는 자리에 하나 더 둡니다.
  final VoidCallback onClearSelection;

  /// 띠의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    // Material로 감싸면 그림자가 지고 버튼의 물결 효과가 나옵니다.
    // 판 위에 얹히는 것이라 바탕이 뚜렷해야 카드와 섞이지 않습니다.
    // (board_zoom_controls.dart와 같은 이유입니다)
    return Material(
      color: colors.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(buttonCornerRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '$count개 선택됨',
              style: AppText.meta.copyWith(color: colors.onSurface),
            ),

            const SizedBox(width: 8),

            TextButton.icon(
              onPressed: onRemoveSelected,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('선택 삭제'),
              style: TextButton.styleFrom(foregroundColor: colors.error),
            ),

            IconButton(
              onPressed: onClearSelection,
              icon: const Icon(Icons.close),
              tooltip: '선택 지우기',
              iconSize: 18,
            ),
          ],
        ),
      ),
    );
  }
}
