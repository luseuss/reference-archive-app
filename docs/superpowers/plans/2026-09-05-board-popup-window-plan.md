# 무드보드 팝업 창 구현 계획

> **For agentic workers:** 이 계획은 한 세션에서 직접 실행합니다(단순
> 실행형 작업). 각 작업 뒤 `flutter analyze` + 관련 테스트를 돌리고,
> 전부 끝나면 `flutter test` 전체 + `flutter run -d windows`로 실제
> 두 창을 띄워 확인합니다.

**Goal:** 무드보드 판 하나를 메인 창에서 뽑아내 별도 OS 창(팝업)으로
띄우고, 두 창 사이에 카드 변경이 실시간으로 반영되게 한다.

**Architecture:** `desktop_multi_window`(v0.3.1, 이미 설치·검증됨)로
같은 프로세스 안에 두 번째 Flutter 엔진(창)을 띄운다. 두 창은 각자
`AppDatabase`를 열지만 같은 sqlite 파일을 가리킨다. 카드를 저장할
때마다 `WindowMethodChannel`로 상대 창에 "이 판 바뀌었다"는 신호를
보내고, 받은 쪽은 자기 연결로 다시 읽어온다.

**Tech Stack:** Flutter, `desktop_multi_window: ^0.3.1`(신규),
`window_manager: ^0.5.2`(기존, 창 크기/닫기 가로채기에 재사용).

**Spec:** `docs/superpowers/specs/2026-09-05-board-popup-window-design.md`

## Global Constraints

- 팝업으로 보여줄 판은 **지금 메인 창에서 열어둔 판 하나뿐**입니다.
  목록에서 판을 골라 바로 팝업으로 여는 기능은 범위 밖입니다.
- **팝업은 한 번에 하나만.** 이미 떠 있으면 새로 열지 않고 그 팝업이
  다른 판을 보여주도록 바꿉니다.
- **메인 창을 닫으면 팝업도 같이 닫힙니다.**
- **두 창 사이 카드 변경은 실시간으로 반영됩니다.** 드래그/크기조절
  **도중**에는 신호를 보내지 않고, 저장이 확정된 순간에만 보냅니다.
- **데스크톱(Windows/macOS/Linux)에서만** 팝업 관련 UI가 보입니다.
  폰·태블릿에는 통째로 숨깁니다(`board_window_controller.dart`의
  `supportsAlwaysOnTopWindow`와 같은 판정 방식, 값은 같지만 이 기능
  전용으로 새로 선언합니다 — 기존 관례).
- **`window_manager`는 이미 있는 의존성을 그대로 씁니다.** 새 포크로
  바꾸지 않습니다. (README가 포크 버전을 언급하지만, 실제로 문제가
  나타나기 전에는 바꾸지 않습니다 — 미리 최적화하지 않는다는 이
  프로젝트 원칙)
- **`desktop_multi_window`의 실제 API는 pub 캐시에 받아진 v0.3.1
  소스(`example/lib/main.dart` 등)로 이미 확인했습니다.** 아래 코드는
  전부 그 확인된 API를 그대로 씁니다:
  `WindowController.fromCurrentEngine()`, `.arguments`,
  `WindowController.create(WindowConfiguration(...))`, `.show()`,
  `.close()`, `WindowMethodChannel(name, mode: ChannelMode.bidirectional)`,
  `.setMethodCallHandler(...)`, `.invokeMethod(...)`.

## 새로 나온 개념 (PR 본문에 설명 예정)

- **`desktop_multi_window`** — 하나의 Flutter 앱이 진짜 OS 창을 여러
  개 띄우게 해주는 패키지입니다. 각 창은 독립된 Flutter 엔진(화면을
  그리는 단위)을 갖지만 같은 프로세스 안에서 돕니다.
- **창간 메시지(`WindowMethodChannel`)** — 두 창이 메모리를 안
  나누므로, "이런 일이 있었다"고 서로 알리는 통로가 따로 필요합니다.
  `bidirectional` 모드는 딱 둘(메인·팝업)만 서로 부를 수 있게 짝지어
  줍니다.
- **`WindowListener`(window_manager)** — 창의 닫기 버튼을 직접 처리할
  수 있게 해주는 콜백 묶음입니다. "닫기 눌렀을 때 팝업부터 정리하고
  진짜로 닫기"를 만드는 데 씁니다.

---

### Task 1: 네이티브 러너에 다중 창 플러그인 등록 코드 추가

**Files:**
- Modify: `windows/runner/flutter_window.cpp`
- Modify: `macos/Runner/MainFlutterWindow.swift`
- Modify: `linux/my_application.cc`

**Interfaces:**
- Produces: 팝업 창(두 번째 Flutter 엔진)에서도 지금 쓰는 플러그인
  (drift/sqlite3, window_manager, shared_preferences 등)이 전부
  똑같이 등록되어 동작함.

`desktop_multi_window` 패키지 README(`Working with Plugins in
Sub-Windows`)가 요구하는 표준 등록 코드입니다. 창을 새로 만들 때마다
그 창의 엔진에도 플러그인을 등록해주지 않으면, 팝업 창에서는
데이터베이스도 창 관리도 전부 먹통이 됩니다.

- [ ] **Step 1: `windows/runner/flutter_window.cpp` 수정**

```diff
 #include "flutter_window.h"
 
 #include <optional>
 
 #include "flutter/generated_plugin_registrant.h"
+#include "desktop_multi_window/desktop_multi_window_plugin.h"
```

`OnCreate()` 안, `RegisterPlugins(flutter_controller_->engine());` 바로
다음 줄에 추가:

