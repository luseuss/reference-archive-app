// 앱 설정 화면입니다.
//
// 지금 담고 있는 것은 셋뿐입니다.
//   - 밝은 / 어두운 모드
//   - 사용자 이름 (로그인 시스템이 없어서 직접 적습니다)
//   - 만든 사람과 앱 버전
//
// 설정을 늘릴 때는 `lib/services/app_settings.dart`에 값을 먼저 추가하고
// 여기에 고르는 부분을 붙이면 됩니다.

import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';

/// 이 앱을 만든 사람입니다. 설정 화면에 보여줍니다.
const String appAuthor = 'luseuss';

/// 앱 버전입니다.
///
/// `pubspec.yaml`의 version과 **손으로 맞춰야 합니다.** 자동으로 읽어올 수도
/// 있지만(package_info_plus) 그러자고 패키지를 하나 더 붙이기엔 아까워서,
/// 지금은 여기 적어둡니다. 판올림할 때 두 곳을 같이 고치세요.
const String appVersion = '1.0.0';

/// 앱 설정 화면입니다.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  /// 설정을 읽고 쓰는 도구입니다.
  final AppSettings settings;

  /// 화면의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),

      // ListenableBuilder = 설정이 바뀌면 이 안만 다시 그려주는 위젯입니다.
      // 이게 없으면 어두운 모드를 골라도 고른 표시가 안 바뀝니다.
      body: ListenableBuilder(
        listenable: settings,
        builder: (BuildContext context, Widget? child) {
          return ListView(
            padding: const EdgeInsets.all(screenPaddingHorizontal),
            children: <Widget>[
              _buildSectionLabel('화면', palette),
              _buildThemeModeChoice(palette),

              const SizedBox(height: 28),
              _buildSectionLabel('사용자', palette),
              _buildUserNameField(context, palette),

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
        groupValue: settings.themeMode,
        onChanged: (ThemeMode? picked) {
          if (picked != null) {
            settings.setThemeMode(picked);
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
              initialValue: settings.userName,
              decoration: const InputDecoration(labelText: '이름'),

              // 글자를 칠 때마다 저장하면 저장 요청이 쉴 새 없이 나갑니다.
              // 입력을 마치고 다른 곳을 누르거나 확인 키를 눌렀을 때 저장합니다.
              onFieldSubmitted: settings.setUserName,
              onTapOutside: (PointerDownEvent event) {
                FocusScope.of(context).unfocus();
              },
            ),
          ],
        ),
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
