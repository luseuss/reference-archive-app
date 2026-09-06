// 저장 구조 v5 → v6(파트 완전 제거) 마이그레이션이 무사한지 확인하는
// 테스트입니다.
//
// 왜 마이그레이션에 테스트가 반드시 필요한지는
// test/data/migration_v1_to_v2_test.dart 맨 위 설명을 보세요. 같은 이유입니다.
//
// 이번 마이그레이션은 파트 관련 칼럼·데이터를 지우는 것이라, 확인할
// 것은 "제대로 지워졌는가"와 "그 과정에서 다른 데이터가 안 다쳤는가"
// 둘입니다. 특히 v1에서 곧장 v6로 건너뛰는 경우를 반드시 확인합니다 —
// v1 사용자는 v2 단계에서 partId 칼럼과 기본 파트가 먼저 생겼다가,
// 이어서 v6 단계가 바로 그걸 지우는 특이한 경로를 지나갑니다.

import 'dart:io';

import 'package:drift/drift.dart' show QueryRow;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/repositories/local_taxonomy_repository.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('migration_v6_test');
    dbFile = File('${tempDir.path}/reference_archive.sqlite');
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  /// 옛날 구조(v5, 파트가 있던 마지막 버전)의 데이터베이스 파일을 만듭니다.
  ///
  /// [version]에 5를 넘기면 파트 칸(part_id)까지 있는 v5 모습, 1을 넘기면
  /// 파트도 무드보드도 없던 v1 모습입니다.
  void createOldDatabase({required int version}) {
    final Database raw = sqlite3.open(dbFile.path);

    final String partColumn = version >= 2 ? 'part_id TEXT,' : '';

    raw.execute('''
      CREATE TABLE "references" (
        id TEXT NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        type TEXT NOT NULL,
        file_name TEXT,
        youtube_video_id TEXT,
        memo TEXT,
        folder_id TEXT,
        category_id TEXT,
        $partColumn
        is_pinned INTEGER NOT NULL DEFAULT 0,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        p_hash TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        PRIMARY KEY (id)
      )
    ''');

    raw.execute('''
      CREATE TABLE taxonomy_items (
        id TEXT NOT NULL,
        kind TEXT NOT NULL,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        PRIMARY KEY (id)
      )
    ''');

    raw.execute('''
      CREATE TABLE reference_taxonomy_links (
        reference_id TEXT NOT NULL,
        taxonomy_item_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        deleted_at TEXT,
        PRIMARY KEY (reference_id, taxonomy_item_id)
      )
    ''');

    if (version >= 3) {
      raw.execute('''
        CREATE TABLE boards (
          id TEXT NOT NULL,
          name TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          deleted_at TEXT,
          ${version >= 5 ? 'folder_id TEXT,' : ''}
          PRIMARY KEY (id)
        )
      ''');

      raw.execute('''
        CREATE TABLE board_cards (
          id TEXT NOT NULL,
          board_id TEXT NOT NULL,
          reference_id TEXT NOT NULL,
          x REAL NOT NULL,
          y REAL NOT NULL,
          width REAL NOT NULL DEFAULT 220,
          height REAL,
          z_order INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          deleted_at TEXT,
          PRIMARY KEY (id)
        )
      ''');
    }

    const String now = '2026-01-01T00:00:00.000Z';

    // v2부터는 기본 파트가 있었습니다. 지금은 지워질 값이라 실제
    // defaultPartId/defaultPartName 상수 대신 그때 당시와 같은 모양의
    // 값을 직접 적습니다(그 상수들은 이번 마이그레이션으로 앱에서
    // 지워졌습니다).
    if (version >= 2) {
      raw.execute(
        'INSERT INTO taxonomy_items (id, kind, name, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?)',
        <Object>['old-default-part', 'part', '기본', now, now],
      );
    }

    // 예전에 넣어둔 레퍼런스입니다. 파트가 있던 시절 만들어졌다면
    // 기본 파트에 들어있는 것으로 흉내냅니다.
    raw.execute(
      'INSERT INTO "references" '
      '(id, title, type, ${version >= 2 ? 'part_id,' : ''} created_at, updated_at) '
      'VALUES (?, ?, ?, ${version >= 2 ? '?,' : ''} ?, ?)',
      version >= 2
          ? <Object>['old-1', '예전 사진', 'image', 'old-default-part', now, now]
          : <Object>['old-1', '예전 사진', 'image', now, now],
    );

    // 폴더도 하나 넣어둡니다. 마이그레이션이 다른 분류를 건드리면 안 됩니다.
    raw.execute(
      'INSERT INTO taxonomy_items (id, kind, name, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?)',
      <Object>['folder-1', 'folder', '인물', now, now],
    );

    raw.execute('PRAGMA user_version = $version');
    raw.close();
  }

  test('앱이 켜지고 레퍼런스가 남아 있다', () async {
    createOldDatabase(version: 5);

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final List<ReferenceItem> items = await LocalReferenceRepository(db).getAll();

    expect(items.length, 1);
    expect(items.first.title, '예전 사진');
  });

  test('References에서 partId 칼럼이 실제로 없어졌다', () async {
    createOldDatabase(version: 5);

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    // 앱을 통해 한 번 읽어서 마이그레이션이 실행되게 합니다.
    await LocalReferenceRepository(db).getAll();

    final List<QueryRow> columns = await db
        .customSelect('PRAGMA table_info("references")')
        .get();
    final List<String> columnNames =
        columns.map((QueryRow row) => row.read<String>('name')).toList();

    expect(columnNames, isNot(contains('part_id')));
  });

  test('taxonomy_items에서 kind=part 행이 전부 지워졌다', () async {
    createOldDatabase(version: 5);

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final List<TaxonomyItem> folders = await LocalTaxonomyRepository(db)
        .getAll(TaxonomyKind.folder);
    expect(folders.length, 1, reason: '다른 분류는 그대로 남아야 합니다');

    final List<QueryRow> partRows = await db
        .customSelect("SELECT id FROM taxonomy_items WHERE kind = 'part'")
        .get();
    expect(partRows, isEmpty);
  });

  test('파트에 속해 있던 레퍼런스가 지워지지 않고 남아 있다', () async {
    createOldDatabase(version: 5);

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final List<ReferenceItem> items = await LocalReferenceRepository(db).getAll();

    expect(items.length, 1, reason: '레퍼런스 자체는 지워지면 안 됩니다');
    expect(items.first.folderId, isNull, reason: 'folderId는 원래 값(비어있음) 그대로여야 합니다');
  });

  test('원래 있던 폴더는 그대로 남는다', () async {
    createOldDatabase(version: 5);

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final List<TaxonomyItem> folders = await LocalTaxonomyRepository(db)
        .getAll(TaxonomyKind.folder);

    expect(folders.length, 1);
    expect(folders.first.name, '인물');
  });

  test('v1에서 v6로 한 번에 건너뛰어도 오류 없이 켜진다', () async {
    // ── 이 테스트가 핵심입니다 ──
    // v1 사용자는 v2 단계에서 partId 칼럼과 기본 파트가 먼저 생기고,
    // 바로 이어서 v6 단계가 그걸 지웁니다. 두 단계가 한 번에 이어져도
    // "칼럼이 없는데 지우려 한다"거나 순서가 꼬여서 죽으면 안 됩니다.
    createOldDatabase(version: 1);

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final List<ReferenceItem> items = await LocalReferenceRepository(db).getAll();
    expect(items.length, 1, reason: 'v1 사용자의 레퍼런스도 남아 있어야 합니다');

    final List<QueryRow> columns = await db
        .customSelect('PRAGMA table_info("references")')
        .get();
    expect(
      columns.map((QueryRow row) => row.read<String>('name')),
      isNot(contains('part_id')),
    );
  });

  test('두 번 열어도 오류 없이 그대로다', () async {
    createOldDatabase(version: 5);

    final AppDatabase first = AppDatabase.forTesting(NativeDatabase(dbFile));
    await LocalReferenceRepository(first).getAll();
    await first.close();

    // 두 번째로 열 때는 이미 schemaVersion이 6이라 dropColumn이 다시
    // 돌지 않아야 합니다. 다시 돌면 "칼럼이 없다"는 오류가 납니다.
    final AppDatabase second = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(second.close);

    final List<ReferenceItem> items = await LocalReferenceRepository(second).getAll();
    expect(items.length, 1);
  });
}
