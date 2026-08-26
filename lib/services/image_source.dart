// 웹이나 다른 앱에서 이미지를 가져오는 여러 경로를 한 곳으로 모으는 파일입니다.
//
// ── 왜 여러 경로가 필요한가 ──
// 브라우저에서 이미지를 앱으로 끌어다 놓으면, 브라우저가 무엇을 건네주는지가
// 상황마다 다릅니다.
//
//   1. 이미지 데이터 자체 (드물게)
//   2. 임시 파일 경로
//   3. **이미지 주소(URL)만** ← 브라우저에서 끌 때 가장 흔합니다
//
// 그래서 "끌어다 놓기"만 만들면 어떤 경우엔 되고 어떤 경우엔 안 되는,
// 사용자 입장에서 이유를 알 수 없는 기능이 됩니다.
// 이 파일은 무엇이 들어오든 **결국 이미지 데이터(바이트)로 만들어** 돌려줍니다.
//
// 실제 저장은 image_storage.dart가 맡습니다. 여기서는 "가져오기"까지만 합니다.

import 'dart:convert';
import 'dart:typed_data';

/// 이미지를 가져온 결과입니다.
///
/// 성공하면 [bytes]에 이미지 데이터가, 실패하면 [errorMessage]에 이유가 들어갑니다.
/// 둘 중 하나만 채워집니다.
class ImageFetchResult {
  const ImageFetchResult.success(this.bytes, {this.suggestedTitle})
    : errorMessage = null;

  const ImageFetchResult.failure(this.errorMessage)
    : bytes = null,
      suggestedTitle = null;

  /// 가져온 이미지 데이터입니다. 실패하면 null입니다.
  final Uint8List? bytes;

  /// 제목으로 쓸 만한 이름입니다. 없으면 null입니다.
  ///
  /// 예를 들어 주소가 ".../sunset-photo.jpg"라면 "sunset-photo"를 제안합니다.
  /// 사용자가 나중에 고칠 수 있으니 대충이라도 있는 편이 낫습니다.
  final String? suggestedTitle;

  /// 실패한 이유입니다. 성공하면 null입니다.
  ///
  /// 이 글자는 그대로 사용자에게 보여줍니다. 그래서 "HTTP 404" 같은 말 대신
  /// 무엇을 해야 하는지 알 수 있는 문장으로 적습니다.
  final String? errorMessage;

  /// 가져오기에 성공했는지 여부입니다.
  bool get isSuccess => bytes != null;
}

/// 주소나 클립보드에서 이미지를 가져오는 방법에 대한 약속입니다.
///
/// 약속으로 두는 이유는 저장소(repositories/)와 같습니다 —
/// 테스트에서 진짜 인터넷을 쓰지 않고 가짜로 갈아끼우기 위해서입니다.
/// 인터넷을 실제로 쓰는 테스트는 느리고, 연결이 없으면 실패하고,
/// 남의 서버 사정에 따라 결과가 달라집니다.
abstract class ImageSource {
  /// 인터넷 주소에서 이미지를 내려받습니다.
  Future<ImageFetchResult> fetchFromUrl(String url);

  /// 클립보드에 들어있는 이미지를 가져옵니다.
  ///
  /// 클립보드에 이미지가 없으면 실패로 돌려줍니다.
  Future<ImageFetchResult> fetchFromClipboard();

  /// 클립보드에 들어있는 글자를 가져옵니다. 없으면 null입니다.
  ///
  /// 브라우저에서 이미지 주소를 복사한 경우를 처리하려고 씁니다.
  Future<String?> readClipboardText();
}

/// 이 글자가 인터넷 주소처럼 보이는지 확인합니다.
///
/// Windows 경로("C:\사진\a.jpg")를 주소로 착각하지 않도록 http/https만 봅니다.
///
/// 최상위 함수인 이유: 순수한 판별이라 클래스 없이 테스트할 수 있게 하려는 것입니다.
bool looksLikeUrl(String text) {
  final String trimmed = text.trim();
  return trimmed.startsWith('http://') || trimmed.startsWith('https://');
}

