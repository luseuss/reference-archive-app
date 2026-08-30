# 레퍼런스 메모 리치텍스트 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 레퍼런스 상세 화면의 메모 칸을 순수 텍스트에서 리치텍스트(글자색·형광펜·굵게/기울임/밑줄·목록·링크·정렬)로 바꾼다.

**Architecture:** `flutter_quill` 패키지의 `QuillController`/`QuillEditor`/`QuillSimpleToolbar`로 편집기를 만들고, 문서를 Delta(JSON) 문자열로 직렬화해 지금과 같은 `memo TEXT` 칼럼에 저장한다. Delta ↔ 순수 텍스트 변환은 화면 없이 테스트 가능한 순수 함수(`rich_text_memo.dart`)로 뺀다. 기존에 저장된 순수 텍스트 메모는 저장 구조 v4 마이그레이션으로 최소 Delta로 감싸 그대로 보이게 한다.

**Tech Stack:** Flutter, `flutter_quill` (리치텍스트 편집기), drift(로컬 DB, 마이그레이션), `flutter_test`(단위·위젯 테스트)

**Spec:** `docs/superpowers/specs/2026-08-31-rich-text-memo-design.md`

## Global Constraints

- **범위는 레퍼런스 메모만.** 무드보드 카드 주석은 이번에 포함하지 않는다.
- **저장 형식은 Delta(JSON) 문자열.** `memo` 칼럼 타입은 그대로 `TEXT`.
- **저장 구조 v4 마이그레이션 필요** (`schemaVersion` 3 → 4). 기존 순수 텍스트 메모를 `[{"insert": "<글자>\n"}]` 형태로 감싼다.
- **검색(`_containsText`)은 이번에 손대지 않는다.**
- **새 칸을 추가하는 마이그레이션이 아니라 "있는 값을 다시 쓰는" 마이그레이션**이므로 `addColumn` 대신 `update`를 쓴다.
- **모든 새 파일 상단에 한국어로 그 파일의 역할을 설명하는 주석을 단다.** 모든 함수 위에 한국어 한 줄 주석을 단다(프로젝트 `CLAUDE.md` 규칙).
- **저장하지 않는 코드는 없다** — `flutter analyze`가 항상 깨끗해야 하고, 각 태스크가 끝날 때마다 `flutter test`가 전부 통과해야 한다.

---

### Task 1: `flutter_quill` 패키지 추가

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock` (자동 갱신)

**Interfaces:**
- Consumes: 없음
- Produces: `package:flutter_quill/flutter_quill.dart`(`Document`, `QuillController`, `QuillEditor`, `QuillSimpleToolbar` 등), `package:flutter_quill/quill_delta.dart`(`Delta`) — 이후 모든 태스크가 이 두 import 경로를 씁니다.

- [ ] **Step 1: 패키지를 추가합니다**

```bash
flutter pub add flutter_quill
```

- [ ] **Step 2: `pubspec.yaml`에 `flutter_quill: ^11.5.1`(또는 그 이상)이 추가됐는지 확인합니다**

```bash
grep "flutter_quill:" pubspec.yaml
```

Expected: `  flutter_quill: ^11.5.1` (버전 숫자는 pub.dev 최신 버전에 따라 다를 수 있습니다 — 그대로 둡니다)

- [ ] **Step 3: 프로젝트가 여전히 정상 분석되는지 확인합니다**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: 커밋**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "flutter_quill 패키지를 추가한다 (레퍼런스 메모 리치텍스트)"
```

---

### Task 2: Delta ↔ 순수 텍스트 변환 유틸리티

**Files:**
- Create: `lib/utils/rich_text_memo.dart`
- Test: `test/utils/rich_text_memo_test.dart`

**Interfaces:**
- Consumes: `package:flutter_quill/flutter_quill.dart`의 `Document`, `package:flutter_quill/quill_delta.dart`의 `Delta`
- Produces:
  - `Document documentFromMemo(String? memo)` — DB에 저장된 메모 문자열을 `flutter_quill`의 `Document`로 되돌립니다. Task 4(`RichMemoEditor`)가 씁니다.
  - `String memoFromDocument(Document document)` — `Document`를 저장용 문자열로 바꿉니다. Task 4가 씁니다.
  - `String plainTextFromMemo(String? memo)` — 서식을 뺀 순수 글자만 뽑습니다. Task 6(`reference_card.dart`)이 씁니다.

- [ ] **Step 1: 실패하는 테스트를 먼저 씁니다**

`test/utils/rich_text_memo_test.dart`:

