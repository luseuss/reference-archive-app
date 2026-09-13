// 저장 구조 v8 → v9(무드보드 텍스트 카드 추가) 마이그레이션이 무사한지
// 확인하는 테스트입니다.
//
// 왜 마이그레이션에 테스트가 반드시 필요한지는
// test/data/migration_v1_to_v2_test.dart 맨 위 설명을 보세요. 같은 이유입니다.
//
// ── 이번 마이그레이션이 이전 것들과 다른 점 ──
// v5(boards.folderId)·v8(boardCards.groupId)은 **새 칸을 addColumn으로
// 더하기만** 했습니다. 이번엔 그것도 하지만(textContent, fontFamily),
// **이미 있던 reference_id 칸의 NOT NULL 제약도 없애야** 합니다 —
// 텍스트 카드는 애초에 레퍼런스를 안 가리키므로 이 칸이 비어 있어야
// 합니다. SQLite는 ALTER TABLE로 NOT NULL을 못 없애서
// `Migrator.alterTable(TableMigration(...))`(표를 통째로 다시 만들어
// 옮기는 방식)을 씁니다 — "정말로 NULL을 넣을 수 있게 됐는지"가 이번
// 테스트의 핵심입니다(단순히 칼럼이 존재하는지보다 더 중요합니다).
//
// v2→v3 단계의 createTable(boardCards)가 "지금 이 순간의" tables.dart로
// 표를 만드는 것도 v5·v8과 똑같은 함정입니다 — v1이나 v2에서 곧장 v9로
// 건너뛰는 사용자는 v3 단계에서 이미 이 모든 칸을 가진 채로 표를
// 받으므로, `onUpgrade`의 v9 조건도 `from >= 3 && from < 9`로 맞췄습니다.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/board.dart';
import 'package:reference_archive_app/repositories/local_board_repository.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('migration_v9_test');
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
  /// [version]에 8을 넘기면 group_id까지는 있지만 reference_id가 여전히
  /// NOT NULL이고 textContent·fontFamily는 없는 v8 모습, 1을 넘기면
  /// 파트도 무드보드도 없던 v1 모습입니다.
  void createOldDatabase({required int version, String? cardId}) {
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
        parent_id TEXT,
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
          folder_id TEXT,
          PRIMARY KEY (id)
        )
      ''');

      // v8까지는 reference_id가 NOT NULL이고, group_id는 있지만
      // text_content·font_family는 없습니다 — 이번에 새로 추가하는
      // 칼럼이기 때문입니다.
      final String groupIdColumn = version >= 8 ? 'group_id TEXT,' : '';
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
          $groupIdColumn
          PRIMARY KEY (id)
        )
      ''');
    }

    const String now = '2026-01-01T00:00:00.000Z';

    if (cardId != null && version >= 3) {
      raw.execute(
        'INSERT INTO boards (id, name, created_at, updated_at) '
        'VALUES (?, ?, ?, ?)',
        <Object>['board-1', '겨울 무드', now, now],
      );
      raw.execute(
        'INSERT INTO board_cards '
        '(id, board_id, reference_id, x, y, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object>[cardId, 'board-1', 'ref-1', 0.0, 0.0, now, now],
      );
    }

    raw.execute('PRAGMA user_version = $version');
    raw.close();
  }

  test('앱이 켜지고, 있던 레퍼런스 카드가 안 사라진다', () async {
    createOldDatabase(version: 8, cardId: 'card-1');

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final List<BoardCard> cards = await LocalBoardRepository(
      db,
    ).getCards('board-1');

    expect(cards.length, 1);
    expect(cards.first.id, 'card-1');
    expect(cards.first.referenceId, 'ref-1');
    expect(cards.first.isText, isFalse);
  });

  test('예전 카드는 textContent·fontFamily가 비어 있다', () async {
    createOldDatabase(version: 8, cardId: 'card-1');

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final List<BoardCard> cards = await LocalBoardRepository(
      db,
    ).getCards('board-1');

    expect(cards.first.textContent, isNull);
    expect(cards.first.fontFamily, isNull);
  });

  test('마이그레이션 뒤에는 referenceId 없이 텍스트 카드를 저장할 수 있다', () async {
    // ── 이 테스트가 진짜로 확인하는 것 ──
    // 칼럼이 존재하는지가 아니라, 예전에 NOT NULL이던 reference_id에
    // 실제로 NULL을 넣어도 SQLite가 막지 않는지입니다. alterTable이
    // 제대로 표를 다시 만들지 않았다면 여기서 진짜 SQLite 제약 오류가
    // 납니다.
    createOldDatabase(version: 8, cardId: 'card-1');

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final LocalBoardRepository repository = LocalBoardRepository(db);
    final DateTime now = DateTime.now().toUtc();

    await repository.addCards(<BoardCard>[
      BoardCard(
        id: 'text-card-1',
        boardId: 'board-1',
        x: 10,
        y: 10,
        createdAt: now,
        updatedAt: now,
        textContent: '{"insert":"안녕하세요\\n"}',
        fontFamily: 'Gowun Batang',
      ),
    ]);

    final List<BoardCard> cards = await repository.getCards('board-1');
    final BoardCard textCard = cards.singleWhere(
      (BoardCard c) => c.id == 'text-card-1',
    );

    expect(textCard.referenceId, isNull);
    expect(textCard.isText, isTrue);
    expect(textCard.textContent, '{"insert":"안녕하세요\\n"}');
    expect(textCard.fontFamily, 'Gowun Batang');

    // 예전 레퍼런스 카드도 그대로 함께 있어야 합니다.
    expect(cards.length, 2);
  });

  test('두 번 열어도 오류 없이 그대로다', () async {
    createOldDatabase(version: 8, cardId: 'card-1');

    final AppDatabase first = AppDatabase.forTesting(NativeDatabase(dbFile));
    await LocalBoardRepository(first).getCards('board-1');
    await first.close();

    // 두 번째로 열 때는 이미 schemaVersion이 9라 alterTable이 다시
    // 돌지 않아야 합니다. 다시 돌면 표가 또 한 번 통째로 다시 만들어지며
    // 오류가 나거나 데이터가 꼬일 수 있습니다.
    final AppDatabase second = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(second.close);

    final List<BoardCard> cards = await LocalBoardRepository(
      second,
    ).getCards('board-1');
    expect(cards.length, 1);
    expect(cards.first.referenceId, 'ref-1');
  });

  test('v1에서 v9로 한 번에 건너뛰어도 오류 없이 켜지고 텍스트 카드도 저장된다', () async {
    // ── 실제로 겪은 버그(v5, v8)와 같은 종류를 잡는 테스트입니다 ──
    // v2→v3 단계의 createTable(boardCards)는 "지금 이 순간의"
    // tables.dart로 표를 만들어서, 이미 referenceId가 nullable이고
    // textContent·fontFamily가 포함된 채로 board_cards 표가 생깁니다.
    // 그 뒤 v9 단계가 또 alterTable을 하면 어긋납니다. 한참 업데이트를
    // 안 한 사용자는 정확히 이 경로(v1 → v9 직행)를 지나가므로 반드시
    // 확인해야 합니다.
    createOldDatabase(version: 1);

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final LocalBoardRepository repository = LocalBoardRepository(db);
    final DateTime now = DateTime.now().toUtc();

    await repository.saveBoard(
      Board(id: 'board-new', name: '새 판', createdAt: now, updatedAt: now),
    );
    await repository.addCards(<BoardCard>[
      BoardCard(
        id: 'text-card-new',
        boardId: 'board-new',
        x: 0,
        y: 0,
        createdAt: now,
        updatedAt: now,
        textContent: '{"insert":"새 메모\\n"}',
      ),
    ]);

    final List<BoardCard> saved = await repository.getCards('board-new');
    expect(saved.length, 1);
    expect(saved.first.isText, isTrue);
    expect(saved.first.textContent, '{"insert":"새 메모\\n"}');
  });
}
