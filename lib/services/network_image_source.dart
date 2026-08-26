// ImageSource 약속을 실제 인터넷·클립보드로 지키는 구현입니다.
//
// 네트워크와 클립보드를 만지는 코드는 이 파일 안에만 있습니다.
// 화면은 ImageSource 약속만 알면 되고, 테스트는 가짜로 갈아끼웁니다.

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pasteboard/pasteboard.dart';

import 'image_source.dart';

/// 내려받을 이미지의 최대 크기입니다. (20MB)
///
/// 제한을 두는 이유: 주소가 이미지가 아니라 큰 동영상이나 압축파일을 가리킬 수도
/// 있습니다. 그런 걸 통째로 받으면 앱이 한참 멈추거나 메모리가 터집니다.
const int maxDownloadBytes = 20 * 1024 * 1024;

/// 내려받기를 포기하는 시간입니다.
///
/// 응답이 없는 서버를 무한정 기다리면 사용자는 앱이 멈춘 줄 압니다.
const Duration downloadTimeout = Duration(seconds: 20);

/// 인터넷과 클립보드에서 이미지를 가져오는 구현체입니다.
class NetworkImageSource implements ImageSource {
  NetworkImageSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// 인터넷 주소에서 이미지를 내려받습니다.
  ///
  /// 핀터레스트 주소면 **원본 화질 주소를 먼저 시도**하고,
  /// 그게 안 되면 원래 주소로 되돌아갑니다.
  /// (핀터레스트가 알려주는 주소는 화면에 보이던 크기의 축소본입니다)
  @override
  Future<ImageFetchResult> fetchFromUrl(String url) async {
    final String upgraded = upgradePinterestUrl(url);

    if (upgraded != url) {
      final ImageFetchResult result = await _fetch(upgraded);
      if (result.isSuccess) {
        return result;
      }
      // 원본이 없는 경우도 있습니다. 그때는 조용히 원래 주소로 돌아갑니다.
      debugPrint('원본 화질 주소 실패, 원래 주소로 다시 시도: $url');
    }

    return _fetch(url);
  }

  /// 주소 하나를 실제로 내려받습니다.
  Future<ImageFetchResult> _fetch(String url) async {
    final Uri? uri = _parseImageUrl(url);
    if (uri == null) {
      return const ImageFetchResult.failure(
        '이미지 주소가 아닙니다. http로 시작하는 주소를 넣어주세요.',
      );
    }

    try {
      final http.Response response = await _client
          .get(uri)
          .timeout(downloadTimeout);

      if (response.statusCode != 200) {
        // 상태 코드를 그대로 보여줘도 사용자는 무슨 뜻인지 모릅니다.
        // 흔한 경우는 풀어서 설명하고, 나머지는 뭉뚱그립니다.
        if (response.statusCode == 404) {
          return const ImageFetchResult.failure('그 주소에 이미지가 없습니다.');
        }
        if (response.statusCode == 403) {
          return const ImageFetchResult.failure(
            '그 사이트가 이미지 가져오기를 막고 있습니다. '
            '이미지를 복사해서 붙여넣어 보세요.',
          );
        }
        return ImageFetchResult.failure(
          '이미지를 가져오지 못했습니다. (오류 ${response.statusCode})',
        );
      }

      if (response.bodyBytes.length > maxDownloadBytes) {
        return const ImageFetchResult.failure('파일이 너무 큽니다. (20MB 넘음)');
      }

      if (response.bodyBytes.isEmpty) {
        return const ImageFetchResult.failure('빈 파일입니다.');
      }

      return ImageFetchResult.success(
        response.bodyBytes,
        suggestedTitle: titleFromUrl(uri),
      );
    } catch (error) {
      // 인터넷이 끊겼거나, 주소가 없거나, 너무 오래 걸린 경우입니다.
      // 원인을 정확히 가려내기 어렵고 사용자가 할 일은 어차피 같으므로 묶어서 안내합니다.
      debugPrint('이미지 내려받기 실패 ($url): $error');
      return const ImageFetchResult.failure(
        '이미지를 가져오지 못했습니다. 주소와 인터넷 연결을 확인해주세요.',
      );
    }
  }

  /// 클립보드에 들어있는 이미지를 가져옵니다.
  @override
  Future<ImageFetchResult> fetchFromClipboard() async {
    try {
      final Uint8List? bytes = await Pasteboard.image;

      if (bytes == null || bytes.isEmpty) {
        return const ImageFetchResult.failure('클립보드에 이미지가 없습니다.');
      }

      return ImageFetchResult.success(bytes);
    } catch (error) {
      debugPrint('클립보드 읽기 실패: $error');
      return const ImageFetchResult.failure('클립보드를 읽지 못했습니다.');
    }
  }

  /// 클립보드에 들어있는 글자를 가져옵니다.
  @override
  Future<String?> readClipboardText() async {
    try {
      return await Pasteboard.text;
    } catch (error) {
      debugPrint('클립보드 글자 읽기 실패: $error');
      return null;
    }
  }

  /// 글자를 이미지 주소로 해석합니다. 주소가 아니면 null을 돌려줍니다.
  ///
  /// http/https만 받습니다. file: 같은 다른 형식을 그대로 받아들이면
  /// 엉뚱한 곳을 읽으려 할 수 있습니다.
  Uri? _parseImageUrl(String url) {
    final Uri? uri = Uri.tryParse(url.trim());

    if (uri == null || !uri.hasScheme) {
      return null;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }
    if (uri.host.isEmpty) {
      return null;
    }
    return uri;
  }
}

/// 주소에서 제목으로 쓸 만한 이름을 뽑아냅니다.
///
/// ".../photos/sunset-view.jpg?w=800" → "sunset-view"
/// 뽑아낼 게 없으면 null을 돌려줍니다. (제목 없이 저장됩니다)
///
/// 최상위 함수인 이유: 순수한 계산이라 클래스 없이 테스트할 수 있게 하려는 것입니다.
String? titleFromUrl(Uri uri) {
  if (uri.pathSegments.isEmpty) {
    return null;
  }

  // 주소 맨 끝 조각을 씁니다.
  //
  // pathSegments는 두 가지를 이미 처리해서 줍니다.
  //   - 쿼리(?w=800)를 떼어냄
  //   - 퍼센트 인코딩을 풀어줌 ("%EB%85%B8..." → "노을")
  //
  // 그래서 여기서 Uri.decodeComponent()를 또 부르면 안 됩니다.
  // 이미 풀린 글자를 다시 풀려다 "Illegal percent encoding" 오류가 납니다.
  final String lastSegment = uri.pathSegments.last;
  if (lastSegment.isEmpty) {
    return null;
  }

  // 확장자를 뗍니다. ("sunset-view.jpg" → "sunset-view")
  final int dotIndex = lastSegment.lastIndexOf('.');
  final String withoutExtension = dotIndex > 0
      ? lastSegment.substring(0, dotIndex)
      : lastSegment;

  final String trimmed = withoutExtension.trim();

  return trimmed.isEmpty ? null : trimmed;
}