```dart
// Delta(JSON) 문자열과 순수 텍스트를 오가는 계산이 맞는지 확인하는
// 테스트입니다. 화면 없이 통과할 수 있는 순수 함수라 위젯 없이 봅니다.

import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/utils/rich_text_memo.dart';

void main() {
  group('documentFromMemo', () {
    test('null이면 빈 문서를 돌려준다', () {
      final Document doc = documentFromMemo(null);
      expect(doc.toPlainText().trim(), '');
    });

    test('빈 글자면 빈 문서를 돌려준다', () {
      final Document doc = documentFromMemo('   ');
      expect(doc.toPlainText().trim(), '');
    });

    test('유효한 Delta JSON이면 그대로 읽는다', () {
      final String delta = jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'insert': '굵은 글자',
          'attributes': <String, dynamic>{'bold': true},
        },
        <String, dynamic>{'insert': '\n'},
      ]);

      final Document doc = documentFromMemo(delta);

      expect(doc.toPlainText().trim(), '굵은 글자');
    });

    test('마이그레이션 전 순수 텍스트도 그대로 문서로 읽는다', () {
      // v3까지는 memo가 그냥 글자였습니다. 마이그레이션(v4)이 대부분
      // 처리하지만, 혹시 못 탄 값이 남아있어도 여기서 한 번 더 방어합니다.
      final Document doc = documentFromMemo('색감 참고');

      expect(doc.toPlainText().trim(), '색감 참고');
    });

    test('깨진 JSON이어도 그 글자를 그대로 문서로 읽는다', () {
      final Document doc = documentFromMemo('{이건 JSON이 아님');

      expect(doc.toPlainText().trim(), '{이건 JSON이 아님');
    });
  });

  group('memoFromDocument', () {
    test('문서를 저장용 Delta 문자열로 바꾼다', () {
      final Document doc = Document.fromDelta(Delta()..insert('안녕\n'));

      final String saved = memoFromDocument(doc);

      // 저장한 뒤 다시 읽으면 같은 글자가 나와야 합니다(원본 왕복).
      expect(documentFromMemo(saved).toPlainText().trim(), '안녕');
    });
  });

  group('plainTextFromMemo', () {
    test('null이면 빈 글자를 돌려준다', () {
      expect(plainTextFromMemo(null), '');
    });

    test('서식이 있어도 글자만 뽑는다', () {
      final String delta = jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'insert': '색감',
          'attributes': <String, dynamic>{'color': '#ff0000'},
        },
        <String, dynamic>{'insert': ' 참고\n'},
      ]);

      expect(plainTextFromMemo(delta), '색감 참고');
    });

    test('마이그레이션 전 순수 텍스트도 그대로 돌려준다', () {
      expect(plainTextFromMemo('색감 참고'), '색감 참고');
    });
  });
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인합니다**

```bash
flutter test test/utils/rich_text_memo_test.dart
```

Expected: FAIL — `rich_text_memo.dart` 파일이 없어서 import 오류가 납니다.

- [ ] **Step 3: 유틸리티를 만듭니다**

`lib/utils/rich_text_memo.dart`:

```dart
// 레퍼런스 메모(리치텍스트)를 저장용 문자열과 화면용 문서 사이에서
// 오가게 해주는 순수 함수 모음입니다.
//
// ── 왜 이 파일이 따로 있나 ──
// memo 칼럼에는 flutter_quill이 쓰는 Delta라는 JSON 형식이 들어갑니다.
// 이 파일이 없으면 "저장된 글자를 편집기가 읽을 수 있는 문서로 바꾸는 일"과
// "편집기 내용을 저장용 글자로 바꾸는 일"이 화면 코드 여기저기에 흩어집니다.
// 화면 없이도 맞는지 확인할 수 있는 순수한 셈이라 여기 모아뒀습니다.
// (test/utils/rich_text_memo_test.dart)
//
// ── 마이그레이션 전 순수 텍스트를 여기서도 한 번 더 방어하는 이유 ──
// 저장 구조 v4 마이그레이션이 있던 메모를 전부 Delta로 감싸주지만, 혹시
// 못 탄 값이 남아있어도(예: 아주 옛날에 손으로 만든 파일 등) 메모가
// 통째로 안 보이는 것보다는, 서식 없는 글자로라도 보이는 편이 낫습니다.

import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

/// 저장된 메모 문자열을 편집기가 쓸 수 있는 [Document]로 되돌립니다.
///
/// 비어있거나(null, 공백) 못 읽는 값(마이그레이션을 못 탄 순수 텍스트,
/// 깨진 JSON)이면 그 글자를 그대로 담은 문서를 대신 돌려줍니다 — 메모가
/// 통째로 사라지는 것보다 낫습니다.
Document documentFromMemo(String? memo) {
  final String? trimmed = memo?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return Document();
  }

  try {
    final dynamic decoded = jsonDecode(trimmed);
    if (decoded is List) {
      return Document.fromJson(decoded);
    }
  } catch (_) {
    // 아래에서 순수 텍스트로 처리합니다.
  }

  return Document.fromDelta(Delta()..insert('$trimmed\n'));
}

/// 편집기의 [Document]를 저장용 Delta(JSON) 문자열로 바꿉니다.
String memoFromDocument(Document document) {
  return jsonEncode(document.toDelta().toJson());
}

