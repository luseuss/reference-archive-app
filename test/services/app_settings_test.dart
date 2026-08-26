// 앱 설정을 읽고 쓰는 부분을 확인하는 테스트입니다.
//
// ── 여기서 특히 보는 것 ──
// 설정은 **잘못돼도 앱이 켜져야 합니다.** 저장된 값이 이상하거나 아예 못 읽어도
// 기본값으로 넘어가야지, 설정 하나 때문에 앱이 안 켜지면 안 됩니다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/services/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // SharedPreferences는 원래 운영체제의 저장 공간을 씁니다.
  // 테스트에서는 진짜로 저장하면 안 되므로 가짜로 갈아끼웁니다.
  // 이걸 안 하면 테스트를 돌린 컴퓨터에 값이 남습니다.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('저장된 것이 없으면 기본값을 쓴다', () async {
    final AppSettings settings = AppSettings();
    await settings.load();

    // 기본은 "기기 설정 따라가기"입니다.
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.userName, defaultUserName);
  });

  test('고른 밝기 모드를 저장하고 다시 읽는다', () async {
    final AppSettings settings = AppSettings();
    await settings.load();

    await settings.setThemeMode(ThemeMode.dark);

    // 앱을 껐다 켠 것과 같은 상황을 만듭니다.
    final AppSettings reopened = AppSettings();
    await reopened.load();

    expect(reopened.themeMode, ThemeMode.dark);
  });

  test('사용자 이름을 저장하고 다시 읽는다', () async {
    final AppSettings settings = AppSettings();
    await settings.load();

    await settings.setUserName('주원');

    final AppSettings reopened = AppSettings();
    await reopened.load();

    expect(reopened.userName, '주원');
  });

  test('앞뒤 공백은 떼고 저장한다', () async {
    final AppSettings settings = AppSettings();
    await settings.load();

    await settings.setUserName('  주원  ');

    expect(settings.userName, '주원');
  });

  test('빈 이름을 넣으면 기본 이름으로 되돌린다', () async {
    // 이름이 사라지면 사이드바가 허전해지고, 사용자는 뭔가 잘못됐다고 느낍니다.
    final AppSettings settings = AppSettings();
    await settings.load();
    await settings.setUserName('주원');

    await settings.setUserName('   ');

    expect(settings.userName, defaultUserName);
  });

  test('저장된 밝기 모드가 이상한 값이면 기본값으로 넘어간다', () async {
    // 설정 파일이 손상됐거나, 옛 버전이 남긴 값이 있을 수 있습니다.
    // 그때 앱이 안 켜지면 안 됩니다.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'themeMode': '알 수 없는 값',
    });

    final AppSettings settings = AppSettings();
    await settings.load();

    expect(settings.themeMode, ThemeMode.system);
  });

  test('값이 바뀌면 화면에 알린다', () async {
    // 이 알림이 안 가면 설정 화면에서 어두운 모드를 골라도
    // 앱을 껐다 켜야 반영됩니다.
    final AppSettings settings = AppSettings();
    await settings.load();

    int notifiedCount = 0;
    settings.addListener(() => notifiedCount++);

    await settings.setThemeMode(ThemeMode.light);
    expect(notifiedCount, 1);

    await settings.setUserName('주원');
    expect(notifiedCount, 2);
  });

  test('같은 값으로 다시 바꾸면 알리지 않는다', () async {
    // 안 바뀌었는데 알리면 화면을 쓸데없이 다시 그리게 됩니다.
    final AppSettings settings = AppSettings();
    await settings.load();
    await settings.setThemeMode(ThemeMode.dark);

    int notifiedCount = 0;
    settings.addListener(() => notifiedCount++);

    await settings.setThemeMode(ThemeMode.dark);

    expect(notifiedCount, 0);
  });
}
