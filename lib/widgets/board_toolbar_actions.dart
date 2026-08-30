// 무드보드 화면 위쪽 AppBar에 뜨는 버튼 세 개(격자 토글·이미지로 내보내기·
// 레퍼런스 담기)를 한데 모은 위젯입니다.
//
// ── 왜 board_screen.dart에서 뺐나 ──
// 버튼 세 개 모두 "무엇을 누를 수 있는지"를 컨트롤러 상태(카드가 있는지,
// 읽어오는 중인지, 내보내는 중인지…)에서 매번 다시 계산해야 해서, 코드
// 자체는 짧아도 줄 수는 꽤 됩니다. board_screen.dart는 화면을 조립하는
// 일만 하게 두고, "버튼이 어떤 모양·상태여야 하는지"는 여기로 옮겼습니다.
//
// 이 위젯은 카드를 담거나 내보내는 **동작 자체는 하지 않습니다.**
// [onAddCards]/[onExport] 콜백으로 board_screen.dart에 알리기만 합니다 —
// 대화상자를 여는 일(레퍼런스 담기)과 저장 대화상자를 여는 일(내보내기)에
// `context`가 필요한데, 그 context는 board_screen.dart가 더 오래, 더
// 안정적으로 들고 있기 때문입니다.

import 'package:flutter/material.dart';

import '../screens/board_export_controller.dart';
import '../screens/board_interaction_controller.dart';

/// 무드보드 화면 위쪽 AppBar의 액션 버튼들입니다.
class BoardToolbarActions extends StatelessWidget {
  const BoardToolbarActions({
    super.key,
    required this.isLoading,
    required this.interaction,
    required this.export,
    required this.onExport,
    required this.onAddCards,
  });

  /// 판을 아직 읽어오는 중인지 여부입니다. 읽어오는 동안은 어떤 버튼도
  /// 눌러도 뜻이 없습니다(카드 목록이 아직 안 정해졌습니다).
  final bool isLoading;

  /// 카드를 잡고, 옮기고, 크기를 바꾸는 일을 맡는 컨트롤러입니다.
  /// 여기서는 격자 스냅 상태와 카드가 있는지만 봅니다.
  final BoardInteractionController interaction;

  /// 이미지로 내보내는 중인지 상태만 봅니다. 실제로 내보내는 일은
  /// [onExport]를 통해 board_screen.dart가 합니다.
  final BoardExportController export;

  /// 이미지로 내보내기 버튼을 눌렀을 때 알려줍니다.
  final VoidCallback onExport;

  /// 레퍼런스 담기 버튼을 눌렀을 때 알려줍니다.
  final VoidCallback onAddCards;

  @override
  Widget build(BuildContext context) {
    // interaction과 export, 두 컨트롤러 중 어느 쪽이 바뀌어도 다시
    // 그려야 합니다(예: 카드가 담겨서 interaction이 바뀌거나, 내보내기가
    // 끝나서 export가 바뀌거나). Listenable.merge로 둘을 하나로 묶습니다.
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[interaction, export]),
      builder: (BuildContext context, Widget? child) {
        final bool canExport =
            !isLoading && !export.isExporting && interaction.cards.isNotEmpty;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 격자 스냅 토글. **카드끼리 붙는 것은 항상 켜져 있고**
            // 이 버튼은 격자만 다룹니다. 눌린 상태를 색으로 보여줍니다 —
            // 안 그러면 지금 켜졌는지 꺼졌는지 알 방법이 없어서 눌러보고
            // 카드를 끌어봐야 합니다.
            IconButton(
              onPressed: isLoading ? null : interaction.toggleGridSnap,
              icon: const Icon(Icons.grid_4x4),
              isSelected: interaction.gridSnap,
              tooltip: interaction.gridSnap ? '격자에 맞추기 끄기' : '격자에 맞추기',
            ),

            // 이미지로 내보내기. 카드가 없으면 눌러도 뜻이 없어서 막아둡니다.
            IconButton(
              onPressed: canExport ? onExport : null,
              icon: export.isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_alt),
              tooltip: '이미지로 내보내기',
            ),

            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                onPressed: isLoading ? null : onAddCards,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('레퍼런스 담기'),
              ),
            ),
          ],
        );
      },
    );
  }
}
