// 테스트에서 진짜 파일 저장 대신 쓰는 가짜 구현입니다.
//
// ── 왜 필요한가 ──
// 진짜 구현(LocalImageStorage)은 "앱 데이터 폴더가 어디인지"를 운영체제에
// 물어봅니다. 그런데 그건 플러그인이라, 테스트 환경에는 대답해줄 상대가 없어서
// **영원히 기다리게 됩니다.** 테스트가 멈춰버립니다.
//
// 이 가짜는 파일을 만들지 않고 즉시 대답합니다. 덕분에 화면 테스트가
// 파일 시스템과 상관없이 빠르고 안정적으로 돌아갑니다.
//
// 이게 화면이 구현체가 아니라 약속(ImageStorage)에 의존하게 만든 이유입니다.

import 'dart:typed_data';

import 'package:reference_archive_app/services/image_storage.dart';

/// 테스트용 가짜 이미지 저장소입니다. 실제로 파일을 만들지 않습니다.
class FakeImageStorage implements ImageStorage {
  /// saveImage()가 몇 번 불렸는지 세어둡니다. 테스트에서 확인용으로 씁니다.
  int saveCallCount = 0;

  /// deleteImageFile()로 지워진 파일 이름들입니다.
  final List<String> deletedFileNames = <String>[];

  /// saveImage()가 null을 돌려주게 할지 여부입니다.
  /// "그림이 아닌 파일을 골랐을 때" 상황을 흉내낼 때 씁니다.
  bool failOnSave = false;

  /// 파일이 있는 것처럼 가짜 경로를 만들어 돌려줍니다.
  @override
  Future<String> getFullPath(String fileName) async {
    return '/fake/images/$fileName';
  }

  /// 저장한 척하고 가짜 파일 이름을 돌려줍니다.
  @override
  Future<String?> saveImage(Uint8List originalBytes) async {
    saveCallCount++;
    if (failOnSave) {
      return null;
    }
    return 'fake-$saveCallCount.jpg';
  }

  /// 지운 파일 이름만 기록해둡니다.
  @override
  Future<void> deleteImageFile(String fileName) async {
    deletedFileNames.add(fileName);
  }
}
