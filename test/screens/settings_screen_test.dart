// 설정 화면의 "무드보드" 구역(항상 위 기본값·창 불투명도)을 확인하는
// 테스트입니다.
//
// ── 왜 딱 하나뿐인가 ──
// 이 구역은 데스크톱에서만 보입니다(supportsAlwaysOnTopWindow). 위젯
// 테스트 환경에서 그 값을 데스크톱으로 강제로 바꾸면(`debugDefaultTargetPlatformOverride`)
// Flutter 테스트 프레임워크 자체가 "디버그 변수를 건드렸다"고 실패
// 처리합니다 — board_screen_test.dart의 "항상 위" 버튼과 같은 사정으로,
// 이 프로젝트는 그런 경우 **테스트 환경에서는 안 보이는지만** 확인하고
// 실제 동작은 `flutter run -d windows`로 직접 봅니다(CLAUDE.md 참고).
//
// 스위치·슬라이더가 실제로 값을 저장하는지는
// board_window_controller_test.dart에서 저장/불러오기 함수
// (loadBoardAlwaysOnTopDefault 등) 자체를 화면 없이 확인합니다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/screens/settings_screen.dart';
import 'package:reference_archive_app/services/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('테스트 환경(데스크톱이 아닌 곳)에서는 무드보드 구역이 안 보인다', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppSettings settings = AppSettings();
    await settings.load();

    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(settings: settings)),
    );
    await tester.pumpAndSettle();

    // supportsAlwaysOnTopWindow는 위젯 테스트 환경에서 항상 거짓입니다.
    expect(find.text('무드보드'), findsNothing);
    expect(find.text('항상 위로 띄우기'), findsNothing);
    expect(find.text('창 불투명도'), findsNothing);
  });
}
