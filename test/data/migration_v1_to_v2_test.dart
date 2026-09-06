// 저장 구조를 바꿀 때(마이그레이션) 기존 데이터가 무사한지 확인하는 테스트입니다.
//
// ── 왜 이게 중요한가 ──
// `CLAUDE.md`에 못 박아둔 실수가 바로 이것입니다.
//
//   "schemaVersion을 올렸으면 migration에 할 일을 반드시 적을 것.
//    안 적으면 새로 설치한 사람은 멀쩡한데 **기존 사용자의 앱만 안 켜집니다.**"
//
// 개발하는 사람은 대개 데이터베이스를 새로 만드는 쪽입니다. 그래서 마이그레이션이
// 잘못돼도 **자기 컴퓨터에서는 아무 문제가 없습니다.** 업데이트한 사용자만 겪습니다.
//
// 그래서 이 테스트는 **일부러 옛날 구조(v1)의 데이터베이스를 만들어놓고**,
// 앱이 그걸 열었을 때 어떻게 되는지를 봅니다. 실제 업데이트 상황과 같습니다.

import 'dart:io';

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
    // 진짜 파일로 만들어야 합니다. 메모리 데이터베이스는 연결을 닫으면
    // 내용이 사라져서, "옛 데이터가 담긴 파일을 새 앱이 여는" 상황을 못 만듭니다.
    tempDir = await Directory.systemTemp.createTemp('migration_test');
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

  /// 옛날 구조(v1)의 데이터베이스 파일을 만듭니다.
  ///
  /// **partId 칸이 없습니다.** 파트 기능이 생기기 전 모습이고,
  /// 지금 의뢰인 컴퓨터에 있는 파일이 딱 이 모양입니다.
  void createVersion1Database({required int referenceCount}) {
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

    // 예전에 넣어둔 레퍼런스들입니다. 이게 무사해야 합니다.
    const String now = '2026-01-01T00:00:00.000Z';
    for (int index = 1; index <= referenceCount; index++) {
      raw.execute(
        'INSERT INTO "references" (id, title, type, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?)',
        <Object>['old-$index', '예전 사진 $index', 'image', now, now],
      );
    }

    // 폴더도 하나 넣어둡니다. 마이그레이션이 다른 분류를 건드리면 안 됩니다.
    raw.execute(
      'INSERT INTO taxonomy_items (id, kind, name, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?)',
      <Object>['folder-1', 'folder', '인물', now, now],
    );

    // 이 숫자가 "이 파일은 v1이다"라는 표시입니다.
    // 이걸 안 적으면 drift가 새 파일로 알고 마이그레이션을 안 합니다.
    raw.execute('PRAGMA user_version = 1');
    raw.close();
  }

  test('옛 구조의 파일을 열어도 앱이 켜지고 레퍼런스가 남아 있다', () async {
    createVersion1Database(referenceCount: 3);

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final LocalReferenceRepository repository = LocalReferenceRepository(db);

    // 여기까지 오면 앱이 안 죽고 켜진 것입니다. 그것부터가 확인입니다.
    final List<ReferenceItem> items = await repository.getAll();

    expect(items.length, 3, reason: '예전에 넣어둔 레퍼런스가 그대로 있어야 합니다');
    expect(
      items.map((ReferenceItem item) => item.title),
      containsAll(<String>['예전 사진 1', '예전 사진 2', '예전 사진 3']),
    );
  });

  test('원래 있던 폴더는 그대로 남는다', () async {
    // 마이그레이션이 다른 분류는 그대로 둬야 합니다.
    createVersion1Database(referenceCount: 1);

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final LocalTaxonomyRepository taxonomyRepository = LocalTaxonomyRepository(
      db,
    );

    final List<TaxonomyItem> folders = await taxonomyRepository.getAll(
      TaxonomyKind.folder,
    );

    expect(folders.length, 1);
    expect(folders.first.name, '인물');
  });
}
