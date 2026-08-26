// 앱 설정을 읽고 쓰는 파일입니다.
//
// ── 왜 데이터베이스에 안 넣나 ──
// 밝은/어두운 모드 같은 것은 **레퍼런스 데이터가 아닙니다.** 기기마다 다를 수
// 있고, 나중에 기기 간 동기화를 붙일 때도 같이 넘길 값이 아닙니다.
// (이 컴퓨터는 어둡게, 폰은 밝게 쓰고 싶을 수 있습니다)
//
// 그래서 drift 데이터베이스가 아니라 `shared_preferences`에 따로 담습니다.
// 운영체제가 앱마다 마련해주는 작은 저장 공간이고, 이런 자잘한 설정용입니다.
// 데이터베이스에 넣었다면 설정 하나 추가할 때마다 저장 구조를 바꿔야
// (마이그레이션) 했을 텐데, 그것도 피할 수 있습니다.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 설정을 저장할 때 쓰는 이름표들입니다.
///
/// 글자를 여기저기 직접 적으면 오타 하나로 **저장은 되는데 안 읽히는** 상태가
/// 됩니다. 오류도 안 나서 찾기 어렵습니다. 그래서 한곳에 모아둡니다.
const String _themeModeKey = 'themeMode';
const String _userNameKey = 'userName';

/// 사용자 이름을 안 정했을 때 보여줄 이름입니다.
const String defaultUserName = '사용자';

/// 앱 설정을 읽고 쓰는 도구입니다.
///
/// ── ChangeNotifier가 무엇인가 ──
/// "값이 바뀌었다"고 화면에 알려주는 Flutter의 기본 장치입니다.
/// 설정을 바꾸면 `notifyListeners()`가 불리고, 이 값을 보고 있는 화면이
/// 저절로 다시 그려집니다. 설정 화면에서 어두운 모드를 켜면 앱 전체가
/// 곧바로 어두워지는 것이 이 덕분입니다.
class AppSettings extends ChangeNotifier {
  /// 지금 고른 밝기 모드입니다.
  ///
  /// 기본값은 `system` — 운영체제 설정(밝게/어둡게)을 그대로 따라갑니다.
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  /// 사용자 이름입니다. 로그인 시스템이 없어서 직접 적어 넣습니다.
  String _userName = defaultUserName;
  String get userName => _userName;

  /// 저장해둔 설정을 불러옵니다. 앱이 시작할 때 한 번 부릅니다.
  ///
  /// 못 읽어도 앱은 켜져야 하므로, 문제가 생기면 기본값으로 넘어갑니다.
  /// 설정 하나 때문에 앱이 안 켜지면 안 됩니다.
  Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      _themeMode = _themeModeFromName(prefs.getString(_themeModeKey));
      _userName = prefs.getString(_userNameKey) ?? defaultUserName;
    } catch (error) {
      debugPrint('[설정] 불러오기 실패, 기본값을 씁니다: $error');
    }

    notifyListeners();
  }

  /// 밝기 모드를 바꾸고 저장합니다.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }

    _themeMode = mode;

    // 저장이 끝나기를 기다리지 않고 먼저 화면부터 바꿉니다.
    // 버튼을 눌렀는데 잠깐 멈칫하면 앱이 굼떠 보입니다.
    notifyListeners();

    await _save(_themeModeKey, mode.name);
  }

  /// 사용자 이름을 바꾸고 저장합니다.
  ///
  /// 빈 이름은 받지 않습니다. 이름이 사라지면 사이드바가 허전해지고,
  /// 사용자는 뭔가 잘못됐다고 느낍니다.
  Future<void> setUserName(String name) async {
    final String trimmed = name.trim();
    final String next = trimmed.isEmpty ? defaultUserName : trimmed;

    if (_userName == next) {
      return;
    }

    _userName = next;
    notifyListeners();

    await _save(_userNameKey, next);
  }

  /// 값 하나를 저장합니다. 실패해도 앱을 멈추지 않습니다.
  ///
  /// 저장에 실패하면 다음에 앱을 켤 때 설정이 되돌아갈 뿐입니다.
  /// 그것 때문에 오류 화면을 띄울 일은 아닙니다.
  Future<void> _save(String key, String value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (error) {
      debugPrint('[설정] 저장 실패 ($key): $error');
    }
  }

  /// 저장된 글자를 밝기 모드로 되돌립니다.
  ///
  /// 모르는 값이면(설정 파일이 손상됐거나 옛 버전이 남긴 값이면)
  /// 앱을 죽이지 않고 기본값으로 넘어갑니다.
  ThemeMode _themeModeFromName(String? name) {
    for (final ThemeMode mode in ThemeMode.values) {
      if (mode.name == name) {
        return mode;
      }
    }
    return ThemeMode.system;
  }
}
