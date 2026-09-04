// 파트를 지웠을 때 그 안의 레퍼런스가 어떻게 되는지 확인하는 테스트입니다.
//
// ── 왜 이것만 따로 파일을 뒀나 ──
// 파트는 다른 분류(폴더·카테고리·태그·프로젝트)와 **지울 때의 처리가 다릅니다.**
// 다른 것들은 연결을 끊거나 비우면 그만이지만, 파트는 비우면 안 됩니다.
//
// 사이드바가 **파트별로만** 레퍼런스를 보여주기 때문입니다. 어느 파트에도 안 속한
// 레퍼런스는 어느 파트를 눌러도 안 보입니다. "전체 레퍼런스"에는 남아 있지만,
// 사용자 눈에는 **사진이 사라진 것과 같습니다.** 데이터는 멀쩡한데 안 보이는,
// 원인을 찾기 가장 어려운 종류의 문제입니다.
//
// 실제로 파트를 만들 때(PR #16) 이 처리를 빠뜨렸다가 나중에 발견했습니다.
// 같은 실수를 다시 하지 않도록 여기에 못 박아둡니다.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/repositories/local_taxonomy_repository.dart';
import 'package:reference_archive_app/utils/id_generator.dart';

void main() {
  late AppDatabase db;
  late LocalReferenceRepository repository;
  late LocalTaxonomyRepository taxonomyRepository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalReferenceRepository(db);
    taxonomyRepository = LocalTaxonomyRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// 분류 항목을 하나 만들어 저장하고 그 번호를 돌려줍니다.
  Future<String> saveTaxonomy(TaxonomyKind kind, String name) async {
    final DateTime now = DateTime.now().toUtc();
    final TaxonomyItem item = TaxonomyItem(
      id: newId(),
      kind: kind,
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    await taxonomyRepository.save(item);
    return item.id;
  }

  /// 레퍼런스를 하나 저장하고 그 번호를 돌려줍니다.
  Future<String> saveReference({
    required String title,
    String? partId,
    String? folderId,
  }) async {
    final DateTime now = DateTime.now().toUtc();
    final ReferenceItem item = ReferenceItem(
      id: newId(),
      type: ReferenceType.image,
      title: title,
      partId: partId,
      folderId: folderId,
      fileName: '${newId()}.jpg',
      createdAt: now,
      updatedAt: now,
    );
    await repository.save(item);
    return item.id;
  }

  /// 저장소에서 이 레퍼런스를 다시 읽어옵니다.
  Future<ReferenceItem> reload(String id) async {
    final ReferenceItem? item = await repository.getById(id);
    expect(item, isNotNull, reason: '레퍼런스가 사라지면 안 됩니다');
    return item!;
  }

  group('파트를 지웠을 때', () {
    test('그 안의 레퍼런스가 기본 파트로 옮겨진다', () async {
      // ── 이게 이 파일의 핵심입니다 ──
      final String particleId = await saveTaxonomy(TaxonomyKind.part, '파티클');
      final String photoId = await saveReference(
        title: '불꽃',
        partId: particleId,
      );

      await taxonomyRepository.delete(particleId);

      final ReferenceItem photo = await reload(photoId);
      expect(photo.partId, defaultPartId);
    });

    test('어느 파트에도 안 속한 상태로 남지 않는다', () async {
      // 비워두면(null) 사이드바 어느 파트를 눌러도 안 보입니다.
      // 위 테스트와 같은 것을 보는 듯하지만, 이쪽이 **왜 안 되는지**를 못 박습니다.
      final String particleId = await saveTaxonomy(TaxonomyKind.part, '파티클');
      final String photoId = await saveReference(
        title: '불꽃',
        partId: particleId,
      );

      await taxonomyRepository.delete(particleId);

      final ReferenceItem photo = await reload(photoId);
      expect(photo.partId, isNotNull, reason: '파트가 비면 사이드바에서 영영 안 보입니다');
    });

    test('레퍼런스 자체는 지워지지 않는다', () async {
      final String particleId = await saveTaxonomy(TaxonomyKind.part, '파티클');
      await saveReference(title: '불꽃', partId: particleId);
      await saveReference(title: '연기', partId: particleId);

      await taxonomyRepository.delete(particleId);

      final List<ReferenceItem> items = await repository.getAll();
      expect(items.length, 2);
    });

    test('다른 파트에 있던 레퍼런스는 건드리지 않는다', () async {
      final String particleId = await saveTaxonomy(TaxonomyKind.part, '파티클');
      final String designId = await saveTaxonomy(TaxonomyKind.part, '디자인');

      final String designPhotoId = await saveReference(
        title: '포스터',
        partId: designId,
      );

      await taxonomyRepository.delete(particleId);

      final ReferenceItem designPhoto = await reload(designPhotoId);
      expect(designPhoto.partId, designId);
    });

    test('지운 파트는 목록에서 사라진다', () async {
      final String particleId = await saveTaxonomy(TaxonomyKind.part, '파티클');

      await taxonomyRepository.delete(particleId);

      final List<TaxonomyItem> parts = await taxonomyRepository.getAll(
        TaxonomyKind.part,
      );
      expect(parts.map((TaxonomyItem p) => p.id), isNot(contains(particleId)));
    });
  });

  group('기본 파트는 지울 수 없다', () {
    test('지우라고 해도 그대로 남는다', () async {
      // 기본 파트가 없어지면 다른 파트를 지울 때 옮겨갈 곳이 사라지고,
      // 새로 넣는 레퍼런스도 사라진 파트로 들어가게 됩니다.
      await taxonomyRepository.delete(defaultPartId);

      final List<TaxonomyItem> parts = await taxonomyRepository.getAll(
        TaxonomyKind.part,
      );
      expect(parts.length, 1);
      expect(parts.first.id, defaultPartId);
    });

    test('그 안의 레퍼런스도 그대로 남는다', () async {
      final String photoId = await saveReference(
        title: '노을',
        partId: defaultPartId,
      );

      await taxonomyRepository.delete(defaultPartId);

      final ReferenceItem photo = await reload(photoId);
      expect(photo.partId, defaultPartId);
    });

    test('이름은 바꿀 수 있다', () async {
      // 지우기만 막습니다. 이름은 바꿔도 번호가 그대로라 연결이 안 끊깁니다.
      final List<TaxonomyItem> before = await taxonomyRepository.getAll(
        TaxonomyKind.part,
      );

      await taxonomyRepository.save(before.first.copyWith(name: '디자인'));

      final List<TaxonomyItem> after = await taxonomyRepository.getAll(
        TaxonomyKind.part,
      );
      expect(after.first.name, '디자인');
      expect(after.first.id, defaultPartId);
    });
  });

  group('파트를 쓰는 레퍼런스 개수 세기', () {
    test('파트에 든 레퍼런스를 센다', () async {
      // 이걸 빠뜨리면 지우기 확인 창이 "쓰는 레퍼런스는 없습니다"라고 하고,
      // 사용자는 아무 일도 안 일어날 줄 알고 지웁니다.
      final String particleId = await saveTaxonomy(TaxonomyKind.part, '파티클');
      await saveReference(title: '불꽃', partId: particleId);
      await saveReference(title: '연기', partId: particleId);

      expect(await taxonomyRepository.countReferencesUsing(particleId), 2);
    });

    test('다른 파트에 든 것은 세지 않는다', () async {
      final String particleId = await saveTaxonomy(TaxonomyKind.part, '파티클');
      final String designId = await saveTaxonomy(TaxonomyKind.part, '디자인');

      await saveReference(title: '불꽃', partId: particleId);
      await saveReference(title: '포스터', partId: designId);

      expect(await taxonomyRepository.countReferencesUsing(particleId), 1);
    });

    test('지운 레퍼런스는 세지 않는다', () async {
      final String particleId = await saveTaxonomy(TaxonomyKind.part, '파티클');
      final String photoId = await saveReference(
        title: '불꽃',
        partId: particleId,
      );
      await repository.delete(photoId);

      expect(await taxonomyRepository.countReferencesUsing(particleId), 0);
    });
  });

  group('다른 분류는 예전 그대로다 (회귀 확인)', () {
    test('폴더를 지우면 폴더 없음이 된다 (기본 폴더 같은 것은 없음)', () async {
      // 파트만 다르게 다룹니다. 폴더는 비우는 것이 맞습니다 —
      // "폴더 없음"은 정상적인 상태이고 목록에도 그대로 보입니다.
      final String folderId = await saveTaxonomy(TaxonomyKind.folder, '인물');
      final String photoId = await saveReference(
        title: '초상',
        folderId: folderId,
      );

      await taxonomyRepository.delete(folderId);

      final ReferenceItem photo = await reload(photoId);
      expect(photo.folderId, isNull);
    });

    test('폴더를 지워도 파트는 그대로다', () async {
      final String folderId = await saveTaxonomy(TaxonomyKind.folder, '인물');
      final String particleId = await saveTaxonomy(TaxonomyKind.part, '파티클');
      final String photoId = await saveReference(
        title: '초상',
        folderId: folderId,
        partId: particleId,
      );

      await taxonomyRepository.delete(folderId);

      final ReferenceItem photo = await reload(photoId);
      expect(photo.partId, particleId);
    });
  });
}
