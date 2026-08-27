// 무드보드 판 하나를 여는 화면입니다. 카드를 올리고, 끌어서 옮기고, 내립니다.
//
// ── 역할 나누기 ──
//   board_canvas.dart  — 카드를 좌표대로 그리고, 끌기 동작을 알아챕니다.
//   board_card_view.dart — 카드 한 장이 어떻게 생겼는지.
//   board_layout.dart  — 어디에 놓을지 계산합니다(순수한 셈).
//   이 파일             — **위치를 기억하고 저장합니다.**
//
// ── 언제 저장하는가 (이 화면에서 가장 중요한 결정) ──
// 카드를 끄는 동안에는 **화면에서만** 위치를 바꾸고, 손을 뗐을 때 한 번 저장합니다.
// 끄는 동안 매 순간 저장하면 1초에 수십 번 데이터베이스에 쓰게 되어 눈에 띄게 버벅입니다.
//
// ── "저장" 버튼이 없는 이유 ──
// 손을 떼는 순간 저장되므로 따로 누를 것이 없습니다. 저장 버튼을 두면 사용자는
// 언제 눌러야 하는지 신경 쓰게 되고, 안 누르고 나갔다가 배치를 통째로 잃습니다.

import 'package:flutter/material.dart';

import '../models/board.dart';
import '../models/reference_item.dart';
import '../repositories/board_repository.dart';
import '../repositories/reference_repository.dart';
import '../services/image_storage.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';
import '../utils/board_layout.dart';
import '../utils/id_generator.dart';
import '../widgets/board_canvas.dart';
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

  /// 레퍼런스 번호 → 레퍼런스. 카드가 보여줄 제목과 파일 이름을 여기서 찾습니다.
  Map<String, ReferenceItem> _itemsById = <String, ReferenceItem>{};

  /// 레퍼런스 번호 → 이미지 파일의 전체 경로
  Map<String, String?> _imagePaths = <String, String?>{};

  /// 지금 끌고 있는 카드의 번호입니다. 아무것도 안 끌고 있으면 null입니다.
  String? _draggingCardId;

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

    // ── 레퍼런스를 하나씩 찾지 않고 전부 가져오는 이유 ──
    // 카드가 30장이면 하나씩 찾을 때 데이터베이스에 30번 오갑니다.
    // 한 번에 가져와 표를 만들어두면 찾는 일은 앱 안에서 끝납니다.
    final List<ReferenceItem> items = await widget.referenceRepository.getAll();

    final Map<String, ReferenceItem> itemsById = <String, ReferenceItem>{};
    final Map<String, String?> paths = <String, String?>{};

    for (final ReferenceItem item in items) {
      itemsById[item.id] = item;

      final String? fileName = item.fileName;
      if (fileName != null) {
        paths[item.id] = await widget.imageStorage.getFullPath(fileName);
      }
    }

    // 읽어오는 사이에 사용자가 화면을 떠났을 수 있습니다.
    if (!mounted) {
      return;
    }

    setState(() {
      _cards = cards;
      _itemsById = itemsById;
      _imagePaths = paths;
      _isLoading = false;
    });
  }

  /// 지금 판에서 가장 위에 있는 카드의 zOrder를 돌려줍니다. 카드가 없으면 0입니다.
  ///
  /// 데이터베이스에 묻지 않고 손에 든 목록에서 셉니다. 카드를 잡을 때마다
  /// 물어보면 끄는 동작이 시작될 때마다 잠깐씩 걸립니다.
  int _topZOrder() {
    int top = 0;
    for (final BoardCard card in _cards) {
      if (card.zOrder > top) {
        top = card.zOrder;
      }
    }
    return top;
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
    final int topZ = _topZOrder();

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
  }

  /// 카드를 잡았을 때 실행됩니다. 잡은 카드를 맨 위로 올립니다.
  ///
  /// 맨 위로 올리지 않으면, 아래 깔린 카드를 꺼내려고 끌었는데도
  /// 여전히 다른 카드에 덮인 채 따라옵니다. 무엇을 잡았는지 보이지 않습니다.
  void _onDragStart(BoardCard card) {
    setState(() {
      _draggingCardId = card.id;

      final int index = _indexOf(card.id);
      if (index == -1) {
        return;
      }

      final BoardCard raised = _cards[index].copyWith(zOrder: _topZOrder() + 1);

      // 목록에서 빼서 맨 뒤에 다시 넣습니다. Stack은 뒤에 있는 것을 위에
      // 그리므로, 이것만으로 화면에서도 맨 위로 올라옵니다.
      _cards
        ..removeAt(index)
        ..add(raised);
    });
  }

  /// 카드를 끄는 동안 실행됩니다. **화면에서만** 옮기고 저장은 하지 않습니다.
  ///
  /// [delta]는 이번 순간에 움직인 거리입니다. 지금 위치에 더해서 씁니다.
  void _onDragUpdate(BoardCard card, Offset delta) {
    final int index = _indexOf(card.id);
    if (index == -1) {
      return;
    }

    final BoardCard current = _cards[index];

    // 판 밖으로 나가지 않게 붙잡아둡니다.
    // (왜 막는지는 utils/board_layout.dart의 clampToBoard 설명을 보세요)
    final Offset moved = clampToBoard(
      current.x + delta.dx,
      current.y + delta.dy,
      current,
    );

    setState(() {
      _cards[index] = current.copyWith(x: moved.dx, y: moved.dy);
    });
  }

  /// 카드에서 손을 뗐을 때 실행됩니다. **여기서 한 번만 저장합니다.**
  Future<void> _onDragEnd(BoardCard card) async {
    final int index = _indexOf(card.id);

    setState(() {
      _draggingCardId = null;
    });

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
      _cards.removeWhere((BoardCard each) => each.id == card.id);
    });
  }

  /// 목록에서 이 번호를 가진 카드가 몇 번째인지 찾습니다. 없으면 -1입니다.
  int _indexOf(String cardId) {
    return _cards.indexWhere((BoardCard card) => card.id == cardId);
  }

  /// 화면의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.board.name),
        actions: <Widget>[
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

    return BoardCanvas(
      cards: _cards,
      itemsById: _itemsById,
      imagePaths: _imagePaths,
      draggingCardId: _draggingCardId,
      onDragStart: _onDragStart,
      onDragUpdate: _onDragUpdate,
      onDragEnd: _onDragEnd,
      onRemoveCard: _removeCard,
    );
  }

  /// 아직 판이 비어 있을 때의 안내입니다.
  Widget _buildEmptyState() {
    final AppPalette palette = AppPalette.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(screenPaddingHorizontal),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 64,
              color: palette.textDim,
            ),
            const SizedBox(height: 24),
            Text(
              '판이 비어 있습니다',
              style: AppText.emptyTitle.copyWith(color: palette.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '오른쪽 위 "레퍼런스 담기"로 올린 뒤\n끌어서 원하는 자리에 놓아보세요.',
              style: AppText.emptyBody.copyWith(color: palette.textDim),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _addCards,
              icon: const Icon(Icons.add),
              label: const Text('레퍼런스 담기'),
            ),
          ],
        ),
      ),
    );
  }
}