/// HTML 조각에서 이미지 주소(`<img src="...">`)를 뽑아냅니다. 없으면 null입니다.
///
/// ── 이게 왜 필요한가 (핀터레스트 문제) ──
/// 브라우저에서 이미지를 끌면 주소도 함께 넘어옵니다. 그런데 이미지가 링크에
/// 감싸여 있으면(핀터레스트가 그렇습니다) 그 주소는 **이미지가 아니라 링크가
/// 가리키는 페이지 주소**입니다. 그걸 내려받으면 이미지가 아니라 HTML이 옵니다.
///
/// 다행히 브라우저는 주소와 별개로 **끌어온 부분의 HTML 조각**도 함께 줍니다.
/// 거기에는 `<img src="진짜 이미지 주소">`가 들어 있어서, 링크에 감싸여 있어도
/// 실제 이미지를 찾을 수 있습니다.
///
/// ── 왜 정규식으로 대충 찾나 ──
/// 제대로 하려면 HTML 해석기를 붙여야 하지만, 여기서 다루는 건 완전한 문서가
/// 아니라 태그 몇 개짜리 조각입니다. 첫 번째 img의 src만 찾으면 되므로
/// 패키지를 하나 더 늘리는 것보다 이쪽이 낫습니다.
String? imageUrlFromHtml(String html) {
  // <img ... src="주소" ...> 에서 주소 부분만 꺼냅니다.
  // 따옴표는 큰따옴표와 작은따옴표 둘 다 받습니다.
  final RegExp imgTag = RegExp(
    '''<img[^>]+src\\s*=\\s*["']([^"']+)["']''',
    caseSensitive: false,
  );

  final RegExpMatch? match = imgTag.firstMatch(html);
  final String? found = match?.group(1);

  if (found == null) {
    return null;
  }

  // data: 로 시작하는 것은 주소가 아니라 데이터가 통째로 박힌 경우입니다.
  // 내려받을 대상이 아니므로 여기서는 다루지 않습니다.
  if (!looksLikeUrl(found)) {
    return null;
  }

  // HTML 안에서는 &가 &amp; 로 적혀 있습니다. 그대로 두면 주소가 깨집니다.
  return found.replaceAll('&amp;', '&');
}

/// 아무 글자 덩어리에서나 이미지처럼 보이는 주소를 찾아냅니다. 없으면 null입니다.
///
/// ── 왜 이런 게 필요한가 ──
/// 사이트가 자기만의 방식으로 데이터를 끼워 넣는 경우가 있습니다.
/// 핀터레스트가 그렇습니다. 표준 형식으로는 아무것도 안 주면서,
/// 자체 형식 안에는 이미지 주소를 넣어둡니다.
///
///   application/x-pinterest-closeup-image
///   {"pinId":"...","previewImageUrl":"https://i.pinimg.com/736x/....jpg",...}
///
/// 사이트마다 담는 이름이 다르므로(previewImageUrl, imageUrl, src...) 이름을
/// 찾지 않고 **주소처럼 생긴 글자**를 찾습니다. 그래야 핀터레스트뿐 아니라
/// 비슷하게 동작하는 다른 사이트에도 통합니다.
String? findImageUrlInText(String text) {
  // http(s)로 시작해서 이미지 확장자로 끝나는 부분을 찾습니다.
  // 확장자 뒤에 ?크기 같은 게 붙어 있어도 확장자까지만 가져옵니다.
  final RegExp imageUrl = RegExp(
    r'https?://[^\s"'
    r"'"
    r'\\<>]+?\.(?:jpg|jpeg|png|gif|webp|bmp)',
    caseSensitive: false,
  );

  return imageUrl.firstMatch(text)?.group(0);
}

/// 사이트 자체 형식의 원시 바이트를 주소를 찾을 수 있는 글자로 바꿉니다.
///
/// ── 0 바이트를 걸러내는 이유 (중요) ──
/// 자체 형식은 글자 하나에 2바이트를 쓰는 방식(UTF-16)으로 담겨 옵니다.
/// 영어와 숫자는 뒤쪽 바이트가 0이라, 그대로 읽으면 글자 사이에 0이 하나씩 낍니다.
///
///   실제 바이트: h \0 t \0 t \0 p \0 s \0
///   그대로 읽으면 글자가 끊겨서 "https"로 안 보입니다.
///
/// 0을 빼고 읽어야 "https://..." 가 됩니다.
/// 평범한 글자에는 0이 들어있지 않으므로 빼도 손해가 없습니다.
///
/// **처음에 이 처리를 빠뜨려서 핀터레스트 상세 페이지가 계속 실패했습니다.**
/// 진단 로그에서는 0이 공백처럼 보여서 눈치채기 어려웠습니다.
String textFromCustomData(List<int> bytes) {
  final List<int> withoutPadding =
      bytes.where((int byte) => byte != 0).toList();

  return utf8.decode(withoutPadding, allowMalformed: true);
}

