// 검색·필터·정렬이 제대로 동작하는지 확인하는 테스트입니다.
//
// 이 기능들은 전부 SQL로 처리되기 때문에, 화면 없이 저장소만 놓고 검증할 수 있습니다.
// 화면을 만들기 전에 여기부터 맞춰두면, 나중에 "화면이 이상한 건지 검색이 이상한 건지"
// 헷갈릴 일이 없습니다.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/models/reference_query.dart';
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
    String? memo,
    String? folderId,
    String? categoryId,
    List<String> tagIds = const <String>[],
    List<String> projectIds = const <String>[],
    bool isFavorite = false,
    bool isPinned = false,
    DateTime? createdAt,
  }) async {
    final DateTime now = createdAt ?? DateTime.now().toUtc();
    final ReferenceItem item = ReferenceItem(
      id: newId(),
      type: ReferenceType.image,
      title: title,
      memo: memo,
      folderId: folderId,
      categoryId: categoryId,
      tagIds: tagIds,
      projectIds: projectIds,
      isFavorite: isFavorite,
      isPinned: isPinned,
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

  /// 결과에서 제목만 뽑아 돌려줍니다. 확인하기 편하게 하려는 도우미입니다.
  List<String> titlesOf(List<ReferenceItem> items) {
    return items.map((ReferenceItem item) => item.title).toList();
  }

  group('검색어', () {
    test('제목에 들어있으면 찾는다', () async {
      await saveReference(title: '노을 사진');
      await saveReference(title: '건물 사진');

      final List<ReferenceItem> found =
          await repository.search(const ReferenceQuery(searchText: '노을'));

      expect(titlesOf(found), <String>['노을 사진']);
    });

    test('메모에 들어있어도 찾는다', () async {
      await saveReference(title: '무제', memo: '노을 색감 참고');
      await saveReference(title: '건물');

      final List<ReferenceItem> found =
          await repository.search(const ReferenceQuery(searchText: '노을'));

      expect(titlesOf(found), <String>['무제']);
    });

    test('가운데 글자로도 찾는다', () async {
      await saveReference(title: '가을 노을 사진');

      final List<ReferenceItem> found =
          await repository.search(const ReferenceQuery(searchText: '노을'));

      expect(found.length, 1);
    });

    test('검색어가 비어 있으면 전부 나온다', () async {
      await saveReference(title: '첫째');
      await saveReference(title: '둘째');

      final List<ReferenceItem> found =
          await repository.search(const ReferenceQuery());

      expect(found.length, 2);
    });

    test('앞뒤 공백만 있는 검색어는 검색하지 않은 것으로 친다', () async {
      await saveReference(title: '첫째');
      await saveReference(title: '둘째');

      final List<ReferenceItem> found =
          await repository.search(const ReferenceQuery(searchText: '   '));

      expect(found.length, 2);
    });

    test('% 같은 특수문자를 넣어도 글자 그대로 찾는다', () async {
      // %는 SQL에서 "아무 글자나"라는 뜻이라, 막아두지 않으면
      // "50%"로 검색했을 때 엉뚱한 것까지 전부 나옵니다.
      await saveReference(title: '할인 50% 포스터');
      await saveReference(title: '그냥 포스터');

      final List<ReferenceItem> found =
          await repository.search(const ReferenceQuery(searchText: '50%'));

      expect(titlesOf(found), <String>['할인 50% 포스터']);
    });

    test('_ 를 넣어도 글자 그대로 찾는다', () async {
      // _는 SQL에서 "아무 글자 한 개"라는 뜻입니다.
      await saveReference(title: 'IMG_1234');
      await saveReference(title: 'IMGX1234');

      final List<ReferenceItem> found =
          await repository.search(const ReferenceQuery(searchText: 'IMG_'));

      expect(titlesOf(found), <String>['IMG_1234']);
    });

    test('지운 항목은 검색되지 않는다', () async {
      final ReferenceItem item = await saveReference(title: '노을 사진');
      await repository.delete(item.id);

      final List<ReferenceItem> found =
          await repository.search(const ReferenceQuery(searchText: '노을'));

      expect(found, isEmpty);
    });
  });

  group('필터', () {
    test('폴더로 거를 수 있다', () async {
      final String folder = await saveTaxonomy(TaxonomyKind.folder, '인물');
      await saveReference(title: '인물 사진', folderId: folder);
      await saveReference(title: '풍경 사진');

      final List<ReferenceItem> found =
          await repository.search(ReferenceQuery(folderId: folder));

      expect(titlesOf(found), <String>['인물 사진']);
    });

    test('카테고리로 거를 수 있다', () async {
      final String category = await saveTaxonomy(TaxonomyKind.category, '사진');
      await saveReference(title: '사진 하나', categoryId: category);
      await saveReference(title: '그림 하나');

      final List<ReferenceItem> found =
          await repository.search(ReferenceQuery(categoryId: category));

      expect(titlesOf(found), <String>['사진 하나']);
    });

    test('태그로 거를 수 있다', () async {
      final String tag = await saveTaxonomy(TaxonomyKind.tag, '노을');
      await saveReference(title: '태그 붙은 것', tagIds: <String>[tag]);
      await saveReference(title: '태그 없는 것');

      final List<ReferenceItem> found =
          await repository.search(ReferenceQuery(tagId: tag));

      expect(titlesOf(found), <String>['태그 붙은 것']);
    });

    test('프로젝트로 거를 수 있다', () async {
      final String project = await saveTaxonomy(TaxonomyKind.project, '개인 작업');
      await saveReference(title: '프로젝트 것', projectIds: <String>[project]);
      await saveReference(title: '그냥 것');

      final List<ReferenceItem> found =
          await repository.search(ReferenceQuery(projectId: project));

      expect(titlesOf(found), <String>['프로젝트 것']);
    });

    test('뗀 태그로는 걸러지지 않는다', () async {
      // 연결 표는 소프트 삭제라 뗀 줄이 그대로 남습니다.
      // 그걸 안 걸러내면 이미 뗀 태그로 검색했을 때 계속 나옵니다.
      final String tag = await saveTaxonomy(TaxonomyKind.tag, '노을');
      final ReferenceItem item =
          await saveReference(title: '태그 뗀 것', tagIds: <String>[tag]);

      await repository.setLinkedTaxonomyIds(item.id, TaxonomyKind.tag, <String>[]);

      final List<ReferenceItem> found =
          await repository.search(ReferenceQuery(tagId: tag));

      expect(found, isEmpty);
    });

    test('즐겨찾기만 볼 수 있다', () async {
      await saveReference(title: '즐겨찾기 한 것', isFavorite: true);
      await saveReference(title: '안 한 것');

      final List<ReferenceItem> found =
          await repository.search(const ReferenceQuery(favoritesOnly: true));

      expect(titlesOf(found), <String>['즐겨찾기 한 것']);
    });

    test('조건 여러 개를 함께 걸면 전부 만족하는 것만 나온다', () async {
      final String folder = await saveTaxonomy(TaxonomyKind.folder, '인물');
      final String tag = await saveTaxonomy(TaxonomyKind.tag, '노을');

      await saveReference(
        title: '전부 맞는 것',
        folderId: folder,
        tagIds: <String>[tag],
        isFavorite: true,
      );
      // 폴더만 맞고 태그가 없는 것
      await saveReference(title: '폴더만 맞는 것', folderId: folder, isFavorite: true);
      // 태그만 맞는 것
      await saveReference(title: '태그만 맞는 것', tagIds: <String>[tag], isFavorite: true);

      final List<ReferenceItem> found = await repository.search(
        ReferenceQuery(folderId: folder, tagId: tag, favoritesOnly: true),
      );

      expect(titlesOf(found), <String>['전부 맞는 것']);
    });

    test('검색어와 필터를 함께 쓸 수 있다', () async {
      final String folder = await saveTaxonomy(TaxonomyKind.folder, '인물');
      await saveReference(title: '노을 인물', folderId: folder);
      await saveReference(title: '건물 인물', folderId: folder);
      await saveReference(title: '노을 풍경');

      final List<ReferenceItem> found = await repository.search(
        ReferenceQuery(searchText: '노을', folderId: folder),
      );

      expect(titlesOf(found), <String>['노을 인물']);
    });
  });

  group('정렬', () {
    test('제목순으로 정렬된다', () async {
      await saveReference(title: '풍경');
      await saveReference(title: '건축');
      await saveReference(title: '인물');

      final List<ReferenceItem> found = await repository.search(
        const ReferenceQuery(sortOrder: ReferenceSortOrder.titleAscending),
      );

      expect(titlesOf(found), <String>['건축', '인물', '풍경']);
    });

    test('오래된 순으로 정렬된다', () async {
      await saveReference(title: '옛날 것', createdAt: DateTime.utc(2020, 1, 1));
      await saveReference(title: '중간 것', createdAt: DateTime.utc(2022, 1, 1));
      await saveReference(title: '최근 것', createdAt: DateTime.utc(2024, 1, 1));

      final List<ReferenceItem> found = await repository.search(
        const ReferenceQuery(sortOrder: ReferenceSortOrder.oldestAdded),
      );

      expect(titlesOf(found), <String>['옛날 것', '중간 것', '최근 것']);
    });

    test('최근 추가순으로 정렬된다', () async {
      await saveReference(title: '옛날 것', createdAt: DateTime.utc(2020, 1, 1));
      await saveReference(title: '최근 것', createdAt: DateTime.utc(2024, 1, 1));

      final List<ReferenceItem> found = await repository.search(
        const ReferenceQuery(sortOrder: ReferenceSortOrder.recentlyAdded),
      );

      expect(titlesOf(found), <String>['최근 것', '옛날 것']);
    });

    test('정렬 방식과 상관없이 고정한 것이 맨 위에 온다', () async {
      // 제목순으로 하면 "가나다"가 맨 앞이어야 하지만,
      // 고정한 "하하하"가 그보다 위에 있어야 합니다.
      await saveReference(title: '가나다');
      await saveReference(title: '하하하', isPinned: true);

      final List<ReferenceItem> found = await repository.search(
        const ReferenceQuery(sortOrder: ReferenceSortOrder.titleAscending),
      );

      expect(titlesOf(found), <String>['하하하', '가나다']);
    });

    test('검색 결과 안에서도 고정한 것이 맨 위에 온다', () async {
      await saveReference(title: '노을 하나');
      await saveReference(title: '노을 둘', isPinned: true);

      final List<ReferenceItem> found = await repository.search(
        const ReferenceQuery(
          searchText: '노을',
          sortOrder: ReferenceSortOrder.titleAscending,
        ),
      );

      expect(found.first.title, '노을 둘');
    });
  });

  group('ReferenceQuery 자체', () {
    test('아무 조건도 없으면 hasAnyFilter가 false다', () {
      expect(const ReferenceQuery().hasAnyFilter, isFalse);
    });

    test('조건이 하나라도 있으면 hasAnyFilter가 true다', () {
      expect(const ReferenceQuery(searchText: '노을').hasAnyFilter, isTrue);
      expect(const ReferenceQuery(favoritesOnly: true).hasAnyFilter, isTrue);
      expect(const ReferenceQuery(folderId: 'x').hasAnyFilter, isTrue);
    });

    test('공백만 있는 검색어는 조건으로 치지 않는다', () {
      expect(const ReferenceQuery(searchText: '   ').hasAnyFilter, isFalse);
    });

    test('clearFilter는 해당 종류만 끈다', () {
      const ReferenceQuery query = ReferenceQuery(
        folderId: 'f',
        tagId: 't',
        searchText: '노을',
      );

      final ReferenceQuery cleared = query.clearFilter(TaxonomyKind.folder);

      expect(cleared.folderId, isNull);
      // 나머지는 그대로 남아야 합니다.
      expect(cleared.tagId, 't');
      expect(cleared.searchText, '노을');
    });

    test('clearAll은 조건을 다 지우지만 정렬은 남긴다', () {
      const ReferenceQuery query = ReferenceQuery(
        folderId: 'f',
        searchText: '노을',
        favoritesOnly: true,
        sortOrder: ReferenceSortOrder.titleAscending,
      );

      final ReferenceQuery cleared = query.clearAll();

      expect(cleared.hasAnyFilter, isFalse);
      // 조건을 지웠다고 정렬까지 되돌리면 사용자가 당황합니다.
      expect(cleared.sortOrder, ReferenceSortOrder.titleAscending);
    });
  });
}