```cpp
  // 팝업으로 뜨는 두 번째 창(desktop_multi_window)에도 이 창과 똑같이
  // 플러그인(데이터베이스, window_manager 등)이 등록되게 합니다.
  // 안 하면 팝업 창에서는 무드보드가 아예 안 열립니다.
  DesktopMultiWindowSetWindowCreatedCallback([](void *controller) {
    auto *flutter_view_controller =
        reinterpret_cast<flutter::FlutterViewController *>(controller);
    auto *registry = flutter_view_controller->engine();
    RegisterPlugins(registry);
  });
```

- [ ] **Step 2: `macos/Runner/MainFlutterWindow.swift` 수정**

```diff
 import Cocoa
 import FlutterMacOS
+import desktop_multi_window
```

`awakeFromNib()` 안, `RegisterGeneratedPlugins(registry: flutterViewController)`
다음 줄에 추가:

```swift
    // 팝업으로 뜨는 두 번째 창에도 플러그인이 등록되게 합니다.
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
    }
```

- [ ] **Step 3: `linux/my_application.cc` 수정**

```diff
 #include "my_application.h"
 
 #include <flutter_linux/flutter_linux.h>
 #ifdef GDK_WINDOWING_X11
 #include <gdk/gdkx.h>
 #endif
 
 #include "flutter/generated_plugin_registrant.h"
+#include "desktop_multi_window/desktop_multi_window_plugin.h"
```

`my_application_activate()` 안, `fl_register_plugins(FL_PLUGIN_REGISTRY(view));`
다음 줄에 추가:

```cpp
  // 팝업으로 뜨는 두 번째 창에도 플러그인이 등록되게 합니다.
  desktop_multi_window_plugin_set_window_created_callback([](FlPluginRegistry* registry){
    fl_register_plugins(registry);
  });
```

- [ ] **Step 4: Windows에서 빌드 확인**

Run: `flutter build windows`
Expected: 성공. (macOS/Linux는 이 프로젝트가 개발 중인 기기가 아니라
빌드 확인을 못 합니다 — CLAUDE.md에도 Windows 중심으로 개발한다고
적혀 있습니다. 코드는 README 그대로라 틀릴 여지가 적습니다.)

- [ ] **Step 5: 커밋**

```bash
git add windows/runner/flutter_window.cpp macos/Runner/MainFlutterWindow.swift linux/my_application.cc
git commit -m "다중 창 플러그인 등록 코드를 추가한다"
```

---

### Task 2: `BoardInteractionController`에 저장 완료 신호(`onSaved`) 추가

**Files:**
- Modify: `lib/screens/board_interaction_controller.dart`
- Test: `test/screens/board_interaction_controller_test.dart` (새 파일)

**Interfaces:**
- Consumes: 없음 (기존 클래스 확장)
- Produces: `BoardInteractionController({..., this.onSaved})` — 새
  선택 인자. 카드가 실제로 저장될 때마다(추가/내리기/드래그 끝/
  크기조절 끝/여러 장 내리기/정렬/크기 맞추기) 한 번씩 불립니다.
  드래그·크기조절 **도중**에는 안 불립니다.

- [ ] **Step 1: 생성자에 콜백 필드 추가**

`lib/screens/board_interaction_controller.dart`의 클래스 선언 바로
아래(생성자 위)에 추가:

```dart
  /// 카드가 실제로 저장될 때마다(추가·내리기·드래그 끝·크기조절 끝·
  /// 정렬·크기 맞추기) 한 번씩 불립니다. 드래그·크기조절 **도중**에는
  /// 안 불립니다 — 그때는 아직 저장 전이라 화면에서만 바뀌는 값입니다.
  ///
  /// 무드보드 팝업 창(board_popup_controller.dart)이 이 콜백으로
  /// "이 판이 바뀌었다"를 상대 창에 알립니다. 이 클래스 자체는
  /// desktop_multi_window를 몰라도 됩니다 — 저장 로직과 창간 통신은
  /// 다른 관심사입니다.
  final VoidCallback? onSaved;
```

생성자를 다음으로 바꿉니다:

```dart
  BoardInteractionController({
    required this.boardId,
    required this.boardRepository,
    this.onSaved,
  });
```

- [ ] **Step 2: 저장이 끝나는 지점마다 `onSaved` 호출**

아래 메서드들의 **DB 쓰기가 끝난 직후**(각 메서드에서 `boardRepository`를
부른 바로 다음 줄)에 `onSaved?.call();`을 추가합니다. `notifyListeners()`
호출과는 별개입니다 — `notifyListeners()`는 "화면을 다시 그려라",
`onSaved`는 "다른 창에 알려라"로 뜻이 다릅니다.

`addCards`:
```dart
    await boardRepository.addCards(newCards);
    onSaved?.call();

    _cards = <BoardCard>[..._cards, ...newCards];
    notifyListeners();
```

`removeCard`:
```dart
    await boardRepository.removeCard(card.id);
    onSaved?.call();

    _cards = _cards.where((BoardCard each) => each.id != card.id).toList();
    notifyListeners();
```

`_saveCard`(끝에 추가, `if (index == -1) return;` 다음):
```dart
  Future<void> _saveCard(String cardId) async {
    final int index = indexOfCard(_cards, cardId);
    if (index == -1) {
      return;
    }

    await boardRepository.saveCard(_cards[index]);
    onSaved?.call();
  }
```

`_saveCards`(끝에 추가, `if (toSave.isEmpty) return;` 다음):
```dart
  Future<void> _saveCards(Set<String> cardIds) async {
    final List<BoardCard> toSave = _cards
        .where((BoardCard card) => cardIds.contains(card.id))
        .toList();

    if (toSave.isEmpty) {
      return;
    }

    await boardRepository.saveCards(toSave);
    onSaved?.call();
  }
```

