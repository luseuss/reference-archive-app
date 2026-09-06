// 저장 구조 v4 → v5(무드보드를 폴더에 연결) 마이그레이션이 무사한지
// 확인하는 테스트입니다.
//
// 왜 마이그레이션에 테스트가 반드시 필요한지는
// test/data/migration_v1_to_v2_test.dart 맨 위 설명을 보세요. 같은 이유입니다.
//
// 이번 마이그레이션은 boards 표에 folderId 칼럼을 addColumn으로
// 추가하는 것뿐이라 단순해 보이지만, 실제로 **여러 버전을 건너뛰는
// 경우에서 진짜 버그를 하나 잡았습니다** — v2→v3 마이그레이션의
// createTable(boards)는 "그 당시의" 표 모양이 아니라 **지금 이 순간의
// tables.dart**로 표를 만듭니다. 그래서 v1이나 v2에서 곧장 v5로
// 건너뛰는 사용자는 v3 단계에서 이미 folderId가 포함된 boards 표를
// 받고, 그 뒤 v5 단계가 또 addColumn을 하려다 "칼럼이 이미 있다"는
// 오류로 앱이 아예 안 켜졌습니다. `onUpgrade`의 v5 조건을
// `from >= 3 && from < 5`로 고쳐서 해결했습니다 — 이 테스트의
// "v1에서 v5로 한 번에 건너뛰어도" 케이스가 정확히 그 버그를 잡습니다.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/board.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';
import 'package:reference_archive_app/repositories/local_board_repository.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('migration_v5_test');
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
  /// [version]에 4를 넘기면 무드보드 표까지 있지만 folder_id는 아직
  /// 없는 v4 모습, 1을 넘기면 파트도 무드보드도 없던 v1 모습입니다.
  /// [boardId]를 주면 그 번호로 무드보드 하나를 미리 넣어둡니다
  /// (version이 4 이상일 때만 뜻이 있습니다).
  void createOldDatabase({required int version, String? boardId}) {
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

    // v3부터 무드보드 표 두 개가 있습니다. v4까지는 boards에
    // folder_id가 없습니다 — 이번에 새로 추가하는 칼럼이기 때문입니다.
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
        'INSERT INTO taxonomy_items (id, kind, name, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?)',
        <Object>[defaultPartId, 'part', defaultPartName, now, now],
      );
    }

    if (boardId != null && version >= 3) {
      raw.execute(
        'INSERT INTO boards (id, name, created_at, updated_at) '
        'VALUES (?, ?, ?, ?)',
        <Object>[boardId, '겨울 무드', now, now],
      );
    }

    raw.execute('PRAGMA user_version = $version');
    raw.close();
  }

  test('앱이 켜지고, 있던 무드보드가 안 사라진다', () async {
    createOldDatabase(version: 4, boardId: 'board-1');

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final List<Board> boards = await LocalBoardRepository(db).getAllBoards();

    expect(boards.length, 1);
    expect(boards.first.id, 'board-1');
  });

  test('예전 무드보드는 folderId가 비어 있다', () async {
    createOldDatabase(version: 4, boardId: 'board-1');

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final Board? board = await LocalBoardRepository(db).getBoardById('board-1');

    expect(board, isNotNull);
    expect(board!.folderId, isNull);
  });

  test('마이그레이션 뒤에는 폴더를 정해서 저장할 수 있다', () async {
    createOldDatabase(version: 4, boardId: 'board-1');

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final LocalBoardRepository repository = LocalBoardRepository(db);
    final Board board = (await repository.getBoardById('board-1'))!;

    await repository.saveBoard(board.copyWith(folderId: 'folder-1'));

    final Board? updated = await repository.getBoardById('board-1');
    expect(updated!.folderId, 'folder-1');
  });

  test('두 번 열어도 오류 없이 그대로다', () async {
    createOldDatabase(version: 4, boardId: 'board-1');

    final AppDatabase first = AppDatabase.forTesting(NativeDatabase(dbFile));
    await LocalBoardRepository(first).getAllBoards();
    await first.close();

    // 두 번째로 열 때는 이미 schemaVersion이 5라 addColumn이 다시
    // 돌지 않아야 합니다. 다시 돌면 "칼럼이 이미 있다"는 오류가 납니다.
    final AppDatabase second = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(second.close);

    final List<Board> boards = await LocalBoardRepository(second).getAllBoards();
    expect(boards.length, 1);
  });

  test('v4에서 v5로만 건너뛰어도 addColumn이 한 번만 실행된다', () async {
    // 이 테스트가 실제로 확인하는 것: boards 표가 **이미 folder_id 없이
    // 실제로 존재하던** 사용자(v3·v4)는 addColumn이 정상적으로 실행돼야
    // 합니다. 아래 "v1에서 v5로" 테스트와 짝을 이룹니다 — 그쪽은
    // 반대로 addColumn을 **건너뛰어야** 하는 경우입니다.
    createOldDatabase(version: 4, boardId: 'board-1');

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final Board? board = await LocalBoardRepository(db).getBoardById('board-1');
    expect(board, isNotNull, reason: 'addColumn이 실패하면 앱 자체가 안 켜집니다');
  });

  test('v1에서 v5로 한 번에 건너뛰어도 오류 없이 켜진다', () async {
    // ── 실제로 겪은 버그를 잡는 테스트입니다 ──
    // v2→v3 단계의 createTable(boards)는 "지금 이 순간의" tables.dart로
    // 표를 만들어서, 이미 folder_id가 포함된 채로 boards 표가 생깁니다.
    // 그 뒤 v5 단계가 또 addColumn을 하려고 하면 "칼럼이 이미 있다"는
    // 오류로 앱이 아예 안 켜집니다. 한참 업데이트를 안 한 사용자는
    // 정확히 이 경로(v1 → v5 직행)를 지나가므로 반드시 확인해야 합니다.
    createOldDatabase(version: 1);

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    // 앱이 켜졌다는 것 자체가 이 테스트의 핵심입니다. 새 무드보드를
    // 하나 만들어 folderId까지 정상적으로 쓸 수 있는지도 함께 봅니다.
    final LocalBoardRepository repository = LocalBoardRepository(db);
    final DateTime now = DateTime.now().toUtc();
    await repository.saveBoard(
      Board(
        id: 'board-new',
        name: '새 판',
        createdAt: now,
        updatedAt: now,
        folderId: 'folder-1',
      ),
    );

    final Board? saved = await repository.getBoardById('board-new');
    expect(saved, isNotNull);
    expect(saved!.folderId, 'folder-1');
  });
}
