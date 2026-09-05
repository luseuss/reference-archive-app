// "항상 위" 기능이 **어느 기기에서 켜지는지**를 확인하는 테스트입니다.
//
// ── 이 테스트가 확인하지 못하는 것 ──
// 창이 실제로 다른 프로그램 위에 뜨는지는 여기서 알 수 없습니다. 테스트
// 환경에서는 window_manager 플러그인 통로가 안 열리기 때문입니다(웹뷰와
// 같은 사정 — home_hover_preview_test.dart 설명 참고). 그건
// `flutter run -d windows`로 직접 봐야 합니다.
//
// 대신 여기서는 "데스크톱에서만 이 기능을 쓸 수 있는지"를 확인합니다.
// (BoardWindowController.load()/toggle()이 이 값을 먼저 본 뒤에만
// window_manager를 부르므로, 이 값이 거짓이면 테스트 환경에서도
// 안전합니다)
//
// 저장/불러오기 함수(loadBoardAlwaysOnTopDefault 등)는 window_manager를
// 안 부르고 SharedPreferences만 건드리므로, 플랫폼과 상관없이 바로
// 확인할 수 있습니다 — 설정 화면(settings_screen.dart)이 이 함수들을
// 그대로 쓰기 때문에 여기서 확실히 다져둡니다.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/screens/board_window_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('항상 위 기본값 저장/불러오기', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('저장된 것이 없으면 꺼짐이다', () async {
      expect(await loadBoardAlwaysOnTopDefault(), isFalse);
    });

    test('켜서 저장하면 다시 읽어도 켜져 있다', () async {
      await saveBoardAlwaysOnTopDefault(true);
      expect(await loadBoardAlwaysOnTopDefault(), isTrue);
    });
  });

  group('무드보드 창 불투명도 기본값 저장/불러오기', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('저장된 것이 없으면 1.0(완전히 안 비침)이다', () async {
      expect(await loadBoardOpacityDefault(), 1.0);
    });

    test('저장하면 다시 읽어도 그 값 그대로다', () async {
      await saveBoardOpacityDefault(0.7);
      expect(await loadBoardOpacityDefault(), 0.7);
    });
  });

  group('어느 기기에서 켜지는가', () {
    tearDown(() {
      // 바꿔둔 값을 원래대로 돌려놓습니다.
      // 안 그러면 뒤에 실행되는 다른 테스트까지 영향을 받습니다.
      debugDefaultTargetPlatformOverride = null;
    });

    test('데스크톱에서는 켜진다', () {
      for (final TargetPlatform platform in <TargetPlatform>[
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(supportsAlwaysOnTopWindow, isTrue, reason: '$platform');
      }
    });

    test('폰·태블릿에서는 꺼진다', () {
      // 폰·태블릿에는 여러 앱을 나란히 띄워 겹쳐보는 개념 자체가 없어서,
      // 억지로 흉내내지 않는다는 것이 이 프로젝트의 방침입니다.
      for (final TargetPlatform platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.iOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(supportsAlwaysOnTopWindow, isFalse, reason: '$platform');
      }
    });
  });

  group('폰·태블릿에서는 컨트롤러도 조용히 아무 일도 안 한다', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('load()가 오류 없이 끝나고 값이 그대로다', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final BoardWindowController controller = BoardWindowController();
      await controller.load();

      expect(controller.alwaysOnTop, isFalse);
    });

    test('toggle()도 오류 없이 끝나고 값이 안 바뀐다', () async {
      // supportsAlwaysOnTopWindow가 거짓이면 window_manager를 아예
      // 안 부릅니다. 안 그러면 테스트 환경에서 플러그인 통로가 없어
      // 오류가 납니다.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final BoardWindowController controller = BoardWindowController();
      await controller.toggle();

      expect(controller.alwaysOnTop, isFalse);
    });
  });
}