`removeSelectedCards`(반복문 뒤, `_cards = _cards.where(...)` 앞):
```dart
    for (final String cardId in toRemove) {
      await boardRepository.removeCard(cardId);
    }
    onSaved?.call();

    _cards = _cards
        .where((BoardCard card) => !toRemove.contains(card.id))
        .toList();
```

`_saveCard`/`_saveCards`를 쓰는 `onResizeEnd`/`onDragEnd`/`alignSelected`/
`matchSizeSelected`는 **이미 위에서 고친 `_saveCard`/`_saveCards`를
그대로 거치므로 따로 손댈 곳이 없습니다.**

- [ ] **Step 2.5: 클래스 위 파일 설명에 한 줄 추가**

파일 맨 위 설명 블록(`// ── ChangeNotifier가 무엇인가 ──` 다음)에
문단 하나를 추가합니다:

```dart
//
// ── onSaved는 무엇인가 (무드보드 팝업 창) ──
// 카드가 저장될 때마다 board_popup_controller.dart가 이 신호를 받아
// 상대 창(메인 ↔ 팝업)에 "이 판이 바뀌었다"고 알립니다. 자세한 설명은
// onSaved 필드 주석 참고.
```

- [ ] **Step 3: 테스트 작성**

`test/screens/board_interaction_controller_test.dart`(새 파일):

```dart
// BoardInteractionController의 onSaved 콜백이 저장이 실제로 끝난
// 순간에만 불리는지 확인하는 테스트입니다.
//
// ── 왜 확인하나 ──
// 무드보드 팝업 창(board_popup_controller.dart)이 이 신호를 받아
// 상대 창에 "다시 읽어라"고 알립니다. 드래그 **도중**에도 매번
// 신호가 나가면 상대 창이 매 프레임 다시 그리려 들어 버벅입니다.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/board.dart';
import 'package:reference_archive_app/repositories/local_board_repository.dart';
import 'package:reference_archive_app/screens/board_interaction_controller.dart';
import 'package:reference_archive_app/utils/board_card_actions.dart';
import 'package:reference_archive_app/utils/id_generator.dart';

void main() {
  late AppDatabase db;
  late LocalBoardRepository repository;
  late BoardInteractionController controller;
  late int savedCount;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalBoardRepository(db);
    savedCount = 0;

    final DateTime now = DateTime.now().toUtc();
    await repository.saveBoard(
      Board(id: 'board-1', name: '테스트 판', createdAt: now, updatedAt: now),
    );

    controller = BoardInteractionController(
      boardId: 'board-1',
      boardRepository: repository,
      onSaved: () => savedCount++,
    );
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('카드를 담으면 onSaved가 한 번 불린다', (WidgetTester tester) async {
    await controller.addCards(<String>['ref-1', 'ref-2']);
    expect(savedCount, 1);
  });

  testWidgets('카드를 내리면 onSaved가 한 번 불린다', (WidgetTester tester) async {
    await controller.addCards(<String>['ref-1']);
    savedCount = 0;

    await controller.removeCard(controller.cards.single);
    expect(savedCount, 1);
  });

  testWidgets('드래그 도중에는 onSaved가 안 불리고, 손을 떼야 불린다', (
    WidgetTester tester,
  ) async {
    await controller.addCards(<String>['ref-1']);
    savedCount = 0;
    final BoardCard card = controller.cards.single;

    controller.onDragStart(card);
    controller.onDragUpdate(card, const Offset(10, 10));
    controller.onDragUpdate(card, const Offset(10, 10));
    expect(savedCount, 0, reason: '끄는 도중에는 아직 저장 전입니다');

    await controller.onDragEnd(controller.cards.single);
    expect(savedCount, 1);
  });

  testWidgets('크기조절 도중에는 onSaved가 안 불리고, 손을 떼야 불린다', (
    WidgetTester tester,
  ) async {
    await controller.addCards(<String>['ref-1']);
    savedCount = 0;
    final BoardCard card = controller.cards.single;

    controller.onResizeStart(
      card,
      const Size(200, 150),
      BoardResizeCorner.bottomRight,
    );
    controller.onResizeUpdate(card, const Offset(10, 10));
    expect(savedCount, 0);

    await controller.onResizeEnd(controller.cards.single);
    expect(savedCount, 1);
  });
}
```

- [ ] **Step 4: 테스트 실행**

Run: `flutter test test/screens/board_interaction_controller_test.dart`
Expected: 4건 전부 통과

- [ ] **Step 5: 커밋**

```bash
git add lib/screens/board_interaction_controller.dart test/screens/board_interaction_controller_test.dart
git commit -m "BoardInteractionController에 저장 완료 신호(onSaved)를 추가한다"
```

---

### Task 3: 창간 통신 도우미 `BoardWindowSync` + 팝업 창 여닫기 `BoardPopupController`

**Files:**
- Create: `lib/services/board_window_sync.dart`
- Create: `lib/screens/board_popup_controller.dart`

**Interfaces:**
- Consumes: `package:desktop_multi_window`의 `WindowController`,
  `WindowConfiguration`, `WindowMethodChannel`, `ChannelMode`
  (Task 1에서 검증된 실제 API).
- Produces:
  - `BoardWindowSync.notifyCardsChanged(String boardId)`
  - `BoardWindowSync.notifyShowBoard(String boardId)`
  - `BoardWindowSync.setCardsChangedListener(void Function(String)? listener)`
  - `BoardWindowSync.setShowBoardListener(void Function(String)? listener)`
  - `bool supportsBoardPopupWindow` (top-level getter)
  - `BoardPopupController.instance` (싱글턴), `.isOpen`,
    `.showBoard(String boardId)`, `.closeIfOpen()`

