// 무드보드 판 하나를 여는 화면입니다. 판을 읽어오고, 화면에 띄웁니다.
//
// ── 역할 나누기 ──
//   board_interaction_controller.dart — 카드를 **잡고, 옮기고, 크기를
//     바꾸고, 담고, 내리는** 상태와 동작 전부. (2026-08-29에 이 파일에서 뺐습니다)
//   board_export_controller.dart — **이미지로 내보내는** 상태와 동작.
//     (2026-08-31에 이 파일에서 뺐습니다)
//   board_window_controller.dart — 창을 **항상 위**로 띄우는 상태와 동작.
//     (4단계 8번)
//   board_toolbar_actions.dart — 위쪽 AppBar 버튼들(격자·항상 위·내보내기·
//     담기)이 어떤 모양·상태여야 하는지. (2026-08-31에 이 파일에서 뺐습니다)
//   board_viewport.dart      — 판을 확대·축소하고 이동해서 보여줍니다(줌·팬).
//   board_canvas.dart        — 카드를 좌표대로 놓고, 조작을 알아챕니다.
//   board_card_view.dart     — 카드 한 장이 어떻게 생겼는지.
//   board_layout.dart        — 자리와 배율 계산(순수한 셈).
//   이 파일                   — **읽어오고, 화면을 조립합니다.**
//
// ── 카드 조작·내보내기는 왜 다른 파일로 뺐나 ──
// 끌기·크기 조절·스냅은 전부 같은 카드 목록과 몇 가지 값(활성 카드, 안내선
// 자리…)을 함께 건드립니다. 그 상태와 동작을 통째로
// BoardInteractionController로 옮겼습니다. 내보내기도 같은 이유로
// BoardExportController로 옮겼습니다("내보내는 중" 상태와 "찍고 저장하기"
// 동작이 함께 다녀야 합니다). 이 파일은 컨트롤러들을 만들고,
// ListenableBuilder로 감싸 화면에 띄우기만 합니다.
//
// ── "저장" 버튼이 없는 이유 ──
// 손을 떼는 순간 저장되므로 따로 누를 것이 없습니다(저장 자체는
// 컨트롤러가 합니다). 저장 버튼을 두면 사용자는 언제 눌러야 하는지 신경
// 쓰게 되고, 안 누르고 나갔다가 배치를 통째로 잃습니다.

import 'package:flutter/material.dart';

import '../models/board.dart';
import '../repositories/board_repository.dart';
import '../repositories/reference_repository.dart';
import '../services/image_storage.dart';
import '../services/reference_lookup.dart';
import '../utils/board_layout.dart';
import '../widgets/board_canvas.dart';
import '../widgets/board_selection_bar.dart';
import '../widgets/board_toolbar_actions.dart';
import '../widgets/board_viewport.dart';
import '../widgets/empty_state_message.dart';
import '../widgets/pick_references_dialog.dart';
import 'board_export_controller.dart';
import 'board_interaction_controller.dart';
import 'board_window_controller.dart';

/// 무드보드 판 하나를 보여주는 화면입니다.
class BoardScreen extends StatefulWidget {
  const BoardScreen({
    super.key,
    required this.board,
    required this.boardRepository,
    required this.referenceRepository,
    required this.imageStorage,
  });

  /// 지금 열어본 무드보드입니다.
  final Board board;

  /// 무드보드와 카드 배치를 읽고 쓰는 통로입니다.
  final BoardRepository boardRepository;

  /// 레퍼런스를 읽는 통로입니다. 카드가 보여줄 제목과 그림을 여기서 가져옵니다.
  final ReferenceRepository referenceRepository;

  /// 이미지 파일 경로를 알려주는 도구입니다.
  final ImageStorage imageStorage;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  /// 카드를 잡고, 옮기고, 크기를 바꾸고, 담고, 내리는 일을 전부 맡습니다.
  late final BoardInteractionController _interaction;

  /// 판을 이미지로 내보내는 일을 맡습니다.
  final BoardExportController _export = BoardExportController();

  /// 창을 항상 위로 띄우는 일을 맡습니다.
  final BoardWindowController _window = BoardWindowController();

  /// 카드가 보여줄 레퍼런스를 번호로 찾을 수 있게 정리해둔 것입니다.
  ///
  /// 카드에는 번호만 들어있어서, 제목과 그림을 보여주려면 짝을 지어야 합니다.
  /// (services/reference_lookup.dart 설명 참고)
  ReferenceLookup _lookup = const ReferenceLookup.empty();

