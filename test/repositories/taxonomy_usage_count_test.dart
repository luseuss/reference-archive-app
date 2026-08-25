// 분류 항목을 쓰는 레퍼런스 개수를 정확히 세는지 확인하는 테스트입니다.
//
// 이 숫자는 사용자가 "지울까 말까"를 판단하는 근거입니다.
// 틀린 숫자를 보여주면 사용자가 잘못된 판단으로 지우게 되므로,
// 특히 헷갈리기 쉬운 경우(지운 레퍼런스, 뗀 태그)를 꼼꼼히 확인합니다.

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

  /// 테스트용 레퍼런스를 하나 만들어 저장하고 돌려줍니다.
  Future<ReferenceItem> saveReference({
    String title = '사진',
    String? folderId,
    String? categoryId,
    List<String> tagIds = const <String>[],
    List<String> projectIds = const <String>[],
  }) async {
    final DateTime now = DateTime.now().toUtc();
    final ReferenceItem item = ReferenceItem(
      id: newId(),
      type: ReferenceType.image,
      title: title,
      folderId: folderId,
      categoryId: categoryId,
      tagIds: tagIds,
      projectIds: projectIds,
      fileName: '${newId()}.jpg',
      createdAt: now,
      updatedAt: now,
    );
    await repository.save(item);
    return item;
  }

  /// 테스트용 분류 항목을 만들어 저장하고 그 id를 돌려줍니다.
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

  test('아무도 안 쓰면 0이다', () async {
    final String tag = await saveTaxonomy(TaxonomyKind.tag, '노을');

    expect(await taxonomyRepository.countReferencesUsing(tag), 0);
  });

  test('폴더를 쓰는 레퍼런스를 센다', () async {
    final String folder = await saveTaxonomy(TaxonomyKind.folder, '인물');
    await saveReference(folderId: folder);
    await saveReference(folderId: folder);
    await saveReference();

    expect(await taxonomyRepository.countReferencesUsing(folder), 2);
  });

  test('카테고리를 쓰는 레퍼런스를 센다', () async {
    final String category = await saveTaxonomy(TaxonomyKind.category, '사진');
    await saveReference(categoryId: category);

    expect(await taxonomyRepository.countReferencesUsing(category), 1);
  });

  test('태그가 붙은 레퍼런스를 센다', () async {
    final String tag = await saveTaxonomy(TaxonomyKind.tag, '노을');
    await saveReference(tagIds: <String>[tag]);
    await saveReference(tagIds: <String>[tag]);
    await saveReference();

    expect(await taxonomyRepository.countReferencesUsing(tag), 2);
  });

  test('프로젝트에 속한 레퍼런스를 센다', () async {
    final String project = await saveTaxonomy(TaxonomyKind.project, '개인 작업');
    await saveReference(projectIds: <String>[project]);

    expect(await taxonomyRepository.countReferencesUsing(project), 1);
  });

  test('지운 레퍼런스는 세지 않는다 (폴더)', () async {
    final String folder = await saveTaxonomy(TaxonomyKind.folder, '인물');
    final ReferenceItem item = await saveReference(folderId: folder);
    await saveReference(folderId: folder);

    await repository.delete(item.id);

    expect(await taxonomyRepository.countReferencesUsing(folder), 1);
  });

  test('지운 레퍼런스는 세지 않는다 (태그)', () async {
    // 레퍼런스를 지워도 연결 줄은 남아 있습니다(소프트 삭제).
    // 연결 표만 세면 "이미 지운 사진이 이 태그를 쓴다"는 엉뚱한 안내가 나갑니다.
    final String tag = await saveTaxonomy(TaxonomyKind.tag, '노을');
    final ReferenceItem item = await saveReference(tagIds: <String>[tag]);
    await saveReference(tagIds: <String>[tag]);

    await repository.delete(item.id);

    expect(await taxonomyRepository.countReferencesUsing(tag), 1);
  });

  test('뗀 태그는 세지 않는다', () async {
    final String tag = await saveTaxonomy(TaxonomyKind.tag, '노을');
    final ReferenceItem item = await saveReference(tagIds: <String>[tag]);

    await repository.setLinkedTaxonomyIds(item.id, TaxonomyKind.tag, <String>[]);

    expect(await taxonomyRepository.countReferencesUsing(tag), 0);
  });

  test('한 레퍼런스가 태그와 프로젝트를 함께 써도 각각 따로 센다', () async {
    final String tag = await saveTaxonomy(TaxonomyKind.tag, '노을');
    final String project = await saveTaxonomy(TaxonomyKind.project, '개인 작업');

    await saveReference(tagIds: <String>[tag], projectIds: <String>[project]);

    expect(await taxonomyRepository.countReferencesUsing(tag), 1);
    expect(await taxonomyRepository.countReferencesUsing(project), 1);
  });

  test('분류 항목을 지우고 나면 0이 된다', () async {
    final String tag = await saveTaxonomy(TaxonomyKind.tag, '노을');
    await saveReference(tagIds: <String>[tag]);

    expect(await taxonomyRepository.countReferencesUsing(tag), 1);

    await taxonomyRepository.delete(tag);

    // 지우면서 연결도 함께 끊기므로 0이어야 합니다.
    expect(await taxonomyRepository.countReferencesUsing(tag), 0);
  });
}