- [ ] **Step 1: `lib/services/board_window_sync.dart` 작성**

```dart
// 무드보드 메인 창과 팝업 창이 서로 "이 판이 바뀌었다"/"이 판을
// 보여줘"라는 신호를 주고받는 통로입니다.
//
// ── 왜 필요한가 ──
// 두 창은 desktop_multi_window로 만들어진 서로 다른 Flutter 엔진이라
// 메모리(변수)를 안 나눕니다. drift의 자동 갱신(watch())도 같은
// 프로세스의 같은 연결 안에서만 작동해서 창 사이에는 안 통합니다.
// 그래서 한쪽이 카드를 저장하면(board_interaction_controller.dart의
// onSaved), 상대 창에게 "다시 읽어라"고 명시적으로 알려야 합니다.
//
// ── 창 하나에 신호 받는 곳이 왜 하나뿐인가 ──
// WindowMethodChannel.setMethodCallHandler는 창(엔진) 하나에 핸들러를
// 하나만 등록합니다(다시 부르면 갈아치웁니다). 이 창에서 지금 어떤
// BoardScreen이 열려 있든 신호를 받아야 하므로, 여기서 핸들러를 한 번만
// 등록해두고(ensureInitialized) 실제 화면들은 리스너 자리에 자기
// 콜백을 꽂았다 빼기만 합니다.

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 메인 ↔ 팝업 두 창끼리만 주고받는 채널입니다. bidirectional이라
/// 정확히 둘만 서로를 부를 수 있습니다 — 팝업은 한 번에 하나뿐이므로
/// 딱 맞습니다.
const WindowMethodChannel _channel = WindowMethodChannel(
  'board_popup_sync',
  mode: ChannelMode.bidirectional,
);

/// 이 기기에서 무드보드 팝업 창을 쓸 수 있는지 여부입니다.
///
/// 창이 있는 데스크톱(Windows/macOS/Linux)에서만 뜻이 있습니다.
/// board_window_controller.dart의 supportsAlwaysOnTopWindow와 같은
/// 판정입니다 — 이 기능 전용으로 따로 둡니다(이 프로젝트가 지금까지
/// 플랫폼 판정을 그 기능이 있는 파일마다 따로 두는 방식과 같습니다).
bool get supportsBoardPopupWindow {
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

/// 무드보드 메인 창과 팝업 창 사이의 신호를 주고받습니다.
class BoardWindowSync {
  BoardWindowSync._();

  static bool _initialized = false;
  static void Function(String boardId)? _onCardsChanged;
  static void Function(String boardId)? _onShowBoard;

  /// 이 창(엔진)에서 신호를 받을 준비를 합니다. 여러 번 불러도
  /// 안전합니다(두 번째부터는 조용히 넘어갑니다).
  static void ensureInitialized() {
    if (_initialized) {
      return;
    }
    _initialized = true;

    _channel.setMethodCallHandler((MethodCall call) async {
      final String boardId = call.arguments as String;
      switch (call.method) {
        case 'cardsChanged':
          _onCardsChanged?.call(boardId);
        case 'showBoard':
          _onShowBoard?.call(boardId);
      }
      return null;
    });
  }

  /// "이 판이 바뀌었다"는 신호를 받을 콜백을 꽂습니다. null을 넘기면 뺍니다.
  ///
  /// 지금 열려 있는 BoardScreen이 initState에서 꽂고 dispose에서 뺍니다.
  static void setCardsChangedListener(void Function(String boardId)? listener) {
    _onCardsChanged = listener;
  }

  /// "이 판을 보여줘"라는 신호를 받을 콜백을 꽂습니다. 팝업 창의 바깥
  /// 껍데기(board_popup_app.dart)만 씁니다 — 메인 창은 이 신호를
  /// 받을 일이 없습니다.
  static void setShowBoardListener(void Function(String boardId)? listener) {
    _onShowBoard = listener;
  }

  /// 상대 창에게 "이 판이 바뀌었으니 다시 읽어라"고 알립니다.
  ///
  /// 상대 창이 없으면(팝업을 안 띄웠으면) 조용히 실패합니다 — 알릴
  /// 상대가 없는 것은 오류가 아닙니다.
  static Future<void> notifyCardsChanged(String boardId) =>
      _invoke('cardsChanged', boardId);

  /// 팝업에게 "이 판을 보여줘"라고 알립니다. (메인 → 팝업 전용)
  static Future<void> notifyShowBoard(String boardId) =>
      _invoke('showBoard', boardId);

  static Future<void> _invoke(String method, String boardId) async {
    ensureInitialized();
    try {
      await _channel.invokeMethod(method, boardId);
    } catch (_) {
      // 상대 창이 없거나 아직 준비되지 않았습니다. 조용히 넘어갑니다.
    }
  }
}
```

- [ ] **Step 2: `lib/screens/board_popup_controller.dart` 작성**

