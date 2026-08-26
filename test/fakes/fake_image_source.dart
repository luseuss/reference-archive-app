// 테스트에서 진짜 인터넷·클립보드 대신 쓰는 가짜 구현입니다.
//
// ── 왜 필요한가 ──
// 진짜 구현(NetworkImageSource)은 인터넷에 접속하고 운영체제의 클립보드를 읽습니다.
// 테스트에서 그대로 쓰면 느리고, 인터넷이 없으면 실패하고, 테스트를 돌리는 사람의
// 클립보드에 뭐가 들어있느냐에 따라 결과가 달라집니다.
//
// 이 가짜는 미리 정해둔 답을 즉시 돌려줍니다.
// 덕분에 "클립보드가 비었을 때", "사이트가 막았을 때" 같은 상황도 마음대로 시험할 수 있습니다.

import 'dart:typed_data';

import 'package:reference_archive_app/services/image_source.dart';

/// 테스트용 가짜 이미지 가져오기입니다.
class FakeImageSource implements ImageSource {
  /// 클립보드에 이미지가 있는 것으로 칠지 여부입니다.
  bool hasClipboardImage = false;

  /// 클립보드에 들어있는 것으로 칠 글자입니다. (이미지 주소 붙여넣기 시험용)
  String? clipboardText;

  /// fetchFromUrl이 성공을 돌려줄지 여부입니다.
  bool succeedOnUrl = true;

  /// fetchFromUrl이 어떤 주소로 불렸는지 기록합니다. 테스트에서 확인용으로 씁니다.
  String? requestedUrl;

  /// 성공했을 때 돌려줄 이미지 데이터입니다.
  Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3]);

  @override
  Future<ImageFetchResult> fetchFromUrl(String url) async {
    requestedUrl = url;
    if (!succeedOnUrl) {
      return const ImageFetchResult.failure('내려받지 못했습니다.');
    }
    return ImageFetchResult.success(bytes, suggestedTitle: '내려받은것');
  }

  @override
  Future<ImageFetchResult> fetchFromClipboard() async {
    if (!hasClipboardImage) {
      return const ImageFetchResult.failure('클립보드에 이미지가 없습니다.');
    }
    return ImageFetchResult.success(bytes);
  }

  @override
  Future<String?> readClipboardText() async => clipboardText;
}