  /// 보던 화면을 "카드 전부 보기"로 되돌리라고 알리는 숫자입니다.
  ///
  /// 숫자 자체에는 뜻이 없습니다. **1 올리면 되돌아갑니다.**
  /// (BoardViewport의 viewResetCount 설명 참고)
  ///
  /// 레퍼런스를 새로 담을 때 씁니다. 멀리 확대해서 보고 있었다면 새 카드가
  /// 화면 밖에 생겨서 안 담긴 것처럼 보이기 때문입니다.
  int _viewResetCount = 0;

  /// 아직 읽어오는 중인지 여부입니다.
  bool _isLoading = true;

  /// 화면이 만들어질 때 컨트롤러를 준비하고 판의 내용을 읽어옵니다.
  @override
  void initState() {
    super.initState();

    _interaction = BoardInteractionController(
      boardId: widget.board.id,
      boardRepository: widget.boardRepository,
    );

    _loadBoard();

    // 저장해둔 "항상 위" 상태를 불러와 창에 다시 적용합니다. 데스크톱이
    // 아니면(supportsAlwaysOnTopWindow가 거짓이면) 조용히 아무 일도
    // 안 합니다.
    _window.load();
  }

  /// 컨트롤러가 안 쓰는 자원을 붙잡고 있지 않도록 정리합니다.
  @override
  void dispose() {
    _interaction.dispose();
    _export.dispose();
    _window.dispose();
    super.dispose();
  }

  /// 판에 놓인 카드와, 그 카드들이 보여줄 레퍼런스를 읽어옵니다.
  Future<void> _loadBoard() async {
    final List<BoardCard> cards = await widget.boardRepository.getCards(
      widget.board.id,
    );

    final ReferenceLookup lookup = await ReferenceLookup.load(
      repository: widget.referenceRepository,
      imageStorage: widget.imageStorage,
    );

    // 읽어오는 사이에 사용자가 화면을 떠났을 수 있습니다.
    if (!mounted) {
      return;
    }

    _interaction.setCards(cards);

    setState(() {
      _lookup = lookup;
      _isLoading = false;
    });
  }

  /// 레퍼런스를 골라 판에 담습니다.
  ///
  /// 레퍼런스를 고르는 대화상자는 `context`가 필요해서 여기 남아 있습니다.
  /// 고른 번호를 저장하고 목록에 넣는 일은 컨트롤러가 합니다.
  Future<void> _addCards() async {
    final List<String>? pickedIds = await showPickReferencesDialog(
      context: context,
      repository: widget.referenceRepository,
      imageStorage: widget.imageStorage,
      alreadyOnBoard: _interaction.cards
          .map((BoardCard card) => card.referenceId)
          .toSet(),
    );

    if (pickedIds == null || pickedIds.isEmpty || !mounted) {
      return;
    }

    await _interaction.addCards(pickedIds);

    if (!mounted) {
      return;
    }

    // 담은 카드가 화면 밖에 생기면 "안 담겼나?" 싶어집니다.
    // 한 번 전체 보기로 되돌려서 방금 담은 것이 반드시 보이게 합니다.
    setState(() {
      _viewResetCount++;
    });
  }

