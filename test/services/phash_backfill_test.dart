// pHash가 없는 레퍼런스를 채우는 백필 로직을 확인하는 테스트입니다.
//
// 진짜 이미지 파일이 필요해서(dHashFromBytes가 실제로 읽어야 합니다)
// migration 테스트들처럼 임시 폴더에 진짜 파일을 만들어 씁니다.

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/services/image_storage.dart';
import 'package:reference_archive_app/services/phash_backfill.dart';
import 'package:reference_archive_app/utils/id_generator.dart';

/// 실제 파일 시스템의 한 폴더를 가리키는 간단한 이미지 저장소입니다.
/// saveImage/deleteImageFile은 이 테스트에서 안 씁니다.
class _DiskImageStorage implements ImageStorage {
  _DiskImageStorage(this.directory);

  final Directory directory;

  @override
  Future<String> getFullPath(String fileName) async {
    return '${directory.path}/$fileName';
  }

  @override
  Future<String?> saveImage(Uint8List originalBytes) async {
    throw UnimplementedError('이 테스트에서는 안 씁니다');
  }

  @override
  Future<void> deleteImageFile(String fileName) async {}
}

void main() {
  late AppDatabase db;
  late LocalReferenceRepository repository;
  late Directory tempDir;
  late _DiskImageStorage imageStorage;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalReferenceRepository(db);
    tempDir = await Directory.systemTemp.createTemp('phash_backfill_test');
    imageStorage = _DiskImageStorage(tempDir);
  });

  tearDown(() async {
    await db.close();
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  /// 임시 폴더 안에 진짜 이미지 파일을 하나 만들어 파일 이름을 돌려줍니다.
  Future<String> writeTestImage(String fileName) async {
    final img.Image image = img.Image(width: 20, height: 20);
    for (int y = 0; y < 20; y++) {
      for (int x = 0; x < 20; x++) {
        image.setPixelRgb(x, y, x < 10 ? 0 : 255, 0, 0);
      }
    }
    final Uint8List bytes = Uint8List.fromList(img.encodePng(image));
    await File('${tempDir.path}/$fileName').writeAsBytes(bytes);
    return fileName;
  }

  /// 테스트용 레퍼런스를 저장하고 돌려줍니다.
  Future<ReferenceItem> saveReference({String? fileName, String? pHash}) async {
    final DateTime now = DateTime.now().toUtc();
    final ReferenceItem item = ReferenceItem(
      id: newId(),
      type: ReferenceType.image,
      fileName: fileName,
      pHash: pHash,
      createdAt: now,
      updatedAt: now,
    );
    await repository.save(item);
    return item;
  }

  test('pHash가 없는 레퍼런스를 채운다', () async {
    final String fileName = await writeTestImage('a.png');
    await saveReference(fileName: fileName);

    await backfillMissingPHashes(repository: repository, imageStorage: imageStorage);

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.first.pHash, isNotNull);
    expect(items.first.pHash!.length, 64);
  });

  test('이미 pHash가 있으면 안 건드린다', () async {
    const String existing = 'already-there';
    final String fileName = await writeTestImage('b.png');
    await saveReference(fileName: fileName, pHash: existing);

    await backfillMissingPHashes(repository: repository, imageStorage: imageStorage);

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.first.pHash, existing);
  });

  test('사진 파일이 없는 레퍼런스(유튜브 등)는 조용히 건너뛴다', () async {
    await saveReference(fileName: null);

    // 오류 없이 끝나야 합니다.
    await backfillMissingPHashes(repository: repository, imageStorage: imageStorage);

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.first.pHash, isNull);
  });

  test('파일이 실제로 없으면(깨진 경로 등) 조용히 건너뛴다', () async {
    await saveReference(fileName: 'no-such-file.png');

    await backfillMissingPHashes(repository: repository, imageStorage: imageStorage);

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.first.pHash, isNull);
  });

  test('updatedAt을 건드리지 않는다', () async {
    final String fileName = await writeTestImage('updated-at.png');
    final ReferenceItem original = await saveReference(fileName: fileName);

    final ReferenceItem before = (await repository.getById(original.id))!;

    // 실제 기기 동작을 흉내내기 위해 아주 살짝 시간을 흘려보냅니다.
    // (updatedAt이 바뀐다면 이 시점보다 뒤 시각으로 찍힐 것입니다)
    await Future<void>.delayed(const Duration(milliseconds: 5));

    await backfillMissingPHashes(repository: repository, imageStorage: imageStorage);

    final ReferenceItem after = (await repository.getById(original.id))!;

    expect(after.pHash, isNotNull);
    // 시간이 "가까운" 정도가 아니라, 아예 손대지 않아 완전히 같아야 합니다.
    expect(after.updatedAt, before.updatedAt);
  });

  test('여러 장을 한 번에 채운다', () async {
    final String fileA = await writeTestImage('a.png');
    final String fileB = await writeTestImage('c.png');
    await saveReference(fileName: fileA);
    await saveReference(fileName: fileB);

    await backfillMissingPHashes(repository: repository, imageStorage: imageStorage);

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.every((ReferenceItem i) => i.pHash != null), isTrue);
  });
}
