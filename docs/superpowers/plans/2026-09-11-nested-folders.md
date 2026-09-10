# 폴더 중첩(하위 폴더) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 사이드바와 분류 관리 화면의 폴더에 하위 폴더(중첩, 무제한 깊이)를 추가하고, 상위 폴더를 고르면 하위 폴더의 레퍼런스도 함께 보이게 한다.

**Architecture:** `TaxonomyItems` 테이블에 `parentId`(자기 참조, nullable) 칼럼 하나를 추가한다. 트리 계산(깊이, 하위 id 모으기, 순환 검사)은 전부 `lib/utils/folder_tree.dart`의 순수 함수로 뽑아 저장소·다이얼로그·사이드바가 공통으로 쓴다. 레퍼런스 조회는 저장소 한 곳(`LocalReferenceRepository.search`)에서만 "폴더 자신+하위"로 확장하므로, 그 위의 화면 코드는 손대지 않아도 규칙이 전부 적용된다.

**Tech Stack:** Flutter, drift(sqlite), 기존 프로젝트 관례(Repository 패턴, 순수 함수 유틸, 위젯 테스트).

**Spec:** `docs/superpowers/specs/2026-09-11-nested-folders-design.md`

## Global Constraints

- 모든 새 파일 상단에 그 파일의 역할을 한국어로 설명하는 주석을 단다.
- 모든 새 함수/메서드 위에 한국어 한 줄 주석을 단다. "왜 이렇게 했는지"가
  자명하지 않으면 이유도 적는다.
- 영리하지만 읽기 어려운 코드보다 길더라도 읽기 쉬운 코드를 택한다.
- 각 태스크가 끝나면 `flutter analyze`와 관련 `flutter test`가 통과해야 한다.
- drift 표 정의(`lib/data/tables.dart`)를 고친 태스크(Task 1)는 반드시
  `dart run build_runner build`를 돌려야 한다(5~7분 소요).
- 마이그레이션은 반드시 실제 sqlite로 만든 "옛날 모양" 데이터베이스를 열어
  검증한다(문서만 믿지 않는다 — CLAUDE.md 관례).
- 새 브랜치(`nested-folders`, 이미 만들어져 있음)에서 작업하고, `main`에는
  직접 커밋하지 않는다. 각 태스크 끝에 커밋한다.

---

## Task 1: 데이터 모델 — parentId 칼럼 + 저장 구조 v7

**Files:**
- Modify: `lib/data/tables.dart` (`TaxonomyItems` 클래스, 현재 91-112행)
- Modify: `lib/data/app_database.dart` (`schemaVersion`, `migration`, 새 `_upgradeToVersion7`)
- Modify: `lib/models/taxonomy_item.dart`
- Test: `test/data/migration_v6_to_v7_test.dart` (신규)

**Interfaces:**
- Produces: `TaxonomyItem.parentId`(`String?`, named optional, 기본 null) — 이후
  모든 태스크가 이 필드를 씁니다.
- Produces: `taxonomyItems.parentId` drift 칼럼(생성 코드에
  `TaxonomyItemRow.parentId`, `TaxonomyItemsCompanion.parentId`로 나타남).

- [ ] **Step 1: `TaxonomyItem`에 `parentId` 필드 추가**

`lib/models/taxonomy_item.dart`를 엽니다. 생성자와 필드를 이렇게 바꿉니다.

```dart
class TaxonomyItem {
  TaxonomyItem({
    required this.id,
    required this.kind,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
  });

  /// 고유 번호(UUID v4)
  final String id;

  /// 폴더/카테고리/태그/프로젝트 중 무엇인지
  final TaxonomyKind kind;

  /// 사용자가 붙인 이름
  final String name;

  /// 상위 폴더의 id입니다. null이면 최상위(하위 폴더가 아님)입니다.
  ///
  /// 폴더(kind가 folder)일 때만 의미가 있습니다 — 카테고리·태그·프로젝트는
  /// 항상 null입니다. 이 값을 바꾸는 건 copyWith가 아니라
  /// TaxonomyRepository.moveFolder()를 통해서만 합니다(순환 참조 검사가
  /// 거기 있습니다).
  final String? parentId;

  /// 만든 시각 (UTC)
  final DateTime createdAt;

  /// 마지막으로 고친 시각 (UTC)
  final DateTime updatedAt;

  /// 몇 가지만 바꾼 사본을 만들어 돌려줍니다.
  /// 왜 이런 방식인지는 reference_item.dart의 copyWith 설명을 보세요.
  ///
  /// parentId는 여기서 못 바꿉니다 — 상위 폴더를 바꾸는 건
  /// TaxonomyRepository.moveFolder()를 쓰세요(순환 참조 검사가 필요해서
  /// 저장소 쪽 책임입니다).
  TaxonomyItem copyWith({String? name, DateTime? updatedAt}) {
    return TaxonomyItem(
      id: id,
      kind: kind,
      name: name ?? this.name,
      parentId: parentId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
```

- [ ] **Step 2: `TaxonomyItems` 표에 `parentId` 칼럼 추가**

`lib/data/tables.dart`의 `TaxonomyItems` 클래스에서 `name` 칼럼 바로 아래에
추가합니다.

```dart
  /// 사용자가 붙인 이름입니다.
  TextColumn get name => text()();

  /// 상위 폴더의 id입니다. null이면 최상위(하위 폴더가 아님)입니다.
  /// 폴더(kind='folder')만 씁니다 — 카테고리·태그·프로젝트는 항상 null입니다.
  TextColumn get parentId => text().nullable()();
```

- [ ] **Step 3: 코드 생성기 실행**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `lib/data/app_database.g.dart`가 다시 생성되고, `$TaxonomyItemsTable`에
`parentId` 칼럼과 `TaxonomyItemRow.parentId`, `TaxonomyItemsCompanion.parentId`가
생긴다. 5~7분 걸릴 수 있습니다.

- [ ] **Step 4: schemaVersion을 7로 올리고 버전 기록에 추가**

`lib/data/app_database.dart`의 버전 기록 주석과 `schemaVersion`을 고칩니다.

```dart
  ///   6 — 파트(Part) 개념을 없앰. References.partId 칼럼 삭제,
  ///       taxonomy_items의 kind='part' 행 삭제
  ///   7 — TaxonomyItems에 parentId 추가 (폴더 중첩)
  @override
  int get schemaVersion => 7;
```

- [ ] **Step 5: `_upgradeToVersion7` 추가 + `migration`에 연결**

`onUpgrade` 안, `if (from < 6) { await _upgradeToVersion6(m); }` 바로 다음에
추가합니다.

```dart
        if (from < 7) {
          await _upgradeToVersion7(m);
        }
```

클래스 안, `_upgradeToVersion6` 메서드 바로 다음에 추가합니다.

```dart
  /// 버전 6 → 7. 폴더에 상위 폴더(parentId) 칸을 추가합니다(폴더 중첩).
  ///
  /// nullable 칸을 addColumn으로 더하기만 하면 됩니다. 기존 폴더는 전부
  /// "아직 상위가 없는"(null) 상태로 시작합니다 — 전부 최상위 폴더가 되고,
  /// 데이터 손실은 없습니다.
  ///
  /// ── 왜 v5(boards.folderId)처럼 특수한 부등호 조건이 필요 없나 ──
  /// v5는 `from >= 3 && from < 5`라는 특수 조건이 필요했습니다. boards
  /// 표가 v3에서 `createTable`로 **그 시점의 tables.dart 정의**로 막 만들어져,
  /// v1/v2에서 건너뛰어 온 사용자는 이미 folderId가 있는 채로 시작하기
  /// 때문입니다. taxonomy_items는 schemaVersion 1부터 onCreate(createAll)로만
  /// 만들어졌고, 그 뒤로 어떤 버전도 createTable로 다시 만든 적이 없습니다
  /// (v3는 boards/boardCards만 만듭니다). 그래서 이 표는 "새로 만들 때
  /// 현재 정의를 쓰는" 문제에서 애초에 자유롭고, 그냥 `from < 7`이면 됩니다.
  Future<void> _upgradeToVersion7(Migrator m) async {
    await m.addColumn(taxonomyItems, taxonomyItems.parentId);
  }
```

- [ ] **Step 6: 마이그레이션 테스트 작성**

Create `test/data/migration_v6_to_v7_test.dart`:

```dart
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
```

- [ ] **Step 7: 테스트 실행**

Run: `flutter test test/data/migration_v6_to_v7_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 8: 기존 테스트가 깨지지 않았는지 전체 확인**

Run: `flutter analyze && flutter test`
Expected: `TaxonomyItem(...)`을 `parentId` 없이 만드는 기존 테스트/코드는
`parentId`가 옵션(기본 null)이라 그대로 컴파일됩니다. 전부 PASS.

- [ ] **Step 9: 커밋**

```bash
git add lib/data/tables.dart lib/data/app_database.dart lib/data/app_database.g.dart \
  lib/models/taxonomy_item.dart test/data/migration_v6_to_v7_test.dart
git commit -m "저장 구조 v7: TaxonomyItems에 parentId를 추가한다"
```

---

## Task 2: 순수 함수 — lib/utils/folder_tree.dart

**Files:**
- Create: `lib/utils/folder_tree.dart`
- Test: `test/utils/folder_tree_test.dart`

**Interfaces:**
- Consumes: `TaxonomyItem`(id, parentId, name) — Task 1에서 만듦.
- Produces: `class FolderTreeEntry { TaxonomyItem folder; int depth; }`,
  `Set<String> collectFolderAndDescendantIds(String rootId, Map<String, String?> parentById)`,
  `Map<String, String?> parentIdMap(List<TaxonomyItem> folders)`,
  `List<FolderTreeEntry> buildFolderTree(List<TaxonomyItem> allFolders, {Set<String> excludeIds})`
  — 이후 모든 태스크(저장소, 다이얼로그, 사이드바, 관리 화면)가 이 네 가지를 씁니다.

- [ ] **Step 1: 실패하는 테스트부터 작성**

Create `test/utils/folder_tree_test.dart`:

```dart
// lib/utils/folder_tree.dart의 순수 함수들을 확인하는 테스트입니다.

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';
import 'package:reference_archive_app/utils/folder_tree.dart';

