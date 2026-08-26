// 앱에서 쓰는 색을 한곳에 모아둔 파일입니다.
//
// ── 이 색들은 어디서 왔나 ──
// 기존 웹앱(`app.html`)의 CSS 변수를 그대로 옮긴 것입니다. 새로 정한 색이
// 아니라 **이미 쓰던 색**이라, 여기 값을 바꾸면 기존 앱과 달라집니다.
//
//   웹앱의 :root { --bg: #f6f5f2; ... }          → AppPalette.light
//   웹앱의 html[data-theme="dark"] { ... }        → AppPalette.dark
//
// ── 왜 Flutter가 색을 자동으로 만들게 두지 않았나 ──
// Flutter에는 대표색 하나만 주면 나머지를 알아서 만들어주는 기능이 있습니다
// (`ColorScheme.fromSeed`). 처음에는 그걸 썼는데, 자동으로 만들어진 색이라
// **기존 앱의 따뜻한 느낌과 달랐습니다.** 배경이 푸른기 도는 회색이 되고,
// 테두리 색은 아예 없었습니다.
//
// 기존 앱과 같아 보이는 것이 목적이므로, 자동 생성을 쓰지 않고
// 원본 값을 하나하나 적었습니다.

import 'package:flutter/material.dart';

/// 밝은 모드 / 어두운 모드 각각의 색 묶음입니다.
///
/// 두 모드가 **같은 이름의 색을 서로 다른 값으로** 갖습니다.
/// 그래서 화면 코드는 `AppPalette.of(context).accent`처럼 이름만 쓰면 되고,
/// 지금이 밝은 모드인지 어두운 모드인지 신경 쓰지 않아도 됩니다.
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.border,
    required this.text,
    required this.textDim,
    required this.accent,
    required this.accentText,
    required this.accentSoft,
    required this.tagBackground,
    required this.danger,
    required this.dangerSoft,
    required this.cardShadow,
    required this.cardShadowHovered,
  });

  /// 화면 전체 바탕색입니다. 카드보다 살짝 어둡습니다.
  final Color background;

  /// 카드·대화상자처럼 바탕 위에 얹히는 것들의 색입니다.
  final Color surface;

  /// 카드 테두리와 구분선 색입니다.
  ///
  /// 기존 앱은 그림자만으로 카드를 띄우지 않고 **얇은 테두리를 함께** 씁니다.
  /// 이게 그 앱 특유의 차분한 느낌을 만드는 부분이라 빼면 인상이 달라집니다.
  final Color border;

  /// 본문 글자색입니다.
  final Color text;

  /// 덜 중요한 글자색입니다. (메모, 날짜, 태그 등)
  final Color textDim;

  /// 강조색입니다. 기존 앱의 진한 숲 초록입니다.
  final Color accent;

  /// 강조색 위에 얹는 글자색입니다.
  final Color accentText;

  /// 강조색의 아주 연한 버전입니다. 버튼에 마우스를 올렸을 때 등에 씁니다.
  final Color accentSoft;

  /// 태그 배경처럼 아주 옅게 깔리는 색입니다.
  final Color tagBackground;

  /// 삭제처럼 되돌리기 어려운 동작에 쓰는 색입니다.
  final Color danger;

  /// danger의 아주 연한 버전입니다.
  final Color dangerSoft;

  /// 카드에 깔리는 그림자입니다.
  ///
  /// 그림자를 두 겹으로 겹칩니다. 하나는 아주 가까이 옅게(윤곽을 또렷하게),
  /// 하나는 멀리 넓게(떠 있는 느낌). 한 겹만 쓰면 밋밋하거나 과해집니다.
  final List<BoxShadow> cardShadow;

  /// 마우스를 올렸을 때의 카드 그림자입니다. 더 진하고 넓게 퍼집니다.
  final List<BoxShadow> cardShadowHovered;

  /// 지금 화면에 맞는 색 묶음을 돌려줍니다.
  ///
  /// 화면 코드에서는 이렇게 씁니다.
  ///
  ///   final AppPalette palette = AppPalette.of(context);
  ///   ... color: palette.accent ...
  static AppPalette of(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? dark : light;
  }

  /// 밝은 모드 색입니다. (웹앱의 `:root`)
  static const AppPalette light = AppPalette(
    background: Color(0xFFF6F5F2),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE5E2DB),
    text: Color(0xFF2A2824),
    textDim: Color(0xFF8A8578),
    accent: Color(0xFF3D5A4C),
    accentText: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFE6EDE9),
    tagBackground: Color(0xFFF0EEE8),
    danger: Color(0xFFB3543F),
    dangerSoft: Color(0xFFF7ECE9),
    cardShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x0A1E1C14),
        blurRadius: 2,
        offset: Offset(0, 1),
      ),
      BoxShadow(
        color: Color(0x0F1E1C14),
        blurRadius: 16,
        offset: Offset(0, 4),
      ),
    ],
    cardShadowHovered: <BoxShadow>[
      BoxShadow(
        color: Color(0x0F000000),
        blurRadius: 6,
        offset: Offset(0, 4),
      ),
      BoxShadow(
        color: Color(0x1A000000),
        blurRadius: 28,
        offset: Offset(0, 12),
      ),
    ],
  );

  /// 어두운 모드 색입니다. (웹앱의 `html[data-theme="dark"]`)
  static const AppPalette dark = AppPalette(
    background: Color(0xFF17181B),
    surface: Color(0xFF1F2023),
    border: Color(0xFF33343A),
    text: Color(0xFFEAE8E2),
    textDim: Color(0xFF8F8D86),
    accent: Color(0xFF7AB596),
    accentText: Color(0xFF12241C),
    accentSoft: Color(0xFF20302A),
    tagBackground: Color(0xFF26272C),
    danger: Color(0xFFE0897A),
    dangerSoft: Color(0xFF2E2220),
    cardShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x4D000000),
        blurRadius: 2,
        offset: Offset(0, 1),
      ),
      BoxShadow(
        color: Color(0x59000000),
        blurRadius: 20,
        offset: Offset(0, 6),
      ),
    ],
    cardShadowHovered: <BoxShadow>[
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 6,
        offset: Offset(0, 4),
      ),
      BoxShadow(
        color: Color(0x80000000),
        blurRadius: 28,
        offset: Offset(0, 12),
      ),
    ],
  );
}

