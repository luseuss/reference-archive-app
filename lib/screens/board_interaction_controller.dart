// 무드보드 판 위의 카드 목록을 "잡고, 옮기고, 크기를 바꾸고, 담고, 내리는"
// 상태와 동작을 한데 모은 곳입니다.
//
// ── 왜 board_screen.dart에서 뺐나 ──
// 끌기·크기 조절·스냅 안내선은 전부 같은 목록(cards)과 같은 몇 가지 값
// (활성 카드, 손잡이를 잡은 순간의 크기, 안내선 자리…)을 함께 건드립니다.
// 그냥 함수만 다른 파일로 옮기면 이 값들을 인자로 주고받아야 해서 오히려
// 읽기 어려워집니다. 그래서 **상태까지 함께** 옮길 작은 클래스를 만들었습니다.
//
// board_screen.dart는 판을 "읽어오고 화면에 띄우는" 일만 하고, 카드를
// "조작하는" 일은 전부 이 파일이 맡습니다.
//
// ── ChangeNotifier가 무엇인가 ──
// "값이 바뀌었다"고 화면에 알려주는 Flutter의 기본 장치입니다.
// (lib/services/app_settings.dart에서 먼저 쓴 것과 같은 방식입니다)
// 카드를 옮기면 notifyListeners()가 불리고, ListenableBuilder로 감싼
// 부분이 저절로 다시 그려집니다.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/board.dart';
import '../repositories/board_repository.dart';
import '../utils/board_align.dart';
import '../utils/board_card_actions.dart';
import '../utils/board_card_selection.dart';
import '../utils/board_layout.dart';
import '../utils/id_generator.dart';

/// 무드보드 판 위의 카드를 조작하는 모든 상태와 동작을 담습니다.
class BoardInteractionController extends ChangeNotifier {
  BoardInteractionController({
    required this.boardId,
    required this.boardRepository,
  });

  /// 이 판의 번호입니다. 새 카드를 만들 때 씁니다.
  final String boardId;

  /// 카드 배치를 저장하는 통로입니다.
  final BoardRepository boardRepository;

  /// 판에 놓인 카드들입니다. **아래에 깔린 것부터** 순서대로 들어있습니다.
  List<BoardCard> get cards => _cards;
  List<BoardCard> _cards = <BoardCard>[];

  /// 지금 끌거나 크기를 바꾸고 있는 카드의 번호입니다. 없으면 null입니다.
  String? get activeCardId => _activeCardId;
  String? _activeCardId;

  /// 지금 함께 끌리고 있는 카드들의 번호입니다. 끄는 중이 아니면 비어 있습니다.
  ///
  /// 여러 장을 골라 끄는 중이면 그 전부, 아니면 [_activeCardId] 하나만
  /// 들어있습니다. (onDragStart에서 정합니다)
  Set<String> _draggingIds = <String>{};

  /// 크기 조절 손잡이를 잡은 순간의 카드 크기입니다. 조절 중이 아니면 null입니다.
  ///
  /// 저장된 값이 아니라 **실제로 그려져 있던 크기**입니다. 카드 높이는 보통
  /// 비어 있어서(= 그림 비율대로) 저장된 값만으로는 알 수 없기 때문입니다.
  Size? _resizeStartSize;

  /// 크기 조절 손잡이를 잡은 순간의 카드 자리입니다. 조절 중이 아니면 null입니다.
  ///
  /// 반대쪽(고정돼야 할) 모서리를 구할 때 씁니다. [_resizeStartSize]와
  /// 짝을 이루는 "손잡이를 잡던 순간의 스냅샷"입니다.
  Offset? _resizeStartPosition;

  /// 지금 잡고 있는 손잡이가 카드의 어느 모서리에 있는지입니다.
  /// 조절 중이 아니면 null입니다. (board_card_actions.dart의
  /// BoardResizeCorner 설명 참고)
  BoardResizeCorner? _resizeCorner;