void main() {
  /// 테스트용 폴더를 하나 만듭니다.
  TaxonomyItem folder(String id, String name, {String? parentId}) {
    final DateTime now = DateTime.utc(2026, 1, 1);
    return TaxonomyItem(
      id: id,
      kind: TaxonomyKind.folder,
      name: name,
      parentId: parentId,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('parentIdMap', () {
    test('id별로 parentId 표를 만든다', () {
      final List<TaxonomyItem> all = <TaxonomyItem>[
        folder('a', '인물'),
        folder('b', '얼굴', parentId: 'a'),
      ];

      expect(parentIdMap(all), <String, String?>{'a': null, 'b': 'a'});
    });
  });

  group('collectFolderAndDescendantIds', () {
    test('자기 자신만 있으면 자기 자신만 돌려준다', () {
      final Map<String, String?> map = parentIdMap(<TaxonomyItem>[folder('a', '인물')]);

      expect(collectFolderAndDescendantIds('a', map), <String>{'a'});
    });

    test('자식과 손자까지 모은다', () {
      final Map<String, String?> map = parentIdMap(<TaxonomyItem>[
        folder('a', '인물'),
        folder('b', '얼굴', parentId: 'a'),
        folder('c', '포즈', parentId: 'a'),
        folder('d', '옆얼굴', parentId: 'b'),
        folder('e', '풍경'), // 무관한 최상위 폴더
      ]);

      expect(
        collectFolderAndDescendantIds('a', map),
        <String>{'a', 'b', 'c', 'd'},
      );
    });

    test('형제의 하위는 포함하지 않는다', () {
      final Map<String, String?> map = parentIdMap(<TaxonomyItem>[
        folder('a', '인물'),
        folder('b', '얼굴', parentId: 'a'),
        folder('c', '포즈', parentId: 'a'),
        folder('d', '옆얼굴', parentId: 'b'),
      ]);

      expect(collectFolderAndDescendantIds('c', map), <String>{'c'});
    });
  });

  group('buildFolderTree', () {
    test('빈 목록이면 빈 트리를 돌려준다', () {
      expect(buildFolderTree(<TaxonomyItem>[]), isEmpty);
    });

    test('최상위 폴더끼리는 이름 가나다순이다', () {
      final List<TaxonomyItem> all = <TaxonomyItem>[
        folder('a', '풍경'),
        folder('b', '건축'),
        folder('c', '인물'),
      ];

      final List<FolderTreeEntry> tree = buildFolderTree(all);

      expect(
        tree.map((FolderTreeEntry e) => e.folder.name).toList(),
        <String>['건축', '인물', '풍경'],
      );
      expect(tree.every((FolderTreeEntry e) => e.depth == 0), isTrue);
    });

    test('부모 바로 다음에 자식이 오고 깊이가 늘어난다', () {
      final List<TaxonomyItem> all = <TaxonomyItem>[
        folder('a', '인물'),
        folder('b', '얼굴', parentId: 'a'),
        folder('c', '포즈', parentId: 'a'),
        folder('d', '옆얼굴', parentId: 'b'),
        folder('e', '풍경'),
      ];

      final List<FolderTreeEntry> tree = buildFolderTree(all);

      expect(
        tree.map((FolderTreeEntry e) => '${e.folder.name}:${e.depth}').toList(),
        <String>['인물:0', '얼굴:1', '옆얼굴:2', '포즈:1', '풍경:0'],
      );
    });

    test('excludeIds에 넣은 폴더와 그 하위는 빠진다', () {
      final List<TaxonomyItem> all = <TaxonomyItem>[
        folder('a', '인물'),
        folder('b', '얼굴', parentId: 'a'),
        folder('c', '옆얼굴', parentId: 'b'),
        folder('d', '풍경'),
      ];

      final List<FolderTreeEntry> tree = buildFolderTree(
        all,
        excludeIds: <String>{'b', 'c'},
      );

      expect(
        tree.map((FolderTreeEntry e) => e.folder.name).toList(),
        <String>['인물', '풍경'],
      );
    });
  });
}
```

- [ ] **Step 2: 테스트 실행해서 실패 확인**

Run: `flutter test test/utils/folder_tree_test.dart`
Expected: FAIL — `lib/utils/folder_tree.dart`가 없어서 import 오류.

- [ ] **Step 3: 구현**

Create `lib/utils/folder_tree.dart`:

```dart
// 폴더의 부모-자식 관계를 계산하는 순수 함수 모음입니다.
//
// "순수 함수"로 뽑아둔 이유는 lib/utils/board_layout.dart와 같습니다 —
// 데이터베이스나 화면 없이, 폴더 목록만 넣으면 결과가 나와서 앱을 안
// 띄우고 테스트할 수 있습니다.
//
// 여기 있는 함수들은 전부 "폴더"(TaxonomyKind.folder)만 다룹니다. 카테고리·
// 태그·프로젝트는 parentId가 항상 null이라 애초에 트리를 이룰 일이 없습니다.

import '../models/taxonomy_item.dart';

/// 폴더 하나와 트리에서의 깊이(최상위 = 0)를 함께 담는 값입니다.
class FolderTreeEntry {
  const FolderTreeEntry({required this.folder, required this.depth});

  /// 이 자리의 폴더입니다.
  final TaxonomyItem folder;

  /// 트리에서의 깊이입니다. 최상위 폴더는 0, 그 하위는 1, 그 하위는 2...
  final int depth;
}

/// [folders] 목록에서 (id → parentId) 표를 만듭니다.
///
/// [collectFolderAndDescendantIds]에 넘길 때 씁니다. 저장소 쪽처럼
/// TaxonomyItem 전체를 만들기보다 (id, parentId)만 가벼운 쿼리로 읽어온
/// 곳에서도 같은 함수를 쓸 수 있도록, 그 계산 결과와 이 표는 형태가
/// 같습니다.
Map<String, String?> parentIdMap(List<TaxonomyItem> folders) {
  return <String, String?>{
    for (final TaxonomyItem folder in folders) folder.id: folder.parentId,
  };
}

/// [rootId]와 그 아래 모든 하위 폴더(자식, 손자, ...)의 id를 모아 돌려줍니다.
/// [rootId] 자신도 결과에 포함됩니다.
///
/// [parentById]는 (폴더 id → 그 폴더의 상위 폴더 id) 표입니다. 폴더를
/// 지울 때(하위까지 함께 지우기), 폴더를 옮길 때(순환 방지) 둘 다
/// "이 폴더 아래로는 못 간다/지운다"는 집합이 필요해서 하나로 묶었습니다.
Set<String> collectFolderAndDescendantIds(
  String rootId,
  Map<String, String?> parentById,
) {
  final Map<String, List<String>> childrenOf = <String, List<String>>{};
  parentById.forEach((String id, String? parentId) {
    if (parentId != null) {
      childrenOf.putIfAbsent(parentId, () => <String>[]).add(id);
    }
  });

  final Set<String> collected = <String>{rootId};
  final List<String> toVisit = <String>[rootId];

  while (toVisit.isNotEmpty) {
    final String currentId = toVisit.removeLast();
    for (final String childId in childrenOf[currentId] ?? const <String>[]) {
      // add()가 false를 돌려주면 이미 방문한 것입니다. 데이터가 깨져서
      // parentId가 순환을 이루더라도(정상 경로로는 안 생기지만) 무한
      // 루프에 빠지지 않도록 막아줍니다.
      if (collected.add(childId)) {
        toVisit.add(childId);
      }
    }
  }

  return collected;
}

/// 폴더 목록을 트리 순서로 펼칩니다.
///
/// 부모 바로 다음에 그 자식들이 오고, 형제끼리는 이름 가나다순입니다.
/// [excludeIds]에 들어있는 폴더는 결과에서 빠집니다 — **그 하위도 자동으로
/// 함께 빠집니다**(parentId 체인이 끊어져서 더 이상 안 걸리기 때문입니다).
/// 그래서 이 인자에는 항상 [collectFolderAndDescendantIds]로 구한 "자기
/// 자신+하위 전체" 집합을 넘기세요 — 하위 일부만 빠진 어중간한 집합을
/// 넘기면 그 하위가 트리에서 통째로 안 보이게 됩니다(부모가 없어져서).
///
/// 예: 폴더를 옮길 때 "자기 자신과 자기 하위"를 상위 폴더 후보에서
/// 빼는 용도로 씁니다.
List<FolderTreeEntry> buildFolderTree(
  List<TaxonomyItem> allFolders, {
  Set<String> excludeIds = const <String>{},
}) {
  final List<TaxonomyItem> eligible = allFolders
      .where((TaxonomyItem folder) => !excludeIds.contains(folder.id))
      .toList();

  final Map<String?, List<TaxonomyItem>> childrenByParent =
      <String?, List<TaxonomyItem>>{};
  for (final TaxonomyItem folder in eligible) {
    childrenByParent
        .putIfAbsent(folder.parentId, () => <TaxonomyItem>[])
        .add(folder);
  }
  for (final List<TaxonomyItem> siblings in childrenByParent.values) {
    siblings.sort((TaxonomyItem a, TaxonomyItem b) => a.name.compareTo(b.name));
  }

  final List<FolderTreeEntry> result = <FolderTreeEntry>[];

  void addChildrenOf(String? parentId, int depth) {
    for (final TaxonomyItem folder
        in childrenByParent[parentId] ?? const <TaxonomyItem>[]) {
      result.add(FolderTreeEntry(folder: folder, depth: depth));
      addChildrenOf(folder.id, depth + 1);
    }
  }

  addChildrenOf(null, 0);
  return result;
}
```

- [ ] **Step 4: 테스트 실행해서 통과 확인**

Run: `flutter test test/utils/folder_tree_test.dart`
Expected: PASS (모든 테스트)

- [ ] **Step 5: 커밋**

```bash
git add lib/utils/folder_tree.dart test/utils/folder_tree_test.dart
git commit -m "폴더 트리를 계산하는 순수 함수 folder_tree.dart를 추가한다"
```

---

## Task 3: TaxonomyRepository — moveFolder, existsWithName 범위, 연쇄 삭제

**Files:**
- Modify: `lib/repositories/taxonomy_repository.dart`
- Modify: `lib/repositories/local_taxonomy_repository.dart`
- Test: `test/repositories/local_taxonomy_repository_test.dart`

**Interfaces:**
- Consumes: Task 2의 `collectFolderAndDescendantIds`, `parentIdMap`.
- Produces: `TaxonomyRepository.moveFolder(String id, String? newParentId)`,
  `class FolderMoveCycleException implements Exception`,
  `existsWithName(TaxonomyKind kind, String name, {String? excludeId, String? parentId})`
  (parentId가 새 인자) — Task 6, 7, 10이 이 셋을 씁니다.

- [ ] **Step 1: 실패하는 테스트부터 작성**

`test/repositories/local_taxonomy_repository_test.dart`를 엽니다.
`makeItem` 도우미 아래, 기존 `group('이름 중복 검사', ...)` 앞에 새 그룹을
추가합니다(파일 맨 아래, 마지막 `});` 앞).

```dart
  group('moveFolder', () {
    test('상위 폴더를 옮길 수 있다', () async {
      final TaxonomyItem parent = makeItem(TaxonomyKind.folder, '인물');
      final TaxonomyItem child = makeItem(TaxonomyKind.folder, '풍경');
      await repository.save(parent);
      await repository.save(child);

      await repository.moveFolder(child.id, parent.id);

      final TaxonomyItem? reloaded = await repository.getById(child.id);
      expect(reloaded!.parentId, parent.id);
    });

    test('null로 옮기면 최상위가 된다', () async {
      final TaxonomyItem parent = makeItem(TaxonomyKind.folder, '인물');
      final TaxonomyItem child = makeItem(TaxonomyKind.folder, '얼굴');
      await repository.save(parent);
      await repository.save(child);
      await repository.moveFolder(child.id, parent.id);

      await repository.moveFolder(child.id, null);

      final TaxonomyItem? reloaded = await repository.getById(child.id);
      expect(reloaded!.parentId, isNull);
    });

    test('자기 자신을 상위로 지정하면 예외가 난다', () async {
      final TaxonomyItem folder = makeItem(TaxonomyKind.folder, '인물');
      await repository.save(folder);

      expect(
        () => repository.moveFolder(folder.id, folder.id),
        throwsA(isA<FolderMoveCycleException>()),
      );
    });

    test('자기 하위를 상위로 지정하면 예외가 나고 바뀌지 않는다', () async {
      final TaxonomyItem parent = makeItem(TaxonomyKind.folder, '인물');
      final TaxonomyItem child = makeItem(TaxonomyKind.folder, '얼굴');
      await repository.save(parent);
      await repository.save(child);
      await repository.moveFolder(child.id, parent.id);

      await expectLater(
        () => repository.moveFolder(parent.id, child.id),
        throwsA(isA<FolderMoveCycleException>()),
      );

      final TaxonomyItem? reloadedParent = await repository.getById(parent.id);
      expect(reloadedParent!.parentId, isNull, reason: '실패했으니 안 바뀌어야 합니다');
    });
  });

  group('이름 중복 검사 — 상위 폴더별로', () {
    test('부모가 다르면 같은 이름을 써도 중복이 아니다', () async {
      final TaxonomyItem parentA = makeItem(TaxonomyKind.folder, '인물');
      final TaxonomyItem parentB = makeItem(TaxonomyKind.folder, '풍경');
      await repository.save(parentA);
      await repository.save(parentB);
      final TaxonomyItem childA = makeItem(TaxonomyKind.folder, '얼굴');
      await repository.save(childA);
      await repository.moveFolder(childA.id, parentA.id);

      expect(
        await repository.existsWithName(
          TaxonomyKind.folder,
          '얼굴',
          parentId: parentB.id,
        ),
        isFalse,
      );
    });

    test('같은 부모 밑이면 중복이다', () async {
      final TaxonomyItem parent = makeItem(TaxonomyKind.folder, '인물');
      await repository.save(parent);
      final TaxonomyItem child = makeItem(TaxonomyKind.folder, '얼굴');
      await repository.save(child);
      await repository.moveFolder(child.id, parent.id);

      expect(
        await repository.existsWithName(
          TaxonomyKind.folder,
          '얼굴',
          parentId: parent.id,
        ),
        isTrue,
      );
    });
  });

  group('하위 폴더 연쇄 삭제', () {
    test('폴더를 지우면 하위 폴더도 함께 지워진다', () async {
      final TaxonomyItem parent = makeItem(TaxonomyKind.folder, '인물');
      await repository.save(parent);
      final TaxonomyItem child = makeItem(TaxonomyKind.folder, '얼굴');
      await repository.save(child);
      await repository.moveFolder(child.id, parent.id);
      final TaxonomyItem grandchild = makeItem(TaxonomyKind.folder, '눈');
      await repository.save(grandchild);
      await repository.moveFolder(grandchild.id, child.id);

      await repository.delete(parent.id);

      expect(await repository.getById(parent.id), isNull);
      expect(await repository.getById(child.id), isNull);
      expect(await repository.getById(grandchild.id), isNull);
    });

    test('하위 폴더에 있던 레퍼런스도 폴더 없음이 된다', () async {
      final TaxonomyItem parent = makeItem(TaxonomyKind.folder, '인물');
      await repository.save(parent);
      final TaxonomyItem child = makeItem(TaxonomyKind.folder, '얼굴');
      await repository.save(child);
      await repository.moveFolder(child.id, parent.id);

      final LocalReferenceRepository referenceRepository =
          LocalReferenceRepository(db);
      final DateTime now = DateTime.now().toUtc();
      final ReferenceItem photo = ReferenceItem(
        id: newId(),
        type: ReferenceType.image,
        title: '눈매',
        folderId: child.id,
        fileName: '${newId()}.jpg',
        createdAt: now,
        updatedAt: now,
      );
      await referenceRepository.save(photo);

      await repository.delete(parent.id);

      final ReferenceItem? reloaded = await referenceRepository.getById(photo.id);
      expect(reloaded!.folderId, isNull);
    });

    test('형제 폴더는 지워지지 않는다', () async {
      final TaxonomyItem parent = makeItem(TaxonomyKind.folder, '인물');
      await repository.save(parent);
      final TaxonomyItem childA = makeItem(TaxonomyKind.folder, '얼굴');
      await repository.save(childA);
      await repository.moveFolder(childA.id, parent.id);
      final TaxonomyItem sibling = makeItem(TaxonomyKind.folder, '풍경');
      await repository.save(sibling);

      await repository.delete(parent.id);

      expect(await repository.getById(sibling.id), isNotNull);
    });
  });
```

- [ ] **Step 2: 테스트 실행해서 실패 확인**

Run: `flutter test test/repositories/local_taxonomy_repository_test.dart`
Expected: FAIL — `moveFolder`, `FolderMoveCycleException`, `existsWithName`의
`parentId` 인자가 아직 없어서 컴파일 오류.

- [ ] **Step 3: 인터페이스에 추가**

`lib/repositories/taxonomy_repository.dart`를 엽니다. import 아래에 예외
클래스를 추가합니다.

```dart
import '../models/enums.dart';
import '../models/taxonomy_item.dart';

