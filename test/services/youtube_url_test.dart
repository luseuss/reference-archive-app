// 유튜브 주소에서 영상 번호를 뽑아내는 부분을 확인하는 테스트입니다.
//
// 이 부분이 틀리면 "주소를 넣었는데 안 된다"는 증상으로 나타나는데,
// 사용자 입장에서는 앱이 그냥 고장난 것으로 보입니다. 주소 모양이 워낙 많아서
// 실제로 쓰이는 형태를 전부 적어두고 지킵니다.
//
// 새로운 주소 모양이 안 먹히는 것을 발견하면, 여기에 먼저 한 줄 추가하고
// lib/services/youtube_url.dart를 고치세요.

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/services/youtube_url.dart';

void main() {
  // 테스트 내내 쓰는 영상 번호입니다. 실제로 존재하는 영상의 번호 형식입니다.
  const String id = 'dQw4w9WgXcQ';

  group('영상 번호 뽑아내기 — 되는 주소들', () {
    test('주소창에서 복사한 형태', () {
      expect(youtubeVideoIdFrom('https://www.youtube.com/watch?v=$id'), id);
    });

    test('"공유" 버튼이 만들어주는 짧은 주소', () {
      expect(youtubeVideoIdFrom('https://youtu.be/$id'), id);
    });

    test('공유 주소에 추적용 값이 붙어 있어도 된다', () {
      // 유튜브가 "공유"로 복사해주면 ?si=... 가 따라옵니다.
      expect(youtubeVideoIdFrom('https://youtu.be/$id?si=AbCdEfGhIjK'), id);
    });

    test('재생 시점(t)이 붙어 있어도 된다', () {
      expect(youtubeVideoIdFrom('https://www.youtube.com/watch?v=$id&t=42s'), id);
    });

    test('v가 첫 번째 값이 아니어도 찾는다', () {
      // 이름으로 찾기 때문에 순서는 상관없습니다.
      expect(
        youtubeVideoIdFrom('https://www.youtube.com/watch?list=PL123&v=$id'),
        id,
      );
    });

    test('쇼츠', () {
      expect(youtubeVideoIdFrom('https://www.youtube.com/shorts/$id'), id);
    });

    test('라이브', () {
      expect(youtubeVideoIdFrom('https://www.youtube.com/live/$id'), id);
    });

    test('임베드 주소', () {
      expect(youtubeVideoIdFrom('https://www.youtube.com/embed/$id'), id);
    });

    test('폰에서 복사한 주소 (m.youtube.com)', () {
      expect(youtubeVideoIdFrom('https://m.youtube.com/watch?v=$id'), id);
    });

    test('유튜브 뮤직', () {
      expect(youtubeVideoIdFrom('https://music.youtube.com/watch?v=$id'), id);
    });

    test('www가 없어도 된다', () {
      expect(youtubeVideoIdFrom('https://youtube.com/watch?v=$id'), id);
    });

    test('http여도 된다', () {
      expect(youtubeVideoIdFrom('http://www.youtube.com/watch?v=$id'), id);
    });

    test('https:// 가 아예 빠져 있어도 된다', () {
      // 글에서 긁어오면 앞이 잘려 있는 경우가 흔합니다.
      expect(youtubeVideoIdFrom('youtu.be/$id'), id);
      expect(youtubeVideoIdFrom('www.youtube.com/watch?v=$id'), id);
    });

    test('앞뒤 공백은 무시한다', () {
      expect(youtubeVideoIdFrom('  https://youtu.be/$id  \n'), id);
    });

    test('영상 번호에 - 와 _ 가 들어가도 된다', () {
      // 실제로 흔합니다. 이걸 거르면 멀쩡한 영상이 안 들어갑니다.
      const String dashId = 'a-b_c1D2e3F';
      expect(youtubeVideoIdFrom('https://youtu.be/$dashId'), dashId);
    });
  });

  group('영상 번호 뽑아내기 — 안 되는 주소들', () {
    test('유튜브가 아닌 사이트는 null', () {
      expect(youtubeVideoIdFrom('https://vimeo.com/123456'), isNull);
      expect(youtubeVideoIdFrom('https://example.com/watch?v=$id'), isNull);
    });

    test('유튜브를 흉내낸 주소는 null', () {
      // 이걸 통과시키면 엉뚱한 사이트를 유튜브로 저장하게 됩니다.
      expect(youtubeVideoIdFrom('https://notyoutube.com/watch?v=$id'), isNull);
      expect(youtubeVideoIdFrom('https://youtube.com.evil.net/watch?v=$id'), isNull);
    });

    test('영상이 아닌 유튜브 페이지는 null', () {
      expect(youtubeVideoIdFrom('https://www.youtube.com/'), isNull);
      expect(youtubeVideoIdFrom('https://www.youtube.com/@somechannel'), isNull);
      expect(
        youtubeVideoIdFrom('https://www.youtube.com/playlist?list=PL123'),
        isNull,
      );
    });

    test('영상 번호 길이가 안 맞으면 null', () {
      // 11글자가 아니면 유튜브 영상 번호가 아닙니다.
      expect(youtubeVideoIdFrom('https://youtu.be/tooshort'), isNull);
      expect(youtubeVideoIdFrom('https://youtu.be/waaaaaaaaaaytoolong'), isNull);
    });

    test('v 값이 비어 있으면 null', () {
      // 확인 없이 받으면 빈 영상 번호를 저장하게 되고,
      // 나중에 재생할 때 이유를 알 수 없는 오류가 납니다.
      expect(youtubeVideoIdFrom('https://www.youtube.com/watch?v='), isNull);
    });

    test('영상 번호에 이상한 글자가 있으면 null', () {
      expect(youtubeVideoIdFrom('https://youtu.be/abc!@#\$%^&'), isNull);
    });

    test('빈 글자와 주소가 아닌 글자는 null', () {
      expect(youtubeVideoIdFrom(''), isNull);
      expect(youtubeVideoIdFrom('   '), isNull);
      expect(youtubeVideoIdFrom('그냥 적어둔 메모'), isNull);
    });
  });

  group('isYoutubeVideoUrl', () {
    test('영상 주소면 true, 아니면 false', () {
      expect(isYoutubeVideoUrl('https://youtu.be/$id'), isTrue);
      expect(isYoutubeVideoUrl('https://example.com/photo.jpg'), isFalse);
      expect(isYoutubeVideoUrl('https://www.youtube.com/@somechannel'), isFalse);
    });
  });

  group('주소 만들기', () {
    test('감상 주소', () {
      expect(youtubeWatchUrl(id), 'https://www.youtube.com/watch?v=$id');
    });

    test('앱 안에서 재생할 주소는 embed에 자동재생이 붙는다', () {
      final String url = youtubeEmbedUrl(id);

      expect(url, startsWith('https://www.youtube.com/embed/$id'));
      expect(url, contains('autoplay=1'));
      // 아이폰에서 전체화면으로 튕기지 않게 하는 값입니다.
      expect(url, contains('playsinline=1'));
    });

    test('재생기 HTML은 embed 주소를 iframe 안에 넣는다', () {
      // ── 이 테스트가 지키는 것 (실제로 겪은 문제) ──
      // 처음에는 embed 주소를 웹뷰의 맨 위 페이지로 그대로 열었습니다.
      // 그랬더니 유튜브가 "오류 153 — 플레이어 구성 오류"를 냈습니다.
      // 요청에 "어느 페이지에 끼워져 있는지"가 없어서입니다.
      //
      // 그래서 iframe에 담게 바꿨습니다. 누군가 나중에 "굳이 HTML까지 만들 필요
      // 있나" 하고 되돌리면 재생이 통째로 깨지므로 여기서 못 박아둡니다.
      final String html = youtubePlayerHtml(id);

      expect(html, contains('<iframe'));
      expect(html, contains(youtubeEmbedUrl(id)));
      // 전체화면 버튼이 동작하려면 이 값이 있어야 합니다.
      expect(html, contains('allowfullscreen'));
      // 자동재생도 iframe에 허용을 적어줘야 먹습니다.
      expect(html, contains('autoplay'));
    });

    test('썸네일 주소는 두 가지를 만들 수 있다', () {
      expect(
        youtubeThumbnailUrl(id),
        'https://img.youtube.com/vi/$id/maxresdefault.jpg',
      );
      expect(
        youtubeThumbnailUrl(id, preferHighest: false),
        'https://img.youtube.com/vi/$id/hqdefault.jpg',
      );
    });

    test('뽑아낸 번호를 다시 넣어도 그대로 나온다', () {
      // 주소 → 번호 → 주소 → 번호가 어긋나지 않는지 봅니다.
      final String? extracted = youtubeVideoIdFrom('https://youtu.be/$id?si=x');
      expect(youtubeVideoIdFrom(youtubeWatchUrl(extracted!)), id);
    });
  });
}