```dart
// 무드보드 판을 별도 OS 창(팝업)으로 띄우고 관리합니다.
//
// ── 왜 싱글턴인가 ──
// "팝업은 한 번에 하나만"이라는 규칙(CLAUDE.md, 설계 스펙)을 지키려면
// 지금 팝업이 떠 있는지·어느 창인지를 앱 전체에서 하나만 알고 있어야
// 합니다. 무드보드 화면(board_screen.dart)을 열 때마다 새로 만들면
// 이 정보가 흩어집니다.
//
// ── 메인 창을 닫을 때도 이걸 씁니다 ──
// lib/main.dart가 메인 창의 닫기를 가로챌 때 이 컨트롤러의
// closeIfOpen()을 불러 팝업부터 정리합니다.

import 'package:desktop_multi_window/desktop_multi_window.dart';

import '../services/board_window_sync.dart';

/// 무드보드 팝업 창을 열고 닫는 일을 맡습니다.
class BoardPopupController {
  BoardPopupController._();

  /// 앱 전체에서 하나만 씁니다.
  static final BoardPopupController instance = BoardPopupController._();

  WindowController? _popup;

  /// 지금 팝업이 떠 있는지 여부입니다.
  bool get isOpen => _popup != null;

  /// 팝업으로 [boardId]를 보여줍니다.
  ///
  /// 이미 팝업이 떠 있으면 새로 열지 않고, 그 팝업에게 "이 판을
  /// 보여줘"라고 신호만 보냅니다(한 번에 하나만 띄운다는 규칙).
  Future<void> showBoard(String boardId) async {
    final WindowController? existing = _popup;
    if (existing != null) {
      await BoardWindowSync.notifyShowBoard(boardId);
      await existing.show();
      return;
    }

    // arguments는 그냥 판 번호(boardId) 문자열입니다. 이 앱은 팝업 창이
    // 딱 한 종류(무드보드)뿐이라, 여러 창 종류를 가리는 JSON 값을
    // 만들 필요가 없습니다.
    final WindowController created = await WindowController.create(
      WindowConfiguration(hiddenAtLaunch: true, arguments: boardId),
    );
    _popup = created;
    await created.show();
  }

  /// 떠 있는 팝업을 닫습니다. 없으면 아무 일도 안 합니다.
  Future<void> closeIfOpen() async {
    final WindowController? popup = _popup;
    _popup = null;
    if (popup == null) {
      return;
    }

    try {
      await popup.close();
    } catch (_) {
      // 이미 닫혔거나(사용자가 직접 닫음) 창을 못 찾으면 무시합니다.
    }
  }
}
```

- [ ] **Step 3: `flutter analyze`로 확인**

Run: `flutter analyze`
Expected: 문제 없음

- [ ] **Step 4: 커밋**

```bash
git add lib/services/board_window_sync.dart lib/screens/board_popup_controller.dart
git commit -m "무드보드 창간 통신(BoardWindowSync)과 팝업 열기/닫기(BoardPopupController)를 만든다"
```

---

### Task 4: `BoardScreen`이 신호를 보내고 받게 연결 + 팝업으로 띄우기 버튼

**Files:**
- Modify: `lib/screens/board_screen.dart`
- Modify: `lib/widgets/board_toolbar_actions.dart`
- Test: `test/screens/board_screen_test.dart` (기존 파일에 케이스 추가
  하지 않음 — 실제 창 관련 동작은 위젯 테스트로 못 잡습니다. 대신
  "팝업 버튼이 데스크톱이 아니면 안 보인다"류의 기존 패턴이 있는지
  확인하고, 있으면 그 옆에 한 줄 추가합니다. Step 3 참고)

**Interfaces:**
- Consumes: Task 2의 `onSaved`, Task 3의 `BoardWindowSync`/
  `BoardPopupController`/`supportsBoardPopupWindow`.
- Produces: `BoardScreen`에 `canPopOut`(기본 `true`) 선택 인자 추가.

- [ ] **Step 1: `board_screen.dart` — import 추가**

```dart
import '../services/board_window_sync.dart';
import 'board_popup_controller.dart';
```

- [ ] **Step 2: `BoardScreen` 위젯에 `canPopOut` 필드 추가**

```dart
class BoardScreen extends StatefulWidget {
  const BoardScreen({
    super.key,
    required this.board,
    required this.boardRepository,
    required this.referenceRepository,
    required this.imageStorage,
    this.canPopOut = true,
  });

  // ...(기존 필드 그대로)...

  /// "팝업으로 띄우기" 버튼을 보여줄지 여부입니다.
  ///
  /// 팝업 창 자기 자신 안에서 또 팝업을 띄우는 것은 뜻이 없어서,
  /// board_popup_app.dart가 이 화면을 열 때는 거짓으로 넘겨 버튼을
  /// 숨깁니다. 메인 창에서 여는 board_list_screen.dart는 이 값을
  /// 안 넘기므로 기본값(참)을 씁니다 — 그 호출부는 안 고쳐도 됩니다.
  final bool canPopOut;
```

- [ ] **Step 3: `initState`/`dispose`에서 신호 연결**

`_BoardScreenState`에 아래를 추가합니다. `initState()`의 기존 내용
(`_interaction = ...`) 앞뒤로 나눠 넣습니다:

```dart
  @override
  void initState() {
    super.initState();

    _interaction = BoardInteractionController(
      boardId: widget.board.id,
      boardRepository: widget.boardRepository,

      // 카드가 저장될 때마다 상대 창(메인 ↔ 팝업)에 "이 판이
      // 바뀌었다"고 알립니다. 데스크톱이 아니면 아무 상대가 없으니
      // 조용히 실패합니다(BoardWindowSync 안에서 처리).
      onSaved: supportsBoardPopupWindow
          ? () => BoardWindowSync.notifyCardsChanged(widget.board.id)
          : null,
    );

    // 상대 창이 이 판을 바꿨다는 신호를 받으면 다시 읽어옵니다.
    // 데스크톱이 아니면 신호 자체가 안 오므로 등록할 필요가 없습니다.
    if (supportsBoardPopupWindow) {
      BoardWindowSync.setCardsChangedListener((String boardId) {
        if (boardId == widget.board.id) {
          _reloadCards();
        }
      });
    }

    _loadBoard();

    _window.load();
  }
```