/// 폴더를 순환이 생기는 위치로 옮기려 할 때 [TaxonomyRepository.moveFolder]가
/// 던지는 예외입니다(자기 자신이나 자기 하위를 자신의 상위로 지정하려는 경우).
class FolderMoveCycleException implements Exception {
  const FolderMoveCycleException();
}
```

`delete` 메서드 바로 다음에 추가합니다.

```dart
  /// 폴더의 상위 폴더를 바꿉니다. [newParentId]가 null이면 최상위로 옮깁니다.
  ///
  /// 폴더(kind가 folder)에만 부르세요 — 카테고리 등은 부모 개념이 없습니다.
  /// 순환이 생기는 이동(자기 자신이나 자기 하위를 상위로 지정)은
  /// [FolderMoveCycleException]을 던지고 아무것도 바꾸지 않습니다.
  Future<void> moveFolder(String id, String? newParentId);
```

`existsWithName` 시그니처를 바꿉니다(주석도 갱신).

```dart
  /// 같은 종류 안에 같은 이름이 이미 있는지 확인합니다.
  ///
  /// 폴더는 **같은 상위 폴더([parentId]) 밑에서만** 겹치는지 봅니다 — 다른
  /// 가지에서는 같은 이름을 써도 됩니다. 카테고리·태그·프로젝트는 부모
  /// 개념이 없어서([parentId]를 안 넘기면) 지금처럼 전체 기준입니다.
  ///
  /// [excludeId]는 이름 바꾸기를 할 때 자기 자신은 빼고 검사하려고 쓰는 값입니다.
  Future<bool> existsWithName(
    TaxonomyKind kind,
    String name, {
    String? excludeId,
    String? parentId,
  });
```

- [ ] **Step 4: LocalTaxonomyRepository 구현**

`lib/repositories/local_taxonomy_repository.dart`를 엽니다. import에 추가합니다.

```dart
import '../utils/folder_tree.dart';
```

`save()`의 `TaxonomyItemsCompanion.insert(...)`에 `parentId`를 추가합니다.

```dart
    await _db.into(_db.taxonomyItems).insertOnConflictUpdate(
          TaxonomyItemsCompanion.insert(
            id: item.id,
            kind: item.kind.storedName,
            name: item.name,
            // Value로 명시적으로 감싸야 null도 그대로 저장됩니다. 그냥
            // item.parentId만 넘기면(감싸지 않으면) "이 칸은 안 건드린다"는
            // 뜻이 되어, 최상위로 옮긴 것(null로 바꾼 것)이 저장되지 않습니다.
            // (local_board_repository.dart의 folderId와 같은 이유입니다)
            parentId: Value<String?>(item.parentId),
            createdAt: item.createdAt,
            updatedAt: now,
          ),
        );
```

`existsWithName`을 통째로 바꿉니다.

```dart
  /// 같은 종류 안에, 폴더라면 같은 상위 폴더 밑에 같은 이름이 이미 있는지
  /// 확인합니다.
  @override
  Future<bool> existsWithName(
    TaxonomyKind kind,
    String name, {
    String? excludeId,
    String? parentId,
  }) async {
    final String normalized = name.trim().toLowerCase();

    final SimpleSelectStatement<$TaxonomyItemsTable, TaxonomyItemRow> query =
        _db.select(_db.taxonomyItems)
          ..where(($TaxonomyItemsTable t) =>
              t.kind.equals(kind.storedName) & t.deletedAt.isNull());

    final List<TaxonomyItemRow> rows = await query.get();

    for (final TaxonomyItemRow row in rows) {
      if (excludeId != null && row.id == excludeId) {
        continue;
      }
      // 같은 상위 폴더 밑에 있는 것만 비교합니다. 카테고리·태그·프로젝트는
      // parentId가 늘 null이라(호출하는 쪽도 안 넘기므로) 지금처럼 전체
      // 기준 그대로입니다.
      if (row.parentId != parentId) {
        continue;
      }
      if (row.name.trim().toLowerCase() == normalized) {
        return true;
      }
    }
    return false;
  }
```

`delete()`를 통째로 바꿉니다.

```dart
  /// 항목을 지웁니다(소프트 삭제). 이 항목을 쓰던 레퍼런스도 함께 정리합니다.
  ///
  /// 폴더라면 하위 폴더(자식, 손자, ...)까지 전부 함께 지웁니다.
  @override
  Future<void> delete(String id) async {
    final DateTime now = DateTime.now().toUtc();

    await _db.transaction(() async {
      final Set<String> idsToDelete = await _folderAndDescendantIds(id);

      await (_db.update(_db.taxonomyItems)
            ..where(($TaxonomyItemsTable t) => t.id.isIn(idsToDelete)))
          .write(TaxonomyItemsCompanion(
        deletedAt: Value<DateTime?>(now),
        updatedAt: Value<DateTime>(now),
      ));

      // 태그·프로젝트로 쓰이던 연결을 끊습니다.
      await (_db.update(_db.referenceTaxonomyLinks)
            ..where(($ReferenceTaxonomyLinksTable t) =>
                t.taxonomyItemId.isIn(idsToDelete) & t.deletedAt.isNull()))
          .write(ReferenceTaxonomyLinksCompanion(deletedAt: Value<DateTime?>(now)));

      // 폴더로 쓰이던 레퍼런스는 폴더 없음 상태로 되돌립니다. (지운 폴더나
      // 그 하위 폴더 중 어디에 있었든 전부 대상입니다)
      await (_db.update(_db.references)
            ..where(($ReferencesTable t) => t.folderId.isIn(idsToDelete)))
          .write(ReferencesCompanion(
        folderId: const Value<String?>(null),
        updatedAt: Value<DateTime>(now),
      ));

      // 카테고리로 쓰이던 레퍼런스도 마찬가지입니다.
      await (_db.update(_db.references)
            ..where(($ReferencesTable t) => t.categoryId.isIn(idsToDelete)))
          .write(ReferencesCompanion(
        categoryId: const Value<String?>(null),
        updatedAt: Value<DateTime>(now),
      ));
    });
  }

  /// [id]와(폴더라면) 그 하위 폴더 전부의 id를 모아 돌려줍니다.
  /// 폴더가 아니면(하위 개념이 없으면) [id] 하나만 담긴 집합입니다.
  Future<Set<String>> _folderAndDescendantIds(String id) async {
    final List<TaxonomyItem> allFolders = await getAll(TaxonomyKind.folder);
    final bool isFolder = allFolders.any((TaxonomyItem f) => f.id == id);
    if (!isFolder) {
      return <String>{id};
    }
    return collectFolderAndDescendantIds(id, parentIdMap(allFolders));
  }
```

`_toModel`에 `parentId`를 추가합니다.

```dart
  TaxonomyItem? _toModel(TaxonomyItemRow row) {
    final TaxonomyKind? kind = TaxonomyKind.fromStoredName(row.kind);
    if (kind == null) {
      return null;
    }

    return TaxonomyItem(
      id: row.id,
      kind: kind,
      name: row.name,
      parentId: row.parentId,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }
```

파일 맨 끝(클래스 닫는 `}` 다음)에 `moveFolder` 구현을 추가합니다.

```dart
  /// 폴더의 상위 폴더를 바꿉니다. [newParentId]가 null이면 최상위로 옮깁니다.
  @override
  Future<void> moveFolder(String id, String? newParentId) async {
    final DateTime now = DateTime.now().toUtc();

    if (newParentId != null) {
      final List<TaxonomyItem> allFolders = await getAll(TaxonomyKind.folder);
      final Set<String> forbidden =
          collectFolderAndDescendantIds(id, parentIdMap(allFolders));
      if (forbidden.contains(newParentId)) {
        throw const FolderMoveCycleException();
      }
    }

    await (_db.update(_db.taxonomyItems)
          ..where(($TaxonomyItemsTable t) => t.id.equals(id)))
        .write(TaxonomyItemsCompanion(
      parentId: Value<String?>(newParentId),
      updatedAt: Value<DateTime>(now),
    ));
  }
```

(주의: 위 `moveFolder`는 클래스 **안**에 있어야 합니다 — `_toModel`이나
`delete` 근처, 클래스의 마지막 멤버로 추가하세요. 클래스를 닫는 마지막
`}`보다 앞에 있어야 합니다.)

- [ ] **Step 5: 테스트 실행해서 통과 확인**

Run: `flutter test test/repositories/local_taxonomy_repository_test.dart`
Expected: PASS (모든 테스트)

- [ ] **Step 6: 전체 확인**

Run: `flutter analyze && flutter test`
Expected: 전부 PASS. (기존 "같은 종류에 같은 이름이 있으면 true" 같은 테스트는
`parentId`를 안 넘기므로 둘 다 null 취급되어 그대로 통과해야 합니다.)

- [ ] **Step 7: 커밋**

```bash
git add lib/repositories/taxonomy_repository.dart \
  lib/repositories/local_taxonomy_repository.dart \
  test/repositories/local_taxonomy_repository_test.dart
git commit -m "TaxonomyRepository에 moveFolder와 하위 폴더 연쇄 삭제를 추가한다"
```

---

## Task 4: LocalReferenceRepository.search — 폴더 필터를 자신+하위로 확장

**Files:**
- Modify: `lib/repositories/local_reference_repository.dart` (`search()`, 약 66-70행)
- Modify: `test/repositories/reference_search_test.dart`

**Interfaces:**
- Consumes: Task 2의 `collectFolderAndDescendantIds`.
- Produces: `search(ReferenceQuery(folderId: x))`가 이제 x 자신 + 하위 폴더
  전부의 레퍼런스를 돌려줌 — `ReferenceQuery`나 이걸 부르는 화면 코드는
  안 바뀝니다.

- [ ] **Step 1: 실패하는 테스트부터 작성**

`test/repositories/reference_search_test.dart`의 `saveTaxonomy` 도우미에
`parentId`를 받을 수 있게 합니다.

```dart
  /// 테스트용 분류 항목을 만들어 저장하고 그 id를 돌려줍니다.
  Future<String> saveTaxonomy(TaxonomyKind kind, String name, {String? parentId}) async {
    final DateTime now = DateTime.now().toUtc();
    final TaxonomyItem item = TaxonomyItem(
      id: newId(),
      kind: kind,
      name: name,
      parentId: parentId,
      createdAt: now,
      updatedAt: now,
    );
    await taxonomyRepository.save(item);
    return item.id;
  }
```

`group('필터', ...)` 안, `test('폴더로 거를 수 있다', ...)` 바로 다음에
추가합니다.

```dart
    test('상위 폴더를 고르면 하위 폴더의 것도 함께 나온다', () async {
      final String parent = await saveTaxonomy(TaxonomyKind.folder, '인물');
      final String child =
          await saveTaxonomy(TaxonomyKind.folder, '얼굴', parentId: parent);

      await saveReference(title: '상위 폴더 사진', folderId: parent);
      await saveReference(title: '하위 폴더 사진', folderId: child);
      await saveReference(title: '무관한 사진');

      final List<ReferenceItem> items =
          await repository.search(ReferenceQuery(folderId: parent));

      expect(titlesOf(items), containsAll(<String>['상위 폴더 사진', '하위 폴더 사진']));
      expect(titlesOf(items), isNot(contains('무관한 사진')));
    });

    test('하위 폴더를 고르면 그 하위 것만 나온다(상위는 안 섞인다)', () async {
      final String parent = await saveTaxonomy(TaxonomyKind.folder, '인물');
      final String child =
          await saveTaxonomy(TaxonomyKind.folder, '얼굴', parentId: parent);

      await saveReference(title: '상위 폴더 사진', folderId: parent);
      await saveReference(title: '하위 폴더 사진', folderId: child);

      final List<ReferenceItem> items =
          await repository.search(ReferenceQuery(folderId: child));

      expect(titlesOf(items), <String>['하위 폴더 사진']);
    });
```

- [ ] **Step 2: 테스트 실행해서 실패 확인**

Run: `flutter test test/repositories/reference_search_test.dart`
Expected: FAIL — "상위 폴더를 고르면..." 테스트가 `하위 폴더 사진`을 못 찾음
(지금은 정확히 일치하는 폴더만 거르기 때문).

- [ ] **Step 3: 구현**

`lib/repositories/local_reference_repository.dart`의 import에 추가합니다.

```dart
import '../models/taxonomy_item.dart';
import '../utils/folder_tree.dart';
```

`search()`의 폴더 필터 부분을 바꿉니다.

```dart
    // ── 폴더 / 카테고리 필터 ──
    //
    // 폴더는 자기 자신뿐 아니라 그 아래 모든 하위 폴더도 함께 봅니다.
    // 사이드바에서 상위 폴더를 고르면 하위 폴더의 레퍼런스까지 보여주기
    // 위한 것입니다. 이 저장소를 거치는 모든 화면(메인 목록, 무드보드에
    // 기존 레퍼런스를 고르는 화면 등)에 자동으로 적용됩니다.
    final String? folderId = query.folderId;
    if (folderId != null) {
      final Set<String> folderIds = await _folderAndDescendantIds(folderId);
      statement.where(($ReferencesTable t) => t.folderId.isIn(folderIds));
    }
```

`search()` 메서드가 끝난 뒤(또는 `_containsText` 근처), 클래스 안에 새
private 메서드를 추가합니다.

```dart
  /// [folderId] 자신과 그 아래 모든 하위 폴더의 id를 모아 돌려줍니다.
  Future<Set<String>> _folderAndDescendantIds(String folderId) async {
    final List<TaxonomyItemRow> folderRows = await (_db.select(_db.taxonomyItems)
          ..where(($TaxonomyItemsTable t) =>
              t.kind.equals(TaxonomyKind.folder.storedName) & t.deletedAt.isNull()))
        .get();

    final Map<String, String?> parentById = <String, String?>{
      for (final TaxonomyItemRow row in folderRows) row.id: row.parentId,
    };

    return collectFolderAndDescendantIds(folderId, parentById);
  }
```

- [ ] **Step 4: 테스트 실행해서 통과 확인**

Run: `flutter test test/repositories/reference_search_test.dart`
Expected: PASS (모든 테스트, 기존 것 포함)

- [ ] **Step 5: 전체 확인**

Run: `flutter analyze && flutter test`
Expected: 전부 PASS.

- [ ] **Step 6: 커밋**

```bash
git add lib/repositories/local_reference_repository.dart \
  test/repositories/reference_search_test.dart
