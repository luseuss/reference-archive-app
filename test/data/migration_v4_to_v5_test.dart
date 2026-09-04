// 저장 구조 v4 → v5(무드보드 카드 그룹화) 마이그레이션이 무사한지 확인하는
// 테스트입니다.
//
// 왜 마이그레이션에 테스트가 반드시 필요한지는
// test/data/migration_v1_to_v2_test.dart 맨 위 설명을 보세요. 같은 이유입니다.
//
// 이번 마이그레이션은 BoardCards에 groupId 칸 하나를 추가할 뿐입니다.
// 그런데 **BoardCards 표 자체가 v3에서 처음 생겼다는 점**이 함정입니다.
// v3보다 낮은 버전에서 올라오는 사용자는 이 표를 `createTable`로 지금 막
// 만드는데, 그 함수는 tables.dart의 **지금 코드**를 그대로 읽어서 만들기
// 때문에 groupId 칸이 이미 들어간 채로 만들어집니다. 그 상태에서 v5의
// addColumn을 또 실행하면 "칸이 이미 있다"는 오류가 납니다 — 이 테스트가
// 실제로 잡은 문제이고, `app_database.dart`의 `from >= 3 && from < 5`
// 조건이 그 대응입니다.
//
// 그래서 확인할 것이 평소보다 하나 더 있습니다: **v3보다 낮은 버전에서
// 건너뛰어 올라와도 오류 없이 켜지는지**입니다.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/board.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';
import 'package:reference_archive_app/repositories/local_board_repository.dart';
import 'package:reference_archive_app/repositories/local_taxonomy_repository.dart';
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
  /// [version]에 4를 넘기면 무드보드 카드에 groupId만 없는 v4 모습,
  /// 3을 넘기면 memo가 아직 순수 텍스트인 v3 모습, 1을 넘기면 파트도
  /// 무드보드도 없던 v1 모습입니다.
  ///
  /// [withCard]가 참이면 카드를 하나 만들어 판에 올려둡니다 —
  /// group_id 칸이 없는 채로 저장된 "예전 카드"가 무사한지 보려는 것입니다.
  void createOldDatabase({required int version, bool withCard = false}) {
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

    // v3부터는 무드보드 표 두 개가 이미 있습니다. **group_id 칸은 아직
    // 없습니다** — 이게 진짜 v3~v4 시절의 모습이고, 이 테스트가 확인하려는
    // 것의 핵심입니다.
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
        'INSERT INTO "references" (id, title, type, part_id, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['old-1', '예전 사진', 'image', defaultPartId, now, now],
      );

      raw.execute(
        'INSERT INTO taxonomy_items (id, kind, name, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?)',
        <Object>[defaultPartId, 'part', defaultPartName, now, now],
      );
    } else {
      raw.execute(
        'INSERT INTO "references" (id, title, type, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?)',
        <Object?>['old-1', '예전 사진', 'image', now, now],
      );
    }

    if (version >= 3 && withCard) {
      raw.execute(
        'INSERT INTO boards (id, name, created_at, updated_at) '
        'VALUES (?, ?, ?, ?)',
        <Object>['board-1', '겨울 무드', now, now],
      );

      raw.execute(
        'INSERT INTO board_cards '
        '(id, board_id, reference_id, x, y, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object>['card-1', 'board-1', 'old-1', 100.0, 200.0, now, now],
      );
    }

    raw.execute('PRAGMA user_version = $version');
    raw.close();
  }

  test('앱이 켜지고, 예전 카드는 그룹 없는 상태(null)로 남는다', () async {
    createOldDatabase(version: 4, withCard: true);

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final List<BoardCard> cards = await LocalBoardRepository(
      db,
    ).getCards('board-1');

    expect(cards.length, 1);
    expect(cards.first.groupId, isNull);
  });

  test('그룹을 새로 만들어 저장할 수 있다', () async {
    // ── 이게 이 파일의 핵심입니다 ──
    // 칸을 추가하는 것을 빠뜨리면, 업데이트한 사용자만 그룹으로 묶으려는
    // 순간 "그런 칸 없다"는 오류를 만납니다.
    createOldDatabase(version: 4, withCard: true);

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final LocalBoardRepository boards = LocalBoardRepository(db);
    final List<BoardCard> cards = await boards.getCards('board-1');

    await boards.saveCard(cards.first.copyWith(groupId: 'group-1'));

    final List<BoardCard> updated = await boards.getCards('board-1');
    expect(updated.first.groupId, 'group-1');
  });

  test('두 번 열어도 group_id 칸을 두 번 추가하려 들지 않는다', () async {
    createOldDatabase(version: 4, withCard: true);

    final AppDatabase first = AppDatabase.forTesting(NativeDatabase(dbFile));
    await LocalBoardRepository(first).getCards('board-1');
    await first.close();

    // 두 번째로 열 때 schemaVersion이 이미 5라, addColumn을 다시 시도하면
    // "칸이 이미 있다"는 오류로 앱이 아예 안 켜져야 정상인데, 안 켜지면
    // 이 test 자체가 실패합니다 — 즉 여기까지 오면 통과입니다.
    final AppDatabase second = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(second.close);

    final List<BoardCard> cards = await LocalBoardRepository(
      second,
    ).getCards('board-1');
    expect(cards.length, 1);
  });

  test('v3에서 v5로 한 번에 건너뛰어도 켜진다 (진짜 v3 모습에서 addColumn)', () async {
    // v3는 표가 있지만 group_id 칸은 없는 **진짜** 시절입니다. 이 경우에는
    // addColumn이 실제로 실행돼야 합니다 — v1/v2에서 건너뛰는 경우
    // (createTable이 최신 모습으로 만들어버리는 경우)와 정반대의 함정입니다.
    createOldDatabase(version: 3, withCard: true);

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final List<BoardCard> cards = await LocalBoardRepository(
      db,
    ).getCards('board-1');
    expect(cards.length, 1);
    expect(cards.first.groupId, isNull);
  });

  test('v1에서 v5로 한 번에 건너뛰어도 켜진다 (createTable이 이미 최신 모습으로 만듦)', () async {
    // 한참 업데이트를 안 한 사용자는 1에서 곧장 5로 옵니다. 이때는
    // BoardCards 표 자체가 v3 단계에서 **지금 코드 기준**으로 막 만들어져서
    // group_id가 이미 있는 채로 생기고, v5의 addColumn은 건너뛰어야 합니다.
    // (이걸 못 건너뛰면 "칸이 이미 있다"는 오류로 이 테스트가 실패합니다 —
    // 실제로 이 프로젝트에서 한 번 났던 문제입니다)
    createOldDatabase(version: 1);

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    // v2가 해줘야 할 일
    final List<TaxonomyItem> parts = await LocalTaxonomyRepository(
      db,
    ).getAll(TaxonomyKind.part);
    expect(parts.length, 1, reason: 'v2 단계가 건너뛰어졌습니다');

    // v3이 해줘야 할 일 — 무드보드 표가 있어야 합니다.
    final DateTime now = DateTime.now().toUtc();
    await LocalBoardRepository(db).saveBoard(
      Board(id: 'board-1', name: '겨울 무드', createdAt: now, updatedAt: now),
    );

    // v5가 해줘야 할 일 — 그룹으로 묶어 저장할 수 있어야 합니다.
    final LocalBoardRepository boards = LocalBoardRepository(db);
    await boards.addCards(<BoardCard>[
      BoardCard(
        id: 'card-1',
        boardId: 'board-1',
        referenceId: 'old-1',
        x: 0,
        y: 0,
        groupId: 'group-1',
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    final List<BoardCard> cards = await boards.getCards('board-1');
    expect(
      cards.first.groupId,
      'group-1',
      reason: 'v5 단계가 건너뛰어졌습니다',
    );
  });
}
