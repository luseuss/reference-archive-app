// 무드보드 판 하나를 여는 화면입니다. 카드를 올리고, 끌어서 옮기고, 크기를 바꾸고, 내립니다.
//
// ── 역할 나누기 ──
//   board_viewport.dart      — 판을 확대·축소하고 이동해서 보여줍니다(줌·팬).
//   board_canvas.dart        — 카드를 좌표대로 놓고, 조작을 알아챕니다.
//   board_card_view.dart     — 카드 한 장이 어떻게 생겼는지.
//   board_layout.dart        — 자리와 배율 계산(순수한 셈).
//   board_card_actions.dart  — 옮기기·크기 바꾸기·맨 위로 올리기 규칙(순수한 셈).
//   이 파일                   — **읽어오고, 기억하고, 저장합니다.**
//
// ── 언제 저장하는가 (이 화면에서 가장 중요한 결정) ──
// 카드를 끄는 동안에는 **화면에서만** 위치와 크기를 바꾸고, 손을 뗐을 때 한 번
// 저장합니다. 끄는 동안 매 순간 저장하면 1초에 수십 번 데이터베이스에 쓰게 되어
// 눈에 띄게 버벅입니다.
//
// ── "저장" 버튼이 없는 이유 ──
// 손을 떼는 순간 저장되므로 따로 누를 것이 없습니다. 저장 버튼을 두면 사용자는
// 언제 눌러야 하는지 신경 쓰게 되고, 안 누르고 나갔다가 배치를 통째로 잃습니다.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/board.dart';
import '../repositories/board_repository.dart';
import '../repositories/reference_repository.dart';
import '../services/image_storage.dart';
import '../services/reference_lookup.dart';
import '../utils/board_card_actions.dart';
import '../utils/board_layout.dart';
import '../utils/id_generator.dart';
import '../widgets/board_canvas.dart';
import '../widgets/board_viewport.dart';
import '../widgets/empty_state_message.dart';
import '../widgets/pick_references_dialog.dart';

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
  /// 판에 놓인 카드들입니다. **아래에 깔린 것부터** 순서대로 들어있습니다.
  List<BoardCard> _cards = <BoardCard>[];

  /// 카드가 보여줄 레퍼런스를 번호로 찾을 수 있게 정리해둔 것입니다.
  ///
  /// 카드에는 번호만 들어있어서, 제목과 그림을 보여주려면 짝을 지어야 합니다.
  /// (services/reference_lookup.dart 설명 참고)
  ReferenceLookup _lookup = const ReferenceLookup.empty();

  /// 지금 끌거나 크기를 바꾸고 있는 카드의 번호입니다. 없으면 null입니다.
  String? _activeCardId;

  /// 크기 조절 손잡이를 잡은 순간의 카드 크기입니다. 조절 중이 아니면 null입니다.
  ///
  /// 저장된 값이 아니라 **실제로 그려져 있던 크기**입니다. 카드 높이는 보통
  /// 비어 있어서(= 그림 비율대로) 저장된 값만으로는 알 수 없기 때문입니다.
  Size? _resizeStartSize;

  /// 손잡이를 잡은 뒤 지금까지 움직인 거리의 합입니다.
  ///
  /// ── 왜 합을 따로 들고 있나 ──
  /// 매 순간의 움직임을 카드 크기에 바로바로 더하면, 조금씩 어긋난 값이
  /// 쌓여서 손가락과 카드 모서리가 점점 벌어집니다. **처음 크기 + 지금까지의 합**
  /// 으로 매번 새로 계산하면 어긋날 일이 없습니다.
  Offset _resizeDelta = Offset.zero;

  /// 보던 화면을 "카드 전부 보기"로 되돌리라고 알리는 숫자입니다.
  ///
  /// 숫자 자체에는 뜻이 없습니다. **1 올리면 되돌아갑니다.**
  /// (BoardViewport의 viewResetCount 설명 참고)
  ///
  /// 레퍼런스를 새로 담을 때 씁니다. 멀리 확대해서 보고 있었다면 새 카드가
  /// 화면 밖에 생겨서 안 담긴 것처럼 보이기 때문입니다.
  int _viewResetCount = 0;

  /// 격자 스냅을 켰는지 여부입니다. 위쪽 막대 버튼으로 켜고 끕니다.
  ///
  /// **카드끼리 붙는 것은 항상 켜져 있습니다.** 이 값은 격자만 다룹니다.
  ///
  /// 기억하지 않습니다 — 판을 나갔다 오면 꺼집니다. 기존 웹앱과 같습니다.
  bool _gridSnap = false;

  /// 스냅 안내선을 그릴 자리입니다. 안 붙었으면 null입니다.
  double? _guideX;
  double? _guideY;

  /// 아직 읽어오는 중인지 여부입니다.
  bool _isLoading = true;

  /// 화면이 만들어질 때 판의 내용을 읽어옵니다.
  @override
  void initState() {
    super.initState();
    _loadBoard();
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

    setState(() {
      _cards = cards;
      _lookup = lookup;
      _isLoading = false;
    });
  }

  /// 레퍼런스를 골라 판에 올립니다.
  Future<void> _addCards() async {
    final List<String>? pickedIds = await showPickReferencesDialog(
      context: context,
      repository: widget.referenceRepository,
      imageStorage: widget.imageStorage,
      alreadyOnBoard: _cards.map((BoardCard card) => card.referenceId).toSet(),
    );

    if (pickedIds == null || pickedIds.isEmpty || !mounted) {
      return;
    }

    final DateTime now = DateTime.now().toUtc();
    final int startIndex = _cards.length;
    final int topZ = topZOrderOf(_cards);

    final List<BoardCard> newCards = <BoardCard>[];
    for (int i = 0; i < pickedIds.length; i++) {
      final Offset position = initialCardPosition(startIndex + i);

      newCards.add(
        BoardCard(
          id: newId(),
          boardId: widget.board.id,
          referenceId: pickedIds[i],
          x: position.dx,
          y: position.dy,

          // 새로 올린 것이 맨 위에 옵니다. 방금 올렸는데 다른 카드 밑에
          // 깔려서 안 보이면 안 올라간 줄 압니다.
          zOrder: topZ + 1 + i,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    await widget.boardRepository.addCards(newCards);

    if (!mounted) {
      return;
    }
    await _loadBoard();

    if (!mounted) {
      return;
    }

    // 담은 카드가 화면 밖에 생기면 "안 담겼나?" 싶어집니다.
    // 한 번 전체 보기로 되돌려서 방금 담은 것이 반드시 보이게 합니다.
    setState(() {
      _viewResetCount++;
    });
  }

  /// 카드를 잡았을 때 실행됩니다. 잡은 카드를 맨 위로 올립니다.
  ///
  /// 규칙 자체는 utils/board_card_actions.dart에 있습니다. 여기서는
  /// "지금 무엇을 잡고 있는지"만 기억하고 결과를 화면에 반영합니다.
  void _onDragStart(BoardCard card) {
    setState(() {
      _activeCardId = card.id;
      _cards = raiseCardToTop(_cards, card.id);
    });
  }

  /// 카드를 끄는 동안 실행됩니다. **화면에서만** 옮기고 저장은 하지 않습니다.
  ///
  /// [delta]는 이번 순간에 움직인 거리입니다.
  void _onDragUpdate(BoardCard card, Offset delta) {
    final BoardCardsUpdate update = moveCard(
      _cards,
      card.id,
      delta,
      snap: _snapEnabled,
      useGrid: _gridSnap,
    );

    setState(() {
      _cards = update.cards;
      _guideX = update.guideX;
      _guideY = update.guideY;
    });
  }

  /// 카드에서 손을 뗐을 때 실행됩니다. **여기서 한 번만 저장합니다.**
  Future<void> _onDragEnd(BoardCard card) async {
    setState(() {
      _activeCardId = null;
      _clearGuides();
    });

    await _saveCard(card.id);
  }

  /// 크기 조절 손잡이를 잡았을 때 실행됩니다.
  ///
  /// [currentSize]는 저장된 값이 아니라 **지금 실제로 그려져 있는 크기**입니다.
  /// 카드 높이는 보통 비어 있어서(= 그림 비율대로) 저장된 값만으로는
  /// 지금 높이가 얼마인지 알 수 없기 때문에, 카드가 직접 재서 알려줍니다.
  void _onResizeStart(BoardCard card, Size currentSize) {
    setState(() {
      _activeCardId = card.id;
      _resizeStartSize = currentSize;
      _resizeDelta = Offset.zero;
    });
  }

  /// 손잡이를 끄는 동안 실행됩니다. **화면에서만** 크기를 바꾸고 저장은 하지 않습니다.
  ///
  /// 가로세로 비율을 왜 고정하는지는 utils/board_card_actions.dart의
  /// resizeCard 설명을 보세요.
  void _onResizeUpdate(BoardCard card, Offset delta) {
    final Size? startSize = _resizeStartSize;
    if (startSize == null) {
      return;
    }

    _resizeDelta += delta;

    final BoardCardsUpdate update = resizeCard(
      _cards,
      card.id,
      startSize: startSize,
      movedSoFar: _resizeDelta,
      snap: _snapEnabled,
      useGrid: _gridSnap,
    );

    setState(() {
      _cards = update.cards;
      _guideX = update.guideX;
      _guideY = update.guideY;
    });
  }

  /// 손잡이에서 손을 뗐을 때 실행됩니다. **여기서 한 번만 저장합니다.**
  ///
  /// 이때 카드의 높이가 처음으로 채워집니다. 그 전까지는 비어 있었고
  /// (= 그림 비율대로), 이제부터는 정해진 크기로 그려집니다.
  Future<void> _onResizeEnd(BoardCard card) async {
    setState(() {
      _activeCardId = null;
      _resizeStartSize = null;
      _resizeDelta = Offset.zero;
      _clearGuides();
    });

    await _saveCard(card.id);
  }

  /// 지금 스냅을 걸어야 하는지 알려줍니다.
  ///
  /// ── Alt를 누르고 있으면 잠시 끕니다 ──
  /// 스냅은 대개 도움이 되지만, 일부러 살짝 어긋나게 놓고 싶을 때는
  /// 방해가 됩니다. PureRef·피그마 같은 도구들이 쓰는 방식이라 손에 익습니다.
  ///
  /// `HardwareKeyboard`는 지금 눌려 있는 키를 바로 알려주는 Flutter의
  /// 기본 장치입니다. 키 입력을 받는 위젯을 따로 만들지 않아도 됩니다.
  bool get _snapEnabled => !HardwareKeyboard.instance.isAltPressed;

  /// 안내선을 지웁니다. 끌기가 끝나면 부릅니다.
  ///
  /// setState 안에서 부르세요. 여기서 직접 부르지 않는 이유는, 끌기가
  /// 끝날 때 어차피 다른 값들도 함께 바꾸기 때문입니다.
  void _clearGuides() {
    _guideX = null;
    _guideY = null;
  }

  /// 카드 하나의 지금 상태를 저장합니다. 목록에 없으면 아무 일도 안 합니다.
  ///
  /// 끌기와 크기 조절이 끝날 때 둘 다 이걸 부릅니다.
  Future<void> _saveCard(String cardId) async {
    final int index = indexOfCard(_cards, cardId);
    if (index == -1) {
      return;
    }

    await widget.boardRepository.saveCard(_cards[index]);
  }

  /// 카드를 판에서 내립니다.
  ///
  /// **레퍼런스를 지우는 것이 아닙니다.** 판에서만 내려가고 목록에는 그대로 남습니다.
  /// 그래서 "정말 지울까요?"를 묻지 않습니다. 되돌리기 쉬운 일에 매번 확인을 받으면
  /// 사용자는 확인 창을 안 읽고 누르는 버릇이 들고, 정작 위험한 확인도 그냥 넘깁니다.
  Future<void> _removeCard(BoardCard card) async {
    await widget.boardRepository.removeCard(card.id);

    if (!mounted) {
      return;
    }

    setState(() {
      // 목록을 직접 뜯어고치지 않고 새 목록으로 갈아끼웁니다.
      // 옮기기·크기 바꾸기와 같은 방식이라 읽을 때 헷갈리지 않습니다.
      _cards = _cards
          .where((BoardCard each) => each.id != card.id)
          .toList();
    });
  }

  /// 화면의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.board.name),
        actions: <Widget>[
          // 격자 스냅 토글. **카드끼리 붙는 것은 항상 켜져 있고**
          // 이 버튼은 격자만 다룹니다.
          //
          // 눌린 상태를 색으로 보여줍니다. 안 그러면 지금 켜졌는지 꺼졌는지
          // 알 방법이 없어서 눌러보고 카드를 끌어봐야 합니다.
          IconButton(
            onPressed: _isLoading
                ? null
                : () => setState(() => _gridSnap = !_gridSnap),
            icon: const Icon(Icons.grid_4x4),
            isSelected: _gridSnap,
            tooltip: _gridSnap ? '격자에 맞추기 끄기' : '격자에 맞추기',
          ),

          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.tonalIcon(
              onPressed: _isLoading ? null : _addCards,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('레퍼런스 담기'),
            ),
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

    if (_cards.isEmpty) {
      return _buildEmptyState();
    }

    // 판에 끝이 없어서, 그릴 자리를 카드에서 구합니다.
    // 카드를 옮기면 이 자리도 따라 움직입니다.
    //
    // 한 번만 구해서 둘에게 나눠줍니다. 각자 구하게 두면 언젠가 한쪽만
    // 고쳐서 상자와 카드가 어긋나게 됩니다.
    final Rect canvasRect = boardCanvasRect(_cards);

    // 판을 확대·이동해서 보여주는 일은 BoardViewport가 맡습니다.
    // 카드를 놓고 조작을 알아채는 일만 BoardCanvas가 합니다.
    return BoardViewport(
      canvasRect: canvasRect,
      contentBounds: boardContentBounds(_cards),
      viewResetCount: _viewResetCount,
      child: BoardCanvas(
        cards: _cards,
        canvasRect: canvasRect,
        guideX: _guideX,
        guideY: _guideY,
        itemsById: _lookup.itemsById,
        imagePaths: _lookup.imagePaths,
        activeCardId: _activeCardId,
        onDragStart: _onDragStart,
        onDragUpdate: _onDragUpdate,
        onDragEnd: _onDragEnd,
        onResizeStart: _onResizeStart,
        onResizeUpdate: _onResizeUpdate,
        onResizeEnd: _onResizeEnd,
        onRemoveCard: _removeCard,
      ),
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