git commit -m "레퍼런스 검색이 상위 폴더를 고르면 하위 폴더 것도 함께 보여주게 한다"
```

---

## Task 5: pick_taxonomy_dialog.dart — 들여쓰기(depthById) 지원

**Files:**
- Modify: `lib/widgets/pick_taxonomy_dialog.dart`
- Test: `test/widgets/pick_taxonomy_dialog_test.dart` (신규)

**Interfaces:**
- Produces: `showPickTaxonomyDialog(..., Map<String, int>? depthById)` — 안
  넘기면(null) 기존과 동일한 모양입니다. Task 6, 7이 이 파라미터를 씁니다.

- [ ] **Step 1: 실패하는 테스트부터 작성**

Create `test/widgets/pick_taxonomy_dialog_test.dart`:

```dart
// pick_taxonomy_dialog.dart의 들여쓰기(depthById) 옵션을 확인하는 테스트입니다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';
import 'package:reference_archive_app/widgets/pick_taxonomy_dialog.dart';

void main() {
  TaxonomyItem folder(String id, String name) {
    final DateTime now = DateTime.utc(2026, 1, 1);
    return TaxonomyItem(
      id: id,
      kind: TaxonomyKind.folder,
      name: name,
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('depthById 없이도 그대로 고를 수 있다(기존 동작 유지)', (WidgetTester tester) async {
    late Future<PickedTaxonomy?> result;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (BuildContext context) {
          return ElevatedButton(
            onPressed: () {
              result = showPickTaxonomyDialog(
                context: context,
                kind: TaxonomyKind.folder,
                items: <TaxonomyItem>[folder('a', '인물')],
                title: '폴더 고르기',
              );
            },
            child: const Text('열기'),
          );
        },
      ),
    ));

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('인물'));
    await tester.pumpAndSettle();

    final PickedTaxonomy? picked = await result;
    expect(picked?.item?.id, 'a');
  });

  testWidgets('depthById를 넘기면 들여써서 보이지만 그대로 고를 수 있다', (WidgetTester tester) async {
    late Future<PickedTaxonomy?> result;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (BuildContext context) {
          return ElevatedButton(
            onPressed: () {
              result = showPickTaxonomyDialog(
                context: context,
                kind: TaxonomyKind.folder,
                items: <TaxonomyItem>[folder('a', '인물'), folder('b', '얼굴')],
                depthById: const <String, int>{'b': 1},
                title: '폴더 고르기',
              );
            },
            child: const Text('열기'),
          );
        },
      ),
    ));

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('얼굴'));
    await tester.pumpAndSettle();

    final PickedTaxonomy? picked = await result;
    expect(picked?.item?.id, 'b');
  });
}
```

- [ ] **Step 2: 테스트 실행해서 실패 확인**

Run: `flutter test test/widgets/pick_taxonomy_dialog_test.dart`
Expected: FAIL — `depthById` 파라미터가 없어서 컴파일 오류.

- [ ] **Step 3: 구현**

`lib/widgets/pick_taxonomy_dialog.dart`의 `showPickTaxonomyDialog`와
`_PickTaxonomyDialog`를 고칩니다.

```dart
Future<PickedTaxonomy?> showPickTaxonomyDialog({
  required BuildContext context,
  required TaxonomyKind kind,
  required List<TaxonomyItem> items,
  required String title,
  bool allowNone = false,
  Map<String, int>? depthById,
}) {
  return showDialog<PickedTaxonomy>(
    context: context,
    builder: (BuildContext context) {
      return _PickTaxonomyDialog(
        kind: kind,
        items: items,
        title: title,
        allowNone: allowNone,
        depthById: depthById,
      );
    },
  );
}
```

```dart
class _PickTaxonomyDialog extends StatelessWidget {
  const _PickTaxonomyDialog({
    required this.kind,
    required this.items,
    required this.title,
    required this.allowNone,
    this.depthById,
  });

  final TaxonomyKind kind;
  final List<TaxonomyItem> items;
  final String title;
  final bool allowNone;

  /// 항목 id → 트리 깊이입니다. 폴더처럼 중첩이 있는 종류를 들여써
  /// 보여줄 때만 넘겨줍니다. null이면(태그 등 중첩이 없는 종류) 들여쓰지
  /// 않습니다.
  final Map<String, int>? depthById;
```

`_buildOptionList`의 `for (final TaxonomyItem item in items) { ... }`
블록을 바꿉니다.

```dart
    for (final TaxonomyItem item in items) {
      final int depth = depthById?[item.id] ?? 0;
      options.add(
        ListTile(
          contentPadding: EdgeInsets.only(left: 16.0 + (depth * 20), right: 16),
          leading: const Icon(Icons.label_outline),
          title: Text(item.name),
          onTap: () {
            Navigator.of(context).pop(PickedTaxonomy(item));
          },
        ),
      );
    }
```

- [ ] **Step 4: 테스트 실행해서 통과 확인**

Run: `flutter test test/widgets/pick_taxonomy_dialog_test.dart`
Expected: PASS

- [ ] **Step 5: 이 다이얼로그를 쓰는 기존 화면들이 안 깨졌는지 확인**

Run: `flutter test test/screens/board_list_screen_test.dart`
(또는 `showPickTaxonomyDialog`를 쓰는 다른 기존 테스트 — `grep -rl
showPickTaxonomyDialog test`로 확인)
Expected: PASS (depthById 기본값이 null이라 기존 호출부는 그대로 동작)

- [ ] **Step 6: 커밋**

```bash
git add lib/widgets/pick_taxonomy_dialog.dart test/widgets/pick_taxonomy_dialog_test.dart
git commit -m "pick_taxonomy_dialog.dart에 들여쓰기(depthById)를 추가한다"
```

---

## Task 6: create_taxonomy_dialog.dart — 상위 폴더 선택 칸

**Files:**
- Modify: `lib/widgets/create_taxonomy_dialog.dart`
- Test: `test/screens/taxonomy_manage_screen_test.dart` (Task 6+7 공용 그룹)

**Interfaces:**
- Consumes: Task 2(`buildFolderTree`, `FolderTreeEntry`), Task 5(`showPickTaxonomyDialog`
  의 `depthById`), Task 3(`existsWithName`의 `parentId` 인자).
- Produces: `showCreateTaxonomyDialog(..., List<TaxonomyItem> allFolders = const [],
  String? initialParentId)` — Task 9, 10이 씁니다.

- [ ] **Step 1: 구현**

`lib/widgets/create_taxonomy_dialog.dart`의 import에 추가합니다.

```dart
import '../utils/folder_tree.dart';
import 'pick_taxonomy_dialog.dart';
```

`showCreateTaxonomyDialog` 시그니처와 내부를 바꿉니다.

```dart
Future<TaxonomyItem?> showCreateTaxonomyDialog({
  required BuildContext context,
  required TaxonomyKind kind,
  required TaxonomyRepository repository,
  List<TaxonomyItem> allFolders = const <TaxonomyItem>[],
  String? initialParentId,
}) {
  return showDialog<TaxonomyItem>(
    context: context,
    builder: (BuildContext context) {
      return _CreateTaxonomyDialog(
        kind: kind,
        repository: repository,
        allFolders: allFolders,
        initialParentId: initialParentId,
      );
    },
  );
}
```

```dart
class _CreateTaxonomyDialog extends StatefulWidget {
  const _CreateTaxonomyDialog({
    required this.kind,
    required this.repository,
    this.allFolders = const <TaxonomyItem>[],
    this.initialParentId,
  });

  final TaxonomyKind kind;
  final TaxonomyRepository repository;

  /// 폴더일 때만 씁니다. "상위 폴더" 칸을 채울 후보들입니다.
  final List<TaxonomyItem> allFolders;

  /// 처음에 골라져 있을 상위 폴더입니다(예: 사이드바 "하위 폴더 만들기").
  final String? initialParentId;

  @override
  State<_CreateTaxonomyDialog> createState() => _CreateTaxonomyDialogState();
}
```

`_CreateTaxonomyDialogState`에 상태를 추가합니다.

```dart
class _CreateTaxonomyDialogState extends State<_CreateTaxonomyDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;
  bool _isSaving = false;

  /// 폴더일 때만 씁니다. 지금 고른 상위 폴더의 id입니다. null이면 최상위입니다.
  late String? _selectedParentId = widget.initialParentId;
```

`_save()`를 바꿉니다.

```dart
  Future<void> _save() async {
    final String name = _controller.text.trim();

    if (name.isEmpty) {
      setState(() {
        _errorText = '이름을 입력해주세요.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final bool isFolder = widget.kind == TaxonomyKind.folder;
    final bool alreadyExists = await widget.repository.existsWithName(
      widget.kind,
      name,
      parentId: isFolder ? _selectedParentId : null,
    );

    if (!mounted) {
      return;
    }

    if (alreadyExists) {
      setState(() {
        _isSaving = false;
        _errorText = '같은 이름의 ${withSubjectParticle(widget.kind.displayName)} 이미 있습니다.';
      });
      return;
    }

    final DateTime now = DateTime.now().toUtc();
    final TaxonomyItem created = TaxonomyItem(
      id: newId(),
      kind: widget.kind,
      name: name,
      parentId: isFolder ? _selectedParentId : null,
      createdAt: now,
      updatedAt: now,
    );
    await widget.repository.save(created);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(created);
  }

  /// "상위 폴더" 칸을 눌렀을 때 고르는 대화상자를 띄웁니다.
  Future<void> _pickParent() async {
    final List<FolderTreeEntry> tree = buildFolderTree(widget.allFolders);
    final PickedTaxonomy? picked = await showPickTaxonomyDialog(
      context: context,
      kind: TaxonomyKind.folder,
      items: tree.map((FolderTreeEntry e) => e.folder).toList(),
      depthById: <String, int>{
        for (final FolderTreeEntry e in tree) e.folder.id: e.depth,
      },
      title: '상위 폴더',
      allowNone: true,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedParentId = picked.item?.id;
    });
  }
```

`build()`를 바꿉니다. `content: TextField(...)` 한 줄이었던 것을 폴더일
때만 상위 폴더 칸이 붙는 `Column`으로 바꿉니다.

```dart
  @override
  Widget build(BuildContext context) {
    final String kindName = widget.kind.displayName;
    final bool isFolder = widget.kind == TaxonomyKind.folder;
    final String parentLabel = _selectedParentId == null
        ? '최상위'
        : widget.allFolders
            .firstWhere((TaxonomyItem f) => f.id == _selectedParentId)
            .name;

    return AlertDialog(
      title: Text('새 $kindName 만들기'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: '$kindName 이름',
              errorText: _errorText,
            ),
            onSubmitted: (String _) {
              if (!_isSaving) {
                _save();
              }
            },
          ),
          if (isFolder) ...<Widget>[
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_outlined),
              title: const Text('상위 폴더'),
              subtitle: Text(parentLabel),
              onTap: _isSaving ? null : _pickParent,
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('만들기'),
        ),
      ],
    );
  }
```

- [ ] **Step 2: `flutter analyze`로 컴파일 확인**

Run: `flutter analyze lib/widgets/create_taxonomy_dialog.dart`
Expected: 0 issues. (테스트는 Task 9에서 rename 다이얼로그와 함께 한
그룹으로 작성합니다 — 두 다이얼로그가 taxonomy_manage_screen을 통해
같은 화면에서 열리기 때문입니다.)

- [ ] **Step 3: 커밋**

```bash
git add lib/widgets/create_taxonomy_dialog.dart
git commit -m "create_taxonomy_dialog.dart에 상위 폴더 선택 칸을 추가한다"
```

---

## Task 7: rename_taxonomy_dialog.dart — 상위 폴더 선택 칸 + 이름/부모 동시 변경

**Files:**
- Modify: `lib/widgets/rename_taxonomy_dialog.dart`
- Test: `test/screens/taxonomy_manage_screen_test.dart` (Task 6+7 공용 그룹,
  아래 Step 3에서 함께 작성)

**Interfaces:**
- Consumes: Task 2(`buildFolderTree`, `collectFolderAndDescendantIds`,
  `parentIdMap`), Task 3(`existsWithName`의 `parentId`, `moveFolder`).
- Produces: `showRenameTaxonomyDialog(..., List<TaxonomyItem> allFolders = const [])`
  — Task 10이 씁니다.

- [ ] **Step 1: 구현**

`lib/widgets/rename_taxonomy_dialog.dart`의 import에 추가합니다.

```dart
import '../utils/folder_tree.dart';
import 'pick_taxonomy_dialog.dart';
```

`showRenameTaxonomyDialog`와 위젯 선언을 바꿉니다.

```dart
Future<bool> showRenameTaxonomyDialog({
  required BuildContext context,
  required TaxonomyItem item,
  required TaxonomyRepository repository,
  List<TaxonomyItem> allFolders = const <TaxonomyItem>[],
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return _RenameTaxonomyDialog(
        item: item,
        repository: repository,
        allFolders: allFolders,
      );
    },
  );

  return result ?? false;
}

class _RenameTaxonomyDialog extends StatefulWidget {
  const _RenameTaxonomyDialog({
    required this.item,
    required this.repository,
    this.allFolders = const <TaxonomyItem>[],
  });

  final TaxonomyItem item;
  final TaxonomyRepository repository;

  /// item이 폴더일 때만 씁니다. "상위 폴더" 칸을 채울 후보들입니다.
  final List<TaxonomyItem> allFolders;

  @override
  State<_RenameTaxonomyDialog> createState() => _RenameTaxonomyDialogState();
}
```

`_RenameTaxonomyDialogState`에 상태를 추가합니다(`_controller` 선언 다음).

```dart
  /// 폴더일 때만 씁니다. 지금 고른 상위 폴더의 id입니다.
  late String? _selectedParentId = widget.item.parentId;