  /// 판에 놓인 카드 전체를 사진(PNG) 한 장으로 내보냅니다.
  ///
  /// 실제로 찍고 저장하는 일은 [_export]가 합니다. 여기서는 그 결과를
  /// 받아 스낵바 문구만 고릅니다.
  Future<void> _exportBoardImage() async {
    final BoardExportOutcome? outcome = await _export.export(
      context: context,
      boardName: widget.board.name,
      cards: _interaction.cards,
      itemsById: _lookup.itemsById,
      imagePaths: _lookup.imagePaths,
    );

    if (!mounted || outcome == null) {
      return;
    }

    final String? message = switch (outcome) {
      BoardExportOutcome.saved => '이미지를 저장했습니다.',
      BoardExportOutcome.noCards => '내보낼 카드가 없습니다.',

      // 저장 대화상자에서 취소한 것은 실패가 아니라 조용히 넘어갑니다.
      BoardExportOutcome.cancelled => null,
    };

    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// 화면의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.board.name),
        actions: <Widget>[
          BoardToolbarActions(
            isLoading: _isLoading,
            interaction: _interaction,
            export: _export,
            window: _window,
            onExport: _exportBoardImage,
            onAddCards: _addCards,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  /// 화면 가운데 내용을 만듭니다. 상황에 따라 셋 중 하나입니다.
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ListenableBuilder = 컨트롤러가 바뀌면 이 안을 다시 그려주는 위젯입니다.
    // 카드를 끌 때마다 화면 전체(appBar 포함)가 아니라 이 안만 다시 그립니다.
    return ListenableBuilder(
      listenable: _interaction,
      builder: (BuildContext context, Widget? child) {
        final List<BoardCard> cards = _interaction.cards;

        if (cards.isEmpty) {
          return _buildEmptyState();
        }

        // 판에 끝이 없어서, 그릴 자리를 카드에서 구합니다.
        // 카드를 옮기면 이 자리도 따라 움직입니다.
        //
        // 한 번만 구해서 둘에게 나눠줍니다. 각자 구하게 두면 언젠가 한쪽만
        // 고쳐서 상자와 카드가 어긋나게 됩니다.
        final Rect canvasRect = boardCanvasRect(cards);

        // 판을 확대·이동해서 보여주는 일은 BoardViewport가 맡습니다.
        // 카드를 놓고 조작을 알아채는 일만 BoardCanvas가 합니다.
        //
        // 선택 툴바는 Stack으로 그 위에 얹습니다. BoardViewport는 카드가
        // 뭔지 몰라서 "몇 장 골랐는지"를 스스로 그릴 수 없습니다.
        return Stack(
          children: <Widget>[
            BoardViewport(
              canvasRect: canvasRect,
              contentBounds: boardContentBounds(cards),
              viewResetCount: _viewResetCount,
              onMarqueeBegin: ({required bool additive}) =>
                  _interaction.beginMarquee(additive: additive),
              onMarqueeUpdate: _interaction.updateMarquee,
              onMarqueeEnd: _interaction.endMarquee,
              onEmptyTap: ({required bool shiftHeld}) =>
                  _interaction.handleEmptyTap(shiftHeld: shiftHeld),
              child: BoardCanvas(
                cards: cards,
                canvasRect: canvasRect,
                guideX: _interaction.guideX,
                guideY: _interaction.guideY,
                itemsById: _lookup.itemsById,
                imagePaths: _lookup.imagePaths,
                activeCardId: _interaction.activeCardId,
                selectedCardIds: _interaction.selectedCardIds,
                onCardPressed: (BoardCard card, {required bool shiftHeld}) =>
                    _interaction.onCardPressed(card, shiftHeld: shiftHeld),
                onDragStart: _interaction.onDragStart,
                onDragUpdate: _interaction.onDragUpdate,
                onDragEnd: _interaction.onDragEnd,
                onMeasured: _interaction.onCardMeasured,
                onResizeStart: _interaction.onResizeStart,
                onResizeUpdate: _interaction.onResizeUpdate,
                onResizeEnd: _interaction.onResizeEnd,
                onRemoveCard: _interaction.removeCard,
              ),
            ),

            // 카드를 하나라도 골랐을 때만 아래쪽에 떠 있는 선택 띠입니다.
            if (_interaction.selectedCardIds.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: Center(
                  child: BoardSelectionBar(
                    count: _interaction.selectedCardIds.length,
                    onAlign: _interaction.alignSelected,
                    onMatchSize: _interaction.matchSizeSelected,
                    canGroup: _interaction.canGroupSelected,
                    onGroup: _interaction.groupSelected,
                    canUngroup: _interaction.canUngroupSelected,
                    onUngroup: _interaction.ungroupSelected,
                    onRemoveSelected: _interaction.removeSelectedCards,
                    onClearSelection: _interaction.clearSelection,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 아직 판이 비어 있을 때의 안내입니다.
  Widget _buildEmptyState() {
    return EmptyStateMessage(
      icon: Icons.add_photo_alternate_outlined,
      title: '판이 비어 있습니다',
      body: '오른쪽 위 "레퍼런스 담기"로 올린 뒤\n끌어서 원하는 자리에 놓아보세요.',
      action: FilledButton.icon(
        onPressed: _addCards,
        icon: const Icon(Icons.add),
        label: const Text('레퍼런스 담기'),
      ),
    );
  }
}