/// 저장된 메모 문자열에서 서식을 뺀 순수 글자만 뽑아냅니다.
///
/// 목록 카드 미리보기(reference_card.dart)에 씁니다. 미리보기는 서식까지
/// 보여줄 자리가 아니라서, 글자만 있으면 됩니다.
String plainTextFromMemo(String? memo) {
  return documentFromMemo(memo).toPlainText().trim();
}
```

- [ ] **Step 4: 테스트가 통과하는지 확인합니다**

```bash
flutter test test/utils/rich_text_memo_test.dart
```

Expected: 모든 테스트 PASS (11개)

- [ ] **Step 5: 커밋**

```bash
git add lib/utils/rich_text_memo.dart test/utils/rich_text_memo_test.dart
git commit -m "메모 Delta ↔ 순수 텍스트 변환 유틸리티를 만든다"
```

---

### Task 3: 저장 구조 v4 마이그레이션 — 기존 메모를 Delta로 감싸기

**Files:**
- Modify: `lib/data/app_database.dart`
- Test: `test/data/migration_v3_to_v4_test.dart`

**Interfaces:**
- Consumes: `dart:convert`의 `jsonEncode`, drift가 생성한 `ReferenceRow`/`ReferencesCompanion`/`$ReferencesTable`(이미 `app_database.g.dart`에 있음)
- Produces: `schemaVersion` 4. 이후 태스크에는 영향 없음(이 태스크는 저장 형식이 이미 v4라고 가정하는 나머지 태스크들의 전제 조건입니다).

- [ ] **Step 1: 실패하는 마이그레이션 테스트를 먼저 씁니다**

`test/data/migration_v3_to_v4_test.dart`:

```dart
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
```

- [ ] **Step 2: 테스트가 실패하는지 확인합니다**

```bash
flutter test test/data/migration_v3_to_v4_test.dart
```

Expected: FAIL — `AppDatabase.forTesting`으로 v3 파일을 열면
schemaVersion이 아직 3이라 아무 마이그레이션도 안 돌고, memo가 여전히
순수 텍스트라서 "안 그대로다(isNot)" 검사에서 실패합니다. (schemaVersion
자체는 3 그대로라 앱은 켜지지만, memo 변환 관련 검사들이 깨집니다)

- [ ] **Step 3: `app_database.dart`에 v4 마이그레이션을 추가합니다**

`lib/data/app_database.dart`의 import 목록 맨 위에 추가:

```dart
import 'dart:convert';
```

`schemaVersion` getter를 고칩니다 (기존 55~59번째 줄 부근):

```dart
  /// ── 버전 기록 ──
  ///   1 — 처음 만든 구조
  ///   2 — References에 partId 추가 (파트 기능). PR #16
  ///   3 — Boards, BoardCards 표 추가 (무드보드). PR #17
  ///   4 — References.memo를 순수 텍스트에서 Delta(JSON)로. 5단계 1번
  @override
  int get schemaVersion => 4;
```

`migration` getter의 `onUpgrade` 안, `if (from < 3)` 다음에 이어서 추가:

```dart
        if (from < 3) {
          await _upgradeToVersion3(m);
        }

        // `if (from < 4)`도 마찬가지입니다. v1이나 v2에 머물러 있던
        // 사용자는 위 단계를 먼저 거친 뒤 여기까지 이어서 실행됩니다.
        if (from < 4) {
          await _upgradeToVersion4();
        }
```

`_upgradeToVersion3` 메서드 뒤(기존 132~135번째 줄 부근)에 새 메서드를
추가합니다:

```dart
  /// 버전 3 → 4. 메모를 순수 텍스트에서 리치텍스트(Delta JSON)로 바꿉니다.
  ///
  /// ── 칼럼을 추가하는 게 아니라 값을 다시 씁니다 ──
  /// memo 칼럼 자체는 그대로 TEXT입니다. 안에 들어가는 내용의 뜻만
  /// "순수 글자"에서 "서식이 붙은 JSON"으로 바뀝니다. 그래서 addColumn이
  /// 아니라 update를 씁니다.
  ///
  /// memo가 비어있는(null) 레퍼런스는 손대지 않습니다 — 빈 메모는 그대로
  /// 빈 메모입니다.
  Future<void> _upgradeToVersion4() async {
    final List<ReferenceRow> rows = await select(references).get();

    for (final ReferenceRow row in rows) {
      final String? memo = row.memo;
      if (memo == null || memo.isEmpty) {
        continue;
      }

      // 최소 Delta로 감쌉니다: "이 글자를 그대로 넣어라"는 명령 하나뿐인
      // 문서입니다. 새 편집기로 열면 서식 없는 원래 글자가 그대로 보입니다.
      final String delta = jsonEncode(<Map<String, String>>[
        <String, String>{'insert': '$memo\n'},
      ]);

      await (update(
        references,
      )..where(($ReferencesTable t) => t.id.equals(row.id))).write(
        ReferencesCompanion(memo: Value<String?>(delta)),
      );
    }
  }
