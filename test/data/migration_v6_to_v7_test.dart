// 저장 구조 v6 → v7(폴더 중첩 parentId 추가) 마이그레이션이 무사한지
// 확인하는 테스트입니다.
//
// 왜 마이그레이션에 테스트가 반드시 필요한지는
// test/data/migration_v1_to_v2_test.dart 맨 위 설명을 보세요.

import 'dart:io';

import 'package:drift/drift.dart' show QueryRow;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';
import 'package:reference_archive_app/repositories/local_taxonomy_repository.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('migration_v7_test');
    dbFile = File('${tempDir.path}/reference_archive.sqlite');
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  /// 옛날 구조(v6, parentId가 없던 마지막 버전)의 데이터베이스 파일을 만듭니다.
  void createOldDatabase() {
    final Database raw = sqlite3.open(dbFile.path);

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

    raw.execute('''
      CREATE TABLE boards (
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        folder_id TEXT,
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

    const String now = '2026-01-01T00:00:00.000Z';
    raw.execute(
      'INSERT INTO taxonomy_items (id, kind, name, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?)',
      <Object>['folder-1', 'folder', '인물', now, now],
    );

    raw.execute('PRAGMA user_version = 6');
    raw.close();
  }

  test('앱이 켜지고 기존 폴더가 남아 있다', () async {
    createOldDatabase();

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final List<TaxonomyItem> folders =
        await LocalTaxonomyRepository(db).getAll(TaxonomyKind.folder);

    expect(folders.length, 1);
    expect(folders.first.name, '인물');
  });

  test('기존 폴더는 parentId가 비어 있어 최상위가 된다', () async {
    createOldDatabase();

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final List<TaxonomyItem> folders =
        await LocalTaxonomyRepository(db).getAll(TaxonomyKind.folder);

    expect(folders.first.parentId, isNull);
  });

  test('taxonomy_items에 parent_id 칼럼이 생겼다', () async {
    createOldDatabase();

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    await LocalTaxonomyRepository(db).getAll(TaxonomyKind.folder);

    final List<QueryRow> columns =
        await db.customSelect('PRAGMA table_info(taxonomy_items)').get();
    final List<String> columnNames =
        columns.map((QueryRow row) => row.read<String>('name')).toList();

    expect(columnNames, contains('parent_id'));
  });

  test('두 번 열어도 오류 없이 그대로다', () async {
    createOldDatabase();

    final AppDatabase first = AppDatabase.forTesting(NativeDatabase(dbFile));
    await LocalTaxonomyRepository(first).getAll(TaxonomyKind.folder);
    await first.close();

    final AppDatabase second = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(second.close);

    final List<TaxonomyItem> folders =
        await LocalTaxonomyRepository(second).getAll(TaxonomyKind.folder);
    expect(folders.length, 1);
  });
}