`dispose()`에 리스너 해제를 추가합니다(기존 줄들 사이 아무 곳,
`_interaction.dispose()` 전에 두면 됩니다):

```dart
  @override
  void dispose() {
    if (supportsBoardPopupWindow) {
      BoardWindowSync.setCardsChangedListener(null);
    }
    _interaction.dispose();
    _export.dispose();
    _window.dispose();
    super.dispose();
  }
```

- [ ] **Step 4: 다시 읽어오는 함수 추가**

`_loadBoard` 메서드 바로 아래에 추가합니다:

```dart
  /// 상대 창(메인 ↔ 팝업)에서 이 판이 바뀌었다는 신호를 받으면
  /// 카드만 다시 읽어옵니다. _loadBoard와 달리 레퍼런스 목록
  /// (_lookup)은 다시 안 읽습니다 — 카드 배치만 바뀌었을 뿐, 레퍼런스
  /// 자체(제목·그림)는 이 신호로는 안 바뀌기 때문입니다.
  Future<void> _reloadCards() async {
    final List<BoardCard> cards = await widget.boardRepository.getCards(
      widget.board.id,
    );

    if (!mounted) {
      return;
    }

    _interaction.setCards(cards);
  }
```

- [ ] **Step 5: 팝업으로 띄우기 버튼 연결**

`build()`의 `BoardToolbarActions(...)` 호출에 인자를 추가합니다:

```dart
          BoardToolbarActions(
            isLoading: _isLoading,
            interaction: _interaction,
            export: _export,
            window: _window,
            onExport: _exportBoardImage,
            onAddCards: _addCards,
            canPopOut: widget.canPopOut,
            onPopOut: () => BoardPopupController.instance.showBoard(widget.board.id),
          ),
```

- [ ] **Step 6: `board_toolbar_actions.dart`에 버튼 추가**

import 추가:

```dart
import '../services/board_window_sync.dart';
```

생성자와 필드에 추가:

```dart
  const BoardToolbarActions({
    super.key,
    required this.isLoading,
    required this.interaction,
    required this.export,
    required this.window,
    required this.onExport,
    required this.onAddCards,
    required this.canPopOut,
    required this.onPopOut,
  });

  // ...(기존 필드들)...

  /// "팝업으로 띄우기" 버튼을 보여줄지 여부입니다. (BoardScreen.canPopOut)
  final bool canPopOut;

  /// 팝업으로 띄우기 버튼을 눌렀을 때 실행할 동작입니다.
  final VoidCallback onPopOut;
```

"항상 위" 아이콘 버튼 바로 다음에 버튼을 추가합니다:

```dart
            // 팝업으로 띄우기. 데스크톱에서만, 그리고 이 화면이
            // 팝업 자기 자신이 아닐 때만(canPopOut) 보입니다.
            if (supportsBoardPopupWindow && canPopOut)
              IconButton(
                onPressed: isLoading ? null : onPopOut,
                icon: const Icon(Icons.picture_in_picture_alt_outlined),
                tooltip: '팝업으로 띄우기',
              ),
```

- [ ] **Step 7: `flutter analyze` + 기존 위젯 테스트 확인**

Run: `flutter analyze`
Expected: 문제 없음

Run: `flutter test test/screens/board_screen_test.dart test/widgets/board_toolbar_actions_test.dart`
(뒤 파일이 없으면 board_screen_test.dart만) Expected: 전부 통과 —
`canPopOut` 기본값이 `true`라 기존 호출부(테스트 포함)는 안 고쳐도
그대로 컴파일되고 통과해야 합니다. 만약 `board_toolbar_actions.dart`를
직접 인스턴스화하는 테스트가 있어서 새 필수 인자 때문에 컴파일이
깨지면, 그 테스트에도 `canPopOut: true, onPopOut: () {}`를 추가합니다.

- [ ] **Step 8: 커밋**

```bash
git add lib/screens/board_screen.dart lib/widgets/board_toolbar_actions.dart
git commit -m "무드보드 화면에 팝업으로 띄우기 버튼과 실시간 동기화를 연결한다"
```

---

### Task 5: 팝업 창 전용 진입점 `board_popup_app.dart` + `main()` 갈림길

**Files:**
- Create: `lib/screens/board_popup_app.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: Task 3의 `BoardWindowSync`/`supportsBoardPopupWindow`,
  Task 4의 `BoardScreen(canPopOut: false)`.
- Produces: `main()`이 메인 창/팝업 창을 가릅니다.

- [ ] **Step 1: `lib/screens/board_popup_app.dart` 작성**

```dart
// 무드보드를 팝업 창(별도 OS 창)으로 띄울 때, 그 창 전체를 채우는
// 진입점입니다. lib/main.dart가 "이 창은 팝업이다"라고 판단하면
// 이 위젯을 띄웁니다.
//
// ── 왜 이 화면이 따로 필요한가 ──
// board_screen.dart는 "판 하나"를 보여줄 뿐, 어느 판을 보여줄지는
// 밖에서 정해줘야 합니다. 이 화면은 처음 뜰 때 받은 판 번호로 시작해서,
// "다른 판을 보여줘"라는 신호(BoardWindowSync)를 받으면 판 번호를
// 바꿔 BoardScreen을 새로 만듭니다.
//
// ── 데이터베이스를 또 엽니다 ──
// 팝업 창은 메인 창과 다른 Flutter 엔진이라 메모리를 안 나눕니다.
// 그래서 AppDatabase()를 하나 더 엽니다 — 파일 경로가 같으므로
// (data/app_database.dart의 _openConnection 참고) 메인 창과 같은
// 데이터를 봅니다. 2026-08-31 스파이크에서 이미 확인된 방식입니다.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;

