// 유튜브 주소에서 영상 번호(video ID)를 뽑아내는 파일입니다.
//
// ── 왜 따로 있는가 ──
// 유튜브 주소는 모양이 여러 가지입니다. 사용자가 어디서 복사했느냐에 따라
// 전부 다르게 생겼는데, 우리에게 필요한 것은 그 안의 11글자짜리 영상 번호 하나뿐입니다.
//
//   https://www.youtube.com/watch?v=dQw4w9WgXcQ      ← 주소창에서 복사
//   https://youtu.be/dQw4w9WgXcQ?si=abc123           ← "공유" 버튼으로 복사
//   https://www.youtube.com/shorts/dQw4w9WgXcQ       ← 쇼츠
//   https://www.youtube.com/live/dQw4w9WgXcQ         ← 라이브
//   https://m.youtube.com/watch?v=dQw4w9WgXcQ        ← 폰에서 복사
//
// 여기 있는 함수들은 **인터넷도 화면도 건드리지 않습니다.** 글자를 받아 글자를
// 돌려줄 뿐이라 테스트하기 쉽고, 새로운 주소 모양이 나와도 여기만 고치면 됩니다.

/// 영상 번호의 글자 수입니다. 유튜브 영상 번호는 언제나 11글자입니다.
const int _videoIdLength = 11;

/// 유튜브 주소로 인정하는 사이트 이름들입니다.
///
/// `www.`은 떼고 비교하므로 여기 적을 필요가 없습니다.
const Set<String> _youtubeHosts = <String>{
  'youtube.com',
  'm.youtube.com',
  'music.youtube.com',
  'youtu.be',
  'youtube-nocookie.com',
};

/// 주소 안에서 영상 번호가 경로에 들어가는 형태들입니다.
///
/// 예: `youtube.com/shorts/dQw4w9WgXcQ` 에서 `shorts` 다음 칸이 영상 번호입니다.
const Set<String> _pathPrefixesWithId = <String>{
  'shorts',
  'embed',
  'live',
  'v',
};

/// 유튜브 주소에서 영상 번호를 뽑아냅니다. 유튜브 주소가 아니면 null입니다.
///
/// 앞뒤 공백과 `https://` 누락은 알아서 처리합니다.
/// 사용자가 주소창에서 복사하면 보통 온전하지만, 글에서 긁어오면
/// "youtu.be/..." 처럼 앞이 잘려 있는 경우가 흔합니다.
String? youtubeVideoIdFrom(String rawUrl) {
  final String trimmed = rawUrl.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final Uri? uri = _parseWithScheme(trimmed);
  if (uri == null) {
    return null;
  }

  if (!_isYoutubeHost(uri.host)) {
    return null;
  }

  // ① youtu.be/영상번호 — "공유" 버튼이 만들어주는 짧은 주소입니다.
  //    사이트 이름 바로 다음 칸이 영상 번호입니다.
  if (_stripWww(uri.host) == 'youtu.be') {
    return _validId(_firstPathSegment(uri));
  }

  // ② youtube.com/watch?v=영상번호 — 주소창에서 복사하면 이 모양입니다.
  //    `v` 말고도 `t=30s` 같은 것이 함께 붙어 있을 수 있어서 이름으로 찾습니다.
  final String? fromQuery = uri.queryParameters['v'];
  if (fromQuery != null) {
    return _validId(fromQuery);
  }

  // ③ youtube.com/shorts/영상번호 처럼 경로에 들어가는 형태들입니다.
  final List<String> segments = uri.pathSegments;
  if (segments.length >= 2 && _pathPrefixesWithId.contains(segments.first)) {
    return _validId(segments[1]);
  }

  // 유튜브 주소이긴 한데 영상 하나를 가리키지 않는 경우입니다.
  // (채널 페이지, 재생목록만 있는 주소 등)
  return null;
}

