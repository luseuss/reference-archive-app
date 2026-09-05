# 레퍼런스를 무드보드로 끌어다 배치하기 — 설계

**작성일**: 2026-09-05
**분류**: 아키텍처(새 상호작용 경로) — `superpowers:brainstorming` 절차를 따름
**선행 스파이크**: 같은 날 진행한 "크로스윈도우 드래그 가능성" 스파이크(코드는 버림).
메인 창 → 무드보드 팝업 창으로 텍스트 드래그가 실제로 되는 것을 확인했습니다.

## 배경

의뢰인 요청: "아카이브 메인화면에서 레퍼런스를 바로 끌어다 배치할 수 있게 만들어줘."

확인 결과, 정확한 요구는 **"열려 있는 판(무드보드) 위로 레퍼런스 카드를 직접
끌어다 놓으면, 놓은 자리에 배치되는 것"** 입니다. "레퍼런스 담기" 대화상자로
고르는 지금 방식보다 훨씬 빠른 경로를 원하는 것으로, PureRef 대체(CLAUDE.md
"무드보드는 PureRef를 대체하는 것이 목표")에 부합하는 자연스러운 다음 단계입니다.

## 이게 왜 "아키텍처" 분류인가

지금(PR #48부터) 데스크톱에서 무드보드는 **항상 메인 창과 다른 OS 창(팝업)**
으로 뜹니다. 따라서 "열려 있는 판 위로 끌어다 놓기"는 사실상 **서로 다른 두
Flutter 엔진(=두 창) 사이의 드래그**가 됩니다. Flutter의 기본 `Draggable`/
`DragTarget`은 한 위젯 트리(=한 창) 안에서만 동작하므로, 이 기능은 기존
컴포넌트를 조합하는 것이 아니라 **새로운 상호작용 경로**를 만드는 일입니다.

## 범위

**포함**
- 메인 화면(레퍼런스 격자)의 카드 **한 장**을 잡아 열려 있는 무드보드(팝업
  창)로 끌어다 놓으면, 놓은 지점에 새 카드로 배치됩니다.
- 이미 그 판에 담겨 있는 레퍼런스를 또 끌어다 놓으면, 담지 않고 안내만
  보여줍니다("레퍼런스 담기" 대화상자가 이미 담긴 레퍼런스를 애초에
  고를 수 없게 막는 것과 같은 규칙).

**포함하지 않음 (다음 조각)**
- **여러 장을 한꺼번에 드래그.** 의뢰인이 "한 장씩 먼저"를 선택했습니다.
  나중에 필요해지면 별도 작업으로 다룹니다.
- **모바일·태블릿에서의 동작.** 이 플랫폼들은 무드보드가 팝업이 아니라
  메인 내비게이션 스택의 다른 화면으로 뜨므로, 메인 화면과 무드보드가
  애초에 동시에 보이지 않습니다 — "끌어다 놓을 대상"이 같이 있을 수
  없어서 이 기능 자체가 성립하지 않습니다. `supportsBoardPopupWindow`로
  가려 데스크톱에서만 드래그가 시작되게 합니다.
- **판 목록 화면(아직 안 열린 판) 위로 드래그.** "열려 있는 판" 한정입니다.

## 데이터 전달 방식

두 창이 서로 다른 Flutter 엔진이라 Dart 메모리를 안 나눕니다. 그래서
`super_drag_and_drop`의 `DragItem.localData`(같은 앱 안에서만 보이는 값)는
쓸 수 없고, 실제 OS 드래그 페이로드로 실어 보내야 합니다 — 이번 스파이크가
확인한 부분입니다.

- **표준 텍스트 포맷(`Formats.plainText`)에 접두사를 붙인 문자열**을 씁니다.
  `refarchive-reference:<레퍼런스 id>` 형태입니다.
- 커스텀 포맷(`DataFormat` 직접 정의)도 검토했지만, 이번 범위(같은 앱 안
  드래그, 값 하나만 전달)에는 접두사 붙인 일반 텍스트로 충분하고 구현이
  훨씬 단순합니다. 접두사는 브라우저 등에서 끌려온 일반 텍스트와 헷갈리지
  않기 위한 것입니다 — 접두사가 없는 드롭은 조용히 무시합니다.
- 인코딩/디코딩은 새 순수 함수 파일(`lib/utils/reference_drag_payload.dart`)로
  뺍니다. 화면을 안 띄우고 유닛 테스트로 확인할 수 있는 부분입니다.

`super_drag_and_drop`/`super_clipboard`/`super_native_extensions`는 이미 이
프로젝트가 PR #7(웹 이미지 드래그 가져오기)에서 쓰고 있는 의존성입니다 —
**새 패키지를 추가하지 않습니다.** `lib/widgets/home_drop_area.dart`가 이미
`DropRegion`을 쓰고 있어 실전 검증된 경로이기도 합니다.

## 드래그 소스: 레퍼런스 카드

`lib/widgets/reference_card.dart`의 카드 본체를 `DragItemWidget` +
`DraggableWidget`으로 감쌉니다. `dragItemProvider`가
`encodeReferenceDragPayload(item.id)` 값을 `Formats.plainText`에 담아
돌려줍니다.

**데스크톱에서만 감쌉니다** (`supportsBoardPopupWindow`로 가림). 폰·태블릿은
드래그를 시작해도 놓을 대상이 없으므로, 굳이 만지지 않은 카드 위젯 그대로
둡니다 — 이 프로젝트의 다른 플랫폼 차이 처리(`supportsHoverPreview`,
`supportsAlwaysOnTopWindow`)와 같은 방식입니다.

**알려진 위험 — 제스처 아레나.** 카드는 이미 `InkWell`로 탭(상세 열기·선택
모드 토글)을 받고 있습니다. `super_drag_and_drop`의 데스크톱 드래그 인식기
(`_ImmediateMultiDragGestureRecognizer`)는 Flutter의 표준 제스처 아레나에
참여하는 인식기라, `InkWell`의 탭 인식기와 경쟁하게 됩니다. 이 프로젝트는
이미 여러 번(무드보드 카드 끌기 PR #18, 마퀴 선택 PR #25) 이런 경쟁에서 탭이
씹히거나 끌기가 안 먹히는 문제를 겪었습니다. **구현 작업에서 반드시
확인할 것**: 짧게 클릭하면 여전히 상세 화면이 열리는지, 살짝만 끌었을 때
탭으로 씹히지 않고 드래그가 제대로 시작되는지. 문제가 생기면 이 프로젝트가
이미 쓴 해법(카드 안쪽 탭 인식을 `Listener`로 내리는 것 등, `board_canvas.dart`
참고)을 같은 방식으로 적용합니다.

## 드롭 대상: 무드보드 화면

`lib/widgets/board_viewport.dart`가 화면 좌표 ↔ 판 좌표 변환(`_toCanvasPoint`)을
이미 갖고 있으므로, **DropRegion도 여기에 둡니다** — 변환 로직을 다른 곳에
복제하지 않기 위해서입니다.

- `BoardViewport`에 새 콜백 `onReferenceDropped: void Function(String
  referenceId, Offset canvasPosition)?`를 추가합니다.
- 위젯 트리 전체(판을 옮기는 바닥 포함)를 `DropRegion`으로 감쌉니다.
  - `formats: Formats.standardFormats`
  - `onDropOver`: 접두사가 붙은 값인지 확인해 `DropOperation.copy`를
    돌려주고(아니면 `DropOperation.none`), 판 가장자리를 살짝 강조합니다
    (`onDropEnter`/`onDropLeave`로 상태만 켜고 끕니다. 격자 스냅 안내선처럼
    `IgnorePointer`로 감싸 클릭을 가로채지 않게 합니다).
  - `onPerformDrop`: `dataReader.getValue(Formats.plainText, ...)`로 문자열을
    받아 `tryDecodeReferenceDragPayload()`로 해석하고, 성공하면
    `event.position.local`을 `_toCanvasPoint()`로 판 좌표로 바꿔
    `onReferenceDropped`를 부릅니다.
- `BoardScreen`은 이 콜백을 받아 `_handleReferenceDropped(referenceId,
  canvasPosition)`으로 처리합니다:
  1. `_interaction.cards`에 같은 `referenceId`가 이미 있으면 스낵바
     "이미 담겨 있는 레퍼런스입니다"만 띄우고 끝냅니다.
  2. 없으면 `_interaction.addCardAt(referenceId, canvasPosition)`을 부릅니다.

## 카드 생성: `BoardInteractionController.addCardAt`

기존 `addCards(List<String>)`는 자동 배치(`initialCardPosition`)로 여러 장을
줄지어 놓는 용도입니다. 드래그는 **사용자가 직접 고른 자리**에 한 장만
놓아야 하므로 새 메서드를 만듭니다.

```dart
/// 레퍼런스 하나를 [position](판 좌표)에 새 카드로 만들어 담고 저장합니다.
/// 드래그로 끌어다 놓았을 때 씁니다 — addCards()와 달리 자리를 자동으로
/// 정하지 않고 그대로 씁니다.
Future<void> addCardAt(String referenceId, Offset position) async {
  final DateTime now = DateTime.now().toUtc();
  final BoardCard newCard = BoardCard(
    id: newId(),
    boardId: boardId,
    referenceId: referenceId,
    x: position.dx,
    y: position.dy,
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

`onSaved?.call()`을 그대로 부르므로, PR #48에서 만든
`BoardWindowSync.notifyCardsChanged` 경로를 그대로 타 **다른 창에도 자동으로
실시간 반영됩니다.** 이 부분은 새로 만들 것이 없습니다.

카드의 너비·높이는 지정하지 않습니다 — 기존 `addCards()`와 같은 기본값
(`defaultBoardCardWidth`, 그림 비율로 정해지는 높이)을 그대로 따릅니다.

**놓이는 자리는 "카드의 왼쪽 위 모서리가 드롭 지점"입니다.** 커서가 카드
가운데를 가리키도록 보정하는 것도 검토했지만, 드래그 중 보여주는 미리보기
이미지의 정확한 크기를 드롭 시점에 알기 어렵고, 이번 범위에서는 "대략 놓은
자리 근처"면 충분합니다. 어긋남이 거슬리면 다음 조각에서 보정합니다.

## 저장 구조

**안 바뀝니다. 마이그레이션 없음.** `BoardCard`에 새 칸이 필요 없고,
`addCardAt`은 기존 `addCards`가 이미 쓰는 저장 경로(`boardRepository.addCards`)
를 그대로 씁니다.

## 테스트 전략

- **순수 함수는 유닛 테스트로 확인합니다**: `reference_drag_payload.dart`의
  인코딩/디코딩(정상 값, 접두사 없는 값, 빈 문자열), `addCardAt`(저장·
  `onSaved` 호출·중복 시 스낵바 분기는 `LocalBoardRepository` + 메모리
  drift DB로 확인 가능 — `board_interaction_controller_test.dart`의 기존
  패턴을 그대로 따릅니다).
- **실제 네이티브 드래그 자체는 위젯 테스트로 못 잡습니다** (이 프로젝트의
  웹뷰·다중 창 기능들과 같은 사정 — CLAUDE.md 참고). `DropRegion`의
  `onPerformDrop` 콜백은 직접 함수로 호출해 로직만 확인하고, 실제 마우스로
  카드를 끌어다 놓는 것은 `flutter run -d windows`로 의뢰인이 직접
  확인해야 합니다.
- 제스처 아레나 위험(위 참고)도 위젯 테스트로 완전히 잡기 어려운 부류라,
  실제 클릭·드래그 둘 다 되는지 의뢰인이 직접 확인합니다.

## 알려진 한계 (이번 범위에서 의도적으로 남기는 것)

- 여러 장 동시 드래그는 안 됩니다.
- 모바일·태블릿에서는 이 기능 자체가 없습니다(개념상 불가능).
- 드롭 위치는 카드 왼쪽 위 모서리 기준이라, 커서가 카드 한가운데를 가리키는
  것과는 살짝 다를 수 있습니다.
- 판 목록(아직 안 연 판) 위로 드래그하는 것은 다루지 않습니다.
