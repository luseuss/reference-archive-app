// 레퍼런스 저장소가 제대로 동작하는지 확인하는 테스트입니다.
//
// 실제 데이터베이스 파일을 만들지 않고 메모리 안에서만 도는 데이터베이스를 씁니다.
// 터미널에서 `flutter test` 로 실행합니다.

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

  /// 테스트용 이미지 레퍼런스를 하나 만들어 돌려주는 도우미 함수입니다.
  ReferenceItem makeImage(String title, {bool isPinned = false}) {
    final DateTime now = DateTime.now().toUtc();
    return ReferenceItem(
      id: newId(),
      type: ReferenceType.image,
      title: title,
      fileName: '${newId()}.jpg',
      isPinned: isPinned,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 테스트용 분류 항목을 하나 만들어 저장하고 그 id를 돌려줍니다.
  Future<String> makeTaxonomy(TaxonomyKind kind, String name) async {
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

  group('기본 저장과 조회', () {
    test('저장한 레퍼런스를 다시 읽어올 수 있다', () async {
      final ReferenceItem item = makeImage('노을 사진');
      await repository.save(item);

      final ReferenceItem? loaded = await repository.getById(item.id);

      expect(loaded, isNotNull);
      expect(loaded!.title, '노을 사진');
      expect(loaded.type, ReferenceType.image);
      expect(loaded.fileName, item.fileName);
    });

    test('유튜브 레퍼런스도 저장된다', () async {
      final DateTime now = DateTime.now().toUtc();
      final ReferenceItem video = ReferenceItem(
        id: newId(),
        type: ReferenceType.youtube,
        title: '참고 영상',
        youtubeVideoId: 'dQw4w9WgXcQ',
        createdAt: now,
        updatedAt: now,
      );
      await repository.save(video);

      final ReferenceItem? loaded = await repository.getById(video.id);

      expect(loaded!.type, ReferenceType.youtube);
      expect(loaded.youtubeVideoId, 'dQw4w9WgXcQ');
      // 유튜브는 파일이 없으므로 fileName은 비어 있어야 합니다.
      expect(loaded.fileName, isNull);
    });

    test('없는 id를 찾으면 null이다', () async {
      expect(await repository.getById(newId()), isNull);
    });

    test('같은 id로 저장하면 덮어쓴다 (중복 생성 아님)', () async {
      final ReferenceItem item = makeImage('원래 제목');
      await repository.save(item);
      await repository.save(item.copyWith(title: '바뀐 제목'));

      final List<ReferenceItem> all = await repository.getAll();

      expect(all.length, 1);
      expect(all.first.title, '바뀐 제목');
    });
  });

  group('삭제', () {
    test('지운 레퍼런스는 목록과 조회에서 모두 빠진다', () async {
      final ReferenceItem item = makeImage('노을 사진');
      await repository.save(item);
      await repository.delete(item.id);

      expect(await repository.getById(item.id), isNull);
      expect(await repository.getAll(), isEmpty);
    });

    test('지워도 데이터베이스에는 남아있다 (소프트 삭제)', () async {
      final ReferenceItem item = makeImage('노을 사진');
      await repository.save(item);
      await repository.delete(item.id);

      // 저장소를 거치지 않고 데이터베이스를 직접 들여다봅니다.
      // 나중에 기기 간 동기화를 붙일 때 "지웠다"는 사실 자체가 필요하기 때문입니다.
      final List<ReferenceRow> allRows = await db.select(db.references).get();

      expect(allRows.length, 1);
      expect(allRows.first.deletedAt, isNotNull);
    });
  });

  group('정렬', () {
    test('핀 고정한 항목이 항상 맨 위에 온다', () async {
      // 고정 안 한 항목을 나중에 저장해서 "최근 수정순"으로는 위에 오게 만듭니다.
      // 그래도 고정한 항목이 위에 있어야 합니다.
      final ReferenceItem pinned = makeImage('고정한 것', isPinned: true);
      await repository.save(pinned);
      await repository.save(makeImage('최근에 고친 것'));

      final List<ReferenceItem> all = await repository.getAll();

      expect(all.first.title, '고정한 것');
    });

    test('고정한 것이 없으면 최근에 고친 순서로 나온다', () async {
      await repository.save(makeImage('먼저 만든 것'));
      await repository.save(makeImage('나중에 만든 것'));

      final List<ReferenceItem> all = await repository.getAll();

      expect(all.first.title, '나중에 만든 것');
    });
  });

  group('태그 연결', () {
    test('저장할 때 태그가 함께 연결된다', () async {
      final String tagA = await makeTaxonomy(TaxonomyKind.tag, '노을');
      final String tagB = await makeTaxonomy(TaxonomyKind.tag, '풍경');

      final ReferenceItem item = makeImage('노을 사진');
      await repository.save(item.copyWith(tagIds: <String>[tagA, tagB]));

      final ReferenceItem? loaded = await repository.getById(item.id);

      expect(loaded!.tagIds.length, 2);
      expect(loaded.tagIds, containsAll(<String>[tagA, tagB]));
    });

    test('태그 목록을 통째로 바꾸면 없어진 것은 떨어진다', () async {
      final String tagA = await makeTaxonomy(TaxonomyKind.tag, '노을');
      final String tagB = await makeTaxonomy(TaxonomyKind.tag, '풍경');

      final ReferenceItem item = makeImage('노을 사진');
      await repository.save(item.copyWith(tagIds: <String>[tagA, tagB]));

      // 태그 하나만 남기고 바꿉니다.
      await repository.setLinkedTaxonomyIds(item.id, TaxonomyKind.tag, <String>[tagA]);

      final ReferenceItem? loaded = await repository.getById(item.id);

      expect(loaded!.tagIds, <String>[tagA]);
    });

    test('뗐던 태그를 다시 붙일 수 있다', () async {
      // 연결 표는 소프트 삭제라 뗀 줄이 그대로 남아 있습니다.
      // 그냥 새로 넣으면 "이미 있는 줄"이라며 실패할 수 있어서 되살리도록 만들었는데,
      // 실제로 되는지 확인합니다.
      final String tag = await makeTaxonomy(TaxonomyKind.tag, '노을');
      final ReferenceItem item = makeImage('노을 사진');

      await repository.save(item.copyWith(tagIds: <String>[tag]));
      await repository.setLinkedTaxonomyIds(item.id, TaxonomyKind.tag, <String>[]);
      await repository.setLinkedTaxonomyIds(item.id, TaxonomyKind.tag, <String>[tag]);

      final ReferenceItem? loaded = await repository.getById(item.id);

      expect(loaded!.tagIds, <String>[tag]);
    });

    test('태그와 프로젝트는 서로 섞이지 않는다', () async {
      final String tag = await makeTaxonomy(TaxonomyKind.tag, '노을');
      final String project = await makeTaxonomy(TaxonomyKind.project, '개인 작업');

      final ReferenceItem item = makeImage('노을 사진');
      await repository.save(item.copyWith(
        tagIds: <String>[tag],
        projectIds: <String>[project],
      ));

      final ReferenceItem? loaded = await repository.getById(item.id);

      // 둘 다 같은 연결 표에 들어가지만 종류로 갈라져 나와야 합니다.
      expect(loaded!.tagIds, <String>[tag]);
      expect(loaded.projectIds, <String>[project]);
    });

    test('태그를 지우면 붙어있던 레퍼런스에서도 떨어진다', () async {
      final String tag = await makeTaxonomy(TaxonomyKind.tag, '노을');
      final ReferenceItem item = makeImage('노을 사진');
      await repository.save(item.copyWith(tagIds: <String>[tag]));

      await taxonomyRepository.delete(tag);

      final ReferenceItem? loaded = await repository.getById(item.id);

      expect(loaded!.tagIds, isEmpty);
    });
  });

  group('폴더와 카테고리', () {
    test('폴더를 지우면 그 폴더에 있던 레퍼런스는 폴더 없음이 된다', () async {
      final String folder = await makeTaxonomy(TaxonomyKind.folder, '인물');

      final ReferenceItem item = makeImage('초상 사진');
      await repository.save(item.copyWith(folderId: folder));

      await taxonomyRepository.delete(folder);

      final ReferenceItem? loaded = await repository.getById(item.id);

      // 레퍼런스 자체는 살아있어야 합니다. 폴더만 사라진 것입니다.
      expect(loaded, isNotNull);
      expect(loaded!.folderId, isNull);
    });

    test('카테고리를 지워도 레퍼런스는 살아남는다', () async {
      final String category = await makeTaxonomy(TaxonomyKind.category, '사진');

      final ReferenceItem item = makeImage('초상 사진');
      await repository.save(item.copyWith(categoryId: category));

      await taxonomyRepository.delete(category);

      final ReferenceItem? loaded = await repository.getById(item.id);

      expect(loaded, isNotNull);
      expect(loaded!.categoryId, isNull);
    });

    test('clearFolder로 폴더에서 빼낼 수 있다', () async {
      final String folder = await makeTaxonomy(TaxonomyKind.folder, '인물');

      final ReferenceItem item = makeImage('초상 사진');
      await repository.save(item.copyWith(folderId: folder));

      final ReferenceItem? withFolder = await repository.getById(item.id);
      await repository.save(withFolder!.clearFolder());

      final ReferenceItem? loaded = await repository.getById(item.id);

      expect(loaded!.folderId, isNull);
    });
  });

  group('시각 기록', () {
    test('저장하면 updatedAt이 갱신되고 createdAt은 그대로다', () async {
      final DateTime past = DateTime.utc(2020, 1, 1);
      final ReferenceItem item = ReferenceItem(
        id: newId(),
        type: ReferenceType.image,
        title: '옛날 사진',
        createdAt: past,
        updatedAt: past,
      );
      await repository.save(item);

      final ReferenceItem? loaded = await repository.getById(item.id);

      // 만든 시각은 건드리지 않습니다.
      expect(loaded!.createdAt, past);
      // 고친 시각은 저장할 때 자동으로 지금 시각이 됩니다.
      expect(loaded.updatedAt.isAfter(past), isTrue);
    });

    test('시각은 UTC로 기록된다', () async {
      final ReferenceItem item = makeImage('노을 사진');
      await repository.save(item);

      final ReferenceItem? loaded = await repository.getById(item.id);

      // 현지 시각으로 저장하면 시차가 다른 기기끼리 합칠 때 순서가 뒤집힙니다.
      expect(loaded!.createdAt.isUtc, isTrue);
      expect(loaded.updatedAt.isUtc, isTrue);
    });
  });

  group('유사한 것끼리 정렬', () {
    test('태그가 겹치는 항목이 앞으로 온다', () async {
      final DateTime now = DateTime.now().toUtc();

      // 태그는 연결 표가 실제 taxonomyItems 행을 inner join으로 찾으므로,
      // 임의의 문자열이 아니라 실제로 만들어둔 태그 id를 써야 저장 후
      // 다시 읽어올 때 tagIds가 비어버리지 않습니다.
      final String sunsetTag = await makeTaxonomy(TaxonomyKind.tag, '노을');
      final String architectureTag = await makeTaxonomy(TaxonomyKind.tag, '건축');

      final ReferenceItem anchor = ReferenceItem(
        id: newId(),
        type: ReferenceType.image,
        tagIds: <String>[sunsetTag],
        createdAt: now,
        updatedAt: now,
      );
      final ReferenceItem similar = ReferenceItem(
        id: newId(),
        type: ReferenceType.image,
        tagIds: <String>[sunsetTag],
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      );
      final ReferenceItem unrelated = ReferenceItem(
        id: newId(),
        type: ReferenceType.image,
        tagIds: <String>[architectureTag],
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      );

      await repository.save(unrelated);
      await repository.save(similar);
      await repository.save(anchor); // 가장 최근 -> 기준점

      final List<ReferenceItem> result = await repository.search(
        const ReferenceQuery(sortOrder: ReferenceSortOrder.similar),
      );

      expect(result.map((ReferenceItem i) => i.id).toList(), <String>[
        anchor.id,
        similar.id,
        unrelated.id,
      ]);
    });

    test('핀 고정된 항목은 유사도와 무관하게 맨 위에 남는다', () async {
      final DateTime now = DateTime.now().toUtc();

      final String sunsetTag = await makeTaxonomy(TaxonomyKind.tag, '노을');
      final String architectureTag = await makeTaxonomy(TaxonomyKind.tag, '건축');

      final ReferenceItem pinnedButUnrelated = ReferenceItem(
        id: newId(),
        type: ReferenceType.image,
        tagIds: <String>[architectureTag],
        isPinned: true,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 5)),
      );
      final ReferenceItem anchor = ReferenceItem(
        id: newId(),
        type: ReferenceType.image,
        tagIds: <String>[sunsetTag],
        createdAt: now,
        updatedAt: now,
      );

      await repository.save(anchor);
      await repository.save(pinnedButUnrelated);

      final List<ReferenceItem> result = await repository.search(
        const ReferenceQuery(sortOrder: ReferenceSortOrder.similar),
      );

      expect(result.first.id, pinnedButUnrelated.id);
    });
  });
}