```

`_save()`를 통째로 바꿉니다.

```dart
  /// 새 이름과(폴더라면) 새 상위 폴더로 저장합니다.
  Future<void> _save() async {
    final String name = _controller.text.trim();

    if (name.isEmpty) {
      setState(() {
        _errorText = '이름을 입력해주세요.';
      });
      return;
    }

    final bool isFolder = widget.item.kind == TaxonomyKind.folder;
    final String? targetParentId = isFolder ? _selectedParentId : null;
    final bool nameChanged = name != widget.item.name;
    final bool parentChanged = isFolder && targetParentId != widget.item.parentId;

    if (!nameChanged && !parentChanged) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    if (nameChanged) {
      final bool alreadyExists = await widget.repository.existsWithName(
        widget.item.kind,
        name,
        excludeId: widget.item.id,
        parentId: targetParentId,
      );

      if (!mounted) {
        return;
      }

      if (alreadyExists) {
        setState(() {
          _isSaving = false;
          _errorText =
              '같은 이름의 ${withSubjectParticle(widget.item.kind.displayName)} 이미 있습니다.';
        });
        return;
      }
    }

    // ── 순서가 중요합니다 ──
    // save()는 항목을 통째로 다시 써서 parentId도 함께 저장합니다. 그런데
    // widget.item은 이 대화상자가 열릴 때의 옛 parentId를 그대로 들고
    // 있습니다(copyWith(name: name)은 parentId를 안 건드립니다). 그래서
    // moveFolder로 새 parentId를 먼저 넣은 뒤 save()를 부르면, save()가
    // 그 값을 옛 parentId로 도로 덮어씁니다. **이름을 먼저 저장하고,
    // 상위 폴더 이동은 마지막에** 합니다.
    if (nameChanged) {
      await widget.repository.save(widget.item.copyWith(name: name));
    }
    if (!mounted) {
      return;
    }

    if (parentChanged) {
      await widget.repository.moveFolder(widget.item.id, targetParentId);
    }
    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  /// "상위 폴더" 칸을 눌렀을 때 고르는 대화상자를 띄웁니다.
  ///
  /// 자기 자신과 자기 하위는 후보에서 뺍니다 — 순환을 UI에서부터 막아,
  /// 저장소의 moveFolder 예외(FolderMoveCycleException)는 이 경로에서는
  /// 사실상 일어나지 않습니다(방어선은 저장소 쪽에도 남아 있습니다).
  Future<void> _pickParent() async {
    final Set<String> excludeIds = collectFolderAndDescendantIds(
      widget.item.id,
      parentIdMap(widget.allFolders),
    );
    final List<FolderTreeEntry> tree = buildFolderTree(
      widget.allFolders,
      excludeIds: excludeIds,
    );
    final PickedTaxonomy? picked = await showPickTaxonomyDialog(
      context: context,
      kind: TaxonomyKind.folder,
      items: tree.map((FolderTreeEntry e) => e.folder).toList(),
      depthById: <String, int>{
        for (final FolderTreeEntry e in tree) e.folder.id: e.depth,
      },
      title: '상위 폴더',
      allowNone: true,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedParentId = picked.item?.id;
    });
  }
```

`build()`를 바꿉니다.

```dart
  @override
  Widget build(BuildContext context) {
    final String kindName = widget.item.kind.displayName;
    final bool isFolder = widget.item.kind == TaxonomyKind.folder;
    final String parentLabel = _selectedParentId == null
        ? '최상위'
        : widget.allFolders
            .firstWhere((TaxonomyItem f) => f.id == _selectedParentId)
            .name;

    return AlertDialog(
      title: Text('$kindName 이름 바꾸기'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: '$kindName 이름',
              errorText: _errorText,
            ),
            onSubmitted: (String _) {
              if (!_isSaving) {
                _save();
              }
            },
          ),
          if (isFolder) ...<Widget>[
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_outlined),
              title: const Text('상위 폴더'),
              subtitle: Text(parentLabel),
              onTap: _isSaving ? null : _pickParent,
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('바꾸기'),
        ),
      ],
    );
  }
```

- [ ] **Step 2: `flutter analyze`로 컴파일 확인**

Run: `flutter analyze lib/widgets/rename_taxonomy_dialog.dart`
Expected: 0 issues.

- [ ] **Step 3: taxonomy_manage_screen.dart를 통해 두 다이얼로그를 함께 테스트**

이 화면(`taxonomy_manage_screen.dart`)은 Task 9에서 `allFolders`를 넘기도록
바뀝니다. 지금 단계에서는 화면이 아직 `allFolders`를 안 넘기므로(기본값
빈 목록) 테스트가 통과하지 않습니다 — **이 Step은 Task 9 Step 1/3에서 함께
작성/실행합니다.** 지금은 건너뜁니다(아래 커밋에는 위젯 코드만 포함).

- [ ] **Step 4: 커밋**

```bash
git add lib/widgets/rename_taxonomy_dialog.dart
git commit -m "rename_taxonomy_dialog.dart에 상위 폴더 선택 칸을 추가한다"
```

---

## Task 8: taxonomy_single_field.dart + reference_detail_taxonomy_fields.dart — 들여쓰기

**Files:**
- Modify: `lib/widgets/taxonomy_single_field.dart`
- Modify: `lib/widgets/reference_detail_taxonomy_fields.dart`
- Test: 기존 레퍼런스 편집 화면 테스트로 회귀만 확인(새 전용 테스트 파일은
  만들지 않음 — 아래 Step 4 참고)

**Interfaces:**
- Consumes: Task 2(`buildFolderTree`, `FolderTreeEntry`).
- Produces: `TaxonomySingleField(..., Map<String, int>? depthById)`.

- [ ] **Step 1: TaxonomySingleField에 depthById 추가**

`lib/widgets/taxonomy_single_field.dart`를 고칩니다.

```dart
class TaxonomySingleField extends StatelessWidget {
  const TaxonomySingleField({
    super.key,
    required this.kind,
    required this.options,
    required this.selectedId,
    required this.repository,
    required this.onChanged,
    required this.onCreated,
    this.depthById,
  });

  final TaxonomyKind kind;
  final List<TaxonomyItem> options;
  final String? selectedId;
  final TaxonomyRepository repository;
  final ValueChanged<String?> onChanged;
  final ValueChanged<TaxonomyItem> onCreated;

  /// 항목 id → 트리 깊이입니다. 폴더처럼 중첩이 있는 종류를 들여써
  /// 보여줄 때만 넘겨줍니다. null이면(카테고리 등) 들여쓰지 않습니다.
  final Map<String, int>? depthById;
```

`build()`의 `items:` 목록을 바꿉니다.

```dart
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('없음'),
              ),
              ...options.map((TaxonomyItem item) {
                final int depth = depthById?[item.id] ?? 0;
                return DropdownMenuItem<String?>(
                  value: item.id,
                  child: Text('${'    ' * depth}${item.name}'),
                );
              }),
            ],
