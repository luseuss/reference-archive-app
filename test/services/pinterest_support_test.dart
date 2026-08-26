// 핀터레스트에서 이미지를 가져오기 위한 두 기능을 확인하는 테스트입니다.
//
//   1. 사이트가 자체 형식에 끼워 넣은 이미지 주소 찾기
//   2. 축소본 주소를 원본 화질 주소로 바꾸기
//
// 두 데이터 모두 실제 앱 로그에서 확인한 것을 그대로 썼습니다.

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/services/image_source.dart';

void main() {
  group('자체 데이터에서 이미지 주소 찾기', () {
    test('핀터레스트 상세 페이지 데이터에서 주소를 찾는다', () {
      // 실제 로그에 찍힌 내용입니다.
      // 핀터레스트는 표준 형식으로는 아무것도 안 주면서
      // 자체 형식 안에는 이미지 주소를 넣어둡니다.
      const String customData =
          'chromium/x-drag-id B981C820D2DD16966C30FD652C61E1C8'
          'application/x-pinterest-closeup-image'
          '{"clientTrackingParams":"CwABAAAAEDIyMzcy","isPdpEligible":false,'
          '"isPromoted":false,"isVideo":false,"pinId":"628463323029257840",'
          '"previewImageUrl":"https://i.pinimg.com/736x/1e/dc/ac/1edcac3e7705a41a37a18087acaed1d1.jpg",'
          '"sourceNodeId":"UGluOjYyODQ2MzMyMzAyOTI1Nzg0MA=="}';

      expect(
        findImageUrlInText(customData),
        'https://i.pinimg.com/736x/1e/dc/ac/1edcac3e7705a41a37a18087acaed1d1.jpg',
      );
    });


    test('여러 확장자를 알아본다', () {
      expect(findImageUrlInText('x https://a.com/1.png y'), 'https://a.com/1.png');
      expect(findImageUrlInText('x https://a.com/2.webp y'), 'https://a.com/2.webp');
      expect(findImageUrlInText('x https://a.com/3.JPEG y'), 'https://a.com/3.JPEG');
    });

    test('이미지가 아닌 주소는 찾지 않는다', () {
      // 페이지 주소를 이미지로 착각하면 HTML을 받아와 실패합니다.
      const String text = '{"link":"https://www.pinterest.com/pin/12345/"}';

      expect(findImageUrlInText(text), isNull);
    });

    test('주소가 없으면 null', () {
      expect(findImageUrlInText('그냥 글자'), isNull);
      expect(findImageUrlInText(''), isNull);
    });
  });

  group('원본 화질 주소로 바꾸기', () {
    test('736x 를 originals 로 바꾼다', () {
      // 실제로 확인한 차이: 736x는 36KB, originals는 223KB
      expect(
        upgradePinterestUrl(
          'https://i.pinimg.com/736x/1e/dc/ac/1edcac3e.jpg',
        ),
        'https://i.pinimg.com/originals/1e/dc/ac/1edcac3e.jpg',
      );
    });

    test('236x 도 바꾼다 (피드에서 오는 크기)', () {
      expect(
        upgradePinterestUrl('https://i.pinimg.com/236x/d7/32/ea/d732ea45.jpg'),
        'https://i.pinimg.com/originals/d7/32/ea/d732ea45.jpg',
      );
    });

    test('확장자는 건드리지 않는다', () {
      // .jpg를 .png로 바꾸면 403이 납니다(실제로 확인).
      expect(
        upgradePinterestUrl('https://i.pinimg.com/564x/ab/cd/ef/photo.png'),
        'https://i.pinimg.com/originals/ab/cd/ef/photo.png',
      );
    });

    test('이미 originals 면 그대로 둔다', () {
      const String url = 'https://i.pinimg.com/originals/ab/cd/ef/photo.jpg';

      expect(upgradePinterestUrl(url), url);
    });

    test('핀터레스트가 아닌 주소는 건드리지 않는다', () {
      const String url = 'https://example.com/736x/photo.jpg';

      expect(upgradePinterestUrl(url), url);
    });

    test('비슷하지만 다른 주소도 건드리지 않는다', () {
      // 주소 한가운데에 pinimg가 들어간 남의 사이트를 잘못 건드리면 안 됩니다.
      const String url = 'https://evil.com/i.pinimg.com/736x/a.jpg';

      expect(upgradePinterestUrl(url), url);
    });
  });
}
