// 사이트 자체 형식의 원시 바이트를 읽는 부분을 확인하는 테스트입니다.
//
// ── 이 테스트가 왜 따로 있는가 ──
// 처음에는 이 처리를 화면 코드 안에 숨겨두고, 테스트는 "공백이 낀 글자"로
// 대충 만들어 시험했습니다. 테스트는 통과했지만 **실제로는 동작하지 않았습니다.**
// 로그에 0 바이트가 공백처럼 보여서, 실제와 다른 것을 검증하고 있었던 겁니다.
//
// 그래서 처리를 밖으로 꺼내고, 실제로 오는 것과 같은 **진짜 바이트**로 시험합니다.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/services/image_source.dart';

void main() {
  /// 글자를 UTF-16LE 바이트로 만듭니다. 실제로 오는 모양과 같습니다.
  ///
  /// 영어와 숫자는 뒤쪽 바이트가 0이라 "h,0,t,0,t,0..." 이 됩니다.
  List<int> toUtf16LeBytes(String text) {
    final List<int> bytes = <int>[];
    for (final int unit in text.codeUnits) {
      bytes.add(unit & 0xFF);
      bytes.add((unit >> 8) & 0xFF);
    }
    return bytes;
  }

  test('0이 낀 바이트에서 주소를 읽어낸다', () {
    const String url = 'https://i.pinimg.com/736x/ab/cd/ef/photo.jpg';
    final List<int> bytes = toUtf16LeBytes(url);

    // 0을 안 빼고 그냥 읽으면 글자가 끊겨서 주소로 안 보입니다.
    // (이게 실제로 실패했던 이유입니다)
    final String naive = utf8.decode(bytes, allowMalformed: true);
    expect(findImageUrlInText(naive), isNull);

    // 제대로 읽으면 찾힙니다.
    final String proper = textFromCustomData(bytes);
    expect(findImageUrlInText(proper), url);
  });

  test('핀터레스트 상세 페이지 데이터를 통째로 넣어도 찾는다', () {
    // 실제 로그에서 확인한 모양입니다.
    const String json =
        'application/x-pinterest-closeup-image'
        '{"isVideo":false,"pinId":"628463323029257840",'
        '"previewImageUrl":"https://i.pinimg.com/736x/1e/dc/ac/1edcac3e.jpg"}';

    final String text = textFromCustomData(toUtf16LeBytes(json));

    expect(
      findImageUrlInText(text),
      'https://i.pinimg.com/736x/1e/dc/ac/1edcac3e.jpg',
    );
  });

  test('0이 없는 평범한 바이트도 그대로 읽는다', () {
    // 어떤 사이트는 0 없이 UTF-8로 담습니다. 그때도 망가지면 안 됩니다.
    const String plain = '{"src":"https://a.com/b.png"}';
    final List<int> bytes = utf8.encode(plain);

    expect(textFromCustomData(bytes), plain);
    expect(findImageUrlInText(textFromCustomData(bytes)), 'https://a.com/b.png');
  });

  test('빈 바이트는 빈 글자', () {
    expect(textFromCustomData(<int>[]), '');
  });
}