```

- [ ] **Step 2: reference_detail_taxonomy_fields.dart에서 폴더 칸에 트리 순서 전달**

`lib/widgets/reference_detail_taxonomy_fields.dart`의 import에 추가합니다.

```dart
import '../utils/folder_tree.dart';
```

`build()` 맨 위, `return Column(` 전에 트리를 계산해둡니다.

```dart
  @override
  Widget build(BuildContext context) {
    // 폴더 칸만 트리 순서(부모 다음에 자식)+들여쓰기로 보여줍니다.
    // 카테고리는 중첩이 없어서 그대로입니다.
    final List<FolderTreeEntry> folderTree = buildFolderTree(
      controller.options[TaxonomyKind.folder] ?? <TaxonomyItem>[],
    );

    return Column(
```

폴더 `TaxonomySingleField`를 바꿉니다.

```dart
        TaxonomySingleField(
          kind: TaxonomyKind.folder,
          options: folderTree.map((FolderTreeEntry e) => e.folder).toList(),
          depthById: <String, int>{
            for (final FolderTreeEntry e in folderTree) e.folder.id: e.depth,
          },
          selectedId: controller.folderId,
          repository: repository,
          onChanged: controller.setFolder,
          onCreated: (TaxonomyItem created) => controller.handleCreated(
            repository,
            TaxonomyKind.folder,
            created,
          ),
        ),
```

(카테고리 `TaxonomySingleField`는 그대로 둡니다 — `depthById`를 안 넘기면
기본 null이라 안 들여써집니다.)

- [ ] **Step 3: `flutter analyze`로 컴파일 확인**

Run: `flutter analyze lib/widgets/taxonomy_single_field.dart lib/widgets/reference_detail_taxonomy_fields.dart`
Expected: 0 issues.

- [ ] **Step 4: 기존 레퍼런스 편집 화면 테스트로 회귀 확인**

Run: `flutter test test/screens/reference_detail_screen_test.dart`
(파일명이 다르면 `grep -rl TaxonomySingleField test`로 실제 파일을 찾아
그 테스트를 돌립니다)
Expected: PASS — 폴더 목록에 이름이 그대로 보이고(들여쓰기는 공백일
뿐이라 `find.text('인물')`류 매칭에 영향 없음) 고르기 동작도 그대로입니다.

- [ ] **Step 5: 커밋**

```bash
git add lib/widgets/taxonomy_single_field.dart \
  lib/widgets/reference_detail_taxonomy_fields.dart
git commit -m "레퍼런스 편집 화면의 폴더 칸을 들여써서 보여준다"
```

---

## Task 9: taxonomy_manage_screen.dart — 폴더 탭 트리 + 하위 폴더 삭제 안내

**Files:**
- Modify: `lib/screens/taxonomy_manage_screen.dart`
- Modify: `test/screens/taxonomy_manage_screen_test.dart`

**Interfaces:**
- Consumes: Task 2(`buildFolderTree`, `FolderTreeEntry`, `collectFolderAndDescendantIds`,
  `parentIdMap`), Task 6(`showCreateTaxonomyDialog`의 `allFolders`), Task 7
  (`showRenameTaxonomyDialog`의 `allFolders`).

- [ ] **Step 1: 실패하는 테스트부터 작성**

`test/screens/taxonomy_manage_screen_test.dart`의 import에 추가합니다.

```dart
import 'package:reference_archive_app/utils/id_generator.dart';
```

(이미 있으면 건너뜁니다 — 파일 위쪽을 확인하세요.)

파일 끝, 마지막 `testWidgets('새로 만들기로...')` 다음에(파일을 닫는
마지막 `}` 앞) 새 그룹들을 추가합니다.

```dart
  group('하위 폴더', () {
    testWidgets('하위 폴더가 함께 보인다', (WidgetTester tester) async {
      useTallScreen(tester);
      final TaxonomyItem parent = await saveTaxonomy(TaxonomyKind.folder, '인물');
      await taxonomyRepository.save(
        TaxonomyItem(
          id: newId(),
          kind: TaxonomyKind.folder,
          name: '얼굴',
          parentId: parent.id,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      await tester.pumpWidget(makeScreen());
      await tester.pumpAndSettle();

      expect(find.text('인물'), findsOneWidget);
      expect(find.text('얼굴'), findsOneWidget);
    });

    testWidgets('하위 폴더가 있는 폴더를 지우면 개수를 알려주고 함께 지운다',
        (WidgetTester tester) async {
      useTallScreen(tester);
      final TaxonomyItem parent = await saveTaxonomy(TaxonomyKind.folder, '인물');
      final TaxonomyItem child = TaxonomyItem(
        id: newId(),
        kind: TaxonomyKind.folder,
        name: '얼굴',
        parentId: parent.id,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      await taxonomyRepository.save(child);

      await tester.pumpWidget(makeScreen());
      await tester.pumpAndSettle();

      // "인물"이 트리에서 먼저 나오므로 첫 번째 삭제 버튼입니다.
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('하위 폴더 1개도 함께 지워집니다'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '삭제'));
      await tester.pumpAndSettle();

      expect(find.text('인물'), findsNothing);
      expect(find.text('얼굴'), findsNothing);
      expect(await taxonomyRepository.getById(child.id), isNull);
    });
  });

  group('상위 폴더', () {
    testWidgets('새로 만들 때 상위 폴더를 고를 수 있다', (WidgetTester tester) async {
      useTallScreen(tester);
      final TaxonomyItem parent = await saveTaxonomy(TaxonomyKind.folder, '인물');

      await tester.pumpWidget(makeScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('새로 만들기'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('최상위'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(of: find.byType(AlertDialog).last, matching: find.text('인물')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '얼굴');
      await tester.tap(find.text('만들기'));
      await tester.pumpAndSettle();

      final List<TaxonomyItem> folders =
          await taxonomyRepository.getAll(TaxonomyKind.folder);
      final TaxonomyItem child = folders.firstWhere((TaxonomyItem f) => f.name == '얼굴');
      expect(child.parentId, parent.id);
    });

    testWidgets('이름 바꾸기에서 상위 폴더를 바꾸면 함께 저장된다', (WidgetTester tester) async {
      useTallScreen(tester);
      final TaxonomyItem parent = await saveTaxonomy(TaxonomyKind.folder, '인물');
      final TaxonomyItem child = await saveTaxonomy(TaxonomyKind.folder, '풍경');

      await tester.pumpWidget(makeScreen());
      await tester.pumpAndSettle();

      // 가나다순으로 "인물" 다음이 "풍경"이라 두 번째 이름 바꾸기 버튼입니다.
      await tester.tap(find.byIcon(Icons.edit_outlined).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('최상위'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(AlertDialog).last, matching: find.text('인물')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('바꾸기'));
      await tester.pumpAndSettle();

      final TaxonomyItem? reloaded = await taxonomyRepository.getById(child.id);
      expect(reloaded!.parentId, parent.id);
    });

    testWidgets('자기 자신과 자기 하위는 상위 폴더 후보에 안 보인다', (WidgetTester tester) async {
      useTallScreen(tester);
      final TaxonomyItem parent = await saveTaxonomy(TaxonomyKind.folder, '인물');
      await taxonomyRepository.save(
        TaxonomyItem(
          id: newId(),
          kind: TaxonomyKind.folder,
          name: '얼굴',
          parentId: parent.id,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await saveTaxonomy(TaxonomyKind.folder, '풍경'); // 무관한 폴더(후보로 보여야 함)

      await tester.pumpWidget(makeScreen());
      await tester.pumpAndSettle();

      // 트리 순서: 인물, 얼굴(들여쓰기), 풍경. "인물"의 이름 바꾸기가 첫 번째입니다.
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('최상위'));
      await tester.pumpAndSettle();

      final Finder pickDialog = find.byType(AlertDialog).last;
      expect(find.descendant(of: pickDialog, matching: find.text('인물')), findsNothing);
      expect(find.descendant(of: pickDialog, matching: find.text('얼굴')), findsNothing);
      expect(find.descendant(of: pickDialog, matching: find.text('풍경')), findsOneWidget);
    });
  });
```

- [ ] **Step 2: 테스트 실행해서 실패 확인**

Run: `flutter test test/screens/taxonomy_manage_screen_test.dart`
Expected: FAIL — 하위 폴더가 트리로 안 보이고, "최상위"/상위 폴더 칸
자체가 아직 없습니다(Task 6, 7에서 위젯은 만들었지만 이 화면이 아직
`allFolders`를 안 넘겨서 목록이 비어 있음).

- [ ] **Step 3: 구현**

`lib/screens/taxonomy_manage_screen.dart`의 import에 추가합니다.

```dart
import '../utils/folder_tree.dart';
```

`_buildList`를 바꿉니다.

```dart
  /// 한 종류의 항목 목록을 만듭니다.
  ///
  /// 폴더만 트리 순서(부모 다음에 자식)+들여쓰기로 보여줍니다. 다른
  /// 종류는 부모 개념이 없어서 지금처럼 평평한 가나다순 그대로입니다.
  Widget _buildList(TaxonomyKind kind) {
    final List<TaxonomyItem> items = _itemsByKind[kind] ?? <TaxonomyItem>[];

    if (items.isEmpty) {
      return _buildEmptyState(kind);
    }

    final List<FolderTreeEntry> entries = kind == TaxonomyKind.folder
        ? buildFolderTree(items)
        : items
            .map((TaxonomyItem item) => FolderTreeEntry(folder: item, depth: 0))
            .toList();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int index) {
        final TaxonomyItem item = entries[index].folder;
        final int depth = entries[index].depth;
        final int usageCount = _usageCounts[item.id] ?? 0;

        return ListTile(
          contentPadding: EdgeInsets.only(left: 16.0 + (depth * 20), right: 16),
          title: Text(item.name),
          subtitle: Text(
            usageCount == 0 ? '쓰는 레퍼런스 없음' : '레퍼런스 $usageCount개에서 사용 중',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                onPressed: () => _renameItem(item),
                icon: const Icon(Icons.edit_outlined),
                tooltip: '이름 바꾸기',
              ),
              IconButton(
                onPressed: () => _deleteItem(item),
                icon: const Icon(Icons.delete_outline),
                tooltip: '삭제',
              ),
            ],
          ),
        );
      },
    );
  }
```

`_createItem`을 바꿉니다.

```dart
  /// 새 항목을 만듭니다.
  Future<void> _createItem(TaxonomyKind kind) async {
    final TaxonomyItem? created = await showCreateTaxonomyDialog(
      context: context,
      kind: kind,
      repository: widget.repository,
      allFolders: kind == TaxonomyKind.folder
          ? (_itemsByKind[TaxonomyKind.folder] ?? <TaxonomyItem>[])
          : const <TaxonomyItem>[],
    );

    if (created != null) {
      _hasChanges = true;
      await _loadAll();
    }
  }
```

`_renameItem`을 바꿉니다.

```dart
  /// 항목의 이름을(폴더라면 상위 폴더도) 바꿉니다.
  Future<void> _renameItem(TaxonomyItem item) async {
    final bool renamed = await showRenameTaxonomyDialog(
      context: context,
      item: item,
      repository: widget.repository,
      allFolders: item.kind == TaxonomyKind.folder
          ? (_itemsByKind[TaxonomyKind.folder] ?? <TaxonomyItem>[])
          : const <TaxonomyItem>[],
    );

    if (renamed) {
      _hasChanges = true;
      await _loadAll();
    }
  }
```

`_deleteItem`과 `_confirmDelete`를 바꿉니다.

```dart
  /// 항목을 지웁니다. 쓰는 레퍼런스가 있으면(폴더라면 하위 폴더가 있으면도)
  /// 알려주고 확인받습니다.
  Future<void> _deleteItem(TaxonomyItem item) async {
    final int usageCount = _usageCounts[item.id] ?? 0;
    final int subfolderCount = item.kind == TaxonomyKind.folder
        ? collectFolderAndDescendantIds(
              item.id,
              parentIdMap(_itemsByKind[TaxonomyKind.folder] ?? <TaxonomyItem>[]),
            ).length -
            1 // 자기 자신은 빼고 셉니다.
        : 0;

    final bool confirmed = await _confirmDelete(item, usageCount, subfolderCount);

    if (!confirmed) {
      return;
    }

    await widget.repository.delete(item.id);
    _hasChanges = true;
    await _loadAll();
  }

  /// 정말 지울지 확인받는 대화상자를 띄웁니다.
  Future<bool> _confirmDelete(
    TaxonomyItem item,
    int usageCount,
    int subfolderCount,
  ) async {
    final String kindName = item.kind.displayName;

    final StringBuffer message = StringBuffer(
      '"${item.name}" ${withObjectParticle(kindName)} 지웁니다.\n',
    );
    if (subfolderCount > 0) {
      message.write('하위 폴더 $subfolderCount개도 함께 지워집니다.\n');
    }
    if (usageCount == 0) {
      message.write('이 ${withObjectParticle(kindName)} 쓰는 레퍼런스는 없습니다.');
    } else {
      message.write(
        '이 ${withObjectParticle(kindName)} 쓰는 레퍼런스가 $usageCount개 있습니다.\n'
        '레퍼런스 자체는 지워지지 않지만, 그 $kindName 연결이 사라지며 '
        '되돌릴 수 없습니다.',
      );
    }

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$kindName 삭제'),
          content: Text(message.toString()),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
```

- [ ] **Step 4: 테스트 실행해서 통과 확인**

Run: `flutter test test/screens/taxonomy_manage_screen_test.dart`
Expected: PASS (기존 테스트 포함 전부)

- [ ] **Step 5: 전체 확인**

Run: `flutter analyze && flutter test`
Expected: 전부 PASS.

- [ ] **Step 6: 커밋**

```bash
git add lib/screens/taxonomy_manage_screen.dart test/screens/taxonomy_manage_screen_test.dart
git commit -m "분류 관리 화면의 폴더 탭을 트리로 보여주고 삭제 확인에 하위 개수를 알려준다"
```

---

## Task 10: app_sidebar.dart — 트리 표시 + 펼치기/접기 + 메뉴(하위 폴더 만들기/이름 바꾸기/삭제)

**Files:**
- Modify: `lib/widgets/app_sidebar.dart`
- Modify: `lib/screens/home_screen.dart`
- Modify: `test/screens/home_folders_sidebar_test.dart`

**Interfaces:**
- Consumes: Task 2(`buildFolderTree`, `FolderTreeEntry`, `collectFolderAndDescendantIds`,
  `parentIdMap`), Task 6/7(다이얼로그의 `allFolders`).
- Produces: `AppSidebar`가 `StatefulWidget`이 되고 새 콜백
  `onCreateSubfolder`, `onRenameFolder`, `onDeleteFolder`,
  `onMoveFolder`를 받음 — Task 11(드래그앤드롭)이 `onMoveFolder`를
  마저 씁니다(이 태스크에서는 시그니처만 만들고 아직 아무도 안 부릅니다).

- [ ] **Step 1: 실패하는 테스트부터 작성**

`test/screens/home_folders_sidebar_test.dart`의 파일 끝(마지막 `}` 앞)에
새 그룹을 추가합니다.

```dart
  group('폴더 트리(하위 폴더)', () {
    testWidgets('하위 폴더가 기본으로 펼쳐져 함께 보인다', (WidgetTester tester) async {
      final String parentId = await saveFolder('인물');
      final DateTime now = DateTime.now().toUtc();
      await taxonomyRepository.save(TaxonomyItem(
        id: newId(),
        kind: TaxonomyKind.folder,
        name: '얼굴',
        parentId: parentId,
        createdAt: now,
        updatedAt: now,
      ));

      await openApp(tester);

      expect(find.text('인물'), findsOneWidget);
      expect(find.text('얼굴'), findsOneWidget);
    });

    testWidgets('접기 화살표를 누르면 하위 폴더가 숨겨진다', (WidgetTester tester) async {
      final String parentId = await saveFolder('인물');
      final DateTime now = DateTime.now().toUtc();
      await taxonomyRepository.save(TaxonomyItem(
        id: newId(),
        kind: TaxonomyKind.folder,
        name: '얼굴',
        parentId: parentId,
        createdAt: now,
        updatedAt: now,
      ));

      await openApp(tester);
      expect(find.text('얼굴'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();
      expect(find.text('얼굴'), findsNothing);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text('얼굴'), findsOneWidget);
    });

    testWidgets('상위 폴더를 고르면 하위 폴더의 레퍼런스도 함께 보인다', (WidgetTester tester) async {
      final String parentId = await saveFolder('인물');
      final DateTime now = DateTime.now().toUtc();
      final String childId = newId();
      await taxonomyRepository.save(TaxonomyItem(
        id: childId,
        kind: TaxonomyKind.folder,
        name: '얼굴',
        parentId: parentId,
        createdAt: now,
        updatedAt: now,
      ));
      await saveReference(title: '상위 사진', folderId: parentId);
      await saveReference(title: '하위 사진', folderId: childId);

      await openApp(tester);

      await tester.tap(find.text('인물'));
      await tester.pumpAndSettle();

      expect(find.text('상위 사진'), findsOneWidget);
      expect(find.text('하위 사진'), findsOneWidget);
    });

    testWidgets('사이드바 메뉴로 하위 폴더를 만들 수 있다', (WidgetTester tester) async {
      await saveFolder('인물');

      await openApp(tester);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('하위 폴더 만들기'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '얼굴');
      await tester.tap(find.text('만들기'));
      await tester.pumpAndSettle();

      expect(find.text('얼굴'), findsOneWidget);

      final List<TaxonomyItem> folders =
          await taxonomyRepository.getAll(TaxonomyKind.folder);
      final TaxonomyItem child = folders.firstWhere((TaxonomyItem f) => f.name == '얼굴');
      expect(child.parentId, isNotNull);
    });

    testWidgets('사이드바 메뉴로 폴더를 지울 수 있다', (WidgetTester tester) async {
      final String folderId = await saveFolder('인물');

      await openApp(tester);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '삭제'));
      await tester.pumpAndSettle();

      expect(find.text('인물'), findsNothing);
      expect(await taxonomyRepository.getById(folderId), isNull);
    });
  });
```

Import에 `newId`가 이미 있는지 확인하고(이 파일은 이미
`utils/id_generator.dart`를 씁니다 — 없으면 추가) 진행합니다.

- [ ] **Step 2: 테스트 실행해서 실패 확인**

Run: `flutter test test/screens/home_folders_sidebar_test.dart`
Expected: FAIL — `AppSidebar`가 아직 트리도, 메뉴도 없습니다.

- [ ] **Step 3: AppSidebar 구현**

`lib/widgets/app_sidebar.dart`를 엽니다. 상단 주석에 한 줄 추가합니다
("── 하위 폴더(2026-09-11) ──" 같은 표시로, 이 화면이 이제 트리라는 것을
남깁니다). import에 추가합니다.

```dart
import '../utils/folder_tree.dart';
```

`AppSidebar` 클래스를 `StatelessWidget`에서 `StatefulWidget`으로 바꾸고,
콜백을 추가합니다.

```dart
class AppSidebar extends StatefulWidget {
  const AppSidebar({
    super.key,
    required this.userName,
    required this.folders,
    required this.selectedFolderId,
    required this.onSelectFolder,
    required this.onCreateSubfolder,
    required this.onRenameFolder,
    required this.onDeleteFolder,
    required this.onMoveFolder,
    required this.onOpenBoards,
    required this.onOpenTrash,
    required this.onOpenSettings,
    required this.onLogInOut,
  });

  final String userName;
  final List<TaxonomyItem> folders;
  final String? selectedFolderId;
  final ValueChanged<String?> onSelectFolder;

  /// "하위 폴더 만들기"를 눌렀을 때 실행합니다. 어느 폴더 밑에 만들지 알려줍니다.
  final ValueChanged<TaxonomyItem> onCreateSubfolder;

  /// "이름 바꾸기"를 눌렀을 때 실행합니다.
  final ValueChanged<TaxonomyItem> onRenameFolder;

  /// "삭제"를 눌렀을 때 실행합니다.
  final ValueChanged<TaxonomyItem> onDeleteFolder;

  /// 폴더를 드래그해서 다른 폴더(또는 "전체 레퍼런스"/빈 자리) 위에
  /// 놓았을 때 실행합니다. newParentId가 null이면 최상위로 옮기라는
  /// 뜻입니다.
  final void Function(String draggedFolderId, String? newParentId) onMoveFolder;

  final VoidCallback onOpenBoards;
  final VoidCallback onOpenTrash;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogInOut;

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}
```

이어서 상태 클래스를 만듭니다. 기존에 `AppSidebar`(구 StatelessWidget)
안에 있던 메서드들(`build`, `_buildUserBlock`, `_buildBoardsBlock`,
`_buildFolderList`, `_buildBottomBlock`, `_buildNavItem`, `_initial`)을
전부 이 새 상태 클래스 안으로 옮기고, `this.`로 접근하던 필드는
`widget.`으로 바꿉니다(`userName` → `widget.userName` 등).
`_buildFolderList`만 아래처럼 새로 씁니다(나머지는 그대로 옮기면
됩니다).

```dart
class _AppSidebarState extends State<AppSidebar> {
  /// 지금 펼쳐진 폴더의 id들입니다. 화면을 나가면(위젯이 다시 만들어지면)
  /// 초기화됩니다 — 이번 범위에서는 영구 저장하지 않습니다. 기본은
  /// "전부 펼침"입니다 — 갑자기 하위 폴더가 안 보이면 사용자가 당황하기
  /// 때문에, 접는 것은 사용자가 직접 고르게 합니다.
  final Set<String> _expandedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _expandedIds.addAll(widget.folders.map((TaxonomyItem f) => f.id));
  }

  /// 새로 생긴 폴더도 기본으로 펼쳐둡니다.
  @override
  void didUpdateWidget(covariant AppSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Set<String> oldIds =
        oldWidget.folders.map((TaxonomyItem f) => f.id).toSet();
    for (final TaxonomyItem folder in widget.folders) {
      if (!oldIds.contains(folder.id)) {
        _expandedIds.add(folder.id);
      }
    }
  }

  /// 폴더 하나의 펼침 상태를 뒤집습니다.
  void _toggleExpanded(String folderId) {
    setState(() {
      if (!_expandedIds.remove(folderId)) {
        _expandedIds.add(folderId);
      }
    });
  }

  // ... build(), _buildUserBlock(), _buildBoardsBlock(), _buildBottomBlock(),
  // _buildNavItem(), _initial()은 기존 AppSidebar에서 그대로 옮기되
  // this.xxx를 widget.xxx로 바꿉니다.

  /// ② 폴더 목록입니다. 트리(들여쓰기 + 펼치기/접기)로 보여줍니다.
  Widget _buildFolderList(AppPalette dark) {
    final List<FolderTreeEntry> tree = buildFolderTree(widget.folders);
    final List<FolderTreeEntry> visible = _visibleEntries(tree);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: dark.surface,
        borderRadius: BorderRadius.circular(appCornerRadius),
        border: Border.all(color: dark.border),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildAllReferencesRow(dark),
          for (final FolderTreeEntry entry in visible)
            _buildFolderRow(dark, entry, tree),
        ],
      ),
    );
  }

  /// [tree]에서, 접힌 폴더의 하위는 뺀 "지금 눈에 보여야 할" 목록을 돌려줍니다.
  List<FolderTreeEntry> _visibleEntries(List<FolderTreeEntry> tree) {
    final List<FolderTreeEntry> visible = <FolderTreeEntry>[];
    int? hiddenBelowDepth;

    for (final FolderTreeEntry entry in tree) {
      if (hiddenBelowDepth != null) {
        if (entry.depth > hiddenBelowDepth!) {
          continue;
        }
        hiddenBelowDepth = null;
      }

      visible.add(entry);

      final bool hasChildren =
          tree.any((FolderTreeEntry e) => e.folder.parentId == entry.folder.id);
      if (hasChildren && !_expandedIds.contains(entry.folder.id)) {
        hiddenBelowDepth = entry.depth;
      }
    }
    return visible;
  }

  /// "전체 레퍼런스" 줄입니다. 폴더를 여기로 끌어다 놓으면 최상위로 옮겨집니다.
  Widget _buildAllReferencesRow(AppPalette dark) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (DragTargetDetails<String> details) => true,
      onAcceptWithDetails: (DragTargetDetails<String> details) =>
          widget.onMoveFolder(details.data, null),
      builder: (BuildContext context, List<String?> candidateData, List<Object?> rejectedData) {
        return _buildNavItem(
          dark,
          icon: Icons.photo_library_outlined,
          label: '전체 레퍼런스',
          isSelected: widget.selectedFolderId == null,
          onTap: () => widget.onSelectFolder(null),
        );
      },
    );
  }

  /// 폴더 하나의 줄입니다. 들여쓰기, 펼치기/접기 화살표(자식이 있을 때만),
  /// 메뉴(⋮), 드래그로 옮기기를 담당합니다.
  Widget _buildFolderRow(
    AppPalette dark,
    FolderTreeEntry entry,
    List<FolderTreeEntry> tree,
  ) {
    final TaxonomyItem folder = entry.folder;
    final bool hasChildren =
        tree.any((FolderTreeEntry e) => e.folder.parentId == folder.id);
    final bool isExpanded = _expandedIds.contains(folder.id);

    // 이름 부분만 드래그로 잡을 수 있게 합니다. 메뉴 버튼까지 드래그
    // 대상으로 감싸면 메뉴를 누르려는 손짓과 드래그 손짓이 부딪힙니다.
    final Widget draggableLabel = Draggable<String>(
      data: folder.id,
      feedback: Material(
        color: Colors.transparent,
        child: Chip(label: Text(folder.name)),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _buildNavItem(
          dark,
          icon: Icons.folder_copy_outlined,
          label: folder.name,
          isSelected: widget.selectedFolderId == folder.id,
          onTap: () => widget.onSelectFolder(folder.id),
        ),
      ),
      child: _buildNavItem(
        dark,
        icon: Icons.folder_copy_outlined,
        label: folder.name,
        isSelected: widget.selectedFolderId == folder.id,
        onTap: () => widget.onSelectFolder(folder.id),
      ),
    );

    final Widget row = Padding(
      padding: EdgeInsets.only(left: entry.depth * 16.0),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 24,
            child: hasChildren
                ? IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    color: dark.textDim,
                    icon: Icon(isExpanded ? Icons.expand_more : Icons.chevron_right),
                    onPressed: () => _toggleExpanded(folder.id),
                  )
                : null,
          ),
          Expanded(child: draggableLabel),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 18, color: dark.textDim),
            onSelected: (String value) {
              if (value == 'subfolder') {
                widget.onCreateSubfolder(folder);
              } else if (value == 'rename') {
                widget.onRenameFolder(folder);
              } else if (value == 'delete') {
                widget.onDeleteFolder(folder);
              }
            },
            itemBuilder: (BuildContext context) {
              return const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(value: 'subfolder', child: Text('하위 폴더 만들기')),
                PopupMenuItem<String>(value: 'rename', child: Text('이름 바꾸기')),
                PopupMenuItem<String>(value: 'delete', child: Text('삭제')),
              ];
            },
          ),
        ],
      ),
    );

    return DragTarget<String>(
      // 자기 자신 위로는 못 옮깁니다. 자기 하위로 옮기는 순환은 여기서
      // 안 막고 저장소(moveFolder)가 막습니다 — 드래그하는 시점에는
      // "자기 하위가 누구인지" 매번 계산하기보다, 실제로 놓았을 때
      // home_screen.dart의 onMoveFolder가 예외를 받아 안내합니다.
      onWillAcceptWithDetails: (DragTargetDetails<String> details) =>
          details.data != folder.id,
      onAcceptWithDetails: (DragTargetDetails<String> details) =>
          widget.onMoveFolder(details.data, folder.id),
      builder: (BuildContext context, List<String?> candidateData, List<Object?> rejectedData) {
        final bool isHovering = candidateData.isNotEmpty;
        return Container(
          decoration: isHovering
              ? BoxDecoration(
                  border: Border.all(color: dark.accent),
                  borderRadius: BorderRadius.circular(inputCornerRadius),
                )
              : null,
          child: row,
        );
      },
    );
  }
}
```

(이 Step은 Task 11의 드래그앤드롭 코드를 이미 포함하고 있습니다 —
`Draggable`/`DragTarget`을 트리 구조와 동시에 짜는 게 따로 짜서 나중에
합치는 것보다 간단해서 한 Step에 같이 넣었습니다. Task 11에서는 이
동작을 검증하는 테스트만 추가합니다.)

- [ ] **Step 4: home_screen.dart에 새 핸들러 연결**

`lib/screens/home_screen.dart`의 import에 추가합니다.

```dart
import '../repositories/taxonomy_repository.dart'; // 이미 있음 — FolderMoveCycleException도 여기서 옵니다.
import '../utils/folder_tree.dart';
import '../widgets/create_taxonomy_dialog.dart';
import '../widgets/rename_taxonomy_dialog.dart';
```

`_buildSidebar()`를 바꿉니다.

```dart
  /// 왼쪽 사이드바를 만듭니다. (①②③)
  Widget _buildSidebar() {
    return AppSidebar(
      userName: widget.settings.userName,
      folders: _taxonomyOptions[TaxonomyKind.folder] ?? <TaxonomyItem>[],
      selectedFolderId: _selectedFolderId,
      onSelectFolder: _selectFolder,
      onCreateSubfolder: _createSubfolder,
      onRenameFolder: _renameFolder,
      onDeleteFolder: _deleteFolderFromSidebar,
      onMoveFolder: _moveFolder,
      onOpenBoards: _openBoards,
      onOpenTrash: _openTrash,
      onOpenSettings: _openSettings,
      onLogInOut: _showLoginNotReady,
    );
  }
