// 분류 항목(폴더/카테고리/태그/프로젝트) 저장소가 제대로 동작하는지 확인하는 테스트입니다.
//
// 실제 데이터베이스 파일을 만들지 않고 메모리 안에서만 도는 데이터베이스를 씁니다.
// 그래서 테스트를 몇 번 돌려도 흔적이 남지 않고, 테스트끼리 서로 영향을 주지 않습니다.
//
// 터미널에서 `flutter test` 로 실행합니다.

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
  late LocalTaxonomyRepository repository;

  // setUp은 테스트 하나하나마다 실행됩니다. 매번 새 데이터베이스로 시작한다는 뜻입니다.
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalTaxonomyRepository(db);
  });

  // tearDown은 테스트가 끝날 때마다 실행됩니다. 데이터베이스를 닫아 정리합니다.
  tearDown(() async {
    await db.close();
  });

  /// 테스트용 분류 항목을 하나 만들어 돌려주는 도우미 함수입니다.
  TaxonomyItem makeItem(TaxonomyKind kind, String name) {
    final DateTime now = DateTime.now().toUtc();
    return TaxonomyItem(
      id: newId(),
      kind: kind,
      name: name,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('저장한 항목을 다시 읽어올 수 있다', () async {
    final TaxonomyItem folder = makeItem(TaxonomyKind.folder, '인물');
    await repository.save(folder);

    final TaxonomyItem? loaded = await repository.getById(folder.id);

    expect(loaded, isNotNull);
    expect(loaded!.name, '인물');
    expect(loaded.kind, TaxonomyKind.folder);
  });

  test('종류가 다르면 서로 섞이지 않는다', () async {
    await repository.save(makeItem(TaxonomyKind.folder, '인물'));
    await repository.save(makeItem(TaxonomyKind.tag, '인물'));
    await repository.save(makeItem(TaxonomyKind.tag, '풍경'));

    final List<TaxonomyItem> folders = await repository.getAll(TaxonomyKind.folder);
    final List<TaxonomyItem> tags = await repository.getAll(TaxonomyKind.tag);

    // 폴더 "인물"과 태그 "인물"은 이름이 같아도 별개입니다.
    expect(folders.length, 1);
    expect(tags.length, 2);
  });

  test('목록은 이름 가나다순으로 나온다', () async {
    await repository.save(makeItem(TaxonomyKind.folder, '풍경'));
    await repository.save(makeItem(TaxonomyKind.folder, '건축'));
    await repository.save(makeItem(TaxonomyKind.folder, '인물'));

    final List<TaxonomyItem> folders = await repository.getAll(TaxonomyKind.folder);

    expect(folders.map((TaxonomyItem f) => f.name).toList(), <String>['건축', '인물', '풍경']);
  });

  test('지운 항목은 목록과 조회에서 모두 빠진다', () async {
    final TaxonomyItem folder = makeItem(TaxonomyKind.folder, '인물');
    await repository.save(folder);
    await repository.delete(folder.id);

    expect(await repository.getById(folder.id), isNull);
    expect(await repository.getAll(TaxonomyKind.folder), isEmpty);
  });

  test('지워도 데이터베이스에는 남아있다 (소프트 삭제)', () async {
    final TaxonomyItem folder = makeItem(TaxonomyKind.folder, '인물');
    await repository.save(folder);
    await repository.delete(folder.id);

    // 저장소를 거치지 않고 데이터베이스를 직접 들여다봅니다.
    // 진짜로 지워졌다면 줄이 아예 없어야 하지만, 소프트 삭제라 남아 있어야 합니다.
    // 나중에 기기 간 동기화를 붙일 때 "지웠다"는 사실 자체가 필요하기 때문입니다.
    //
    // 폴더만 골라서 셉니다. 다른 종류(카테고리 등)를 만든 적이 있다면
    // 그것까지 딸려올 수 있어서 kind로 걸러서 셉니다.
    final List<TaxonomyItemRow> folderRows =
        await (db.select(db.taxonomyItems)..where(
              ($TaxonomyItemsTable t) =>
                  t.kind.equals(TaxonomyKind.folder.storedName),
            ))
            .get();

    expect(folderRows.length, 1);
    expect(folderRows.first.deletedAt, isNotNull);
  });

  test('폴더를 지우면 그 폴더를 쓰던 레퍼런스는 폴더 없음이 된다', () async {
    // (part_delete_test.dart의 "다른 분류는 예전 그대로다" 그룹에서 옮겨온
    // 테스트입니다. 파트 자체는 없어졌지만, 폴더는 카테고리와 달리 연결
    // 표가 아니라 레퍼런스 표에 직접 박힌 칼럼이라 이 동작만 따로 확인해둘
    // 가치가 있습니다.) "폴더 없음"은 정상적인 상태이고 목록에도 그대로
    // 보입니다.
    final TaxonomyItem folder = makeItem(TaxonomyKind.folder, '인물');
    await repository.save(folder);

    final LocalReferenceRepository referenceRepository =
        LocalReferenceRepository(db);
    final DateTime now = DateTime.now().toUtc();
    final ReferenceItem photo = ReferenceItem(
      id: newId(),
      type: ReferenceType.image,
      title: '초상',
      folderId: folder.id,
      fileName: '${newId()}.jpg',
      createdAt: now,
      updatedAt: now,
    );
    await referenceRepository.save(photo);

    await repository.delete(folder.id);

    final ReferenceItem? reloaded = await referenceRepository.getById(
      photo.id,
    );
    expect(reloaded!.folderId, isNull);
  });

  test('저장하면 updatedAt이 갱신되고 createdAt은 그대로다', () async {
    final DateTime past = DateTime.utc(2020, 1, 1);
    final TaxonomyItem folder = TaxonomyItem(
      id: newId(),
      kind: TaxonomyKind.folder,
      name: '인물',
      createdAt: past,
      updatedAt: past,
    );
    await repository.save(folder);

    final TaxonomyItem? loaded = await repository.getById(folder.id);

    // 만든 시각은 건드리지 않습니다.
    expect(loaded!.createdAt, past);
    // 고친 시각은 저장할 때 자동으로 지금 시각이 됩니다.
    expect(loaded.updatedAt.isAfter(past), isTrue);
  });

  test('저장하는 시각은 UTC로 기록된다', () async {
    final TaxonomyItem folder = makeItem(TaxonomyKind.folder, '인물');
    await repository.save(folder);

    final TaxonomyItem? loaded = await repository.getById(folder.id);

    // 현지 시각으로 저장하면 시차가 다른 기기끼리 합칠 때 순서가 뒤집힙니다.
    expect(loaded!.updatedAt.isUtc, isTrue);
  });

  group('이름 중복 검사', () {
    test('같은 종류에 같은 이름이 있으면 true', () async {
      await repository.save(makeItem(TaxonomyKind.folder, '인물'));

      expect(await repository.existsWithName(TaxonomyKind.folder, '인물'), isTrue);
    });

    test('앞뒤 공백과 대소문자는 무시한다', () async {
      await repository.save(makeItem(TaxonomyKind.tag, 'Portrait'));

      expect(await repository.existsWithName(TaxonomyKind.tag, '  portrait  '), isTrue);
    });

    test('종류가 다르면 중복이 아니다', () async {
      await repository.save(makeItem(TaxonomyKind.folder, '인물'));

      expect(await repository.existsWithName(TaxonomyKind.tag, '인물'), isFalse);
    });

    test('이름 바꾸기를 할 때 자기 자신은 중복으로 치지 않는다', () async {
      final TaxonomyItem folder = makeItem(TaxonomyKind.folder, '인물');
      await repository.save(folder);

      expect(
        await repository.existsWithName(TaxonomyKind.folder, '인물', excludeId: folder.id),
        isFalse,
      );
    });

    test('지운 항목의 이름은 다시 쓸 수 있다', () async {
      final TaxonomyItem folder = makeItem(TaxonomyKind.folder, '인물');
      await repository.save(folder);
      await repository.delete(folder.id);

      expect(await repository.existsWithName(TaxonomyKind.folder, '인물'), isFalse);
    });
  });
}
