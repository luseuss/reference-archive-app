// 실제로 파일을 저장하는 LocalImageStorage가 제대로 동작하는지 확인하는 테스트입니다.
//
// ── 어떻게 테스트하나 ──
// LocalImageStorage는 "앱 데이터 폴더가 어디냐"를 운영체제에 물어봅니다(path_provider).
// 테스트 환경에는 대답해줄 상대가 없으므로, 그 자리에 **임시 폴더를 알려주는 가짜**를
// 끼워 넣습니다. 그러면 나머지 코드(크기 줄이기, 파일 쓰기, 경로 만들기)는
// 진짜 그대로 돌아가면서도 테스트가 안전하게 끝납니다.
//
// 테스트가 끝나면 임시 폴더를 통째로 지우므로 컴퓨터에 흔적이 남지 않습니다.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reference_archive_app/services/image_resizer.dart';
import 'package:reference_archive_app/services/local_image_storage.dart';

/// path_provider 대신 임시 폴더를 알려주는 가짜입니다.
class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePathProvider(this.rootPath);

  final String rootPath;

  @override
  Future<String?> getApplicationSupportPath() async => rootPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => rootPath;

  @override
  Future<String?> getTemporaryPath() async => rootPath;
}

void main() {
  // 플러그인을 흉내내려면 테스트 환경이 먼저 준비되어야 합니다.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalImageStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ref_archive_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    storage = LocalImageStorage();
  });

  tearDown(() async {
    // 테스트가 남긴 파일을 전부 정리합니다.
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// 지정한 크기의 테스트용 PNG 이미지를 만들어 돌려줍니다.
  Uint8List makeTestPng(int width, int height) {
    final img.Image image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(120, 160, 140));
    return Uint8List.fromList(img.encodePng(image));
  }

  test('이미지를 저장하면 실제 파일이 만들어진다', () async {
    final String? fileName = await storage.saveImage(makeTestPng(2000, 1000));

    expect(fileName, isNotNull);

    final String fullPath = await storage.getFullPath(fileName!);
    expect(await File(fullPath).exists(), isTrue);
  });

  test('저장된 파일 이름은 .jpg로 끝난다', () async {
    final String? fileName = await storage.saveImage(makeTestPng(800, 600));

    expect(fileName, isNotNull);
    expect(fileName!.endsWith('.jpg'), isTrue);
  });

  test('저장할 때 크기가 실제로 줄어든다', () async {
    final String? fileName = await storage.saveImage(makeTestPng(3000, 1500));

    expect(fileName, isNotNull);

    final String fullPath = await storage.getFullPath(fileName!);
    final img.Image? saved = img.decodeImage(await File(fullPath).readAsBytes());

    expect(saved, isNotNull);
    expect(saved!.width, maxImageLongEdge);
    expect(saved.height, maxImageLongEdge ~/ 2);
  });

  test('같은 이미지를 두 번 저장해도 파일 이름이 겹치지 않는다', () async {
    // 이름이 겹치면 나중에 넣은 사진이 앞의 사진을 덮어써서 그림이 사라집니다.
    final Uint8List bytes = makeTestPng(800, 600);

    final String? first = await storage.saveImage(bytes);
    final String? second = await storage.saveImage(bytes);

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(first, isNot(second));
  });

  test('그림 파일이 아니면 null을 돌려주고 파일도 안 만든다', () async {
    final Uint8List notAnImage = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);

    final String? fileName = await storage.saveImage(notAnImage);

    expect(fileName, isNull);

    // 쓰레기 파일이 폴더에 남지 않았는지 확인합니다.
    final Directory imagesDir = Directory('${tempDir.path}${Platform.pathSeparator}images');
    if (await imagesDir.exists()) {
      expect(await imagesDir.list().isEmpty, isTrue);
    }
  });

  test('저장한 파일을 지울 수 있다', () async {
    final String? fileName = await storage.saveImage(makeTestPng(800, 600));
    expect(fileName, isNotNull);

    final String fullPath = await storage.getFullPath(fileName!);
    expect(await File(fullPath).exists(), isTrue);

    await storage.deleteImageFile(fileName);

    expect(await File(fullPath).exists(), isFalse);
  });

  test('없는 파일을 지워도 오류가 나지 않는다', () async {
    // 이미 지워진 파일을 다시 지우려 할 때 앱이 죽으면 안 됩니다.
    await storage.deleteImageFile('없는-파일.jpg');
  });

  test('이미지는 앱 데이터 폴더 안 images 폴더에 저장된다', () async {
    final String? fileName = await storage.saveImage(makeTestPng(800, 600));
    final String fullPath = await storage.getFullPath(fileName!);

    // 사용자 문서 폴더를 어지럽히지 않고 정해진 자리에 모이는지 확인합니다.
    expect(fullPath.contains('images'), isTrue);
    expect(fullPath.startsWith(tempDir.path), isTrue);
  });
}