```

- [ ] **Step 4: 테스트가 통과하는지 확인합니다**

```bash
flutter test test/data/migration_v3_to_v4_test.dart
```

Expected: 5개 테스트 모두 PASS

- [ ] **Step 5: 기존 마이그레이션 테스트도 여전히 통과하는지 확인합니다**

```bash
flutter test test/data/
```

Expected: `migration_v1_to_v2_test.dart`, `migration_v2_to_v3_test.dart`,
`migration_v3_to_v4_test.dart` 전부 PASS

- [ ] **Step 6: 커밋**

```bash
git add lib/data/app_database.dart test/data/migration_v3_to_v4_test.dart
git commit -m "저장 구조 v4: 메모를 리치텍스트(Delta)로 마이그레이션한다"
```

---

### Task 4: `RichMemoEditor` 위젯

**Files:**
- Create: `lib/widgets/rich_memo_editor.dart`
- Test: `test/widgets/rich_memo_editor_test.dart`

**Interfaces:**
- Consumes: `documentFromMemo`/`memoFromDocument`(Task 2), `package:flutter_quill/flutter_quill.dart`의 `QuillController`/`QuillEditor`/`QuillSimpleToolbar`
- Produces: `class RichMemoEditor extends StatefulWidget`, 생성자 `RichMemoEditor({Key? key, required String? initialMemo, required ValueChanged<String> onChanged})`. Task 5(`reference_detail_screen.dart`)가 씁니다.

- [ ] **Step 1: 실패하는 위젯 테스트를 먼저 씁니다**

`test/widgets/rich_memo_editor_test.dart`:

```dart
// RichMemoEditor(리치텍스트 메모 편집기)가 값을 제대로 보여주고,
// 바뀐 내용을 알려주는지 확인하는 테스트입니다.
//
// ── 이 테스트가 확인하지 못하는 것 ──
// 서식 버튼(굵게, 색 고르기 등)을 실제로 눌러서 서식이 먹는지는 여기서
// 확인하지 않습니다. flutter_quill 내부의 그림(버튼 배치, 색상 선택기 등)을
// 다시 그려보는 셈이라 위젯 테스트로 잡기보다 앱을 켜서 눈으로 보는 편이
// 낫습니다. 대신 "값을 넣으면 보이는지"와 "내용이 바뀌면 알려주는지"는
// 확실히 잡아둡니다.

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/utils/rich_text_memo.dart';
import 'package:reference_archive_app/widgets/rich_memo_editor.dart';