  /// 손잡이를 잡은 뒤 지금까지 움직인 거리의 합입니다.
  ///
  /// ── 왜 합을 따로 들고 있나 ──
  /// 매 순간의 움직임을 카드 크기에 바로바로 더하면, 조금씩 어긋난 값이
  /// 쌓여서 손가락과 카드 모서리가 점점 벌어집니다. **처음 크기 + 지금까지의 합**
  /// 으로 매번 새로 계산하면 어긋날 일이 없습니다.
  Offset _resizeDelta = Offset.zero;

  /// 격자 스냅을 켰는지 여부입니다. 위쪽 막대 버튼으로 켜고 끕니다.
  ///
  /// **카드끼리 붙는 것은 항상 켜져 있습니다.** 이 값은 격자만 다룹니다.
  ///
  /// 기억하지 않습니다 — 판을 나갔다 오면 꺼집니다. 기존 웹앱과 같습니다.
  bool get gridSnap => _gridSnap;
  bool _gridSnap = false;

  /// 카드들이 **실제로 몇 픽셀로 그려졌는지**입니다. (카드 번호 → 높이)
  ///
  /// 카드 높이는 보통 저장돼 있지 않고 그림 비율이 정합니다. 그래서 판은
  /// 카드가 세로로 얼마나 긴지 모릅니다. 각 카드가 그려진 뒤에 자기를 재서
  /// 알려주면 여기 모입니다. (board_card_view.dart의 onMeasured)
  ///
  /// **저장하지 않습니다.** 기기·창 크기에 따라 달라지는 값이고, 다시 그리면
  /// 또 알려주기 때문입니다.
  final Map<String, double> _measuredHeights = <String, double>{};

  /// 스냅 안내선을 그릴 자리입니다. 안 붙었으면 null입니다.
  double? get guideX => _guideX;
  double? get guideY => _guideY;
  double? _guideX;
  double? _guideY;

  /// 지금 선택된 카드들의 번호입니다. (5단계 마퀴 다중선택)
  ///
  /// 저장하지 않습니다 — 판을 나갔다 오면 비워집니다. "무엇이 골라져
  /// 있는지"는 지금 보고 있는 화면에서만 뜻이 있는 값이라, 다음에 판을
  /// 열었을 때까지 기억할 이유가 없습니다.
  ///
  /// 실제 값과 마퀴 계산은 `lib/utils/board_card_selection.dart`의
  /// `BoardCardSelection`이 담고 있습니다.
  Set<String> get selectedCardIds => _selection.ids;
  final BoardCardSelection _selection = BoardCardSelection();

  /// 지금 스냅을 걸어야 하는지 알려줍니다.
  ///
  /// ── 기본은 자유롭게, Alt를 누르면 붙습니다 ──
  /// 처음에는 반대로(평소 붙고 Alt로 끄기) 만들었는데, 의뢰인이 써보니
  /// **평소에 자유롭게 두고 정밀하게 맞추고 싶을 때만** 스냅을 켜는 쪽이
  /// 손에 맞았습니다. 카드를 대충 늘어놓는 시간이 훨씬 많고, 줄을 맞추는
  /// 건 가끔이라 그렇습니다.
  ///
  /// `HardwareKeyboard`는 지금 눌려 있는 키를 바로 알려주는 Flutter의
  /// 기본 장치입니다. 키 입력을 받는 위젯을 따로 만들지 않아도 됩니다.
  bool get snapEnabled => HardwareKeyboard.instance.isAltPressed;

  /// 판에 놓인 카드 목록을 통째로 갈아끼웁니다.
  ///
  /// 화면을 처음 열 때(board_screen.dart의 _loadBoard)만 씁니다. 그 뒤로는
  /// 이 클래스 안의 메서드들이 목록을 조금씩 고칩니다.
  void setCards(List<BoardCard> cards) {
    _cards = cards;
    notifyListeners();
  }

  /// 격자 스냅을 켜고 끕니다. 위쪽 막대 버튼이 부릅니다.
  void toggleGridSnap() {
    _gridSnap = !_gridSnap;
    notifyListeners();
  }