```

`_selectFolder` 메서드 다음에 새 메서드들을 추가합니다.

```dart
  /// 사이드바 메뉴에서 "하위 폴더 만들기"를 눌렀을 때 실행됩니다.
  Future<void> _createSubfolder(TaxonomyItem parent) async {
    final TaxonomyItem? created = await showCreateTaxonomyDialog(
      context: context,
      kind: TaxonomyKind.folder,
      repository: widget.taxonomyRepository,
      allFolders: _taxonomyOptions[TaxonomyKind.folder] ?? <TaxonomyItem>[],
      initialParentId: parent.id,
    );
    if (created != null) {
      await _loadTaxonomyOptions();
    }
  }

  /// 사이드바 메뉴에서 폴더의 "이름 바꾸기"를 눌렀을 때 실행됩니다.
  Future<void> _renameFolder(TaxonomyItem folder) async {
    final bool renamed = await showRenameTaxonomyDialog(
      context: context,
      item: folder,
      repository: widget.taxonomyRepository,
      allFolders: _taxonomyOptions[TaxonomyKind.folder] ?? <TaxonomyItem>[],
    );
    if (renamed) {
      await _loadTaxonomyOptions();
      await _loadItems(); // 이름이 카드에도 보이는 곳이 있어 함께 새로고침합니다.
    }
  }

  /// 사이드바 메뉴에서 폴더의 "삭제"를 눌렀을 때 실행됩니다.
  Future<void> _deleteFolderFromSidebar(TaxonomyItem folder) async {
    final List<TaxonomyItem> folders =
        _taxonomyOptions[TaxonomyKind.folder] ?? <TaxonomyItem>[];
    final Set<String> idsToDelete =
        collectFolderAndDescendantIds(folder.id, parentIdMap(folders));
    final int subfolderCount = idsToDelete.length - 1;

    final String message = subfolderCount > 0
        ? '"${folder.name}" 폴더를 지웁니다.\n하위 폴더 $subfolderCount개도 함께 지워집니다.'
        : '"${folder.name}" 폴더를 지웁니다.';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('폴더 삭제'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await widget.taxonomyRepository.delete(folder.id);

    // 지금 보고 있던 폴더(또는 그 상위)가 지워졌으면 "전체"로 돌아갑니다.
    // 안 그러면 있지도 않은 폴더를 보고 있는 채로 남습니다.
    if (_selectedFolderId != null && idsToDelete.contains(_selectedFolderId)) {
      _selectFolder(null);
    }

    await _loadTaxonomyOptions();
    await _loadItems();
  }

  /// 사이드바에서 폴더를 다른 폴더(또는 최상위) 위로 드래그해서 옮겼을 때
  /// 실행됩니다.
  Future<void> _moveFolder(String draggedFolderId, String? newParentId) async {
    try {
      await widget.taxonomyRepository.moveFolder(draggedFolderId, newParentId);
    } on FolderMoveCycleException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('폴더를 그 위치로 옮길 수 없습니다.')),
      );
      return;
    }
    await _loadTaxonomyOptions();
  }
```

- [ ] **Step 5: 테스트 실행해서 통과 확인**

Run: `flutter test test/screens/home_folders_sidebar_test.dart`
Expected: PASS (모든 테스트, 기존 것 포함)

- [ ] **Step 6: 전체 확인**

Run: `flutter analyze && flutter test`
Expected: 전부 PASS. (다른 화면에서 `AppSidebar(...)`을 직접 만드는
테스트가 있다면 새 필수 콜백 4개 때문에 컴파일이 깨질 수 있습니다 —
`grep -rl "AppSidebar(" lib test`로 찾아 전부 고쳐줍니다.)

- [ ] **Step 7: 커밋**

```bash
git add lib/widgets/app_sidebar.dart lib/screens/home_screen.dart \
  test/screens/home_folders_sidebar_test.dart
git commit -m "사이드바 폴더 목록을 트리로 바꾸고 하위 폴더 만들기/이름 바꾸기/삭제 메뉴를 추가한다"
```

---

## Task 11: 드래그앤드롭으로 폴더 옮기기 — 테스트로 확정

**Files:**
- Modify: `test/screens/home_folders_sidebar_test.dart`

**Interfaces:**
- Consumes: Task 10에서 이미 구현된 `Draggable`/`DragTarget`,
  `home_screen.dart`의 `_moveFolder`.

(Task 10 Step 3에서 드래그앤드롭 UI 코드 자체는 이미 구현했습니다. 이
태스크는 그 동작을 테스트로 확정하는 것이 전부입니다 — 트리 구조와
드래그 코드가 서로 얽혀 있어서(같은 `_buildFolderRow`) 나눠 구현하면
오히려 왔다갔다하게 됩니다.)

- [ ] **Step 1: 실패하는 테스트부터 작성**

`test/screens/home_folders_sidebar_test.dart`의 `group('폴더 트리(하위
폴더)', ...)` 안에 추가합니다.

