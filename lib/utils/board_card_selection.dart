// 무드보드 판에서 "지금 어떤 카드들이 골라져 있는지"를 담는 곳입니다.
// (5단계 마퀴 다중선택)
//
// ── 왜 board_interaction_controller.dart에서 뺐나 ──
// CLAUDE.md "밀린 정리거리"가 짚어둔 대로입니다. 끌기·크기 조절과는 성격이
// 다른 관심사(무엇이 골라졌는지)라 나눌 수 있었습니다.
//
// ── ChangeNotifier가 아닙니다 ──
// board_viewport_gestures.dart의 MarqueeState와 같은 이유입니다. 이 값은
// board_interaction_controller.dart가 이미 갖고 있는 notifyListeners()
// 체계 하나에 얹혀서 화면에 알려지므로, 여기서 또 다른 알림 체계를 두면
// 오히려 "언제 다시 그려지는지"가 두 갈래로 나뉘어 헷갈립니다. 그래서
// 이 클래스는 값만 들고 있고, 다시 그리라고 알리는 것은 여전히
// board_interaction_controller.dart의 몫입니다.
class BoardCardSelection {
  /// 지금 선택된 카드들의 번호입니다.
  Set<String> ids = <String>{};

  /// 마퀴를 시작할 때, 그 전까지 골라져 있던 카드들의 번호입니다. Shift를
  /// 누른 채 시작했으면(=더하기) 마퀴가 끝나도 이 카드들이 계속 선택에
  /// 남습니다. Shift 없이 시작했으면 빈 목록입니다.
  Set<String> _marqueeBase = <String>{};

  /// Shift를 누른 채 마퀴를 시작했는지 여부입니다. "더하기" 모드입니다.
  bool _marqueeAdditive = false;

  /// 마퀴를 시작한 뒤 조금이라도 움직였는지 여부입니다.
  ///
  /// 움직이지 않고 그냥 뗐다면 "클릭"으로 봅니다. Shift 없이 그런 클릭을
  /// 했다면 선택을 지웁니다 — 빈 곳을 눌렀는데 아무 반응이 없으면
  /// "선택을 지우고 싶었는데 안 지워졌다"는 인상을 줍니다.
  bool _marqueeMoved = false;

  bool get isEmpty => ids.isEmpty;

  /// [cardId]가 선택돼 있으면 빼고, 아니면 더합니다. (Shift+클릭)
  void toggle(String cardId) {
    final Set<String> next = Set<String>.of(ids);
    if (!next.remove(cardId)) {
      next.add(cardId);
    }
    ids = next;
  }

  /// [cardId] 하나만 선택합니다. 다른 것들은 전부 풀립니다.
  void selectOnly(String cardId) {
    ids = <String>{cardId};
  }

  /// 선택을 전부 비웁니다.
  void clear() {
    ids = <String>{};
  }

  /// 마퀴(드래그로 그리는 선택 네모)를 시작합니다.
  ///
  /// [additive]는 Shift를 누른 채 시작했는지입니다. 참이면 지금까지의
  /// 선택을 남겨두고 마퀴에 걸리는 카드를 더합니다. 거짓이면 마퀴에 걸리는
  /// 카드로 통째로 바꿉니다.
  void beginMarquee({required bool additive}) {
    _marqueeBase = Set<String>.of(ids);
    _marqueeAdditive = additive;
    _marqueeMoved = false;
  }

  /// 마퀴에 지금 걸린 카드 번호들([hits])을 선택에 반영합니다.
  ///
  /// 마퀴를 끄는 동안 매번 불려서, 그때까지의 결과를 바로 [ids]에
  /// 반영합니다. 그래야 마퀴를 끄는 동안 카드가 실시간으로 물듭니다.
  void applyMarqueeHits(Set<String> hits) {
    _marqueeMoved = true;
    ids = _marqueeAdditive ? <String>{..._marqueeBase, ...hits} : hits;
  }

  /// 마퀴에서 손을 뗐을 때 부릅니다.
  ///
  /// 움직이지 않고 그냥 뗐다면(=클릭) Shift 없이 시작한 경우에만 선택을
  /// 지우고 `true`를 돌려줍니다 — 부르는 쪽이 이때만 notifyListeners를
  /// 부르면 됩니다. 그 외에는 아무것도 안 바꾸고 `false`를 돌려줍니다.
  bool endMarquee() {
    if (_marqueeMoved || _marqueeAdditive) {
      return false;
    }
    ids = <String>{};
    return true;
  }
}
