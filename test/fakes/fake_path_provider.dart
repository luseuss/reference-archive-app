// path_provider(앱 데이터 폴더가 어디인지 운영체제에 물어보는 플러그인)
// 대신 정해둔 임시 폴더를 알려주는 가짜입니다.
//
// ── 왜 필요한가 ──
// 실제 구현은 운영체제에 물어봐야 하는데, 테스트 환경에는 대답해줄
// 상대가 없어서 영원히 기다리게 됩니다. 이 가짜를 끼워 넣으면 실제
// 파일 시스템(진짜 임시 폴더)은 그대로 쓰면서도, 컴퓨터의 진짜 앱
// 데이터 폴더는 건드리지 않는 테스트를 만들 수 있습니다.
//
// local_image_storage_test.dart와 archive_backup_service_test.dart가
// 함께 씁니다 — 둘 다 "앱 데이터 폴더 안의 실제 파일"을 다루는 코드를
// 확인해야 하기 때문입니다.

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// path_provider 대신 정해둔 폴더를 알려주는 가짜입니다.
class FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  FakePathProvider(this.rootPath);

  final String rootPath;

  @override
  Future<String?> getApplicationSupportPath() async => rootPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => rootPath;

  @override
  Future<String?> getTemporaryPath() async => rootPath;
}