```dart
    testWidgets('폴더를 다른 폴더 위로 끌어다 놓으면 하위로 옮겨진다', (WidgetTester tester) async {
      final String targetId = await saveFolder('인물');
      final String draggedId = await saveFolder('풍경');

      await openApp(tester);

      await tester.drag(
        find.text('풍경'),
        tester.getCenter(find.text('인물')) - tester.getCenter(find.text('풍경')),
      );
      await tester.pumpAndSettle();

      final TaxonomyItem? moved = await taxonomyRepository.getById(draggedId);
      expect(moved!.parentId, targetId);
    });

    testWidgets('자기 하위로 옮기려 하면 안내하고 그대로 둔다', (WidgetTester tester) async {
      final String parentId = await saveFolder('인물');
      final DateTime now = DateTime.now().toUtc();
      final String childId = newId();
      await taxonomyRepository.save(TaxonomyItem(
        id: childId,
        kind: TaxonomyKind.folder,
        name: '얼굴',
        parentId: parentId,
        createdAt: now,
        updatedAt: now,
      ));

      await openApp(tester);

      await tester.drag(
        find.text('인물'),
        tester.getCenter(find.text('얼굴')) - tester.getCenter(find.text('인물')),
      );
      await tester.pumpAndSettle();

      expect(find.text('폴더를 그 위치로 옮길 수 없습니다.'), findsOneWidget);

      final TaxonomyItem? unchanged = await taxonomyRepository.getById(parentId);
      expect(unchanged!.parentId, isNull);
    });

    testWidgets('"전체 레퍼런스" 위로 끌어다 놓으면 최상위로 돌아간다', (WidgetTester tester) async {
      final String parentId = await saveFolder('인물');
      final DateTime now = DateTime.now().toUtc();
      final String childId = newId();
      await taxonomyRepository.save(TaxonomyItem(
        id: childId,
        kind: TaxonomyKind.folder,
        name: '얼굴',
        parentId: parentId,
        createdAt: now,
        updatedAt: now,
      ));

      await openApp(tester);

      await tester.drag(
        find.text('얼굴'),
        tester.getCenter(find.text('전체 레퍼런스')) - tester.getCenter(find.text('얼굴')),
      );
      await tester.pumpAndSettle();

      final TaxonomyItem? moved = await taxonomyRepository.getById(childId);
      expect(moved!.parentId, isNull);
    });
```

- [ ] **Step 2: 테스트 실행**

Run: `flutter test test/screens/home_folders_sidebar_test.dart`
Expected: PASS. (Task 10에서 이미 구현이 끝나 있으므로 바로 통과해야
합니다. **만약 `tester.drag`로 드래그가 인식되지 않으면** — 플러터의
기본 `Draggable`이 즉시-드래그가 아니라 스크롤/제스처 경쟁 때문에
`tester.drag` 한 번으로 안 잡힐 수 있습니다 — CLAUDE.md "끄는 도중의
상태 변화가 얽힌 문제는 tester.drag로 못 잡습니다" 절을 참고해
`tester.startGesture` + `moveTo` 사이에 `pump()`를 넣는 방식으로
바꾸세요:
```dart
final TestGesture gesture = await tester.startGesture(tester.getCenter(find.text('풍경')));
await tester.pump(const Duration(milliseconds: 50));
await gesture.moveTo(tester.getCenter(find.text('인물')));
await tester.pump(const Duration(milliseconds: 50));
await gesture.up();
await tester.pumpAndSettle();
```
)

- [ ] **Step 3: 전체 확인**

Run: `flutter analyze && flutter test`
Expected: 전부 PASS.

- [ ] **Step 4: 커밋**

```bash
git add test/screens/home_folders_sidebar_test.dart
git commit -m "사이드바 드래그앤드롭으로 폴더 옮기기를 테스트로 확정한다"
```

---

## Task 12: 마무리 — 실제 실행 확인 + 문서화

**Files:**
- Modify: `CLAUDE.md` (개발 단계 표, "저장 구조 v7" 관련 절 추가)
- Modify: `update.md` (새 PR 항목 추가)

- [ ] **Step 1: 전체 분석·테스트**

Run: `flutter analyze && flutter test`
Expected: 0 issues, 모든 테스트 PASS. 실패가 있으면 이 태스크를 끝내기
전에 전부 고칩니다.

- [ ] **Step 2: 실제 앱으로 눈으로 확인 (의뢰인 대신 최소 확인)**

Run: `flutter run -d windows` (개발용 실행.bat과 동일한 방식)

다음을 직접 눌러봅니다.
- 사이드바에서 폴더 만들기 → 그 폴더 메뉴(⋮)로 "하위 폴더 만들기" →
  들여써서 보이는지
- 펼치기/접기 화살표
- 상위 폴더를 고르면 하위 폴더 레퍼런스도 함께 보이는지
- 폴더를 드래그해서 다른 폴더 위로 옮기기
- 자기 하위로 옮기려 할 때 스낵바가 뜨는지
- 하위 폴더가 있는 폴더 삭제 시 확인창에 개수가 뜨는지
- 분류 관리 화면 폴더 탭이 트리로 보이는지, 새로 만들기/이름 바꾸기에서
  상위 폴더를 고를 수 있는지
- 레퍼런스 편집 화면의 폴더 칸이 들여써서 보이는지

문제가 있으면 해당 태스크로 돌아가 고칩니다.

- [ ] **Step 3: CLAUDE.md 갱신**

`## 개발 단계` 안, 가장 최근 완료 항목들 근처(파트 제거/사이드바 폴더화
관련 서술) 다음에 짧게 추가합니다.

```markdown
### 단계 밖 작업: 폴더 중첩(하위 폴더) ✅ 완료

PR #60이 남긴 한계("폴더 중첩은 없습니다")를 해소했습니다. 설계는
`docs/superpowers/specs/2026-09-11-nested-folders-design.md`, 계획은
`docs/superpowers/plans/2026-09-11-nested-folders.md`에 있습니다.

- **저장 구조 v7**: `TaxonomyItems.parentId`(nullable, 자기 참조) 추가.
- 트리 계산(깊이, 하위 id 모으기, 순환 검사)은 전부
  `lib/utils/folder_tree.dart`의 순수 함수로 뽑아, 저장소·다이얼로그·
  사이드바·분류 관리 화면이 공통으로 씁니다.
- 사이드바에서 상위 폴더를 고르면 **그 폴더 자신 + 모든 하위 폴더**의
  레퍼런스를 함께 보여줍니다(`LocalReferenceRepository.search`가
  `folderId`를 자신+하위 집합으로 확장 — 저장소 한 곳만 고쳐서 이 저장소를
  쓰는 모든 화면에 자동 적용됩니다).
- 무드보드의 폴더 연결(`board.folderId`)과 새 레퍼런스 자동 배정은
  **하위로 확장되지 않습니다** — 정확히 그 폴더 하나를 가리키는 지금
  동작 그대로입니다(의도적).
- 하위 폴더가 있는 폴더를 지우면 하위 전체가 함께 지워집니다(삭제
  확인창에 개수 표시).
- 폴더 이름 중복 금지는 전체 기준에서 **같은 상위 폴더 밑** 기준으로
  좁아졌습니다.
- 다음에 이 부분을 고치려면: 사이드바 트리는
  `lib/widgets/app_sidebar.dart`의 `_buildFolderRow`/`_visibleEntries`,
  트리 계산 자체는 `lib/utils/folder_tree.dart`, 순환 방지·연쇄 삭제는
  `lib/repositories/local_taxonomy_repository.dart`의 `moveFolder`/`delete`.
```

- [ ] **Step 4: update.md에 PR 항목 추가**

파일 맨 끝(가장 최근 PR, `## PR #61 — ...` 다음)에 추가합니다. 실제 PR
번호는 병합 시점의 GitHub PR 번호로 바꿉니다(아래는 자리표시용 `#62`).

```markdown
## PR #62 — 폴더 중첩(하위 폴더)을 추가한다

**무엇을**: 사이드바와 분류 관리 화면의 폴더에 하위 폴더(중첩, 무제한
깊이)를 추가했습니다. 상위 폴더를 고르면 하위 폴더의 레퍼런스도 함께
보입니다.

**왜**: PR #60에서 파트를 없애고 사이드바를 폴더로 바꾸며 "폴더 중첩은
없습니다"를 알려진 한계로 남겼는데, 의뢰인이 이 한계를 풀어달라고
요청했습니다.

### 확정된 동작

- 폴더 안에 폴더를 무제한으로 만들 수 있습니다.
- 사이드바에서 상위 폴더를 고르면 그 폴더 자신과 모든 하위 폴더의
  레퍼런스가 함께 보입니다.
- 하위 폴더가 있는 폴더를 지우면 하위 전체가 함께 지워집니다(확인창에
  개수 표시).
- 폴더 이름 중복은 이제 같은 상위 폴더 밑에서만 막힙니다(다른 가지에는
  같은 이름을 써도 됩니다).
- 사이드바에서 폴더를 드래그해서 다른 폴더 위에 놓으면 그 하위로
  옮겨집니다. "전체 레퍼런스" 위나 빈 자리에 놓으면 최상위로 돌아갑니다.
  자기 자신이나 자기 하위로 옮기려 하면 스낵바로 안내하고 그대로 둡니다.
- 사이드바 폴더 줄의 메뉴(⋮)로 "하위 폴더 만들기/이름 바꾸기/삭제"를
  할 수 있습니다. 분류 관리 화면에서도 새로 만들기/이름 바꾸기 대화상자에
  "상위 폴더" 칸이 생겼습니다.
- 무드보드의 폴더 연결과 새 레퍼런스 자동 배정은 하위로 확장되지
  않습니다 — 지금처럼 정확히 그 폴더 하나만 가리킵니다(의도적으로
  범위 밖에 둠).

### 저장 구조 v7 — TaxonomyItems.parentId 추가

`m.addColumn(taxonomyItems, taxonomyItems.parentId)`만으로 충분했습니다.
taxonomy_items 표가 schemaVersion 1부터 onCreate로만 만들어지고 그 뒤
어떤 버전도 createTable로 다시 만든 적이 없어서, boards.folderId(v5)가
겪었던 "이미 최신 정의로 새로 만들어짐" 특수 조건이 필요 없었습니다.

### 새로 생긴 것: lib/utils/folder_tree.dart

트리 계산(깊이 매기기, 자기+하위 id 모으기, 순환 방지에 쓰는 재료)을
순수 함수로 뽑았습니다. 저장소(순환 검사, 연쇄 삭제), 사이드바(트리
그리기), 분류 관리 화면(트리 그리기), 새로 만들기/이름 바꾸기
대화상자(상위 폴더 후보 만들기)가 전부 이 파일 하나를 공유합니다.

### 개념 새로 나온 것: (없음 — 이 PR은 기존에 쓰던 Repository/StatefulWidget
패턴만 그대로 확장했습니다. 새 Flutter/Dart 개념은 도입하지 않았습니다.)

### 배운 것 / 다음에 참고할 것

- **`TaxonomyItem.copyWith`로는 parentId를 못 바꿉니다.** 순환 참조
  검사가 필요해서 일부러 뺐습니다 — 부모를 바꾸는 건 반드시
  `TaxonomyRepository.moveFolder()`를 거칩니다.
- **이름 바꾸기 대화상자에서 이름과 상위 폴더를 동시에 바꿀 때는
  순서가 중요합니다.** `save()`는 항목을 통째로 다시 쓰기 때문에, 옛
  parentId를 들고 있는 `widget.item`으로 나중에 `save()`를 부르면
  먼저 옮겨둔 새 parentId를 도로 덮어씁니다. 그래서 이름을 먼저
  `save()`하고, 상위 폴더 이동(`moveFolder`)은 마지막에 합니다
  (`rename_taxonomy_dialog.dart`의 `_save()` 주석 참고).
- **하위 폴더 안내(레퍼런스가 하위에도 있을 수 있다는 것)를 놓친 채로
  개수를 세면 안 됩니다.** 분류 관리 화면·사이드바의 삭제 확인창은 둘 다
  `collectFolderAndDescendantIds`로 하위 개수를 미리 계산해 보여줍니다.

### 어떻게 테스트했나

- `flutter analyze` 문제 없음.
- `flutter test` 전부 통과 (신규: `migration_v6_to_v7_test.dart`,
  `folder_tree_test.dart`, `pick_taxonomy_dialog_test.dart`, 기존 파일에
  추가된 하위 폴더 관련 테스트들).
- 실제 `flutter run -d windows`로 트리 표시·펼치기/접기·드래그앤드롭·
  삭제 확인창·상위 폴더 선택 칸을 직접 눌러 확인.

**한계**: 폴더 순서를 직접 정렬할 수 없습니다(항상 가나다순). 사이드바
펼침/접힘 상태는 앱을 재시작하면 초기화됩니다.
```

- [ ] **Step 5: 커밋**

```bash
git add CLAUDE.md update.md
git commit -m "CLAUDE.md와 update.md에 폴더 중첩 작업을 정리한다"
```

- [ ] **Step 6: 푸시하고 PR 열기**

```bash
git push -u origin nested-folders
gh pr create --title "폴더 중첩(하위 폴더)을 추가한다" --body "설계: docs/superpowers/specs/2026-09-11-nested-folders-design.md 참고. 계획: docs/superpowers/plans/2026-09-11-nested-folders.md 참고."
```

(PR 병합 후, Step 4의 update.md 항목에 적은 자리표시용 PR 번호(#62)를
실제 번호로 고쳐 한 번 더 커밋하세요 — 기존 PR 항목들의 관례입니다.)
