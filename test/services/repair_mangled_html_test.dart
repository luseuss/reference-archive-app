// 깨져서 온 HTML을 되돌리는 기능을 확인하는 테스트입니다.
//
// ── 실제로 겪은 문제 ──
// 핀터레스트 피드에서 이미지를 끌면, 크롬이 주는 HTML 조각이
// UTF-8 바이트인데 UTF-16으로 읽혀서 이렇게 깨져 옵니다.
//
//   받은 글자: 愼愠楲ⵡ慬敢㵬
//   원래 글자: <a aria-label=
//
// 이 테스트의 데이터는 실제 앱 로그에서 가져온 것입니다.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/services/image_source.dart';

void main() {
  /// 정상 글자를 "UTF-8 바이트를 UTF-16으로 읽은" 깨진 모양으로 만듭니다.
  ///
  /// 실제로 크롬에서 벌어지는 일을 테스트에서 똑같이 재현하는 것입니다.
  String mangle(String original) {
    final List<int> bytes = utf8.encode(original);

    // 바이트 두 개씩 묶어 글자 하나로 만듭니다. (리틀 엔디언)
    final List<int> units = <int>[];
    for (int i = 0; i < bytes.length; i += 2) {
      final int low = bytes[i];
      final int high = (i + 1 < bytes.length) ? bytes[i + 1] : 0;
      units.add(low | (high << 8));
    }
    return String.fromCharCodes(units);
  }

  test('실제 로그에서 본 깨진 글자를 되돌린다', () {
    // 앱 로그에 찍혔던 그대로입니다.
    const String mangled = '愼愠楲ⵡ慬敢㵬';

    final String? repaired = repairMangledHtml(mangled);

    expect(repaired, startsWith('<a aria-label='));
  });

  test('깨진 HTML에서 이미지 주소를 찾아낸다', () {
    // 핀터레스트에서 오는 것과 같은 모양입니다.
    // 링크는 핀 페이지, img가 진짜 이미지입니다.
    const String original = '<a href="https://kr.pinterest.com/pin/873487290242261950/">'
        '<img src="https://i.pinimg.com/564x/ab/cd/photo.jpg" alt="사진">'
        '</a>';

    final String mangled = mangle(original);

    // 깨진 상태에서는 못 찾습니다.
    expect(imageUrlFromHtml(mangled), isNull);

    // 되돌리면 찾습니다.
    final String? repaired = repairMangledHtml(mangled);
    expect(repaired, isNotNull);
    expect(
      imageUrlFromHtml(repaired!),
      'https://i.pinimg.com/564x/ab/cd/photo.jpg',
    );
  });

  test('한글이 섞여 있어도 되돌린다', () {
    const String original = '<img src="https://a.com/b.jpg" alt="노을 사진">';

    final String mangled = mangle(original);
    final String? repaired = repairMangledHtml(mangled);

    expect(imageUrlFromHtml(repaired!), 'https://a.com/b.jpg');
  });

  test('빈 글자는 null', () {
    expect(repairMangledHtml(''), isNull);
  });

  test('멀쩡한 HTML에는 쓰지 않는다 (되돌리면 오히려 깨짐)', () {
    // 이 함수는 "정상 처리가 실패했을 때만" 부르는 것입니다.
    // 멀쩡한 글자에 쓰면 알아볼 수 없게 되는 것이 정상이며,
    // 그래서 화면 코드에서 순서를 지켜 부릅니다.
    const String healthy = '<img src="https://a.com/b.jpg">';

    final String? repaired = repairMangledHtml(healthy);

    // 되돌린 결과에서는 원래 주소를 못 찾습니다.
    expect(repaired, isNot(contains('https://a.com/b.jpg')));
  });
}
