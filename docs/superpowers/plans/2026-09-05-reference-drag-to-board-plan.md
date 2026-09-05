# 레퍼런스를 무드보드로 끌어다 배치하기 — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 메인 화면의 레퍼런스 카드를 잡아 열려 있는 무드보드(팝업 창) 위로
끌어다 놓으면, 놓은 자리에 새 카드로 배치되게 만든다.

**Architecture:** 이미 프로젝트가 쓰고 있는 `super_drag_and_drop`(PR #7)을
재사용한다. 레퍼런스 id를 접두사 붙인 일반 텍스트(`Formats.plainText`)로
실어 보내고(같은 앱 안 드래그라도 서로 다른 창=엔진이라 `localData`를
못 쓴다), `BoardViewport`가 이미 갖고 있는 화면↔판 좌표 변환을 재사용해
드롭 지점에 정확히 카드를 만든다.

**Tech Stack:** Flutter, `super_drag_and_drop` / `super_clipboard` /
`super_native_extensions`(이미 의존성에 있음, 새로 추가하지 않음).

**Spec:** `docs/superpowers/specs/2026-09-05-reference-drag-to-board-design.md`

## Global Constraints

- **새 패키지를 추가하지 않는다.** `super_drag_and_drop` 계열은 이미
  `pubspec.yaml`에 있다(PR #7).
- **데스크톱 전용이다.** 모든 새 동작은 `services/board_window_sync.dart`의
  `supportsBoardPopupWindow`로 가린다. 이 값이 거짓인 플랫폼(모바일·태블릿)
  에서는 지금 코드와 동작이 하나도 안 바뀌어야 한다.
- **저장 구조를 바꾸지 않는다.** `BoardCard` 모델에 칸을 더하지 않는다.
  마이그레이션 없음.
- **한 번에 한 장만 드래그한다.** 여러 장 동시 드래그는 이번 범위 밖이다.
- **같은 레퍼런스를 여러 번 담아도 막지 않는다** (스펙 "범위" 참고 —
  `BoardCard`는 원래 같은 `referenceId`를 여러 장 허용하도록 설계돼 있다).
- **빈 판(카드 0장) 위 드래그는 다루지 않는다.** `BoardScreen`이 카드가
  없을 때는 `BoardViewport` 자체를 안 그리므로 좌표 변환 기준이 없다.
- 모든 새 파일 상단에 그 파일의 역할을 한국어로, 모든 새 함수 위에
  한국어 한 줄 설명을 단다(비개발자 의뢰인을 위한 이 프로젝트의 규칙,
  `CLAUDE.md` 참고).

---

## Task 1: 드래그 데이터 인코딩/디코딩 (순수 함수)

**Files:**
- Create: `lib/utils/reference_drag_payload.dart`
- Test: `test/utils/reference_drag_payload_test.dart`

**Interfaces:**
- Produces: `String encodeReferenceDragPayload(String referenceId)`,
  `String? tryDecodeReferenceDragPayload(String? payload)` — Task 3(드롭
  받기)과 Task 5(드래그 시작)가 이 두 함수를 가져다 씁니다.

- [ ] **Step 1: 실패하는 테스트부터 쓴다**

`test/utils/reference_drag_payload_test.dart`:

```dart
// reference_drag_payload.dart의 인코딩/디코딩이 서로 짝이 맞는지,
// 우리 것이 아닌 값은 조용히 걸러내는지 확인합니다.

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/utils/reference_drag_payload.dart';

void main() {
  test('레퍼런스 id를 감쌌다가 그대로 풀 수 있다', () {
    final String payload = encodeReferenceDragPayload('ref-123');
    expect(tryDecodeReferenceDragPayload(payload), 'ref-123');
  });

  test('접두사가 없는 값이면 null이다 (다른 곳에서 온 텍스트)', () {
    expect(tryDecodeReferenceDragPayload('그냥 아무 텍스트'), isNull);
  });

  test('null이 들어오면 null이다', () {
    expect(tryDecodeReferenceDragPayload(null), isNull);
  });

  test('접두사만 있고 id가 비어 있으면 null이다', () {
    expect(tryDecodeReferenceDragPayload('refarchive-reference:'), isNull);
  });
}
```

- [ ] **Step 2: 테스트가 실패하는 것을 확인한다**

Run: `flutter test test/utils/reference_drag_payload_test.dart`
Expected: FAIL — `reference_drag_payload.dart`가 아직 없어서 컴파일 오류.

- [ ] **Step 3: 최소 구현을 만든다**

`lib/utils/reference_drag_payload.dart`:

```dart
// 레퍼런스를 무드보드로 끌어다 놓을 때, 드래그 데이터에 담을 문자열을
// 만들고 해석하는 순수 함수 모음입니다.
//
// ── 왜 접두사를 붙이나 ──
// 창 사이 드래그(메인 창 → 무드보드 팝업 창)는 super_drag_and_drop의
// 표준 텍스트 포맷(Formats.plainText)으로 전달됩니다. 이 포맷은 다른
// 어떤 텍스트 드래그(예: 브라우저에서 끌어온 글자)에도 쓰이는 범용
// 포맷이라, 접두사가 없으면 "이게 우리 레퍼런스 드래그인지"를 구분할
// 방법이 없습니다.
//
// ── 왜 여기 있나 ──
// 화면을 안 띄우고 유닛 테스트로 확인할 수 있는 순수 계산이라,
// board_viewport.dart(받는 쪽)와 reference_card.dart(보내는 쪽) 양쪽이
// 이 파일 하나를 가져다 씁니다. 접두사 문자열을 두 곳에 따로 적어두면
// 나중에 오타로 어긋날 수 있습니다.

/// 이 접두사로 시작하는 값만 "레퍼런스를 무드보드로 끌어다 놓은 것"입니다.
const String _referenceDragPrefix = 'refarchive-reference:';

/// 레퍼런스 id를 드래그 데이터로 보낼 문자열로 만듭니다.
String encodeReferenceDragPayload(String referenceId) {
  return '$_referenceDragPrefix$referenceId';
}

/// 드래그 데이터 문자열에서 레퍼런스 id를 꺼냅니다.
///
/// 접두사가 없거나(다른 곳에서 온 텍스트), id 부분이 비어 있으면
/// null을 돌려줍니다 — 이런 값은 조용히 무시하면 됩니다.
String? tryDecodeReferenceDragPayload(String? payload) {
  if (payload == null || !payload.startsWith(_referenceDragPrefix)) {
    return null;
  }

  final String id = payload.substring(_referenceDragPrefix.length);
  return id.isEmpty ? null : id;
}
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `flutter test test/utils/reference_drag_payload_test.dart`
Expected: PASS (4개 전부)

- [ ] **Step 5: 커밋한다**

```bash
git add lib/utils/reference_drag_payload.dart test/utils/reference_drag_payload_test.dart
git commit -m "Task 1: 레퍼런스 드래그 데이터 인코딩/디코딩 함수를 만든다"
```

---

## Task 2: `BoardInteractionController.addCardAt` — 지정한 자리에 카드 한 장 담기

**Files:**
- Modify: `lib/screens/board_interaction_controller.dart`
- Test: `test/screens/board_interaction_controller_test.dart` (기존 파일에 추가)

**Interfaces:**
- Consumes: 없음(기존 클래스의 `_cards`, `boardRepository`, `boardId`,
  `onSaved`, `topZOrderOf`(`utils/board_card_actions.dart`), `newId()`
  (`utils/id_generator.dart`) — 전부 이 파일에 이미 있습니다.
- Produces: `Future<void> addCardAt(String referenceId, Offset position)`
  — Task 4(BoardScreen이 드롭 콜백에서 이걸 부릅니다)가 씁니다.

- [ ] **Step 1: 실패하는 테스트부터 쓴다**

`test/screens/board_interaction_controller_test.dart`의 마지막
`}`(파일을 닫는 중괄호) 바로 앞에 아래 세 테스트를 추가합니다(기존
`setUp`/`tearDown`을 그대로 씁니다):

```dart
  testWidgets('addCardAt은 지정한 자리에 정확히 카드를 놓는다', (
    WidgetTester tester,
  ) async {
    await controller.addCardAt('ref-1', const Offset(120, 340));

    final BoardCard card = controller.cards.single;
    expect(card.referenceId, 'ref-1');
    expect(card.x, 120);
    expect(card.y, 340);
  });

  testWidgets('addCardAt도 onSaved를 한 번 부른다', (WidgetTester tester) async {
    await controller.addCardAt('ref-1', const Offset(0, 0));
    expect(savedCount, 1);
  });

  testWidgets('addCardAt은 같은 레퍼런스를 여러 번 담아도 막지 않는다', (
    WidgetTester tester,
  ) async {
    await controller.addCardAt('ref-1', const Offset(0, 0));
    await controller.addCardAt('ref-1', const Offset(200, 50));

    expect(controller.cards.length, 2);
    expect(
      controller.cards.map((BoardCard c) => c.referenceId).toList(),
      <String>['ref-1', 'ref-1'],
    );
  });
```

- [ ] **Step 2: 테스트가 실패하는 것을 확인한다**

Run: `flutter test test/screens/board_interaction_controller_test.dart`
Expected: FAIL — `addCardAt` 메서드가 아직 없어서 컴파일 오류.

- [ ] **Step 3: `addCardAt`을 구현한다**

`lib/screens/board_interaction_controller.dart`의 `addCards` 메서드
바로 뒤(`removeCard` 메서드 바로 앞)에 추가합니다:

```dart
  /// 레퍼런스 하나를 [position](판 좌표)에 새 카드로 만들어 담고 저장합니다.
  ///
  /// addCards()와 다른 점: addCards()는 여러 장을 자동으로 줄지어
  /// 놓지만(initialCardPosition), 이건 **사용자가 직접 고른 자리**에
  /// 한 장만 그대로 놓습니다. 무드보드로 레퍼런스를 끌어다 놓았을 때
  /// board_screen.dart가 부릅니다.
  ///
  /// 같은 레퍼런스가 이미 판에 있어도 막지 않습니다 — BoardCard는 원래
  /// 같은 레퍼런스를 한 판에 여러 장 놓을 수 있게 만들어져 있고
  /// (referenceId는 같고 id만 다른 카드), 드래그는 한 번에 하나씩
  /// 신중하게 놓는 동작이라 실수로 중복될 위험도 적습니다.
  Future<void> addCardAt(String referenceId, Offset position) async {
    final DateTime now = DateTime.now().toUtc();
    final BoardCard newCard = BoardCard(
      id: newId(),
      boardId: boardId,
      referenceId: referenceId,
      x: position.dx,
      y: position.dy,

      // 방금 놓은 것이 맨 위에 옵니다. addCards()와 같은 규칙입니다.
      zOrder: topZOrderOf(_cards) + 1,
      createdAt: now,
      updatedAt: now,
    );

    await boardRepository.addCards(<BoardCard>[newCard]);
    onSaved?.call();

    _cards = <BoardCard>[..._cards, newCard];
    notifyListeners();
  }
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `flutter test test/screens/board_interaction_controller_test.dart`
Expected: PASS (기존 4개 + 새 3개 = 7개)

- [ ] **Step 5: 커밋한다**

```bash
git add lib/screens/board_interaction_controller.dart test/screens/board_interaction_controller_test.dart
git commit -m "Task 2: BoardInteractionController에 addCardAt(지정한 자리에 담기)을 추가한다"
```

---

## Task 3: `BoardViewport`가 드롭을 받는다

**Files:**
- Modify: `lib/widgets/board_viewport.dart`

**Interfaces:**
- Consumes: `encodeReferenceDragPayload`/`tryDecodeReferenceDragPayload`
  (Task 1), `supportsBoardPopupWindow`(`services/board_window_sync.dart`,
  이미 존재).
- Produces: `BoardViewport`의 새 선택적 생성자 필드
  `final void Function(String referenceId, Offset canvasPosition)?
  onReferenceDropped;` — Task 4가 씁니다. **기존 호출부
  (`board_screen.dart`, `test/widgets/board_viewport_test.dart`)는 이
  필드를 안 넘겨도 컴파일되게 선택적(기본값 null)으로 둡니다** — 안
  그러면 기존 테스트가 깨집니다.

이 작업은 위젯 테스트로 실제 네이티브 드래그를 확인할 수 없는 부류입니다
(스펙의 "테스트 전략" 참고). 그래서 TDD 대신, 기존 위젯 테스트가
**그대로 통과하는지**(회귀 없음)로 안전망을 삼고, 실제 동작 확인은
Task 6(수동 확인)에서 합니다.

- [ ] **Step 1: import를 추가한다**

`lib/widgets/board_viewport.dart` 맨 위 import 목록에 추가합니다
(기존 `import '../theme/app_metrics.dart';` 위나 아래, 다른 import와
같은 자리):

```dart
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../services/board_window_sync.dart';
import '../utils/reference_drag_payload.dart';
```

- [ ] **Step 2: 생성자 필드를 추가한다**

`class BoardViewport extends StatefulWidget`의 생성자와 필드 목록에
추가합니다:

```dart
class BoardViewport extends StatefulWidget {
  const BoardViewport({
    super.key,
    required this.canvasRect,
    required this.contentBounds,
    required this.viewResetCount,
    required this.onMarqueeBegin,
    required this.onMarqueeUpdate,
    required this.onMarqueeEnd,
    required this.onEmptyTap,
    required this.child,
    this.onReferenceDropped,
  });
```

(위 생성자 목록에 `this.onReferenceDropped,`를 마지막 줄로 추가 —
기존 `required` 필드들은 그대로 둡니다.)

`final Widget child;` 필드 선언 바로 뒤에 새 필드를 추가합니다:

```dart
  /// 메인 화면에서 레퍼런스 카드를 이 판 위로 끌어다 놓았을 때 알려줍니다.
  /// [referenceId]는 놓은 레퍼런스의 번호, [canvasPosition]은 놓은 자리를
  /// **판 좌표**로 바꾼 값입니다(화면 좌표가 아닙니다 — 이 파일만 아는
  /// 배율·이동값을 반영해 바꿔서 넘겨줍니다).
  ///
  /// null이면 드롭을 아예 안 받습니다. `supportsBoardPopupWindow`가
  /// 거짓인 플랫폼(모바일·태블릿)에서는 이 콜백을 안 만들어도 되게
  /// 선택적으로 뒀습니다.
  final void Function(String referenceId, Offset canvasPosition)?
  onReferenceDropped;
```

- [ ] **Step 3: 드롭 강조 상태를 추가한다**

`_BoardViewportState`의 `final MarqueeState _marquee = MarqueeState();`
바로 뒤에 추가합니다:

```dart
  /// 레퍼런스를 이 판 위로 끌고 온 동안(아직 놓지는 않은 상태) 참입니다.
  /// 가장자리를 강조해서 "여기 놓으면 된다"를 알려주는 데만 씁니다.
  bool _isDropHighlighted = false;
```

- [ ] **Step 4: `build()`를 DropRegion으로 감싼다**

지금 `build()`의 `LayoutBuilder` 안, `return Listener(...)`로 시작해
`Stack(...)` 전체를 반환하던 부분을 아래처럼 바꿉니다. **`Listener`와
그 안의 `Stack` 자체는 그대로 두고**, 그 결과를 변수에 담아 조건부로
`DropRegion`으로 한 번 더 감쌉니다:

```dart
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size viewport = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        final double scale = _scaleFor(viewport);
        final Offset offset = _offsetFor(viewport, scale);

        // Listener = 손가락·마우스의 날것 신호를 그대로 받는 위젯입니다.
        // 휠 신호는 "끌기"가 아니라서 GestureDetector로는 안 잡힙니다.
        final Widget content = Listener(
          onPointerSignal: (PointerSignalEvent event) =>
              _onPointerSignal(event, viewport),

          child: Stack(
            children: <Widget>[
              // (기존 1~4층 그대로 — 안 건드립니다)
              // ...
            ],
          ),
        );

        // 레퍼런스를 무드보드로 끌어다 놓는 기능이 없는 플랫폼(모바일·
        // 태블릿)이거나, 이 화면이 그 기능을 안 쓰겠다고 하면(콜백이
        // null이면) DropRegion으로 감싸지 않고 그대로 돌려줍니다.
        // super_drag_and_drop이 이미 제 역할을 하는 곳(home_drop_area.dart)
        // 밖에서까지 켜둘 필요가 없습니다.
        if (!supportsBoardPopupWindow || widget.onReferenceDropped == null) {
          return content;
        }

        return DropRegion(
          // 우리가 보내는 것(Formats.plainText에 접두사 붙인 문자열)만
          // 받습니다. 접두사가 없는 값(다른 곳에서 온 텍스트)은
          // onPerformDrop에서 조용히 무시합니다.
          formats: const <DataFormat<Object>>[Formats.plainText],

          // 끌고 지나가는 동안 "놓을 수 있다"고 알려줍니다. 진짜 우리
          // 페이로드인지는 onPerformDrop에서 접두사로 가립니다 —
          // home_drop_area.dart와 같은 수준의 단순함입니다.
          onDropOver: (DropOverEvent event) => DropOperation.copy,

          onDropEnter: (DropEvent event) {
            setState(() => _isDropHighlighted = true);
          },
          onDropLeave: (DropEvent event) {
            setState(() => _isDropHighlighted = false);
          },

          onPerformDrop: (PerformDropEvent event) async {
            setState(() => _isDropHighlighted = false);

            final DropItem item = event.session.items.first;
            item.dataReader?.getValue<String>(Formats.plainText, (
              String? value,
            ) {
              final String? referenceId = tryDecodeReferenceDragPayload(
                value,
              );
              if (referenceId == null) {
                return;
              }

              final Offset canvasPoint = _toCanvasPoint(
                event.position.local,
                viewport,
              );
              widget.onReferenceDropped?.call(referenceId, canvasPoint);
            });
          },

          child: Stack(
            children: <Widget>[
              content,

              // 끄는 동안에만 가장자리를 강조합니다. 격자 스냅 안내선과
              // 같은 이유로 IgnorePointer로 감쌉니다 — 안 그러면 이
              // 겹치는 네모가 클릭을 가로채 판이 안 움직입니다.
              if (_isDropHighlighted)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
```

**주의**: 위 코드 블록의 `// (기존 1~4층 그대로 — 안 건드립니다)` 부분은
설명을 위해 생략한 것입니다. 실제 작업에서는 지금 파일에 있는 `Stack`의
children(1층 판 이동 바닥, 2층 카드, 3층 마퀴 네모, 4층 확대·축소 버튼)을
**그대로** `content`를 만드는 `Listener`의 `Stack` 안에 둡니다 — 내용은
한 글자도 안 바꿉니다. 바뀌는 것은 "그 `Listener` 전체를 변수에 담고,
그 변수를 그대로 돌려줄지 `DropRegion`으로 한 번 더 감싸서 돌려줄지"
뿐입니다.

- [ ] **Step 5: `flutter analyze`로 확인한다**

Run: `flutter analyze lib/widgets/board_viewport.dart`
Expected: 이슈 없음.

- [ ] **Step 6: 기존 위젯 테스트가 그대로 통과하는지 확인한다 (회귀 없음)**

Run: `flutter test test/widgets/board_viewport_test.dart`
Expected: PASS — `onReferenceDropped`를 안 넘기므로
(`test/widgets/board_viewport_test.dart`는 안 고칩니다) 자동으로 null이
되어 `DropRegion`으로 안 감싸지고, 지금까지의 동작이 그대로입니다.

Run: `flutter test test/screens/board_screen_test.dart`
Expected: PASS (기존 그대로 — 이 Task에서는 board_screen.dart를 아직
안 고쳤으므로 `onReferenceDropped`가 안 넘어가 null입니다.)

- [ ] **Step 7: 커밋한다**

```bash
git add lib/widgets/board_viewport.dart
git commit -m "Task 3: BoardViewport가 레퍼런스 드롭을 받아 판 좌표로 알려주게 한다"
```

---

## Task 4: `BoardScreen`이 드롭을 카드 담기로 연결한다

**Files:**
- Modify: `lib/screens/board_screen.dart`

**Interfaces:**
- Consumes: `BoardViewport.onReferenceDropped`(Task 3),
  `BoardInteractionController.addCardAt`(Task 2).

- [ ] **Step 1: `BoardViewport(...)` 호출에 콜백을 추가한다**

`lib/screens/board_screen.dart`의 `BoardViewport(` 호출(지금
`onEmptyTap: ...,` 다음 줄, `child: BoardCanvas(...)` 앞) 사이에 추가합니다:

```dart
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

              // 메인 화면에서 레퍼런스를 끌어다 놓으면 그 자리에 담습니다.
              // 좌표 변환(화면→판)은 BoardViewport가 이미 해서 넘겨줍니다.
              onReferenceDropped: _interaction.addCardAt,

              child: BoardCanvas(
```

(`_interaction.addCardAt`의 시그니처 `Future<void> Function(String,
Offset)`가 `onReferenceDropped`의 `void Function(String, Offset)?`
자리에 그대로 들어갑니다 — 이 프로젝트가 이미 여러 곳에서 쓰는 패턴입니다.
예: `onRemoveCard: _interaction.removeCard`도 `Future<void> Function`을
`ValueChanged`(=`void Function`) 자리에 그대로 씁니다.)

- [ ] **Step 2: `flutter analyze`로 확인한다**

Run: `flutter analyze lib/screens/board_screen.dart`
Expected: 이슈 없음.

- [ ] **Step 3: 기존 위젯 테스트가 그대로 통과하는지 확인한다**

Run: `flutter test test/screens/board_screen_test.dart`
Expected: PASS — 새 콜백을 하나 넘겼을 뿐, 기존 동작은 안 바뀌었습니다.

- [ ] **Step 4: 커밋한다**

```bash
git add lib/screens/board_screen.dart
git commit -m "Task 4: BoardScreen에서 레퍼런스 드롭을 addCardAt으로 연결한다"
```

---

## Task 5: `ReferenceCard`를 무드보드로 끌 수 있게 만든다

**Files:**
- Modify: `lib/widgets/reference_card.dart`

**Interfaces:**
- Consumes: `encodeReferenceDragPayload`(Task 1),
  `supportsBoardPopupWindow`(기존).

이것도 실제 네이티브 드래그를 위젯 테스트로 확인할 수 없는 부류입니다.
기존 `ReferenceCard` 관련 위젯 테스트(카드 목록에 쓰이는 화면들의
테스트)가 **그대로 통과하는지**로 회귀만 확인하고, 실제 드래그·클릭
동작은 Task 6에서 확인합니다.

- [ ] **Step 1: import를 추가한다**

`lib/widgets/reference_card.dart` 맨 위 import 목록에 추가합니다:

```dart
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../services/board_window_sync.dart';
import '../utils/reference_drag_payload.dart';
```

- [ ] **Step 2: `_buildCard`가 조건부로 드래그 가능하게 감싸게 한다**

지금 `_buildCard` 메서드는 이렇게 끝납니다:

```dart
  Widget _buildCard(BuildContext context, bool isHovered) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppPalette palette = AppPalette.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, isHovered ? -2 : 0, 0),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(appCornerRadius),
        border: Border.all(
          color: isSelected ? colors.primary : palette.border,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isHovered ? palette.cardShadowHovered : palette.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isSelectionMode ? onSelectToggle : onTap,
        onLongPress: onSelectToggle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ReferenceCardThumbnail(
              item: item,
              imagePath: imagePath,
              isSelectionMode: isSelectionMode,
              isSelected: isSelected,
              onSelectToggle: onSelectToggle,
              onPlay: onPlay,
              isPreviewPlaying: isPreviewPlaying,
              previewUrl: previewUrl,
            ),
            ReferenceCardBody(
              item: item,
              taxonomyNames: taxonomyNames,
              isSelectionMode: isSelectionMode,
              onDelete: onDelete,
            ),
          ],
        ),
      ),
    );
  }
```

`return AnimatedContainer(...)`를 지역 변수에 담고, 그 뒤에 조건부
드래그 포장을 추가하도록 바꿉니다 — `AnimatedContainer(...)` 자체의
내용(속성 하나하나)은 **한 글자도 바꾸지 않습니다**:

```dart
  Widget _buildCard(BuildContext context, bool isHovered) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppPalette palette = AppPalette.of(context);

    final Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, isHovered ? -2 : 0, 0),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(appCornerRadius),
        border: Border.all(
          color: isSelected ? colors.primary : palette.border,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isHovered ? palette.cardShadowHovered : palette.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isSelectionMode ? onSelectToggle : onTap,
        onLongPress: onSelectToggle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ReferenceCardThumbnail(
              item: item,
              imagePath: imagePath,
              isSelectionMode: isSelectionMode,
              isSelected: isSelected,
              onSelectToggle: onSelectToggle,
              onPlay: onPlay,
              isPreviewPlaying: isPreviewPlaying,
              previewUrl: previewUrl,
            ),
            ReferenceCardBody(
              item: item,
              taxonomyNames: taxonomyNames,
              isSelectionMode: isSelectionMode,
              onDelete: onDelete,
            ),
          ],
        ),
      ),
    );

    // 무드보드로 끌어다 놓는 것은 데스크톱에서만 됩니다 — 팝업 창이
    // 있어야 놓을 대상이 생기고, 폰·태블릿은 그 개념 자체가 없습니다
    // (services/board_window_sync.dart의 supportsBoardPopupWindow).
    //
    // 고르기 모드 중에는 감싸지 않습니다. 고르기 모드에서 카드를 누르면
    // "고르기"가 되어야 하는데, 드래그 인식기까지 끼면 살짝 끄는 것만으로
    // 고르기가 씹힐 위험이 생깁니다 — 고르기 모드는 여러 장을 빠르게
    // 토글하는 동작이라 그 위험을 감수할 이유가 없습니다.
    if (!supportsBoardPopupWindow || isSelectionMode) {
      return card;
    }

    return DragItemWidget(
      dragItemProvider: (DragItemRequest request) async {
        final DragItem dragItem = DragItem();
        dragItem.add(Formats.plainText(encodeReferenceDragPayload(item.id)));
        return dragItem;
      },
      allowedOperations: () => <DropOperation>[DropOperation.copy],
      child: DraggableWidget(child: card),
    );
  }
```

- [ ] **Step 3: `flutter analyze`로 확인한다**

Run: `flutter analyze lib/widgets/reference_card.dart`
Expected: 이슈 없음.

- [ ] **Step 4: 기존 위젯 테스트가 그대로 통과하는지 확인한다 (회귀 없음)**

`ReferenceCard`를 쓰는 화면들의 테스트가 여럿 있습니다(`test/widget_test.dart`,
`test/screens/home_bulk_select_test.dart`,
`test/screens/home_hover_preview_test.dart` 등). 위젯 테스트 환경에서는
`supportsBoardPopupWindow`가 항상 거짓이므로(이 프로젝트의 다른
데스크톱 전용 기능들과 같은 사정 — `board_window_controller_test.dart`
참고), `DragItemWidget`/`DraggableWidget`으로 감싸지는 경로 자체가
테스트에서는 실행되지 않습니다. 즉 이 변경은 테스트 환경에서는
**아무 영향이 없어야 합니다.**

Run: `flutter test`
Expected: PASS 전부 (지금까지의 전체 테스트 수 + Task 1~2에서 늘어난
개수만큼).

- [ ] **Step 5: 커밋한다**

```bash
git add lib/widgets/reference_card.dart
git commit -m "Task 5: ReferenceCard를 데스크톱에서 무드보드로 끌 수 있게 만든다"
```

---

## Task 6: 실제로 앱을 띄워 확인한다 (수동 확인)

이 기능의 핵심(실제 마우스 드래그, 창 사이 이동, 제스처 아레나 경쟁
여부)은 위젯 테스트로 확인할 수 없습니다. `flutter run -d windows`로
직접 켜서 아래를 하나씩 확인합니다. 코드 변경은 없습니다 — 문제가
발견되면 해당 Task로 돌아가 고칩니다.

**Files:** 없음 (확인 전용)

- [ ] **Step 1: 빌드 확인**

Run: `flutter analyze` (전체), `flutter test`(전체), `flutter build windows`
Expected: 전부 통과·성공.

- [ ] **Step 2: 기본 클릭 동작이 안 깨졌는지 확인 (제스처 아레나 위험)**

`flutter run -d windows`로 앱을 켜고:
1. 레퍼런스 카드를 **그냥 클릭**(끌지 않고) → 상세 화면(또는 대화상자)이
   열리는지 확인합니다.
2. 카드를 **길게 눌러** 고르기 모드로 들어가지는지 확인합니다.
3. 고르기 모드에서 카드를 눌러 **체크가 토글**되는지 확인합니다(드래그
   인식기가 안 끼어드는지).

문제가 있으면(클릭이 씹히거나 안 열리면) Task 5로 돌아가 스펙의 "알려진
위험 — 제스처 아레나" 절에 적어둔 대로, 카드 안쪽 탭 인식을 `Listener`로
내리는 방식(`board_canvas.dart` 참고)을 검토합니다.

- [ ] **Step 3: 실제 드래그 앤 드롭 확인**

1. 무드보드 목록에서 판을 하나 열어(탭 하나로 팝업이 뜹니다 — PR #48)
   그 판에 카드를 최소 1장 이상 올려둡니다(드래그 앤 드롭은 빈 판에서는
   안 되므로).
2. 메인 창의 레퍼런스 카드 하나를 잡아 팝업 창 위로 끌어다 놓습니다.
3. 놓은 자리 근처에 새 카드로 배치되는지 확인합니다.
4. 놓는 동안 판 가장자리가 강조되는지 확인합니다.
5. 이미 그 판에 있는 레퍼런스를 또 끌어다 놓아도(막지 않고) 새 카드로
   더 담기는지 확인합니다.
6. 관계없는 텍스트(예: 메모장에 적힌 글자)를 팝업 창 위로 끌어다 놓았을
   때 **아무 일도 안 일어나는지**(접두사가 없어 무시됨) 확인합니다.

- [ ] **Step 4: 결과를 `update.md`에 기록할 준비**

문제 없이 확인됐다면, 다음 단계(CLAUDE.md/update.md 정리, PR)로
넘어갑니다. 이 계획 문서에는 별도 커밋할 코드 변경이 없습니다.
