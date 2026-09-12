// 앱에서 쓰는 색을 한곳에 모아둔 파일입니다.
//
// ── 이 색들은 어디서 왔나 (2026-09-11, "라이트테이블" 디자인으로 교체) ──
// 처음에는 기존 웹앱(`app.html`)의 CSS 변수를 그대로 옮긴 색이었습니다.
// 두 앱을 함께 쓰는 동안은 그게 맞는 선택이었지만, 의뢰인이 메인 화면
// UI를 "세련되게" 새로 디자인해달라고 요청하면서 **이 파일부터 새로
// 정한 색으로 바뀌었습니다.** 더 이상 웹앱 CSS를 따라가지 않습니다.
//
// ── 컨셉: "라이트테이블" ──
// 이 앱은 사진가의 라이트테이블·콘택트시트처럼, **사진이 주인공이고
// UI는 그 사진을 올려두는 조용한 판**이어야 합니다(작업 중 옆에 띄워두는
// 도구라는 CLAUDE.md의 원칙과 같은 결). 그래서
//   - 바탕은 따뜻한 돌색(그레이베이지)이고 카드는 순백 — 사진이 도드라집니다.
//   - 강조색은 딱 하나, 깊은 청록(페트롤)입니다. 다른 곳엔 색을 안 씁니다.
//   - 어두운 모드도 순수 검정이 아니라 따뜻한 숯색입니다.
//
// ── 왜 Flutter가 색을 자동으로 만들게 두지 않았나 ──
// Flutter에는 대표색 하나만 주면 나머지를 알아서 만들어주는 기능이 있습니다
// (`ColorScheme.fromSeed`). 자동 생성 색은 이번에도 쓰지 않았습니다 —
// 위 컨셉처럼 "이 색만은 반드시 이 톤"이라는 의도가 있는 팔레트는 자동
// 생성으로는 못 만듭니다(전에도 배경이 푸른기 도는 회색이 되고 테두리
// 색이 아예 없어서 버린 적이 있습니다 — PR #11).

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

  /// 강조색입니다. 깊은 청록(페트롤)입니다. 이 앱에서 색을 쓰는 곳은
  /// 사실상 여기 하나뿐입니다 — 강조가 여러 군데 흩어지면 아무것도
  /// 강조되지 않습니다.
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

  /// 밝은 모드 색입니다. 따뜻한 돌색 바탕 + 순백 카드 + 깊은 청록 강조색.
  static const AppPalette light = AppPalette(
    background: Color(0xFFEDE9E1),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFDDD8CD),
    text: Color(0xFF221F1A),
    textDim: Color(0xFF7D7768),
    accent: Color(0xFF1D5C56),
    accentText: Color(0xFFF5FBF9),
    accentSoft: Color(0xFFDCEAE7),
    tagBackground: Color(0xFFF1EEE6),
    danger: Color(0xFFA6402C),
    dangerSoft: Color(0xFFF6E9E4),
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

  /// 어두운 모드 색입니다. 순수 검정이 아니라 따뜻한 숯색 바탕입니다.
  /// (근처색을 순전한 무채색 #0B0B0B 근처로 두면 화면이 차갑고 딱딱해
  /// 보입니다 — 일부러 살짝 따뜻한 톤을 남겨뒀습니다)
  static const AppPalette dark = AppPalette(
    background: Color(0xFF1B1A18),
    surface: Color(0xFF242320),
    border: Color(0xFF38362F),
    text: Color(0xFFEDE9E0),
    textDim: Color(0xFF8C8778),
    accent: Color(0xFF4FA69C),
    accentText: Color(0xFF0B211E),
    accentSoft: Color(0xFF223330),
    tagBackground: Color(0xFF2A2822),
    danger: Color(0xFFD97A63),
    dangerSoft: Color(0xFF332420),
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

