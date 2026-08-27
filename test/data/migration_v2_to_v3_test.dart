// 저장 구조 v2 → v3(무드보드) 마이그레이션이 무사한지 확인하는 테스트입니다.
//
// 왜 마이그레이션에 테스트가 반드시 필요한지는
// test/data/migration_v1_to_v2_test.dart 맨 위 설명을 보세요. 같은 이유입니다.
// 짧게 말하면 **개발하는 사람 컴퓨터에서는 절대 재현되지 않는 종류의 문제**이기 때문입니다.
//
// 이번 마이그레이션은 표를 두 개 새로 만들기만 합니다. 그래서 확인할 것은
// "새 표가 진짜로 만들어졌는가"와 "기존 데이터가 안 다쳤는가" 둘입니다.
//
// ── 마지막 테스트가 특히 중요합니다 ──
// v1에서 v3으로 **한 번에 건너뛰는** 경우를 확인합니다. 한참 업데이트를 안 한
// 사용자가 겪는 상황인데, 개발하다 보면 늘 바로 전 버전에서만 올려보게 되어
// 이 경우를 놓치기 쉽습니다.

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
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    // 진짜 파일로 만들어야 합니다. 메모리 데이터베이스는 연결을 닫으면
    // 내용이 사라져서, "옛 데이터가 담긴 파일을 새 앱이 여는" 상황을 못 만듭니다.
    tempDir = await Directory.systemTemp.createTemp('migration_v3_test');
    dbFile = File('${tempDir.path}/reference_archive.sqlite');
  });

  tearDown(() async {
    // 데이터베이스 연결이 아직 안 닫혔으면 지우기가 실패할 수 있습니다.
    // 임시 폴더라 남아도 문제가 없으므로 조용히 넘어갑니다.
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  /// 옛날 구조의 데이터베이스 파일을 만듭니다.
  ///
  /// [version]에 2를 넘기면 파트까지 들어간 v2 모습(무드보드 표가 없는 상태),
  /// 1을 넘기면 파트도 없던 v1 모습입니다.
  ///
  /// `"references"`를 따옴표로 감싼 것에 주의하세요. references는 **SQLite의
  /// 예약어**라서 그냥 쓰면 문법 오류가 납니다. 평소에는 drift가 알아서
  /// 감싸주기 때문에 드러나지 않습니다.
  void createOldDatabase({required int version}) {
    final Database raw = sqlite3.open(dbFile.path);

    // v2에만 있는 칸입니다. v1에는 이 칸이 없었습니다.
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

    const String now = '2026-01-01T00:00:00.000Z';

    // 예전에 넣어둔 레퍼런스입니다. 이게 무사해야 합니다.
    if (version >= 2) {
      raw.execute(
        'INSERT INTO "references" (id, title, type, part_id, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        <Object>['old-1', '예전 사진', 'image', defaultPartId, now, now],
      );

      // v2 파일에는 기본 파트가 이미 들어 있습니다.
      raw.execute(
        'INSERT INTO taxonomy_items (id, kind, name, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?)',
        <Object>[defaultPartId, 'part', defaultPartName, now, now],
      );
    } else {
      raw.execute(
        'INSERT INTO "references" (id, title, type, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?)',
        <Object>['old-1', '예전 사진', 'image', now, now],
      );
    }

    // 이 숫자가 "이 파일은 몇 번 구조인가"라는 표시입니다.
    // 이걸 안 적으면 drift가 새 파일로 알고 마이그레이션을 건너뜁니다.
    raw.execute('PRAGMA user_version = $version');
    raw.close();
  }

  /// 테스트용 무드보드 하나를 만들어 돌려줍니다.
  Board makeBoard(String name) {
    final DateTime now = DateTime.now().toUtc();
    return Board(id: 'board-$name', name: name, createdAt: now, updatedAt: now);
  }

  test('v2 파일을 열어도 앱이 켜지고 예전 레퍼런스가 남아 있다', () async {
    createOldDatabase(version: 2);

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    // 여기까지 오면 앱이 안 죽고 켜진 것입니다. 그것부터가 확인입니다.
    final List<ReferenceItem> items = await LocalReferenceRepository(db)
        .getAll();

    expect(items.length, 1);
    expect(items.first.title, '예전 사진');
    expect(items.first.partId, defaultPartId, reason: '파트 연결이 그대로여야 합니다');
  });

  test('무드보드 표가 새로 만들어져서 판을 저장할 수 있다', () async {
    // ── 이게 이 파일의 핵심입니다 ──
    // 표를 만드는 것을 빠뜨리면, 새로 설치한 사람은 멀쩡한데(createAll이 다 만듦)
    // **업데이트한 사용자만** 무드보드를 열자마자 "그런 표 없다"는 오류를 만납니다.
    createOldDatabase(version: 2);

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final LocalBoardRepository boards = LocalBoardRepository(db);

    await boards.saveBoard(makeBoard('겨울 무드'));

    final List<Board> saved = await boards.getAllBoards();
    expect(saved.length, 1);
    expect(saved.first.name, '겨울 무드');
  });

  test('판 위에 카드도 올릴 수 있다', () async {
    // 표가 둘인데 하나만 만들어도 위 테스트는 통과합니다. 그래서 따로 확인합니다.
    createOldDatabase(version: 2);

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final LocalBoardRepository boards = LocalBoardRepository(db);
    final Board board = makeBoard('겨울 무드');
    await boards.saveBoard(board);

    final DateTime now = DateTime.now().toUtc();
    await boards.addCards(<BoardCard>[
      BoardCard(
        id: 'card-1',
        boardId: board.id,
        referenceId: 'old-1',
        x: 100,
        y: 200,
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    final List<BoardCard> cards = await boards.getCards(board.id);
    expect(cards.length, 1);
    expect(cards.first.x, 100);
    expect(cards.first.y, 200);
  });

  test('두 번 열어도 판이 그대로 있다', () async {
    // 앱을 껐다 켜는 것과 같은 상황입니다. 마이그레이션을 또 돌리면서
    // 표를 다시 만들어버리면 안에 있던 판이 사라집니다.
    createOldDatabase(version: 2);

    final AppDatabase first = AppDatabase.forTesting(NativeDatabase(dbFile));
    await LocalBoardRepository(first).saveBoard(makeBoard('겨울 무드'));
    await first.close();

    final AppDatabase second = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(second.close);

    final List<Board> boards = await LocalBoardRepository(second)
        .getAllBoards();
    expect(boards.length, 1);
    expect(boards.first.name, '겨울 무드');
  });

  test('v1에서 v3으로 한 번에 건너뛰어도 둘 다 적용된다', () async {
    // ── 왜 이걸 따로 확인하나 ──
    // 한참 업데이트를 안 한 사용자는 1에서 곧장 3으로 옵니다.
    // migration을 `if (from == 2)`처럼 등호로 적어두면 그런 사용자는
    // 무드보드 표를 못 받아서 앱이 죽습니다. 부등호(`from < 3`)로 적어야
    // 필요한 단계가 차례로 다 실행됩니다.
    createOldDatabase(version: 1);

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    // v2가 해줘야 할 일 — 예전 레퍼런스가 기본 파트에 들어가 있어야 합니다.
    final List<ReferenceItem> items = await LocalReferenceRepository(db)
        .getAll();
    expect(items.first.partId, defaultPartId, reason: 'v2 단계가 건너뛰어졌습니다');

    final List<TaxonomyItem> parts = await LocalTaxonomyRepository(db)
        .getAll(TaxonomyKind.part);
    expect(parts.length, 1);

    // v3이 해줘야 할 일 — 무드보드 표가 있어야 합니다.
    await LocalBoardRepository(db).saveBoard(makeBoard('겨울 무드'));
    expect(
      (await LocalBoardRepository(db).getAllBoards()).length,
      1,
      reason: 'v3 단계가 건너뛰어졌습니다',
    );
  });
}
