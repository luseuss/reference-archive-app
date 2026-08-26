// 앱 전체의 테마(색·모양 기본값)를 만드는 파일입니다.
//
// 원래 main.dart 안에 있었는데, 기존 웹앱과 같은 모양을 맞추면서 길어져서
// 따로 뺐습니다. **앱 생김새를 손보려면 이 파일과 app_palette.dart만 보면 됩니다.**
//
// 여기서 정한 것은 "앱 전체의 기본값"입니다. 화면 하나에서만 다르게 하고 싶으면
// 그 화면에서 따로 지정하면 되고, 앱 전체를 바꾸려면 여기를 고칩니다.

import 'package:flutter/material.dart';

import 'app_palette.dart';

/// 밝은 모드 테마를 만들어 돌려줍니다.
ThemeData buildLightTheme() => _buildTheme(AppPalette.light, Brightness.light);

/// 어두운 모드 테마를 만들어 돌려줍니다.
ThemeData buildDarkTheme() => _buildTheme(AppPalette.dark, Brightness.dark);

/// 색 묶음 하나로 테마를 만듭니다.
///
/// 밝은 모드와 어두운 모드가 **모양은 똑같고 색만 다릅니다.** 그래서 함수를
/// 두 벌 쓰지 않고 색만 바꿔 끼웁니다. 한쪽만 고치고 다른 쪽을 빠뜨리는
/// 실수를 아예 못 하게 하려는 것입니다.
ThemeData _buildTheme(AppPalette palette, Brightness brightness) {
  final ColorScheme colors = ColorScheme(
    brightness: brightness,
    primary: palette.accent,
    onPrimary: palette.accentText,
    primaryContainer: palette.accentSoft,
    onPrimaryContainer: palette.accent,

    // 보조색은 따로 두지 않고 강조색을 그대로 씁니다.
    // 기존 웹앱도 색을 하나만 쓰기 때문에, 여기서 다른 색을 만들어내면
    // 없던 색이 화면에 튀어나옵니다.
    secondary: palette.accent,
    onSecondary: palette.accentText,
    secondaryContainer: palette.accentSoft,
    onSecondaryContainer: palette.accent,

    error: palette.danger,
    onError: palette.accentText,
    errorContainer: palette.dangerSoft,
    onErrorContainer: palette.danger,

    surface: palette.surface,
    onSurface: palette.text,

    // 덜 중요한 글자(메모·날짜)와 옅은 바탕(태그)에 쓰이는 자리입니다.
    onSurfaceVariant: palette.textDim,
    surfaceContainerHighest: palette.tagBackground,
    surfaceContainerHigh: palette.tagBackground,
    surfaceContainer: palette.background,

    outline: palette.border,
    outlineVariant: palette.border,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,

    // 화면 바탕은 카드보다 살짝 어둡습니다. 이 차이가 카드를 떠 보이게 합니다.
    scaffoldBackgroundColor: palette.background,

    appBarTheme: AppBarTheme(
      // 기존 웹앱의 헤더는 바탕과 같은 색이고 아래에 실선 하나만 있습니다.
      backgroundColor: palette.background,
      foregroundColor: palette.text,

      // elevation을 0으로 두고 테두리로 구분합니다.
      // 그림자를 주면 머티리얼 느낌이 강해져서 기존 앱과 달라집니다.
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: palette.border)),
    ),

    // 카드의 그림자와 테두리는 카드 위젯에서 직접 그립니다.
    // (기존 앱의 두 겹 그림자를 Material의 elevation으로는 흉내낼 수 없습니다)
    cardTheme: CardThemeData(
      color: palette.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(appCornerRadius),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      border: _inputBorder(palette.border),
      enabledBorder: _inputBorder(palette.border),
      focusedBorder: _inputBorder(palette.accent, width: 2),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: palette.tagBackground,
      side: BorderSide(color: palette.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),

    dividerTheme: DividerThemeData(color: palette.border, space: 1),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: palette.accent,
      foregroundColor: palette.accentText,
    ),
  );
}

/// 입력창 테두리를 만듭니다. 모서리 둥글기를 앱 전체와 맞춥니다.
OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(appCornerRadius),
    borderSide: BorderSide(color: color, width: width),
  );
}
