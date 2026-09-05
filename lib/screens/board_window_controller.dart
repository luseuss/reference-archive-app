// 무드보드 판이 뜬 앱 창을 **다른 프로그램 위에 항상 떠 있게**, 그리고
// **살짝 비쳐 보이게** 하는 상태와 동작을 모은 곳입니다. (4단계 8번 +
// 2026-09-05 불투명도 추가)
//
// ── 왜 필요한가 ──
// 의뢰인이 실제로 하는 작업은 AE·포토샵을 띄워놓고 그 옆에 레퍼런스를
// 참고하며 만드는 일입니다. 다른 프로그램에 가려지면 작업 중에 참고할
// 수가 없어서, 결국 PureRef를 다시 켜게 됩니다(CLAUDE.md "무드보드는
// PureRef를 대체하는 것이 목표입니다" 참고). 그래서 이 판을 항상 위로
// 띄울 수 있어야 하고, 뒤에 있는 다른 프로그램을 함께 보고 싶을 때는
// 살짝 비쳐 보이게도 할 수 있어야 합니다.
//
// ── 데스크톱에서만 켭니다 ──
// "항상 위"·불투명도는 창(window)이 있는 데스크톱에서만 뜻이 있는
// 개념입니다. 폰·태블릿에는 여러 앱을 나란히 띄워 겹쳐보는 개념 자체가
// 없어서, 억지로 흉내내지 않고 이 기능을 통째로 숨깁니다. (CLAUDE.md
// 플랫폼 차이표 참고. home_screen.dart의 supportsHoverPreview와 같은 방식)
//
// ── "저장"과 "창에 적용"을 나눈 이유 ──
// 처음(항상 위만 있었을 때)에는 AppSettings에 안 넣기로 했습니다 — 무드보드
// 화면의 버튼으로만 켜고 끄는 창 자체의 성질이라 봤기 때문입니다. 그런데
// "무드보드를 열기 전에 미리 기본값을 정해두고 싶다"는 요청으로 설정
// 화면에도 스위치·슬라이더가 생겼습니다(2026-09-05). 문제는 설정 화면이
// **메인 창**에서 뜬다는 것 — 거기서 곧바로 windowManager를 부르면 메인
// 창이 항상 위·반투명이 되어버립니다. 그래서 "저장"(loadXxxDefault/
// saveXxxDefault, 아래)과 "지금 이 창에 적용"([load]/[toggle])을
// 나눴습니다. 설정 화면은 **저장만** 하고, 실제로 창에 적용하는 일은
// 무드보드 창 자신(이 클래스)이 [load]를 부를 때만 합니다.
//
// ── ChangeNotifier가 무엇인가 ──
// "값이 바뀌었다"고 화면에 알려주는 Flutter의 기본 장치입니다.
// board_interaction_controller.dart와 같은 방식입니다.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// 설정을 저장할 때 쓰는 이름표입니다.
const String _alwaysOnTopKey = 'boardAlwaysOnTop';

/// 무드보드 창 불투명도를 저장할 때 쓰는 이름표입니다.
const String _opacityKey = 'boardWindowOpacity';

/// 이 기기에서 "항상 위"·불투명도 같은 창 관련 기능을 쓸 수 있는지 여부입니다.
///
/// 창이 있는 데스크톱(Windows/macOS/Linux)에서만 뜻이 있습니다.
bool get supportsAlwaysOnTopWindow {
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

/// 저장해둔 "항상 위" 기본값을 읽습니다. 저장된 적이 없으면 꺼짐(false)입니다.
///
/// 이 파일의 [BoardWindowController](무드보드 창 자신)와
/// settings_screen.dart(설정 화면) 둘 다 이 함수를 씁니다 — 저장 키
/// 이름을 한 곳에만 적어두려는 것입니다.
Future<bool> loadBoardAlwaysOnTopDefault() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_alwaysOnTopKey) ?? false;
}

/// "항상 위" 기본값을 저장합니다.
///
/// **지금 열려 있는 창에는 곧바로 적용되지 않습니다.** 여기서는 저장만
/// 하고, 실제로 창에 적용하는 일은 [BoardWindowController.load]/
/// [BoardWindowController.toggle]이 합니다 — 설정 화면(메인 창)에서 이
/// 함수를 부른다고 메인 창이 갑자기 항상 위로 뜨면 안 되기 때문입니다.
Future<void> saveBoardAlwaysOnTopDefault(bool value) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_alwaysOnTopKey, value);
}

/// 저장해둔 무드보드 창 불투명도 기본값을 읽습니다(0.4~1.0 사이).
/// 저장된 적이 없으면 1.0(완전히 안 비침)입니다.
Future<double> loadBoardOpacityDefault() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getDouble(_opacityKey) ?? 1.0;
}

/// 무드보드 창 불투명도 기본값을 저장합니다.
///
/// [saveBoardAlwaysOnTopDefault]와 같은 이유로 저장만 하고, 창에
/// 적용하는 일은 [BoardWindowController.load]가 합니다.
Future<void> saveBoardOpacityDefault(double value) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(_opacityKey, value);
}

/// 무드보드 창을 "항상 위"로 띄우는 상태와 동작을 담습니다.
class BoardWindowController extends ChangeNotifier {
  /// 지금 항상 위로 떠 있는지 여부입니다.
  bool get alwaysOnTop => _alwaysOnTop;
  bool _alwaysOnTop = false;

  /// 저장해둔 값을 불러오고, 그 값을 실제 창에도 적용합니다.
  ///
  /// 화면(무드보드 판)을 열 때마다 부릅니다. 앱을 다시 켰을 때도 지난번에
  /// 켜뒀던 대로 창이 다시 위로 뜨게 하려는 것입니다 — 창의 "항상 위"
  /// 상태는 운영체제가 기억해주지 않고, 앱을 새로 켤 때마다 꺼진 채로
  /// 시작하기 때문입니다.
  Future<void> load() async {
    if (!supportsAlwaysOnTopWindow) {
      return;
    }

    try {
      _alwaysOnTop = await loadBoardAlwaysOnTopDefault();
      final double opacity = await loadBoardOpacityDefault();

      await windowManager.ensureInitialized();
      await windowManager.setAlwaysOnTop(_alwaysOnTop);

      // 설정 화면에서 미리 골라둔 불투명도가 있으면 이 창에도 적용합니다.
      // 값이 1.0(기본)이면 굳이 부를 필요는 없지만, 매번 불러도 해가
      // 없어서 조건 없이 부릅니다.
      await windowManager.setOpacity(opacity);
    } catch (error) {
      // 못 읽거나 못 적용해도 앱은 계속 켜져 있어야 합니다. 이 기능
      // 하나 때문에 무드보드를 못 열면 안 됩니다.
      debugPrint('[무드보드 창] 항상 위·불투명도 상태를 적용하지 못했습니다: $error');
    }

    notifyListeners();
  }

  /// 항상 위 상태를 켜고 끄고, 저장합니다.
  Future<void> toggle() async {
    if (!supportsAlwaysOnTopWindow) {
      return;
    }

    _alwaysOnTop = !_alwaysOnTop;

    // 저장이 끝나기를 기다리지 않고 먼저 화면(버튼 색)부터 바꿉니다.
    // 눌렀는데 잠깐 멈칫하면 앱이 굼떠 보입니다.
    notifyListeners();

    try {
      await windowManager.setAlwaysOnTop(_alwaysOnTop);
      await saveBoardAlwaysOnTopDefault(_alwaysOnTop);
    } catch (error) {
      debugPrint('[무드보드 창] 항상 위 상태를 바꾸지 못했습니다: $error');
    }
  }
}
