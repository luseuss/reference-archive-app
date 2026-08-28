// 무드보드에서 여러 장을 골랐을 때 화면 아래에 뜨는 작은 띠입니다.
// (5단계 마퀴 다중선택, 6단계 정렬·분배 툴바)
//
// "몇 장 골랐는지", 정렬 6개, 크기 맞추기, 선택 삭제 버튼이 있습니다.
// 그룹화는 아직 없습니다(5단계에서 다음으로 미뤄뒀습니다).

import 'package:flutter/material.dart';

import '../theme/app_metrics.dart';
import '../theme/app_text.dart';
import '../utils/board_align.dart';

/// 무드보드 선택 상태를 보여주는 띠입니다.
class BoardSelectionBar extends StatelessWidget {
  const BoardSelectionBar({
    super.key,
    required this.count,
    required this.onAlign,
    required this.onMatchSize,
    required this.onRemoveSelected,
    required this.onClearSelection,
  });

  /// 지금 골라진 카드 수입니다. 0이면 이 위젯을 아예 안 그리는 것이
  /// 부르는 쪽(board_screen.dart)의 책임입니다.
  final int count;

  /// 정렬 버튼 중 하나를 눌렀을 때 실행할 동작입니다.
  ///
  /// **2장 이상 골랐을 때만** 뜻이 있습니다. 1장이면 정렬·크기맞추기
  /// 버튼을 아예 눌러지지 않게(disabled) 만듭니다 — 눌러도 아무 일이
  /// 안 일어나는 버튼보다, 처음부터 못 누르게 하는 편이 헷갈리지 않습니다.
  final ValueChanged<BoardAlignMode> onAlign;

  /// "크기 맞추기"를 눌렀을 때 실행할 동작입니다.
  final VoidCallback onMatchSize;

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

    // 정렬·크기맞추기는 2장 이상일 때만 뜻이 있습니다.
    final bool canAlign = count >= 2;

    // Material로 감싸면 그림자가 지고 버튼의 물결 효과가 나옵니다.
    // 판 위에 얹히는 것이라 바탕이 뚜렷해야 카드와 섞이지 않습니다.
    // (board_zoom_controls.dart와 같은 이유입니다)
    return Material(
      color: colors.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(buttonCornerRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '$count개 선택됨',
                style: AppText.meta.copyWith(color: colors.onSurface),
              ),
            ),

            _divider(colors),

            // ── 가로 정렬 세 개 ──
            //
            // ── 왜 align_horizontal_*가 아니라 format_align_*인가 ──
            // 처음에는 align_horizontal_left/center/right를 썼는데, 위치는
            // 잡히는데(버튼 자리는 있는데) 아이콘이 안 보였습니다. 비교적
            // 나중에 추가된 아이콘이라 이 앱이 쓰는 아이콘 폰트에 그 글자가
            // 없었던 것으로 보입니다. format_align_*는 Flutter 초창기부터
            // 있던 훨씬 오래된 아이콘이라 안전합니다.
            _alignButton(
              icon: Icons.format_align_left,
              tooltip: '왼쪽 정렬',
              enabled: canAlign,
              onPressed: () => onAlign(BoardAlignMode.left),
            ),
            _alignButton(
              icon: Icons.format_align_center,
              tooltip: '가운데 정렬(가로)',
              enabled: canAlign,
              onPressed: () => onAlign(BoardAlignMode.hcenter),
            ),
            _alignButton(
              icon: Icons.format_align_right,
              tooltip: '오른쪽 정렬',
              enabled: canAlign,
              onPressed: () => onAlign(BoardAlignMode.right),
            ),

            _divider(colors),

            // ── 세로 정렬 세 개 ──
            // 같은 이유로 align_vertical_*이 아니라 vertical_align_*을 씁니다.
            _alignButton(
              icon: Icons.vertical_align_top,
              tooltip: '위 정렬',
              enabled: canAlign,
              onPressed: () => onAlign(BoardAlignMode.top),
            ),
            _alignButton(
              icon: Icons.vertical_align_center,
              tooltip: '가운데 정렬(세로)',
              enabled: canAlign,
              onPressed: () => onAlign(BoardAlignMode.vcenter),
            ),
            _alignButton(
              icon: Icons.vertical_align_bottom,
              tooltip: '아래 정렬',
              enabled: canAlign,
              onPressed: () => onAlign(BoardAlignMode.bottom),
            ),

            _divider(colors),

            IconButton(
              onPressed: canAlign ? onMatchSize : null,
              icon: const Icon(Icons.photo_size_select_large),
              tooltip: '크기 맞추기 (맨 위 카드 기준)',
              iconSize: 18,
            ),

            _divider(colors),

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

  /// 정렬 버튼 하나를 만듭니다. 다들 생김새가 같아서 한곳에 모았습니다.
  Widget _alignButton({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      tooltip: tooltip,
      iconSize: 18,
    );
  }

  /// 버튼 묶음 사이를 나누는 세로 실선입니다. (board_zoom_controls.dart와 같은 것)
  Widget _divider(ColorScheme colors) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: colors.outlineVariant,
    );
  }
}
