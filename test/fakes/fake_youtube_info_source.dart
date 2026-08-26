// 테스트에서 진짜 유튜브 대신 쓰는 가짜 구현입니다.
//
// ── 왜 필요한가 ──
// 진짜 구현(NetworkYoutubeInfoSource)은 유튜브 서버에 접속합니다.
// 테스트에서 그대로 쓰면 느리고, 인터넷이 없으면 실패하고, 유튜브 사정에 따라
// 결과가 달라집니다. 이 가짜는 미리 정해둔 답을 즉시 돌려줍니다.
//
// 덕분에 "제목을 못 가져왔을 때", "썸네일이 없을 때" 같은 상황도
// 마음대로 만들어 시험할 수 있습니다.

import 'dart:typed_data';

import 'package:reference_archive_app/services/youtube_info_source.dart';

/// 테스트용 가짜 유튜브 정보 가져오기입니다.
class FakeYoutubeInfoSource implements YoutubeInfoSource {
  /// 돌려줄 제목입니다. 빈 글자로 두면 "제목을 못 가져온" 상황이 됩니다.
  String title = '가짜 영상 제목';

  /// 썸네일을 돌려줄지 여부입니다.
  ///
  /// false로 두면 "썸네일이 없는 영상"을 흉내냅니다.
  /// (오래된 영상이나 인터넷이 끊긴 경우)
  bool hasThumbnail = true;

  /// 썸네일로 돌려줄 데이터입니다. 내용은 상관없습니다.
  Uint8List thumbnailBytes = Uint8List.fromList(<int>[9, 8, 7]);

  /// fetch가 어떤 영상 번호로 불렸는지 기록합니다. 테스트에서 확인용으로 씁니다.
  final List<String> requestedVideoIds = <String>[];

  @override
  Future<YoutubeVideoInfo> fetch(String videoId) async {
    requestedVideoIds.add(videoId);

    return YoutubeVideoInfo(
      videoId: videoId,
      title: title,
      thumbnailBytes: hasThumbnail ? thumbnailBytes : null,
    );
  }
}
