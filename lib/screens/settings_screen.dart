// 앱 설정 화면입니다.
//
// 지금 담고 있는 것은 넷입니다.
//   - 밝은 / 어두운 모드
//   - 사용자 이름 (로그인 시스템이 없어서 직접 적습니다)
//   - 무드보드 창 기본값 (항상 위, 불투명도 — 데스크톱에서만 보입니다)
//   - 만든 사람과 앱 버전
//
// 설정을 늘릴 때는 `lib/services/app_settings.dart`에 값을 먼저 추가하고
// 여기에 고르는 부분을 붙이면 됩니다.
//
// ── 무드보드 창 기본값은 왜 AppSettings가 아니라 따로 읽어오나 ──
// 밝기 모드·이름은 AppSettings(ChangeNotifier, 앱을 켤 때 한 번만 만들어
// 여기저기 넘겨줌)에 있지만, 무드보드 창 기본값은 board_window_controller.dart의
// loadBoardAlwaysOnTopDefault()/loadBoardOpacityDefault()로 직접
// 읽습니다. 무드보드 창(팝업)의 성질이라 그 파일에 함께 두는 것이
// 자연스럽고, **여기서는 저장만 하지 실제 창에는 적용하지 않습니다** —
// 이 화면은 메인 창에서 뜨므로, 여기서 windowManager를 직접 부르면 메인
// 창이 항상 위·반투명이 되어버립니다(board_window_controller.dart 위쪽
// 설명 참고). 무드보드 창을 열 때 BoardWindowController.load()가 이
// 값을 읽어 그제서야 진짜로 적용합니다.

import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';
import 'board_window_controller.dart';

/// 이 앱을 만든 사람입니다. 설정 화면에 보여줍니다.
const String appAuthor = 'luseuss';

/// 앱 버전입니다.
///
/// `pubspec.yaml`의 version과 **손으로 맞춰야 합니다.** 자동으로 읽어올 수도
/// 있지만(package_info_plus) 그러자고 패키지를 하나 더 붙이기엔 아까워서,
/// 지금은 여기 적어둡니다. 판올림할 때 두 곳을 같이 고치세요.
const String appVersion = '1.0.0';