import '../data/app_database.dart';
import '../models/board.dart';
import '../repositories/local_board_repository.dart';
import '../repositories/local_reference_repository.dart';
import '../services/board_window_sync.dart';
import '../services/local_image_storage.dart';
import '../theme/app_theme.dart';
import 'board_screen.dart';

/// 팝업 창 전체를 채우는 앱입니다.
///
/// [initialBoardId]는 창을 만들 때 받은 판 번호입니다
/// (board_popup_controller.dart의 WindowConfiguration.arguments).
class BoardPopupApp extends StatefulWidget {
  const BoardPopupApp({super.key, required this.initialBoardId});

  final String initialBoardId;

  @override
  State<BoardPopupApp> createState() => _BoardPopupAppState();
}

class _BoardPopupAppState extends State<BoardPopupApp> {
  /// 팝업 창 전용 데이터베이스 연결입니다. 메인 창과 파일은 같지만
  /// 연결(연결 객체) 자체는 다릅니다.
  final AppDatabase _database = AppDatabase();

  /// 지금 보여주고 있는 판 번호입니다. 메인 창이 "다른 판을 보여줘"라고
  /// 알려오면 바뀝니다.
  late String _boardId;

  /// 지금 보여줄 판입니다. 판 번호가 바뀔 때마다 다시 읽어옵니다.
  Board? _board;

  late final LocalBoardRepository _boardRepository;
  late final LocalReferenceRepository _referenceRepository;

  @override
  void initState() {
    super.initState();

    _boardId = widget.initialBoardId;
    _boardRepository = LocalBoardRepository(_database);
    _referenceRepository = LocalReferenceRepository(_database);

    // 메인 창이 "이 판을 보여줘"라고 신호를 보내면 판 번호를 바꿉니다.
    // 이 리스너는 팝업 창이 떠 있는 동안 계속 살아 있습니다(끄지
    // 않습니다) — board_screen.dart의 cardsChanged 리스너와 달리,
    // 이 창의 "바깥 껍데기"가 하나뿐이라 여러 화면이 번갈아 꽂았다
    // 뺄 필요가 없습니다.
    BoardWindowSync.setShowBoardListener((String boardId) {
      setState(() {
        _boardId = boardId;
        _board = null; // 새로 읽어올 때까지 로딩 표시로 되돌립니다.
      });
      _loadBoard();
    });

    _loadBoard();
  }

  /// 지금 판 번호(_boardId)에 해당하는 판을 읽어옵니다.
  Future<void> _loadBoard() async {
    final Board? board = await _boardRepository.getBoardById(_boardId);

    if (!mounted) {
      return;
    }

    setState(() {
      _board = board;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '레퍼런스 아카이브 — 무드보드',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        FlutterQuillLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[Locale('ko'), Locale('en')],
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      home: _board == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : BoardScreen(
              // key를 판 번호로 두면, 판이 바뀔 때 BoardScreen이
              // 완전히 새로 만들어집니다(이전 판의 카드·선택 상태가
              // 안 남습니다).
              key: ValueKey<String>(_board!.id),
              board: _board!,
              boardRepository: _boardRepository,
              referenceRepository: _referenceRepository,
              imageStorage: LocalImageStorage(),
              canPopOut: false,
            ),
    );
  }
}
```

- [ ] **Step 2: `lib/main.dart` 수정 — import 추가**

```dart
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';

import 'screens/board_popup_app.dart';
import 'screens/board_popup_controller.dart';
import 'services/board_window_sync.dart';
```

- [ ] **Step 3: `main()`을 갈림길로 바꾸기**

기존 `void main() async { ... }` 전체를 아래로 바꿉니다:

```dart
/// 앱을 실행합니다. Dart 프로그램은 언제나 main() 함수부터 시작합니다.
///
/// ── 왜 갈림길이 생겼나 (무드보드 팝업 창) ──
/// desktop_multi_window로 만든 팝업 창은 "같은 실행 파일을 다시
/// 시작"하는 방식으로 뜹니다. 그래서 main()이 "나는 메인 창인가,
/// 팝업 창인가"부터 가려야 합니다. WindowController.fromCurrentEngine()의
/// arguments가 비어 있으면 메인 창(맨 처음 뜬 창), 아니면 팝업 창(그
/// 값이 보여줄 판 번호)입니다.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!supportsBoardPopupWindow) {
    // 폰·태블릿에는 여러 창이라는 개념이 없어서 갈림길 자체가 필요
    // 없습니다. WindowController.fromCurrentEngine()을 부르면 오히려
    // 이 플랫폼에서 없는 기능을 억지로 부르는 셈이라 건너뜁니다.
    await _runMainWindow();
    return;
  }

  final WindowController windowController =
      await WindowController.fromCurrentEngine();

  if (windowController.arguments.isEmpty) {
    await _runMainWindow();
  } else {
    // 팝업 창입니다. arguments가 곧 보여줄 판 번호입니다.
    BoardWindowSync.ensureInitialized();
    runApp(BoardPopupApp(initialBoardId: windowController.arguments));
  }
}

/// 메인 창(앱의 진짜 첫 화면)을 준비하고 띄웁니다.
Future<void> _runMainWindow() async {
  final AppDatabase database = AppDatabase();

  // 저장해둔 설정(밝기 모드, 사용자 이름)을 먼저 읽습니다.
  // 화면을 띄운 뒤에 읽으면 밝은 화면이 잠깐 번쩍였다가 어두워집니다.
  final AppSettings settings = AppSettings();
  await settings.load();

  if (supportsBoardPopupWindow) {
    BoardWindowSync.ensureInitialized();
    await _installMainWindowCloseGuard();
  }

  runApp(
    ReferenceArchiveApp(
      referenceRepository: LocalReferenceRepository(database),
      boardRepository: LocalBoardRepository(database),
      taxonomyRepository: LocalTaxonomyRepository(database),
      imageStorage: LocalImageStorage(),
      imageSource: NetworkImageSource(),
      settings: settings,
      youtubeInfoSource: NetworkYoutubeInfoSource(),
    ),
  );
}

