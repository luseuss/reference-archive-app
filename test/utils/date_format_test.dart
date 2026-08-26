// 카드에 보여줄 날짜 글자를 확인하는 테스트입니다.
//
// ── 왜 이걸 테스트하는가 ──
// 이 앱은 시각을 **UTC로 저장**하고 보여줄 때만 현지 시각으로 바꿉니다.
// 그 변환을 빠뜨리면 한국에서는 9시간 어긋난 날짜가 보이고, **밤에 넣은 것은
// 하루 전 날짜로 보입니다.** 눈으로는 알아채기 어려운 종류의 오류라
// 테스트로 못 박아둡니다.

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/utils/date_format.dart';

void main() {
  test('한국식 표기로 만든다', () {
    // 현지 시각 기준으로 만들어지므로, 테스트도 현지 시각으로 넣고 확인합니다.
    final DateTime local = DateTime(2026, 8, 27);

    expect(formatCardDate(local.toUtc()), '2026. 08. 27.');
  });

  test('한 자리 수 월·일 앞에 0을 붙인다', () {
    // "2026. 1. 5." 처럼 들쭉날쭉하면 카드마다 글자 길이가 달라 지저분합니다.
    final DateTime local = DateTime(2026, 1, 5);

    expect(formatCardDate(local.toUtc()), '2026. 01. 05.');
  });

  test('UTC로 저장된 시각을 현지 날짜로 바꾼다', () {
    // ── 이게 이 파일의 핵심입니다 ──
    // 한국에서 밤 늦게(예: 밤 11시) 넣은 레퍼런스는 UTC로는 **그날 낮**입니다.
    // 반대로 UTC 자정 직후는 한국에서 이미 **다음 날 오전 9시**입니다.
    // 변환을 빠뜨리면 이런 항목의 날짜가 하루씩 어긋나 보입니다.
    final DateTime localNight = DateTime(2026, 8, 27, 23, 30);

    // 저장은 UTC로 되지만, 보여줄 때는 넣은 날짜(27일)가 나와야 합니다.
    expect(formatCardDate(localNight.toUtc()), '2026. 08. 27.');
  });

  test('현지 시각을 그대로 넣어도 같은 결과가 나온다', () {
    // toLocal()은 이미 현지 시각인 값에 써도 아무 일이 없습니다.
    // 그래서 어느 쪽을 넘겨도 결과가 같습니다.
    final DateTime local = DateTime(2026, 12, 31, 10);

    expect(formatCardDate(local), formatCardDate(local.toUtc()));
  });
}