/// 핀터레스트 주소를 원본 화질 주소로 바꿉니다. 해당 없으면 그대로 돌려줍니다.
///
/// ── 왜 필요한가 ──
/// 핀터레스트가 알려주는 주소는 화면에 보이던 크기의 축소본입니다.
///
///   https://i.pinimg.com/736x/1e/dc/ac/1edcac....jpg   →  36KB
///   https://i.pinimg.com/originals/1e/dc/ac/1edcac....jpg → 223KB
///
/// 주소에서 크기 부분(`736x`)만 `originals`로 바꾸면 원본이 나옵니다.
/// 레퍼런스로 모으는 것이 목적이니 원본을 받는 편이 낫습니다.
///
/// ── 주의 ──
/// 확장자는 바꾸면 안 됩니다. `.jpg`를 `.png`로 바꾸면 403이 납니다(확인함).
/// 그리고 원본이 없는 경우도 있어서, 실패하면 원래 주소로 되돌아가야 합니다.
/// 그 처리는 부르는 쪽에서 합니다.
String upgradePinterestUrl(String url) {
  // i.pinimg.com/<크기>/... 모양일 때만 손댑니다.
  // 크기 부분은 "236x", "736x", "564x" 처럼 숫자+x 입니다.
  final RegExp sizeSegment = RegExp(
    r'^(https?://i\.pinimg\.com/)\d+x/',
    caseSensitive: false,
  );

  final RegExpMatch? match = sizeSegment.firstMatch(url);
  if (match == null) {
    return url;
  }

  return url.replaceFirst(sizeSegment, '${match.group(1)}originals/');
}

/// 글자가 깨져서 온 HTML을 되돌립니다. 되돌릴 게 없으면 null입니다.
///
/// ── 무슨 일이 일어나는가 ──
/// 크롬이 넘겨주는 HTML 조각이 **UTF-8 바이트인데 UTF-16으로 읽혀서** 오는
/// 경우가 있습니다. (핀터레스트 피드에서 확인했습니다) 그러면 이렇게 보입니다.
///
///   받은 글자: 愼愠楲ⵡ慬敢㵬
///   원래 글자: <a aria-label=
///
/// 규칙이 정확합니다. 받은 글자 한 개가 원래 바이트 두 개를 담고 있습니다.
///
///   愼 = U+613C → 0x3C 0x61 → "<a"
///   愠 = U+6120 → 0x20 0x61 → " a"
///   楲 = U+6972 → 0x72 0x69 → "ri"
///
/// 그래서 글자를 다시 바이트로 풀어 UTF-8로 읽으면 원래 HTML이 나옵니다.
///
/// ── 왜 항상 하지 않고 실패했을 때만 하나 ──
/// 멀쩡하게 온 HTML에 이 처리를 하면 오히려 깨집니다.
/// 그래서 먼저 정상적으로 읽어보고, 이미지를 못 찾았을 때만 시도합니다.
String? repairMangledHtml(String text) {
  if (text.isEmpty) {
    return null;
  }

  final List<int> bytes = <int>[];
  for (final int unit in text.codeUnits) {
    // 아래쪽 바이트가 먼저입니다(리틀 엔디언).
    bytes.add(unit & 0xFF);
    bytes.add((unit >> 8) & 0xFF);
  }

  // allowMalformed: 중간에 이상한 바이트가 있어도 멈추지 않고 넘어갑니다.
  // 어차피 <img src="..."> 부분만 찾으면 되므로 완벽하지 않아도 괜찮습니다.
  final String decoded = utf8.decode(bytes, allowMalformed: true);

  return decoded.isEmpty ? null : decoded;
}
