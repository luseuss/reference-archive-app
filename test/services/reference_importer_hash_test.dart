// 레퍼런스를 새로 들여올 때 dHash가 함께 계산되어 저장되는지 확인하는
// 테스트입니다. 이미 있는 화면 테스트들(home_youtube_test.dart 등)이
// ReferenceImporter를 화면을 통해 간접적으로 쓰고 있어서, 여기서는 이번에
// 추가한 "저장할 때 pHash를 계산한다" 동작만 집중해서 봅니다.

import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/services/image_hash.dart';
import 'package:reference_archive_app/services/reference_importer.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';

import '../fakes/fake_image_source.dart';
import '../fakes/fake_image_storage.dart';
import '../fakes/fake_youtube_info_source.dart';

void main() {
  late AppDatabase db;
  late LocalReferenceRepository repository;
  late FakeImageSource imageSource;
  late FakeImageStorage imageStorage;
  late FakeYoutubeInfoSource youtubeInfoSource;
  late ReferenceImporter importer;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalReferenceRepository(db);
    imageSource = FakeImageSource();
    imageStorage = FakeImageStorage();
    youtubeInfoSource = FakeYoutubeInfoSource();
    importer = ReferenceImporter(
      repository: repository,
      imageStorage: imageStorage,
      imageSource: imageSource,
      youtubeInfoSource: youtubeInfoSource,
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// 진짜 이미지 데이터(PNG)를 만듭니다. dHashFromBytes가 계산할 수
  /// 있어야 하므로 [1,2,3] 같은 가짜 바이트가 아니라 실제 그림이어야 합니다.
  Uint8List makeRealImageBytes() {
    final img.Image image = img.Image(width: 20, height: 20);
    for (int y = 0; y < 20; y++) {
      for (int x = 0; x < 20; x++) {
        image.setPixelRgb(x, y, x < 10 ? 0 : 255, 100, 50);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  test('클립보드에서 붙여넣은 이미지는 pHash가 계산되어 저장된다', () async {
    imageSource.hasClipboardImage = true;
    imageSource.bytes = makeRealImageBytes();

    await importer.importFromClipboard(partId: defaultPartId);

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.length, 1);
    expect(items.first.pHash, dHashFromBytes(imageSource.bytes));
  });

  test('유튜브 썸네일도 pHash가 계산되어 저장된다', () async {
    // hasThumbnail은 기본값(true)을 그대로 둡니다 — thumbnailBytes 필드는
    // Uint8List(널 불가)라서 값만 실제 이미지로 바꿔주면 됩니다.
    youtubeInfoSource.thumbnailBytes = makeRealImageBytes();

    await importer.saveYoutube('dQw4w9WgXcQ', partId: defaultPartId);

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.length, 1);
    expect(items.first.pHash, dHashFromBytes(youtubeInfoSource.thumbnailBytes));
  });

  test('그림이 아닌 데이터를 붙여넣어도 저장은 되고 pHash만 비어있다', () async {
    imageSource.hasClipboardImage = true;
    imageSource.bytes = Uint8List.fromList(<int>[1, 2, 3]);

    // FakeImageStorage.saveImage는 실제로 디코드하지 않아서 그대로
    // "저장된 척"하지만, dHashFromBytes는 진짜로 디코드를 시도하다
    // 실패해서 null을 돌려줘야 합니다.
    await importer.importFromClipboard(partId: defaultPartId);

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.length, 1);
    expect(items.first.pHash, isNull);
  });
}
