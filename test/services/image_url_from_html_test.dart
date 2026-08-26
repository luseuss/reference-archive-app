// 브라우저가 건네주는 HTML 조각에서 이미지 주소를 뽑아내는지 확인하는 테스트입니다.
//
// ── 왜 이 기능이 있는가 ──
// 핀터레스트처럼 이미지가 링크에 감싸여 있는 사이트에서 이미지를 끌면,
// 브라우저가 주는 주소는 이미지가 아니라 **링크가 가리키는 페이지 주소**입니다.
// 그걸 내려받으면 HTML이 와서 실패합니다.
//
// 다행히 브라우저는 끌어온 부분의 HTML 조각도 함께 주는데,
// 거기에는 진짜 이미지 주소가 들어 있습니다.

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/services/image_source.dart';

void main() {
  test('img 태그에서 주소를 뽑는다', () {
    const String html = '<img src="https://i.pinimg.com/564x/ab/cd/photo.jpg">';

    expect(imageUrlFromHtml(html), 'https://i.pinimg.com/564x/ab/cd/photo.jpg');
  });

  test('링크에 감싸인 이미지에서도 이미지 주소를 뽑는다', () {
    // 핀터레스트에서 끌었을 때 오는 모양입니다.
    // 링크(href)는 핀 페이지, img(src)가 진짜 이미지입니다.
    const String html = '<a href="https://www.pinterest.com/pin/12345/">'
        '<img src="https://i.pinimg.com/564x/ab/cd/photo.jpg" alt="사진">'
        '</a>';

    // 페이지 주소가 아니라 이미지 주소가 나와야 합니다.
    expect(imageUrlFromHtml(html), 'https://i.pinimg.com/564x/ab/cd/photo.jpg');
  });

  test('작은따옴표도 받는다', () {
    const String html = "<img src='https://a.com/b.jpg'>";

    expect(imageUrlFromHtml(html), 'https://a.com/b.jpg');
  });

  test('src 앞에 다른 속성이 있어도 찾는다', () {
    const String html =
        '<img class="pin" data-id="9" src="https://a.com/b.jpg" width="200">';

    expect(imageUrlFromHtml(html), 'https://a.com/b.jpg');
  });

  test('대문자 태그도 받는다', () {
    const String html = '<IMG SRC="https://a.com/b.jpg">';

    expect(imageUrlFromHtml(html), 'https://a.com/b.jpg');
  });

  test('&amp; 를 원래 글자로 되돌린다', () {
    // HTML 안에서는 &가 &amp;로 적혀 있습니다. 그대로 두면 주소가 깨집니다.
    const String html = '<img src="https://a.com/b.jpg?w=200&amp;h=100">';

    expect(imageUrlFromHtml(html), 'https://a.com/b.jpg?w=200&h=100');
  });

  test('여러 개면 첫 번째를 쓴다', () {
    const String html = '<img src="https://a.com/first.jpg">'
        '<img src="https://a.com/second.jpg">';

    expect(imageUrlFromHtml(html), 'https://a.com/first.jpg');
  });

  test('img가 없으면 null', () {
    expect(imageUrlFromHtml('<a href="https://a.com">링크</a>'), isNull);
    expect(imageUrlFromHtml('그냥 글자'), isNull);
    expect(imageUrlFromHtml(''), isNull);
  });

  test('data: 로 박힌 이미지는 주소가 아니므로 null', () {
    // 내려받을 대상이 아닙니다.
    const String html = '<img src="data:image/png;base64,AAAA">';

    expect(imageUrlFromHtml(html), isNull);
  });

  test('상대 주소는 다루지 않는다', () {
    // 어느 사이트 기준인지 알 수 없어서 내려받을 수 없습니다.
    const String html = '<img src="/images/photo.jpg">';

    expect(imageUrlFromHtml(html), isNull);
  });
}
