// 앱에서 쓰는 색을 한곳에 모아둔 파일입니다.
//
// ── 이 색들은 어디서 왔나 (2026-09-13, "에메랄드 글래스" 디자인으로 교체) ──
// 처음에는 기존 웹앱(`app.html`)의 CSS 변수였다가, "라이트테이블"(2026-09-11)을
// 거쳐 이번이 두 번째 전면 교체입니다. 의뢰인이 유리질 그라디언트 느낌의
// 참고 화면(반투명 유리 패널 + 뒤에 번지는 색 안개)을 보여주고, 그 결로
// 여러 색 조합 시안을 눈으로 비교해본 뒤 "에메랄드"를 골랐습니다.
//
// ── 컨셉: "에메랄드 글래스" ──
//   - 바탕 위로 에메랄드·시안·라임이 흐릿하게 번지는 "색 안개"가 깔립니다
//     (`meshColors` + `lib/widgets/mesh_background.dart`).
//   - 메인 화면의 카드·머리줄 글자 부분은 **반투명**입니다(`glassSurface`)
//     — 안개가 비쳐 보여야 "유리" 느낌이 납니다.
//   - **사진(썸네일) 자체는 그대로 불투명합니다.** 반투명은 글자가 있는
//     자리에만 씁니다 — 사진 위까지 유리로 덮으면 사진이 흐려 보이고
//     가독성도 떨어집니다(실제로 시안을 비교하며 의뢰인과 확인한 부분).
//   - 안개를 이미 흐릿하게(blur) 그려두기 때문에, 그 위에 얹는 반투명
//     패널은 **따로 블러를 또 먹일 필요가 없습니다.** 안개 자체가 이미
//     또렷한 경계가 없어서, 위에 알파색만 얹어도 "뿌옇게 비치는" 느낌이
//     그대로 납니다. (BackdropFilter를 카드마다 따로 쓰면 카드 수만큼
//     블러 연산이 늘어나 느려질 수 있는데, 이 방식은 그 비용이 없습니다)
//
// ── 실제로 겪은 문제: 대화상자·다른 화면까지 투명해졌었습니다 (2026-09-14) ──
// 처음엔 `surface`(카드·대화상자·설정 화면 등 거의 모든 곳이 쓰는 색)
// 자체를 반투명으로 바꿨습니다. 메인 화면(안개가 있는 곳)에서는
// 의도대로 "유리"로 보였지만, **안개가 없는 다른 화면**(레퍼런스 편집
// 대화상자, 설정, 분류 관리, 무드보드 목록 등)에서는 그냥 뒤에 있던
// 아무 화면이나 얼비쳐서 글자를 거의 못 읽는 상태가 됐습니다 — 의뢰인이
// 스크린샷으로 직접 보여준 실제 버그입니다. 그래서 `surface`는
// **다시 불투명으로 되돌리고**, "안개 위에서만" 쓰는 반투명 색은
// `glassSurface`라는 별도 이름으로 뺐습니다. `glassSurface`는
// `MeshBackground`가 뒤에 있는 자리(메인 화면의 카드·머리줄)에서만
// 골라 씁니다 — 안개가 없는 화면은 전부 그대로 `surface`(불투명)를 씁니다.
//
// ── 왜 Flutter가 색을 자동으로 만들게 두지 않았나 ──
// Flutter에는 대표색 하나만 주면 나머지를 알아서 만들어주는 기능이 있습니다
// (`ColorScheme.fromSeed`). 자동 생성 색은 이번에도 쓰지 않았습니다 —
// "이 자리는 반드시 반투명, 이 자리는 반드시 불투명"이라는 의도가 있는
// 팔레트는 자동 생성으로는 못 만듭니다(PR #11에서도 같은 이유로 버렸습니다).

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
    required this.glassSurface,
    required this.accent,
    required this.accentSecondary,
    required this.accentTertiary,
    required this.accentText,
    required this.accentSoft,
    required this.tagBackground,
    required this.danger,
    required this.dangerSoft,
    required this.cardShadow,
    required this.cardShadowHovered,
    required this.meshColors,
  });

  /// 화면 전체 바탕색입니다. 안개(mesh)를 그리는 기준 바탕이기도 합니다.
  final Color background;

  /// 카드·대화상자·설정 화면 등 바탕 위에 얹히는 대부분의 것들의
  /// 색입니다. **불투명합니다** — 뒤에 안개(mesh)가 없는 화면에서도
  /// 항상 또렷하게 읽혀야 하기 때문입니다(위 "실제로 겪은 문제" 참고).
  final Color surface;

  /// 메인 화면에서, `MeshBackground`(색 안개)가 뒤에 깔린 자리에만
  /// 쓰는 **반투명** 유리색입니다. 지금은 `reference_card.dart`(카드
  /// 아래쪽 글자 부분)와 `main_header.dart`(머리줄)만 이 색을 씁니다.
  /// 안개가 없는 화면(대화상자, 설정, 무드보드 목록 등)에서는 절대
  /// 쓰지 마세요 — 뒤에 아무 안개도 없이 반투명이면 그냥 다른 화면이
  /// 얼비쳐서 글자를 읽기 어려워집니다.
  final Color glassSurface;

  /// 카드 테두리와 구분선 색입니다. 유리 가장자리처럼 아주 옅습니다.
  final Color border;

  /// 본문 글자색입니다.
  final Color text;

  /// 덜 중요한 글자색입니다. (메모, 날짜, 태그 등)
  final Color textDim;

  /// 강조색입니다. 에메랄드입니다. 버튼·선택 표시 등 "가장 중요한 강조"에 씁니다.
  final Color accent;

  /// 두 번째 강조색입니다. 시안. 안개 그라디언트와 머리줄 제목 그라디언트에
  /// accent·accentTertiary와 함께 쓰입니다 — 이 셋 외에는 색을 더 늘리지 않습니다.
  final Color accentSecondary;

  /// 세 번째 강조색입니다. 라임. accent·accentSecondary와 같은 자리에만 씁니다.
  final Color accentTertiary;

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

  /// 배경에 흐릿하게 번지는 "색 안개" 색들입니다.
  /// `lib/widgets/mesh_background.dart`가 이 색들로 뭉갠 원을 그립니다.
  final List<Color> meshColors;

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

  /// 밝은 모드 색입니다. 옅은 민트빛 바탕 위에 파스텔 안개, 그 위에
  /// 대부분은 불투명한 흰색 패널(`surface`)을, 메인 화면 카드·머리줄만
  /// 짙은 흰색(70%) 유리(`glassSurface`)를 얹습니다.
  static const AppPalette light = AppPalette(
    background: Color(0xFFF1FAF5),
    surface: Color(0xFFFFFFFF),
    glassSurface: Color(0xB3FFFFFF),
    border: Color(0x330F3D2E),
    text: Color(0xFF10281F),
    textDim: Color(0xFF5C7A6C),
    accent: Color(0xFF059669),
    accentSecondary: Color(0xFF0891B2),
    accentTertiary: Color(0xFF65A30D),
    accentText: Color(0xFFF2FBF7),
    accentSoft: Color(0xFFDCF3E8),
    tagBackground: Color(0xFFE9F6EF),
    danger: Color(0xFFB5432D),
    dangerSoft: Color(0xFFF7E7E1),
    cardShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x0A0F3D2E),
        blurRadius: 2,
        offset: Offset(0, 1),
      ),
      BoxShadow(
        color: Color(0x0F0F3D2E),
        blurRadius: 16,
        offset: Offset(0, 4),
      ),
    ],
    cardShadowHovered: <BoxShadow>[
      BoxShadow(
        color: Color(0x140F3D2E),
        blurRadius: 6,
        offset: Offset(0, 4),
      ),
      BoxShadow(
        color: Color(0x220F3D2E),
        blurRadius: 28,
        offset: Offset(0, 12),
      ),
    ],
    meshColors: <Color>[
      Color(0xFF6EE7B7),
      Color(0xFF67E8F9),
      Color(0xFFD9F99D),
      Color(0xFF5EEAD4),
    ],
  );

  /// 어두운 모드 색입니다. 거의 검정에 가까운 짙은 초록-검정 바탕 위에
  /// 진한 안개, 그 위에 대부분은 불투명한 짙은 패널(`surface`)을,
  /// 메인 화면 카드·머리줄만 아주 옅은 흰색(약 8%) 유리(`glassSurface`)를
  /// 얹습니다.
  static const AppPalette dark = AppPalette(
    background: Color(0xFF070F0C),
    surface: Color(0xFF10221C),
    glassSurface: Color(0x14FFFFFF),
    border: Color(0x26D8FFEF),
    text: Color(0xFFEAFBF2),
    textDim: Color(0xFF8FB6A4),
    accent: Color(0xFF34D399),
    accentSecondary: Color(0xFF22D3EE),
    accentTertiary: Color(0xFFA3E635),
    accentText: Color(0xFF07130F),
    accentSoft: Color(0xFF15352B),
    tagBackground: Color(0xFF122A22),
    danger: Color(0xFFE58A6C),
    dangerSoft: Color(0xFF2E1C16),
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
    meshColors: <Color>[
      Color(0xFF34D399),
      Color(0xFF22D3EE),
      Color(0xFFA3E635),
      Color(0xFF14B8A6),
    ],
  );
}