void main() {
  /// 화면에 지금 떠 있는 QuillEditor의 컨트롤러를 찾아줍니다.
  ///
  /// 편집기 안의 실제 내용을 확인하려면 화면에 그려진 글자를 찾기보다
  /// 컨트롤러가 들고 있는 문서를 직접 보는 편이 안정적입니다.
  QuillController controllerOf(WidgetTester tester) {
    return tester.widget<QuillEditor>(find.byType(QuillEditor)).controller;
  }

  Future<void> pumpEditor(
    WidgetTester tester, {
    String? initialMemo,
    required ValueChanged<String> onChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RichMemoEditor(
            initialMemo: initialMemo,
            onChanged: onChanged,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('초기 메모가 편집기에 그대로 채워진다', (WidgetTester tester) async {
    final String delta = memoFromDocument(
      Document.fromDelta(Delta()..insert('안녕하세요\n')),
    );

    await pumpEditor(tester, initialMemo: delta, onChanged: (_) {});

    expect(controllerOf(tester).document.toPlainText().trim(), '안녕하세요');
  });

  testWidgets('초기 메모가 없으면 빈 문서로 시작한다', (WidgetTester tester) async {
    await pumpEditor(tester, initialMemo: null, onChanged: (_) {});

    expect(controllerOf(tester).document.toPlainText().trim(), '');
  });

  testWidgets('내용을 바꾸면 onChanged로 새 값이 전달된다', (WidgetTester tester) async {
    String? latest;

    await pumpEditor(
      tester,
      initialMemo: null,
      onChanged: (String value) => latest = value,
    );

    controllerOf(
      tester,
    ).replaceText(0, 0, '새 메모', const TextSelection.collapsed(offset: 4));
    await tester.pump();

    expect(latest, isNotNull);
    expect(plainTextFromMemo(latest), '새 메모');
  });
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인합니다**

```bash
flutter test test/widgets/rich_memo_editor_test.dart
```

Expected: FAIL — `rich_memo_editor.dart` 파일이 없어서 import 오류가 납니다.

- [ ] **Step 3: 위젯을 만듭니다**

`lib/widgets/rich_memo_editor.dart`:

```dart
// 레퍼런스 메모를 리치텍스트(글자색·형광펜·굵게/기울임/밑줄·목록·링크·
// 정렬)로 고칠 수 있는 편집기입니다.
//
// ── 이 위젯이 하는 일과 안 하는 일 ──
// 한다  — flutter_quill 편집창 + 툴바를 감싸 보여주고, 바뀐 내용을
//        Delta(JSON) 문자열로 바꿔 [onChanged]로 알립니다.
// 안 한다 — 저장하지 않습니다. "언제 저장할지"는 이 위젯을 쓰는 화면
//          (reference_detail_screen.dart)이 정합니다 — 그 화면은 "저장"
//          버튼을 눌렀을 때만 데이터베이스에 씁니다.
//
// ── Delta가 무엇인가 ──
// flutter_quill(그리고 원래 Quill.js)이 서식 있는 글을 표현하는 JSON
// 형식입니다. "이 글자를 넣어라" "이만큼 굵게 해라" 같은 명령들의 목록으로
// 문서를 나타냅니다. 순수 텍스트보다 복잡하지만, 색·목록·링크 같은 것을
// 다 담을 수 있습니다. (utils/rich_text_memo.dart 설명 참고)

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../utils/rich_text_memo.dart';

/// 리치텍스트 메모 편집기입니다.
class RichMemoEditor extends StatefulWidget {
  const RichMemoEditor({
    super.key,
    required this.initialMemo,
    required this.onChanged,
  });

  /// 지금까지 저장된 메모입니다(Delta JSON 문자열). 없으면 null입니다.
  final String? initialMemo;

  /// 내용이 바뀔 때마다 새 Delta(JSON) 문자열을 알려줍니다.
  final ValueChanged<String> onChanged;

  @override
  State<RichMemoEditor> createState() => _RichMemoEditorState();
}

class _RichMemoEditorState extends State<RichMemoEditor> {
  /// 편집기의 내용과 커서 위치를 관리하는 도구입니다.
  late final QuillController _controller;

  /// 화면이 만들어질 때 지금까지의 메모로 편집기를 채웁니다.
  @override
  void initState() {
    super.initState();

    _controller = QuillController(
      document: documentFromMemo(widget.initialMemo),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _controller.addListener(_handleChanged);
  }

  /// 편집기 내용이 바뀔 때마다 저장용 문자열로 바꿔 바깥에 알립니다.
  void _handleChanged() {
    widget.onChanged(memoFromDocument(_controller.document));
  }

  /// 화면이 사라질 때 컨트롤러를 정리합니다.
  @override
  void dispose() {
    _controller.removeListener(_handleChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(appCornerRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          QuillSimpleToolbar(controller: _controller),
          Divider(height: 1, color: palette.border),

          // 판을 딱 하나만 두는 이유: QuillEditor는 세로 크기가 정해져
          // 있어야 합니다(ListView 안에 그냥 두면 "세로로 끝이 없다"는
          // 오류가 납니다). 기존 TextField의 maxLines: 4와 비슷한
          // 자리를 잡아둡니다.
          SizedBox(height: 200, child: QuillEditor.basic(controller: _controller)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트가 통과하는지 확인합니다**

```bash
flutter test test/widgets/rich_memo_editor_test.dart
```

Expected: 3개 테스트 모두 PASS

- [ ] **Step 5: `flutter analyze`가 깨끗한지 확인합니다**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 6: 커밋**

```bash
git add lib/widgets/rich_memo_editor.dart test/widgets/rich_memo_editor_test.dart
git commit -m "리치텍스트 메모 편집기(RichMemoEditor)를 만든다"
```

---

### Task 5: `reference_detail_screen.dart`에 편집기 연결

**Files:**
- Modify: `lib/screens/reference_detail_screen.dart`
- Modify: `test/screens/reference_detail_screen_test.dart`

**Interfaces:**
- Consumes: `RichMemoEditor`(Task 4), `plainTextFromMemo`(Task 2)
- Produces: 없음(화면 조립의 끝단)

- [ ] **Step 1: 기존 메모 관련 테스트 두 개를 새 편집기에 맞게 고칩니다**

`test/screens/reference_detail_screen_test.dart` 맨 위 import 목록에 추가:

```dart
import 'package:flutter_quill/flutter_quill.dart';
import 'package:reference_archive_app/utils/rich_text_memo.dart';
import 'package:reference_archive_app/widgets/rich_memo_editor.dart';
```

`makeScreen` 함수 뒤에 헬퍼를 하나 추가합니다(파일 안 다른 곳, 예를 들어
85~96번째 줄 `makeScreen` 바로 아래):

```dart
  /// 화면에 지금 떠 있는 메모 편집기의 컨트롤러를 찾아줍니다.
  QuillController memoControllerOf(WidgetTester tester) {
    return tester.widget<QuillEditor>(find.byType(QuillEditor)).controller;
  }
```

`'기존 제목과 메모가 입력창에 채워져 있다'` 테스트(97~108번째 줄)를 이렇게
바꿉니다:

```dart
  testWidgets('기존 제목과 메모가 입력창에 채워져 있다', (WidgetTester tester) async {
    final ReferenceItem item = await saveReference();
    final ReferenceItem withMemo = item.copyWith(memo: '색감 참고');
    await repository.save(withMemo);

    useTallScreen(tester);
    await tester.pumpWidget(makeScreen(withMemo));
    await tester.pumpAndSettle();

    expect(find.text('노을 사진'), findsOneWidget);
    expect(memoControllerOf(tester).document.toPlainText().trim(), '색감 참고');
  });
```

`'메모를 비우면 저장할 때 null이 된다'` 테스트(126~142번째 줄)를 이렇게
바꿉니다:

```dart
  testWidgets('메모를 비우면 저장할 때 null이 된다', (WidgetTester tester) async {
    final ReferenceItem item = await saveReference();
    final ReferenceItem withMemo = item.copyWith(memo: '지울 메모');
    await repository.save(withMemo);

    useTallScreen(tester);
    await tester.pumpWidget(makeScreen(withMemo));
    await tester.pumpAndSettle();

    // 빈 글자와 "적지 않음"을 굳이 구분할 이유가 없어서 null로 저장합니다.
    memoControllerOf(tester).clear();
    await tester.pump();

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    final ReferenceItem? saved = await repository.getById(item.id);
    expect(saved!.memo, isNull);
  });
```

- [ ] **Step 2: 테스트가 실패하는지 확인합니다**

```bash
flutter test test/screens/reference_detail_screen_test.dart
```

Expected: FAIL — 화면이 아직 `TextField`를 쓰고 있어서
`find.byType(QuillEditor)`가 아무것도 못 찾습니다.

- [ ] **Step 3: 화면을 고칩니다**

`lib/screens/reference_detail_screen.dart`의 import 목록에 추가(16번째
줄 `import '../models/enums.dart';` 위나 아래):

```dart
import '../utils/rich_text_memo.dart';
import '../widgets/rich_memo_editor.dart';
```

`_memoController` 필드(51~52번째 줄)를 지우고 대신 이렇게 바꿉니다:

```dart
  /// 지금 편집기에 있는 메모입니다(Delta JSON 문자열). RichMemoEditor의
  /// onChanged가 부를 때마다 갱신됩니다. 저장을 누를 때만 실제로 씁니다.
  String? _memoJson;
```

`initState`(78~94번째 줄)에서 `_memoController = TextEditingController(...)`
줄을 지우고 대신 이렇게 바꿉니다:

```dart
    _memoJson = widget.item.memo;
```

`dispose`(96~103번째 줄)에서 `_memoController.dispose();` 줄을 지웁니다
(RichMemoEditor가 자기 컨트롤러를 스스로 정리합니다).

`_save()`(150~203번째 줄) 안의 이 부분:

```dart
    // 메모는 비어 있으면 null로 저장합니다.
    // 빈 글자와 "적지 않음"을 굳이 구분할 이유가 없습니다.
    final String memoText = _memoController.text.trim();
```

을 이렇게 바꿉니다:

```dart
    // 메모는 비어 있으면 null로 저장합니다.
    // 빈 글자와 "적지 않음"을 굳이 구분할 이유가 없습니다. RichMemoEditor는
    // 빈 문서여도 항상 뭔가(최소한의 Delta)를 돌려주므로, 순수 글자만
    // 뽑아봐서 비어 있는지 판단합니다.
    final String? memoJson = _memoJson;
    final bool memoIsEmpty =
        memoJson == null || plainTextFromMemo(memoJson).isEmpty;
```

그리고 `ReferenceItem(...)` 생성자 호출 안의
`memo: memoText.isEmpty ? null : memoText,` 줄을 이렇게 바꿉니다:

```dart
      memo: memoIsEmpty ? null : memoJson,
```

`_buildForm()`(235~261번째 줄 부근)에서 메모 `TextField` 블록:

```dart
        TextField(
          controller: _memoController,
          // 메모는 여러 줄을 적을 수 있어야 합니다.
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '메모',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
```

을 이렇게 바꿉니다:

```dart
        Text('메모', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        RichMemoEditor(
          initialMemo: widget.item.memo,
          onChanged: (String updated) => _memoJson = updated,
        ),
        const SizedBox(height: 24),
```

- [ ] **Step 4: 테스트가 통과하는지 확인합니다**

```bash
flutter test test/screens/reference_detail_screen_test.dart
```

Expected: 이 파일의 모든 테스트 PASS (메모 관련 2개 포함)

- [ ] **Step 5: `flutter analyze`가 깨끗한지 확인합니다**

```bash
flutter analyze
```

Expected: `No issues found!` (`_memoController`를 지웠으니 관련
import·필드가 안 남아있는지도 이 단계에서 같이 걸러집니다)

- [ ] **Step 6: 커밋**

```bash
git add lib/screens/reference_detail_screen.dart test/screens/reference_detail_screen_test.dart
git commit -m "레퍼런스 편집 화면의 메모 칸을 리치텍스트 편집기로 바꾼다"
```

---

### Task 6: 목록 카드 미리보기에서 서식 없이 글자만 보이게

**Files:**
- Modify: `lib/widgets/reference_card.dart`

**Interfaces:**
- Consumes: `plainTextFromMemo`(Task 2)
- Produces: 없음(화면 조립의 끝단)

- [ ] **Step 1: 실패하는지부터 확인하기 위해, 먼저 기존 테스트를 돌려봅니다**

```bash
flutter test test/screens/home_card_content_test.dart
```

Expected: 이 시점에는 아직 `reference_card.dart`를 안 고쳤으므로 PASS
그대로입니다(리치텍스트가 아직 화면에 안 붙었으니까요). **이 스텝은
"지금은 통과한다"를 확인해두는 것입니다** — Step 3 이후에도 계속
통과해야 회귀가 없는 것입니다.

- [ ] **Step 2: `reference_card.dart`를 고칩니다**

`lib/widgets/reference_card.dart`의 import 목록에 추가(17번째 줄
`import '../utils/date_format.dart';` 다음 줄):

```dart
import '../utils/rich_text_memo.dart';
```

메모 미리보기 블록(212~222번째 줄 부근):

```dart
          if (item.memo != null && item.memo!.trim().isNotEmpty)
            _bodyGap(
              Text(
                item.memo!.trim(),
                // 메모가 길어도 카드가 한없이 길어지지 않게 세 줄로 자릅니다.
                // 전체는 편집 화면에서 봅니다.
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.cardMemo.copyWith(color: palette.textDim),
              ),
            ),
```

을 이렇게 바꿉니다:

```dart
          if (plainTextFromMemo(item.memo).isNotEmpty)
            _bodyGap(
              Text(
                // 메모는 이제 서식이 붙은 Delta(JSON)일 수 있습니다.
                // 카드 미리보기는 글자만 보여주면 되므로 서식을 뺀
                // plainTextFromMemo를 거칩니다(utils/rich_text_memo.dart).
                plainTextFromMemo(item.memo),
                // 메모가 길어도 카드가 한없이 길어지지 않게 세 줄로 자릅니다.
                // 전체는 편집 화면에서 봅니다.
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.cardMemo.copyWith(color: palette.textDim),
              ),
            ),
```

- [ ] **Step 3: 테스트가 여전히 통과하는지 확인합니다**

```bash
flutter test test/screens/home_card_content_test.dart
```

Expected: PASS 그대로 (`plainTextFromMemo`가 마이그레이션 전 순수
텍스트도 그대로 돌려주도록 만들어뒀기 때문입니다 — Task 2 참고)

- [ ] **Step 4: 새로운 순수 텍스트 메모 표시 테스트를 추가합니다**

`test/screens/home_card_content_test.dart`의 `'메모가 카드에 보인다'`
테스트(147~153번째 줄) 바로 뒤에 하나를 더 씁니다:

```dart
  testWidgets('서식이 붙은 메모도 글자만 카드에 보인다', (WidgetTester tester) async {
    // Delta(JSON) — "색감이" 는 굵게, " 마음에 든다"는 그냥 글자입니다.
    const String delta =
        '[{"insert":"색감이","attributes":{"bold":true}},'
        '{"insert":" 마음에 든다\\n"}]';

    await saveReference(memo: delta);

    await openApp(tester);

    // 서식 정보(JSON 문법)는 안 보이고 글자만 보여야 합니다.
    expect(find.text('색감이 마음에 든다'), findsOneWidget);
    expect(find.textContaining('"insert"'), findsNothing);
  });
```

- [ ] **Step 5: 테스트가 통과하는지 확인합니다**

```bash
flutter test test/screens/home_card_content_test.dart
```

Expected: 이 파일의 모든 테스트 PASS

- [ ] **Step 6: `flutter analyze`가 깨끗한지 확인합니다**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 7: 커밋**

```bash
git add lib/widgets/reference_card.dart test/screens/home_card_content_test.dart
git commit -m "목록 카드 미리보기에서 메모 서식을 빼고 글자만 보여준다"
```

---

### Task 7: 전체 검증 + 문서화 + PR

**Files:**
- Modify: `CLAUDE.md`
- Modify: `update.md`
- (신규/수정 파일 없음 — 검증과 기록만 하는 태스크입니다)

**Interfaces:**
- Consumes: Task 1~6의 모든 결과물
- Produces: 없음(마무리 태스크)

- [ ] **Step 1: 전체 테스트를 돌립니다**

```bash
flutter test
```

Expected: 전부 PASS (기존 개수 + 이번에 추가한 테스트: rich_text_memo
11개, migration_v3_to_v4 5개, rich_memo_editor 3개,
home_card_content_test +1개 = 총 20개 안팎 증가)

- [ ] **Step 2: 정적 분석을 돌립니다**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Windows 빌드를 확인합니다**

```bash
flutter build windows
```

Expected: 빌드 성공 (`Built build\windows\x64\runner\Release\reference_archive_app.exe`)

- [ ] **Step 4: 빌드된 앱을 실제로 켜서 눈으로 확인합니다**

레퍼런스 하나를 열어 메모 칸에서 다음을 직접 눌러봅니다.
- 굵게·기울임·밑줄이 실제로 적용되는지
- 글자색·형광펜(배경색) 선택기가 뜨고 실제로 색이 바뀌는지
- 순서 있는/없는 목록이 만들어지는지
- 링크를 넣을 수 있는지
- 정렬(왼쪽/가운데/오른쪽)이 되는지
- 저장 후 다시 열었을 때 서식이 그대로 남아있는지
- 목록 화면 카드 미리보기에는 서식 없이 글자만 보이는지

문제가 있으면 여기서 고치고 Step 1부터 다시 확인합니다.

- [ ] **Step 5: `CLAUDE.md`를 갱신합니다**

"개발 단계" 표의 5단계 줄(`- **5단계 — 메모(스티키노트)** ← 현재 여기`)을
찾아 완료 표시로 바꿉니다. 5단계 항목이 아직 여러 하위 기능(리치텍스트
외에 링크·목록·정렬 등은 이번에 이미 포함됨)을 하나로 뭉쳐 적어뒀다면,
이번 PR로 5단계의 요구사항(리치텍스트, 글자색/형광펜/배경색, 서식, 링크,
목록, 정렬)이 전부 구현됐는지 spec 문서와 대조해 확인한 뒤 완료 표시합니다.

새 설명 블록을 추가합니다(다른 완료된 단계들과 같은 형식 —
"이렇게 되어 있습니다" 스타일):

```markdown
**5단계(메모)는 이렇게 되어 있습니다:**
- **`flutter_quill` 패키지**로 편집기를 만들었습니다. 저장 형식은
  Delta(JSON) 문자열이고, `memo` 칼럼 타입은 그대로 TEXT입니다 —
  안에 들어가는 내용의 뜻만 바뀌었습니다.
- **저장 구조 v4**로 기존 순수 텍스트 메모를 최소 Delta로 감쌌습니다
  (`lib/data/app_database.dart`의 `_upgradeToVersion4`).
- **Delta ↔ 순수 텍스트 변환은 `lib/utils/rich_text_memo.dart`**에
  순수 함수로 모여 있습니다. 편집기(`RichMemoEditor`)와 목록 카드
  미리보기(`reference_card.dart`) 둘 다 이 파일을 씁니다.
- **검색은 손대지 않았습니다.** Delta JSON 안에도 실제 글자가 그대로
  부분 문자열로 남아있어서 대체로 계속 찾아집니다. 문제가 실제로
  나타나면 그때 고칩니다.
- **무드보드용 가벼운 주석은 이번에 포함하지 않았습니다.** 별도로
  브레인스토밍합니다("무드보드 추가 제안" 표 참고).
```

- [ ] **Step 6: `update.md`에 PR 항목을 추가합니다**

가장 최근 PR 항목 뒤에 `---` 구분선과 함께 새 항목을 추가합니다. 무엇을
왜 어떻게 고쳤는지(위 Task 1~6 요약), 마이그레이션 다섯 가지를 어떻게
확인했는지, 검색을 안 건드린 이유, 알고 있는 한계(무드보드 주석 미포함,
다른 플랫폼 저장 대화상자 미검증 같은 유사 사례를 참고해 이번 PR에 맞게)를
`update.md`의 기존 항목들과 같은 문체·형식으로 적습니다.

- [ ] **Step 7: 커밋 + push**

```bash
git add CLAUDE.md update.md
git commit -m "PR 이력 기록: 레퍼런스 메모 리치텍스트 (5단계)"
git push -u origin <브랜치 이름>
```

(브랜치는 Task 1을 시작하기 전에 `main`에서 미리 만들어뒀어야 합니다 —
`git checkout -b memo-rich-text` 같은 이름. 이 계획 문서에는 브랜치 생성
스텝을 별도로 안 넣었으니, 실행자는 Task 1의 Step 1보다 먼저 브랜치를
만드세요.)

- [ ] **Step 8: PR을 엽니다**

```bash
gh pr create --title "레퍼런스 메모 리치텍스트 (5단계)" --body "..."
```

PR 본문에는 Summary(무엇을 왜), 나중에 고치려면 어디를 보면 되는지
(`rich_text_memo.dart`, `RichMemoEditor`, `_upgradeToVersion4`), Test
plan(analyze/test/build 결과, 의뢰인 확인 여부), 새로 나온 개념(Delta)을
CLAUDE.md 프로젝트 관례대로 적습니다.

**의뢰인의 명시적 "병합해줘" 전까지 병합하지 않고 대기합니다.**

---

## 계획 자체 점검 (self-review)

- **스펙 커버리지**: 스펙의 5개 결정 사항(패키지 선택 → Task 1, 저장
  형식/마이그레이션 → Task 3, 검색 안 건드림 → Task 7 문서화로 명시,
  편집 화면 → Task 5, 미리보기 → Task 6) 전부 태스크가 있습니다. 테스트
  전략 섹션도 각 태스크의 Step들이 그대로 구현합니다.
- **플레이스홀더 스캔**: "TBD", "나중에", "적절히 처리" 같은 문구 없음.
  모든 코드 스텝에 실제 코드가 있습니다.
- **타입 일관성**: `documentFromMemo`/`memoFromDocument`/
  `plainTextFromMemo`(Task 2) → `RichMemoEditor`(Task 4)의
  `initialMemo`/`onChanged` → `reference_detail_screen.dart`(Task 5)의
  `_memoJson` 흐름이 전부 `String?` 하나로 일관됩니다. `RichMemoEditor`
  생성자 이름과 콜백 시그니처가 Task 4와 Task 5에서 동일합니다.
