// 저장 구조 v3 → v4(메모 리치텍스트) 마이그레이션이 무사한지 확인하는
// 테스트입니다.
//
// 왜 마이그레이션에 테스트가 반드시 필요한지는
// test/data/migration_v1_to_v2_test.dart 맨 위 설명을 보세요. 같은 이유입니다.
//
// 이번 마이그레이션은 표 구조(칼럼 추가/삭제)는 안 바뀝니다. **있던 memo
// 값을 최소 Delta(JSON)로 감싸 다시 씁니다.** 그래서 확인할 것은 다섯 가지
// 입니다: 앱이 켜지는지 / 기존 메모가 안 사라지는지 / 감싸진 값이 새
// 편집기로 읽었을 때 원래 글자가 그대로 나오는지 / 두 번 열어도 중복으로
// 안 감싸지는지 / 옛 버전(v1)에서 곧장 건너뛰어도 되는지.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/board.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';
import 'package:reference_archive_app/repositories/local_board_repository.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/repositories/local_taxonomy_repository.dart';
import 'package:reference_archive_app/utils/rich_text_memo.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('migration_v4_test');
    dbFile = File('${tempDir.path}/reference_archive.sqlite');
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  /// 옛날 구조의 데이터베이스 파일을 만듭니다.
  ///
  /// [version]에 3을 넘기면 무드보드 표까지 있는 v3 모습(memo가 아직 순수
  /// 텍스트인 상태), 1을 넘기면 파트도 무드보드도 없던 v1 모습입니다.
  ///
  /// [memo]는 "old-1" 레퍼런스에 넣어둘 메모입니다. null이면 메모 없이 만듭니다.
  void createOldDatabase({required int version, String? memo}) {
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

    // v3부터는 무드보드 표 두 개가 이미 있습니다.
    if (version >= 3) {
      raw.execute('''
        CREATE TABLE boards (
          id TEXT NOT NULL,
          name TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          deleted_at TEXT,
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

    if (version >= 2) {
      raw.execute(
        'INSERT INTO "references" (id, title, type, memo, part_id, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>['old-1', '예전 사진', 'image', memo, defaultPartId, now, now],
      );

      raw.execute(
        'INSERT INTO taxonomy_items (id, kind, name, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?)',
        <Object>[defaultPartId, 'part', defaultPartName, now, now],
      );
    } else {
      raw.execute(
        'INSERT INTO "references" (id, title, type, memo, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['old-1', '예전 사진', 'image', memo, now, now],
      );
    }

    raw.execute('PRAGMA user_version = $version');
    raw.close();
  }

  test('앱이 켜지고, 있던 순수 텍스트 메모가 안 사라진다', () async {
    createOldDatabase(version: 3, memo: '색감 참고');

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final List<ReferenceItem> items = await LocalReferenceRepository(
      db,
    ).getAll();

    expect(items.length, 1);
    expect(items.first.memo, isNotNull);
    // 순수 텍스트가 아니라 Delta(JSON)로 바뀌어 있어야 합니다.
    expect(items.first.memo, isNot('색감 참고'));
  });

  test('감싸진 메모를 새 편집기로 읽으면 원래 글자가 그대로 나온다', () async {
    createOldDatabase(version: 3, memo: '색감 참고');

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final List<ReferenceItem> items = await LocalReferenceRepository(
      db,
    ).getAll();

    expect(plainTextFromMemo(items.first.memo), '색감 참고');
  });

  test('메모가 없던 레퍼런스는 그대로 null이다', () async {
    createOldDatabase(version: 3, memo: null);

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final List<ReferenceItem> items = await LocalReferenceRepository(
      db,
    ).getAll();

    expect(items.first.memo, isNull);
  });

  test('두 번 열어도 메모가 두 번 감싸지지 않는다', () async {
    createOldDatabase(version: 3, memo: '색감 참고');

    final AppDatabase first = AppDatabase.forTesting(NativeDatabase(dbFile));
    final String? afterFirstOpen = (await LocalReferenceRepository(
      first,
    ).getAll()).first.memo;
    await first.close();

    final AppDatabase second = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(second.close);
    final String? afterSecondOpen = (await LocalReferenceRepository(
      second,
    ).getAll()).first.memo;

    // 두 번째로 열 때는 이미 schemaVersion이 4라 마이그레이션이 다시 돌지
    // 않아야 합니다. 값이 완전히 같아야 합니다(다시 감싸지면 값이 달라집니다).
    expect(afterSecondOpen, afterFirstOpen);
    expect(plainTextFromMemo(afterSecondOpen), '색감 참고');
  });

  test('v1에서 v4로 한 번에 건너뛰어도 메모가 마이그레이션된다', () async {
    // 한참 업데이트를 안 한 사용자는 1에서 곧장 4로 옵니다. v2(파트)·
    // v3(무드보드 표)·v4(메모) 세 단계가 순서대로 다 실행돼야 합니다.
    createOldDatabase(version: 1, memo: '오래된 메모');

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    // v2가 해줘야 할 일
    final List<ReferenceItem> items = await LocalReferenceRepository(
      db,
    ).getAll();
    expect(items.first.partId, defaultPartId, reason: 'v2 단계가 건너뛰어졌습니다');

    final List<TaxonomyItem> parts = await LocalTaxonomyRepository(
      db,
    ).getAll(TaxonomyKind.part);
    expect(parts.length, 1);

    // v3이 해줘야 할 일 — 무드보드 표가 있어야 합니다.
    final DateTime now = DateTime.now().toUtc();
    await LocalBoardRepository(db).saveBoard(
      Board(id: 'board-1', name: '겨울 무드', createdAt: now, updatedAt: now),
    );
    expect(
      (await LocalBoardRepository(db).getAllBoards()).length,
      1,
      reason: 'v3 단계가 건너뛰어졌습니다',
    );

    // v4가 해줘야 할 일 — 메모가 Delta로 감싸져 있어야 합니다.
    expect(
      plainTextFromMemo(items.first.memo),
      '오래된 메모',
      reason: 'v4 단계가 건너뛰어졌습니다',
    );
  });
}
