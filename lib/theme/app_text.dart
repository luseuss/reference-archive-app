// 앱에서 쓰는 글자 모양을 한곳에 모아둔 파일입니다.
//
// ── 왜 모아두나 ──
// 화면마다 `TextStyle(fontSize: 12.5, ...)` 처럼 숫자를 직접 적으면, 같은 성격의
// 글자인데 어떤 화면은 12.5px, 어떤 화면은 13px이 되어 미묘하게 안 맞습니다.
// 그리고 나중에 "메모 글자를 좀 키우자"고 할 때 **어디를 다 고쳐야 하는지
// 알 수 없게** 됩니다.
//
// 크기·굵기 값은 대부분 기존 웹앱(`app.html`)의 CSS에서 그대로 가져왔습니다.
// (2026-09-11 "라이트테이블" 디자인부터는 screenTitle/cardTitle 딱 둘만
// 예외입니다 — 글꼴을 세리프로 바꾸면서 크기도 함께 새로 정했습니다.
// app_palette.dart 위쪽 설명 참고)
//
// ── 색이 왜 안 들어있나 ──
// 색은 밝은 모드와 어두운 모드가 다릅니다. 여기 박아두면 한쪽에서만 맞게 됩니다.
// 그래서 **크기·굵기만** 정해두고, 색은 쓰는 곳에서 붙입니다.
//
//   Text('제목', style: AppText.cardTitle.copyWith(color: palette.text))
//
// 조금 번거롭지만, 이 규칙 덕분에 어두운 모드에서 안 보이는 글자가 생기지 않습니다.

import 'package:flutter/material.dart';

/// 앱에서 쓰는 글자 모양들입니다.
///
/// 이름은 "어디에 쓰는 글자인가"로 붙였습니다. `fontSize14_5` 같은 이름을 쓰면
/// 나중에 크기를 바꿀 때 이름과 실제가 어긋나기 때문입니다.
class AppText {
  // 이 클래스는 값을 모아두기만 합니다. 만들어 쓸 일이 없습니다.
  const AppText._();

  /// 화면 맨 위 제목입니다.
  ///
  /// ── 여기만 세리프(Gowun Batang)를 씁니다 ──
  /// 나머지 글자는 전부 app_theme.dart가 기본으로 까는 IBM Plex Sans KR을
  /// 그대로 씁니다. "이게 무엇인지"를 보여주는 자리(화면 제목, 카드 제목)에만
  /// 세리프를 골라 써서, 그 자리가 눈에 띄되 화면 전체가 산만해지지
  /// 않게 했습니다.
  static const TextStyle screenTitle = TextStyle(
    fontFamily: 'Gowun Batang',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  /// 구역 이름표입니다. ("폴더", "카테고리" 같은 작은 라벨)
  ///
  /// 웹앱은 여기에 `text-transform: uppercase`도 걸지만, 한글에는 대문자가
  /// 없어서 의미가 없습니다. 그래서 크기·굵기·자간만 가져왔습니다.
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.44,
  );

  /// 카드 제목입니다. screenTitle과 같은 이유로 세리프(Gowun Batang)를 씁니다.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: 'Gowun Batang',
    fontSize: 15.5,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  /// 카드의 폴더 표시입니다.
  static const TextStyle cardFolder = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );

  /// 카드의 카테고리 표시입니다. 폴더보다 살짝 큽니다.
  ///
  /// 기존 웹앱이 카테고리를 폴더보다 중요하게 다룹니다.
  /// (크기도 한 단계 크고 색도 강조색을 씁니다)
  static const TextStyle cardCategory = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
  );

  /// 카드의 메모입니다.
  static const TextStyle cardMemo = TextStyle(fontSize: 12.5, height: 1.5);

  /// 태그 알약 안의 글자입니다.
  static const TextStyle tag = TextStyle(fontSize: 11);

  /// 날짜·개수처럼 곁들이는 작은 글자입니다.
  static const TextStyle meta = TextStyle(fontSize: 11);

  /// 목록 위의 "총 N개" 같은 안내입니다.
  static const TextStyle countRow = TextStyle(fontSize: 12.5);

  /// 버튼 글자입니다.
  static const TextStyle button = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
  );

  /// 칩(알약 모양 필터 버튼) 글자입니다.
  static const TextStyle chip = TextStyle(fontSize: 12.5);

  /// 폴더·카테고리 칩 글자입니다. 칩보다 조금 크고 굵습니다.
  static const TextStyle folderChip = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  /// 입력창에 치는 글자입니다.
  static const TextStyle input = TextStyle(fontSize: 14);

  /// 아무것도 없을 때 보여주는 안내의 제목입니다.
  static const TextStyle emptyTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  /// 아무것도 없을 때 보여주는 안내의 설명입니다.
  static const TextStyle emptyBody = TextStyle(fontSize: 13.5, height: 1.5);
}