  /// 선택을 지웁니다. 선택 툴바의 "×" 버튼이 부릅니다.
  ///
  /// 빈 곳을 클릭해도 같은 일이 일어나지만(handleEmptyTap), 마우스를
  /// 옮기지 않고 바로 누를 수 있는 버튼을 하나 더 둔 것입니다.
  void clearSelection() {
    if (_selection.isEmpty) {
      return;
    }

    _selection.clear();
    notifyListeners();
  }

  /// 레퍼런스를 새 카드로 만들어 판에 담고 저장합니다.
  ///
  /// 레퍼런스를 고르는 대화상자는 `context`가 필요해서 board_screen.dart에
  /// 남아 있습니다. 대화상자가 번호 목록을 고르고 나면, **저장하고 목록에
  /// 넣는 부분**만 여기서 맡습니다.
  Future<void> addCards(List<String> referenceIds) async {
    final DateTime now = DateTime.now().toUtc();
    final int startIndex = _cards.length;
    final int topZ = topZOrderOf(_cards);

    final List<BoardCard> newCards = <BoardCard>[];
    for (int i = 0; i < referenceIds.length; i++) {
      final Offset position = initialCardPosition(startIndex + i);

      newCards.add(
        BoardCard(
          id: newId(),
          boardId: boardId,
          referenceId: referenceIds[i],
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

    await boardRepository.addCards(newCards);

    _cards = <BoardCard>[..._cards, ...newCards];
    notifyListeners();
  }

  /// 카드를 판에서 내립니다.
  ///
  /// **레퍼런스를 지우는 것이 아닙니다.** 판에서만 내려가고 목록에는 그대로 남습니다.
  /// 그래서 "정말 지울까요?"를 묻지 않습니다. 되돌리기 쉬운 일에 매번 확인을 받으면
  /// 사용자는 확인 창을 안 읽고 누르는 버릇이 들고, 정작 위험한 확인도 그냥 넘깁니다.
  Future<void> removeCard(BoardCard card) async {
    await boardRepository.removeCard(card.id);

    // 목록을 직접 뜯어고치지 않고 새 목록으로 갈아끼웁니다.
    // 옮기기·크기 바꾸기와 같은 방식이라 읽을 때 헷갈리지 않습니다.
    _cards = _cards.where((BoardCard each) => each.id != card.id).toList();
    notifyListeners();
  }

  /// 카드를 누른 순간 실행됩니다. 실제로 끌리기 전에, "무엇이 선택돼야
  /// 하는지"를 여기서 먼저 정합니다.
  ///
  /// ── 왜 끌기 시작이 아니라 누른 순간인가 ──
  /// Shift+클릭처럼 **끌지 않고 선택만** 하는 조작도 있습니다. 끌기가
  /// 시작될 때까지 기다리면 그런 클릭에서는 아무 일도 안 일어납니다.
  ///
  /// [shiftHeld]가 참이면 이 카드를 선택에 더하거나 뺍니다(끌지 않습니다).
  /// 거짓이면, **이미 여러 장이 선택된 상태에서 그중 하나를 눌렀을 때만**
  /// 선택을 그대로 두고(다 같이 끌 수 있게), 그 외에는 이 카드 하나만
  /// 선택합니다.
  void onCardPressed(BoardCard card, {required bool shiftHeld}) {
    if (shiftHeld) {
      _selection.toggle(card.id);
      notifyListeners();
      return;
    }

    final bool keepMultiSelection =
        _selection.ids.contains(card.id) && _selection.ids.length > 1;
    if (!keepMultiSelection) {
      _selection.selectOnly(card.id);
      notifyListeners();
    }
  }

  /// 카드를 잡았을 때(실제로 끌리기 시작할 때) 실행됩니다.
  ///
  /// **Shift를 누르고 있으면 끌지 않습니다.** Shift는 선택을 더하고 빼는
  /// 키라, Shift를 누른 채로도 카드가 끌려버리면 정밀하게 고르기가
  /// 어려워집니다.
  ///
  /// 함께 끌 카드들(같이 선택돼 있으면 전부, 아니면 이 카드 하나)을 정해
  /// [_draggingIds]에 기억해두고, 잡은 카드를 맨 위로 올립니다.
  void onDragStart(BoardCard card) {
    if (HardwareKeyboard.instance.isShiftPressed) {
      return;
    }

    _activeCardId = card.id;
    _draggingIds = _selection.ids.contains(card.id) && _selection.ids.length > 1
        ? _selection.ids
        : <String>{card.id};
    _cards = raiseCardToTop(_cards, card.id);
    notifyListeners();
  }

  /// 카드를 끄는 동안 실행됩니다. **화면에서만** 옮기고 저장은 하지 않습니다.
  ///
  /// [delta]는 이번 순간에 움직인 거리입니다. [_draggingIds]에 든 카드
  /// 전부가 같이 움직입니다 — 여러 장을 골라 끄는 중이면 다 같이,
  /// 아니면 이 카드 하나만입니다.
  void onDragUpdate(BoardCard card, Offset delta) {
    if (_draggingIds.isEmpty) {
      return;
    }

    final BoardCardsUpdate update = moveCards(
      _cards,
      _draggingIds.toList(),
      primaryId: card.id,
      delta: delta,
      snap: snapEnabled,
      useGrid: _gridSnap,
      measuredHeights: _measuredHeights,
    );

    _cards = update.cards;
    _guideX = update.guideX;
    _guideY = update.guideY;
    notifyListeners();
  }

  /// 카드에서 손을 뗐을 때 실행됩니다. **여기서 한 번만 저장합니다.**
  ///
  /// 끌던 카드가 여러 장이었으면 **전부** 저장합니다. 한 장만 저장하면
  /// 같이 끌린 나머지는 화면에는 옮겨져 있는데 다시 켰을 때 원래 자리로
  /// 돌아가 있는, 앞뒤가 안 맞는 상태가 됩니다.
  Future<void> onDragEnd(BoardCard card) async {
    final Set<String> draggedIds = _draggingIds.isEmpty
        ? <String>{card.id}
        : _draggingIds;

    _activeCardId = null;
    _draggingIds = <String>{};
    _clearGuides();
    notifyListeners();

    await _saveCards(draggedIds);
  }

  /// 크기 조절 손잡이를 잡았을 때 실행됩니다.
  ///
  /// [currentSize]는 저장된 값이 아니라 **지금 실제로 그려져 있는 크기**입니다.
  /// 카드 높이는 보통 비어 있어서(= 그림 비율대로) 저장된 값만으로는
  /// 지금 높이가 얼마인지 알 수 없기 때문에, 카드가 직접 재서 알려줍니다.
  ///
  /// [corner]는 어느 손잡이를 잡았는지입니다. 그 반대쪽 모서리가 고정된
  /// 채로 크기가 바뀝니다. (board_card_actions.dart의 resizeCard 설명 참고)
  void onResizeStart(BoardCard card, Size currentSize, BoardResizeCorner corner) {
    _activeCardId = card.id;
    _resizeStartSize = currentSize;
    _resizeStartPosition = Offset(card.x, card.y);
    _resizeCorner = corner;
    _resizeDelta = Offset.zero;
    notifyListeners();
  }

  /// 손잡이를 끄는 동안 실행됩니다. **화면에서만** 크기를 바꾸고 저장은 하지 않습니다.
  ///
  /// 가로세로 비율을 왜 고정하는지는 utils/board_card_actions.dart의
  /// resizeCard 설명을 보세요.
  void onResizeUpdate(BoardCard card, Offset delta) {
    final Size? startSize = _resizeStartSize;
    final Offset? startPosition = _resizeStartPosition;
    final BoardResizeCorner? corner = _resizeCorner;
    if (startSize == null || startPosition == null || corner == null) {
      return;
    }

    _resizeDelta += delta;

    final BoardCardsUpdate update = resizeCard(
      _cards,
      card.id,
      startSize: startSize,
      startPosition: startPosition,
      corner: corner,
      movedSoFar: _resizeDelta,
      snap: snapEnabled,
      useGrid: _gridSnap,
      measuredHeights: _measuredHeights,
    );

    _cards = update.cards;
    _guideX = update.guideX;
    _guideY = update.guideY;
    notifyListeners();
  }

  /// 손잡이에서 손을 뗐을 때 실행됩니다. **여기서 한 번만 저장합니다.**
  ///
  /// 이때 카드의 높이가 처음으로 채워집니다. 그 전까지는 비어 있었고
  /// (= 그림 비율대로), 이제부터는 정해진 크기로 그려집니다.
  Future<void> onResizeEnd(BoardCard card) async {
    _activeCardId = null;
    _resizeStartSize = null;
    _resizeStartPosition = null;
    _resizeCorner = null;
    _resizeDelta = Offset.zero;
    _clearGuides();
    notifyListeners();

    await _saveCard(card.id);
  }

  /// 카드가 자기 크기를 알려왔을 때 받아둡니다.
  ///
  /// ── notifyListeners를 안 부릅니다 ──
  /// 이 값은 **스냅 계산에만** 쓰이고 화면 생김새를 바꾸지 않습니다.
  /// 여기서 다시 그리라고 하면, 그리는 도중에 또 알려오고 또 그리는
  /// 되돌이가 생길 수 있습니다.
  void onCardMeasured(BoardCard card, Size size) {
    _measuredHeights[card.id] = size.height;
  }

  /// 안내선을 지웁니다. 끌기가 끝나면 부릅니다.
  ///
  /// notifyListeners는 부르는 쪽에서 함께 처리합니다. 끌기가 끝날 때
  /// 어차피 다른 값들도 함께 바뀌기 때문입니다.
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

    await boardRepository.saveCard(_cards[index]);
  }

  /// 여러 카드의 지금 상태를 한꺼번에 저장합니다.
  ///
  /// 여러 장을 함께 끌었을 때 씁니다(5단계 마퀴 다중선택).
  Future<void> _saveCards(Set<String> cardIds) async {
    final List<BoardCard> toSave = _cards
        .where((BoardCard card) => cardIds.contains(card.id))
        .toList();

    if (toSave.isEmpty) {
      return;
    }

    await boardRepository.saveCards(toSave);
  }

  // ── 여기서부터는 선택·마퀴(5단계 마퀴 다중선택)입니다 ──
  // 실제 값과 계산은 lib/utils/board_card_selection.dart의
  // BoardCardSelection이 담고 있습니다. 여기 남은 메서드들은 그 계산에
  // 필요한 카드 목록(_cards)을 건네주고, 언제 notifyListeners를 부를지만
  // 정합니다.

  /// 빈 곳을 눌렀을 때 실행됩니다.
  ///
  /// [shiftHeld]가 거짓이면 선택을 지웁니다. 참이면 아무 일도 안 합니다 —
  /// Shift는 "선택에 손대지 않는다"는 뜻으로 씁니다.
  ///
  /// **끌었는지(마퀴)는 여기서 안 봅니다.** 마퀴는 [endMarquee]가 따로
  /// 처리합니다. 이건 **끌지 않고 그냥 눌렀을 때**만 board_viewport.dart가
  /// 부릅니다.
  void handleEmptyTap({required bool shiftHeld}) {
    if (shiftHeld || _selection.isEmpty) {
      return;
    }

    _selection.clear();
    notifyListeners();
  }

  /// 마퀴(드래그로 그리는 선택 네모)를 시작합니다.
  ///
  /// [additive]는 Shift를 누른 채 시작했는지입니다. 참이면 지금까지의
  /// 선택을 남겨두고 마퀴에 걸리는 카드를 더합니다. 거짓이면 마퀴에 걸리는
  /// 카드로 통째로 바꿉니다.
  void beginMarquee({required bool additive}) {
    _selection.beginMarquee(additive: additive);
  }

  /// 마퀴를 끄는 동안 실행됩니다. [canvasRect]는 지금까지 그려진 네모입니다(판 좌표).
  ///
  /// ── 살짝이라도 겹치면 골라집니다 ──
  /// 카드 전체가 네모 안에 다 들어와야 하는 것이 아니라, **한 귀퉁이라도
  /// 걸치면** 선택됩니다. 기존 웹앱과 같은 규칙입니다. 카드가 큰 판에서는
  /// "다 담아야 골라진다"가 오히려 손이 많이 갑니다.
  ///
  /// 매 순간 그때까지의 결과를 바로 selectedCardIds에 반영합니다. 그래야
  /// 마퀴를 끄는 동안 카드가 실시간으로 파랗게 물듭니다.
  void updateMarquee(Rect canvasRect) {
    final Set<String> hits = <String>{
      for (final BoardCard card in _cards)
        if (boardCardRect(
          card,
          measuredHeights: _measuredHeights,
        ).overlaps(canvasRect))
          card.id,
    };

    _selection.applyMarqueeHits(hits);
    notifyListeners();
  }

  /// 마퀴에서 손을 뗐을 때 실행됩니다.
  ///
  /// 움직이지 않고 그냥 뗐다면(=클릭) [handleEmptyTap]과 같은 규칙을
  /// 적용합니다. Shift 없이 눌렀다 뗐을 뿐이라면 선택을 지웁니다.
  void endMarquee() {
    if (_selection.endMarquee()) {
      notifyListeners();
    }
  }

  /// 선택된 카드를 전부 판에서 내립니다.
  ///
  /// 한 장 내리는 것(removeCard)과 같은 이유로 확인을 묻지 않습니다.
  /// 판에서만 내려가고 레퍼런스 목록에는 그대로 남습니다.
  Future<void> removeSelectedCards() async {
    if (_selection.isEmpty) {
      return;
    }

    final Set<String> toRemove = _selection.ids;

    for (final String cardId in toRemove) {
      await boardRepository.removeCard(cardId);
    }

    _cards = _cards
        .where((BoardCard card) => !toRemove.contains(card.id))
        .toList();
    _selection.clear();
    notifyListeners();
  }

  // ── 여기서부터는 정렬·분배(6단계)입니다 ──

  /// 선택된 카드들을 [mode] 방향으로 나란히 맞추고 저장합니다.
  ///
  /// 선택이 2장 미만이면 아무 일도 안 합니다 — 정렬은 "여럿을 나란히
  /// 맞추는" 동작이라 기준으로 삼을 다른 카드가 없으면 뜻이 없습니다.
  Future<void> alignSelected(BoardAlignMode mode) async {
    if (_selection.ids.length < 2) {
      return;
    }

    _cards = alignSelectedCards(
      _cards,
      _selection.ids,
      mode,
      measuredHeights: _measuredHeights,
    );
    notifyListeners();

    await _saveCards(_selection.ids);
  }

  /// 선택된 카드들의 크기를 하나로 맞추고 저장합니다. 자리(x, y)는 그대로입니다.
  ///
  /// ── 기준 카드를 어떻게 고르나 ──
  /// **맨 위에 그려진 카드**(zOrder가 가장 큰 카드)를 기준으로 삼습니다.
  /// 카드를 마지막으로 만지면(잡거나 새로 담으면) 맨 위로 올라오기 때문에,
  /// 대개 "방금 크기를 확인한 카드"와 일치합니다.
  Future<void> matchSizeSelected() async {
    if (_selection.ids.length < 2) {
      return;
    }

    final BoardCard reference = _cards
        .where((BoardCard card) => _selection.ids.contains(card.id))
        .reduce(
          (BoardCard a, BoardCard b) => a.zOrder > b.zOrder ? a : b,
        );

    _cards = matchSizeSelectedCards(
      _cards,
      _selection.ids,
      reference.id,
      measuredHeights: _measuredHeights,
    );
    notifyListeners();

    await _saveCards(_selection.ids);
  }
}