/// 이 글자가 유튜브 영상 주소인지 확인합니다.
///
/// 붙여넣기나 끌어다 놓기에서 "이걸 유튜브로 다뤄야 하나, 이미지로 다뤄야 하나"를
/// 가릴 때 씁니다.
bool isYoutubeVideoUrl(String rawUrl) {
  return youtubeVideoIdFrom(rawUrl) != null;
}

/// 영상 번호로 유튜브 감상 주소를 만듭니다.
///
/// 저장할 때는 사용자가 넣은 주소를 그대로 두지 않고 영상 번호만 저장합니다.
/// 그래야 주소 모양이 무엇이었든 앱 안에서는 한 가지로만 다루면 됩니다.
String youtubeWatchUrl(String videoId) {
  return 'https://www.youtube.com/watch?v=$videoId';
}

/// 영상 번호로 앱 안에서 재생할 때 쓰는 주소를 만듭니다.
///
/// ── 왜 watch 주소를 그대로 안 쓰나 ──
/// 앱 안의 작은 창에서 유튜브 페이지 전체를 띄우면 추천 영상, 댓글, 로그인 안내까지
/// 다 따라 들어와서 정작 영상이 손톱만 해집니다. `embed` 주소는 재생기만 나옵니다.
///
/// 붙는 값들의 뜻:
///   - `autoplay=1`  창을 열면 바로 재생합니다. 보려고 연 것이니까요.
///   - `rel=0`       영상이 끝났을 때 남의 채널 추천을 덜 보여줍니다.
///   - `playsinline=1` 아이폰에서 전체화면으로 튕기지 않고 그 자리에서 재생합니다.
///
/// [muted]를 켜면 소리 없이, 조작 버튼 없이 재생합니다. **호버 미리보기용**입니다.
/// 목록 위로 마우스가 지나갈 때마다 소리가 나면 쓸 수 없는 기능이 됩니다.
/// (브라우저들도 소리가 나는 자동재생은 대부분 막습니다)
String youtubeEmbedUrl(String videoId, {bool muted = false}) {
  final String base =
      'https://www.youtube.com/embed/$videoId'
      '?autoplay=1&rel=0&playsinline=1';

  if (!muted) {
    return base;
  }

  // controls=0 = 조작 버튼 숨김. 미리보기는 누를 수 없게 해둘 것이라
  // 버튼이 보이면 눌리는 줄 알고 헛클릭하게 됩니다.
  return '$base&mute=1&controls=0';
}

