// 여러 건을 한꺼번에 처리하는 저장소 기능을 확인하는 테스트입니다.
//
// 화면에서 여러 장을 골라 "폴더 이동 / 태그 추가 / 삭제"를 할 때 쓰는
// moveManyToFolder, addTaxonomyItemToMany, deleteMany 셋을 봅니다.
//
// 특히 신경 쓴 것은 **이미 태그가 붙어있는 레퍼런스에 다시 붙이지 않는 것**입니다.
// 다시 붙이면 붙인 시각이 새로 찍혀서, 나중에 기기 간 동기화가 바뀐 게 없는데도
// 바뀌었다고 판단하게 됩니다.

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

  /// 테스트용 레퍼런스를 하나 저장하고 그 id를 돌려줍니다.
  Future<String> saveReference({
    String title = '사진',
    String? folderId,
    List<String> tagIds = const <String>[],
  }) async {
    final DateTime now = DateTime.now().toUtc();
    final ReferenceItem item = ReferenceItem(
      id: newId(),
      type: ReferenceType.image,
      title: title,
      folderId: folderId,
      tagIds: tagIds,
      createdAt: now,
      updatedAt: now,
    );
    await repository.save(item);
    return item.id;
  }

  /// 테스트용 분류 항목을 하나 만들고 그 id를 돌려줍니다.
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

  /// 연결 표에서 "언제 붙였는지"를 직접 읽어옵니다.
  ///
  /// 저장소 바깥으로는 안 나오는 값이라 테스트에서만 이렇게 직접 봅니다.
  Future<DateTime> readLinkCreatedAt(
    String referenceId,
    String taxonomyItemId,
  ) async {
    // where를 두 번 부르면 drift가 두 조건을 AND로 묶어줍니다.
    // (조건을 `&`로 잇는 방법도 있지만, 그러려면 이 파일에 drift를 직접
    //  들여와야 합니다. 테스트 파일은 앱 코드만 보게 두는 편이 낫습니다.)
    final ReferenceTaxonomyLinkRow row =
        await (db.select(db.referenceTaxonomyLinks)
              ..where(
                ($ReferenceTaxonomyLinksTable t) =>
                    t.referenceId.equals(referenceId),
              )
              ..where(
                ($ReferenceTaxonomyLinksTable t) =>
                    t.taxonomyItemId.equals(taxonomyItemId),
              ))
            .getSingle();

    return row.createdAt;
  }

  group('moveManyToFolder', () {
    test('고른 것들만 폴더로 옮긴다', () async {
      final String folderId = await saveTaxonomy(TaxonomyKind.folder, '인물');
      final String movedA = await saveReference(title: 'A');
      final String movedB = await saveReference(title: 'B');
      final String untouched = await saveReference(title: 'C');

      await repository.moveManyToFolder(<String>[movedA, movedB], folderId);

      expect((await repository.getById(movedA))!.folderId, folderId);
      expect((await repository.getById(movedB))!.folderId, folderId);
      // 안 고른 것은 그대로여야 합니다.
      expect((await repository.getById(untouched))!.folderId, isNull);
    });

    test('null을 넘기면 폴더에서 빼낸다', () async {
      // copyWith로는 값을 null로 만들 수 없어서 이 경로가 따로 필요합니다.
      final String folderId = await saveTaxonomy(TaxonomyKind.folder, '인물');
      final String id = await saveReference(folderId: folderId);

      await repository.moveManyToFolder(<String>[id], null);

      expect((await repository.getById(id))!.folderId, isNull);
    });

    test('옮기면 updatedAt이 갱신된다', () async {
      final String folderId = await saveTaxonomy(TaxonomyKind.folder, '인물');
      final String id = await saveReference();

      final DateTime before = (await repository.getById(id))!.updatedAt;

      // 시각 차이가 나도록 아주 잠깐 기다립니다.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repository.moveManyToFolder(<String>[id], folderId);

      final DateTime after = (await repository.getById(id))!.updatedAt;
      expect(after.isAfter(before), isTrue);
      // 시각은 언제나 UTC여야 합니다. (CLAUDE.md 설계 원칙 2)
      expect(after.isUtc, isTrue);
    });

    test('빈 목록을 넘겨도 아무 일도 일어나지 않는다', () async {
      final String id = await saveReference();

      await repository.moveManyToFolder(<String>[], 'some-folder');

      expect((await repository.getById(id))!.folderId, isNull);
    });
  });

  group('addTaxonomyItemToMany', () {
    test('고른 것들에 태그를 붙인다', () async {
      final String tagId = await saveTaxonomy(TaxonomyKind.tag, '노을');
      final String taggedA = await saveReference(title: 'A');
      final String taggedB = await saveReference(title: 'B');
      final String untouched = await saveReference(title: 'C');

      await repository.addTaxonomyItemToMany(<String>[taggedA, taggedB], tagId);

      expect((await repository.getById(taggedA))!.tagIds, <String>[tagId]);
      expect((await repository.getById(taggedB))!.tagIds, <String>[tagId]);
      expect((await repository.getById(untouched))!.tagIds, isEmpty);
    });

    test('원래 있던 태그는 그대로 두고 더한다', () async {
      // "통째로 갈아치우기"가 아니라 "더하기"인지 확인합니다.
      final String oldTag = await saveTaxonomy(TaxonomyKind.tag, '인물');
      final String newTag = await saveTaxonomy(TaxonomyKind.tag, '노을');
      final String id = await saveReference(tagIds: <String>[oldTag]);

      await repository.addTaxonomyItemToMany(<String>[id], newTag);

      final ReferenceItem item = (await repository.getById(id))!;
      expect(item.tagIds, containsAll(<String>[oldTag, newTag]));
      expect(item.tagIds.length, 2);
    });

    test('이미 붙어있으면 두 번 붙지 않는다', () async {
      final String tagId = await saveTaxonomy(TaxonomyKind.tag, '노을');
      final String id = await saveReference(tagIds: <String>[tagId]);

      await repository.addTaxonomyItemToMany(<String>[id], tagId);

      expect((await repository.getById(id))!.tagIds, <String>[tagId]);
    });

    test('이미 붙어있으면 붙인 시각을 새로 찍지 않는다', () async {
      // 이걸 안 지키면, 아무것도 안 바뀌었는데 동기화가 "방금 새로 붙은 태그"로
      // 착각합니다. 겉으로는 안 보이지만 나중에 문제가 되는 부분입니다.
      final String tagId = await saveTaxonomy(TaxonomyKind.tag, '노을');
      final String id = await saveReference(tagIds: <String>[tagId]);

      final DateTime linkedAt = await readLinkCreatedAt(id, tagId);

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repository.addTaxonomyItemToMany(<String>[id], tagId);

      expect(await readLinkCreatedAt(id, tagId), linkedAt);
    });

    test('예전에 뗐던 태그를 다시 붙일 수 있다', () async {
      // 뗀 연결은 표에 deletedAt만 찍힌 채 남아 있습니다.
      // 그냥 insert하면 "이미 있는 줄"이라며 실패하는 경우입니다.
      final String tagId = await saveTaxonomy(TaxonomyKind.tag, '노을');
      final String id = await saveReference(tagIds: <String>[tagId]);

      // 한 번 뗍니다.
      await repository.setLinkedTaxonomyIds(id, TaxonomyKind.tag, <String>[]);
      expect((await repository.getById(id))!.tagIds, isEmpty);

      await repository.addTaxonomyItemToMany(<String>[id], tagId);

      expect((await repository.getById(id))!.tagIds, <String>[tagId]);
    });

    test('태그를 붙이면 레퍼런스의 updatedAt도 갱신된다', () async {
      // 태그는 다른 표에 있어서 본체는 글자 하나 안 바뀌지만,
      // 여기서 갱신을 안 하면 동기화가 이 변경을 못 알아챕니다.
      final String tagId = await saveTaxonomy(TaxonomyKind.tag, '노을');
      final String id = await saveReference();

      final DateTime before = (await repository.getById(id))!.updatedAt;

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repository.addTaxonomyItemToMany(<String>[id], tagId);

      expect((await repository.getById(id))!.updatedAt.isAfter(before), isTrue);
    });
  });

  group('deleteMany', () {
    test('고른 것들만 지운다', () async {
      final String deletedA = await saveReference(title: 'A');
      final String deletedB = await saveReference(title: 'B');
      final String kept = await saveReference(title: 'C');

      await repository.deleteMany(<String>[deletedA, deletedB]);

      expect(await repository.getById(deletedA), isNull);
      expect(await repository.getById(deletedB), isNull);
      expect(await repository.getById(kept), isNotNull);
      expect((await repository.getAll()).length, 1);
    });

    test('진짜로 지우지 않고 deletedAt만 찍는다 (소프트 삭제)', () async {
      final String id = await saveReference();

      await repository.deleteMany(<String>[id]);

      // getById는 null이지만 표에는 줄이 남아 있어야 합니다.
      expect(await repository.getById(id), isNull);

      final List<ReferenceRow> rows = await db.select(db.references).get();
      expect(rows.length, 1);
      expect(rows.first.deletedAt, isNotNull);
    });
  });
}
