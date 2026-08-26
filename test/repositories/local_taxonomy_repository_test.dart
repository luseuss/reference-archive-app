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
import 'package:reference_archive_app/models/taxonomy_item.dart';
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
    // 폴더만 골라서 셉니다. 데이터베이스를 새로 만들면 **기본 파트가 하나
    // 들어있어서**(스키마 v2) 전체 줄 수를 세면 그것까지 딸려옵니다.
    final List<TaxonomyItemRow> folderRows =
        await (db.select(db.taxonomyItems)..where(
              ($TaxonomyItemsTable t) =>
                  t.kind.equals(TaxonomyKind.folder.storedName),
            ))
            .get();

    expect(folderRows.length, 1);
    expect(folderRows.first.deletedAt, isNotNull);
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