/// 앱 안 웹뷰에 띄울 재생기 HTML을 만듭니다.
///
/// ── 왜 embed 주소를 그냥 열면 안 되는가 (오류 153) ──
/// embed 주소를 웹뷰의 **맨 위 페이지로 직접** 열면, 그 요청에는 "어느 페이지에
/// 끼워져 있는지"를 알려주는 값(Referer)이 없습니다. 유튜브는 그걸 정상적인
/// 끼워넣기로 보지 않고 이렇게 거부합니다.
///
///   오류 153 — 플레이어 구성 오류
///
/// 그래서 embed 주소를 **`<iframe>` 안에** 넣습니다. 그리고 이 HTML은
/// **진짜 주소를 가진 페이지로** 띄워야 합니다 — `local_player_server.dart`가
/// 그 역할을 합니다. 웹뷰에 HTML을 직접 넘기면서 "youtube.com에 있는 것으로
/// 쳐달라"(baseUrl)고 하는 방법은 **Windows에서 통하지 않습니다.**
/// (그 경위도 local_player_server.dart 맨 위에 적어뒀습니다)
///
/// 기존 웹앱이 잘 되던 이유도 같습니다. 거기서는 애초에 iframe이었고,
/// 진짜 페이지 주소가 참조 주소 역할을 해줬습니다.
///
/// [videoId]는 이 파일의 `youtubeVideoIdFrom()`을 거쳐 **영문·숫자·`-`·`_` 11글자**로
/// 확인된 값만 들어옵니다. 그래서 HTML에 그대로 끼워 넣어도 안전합니다.
/// 확인을 거치지 않은 글자를 여기 넣으면 안 됩니다.
String youtubePlayerHtml(String videoId, {bool muted = false}) {
  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
<style>
  /* 재생기가 창을 꽉 채우고, 둘레에 흰 여백이 생기지 않게 합니다. */
  html, body { margin: 0; padding: 0; height: 100%; background: #000; overflow: hidden; }
  iframe { border: 0; width: 100%; height: 100%; display: block; }
</style>
</head>
<body>
<iframe
  src="${youtubeEmbedUrl(videoId, muted: muted)}"
  allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
  allowfullscreen></iframe>
</body>
</html>
''';
}

/// 영상 번호로 썸네일(미리보기 그림) 주소를 만듭니다.
///
/// [preferHighest]가 true면 가장 큰 그림을 요청합니다. 다만 이 그림은
/// **영상에 따라 없을 수도 있어서**, 실패하면 부르는 쪽에서 false로 다시 시도해야 합니다.
/// 자세한 사정은 youtube_info_source.dart의 `fetchThumbnail()`에 적어뒀습니다.
String youtubeThumbnailUrl(String videoId, {bool preferHighest = true}) {
  final String fileName = preferHighest ? 'maxresdefault' : 'hqdefault';
  return 'https://img.youtube.com/vi/$videoId/$fileName.jpg';
}

// ── 아래는 이 파일 안에서만 쓰는 도우미 함수들입니다 ──

/// 글자를 주소로 해석합니다. `https://`가 빠져 있으면 붙여서 다시 해봅니다.
///
/// `Uri.parse('youtu.be/abc')`는 오류를 내지 않고 **사이트 이름이 비어 있는**
/// 이상한 주소를 만들어냅니다. 그래서 사이트 이름이 비었으면 한 번 더 시도합니다.
Uri? _parseWithScheme(String text) {
  final Uri? direct = Uri.tryParse(text);

  if (direct != null && direct.host.isNotEmpty) {
    return direct;
  }

  return Uri.tryParse('https://$text');
}

/// 이 사이트 이름이 유튜브인지 확인합니다.
bool _isYoutubeHost(String host) {
  return _youtubeHosts.contains(_stripWww(host.toLowerCase()));
}

/// 사이트 이름 앞의 `www.`를 떼어냅니다.
String _stripWww(String host) {
  if (host.startsWith('www.')) {
    return host.substring(4);
  }
  return host;
}

/// 주소 경로의 첫 칸을 돌려줍니다. 없으면 null입니다.
String? _firstPathSegment(Uri uri) {
  if (uri.pathSegments.isEmpty) {
    return null;
  }
  return uri.pathSegments.first;
}

/// 영상 번호처럼 생겼는지 확인하고, 맞으면 그대로 돌려줍니다.
///
/// 길이와 쓰인 글자를 둘 다 봅니다. 확인 없이 받으면 `youtube.com/watch?v=`처럼
/// 값이 비어 있는 주소에서 빈 영상 번호를 저장하게 되고, 나중에 재생할 때
/// 이유를 알 수 없는 오류가 납니다.
String? _validId(String? candidate) {
  if (candidate == null || candidate.length != _videoIdLength) {
    return null;
  }

  for (final int codeUnit in candidate.codeUnits) {
    final bool isDigit = codeUnit >= 0x30 && codeUnit <= 0x39;
    final bool isUpper = codeUnit >= 0x41 && codeUnit <= 0x5A;
    final bool isLower = codeUnit >= 0x61 && codeUnit <= 0x7A;
    final bool isDash = codeUnit == 0x2D; // -
    final bool isUnderscore = codeUnit == 0x5F; // _

    if (!isDigit && !isUpper && !isLower && !isDash && !isUnderscore) {
      return null;
    }
  }

  return candidate;
}