/// 앱 설정 화면입니다.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});

  /// 설정을 읽고 쓰는 도구입니다.
  final AppSettings settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// 무드보드 창 "항상 위" 기본값입니다. 아직 못 읽어왔으면 null입니다.
  bool? _boardAlwaysOnTop;

  /// 무드보드 창 불투명도 기본값입니다(0.4~1.0). 아직 못 읽어왔으면 null입니다.
  double? _boardOpacity;

  /// 화면이 만들어질 때 무드보드 창 기본값을 읽어옵니다.
  ///
  /// 데스크톱이 아니면 아예 안 읽습니다 — 폰·태블릿에는 이 설정 자체가
  /// 안 보이므로 SharedPreferences를 뒤질 이유가 없습니다.
  @override
  void initState() {
    super.initState();

    if (supportsAlwaysOnTopWindow) {
      _loadBoardWindowDefaults();
    }
  }

  /// 저장해둔 무드보드 창 기본값(항상 위, 불투명도)을 읽어옵니다.
  Future<void> _loadBoardWindowDefaults() async {
    final bool alwaysOnTop = await loadBoardAlwaysOnTopDefault();
    final double opacity = await loadBoardOpacityDefault();

    // 읽어오는 사이에 사용자가 화면을 떠났을 수 있습니다.
    if (!mounted) {
      return;
    }

    setState(() {
      _boardAlwaysOnTop = alwaysOnTop;
      _boardOpacity = opacity;
    });
  }

  /// "항상 위" 기본값을 바꾸고 저장합니다.
  ///
  /// **지금 열려 있는 무드보드 창에는 곧바로 적용되지 않습니다.** 다음에
  /// 무드보드 창을 열 때부터 적용됩니다(board_window_controller.dart
  /// 위쪽 설명 참고).
  Future<void> _setBoardAlwaysOnTop(bool value) async {
    // 저장이 끝나기를 기다리지 않고 먼저 화면(스위치)부터 바꿉니다.
    // 눌렀는데 잠깐 멈칫하면 앱이 굼떠 보입니다.
    setState(() => _boardAlwaysOnTop = value);
    await saveBoardAlwaysOnTopDefault(value);
  }

  /// 무드보드 창 불투명도 기본값을 바꾸고 저장합니다. 위와 같은 이유로
  /// 지금 열려 있는 창에는 곧바로 적용되지 않습니다.
  Future<void> _setBoardOpacity(double value) async {
    setState(() => _boardOpacity = value);
    await saveBoardOpacityDefault(value);
  }

  /// 화면의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),

      // ListenableBuilder = 설정이 바뀌면 이 안만 다시 그려주는 위젯입니다.
      // 이게 없으면 어두운 모드를 골라도 고른 표시가 안 바뀝니다.
      body: ListenableBuilder(
        listenable: widget.settings,
        builder: (BuildContext context, Widget? child) {
          return ListView(
            padding: const EdgeInsets.all(screenPaddingHorizontal),
            children: <Widget>[
              _buildSectionLabel('화면', palette),
              _buildThemeModeChoice(palette),

              const SizedBox(height: 28),
              _buildSectionLabel('사용자', palette),
              _buildUserNameField(context, palette),

              // 데스크톱(창이 있는 기기)에서만 보입니다. 폰·태블릿엔
              // "다른 앱 위에 떠 있기"·"창을 반투명하게" 같은 개념
              // 자체가 없어서, 여느 플랫폼 차이 처리와 같은 방식으로
              // 통째로 숨깁니다.
              if (supportsAlwaysOnTopWindow) ...<Widget>[
                const SizedBox(height: 28),
                _buildSectionLabel('무드보드', palette),
                _buildBoardWindowDefaults(palette),
              ],

              const SizedBox(height: 28),
              _buildSectionLabel('앱 정보', palette),
              _buildInfoRow('만든 사람', appAuthor, palette),
              _buildInfoRow('버전', appVersion, palette),
            ],
          );
        },
      ),
    );
  }

  /// 구역 이름표를 만듭니다.
  Widget _buildSectionLabel(String text, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: AppText.sectionLabel.copyWith(color: palette.textDim),
      ),
    );
  }

  /// 밝기 모드를 고르는 부분입니다.
  Widget _buildThemeModeChoice(AppPalette palette) {
    return _buildPanel(
      palette,
      child: RadioGroup<ThemeMode>(
        // RadioGroup = "이 안의 선택지들은 한 묶음"이라고 알려주는 위젯입니다.
        // 지금 고른 값과 바뀌었을 때 할 일을 여기 한 번만 적으면,
        // 안쪽 선택지들은 각자 자기 값만 갖고 있으면 됩니다.
        groupValue: widget.settings.themeMode,
        onChanged: (ThemeMode? picked) {
          if (picked != null) {
            widget.settings.setThemeMode(picked);
          }
        },
        child: Column(
          children: <Widget>[
            _buildThemeModeTile(
              palette,
              mode: ThemeMode.system,
              label: '기기 설정 따라가기',
              description: '컴퓨터나 폰의 밝게/어둡게 설정을 그대로 씁니다.',
            ),
            _buildThemeModeTile(
              palette,
              mode: ThemeMode.light,
              label: '밝게',
              description: '언제나 밝은 화면으로 봅니다.',
            ),
            _buildThemeModeTile(
              palette,
              mode: ThemeMode.dark,
              label: '어둡게',
              description: '언제나 어두운 화면으로 봅니다.',
            ),
          ],
        ),
      ),
    );
  }

  /// 밝기 모드 선택지 하나를 만듭니다.
  ///
  /// 고른 값과 바뀌었을 때 할 일은 위의 RadioGroup이 갖고 있습니다.
  /// 여기는 "내 값은 이것"만 알려주면 됩니다.
  Widget _buildThemeModeTile(
    AppPalette palette, {
    required ThemeMode mode,
    required String label,
    required String description,
  }) {
    // RadioListTile = 여럿 중 하나만 고르는 줄입니다.
    // 체크박스와 달리 하나를 고르면 나머지가 저절로 풀립니다.
    return RadioListTile<ThemeMode>(
      value: mode,
      title: Text(label, style: TextStyle(color: palette.text)),
      subtitle: Text(
        description,
        style: AppText.cardMemo.copyWith(color: palette.textDim),
      ),
      activeColor: palette.accent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  /// 사용자 이름을 적는 부분입니다.
  Widget _buildUserNameField(BuildContext context, AppPalette palette) {
    return _buildPanel(
      palette,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '로그인 기능은 아직 없습니다. 사이드바에 보일 이름을 직접 적어주세요.',
              style: AppText.cardMemo.copyWith(color: palette.textDim),
            ),
            const SizedBox(height: 12),
            TextFormField(
              // 지금 저장된 이름을 처음 값으로 넣습니다.
              initialValue: widget.settings.userName,
              decoration: const InputDecoration(labelText: '이름'),

              // 글자를 칠 때마다 저장하면 저장 요청이 쉴 새 없이 나갑니다.
              // 입력을 마치고 다른 곳을 누르거나 확인 키를 눌렀을 때 저장합니다.
              onFieldSubmitted: widget.settings.setUserName,
              onTapOutside: (PointerDownEvent event) {
                FocusScope.of(context).unfocus();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 무드보드 창의 "항상 위"·불투명도 기본값을 고르는 부분입니다.
  ///
  /// 여기서 바꾼 값은 **다음에 무드보드 창을 열 때부터** 적용됩니다
  /// (board_window_controller.dart 위쪽 설명 참고). 지금 열려 있는
  /// 무드보드 창이 있어도 이 화면에서 곧바로 반투명해지거나 하지
  /// 않습니다.
  Widget _buildBoardWindowDefaults(AppPalette palette) {
    final bool? alwaysOnTop = _boardAlwaysOnTop;
    final double? opacity = _boardOpacity;

    // 아직 저장된 값을 못 읽어왔으면(initState의 비동기 읽기가 끝나기
    // 전) 빙글빙글 도는 표시만 보여줍니다. 화면이 열리자마자 잠깐
    // 보이고 사라지는 정도라 눈에 크게 띄지 않습니다.
    if (alwaysOnTop == null || opacity == null) {
      return _buildPanel(
        palette,
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return _buildPanel(
      palette,
      child: Column(
        children: <Widget>[
          SwitchListTile(
            title: Text('항상 위로 띄우기', style: TextStyle(color: palette.text)),
            subtitle: Text(
              '다음에 무드보드 창을 열 때부터 다른 프로그램 위에 항상 떠 있습니다.',
              style: AppText.cardMemo.copyWith(color: palette.textDim),
            ),
            value: alwaysOnTop,
            activeThumbColor: palette.accent,
            onChanged: _setBoardAlwaysOnTop,
          ),
          Divider(height: 1, color: palette.border),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('창 불투명도', style: TextStyle(color: palette.text)),
                const SizedBox(height: 4),
                Text(
                  '다음에 무드보드 창을 열 때부터 살짝 비쳐 보입니다. '
                  '뒤에 있는 다른 프로그램을 함께 보고 싶을 때 낮춰보세요.',
                  style: AppText.cardMemo.copyWith(color: palette.textDim),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Slider(
                        // 너무 낮추면 글자를 아예 못 읽게 되므로 40%까지만 허용합니다.
                        min: 0.4,
                        max: 1.0,

                        // 5%씩 끊어서 고르게 합니다. 연속값이면 미세한
                        // 차이(예: 73%와 74%)를 정확히 되짚기 어렵습니다.
                        divisions: 12,
                        value: opacity,
                        activeColor: palette.accent,
                        label: '${(opacity * 100).round()}%',
                        onChanged: _setBoardOpacity,
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${(opacity * 100).round()}%',
                        textAlign: TextAlign.end,
                        style: TextStyle(color: palette.textDim),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "만든 사람 / 버전"처럼 읽기만 하는 줄을 만듭니다.
  Widget _buildInfoRow(String label, String value, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: TextStyle(color: palette.textDim)),
          Text(
            value,
            style: TextStyle(
              color: palette.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 설정 항목을 감싸는 상자입니다. 카드와 같은 테두리·둥글기를 씁니다.
  ///
  /// ── Container가 아니라 Material을 쓰는 이유 ──
  /// 처음에는 Container에 배경색을 칠했는데, 그러면 안에 있는 선택지를 눌렀을 때
  /// **누른 표시(물결)가 안 보입니다.** 물결은 가장 가까운 Material 위에 그려지는데,
  /// 배경색을 칠한 Container가 그 위를 덮어버리기 때문입니다.
  /// Flutter가 "물결이 안 보일 수 있다"고 경고로 알려줘서 발견했습니다.
  ///
  /// Material로 만들면 배경·테두리·둥글기를 그대로 주면서 물결도 살아납니다.
  Widget _buildPanel(AppPalette palette, {required Widget child}) {
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(appCornerRadius),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