/// 메인 창을 닫으면 떠 있는 무드보드 팝업 창도 같이 닫히게 합니다.
///
/// ── 왜 필요한가 ──
/// desktop_multi_window의 창들은 같은 프로세스 안에서 돌지만, 메인
/// 창을 그냥 닫으면 팝업 창은 자기가 알아서 안 닫힙니다(서로 다른
/// 엔진이라 "메인이 사라졌다"는 것을 저절로 알 수 없습니다). 그래서
/// 메인 창의 닫기 버튼을 가로채서, 팝업부터 닫고 나서 진짜로 닫습니다.
Future<void> _installMainWindowCloseGuard() async {
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  windowManager.addListener(_MainWindowCloseGuard());
}

class _MainWindowCloseGuard extends WindowListener {
  @override
  void onWindowClose() async {
    await BoardPopupController.instance.closeIfOpen();

    // setPreventClose로 걸어둔 것을 풀어야 진짜로 닫힙니다. 다시
    // 걸 필요는 없습니다 — 앱이 곧 종료됩니다.
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }
}
```

- [ ] **Step 4: `flutter analyze`로 확인**

Run: `flutter analyze`
Expected: 문제 없음

- [ ] **Step 5: `flutter build windows`로 실제 빌드 확인**

Run: `flutter build windows`
Expected: 성공 (Task 1의 러너 등록 코드가 빠졌거나 잘못됐으면 여기서
런타임이 아니라 링크 단계에서 걸릴 수 있습니다 — 그 경우 Task 1로
돌아가 다시 확인합니다)

- [ ] **Step 6: 커밋**

```bash
git add lib/screens/board_popup_app.dart lib/main.dart
git commit -m "무드보드 팝업 창 전용 진입점과 main() 갈림길을 만든다"
```

---

### Task 6: 실제로 두 창을 띄워 확인 (자동화 테스트로 못 잡는 부분)

**Files:** 없음(코드 변경 없음, 수동 확인만)

이 작업은 코드를 안 고칩니다. `flutter run -d windows`로 실제 두 창이
뜨고 상호작용하는지 **직접 확인**합니다 — 위젯 테스트로는 진짜 OS
창 두 개가 뜨는지, 그 사이 메시지가 오가는지 확인할 수 없습니다
(스펙 문서 "테스트 전략" 참고).

- [ ] **Step 1: 앱 실행**

Run: `flutter run -d windows`

- [ ] **Step 2: 팝업 열기 확인**

무드보드 판 하나를 엽니다 → 위쪽 막대의 "팝업으로 띄우기" 버튼을
누릅니다.

Expected: 별도 창이 새로 뜨고, 메인 창에서 보던 것과 같은 판·카드가
보입니다. 메인 창은 그대로 남아 있습니다(사라지지 않습니다).

- [ ] **Step 3: 실시간 동기화 확인**

메인 창에서 카드를 하나 옮깁니다.

Expected: 팝업 창에도 곧바로(새로고침 없이) 옮겨진 자리가 보입니다.
반대로 팝업 창에서 카드를 옮겨도 메인 창에 곧바로 반영되는지도
확인합니다.

- [ ] **Step 4: 팝업 한 번에 하나만 확인**

메인 창에서(같은 판이 열린 채로) "팝업으로 띄우기"를 다시 누릅니다.

Expected: 새 창이 하나 더 뜨지 않고, 있던 팝업이 그대로입니다(또는
살짝 깜빡이며 같은 판을 다시 보여줍니다).

- [ ] **Step 5: 메인 창 닫으면 팝업도 닫히는지 확인**

팝업이 떠 있는 상태에서 메인 창의 닫기(×) 버튼을 누릅니다.

Expected: 팝업 창도 함께 사라지고, 프로세스가 완전히 종료됩니다
(작업 관리자에 남지 않습니다).

- [ ] **Step 6: 결과를 update.md 초안에 메모**

확인한 결과(잘 됐는지, 안 됐으면 무엇이 어땠는지)를 짧게 적어둡니다 —
PR 본문/`update.md`에 쓸 내용입니다.

---

## 전체 마무리

- [ ] **`flutter test` 전체 실행** — Expected: 기존 전부 + Task 2의
      새 테스트 통과, 회귀 없음.
- [ ] **`flutter analyze`** — 문제 없음.
- [ ] **CLAUDE.md 갱신** — "무드보드 추가 제안 → 우선순위 높음" 표에서
      "무드보드를 진짜 별도 창으로 띄우기" 항목을 완료로 표시하고,
      실제로 어떻게 구현됐는지(파일 구성, 신호를 보내는/받는 지점,
      한 번에 하나만 뜨는 규칙, 메인 닫으면 같이 닫히는 방식) 짧게
      남깁니다. 스파이크 기록 옆에 "정식 구현 — PR #??" 형태로 잇습니다.
- [ ] **`update.md`에 이번 PR 기록 추가**
- [ ] **PR 생성** — Summary에 Task 6에서 확인한 결과를 반드시 포함
      (자동화 테스트로 못 잡는 부분이라 의뢰인이 PR을 볼 때 "직접
      확인했다"는 근거가 필요합니다).
