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
import '../utils/board_card_actions.dart';
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

  /// 카드를 잡았을 때 실행됩니다. 잡은 카드를 맨 위로 올립니다.
  ///
  /// 규칙 자체는 utils/board_card_actions.dart에 있습니다. 여기서는
  /// "지금 무엇을 잡고 있는지"만 기억하고 결과를 반영합니다.
  void onDragStart(BoardCard card) {
    _activeCardId = card.id;
    _cards = raiseCardToTop(_cards, card.id);
    notifyListeners();
  }

  /// 카드를 끄는 동안 실행됩니다. **화면에서만** 옮기고 저장은 하지 않습니다.
  ///
  /// [delta]는 이번 순간에 움직인 거리입니다.
  void onDragUpdate(BoardCard card, Offset delta) {
    final BoardCardsUpdate update = moveCard(
      _cards,
      card.id,
      delta,
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
  Future<void> onDragEnd(BoardCard card) async {
    _activeCardId = null;
    _clearGuides();
    notifyListeners();

    await _saveCard(card.id);
  }

  /// 크기 조절 손잡이를 잡았을 때 실행됩니다.
  ///
  /// [currentSize]는 저장된 값이 아니라 **지금 실제로 그려져 있는 크기**입니다.
  /// 카드 높이는 보통 비어 있어서(= 그림 비율대로) 저장된 값만으로는
  /// 지금 높이가 얼마인지 알 수 없기 때문에, 카드가 직접 재서 알려줍니다.
  void onResizeStart(BoardCard card, Size currentSize) {
    _activeCardId = card.id;
    _resizeStartSize = currentSize;
    _resizeDelta = Offset.zero;
    notifyListeners();
  }

  /// 손잡이를 끄는 동안 실행됩니다. **화면에서만** 크기를 바꾸고 저장은 하지 않습니다.
  ///
  /// 가로세로 비율을 왜 고정하는지는 utils/board_card_actions.dart의
  /// resizeCard 설명을 보세요.
  void onResizeUpdate(BoardCard card, Offset delta) {
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
}
