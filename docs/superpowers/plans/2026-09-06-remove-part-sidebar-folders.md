# 파트 제거 + 사이드바 폴더화 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `TaxonomyKind.part`(파트) 개념을 앱에서 완전히 제거하고, 왼쪽 사이드바의
파트 목록 자리를 폴더(`TaxonomyKind.folder`) 목록으로 교체한다.

**Architecture:** `References.folderId` 칼럼이 기존 "폴더 소속" 역할과 파트의
옛 역할("사이드바에서 지금 보고 있는 자리")을 둘 다 맡는다. `partId` 관련 코드는
모델 → 저장소 → 화면 순서로 위에서 아래로 제거하고, 마지막에 저장 구조
(schemaVersion 5 → 6, `partId` 칼럼 drop + `kind='part'` 행 삭제)를 정리한다.

**Tech Stack:** Flutter/Dart, drift 2.34.3(SQLite, `sqlite3_flutter_libs`)

**Spec:** `docs/superpowers/specs/2026-09-06-remove-part-sidebar-folders-design.md`

## Global Constraints

- 파일 상단에 그 파일이 무슨 역할인지 한국어 주석. 함수 위에 한 줄 한국어 주석
  (CLAUDE.md "작업자에게").
- 모든 커밋 메시지는 상세하게 쓰고 끝에 `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`를 붙인다.
- `lib/data/app_database.g.dart`는 손으로 고치지 않는다 — `tables.dart`를 고친 뒤
  `dart run build_runner build`로 다시 생성한다.
- **이 플랜은 하나의 개념(파트)을 코드베이스 전체에서 지우는 원자적 리팩터다.**
  Task 1~11이 전부 끝나기 전까지는 `flutter analyze`가 빨간 줄 없이 통과하지
  않을 수 있다 — 예를 들어 Task 4(모델에서 `partId` 제거)가 끝난 시점에는
  아직 안 고친 저장소·화면 파일들이 존재하지 않는 필드를 참조해서 컴파일
  오류가 난다. **이건 정상이다.** 각 Task는 "이 Task가 맡은 파일들이 서로
  앞뒤가 맞는지"만 확인하고, `flutter analyze`/`flutter test` 전체가 깨끗해지는
  것은 Task 11(테스트 정리) 종료 시점이다. Task 12에서 전체를 한 번에 검증한다.
- **마이그레이션 조건은 CLAUDE.md 규칙대로 반드시 부등호로 쓰고, "여러 버전
  건너뛰기" 테스트를 반드시 포함한다.**
- 새 파일을 만들 때도 파일 상단 설명 주석을 답니다.

---

## 사전 확인: 왜 이렇게 넓게 퍼져 있는지

스펙 문서 작성 중 코드를 직접 읽어 확인한 사실 — `partId`는 다음 25개 파일에
등장한다 (검색: `grep -rl "partId\|TaxonomyKind\.part\|defaultPartId\|defaultPartName"`).

**앱 코드 (13개)**: `enums.dart`, `taxonomy_item.dart`, `reference_item.dart`,
`reference_query.dart`, `local_reference_repository.dart`,
`local_taxonomy_repository.dart`, `reference_importer.dart`,
`reference_taxonomy_edit_controller.dart`, `reference_detail_taxonomy_fields.dart`,
`reference_detail_screen.dart`, `reference_filter_bar.dart`, `home_screen.dart`,
`board_screen.dart`, `taxonomy_manage_screen.dart`, `app_database.dart`,
`tables.dart`, `app_database.g.dart`(생성 파일, 손대지 않음).

**테스트 코드 (12개)**: `migration_v1_to_v2_test.dart`,
`migration_v2_to_v3_test.dart`, `migration_v3_to_v4_test.dart`,
`migration_v4_to_v5_test.dart`, `reference_importer_saved_ids_test.dart`,
`reference_importer_hash_test.dart`, `taxonomy_manage_screen_test.dart`,
`part_delete_test.dart`, `home_parts_test.dart`,
`local_taxonomy_repository_test.dart`(주석만), `app_shell_test.dart`(주석만),
`reference_detail_screen_test.dart`(주석만).

**특히 중요한 함정**: 마이그레이션 테스트 4개(`migration_v1_to_v2_test.dart`
등)는 전부 `AppDatabase.forTesting()`으로 데이터베이스를 여는데, 이건
**지금 앱의 `schemaVersion`(곧 6)까지 전부 마이그레이션을 실행한 뒤의
모습**을 돌려준다. 즉 "v2가 파트를 만든다"는 역사적 사실을 확인하려던
기존 테스트들이, v6이 그 파트를 도로 지워버리는 지금 상황에서는 전부
깨진다(`item.partId`/`TaxonomyKind.part`/`defaultPartId`가 컴파일조차
안 될 것이다). Task 11에서 이 4개 파일을 전부 손본다.

---

### Task 1: 모델에서 파트 제거

**Files:**
- Modify: `lib/models/enums.dart:59-64` (TaxonomyKind.part 값 삭제)
- Modify: `lib/models/taxonomy_item.dart:45-67` (defaultPartId/defaultPartName 삭제)
- Modify: `lib/models/reference_item.dart` (partId 필드·copyWith 인자 삭제)
- Modify: `lib/models/reference_query.dart` (partId 필드 삭제, folderId가
  "자리" 역할을 겸하도록 hasAnyFilter/clearFilter/clearAll 수정)

**Interfaces:**
- Consumes: 없음 (이 플랜의 첫 Task)
- Produces: `ReferenceItem`에 더 이상 `partId`가 없음. `ReferenceQuery`에 더
  이상 `partId`가 없고, `folderId`가 `hasAnyFilter`에서 빠지고
  `clearAll()`에서 보존된다(뒤 Task들이 이 계약에 의존한다).

- [ ] **Step 1: `enums.dart`에서 `TaxonomyKind.part` 삭제**

`lib/models/enums.dart`의 59~64번 줄(파트 값 전체, 콤마 포함)을 지우고,
바로 앞 `project(...)` 항목 끝에 콤마 대신 세미콜론이 오도록 고칩니다.

```dart
enum TaxonomyKind {
  /// 폴더 — 레퍼런스 하나가 폴더 하나에만 들어갑니다.
  folder('folder', '폴더'),

  /// 카테고리 — 레퍼런스 하나가 카테고리 하나에만 들어갑니다.
  category('category', '카테고리'),

  /// 태그 — 레퍼런스 하나에 여러 개를 붙일 수 있습니다.
  tag('tag', '태그'),

  /// 프로젝트 — 레퍼런스 하나가 여러 프로젝트에 속할 수 있습니다.
  project('project', '프로젝트');

  const TaxonomyKind(this.storedName, this.displayName);
  ...
```

**Step 2: `taxonomy_item.dart`에서 기본 파트 상수 삭제**

`lib/models/taxonomy_item.dart`의 45~67번 줄(`/// 기본 파트의 고유 번호입니다.`
주석부터 `const String defaultPartName = '기본';`까지 전부)을 지웁니다.
파일은 `TaxonomyItem` 클래스만 남습니다.

**Step 3: `reference_item.dart`에서 partId 제거**

`lib/models/reference_item.dart`를 다음과 같이 고칩니다 — 생성자의
`this.partId,` 삭제, `final String? partId;` 필드 삭제(주석 포함),
`copyWith`의 `String? partId,` 매개변수와 `partId: partId ?? this.partId,`
삭제, `clearFolder()`/`clearCategory()` 안의 `partId: partId,` 삭제.

```dart
class ReferenceItem {
  ReferenceItem({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.title = '',
    this.fileName,
    this.youtubeVideoId,
    this.memo,
    this.folderId,
    this.categoryId,
    this.isPinned = false,
    this.isFavorite = false,
    this.pHash,
    this.tagIds = const <String>[],
    this.projectIds = const <String>[],
  });

  final String id;
  final ReferenceType type;
  final String title;
  final String? fileName;
  final String? youtubeVideoId;
  final String? memo;

  /// 들어있는 폴더의 id (없으면 null)
  final String? folderId;

  /// 들어있는 카테고리의 id (없으면 null)
  final String? categoryId;

  final bool isPinned;
  final bool isFavorite;
  final String? pHash;
  final List<String> tagIds;
  final List<String> projectIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReferenceItem copyWith({
    String? title,
    ReferenceType? type,
    String? fileName,
    String? youtubeVideoId,
    String? memo,
    String? folderId,
    String? categoryId,
    bool? isPinned,
    bool? isFavorite,
    String? pHash,
    List<String>? tagIds,
    List<String>? projectIds,
    DateTime? updatedAt,
  }) {
    return ReferenceItem(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      memo: memo ?? this.memo,
      folderId: folderId ?? this.folderId,
      categoryId: categoryId ?? this.categoryId,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      pHash: pHash ?? this.pHash,
      tagIds: tagIds ?? this.tagIds,
      projectIds: projectIds ?? this.projectIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  ReferenceItem clearFolder() {
    return ReferenceItem(
      id: id,
      type: type,
      title: title,
      fileName: fileName,
      youtubeVideoId: youtubeVideoId,
      memo: memo,
      folderId: null,
      categoryId: categoryId,
      isPinned: isPinned,
      isFavorite: isFavorite,
      pHash: pHash,
      tagIds: tagIds,
      projectIds: projectIds,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  ReferenceItem clearCategory() {
    return ReferenceItem(
      id: id,
      type: type,
      title: title,
      fileName: fileName,
      youtubeVideoId: youtubeVideoId,
      memo: memo,
      folderId: folderId,
      categoryId: null,
      isPinned: isPinned,
      isFavorite: isFavorite,
      pHash: pHash,
      tagIds: tagIds,
      projectIds: projectIds,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
```

**Step 4: `reference_query.dart`에서 partId 제거, folderId가 "자리" 역할을 겸하게**

`lib/models/reference_query.dart` 전체를 아래로 바꿔씁니다. 핵심 변화:
`partId` 필드 삭제, `folderId`의 문서 주석 갱신, `hasAnyFilter`에서
`folderId != null` 삭제(더 이상 세지 않음), `clearFilter`에서 `partId` 줄
삭제, `clearAll()`이 `folderId`를 보존하도록 변경.

```dart
// "어떤 레퍼런스를 어떤 순서로 가져올지"를 담는 클래스입니다.
//
// ── 왜 인자를 따로 넘기지 않고 이렇게 묶었나 ──
// getAll(검색어, 폴더, 태그, 즐겨찾기만, 정렬방식, ...) 처럼 인자를 늘어놓으면
// 조건이 하나 늘 때마다 저장소의 함수 모양이 바뀌고, 그 함수를 쓰는 곳을
// 전부 찾아 고쳐야 합니다.
//
// 이렇게 클래스로 묶어두면 조건이 늘어도 이 파일에 값 하나만 추가하면 되고,
// 기존 코드는 그대로 돌아갑니다. (기본값이 있으니까요)

import 'enums.dart';

/// 목록을 어떤 순서로 보여줄지 정합니다.
enum ReferenceSortOrder {
  /// 최근에 고친 것부터
  recentlyUpdated('최근 수정순'),

  /// 최근에 추가한 것부터
  recentlyAdded('최근 추가순'),

  /// 예전에 추가한 것부터
  oldestAdded('오래된 순'),

  /// 제목 가나다순
  titleAscending('제목순'),

  /// 가장 최근에 추가한 항목을 기준으로, 비슷한 것끼리 모아서
  /// (utils/similarity.dart의 sortBySimilarity 참고)
  similar('유사한 것끼리');

  const ReferenceSortOrder(this.displayName);

  /// 화면에 보여줄 한국어 이름
  final String displayName;
}

/// 목록을 가져올 때 쓸 조건들입니다.
///
/// 아무것도 넘기지 않으면 "전부, 최근 수정순"이 됩니다.
class ReferenceQuery {
  const ReferenceQuery({
    this.searchText = '',
    this.folderId,
    this.categoryId,
    this.tagId,
    this.projectId,
    this.favoritesOnly = false,
    this.sortOrder = ReferenceSortOrder.recentlyUpdated,
  });

  /// 검색어입니다. 제목과 메모에서 찾습니다.
  ///
  /// 비어 있으면 검색하지 않고 전부 가져옵니다.
  final String searchText;

  /// 이 폴더에 든 것만 가져옵니다. null이면 "전체 레퍼런스"입니다.
  ///
  /// **다른 필터와 성격이 다릅니다.** 카테고리·태그·프로젝트는 목록 위에서
  /// 잠깐 걸었다 푸는 **조건**이지만, 폴더는 왼쪽 사이드바에서 고르는
  /// **지금 보고 있는 자리**에 가깝습니다(예전에는 이 역할을 파트가
  /// 따로 맡고 있었는데, 파트를 없애면서 폴더가 그 역할까지 겸하게
  /// 됐습니다). 그래서 아래 hasAnyFilter와 clearAll에서 다르게 다룹니다.
  final String? folderId;

  /// 이 카테고리에 든 것만 가져옵니다. null이면 거르지 않습니다.
  final String? categoryId;

  /// 이 태그가 붙은 것만 가져옵니다. null이면 거르지 않습니다.
  final String? tagId;

  /// 이 프로젝트에 속한 것만 가져옵니다. null이면 거르지 않습니다.
  final String? projectId;

  /// 켜면 즐겨찾기한 것만 가져옵니다.
  final bool favoritesOnly;

  /// 어떤 순서로 정렬할지
  final ReferenceSortOrder sortOrder;

  /// 조건이 하나라도 걸려 있는지 알려줍니다.
  ///
  /// 화면에서 "조건에 맞는 게 없습니다"와 "아직 아무것도 없습니다"를
  /// 구분해서 안내하려고 씁니다. 아무것도 없는데 "조건에 맞는 게 없다"고 하면
  /// 사용자가 조건을 지우려고 헤매게 됩니다.
  ///
  /// **폴더는 여기 안 셉니다.** 폴더는 "거르는 조건"이라기보다 "지금 보고 있는
  /// 자리"입니다. 빈 폴더를 열었을 때는 "조건에 맞는 게 없다"가 아니라
  /// "아직 아무것도 없다"가 맞는 안내입니다. (조건을 지워봐야 소용없으니까요)
  bool get hasAnyFilter {
    return searchText.trim().isNotEmpty ||
        categoryId != null ||
        tagId != null ||
        projectId != null ||
        favoritesOnly;
  }

  /// 몇 가지만 바꾼 사본을 만들어 돌려줍니다.
  ///
  /// 주의: 이 함수로는 필터를 **끌 수 없습니다.** null을 넘긴 것과 안 넘긴 것을
  /// 구분할 수 없기 때문입니다. 필터를 끄려면 clearFilter()를 쓰세요.
  /// (같은 이유와 해법이 lib/models/reference_item.dart에도 적혀 있습니다)
  ReferenceQuery copyWith({
    String? searchText,
    String? folderId,
    String? categoryId,
    String? tagId,
    String? projectId,
    bool? favoritesOnly,
    ReferenceSortOrder? sortOrder,
  }) {
    return ReferenceQuery(
      searchText: searchText ?? this.searchText,
      folderId: folderId ?? this.folderId,
      categoryId: categoryId ?? this.categoryId,
      tagId: tagId ?? this.tagId,
      projectId: projectId ?? this.projectId,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// 특정 종류의 필터를 끈 사본을 돌려줍니다.
  ///
  /// 예: clearFilter(TaxonomyKind.category) → 카테고리 필터만 해제
  ReferenceQuery clearFilter(TaxonomyKind kind) {
    return ReferenceQuery(
      searchText: searchText,
      folderId: kind == TaxonomyKind.folder ? null : folderId,
      categoryId: kind == TaxonomyKind.category ? null : categoryId,
      tagId: kind == TaxonomyKind.tag ? null : tagId,
      projectId: kind == TaxonomyKind.project ? null : projectId,
      favoritesOnly: favoritesOnly,
      sortOrder: sortOrder,
    );
  }

  /// 모든 필터와 검색어를 지운 사본을 돌려줍니다.
  ///
  /// **정렬 방식과 폴더는 그대로 둡니다.**
  ///
  /// 폴더를 안 지우는 이유: 폴더는 사이드바에서 고른 "지금 보고 있는 자리"입니다.
  /// "조건 지우기"를 눌렀는데 보고 있던 폴더에서 튕겨 나가면 당황스럽습니다.
  /// 폴더를 바꾸려면 사이드바에서 다른 폴더를 고르면 됩니다.
  ReferenceQuery clearAll() {
    return ReferenceQuery(sortOrder: sortOrder, folderId: folderId);
  }
}
```

- [ ] **Step 5: `flutter analyze lib/models`로 이 네 파일 자체는 앞뒤가 맞는지 확인**

Run: `flutter analyze lib/models`
Expected: `lib/models` 안에서는 새 오류가 없어야 합니다(다른 폴더 파일들이
아직 옛 필드를 참조해서 나는 오류는 이 시점에 나오는 게 정상입니다 — 위
Global Constraints 참고).

- [ ] **Step 6: 커밋**

```bash
git add lib/models/enums.dart lib/models/taxonomy_item.dart lib/models/reference_item.dart lib/models/reference_query.dart
git commit -m "모델에서 파트(Part) 개념을 지운다

ReferenceQuery.folderId가 예전에 파트가 하던 '사이드바에서 지금 보고
있는 자리' 역할까지 겸하게 됩니다.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: 저장소에서 파트 제거

**Files:**
- Modify: `lib/repositories/local_reference_repository.dart`
- Modify: `lib/repositories/local_taxonomy_repository.dart`

**Interfaces:**
- Consumes: Task 1의 `ReferenceItem`(partId 없음), `ReferenceQuery`(partId 없음)
- Produces: `LocalReferenceRepository.search()`가 더 이상 `partId`로 거르지
  않음. `LocalTaxonomyRepository.delete()`에 더 이상 기본 파트 보호·재배정
  로직이 없음(뒤 Task들이 "폴더를 지우면 그냥 null이 된다"는 계약에 의존).

- [ ] **Step 1: `local_reference_repository.dart`에서 파트 필터·매핑 삭제**

`search()`의 66~83번 줄을 아래로 바꿉니다(파트 필터 블록 전체 삭제,
폴더·카테고리 필터는 그대로).

```dart
    // ── 폴더 / 카테고리 필터 ──
    final String? folderId = query.folderId;
    if (folderId != null) {
      statement.where(($ReferencesTable t) => t.folderId.equals(folderId));
    }

    final String? categoryId = query.categoryId;
    if (categoryId != null) {
      statement.where(($ReferencesTable t) => t.categoryId.equals(categoryId));
    }

    // ── 즐겨찾기 필터 ──
    if (query.favoritesOnly) {
      statement.where(($ReferencesTable t) => t.isFavorite.equals(true));
    }
```

`save()`(223~240번 줄)에서 `partId: Value<String?>(item.partId),` 줄을
지웁니다. `_toModel()`(562~584번 줄)에서 `partId: row.partId,` 줄을 지웁니다.

- [ ] **Step 2: `local_taxonomy_repository.dart`의 `delete()`에서 파트 특수
  처리·기본 파트 보호 삭제**

`delete()` 전체를 아래로 바꿔씁니다 — 맨 위 "기본 파트만은 지울 수
없습니다" 블록(79~81번 줄)과, transaction 안의 "파트만 다르게 다룹니다"
블록(115~129번 줄)을 지웁니다.

```dart
  /// 항목을 지웁니다(소프트 삭제). 이 항목을 쓰던 레퍼런스도 함께 정리합니다.
  @override
  Future<void> delete(String id) async {
    final DateTime now = DateTime.now().toUtc();

    // 항목 본체와 그 항목을 쓰던 곳들을 함께 정리합니다.
    // 중간에 실패해서 "이미 지운 폴더에 들어있는 레퍼런스"가 남으면 그 레퍼런스가
    // 폴더 목록 어디에도 안 보이게 되므로, transaction으로 묶습니다.
    await _db.transaction(() async {
      await (_db.update(_db.taxonomyItems)..where(($TaxonomyItemsTable t) => t.id.equals(id)))
          .write(TaxonomyItemsCompanion(
        deletedAt: Value<DateTime?>(now),
        updatedAt: Value<DateTime>(now),
      ));

      // 태그·프로젝트로 쓰이던 연결을 끊습니다.
      await (_db.update(_db.referenceTaxonomyLinks)
            ..where(($ReferenceTaxonomyLinksTable t) =>
                t.taxonomyItemId.equals(id) & t.deletedAt.isNull()))
          .write(ReferenceTaxonomyLinksCompanion(deletedAt: Value<DateTime?>(now)));

      // 폴더로 쓰이던 레퍼런스는 폴더 없음 상태로 되돌립니다.
      await (_db.update(_db.references)..where(($ReferencesTable t) => t.folderId.equals(id)))
          .write(ReferencesCompanion(
        folderId: const Value<String?>(null),
        updatedAt: Value<DateTime>(now),
      ));

      // 카테고리로 쓰이던 레퍼런스도 마찬가지입니다.
      await (_db.update(_db.references)..where(($ReferencesTable t) => t.categoryId.equals(id)))
          .write(ReferencesCompanion(
        categoryId: const Value<String?>(null),
        updatedAt: Value<DateTime>(now),
      ));
    });
  }
```

**주의**: 이 함수 위에 있던 "기본 파트는 지울 수 없습니다" 관련 doc 주석
(65~78번 줄)도 함께 지우고, 아래처럼 짧게 바꿉니다.

```dart
  /// 항목을 지웁니다(소프트 삭제). 이 항목을 쓰던 레퍼런스도 함께 정리합니다.
```

- [ ] **Step 3: 커밋**

```bash
git add lib/repositories/local_reference_repository.dart lib/repositories/local_taxonomy_repository.dart
git commit -m "저장소에서 파트 필터링과 기본 파트 보호 로직을 지운다

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: ReferenceImporter의 partId를 folderId로

**Files:**
- Modify: `lib/services/reference_importer.dart`

**Interfaces:**
- Consumes: Task 1의 `ReferenceItem`(folderId만 있음, partId 없음)
- Produces: `ReferenceImporter`의 모든 공개 메서드가 `required String partId`
  대신 `String? folderId`(선택적)를 받는다 — 이후 Task들(4, 5)의 호출부가
  이 시그니처에 맞춘다.
  - `importFromFilePicker({String? folderId})`
  - `importFromDrop(PerformDropEvent event, {String? folderId})`
  - `importFromClipboard({String? folderId})`
  - `importYoutube(String videoId, {String? folderId})`
  - `saveYoutube(String videoId, {String? folderId})`

- [ ] **Step 1: 전체 치환**

`lib/services/reference_importer.dart` 안에서 `required String partId`를
전부 `String? folderId`로, `partId: partId`(호출)를 `folderId: folderId`로,
`partId,`(위치 인자로 넘기던 `_saveOneFile`/`_saveImageBytes`의 두 번째
인자 이름)를 `folderId,`로, `ReferenceItem(...)`을 만들 때 쓰던
`partId: partId,`를 `folderId: folderId,`로 바꿉니다. 아래는 그 결과
전체입니다(주석은 원본 그대로 두되 "파트"라고 적힌 단어만 "폴더"로
바꿨습니다).

```dart
// 레퍼런스를 앱에 들여오는 일을 모아둔 파일입니다.
//
// 들어오는 길이 넷입니다. **어느 길로 들어오든 저장하는 방식은 하나**여야
// 똑같이 리사이즈되고 똑같이 기록됩니다.
//
//   1. 파일 고르기 창
//   2. 창에 끌어다 놓기
//   3. 붙여넣기 (Ctrl+V)
//   4. 유튜브 주소
//
// ── 왜 화면에서 떼어냈나 ──
// 원래 이 내용은 home_screen.dart 안에 있었습니다. 그런데 화면 파일이 1400줄이
// 넘어가면서 "목록 화면 코드"를 찾기가 어려워졌습니다. 여기 있는 것들은
// **화면과 아무 상관이 없습니다** — 어디에 어떻게 그릴지 모르고, 그냥 들여와
// 저장하고 결과만 알려줍니다.
//
// 화면은 결과를 받아 안내를 띄우고 목록을 새로 고치는 일만 합니다.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../models/enums.dart';
import '../models/reference_item.dart';
import '../repositories/reference_repository.dart';
import '../utils/id_generator.dart';
import 'dropped_item_reader.dart';
import 'image_hash.dart';
import 'image_source.dart';
import 'image_storage.dart';
import 'youtube_info_source.dart';
import 'youtube_url.dart';

/// 들여오기를 한 번 하고 난 결과입니다.
///
/// 화면은 이걸 받아서 안내 문구를 띄웁니다. 몇 개 성공했고 몇 개 실패했는지,
/// 실패했다면 무엇이 문제였는지가 들어 있습니다.
class ImportOutcome {
  const ImportOutcome({
    this.savedCount = 0,
    this.failedCount = 0,
    this.errorMessage,
    this.successMessage,
    this.savedIds = const <String>[],
  });

  /// 아무것도 하지 않고 끝난 경우입니다. (사용자가 파일 고르기를 취소한 경우 등)
  const ImportOutcome.nothingToDo()
    : savedCount = 0,
      failedCount = 0,
      errorMessage = null,
      successMessage = null,
      savedIds = const <String>[];

  /// 저장에 성공한 개수입니다.
  final int savedCount;

  /// 실패한 개수입니다.
  final int failedCount;

  /// 실패한 이유입니다. 성공했으면 null입니다.
  ///
  /// 이 글자는 그대로 사용자에게 보여줍니다. 그래서 "그 사이트가 막고 있습니다"처럼
  /// 다음에 뭘 하면 되는지 알 수 있는 문장이 들어갑니다.
  final String? errorMessage;

  /// 성공했을 때 보여줄 문구입니다. 없으면 화면이 "N장 추가했습니다"로 만듭니다.
  ///
  /// 유튜브는 "1장 추가했습니다"가 어색해서 따로 문구를 넘깁니다.
  final String? successMessage;

  /// 이번에 새로 만들어진 레퍼런스들의 번호입니다.
  ///
  /// ── 왜 필요한가 (무드보드에 바로 놓기) ──
  /// 목록 화면은 "몇 개 저장됐는지"만 알면 되지만, 무드보드 화면은 방금
  /// 만들어진 레퍼런스를 **놓은 자리에 카드로 배치**해야 해서 번호까지
  /// 알아야 합니다. 실패한 항목의 번호는 안 들어있습니다.
  final List<String> savedIds;

  /// 사용자에게 알릴 것이 아무것도 없는 경우인지 여부입니다.
  bool get isNothingToDo => savedCount == 0 && failedCount == 0;
}

/// 레퍼런스를 들여와 저장하는 도구입니다.
class ReferenceImporter {
  ReferenceImporter({
    required this.repository,
    required this.imageStorage,
    required this.imageSource,
    required this.youtubeInfoSource,
  });

  /// 레퍼런스를 저장하는 통로입니다.
  final ReferenceRepository repository;

  /// 이미지 파일을 저장하는 도구입니다.
  final ImageStorage imageStorage;

  /// 주소나 클립보드에서 이미지를 가져오는 도구입니다.
  final ImageSource imageSource;

  /// 유튜브에서 제목과 썸네일을 가져오는 도구입니다.
  final YoutubeInfoSource youtubeInfoSource;

  /// 끌어다 놓은 것을 읽어주는 도구입니다.
  late final DroppedItemReader _droppedItemReader = DroppedItemReader(
    imageSource,
  );

  /// 파일 고르기 창을 띄워 이미지를 들여옵니다.
  ///
  /// [folderId]는 새 레퍼런스가 들어갈 폴더입니다. null이면 폴더 없음
  /// (미분류)으로 들어갑니다 — 파트와 달리 폴더는 없어도 정상 상태입니다.
  Future<ImportOutcome> importFromFilePicker({String? folderId}) async {
    // 여러 장을 한 번에 고를 수 있습니다. 사용자가 취소하면 null이 돌아옵니다.
    //
    // withData: true를 주면 파일 내용을 메모리에 함께 담아줍니다.
    // 안드로이드에서는 다른 앱이 넘겨준 파일에 실제 경로가 없을 수 있어서,
    // 경로 대신 내용을 직접 받는 편이 안전합니다.
    final FilePickerResult? picked = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
      dialogTitle: '레퍼런스로 추가할 이미지 고르기',
    );

    if (picked == null || picked.files.isEmpty) {
      return const ImportOutcome.nothingToDo();
    }

    int failedCount = 0;
    final List<String> savedIds = <String>[];

    for (final PlatformFile file in picked.files) {
      final String? savedId = await _saveOneFile(file, folderId);
      if (savedId != null) {
        savedIds.add(savedId);
      } else {
        failedCount++;
      }
    }

    return ImportOutcome(
      savedCount: savedIds.length,
      failedCount: failedCount,
      savedIds: savedIds,
    );
  }

  /// 창에 끌어다 놓은 것들을 들여옵니다.
  ///
  /// ── 브라우저에서 끌면 무엇이 오는가 ──
  /// 상황마다 다릅니다. 무엇이 오는지 가려내는 일은 DroppedItemReader가 합니다.
  /// 여기서는 그 결과를 저장하는 일만 합니다.
  Future<ImportOutcome> importFromDrop(
    PerformDropEvent event, {
    String? folderId,
  }) async {
    int failedCount = 0;
    String? lastError;
    final List<String> savedIds = <String>[];

    for (final DropItem item in event.session.items) {
      final DataReader? reader = item.dataReader;
      if (reader == null) {
        failedCount++;
        continue;
      }

      // 유튜브 링크를 끌어온 것인지 **먼저** 봅니다.
      // 그냥 읽으면 이미지인 줄 알고 내려받다가 실패합니다.
      // (자세한 이유는 DroppedItemReader.youtubeVideoIdOf() 설명 참고)
      final String? videoId = await _droppedItemReader.youtubeVideoIdOf(reader);
      if (videoId != null) {
        final String? savedId = await saveYoutube(videoId, folderId: folderId);
        if (savedId != null) {
          savedIds.add(savedId);
        } else {
          failedCount++;
          lastError = '유튜브 영상을 추가하지 못했습니다.';
        }
        continue;
      }

      final ImageFetchResult fetched = await _droppedItemReader.read(reader);

      if (!fetched.isSuccess) {
        failedCount++;
        lastError = fetched.errorMessage;
        continue;
      }

      final String? savedId = await _saveImageBytes(
        fetched.bytes!,
        folderId: folderId,
        title: fetched.suggestedTitle,
      );
      if (savedId != null) {
        savedIds.add(savedId);
      } else {
        failedCount++;
        // 가져오기는 됐는데 그림이 아닌 경우입니다.
        // (예: 이미지가 아니라 웹페이지 주소를 받아온 경우)
        // "그림 파일이 맞는지 확인하세요"보다 다음에 뭘 하면 되는지 알려줍니다.
        lastError =
            '가져온 것이 이미지가 아닙니다. '
            '이미지를 우클릭해 "이미지 복사" 후 붙여넣어 보세요.';
      }
    }

    return ImportOutcome(
      savedCount: savedIds.length,
      failedCount: failedCount,
      errorMessage: lastError,
      savedIds: savedIds,
    );
  }

  /// 클립보드에 있는 것을 들여옵니다. (Ctrl+V)
  ///
  /// 세 가지를 순서대로 시도합니다.
  ///   1. 클립보드에 **이미지**가 있으면 그걸 씁니다. (브라우저에서 "이미지 복사")
  ///   2. 글자가 **유튜브 주소**면 영상으로 저장합니다.
  ///   3. 글자가 **이미지 주소**면 내려받습니다. (브라우저에서 "이미지 주소 복사")
  ///
  /// 사용자는 둘 중 무엇을 복사했는지 신경 쓰지 않아도 되게 하려는 것입니다.
  Future<ImportOutcome> importFromClipboard({String? folderId}) async {
    ImageFetchResult fetched = await imageSource.fetchFromClipboard();

    // 주소를 실제로 받아보려 시도했는지 기록합니다.
    //
    // 이걸 구분하는 이유: 주소를 받아보다 실패한 경우에는 그쪽에서 온 구체적인
    // 이유("그 사이트가 막고 있습니다" 등)를 그대로 보여줘야 합니다.
    // 그걸 "클립보드에 이미지가 없습니다"로 덮어쓰면, 사용자는 클립보드를
    // 다시 복사하러 가는 엉뚱한 행동을 하게 됩니다.
    bool triedUrl = false;

    if (!fetched.isSuccess) {
      final String? text = await imageSource.readClipboardText();

      // 유튜브 주소면 이미지로 내려받으려 하지 말고 영상으로 저장합니다.
      // 유튜브 페이지를 내려받아 봐야 HTML이라 "그림이 아니다"로 실패합니다.
      final String? videoId = text == null ? null : youtubeVideoIdFrom(text);
      if (videoId != null) {
        return importYoutube(videoId, folderId: folderId);
      }

      if (text != null && looksLikeUrl(text)) {
        triedUrl = true;
        fetched = await imageSource.fetchFromUrl(text.trim());
      }
    }

    if (!fetched.isSuccess) {
      return ImportOutcome(
        failedCount: 1,
        errorMessage: triedUrl
            // 주소를 받아보다 실패 → 그쪽 이유를 그대로 전합니다.
            ? fetched.errorMessage
            // 클립보드에 쓸 만한 게 아예 없음 → 무엇을 하면 되는지 알려줍니다.
            : '클립보드에 이미지가 없습니다. 브라우저에서 이미지를 우클릭해 '
                  '"이미지 복사" 또는 "이미지 주소 복사"를 해보세요.',
      );
    }

    final String? savedId = await _saveImageBytes(
      fetched.bytes!,
      folderId: folderId,
      title: fetched.suggestedTitle,
    );

    return ImportOutcome(
      savedCount: savedId != null ? 1 : 0,
      failedCount: savedId != null ? 0 : 1,
      errorMessage: savedId != null ? null : '이미지를 저장하지 못했습니다.',
      savedIds: savedId != null ? <String>[savedId] : const <String>[],
    );
  }

  /// 영상 번호로 유튜브 레퍼런스를 들여옵니다.
  Future<ImportOutcome> importYoutube(
    String videoId, {
    String? folderId,
  }) async {
    final String? savedId = await saveYoutube(videoId, folderId: folderId);

    return ImportOutcome(
      savedCount: savedId != null ? 1 : 0,
      failedCount: savedId != null ? 0 : 1,
      errorMessage: savedId != null ? null : '유튜브 영상을 추가하지 못했습니다.',
      successMessage: '유튜브 영상을 추가했습니다.',
      savedIds: savedId != null ? <String>[savedId] : const <String>[],
    );
  }

  /// 클립보드에 유튜브 주소가 들어있으면 그걸 돌려줍니다. 없으면 null입니다.
  ///
  /// 주소 입력 대화상자를 띄울 때 미리 채워주는 데 씁니다.
  /// 방금 복사해온 것을 또 붙여넣게 하는 것은 번거롭기만 합니다.
  Future<String?> youtubeUrlInClipboard() async {
    final String? text = await imageSource.readClipboardText();

    if (text != null && isYoutubeVideoUrl(text)) {
      return text.trim();
    }
    return null;
  }

  /// 유튜브 영상 하나를 레퍼런스로 저장합니다.
  ///
  /// ── 썸네일을 왜 내려받아 저장하나 ──
  /// 화면에 띄울 때마다 img.youtube.com에서 가져오게 할 수도 있습니다.
  /// 하지만 그러면 **인터넷이 없을 때 목록이 텅 빈 회색 칸으로 보입니다.**
  /// 이 앱은 "내 컴퓨터에 모아두는" 것이 핵심이라, 이미지와 똑같이 파일로
  /// 저장해둡니다. 그러면 비행기 안에서도 목록은 그대로 보입니다.
  ///
  /// 제목이나 썸네일을 못 가져와도 **저장은 합니다.** 영상 번호만 있으면
  /// 나중에 재생할 수 있고, 제목은 편집 화면에서 직접 적을 수 있습니다.
  ///
  /// 성공하면 새로 만든 레퍼런스의 번호, 실패하면 null을 돌려줍니다.
  Future<String?> saveYoutube(String videoId, {String? folderId}) async {
    try {
      final YoutubeVideoInfo info = await youtubeInfoSource.fetch(videoId);

      // 썸네일은 있으면 저장하고, 없으면 없는 대로 넘어갑니다.
      String? savedFileName;
      final Uint8List? thumbnail = info.thumbnailBytes;
      if (thumbnail != null) {
        savedFileName = await imageStorage.saveImage(thumbnail);
      }

      final String id = newId();
      final DateTime now = DateTime.now().toUtc();
      await repository.save(
        ReferenceItem(
          id: id,
          type: ReferenceType.youtube,
          title: info.title,
          fileName: savedFileName,
          folderId: folderId,
          youtubeVideoId: videoId,
          // 썸네일이 있으면 그 자리에서 dHash도 계산해둡니다. 시각적
          // 유사도(services/utils/similarity.dart)에 씁니다.
          pHash: thumbnail == null ? null : dHashFromBytes(thumbnail),
          createdAt: now,
          updatedAt: now,
        ),
      );
      return id;
    } catch (error) {
      debugPrint('유튜브 저장 실패: $error');
      return null;
    }
  }

  // ── 아래는 이 파일 안에서만 쓰는 도우미들입니다 ──

  /// 고른 파일 하나를 줄여서 저장하고 레퍼런스로 등록합니다.
  ///
  /// 성공하면 새로 만든 레퍼런스의 번호, 실패하면 null을 돌려줍니다.
  Future<String?> _saveOneFile(PlatformFile file, String? folderId) async {
    final String originalName = file.name;
    try {
      // withData: true로 골랐으므로 bytes에 내용이 들어있습니다.
      // 혹시 없으면(플랫폼 사정) 경로로 읽어봅니다.
      Uint8List? bytes = file.bytes;

      if (bytes == null) {
        final String? path = file.path;
        if (path == null) {
          return null;
        }
        bytes = await File(path).readAsBytes();
      }

      return await _saveImageBytes(
        bytes,
        folderId: folderId,
        title: _stripExtension(originalName),
      );
    } catch (error) {
      // 파일 하나가 실패해도 나머지는 계속 처리되도록 여기서 잡습니다.
      // 사진 10장 중 1장이 깨졌다고 9장까지 못 넣으면 곤란합니다.
      debugPrint('이미지 저장 실패 ($originalName): $error');
      return null;
    }
  }

  /// 이미지 데이터를 줄여서 저장하고 레퍼런스로 등록합니다.
  ///
  /// **파일 고르기·끌어다 놓기·붙여넣기가 전부 이 함수로 모입니다.**
  /// 가져오는 경로는 셋이지만 저장하는 방식은 하나여야, 어느 쪽으로 넣든
  /// 똑같이 리사이즈되고 똑같이 기록됩니다.
  ///
  /// 성공하면 새로 만든 레퍼런스의 번호, 실패하면 null을 돌려줍니다.
  Future<String?> _saveImageBytes(
    Uint8List bytes, {
    String? folderId,
    String? title,
  }) async {
    try {
      final String? savedFileName = await imageStorage.saveImage(bytes);

      // 그림 파일이 아니거나 깨진 파일이면 null이 돌아옵니다.
      if (savedFileName == null) {
        return null;
      }

      final String id = newId();
      final DateTime now = DateTime.now().toUtc();
      await repository.save(
        ReferenceItem(
          id: id,
          type: ReferenceType.image,
          // 제목을 못 뽑아낸 경우(클립보드 등)에는 빈 제목으로 둡니다.
          // 목록에서는 "(제목 없음)"으로 보이고 편집 화면에서 고칠 수 있습니다.
          title: title ?? '',
          fileName: savedFileName,
          folderId: folderId,
          // 원본 바이트로 dHash를 계산해둡니다. 저장하며 줄인 크기가
          // 아니라 원본을 쓰는 이유: image_hash.dart가 9x8까지 average(평균)
          // 방식으로 줄여서 비교하므로, 원본이든 나중에 저장된 1600px
          // 파일이든 결과가 달라지지 않고, 저장 파일을 다시 읽는 디스크
          // 접근을 아낄 수 있습니다.
          pHash: dHashFromBytes(bytes),
          createdAt: now,
          updatedAt: now,
        ),
      );
      return id;
    } catch (error) {
      debugPrint('이미지 저장 실패: $error');
      return null;
    }
  }

  /// 파일 이름에서 확장자를 떼어냅니다. ("노을.jpg" → "노을")
  String _stripExtension(String fileName) {
    final int dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0) {
      return fileName;
    }
    return fileName.substring(0, dotIndex);
  }
}
```

- [ ] **Step 2: 커밋**

```bash
git add lib/services/reference_importer.dart
git commit -m "ReferenceImporter가 파트 대신 폴더(선택적)를 받도록 바꾼다

partId(필수)가 folderId(선택적, null 허용)로 바뀝니다. 폴더는 파트와
달리 없어도(null) 정상 상태이기 때문입니다.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: 메인 화면 사이드바를 폴더로

**Files:**
- Modify: `lib/widgets/app_sidebar.dart`
- Modify: `lib/screens/home_screen.dart`

**Interfaces:**
- Consumes: Task 3의 `ReferenceImporter.import*({String? folderId})`
- Produces: `AppSidebar`가 `folders`/`selectedFolderId`/`onSelectFolder`를
  받는다(뒤 Task는 없음 — 이 앱에서 AppSidebar를 쓰는 곳은 home_screen.dart뿐).

- [ ] **Step 1: `app_sidebar.dart`를 폴더 목록으로**

`lib/widgets/app_sidebar.dart` 전체를 아래로 바꿔씁니다. 파트→폴더로
이름과 문서만 바꾸고 구조는 그대로입니다(아이콘도 그대로 `folder_copy_outlined`
를 씁니다 — 이미 폴더 모양이라 바꿀 필요가 없습니다).

```dart
// 화면 왼쪽에 붙는 사이드바입니다.
//
// 의뢰인이 정해준 목업의 ①②③에 해당합니다.
//
//   ① 위   — 사용자 (지금은 이름만. 로그인 기능은 아직 없습니다)
//   ② 가운데 — 폴더 목록 (이 프로젝트의 레퍼런스 묶음으로 나눠 보기)
//   ③ 아래  — 설정 · 로그인/로그아웃
//
// ── 여기 있던 "파트"는 없앴습니다 (2026-09-06) ──
// 원래 ②는 "파트"(디자인/파티클 같은 큰 갈래) 목록이었습니다. 그런데
// References 테이블에는 폴더도 이미 있었고, 폴더와 파트가 하는 일이
// 실제로는 겹쳤습니다(의뢰인이 직접 지적한 부분 — CLAUDE.md
// "단계 밖 작업: 파트를 없애고 사이드바를 폴더로 바꾸기" 참고). 그래서
// 이 자리를 폴더 목록으로 바꾸고 파트는 앱에서 완전히 지웠습니다.
//
// ── 색이 본문과 다릅니다 ──
// 목업에서 사이드바만 짙은 색입니다. 본문은 밝은데 사이드바는 어둡게 두면
// "여기는 성격이 다른 영역"이라는 것이 한눈에 보입니다.
// 그래서 밝은 모드에서도 사이드바는 어두운 색을 씁니다.

import 'package:flutter/material.dart';

import '../models/taxonomy_item.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';

/// 사이드바의 너비입니다. (기존 웹앱의 `flex: 0 0 176px`보다 조금 넓게)
const double sidebarWidth = 232;

/// 사이드바를 항상 펼쳐둘 최소 창 너비입니다.
///
/// 이보다 좁으면 사이드바가 목록을 너무 많이 잡아먹습니다. 그래서 폰이나
/// 좁은 창에서는 평소엔 숨겨두고 메뉴 버튼으로 꺼내 씁니다.
const double sidebarBreakpoint = 900;

/// 화면 왼쪽 사이드바입니다.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.userName,
    required this.folders,
    required this.selectedFolderId,
    required this.onSelectFolder,
    required this.onOpenBoards,
    required this.onOpenTrash,
    required this.onOpenSettings,
    required this.onLogInOut,
  });

  /// ①에 보여줄 사용자 이름입니다.
  final String userName;

  /// ②에 보여줄 폴더 목록입니다.
  final List<TaxonomyItem> folders;

  /// 지금 고른 폴더의 id입니다. null이면 "전체"를 보고 있는 것입니다.
  final String? selectedFolderId;

  /// 폴더를 골랐을 때 알려줍니다. null을 넘기면 "전체"입니다.
  final ValueChanged<String?> onSelectFolder;

  /// 무드보드 목록을 눌렀을 때 실행할 동작입니다.
  final VoidCallback onOpenBoards;

  /// 휴지통을 눌렀을 때 실행할 동작입니다.
  final VoidCallback onOpenTrash;

  /// 설정을 눌렀을 때 실행할 동작입니다.
  final VoidCallback onOpenSettings;

  /// 로그인/로그아웃을 눌렀을 때 실행할 동작입니다.
  final VoidCallback onLogInOut;

  /// 사이드바의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    // 사이드바는 밝은 모드에서도 어두운 색을 씁니다.
    // 그래서 지금 모드와 상관없이 어두운 모드 색을 가져다 씁니다.
    const AppPalette dark = AppPalette.dark;

    return Container(
      width: sidebarWidth,
      color: dark.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildUserBlock(dark),

              const SizedBox(height: 20),

              // 무드보드로 가는 길입니다. 폴더 목록 위에 따로 둡니다.
              //
              // ── 왜 폴더 목록 안에 넣지 않았나 ──
              // 폴더는 "레퍼런스를 어떻게 나눠 볼까"이고, 무드보드는 "레퍼런스로
              // 무엇을 할까"입니다. 성격이 달라서 같은 목록에 섞으면 폴더 중
              // 하나처럼 보입니다. 한 칸 띄워 두면 다른 종류라는 것이 드러납니다.
              _buildBoardsBlock(dark),

              const SizedBox(height: 12),

              // ② 폴더 목록입니다. Expanded로 감싸 남는 공간을 다 차지하게 하면,
              // ③(설정)이 언제나 맨 아래에 붙습니다.
              Expanded(child: _buildFolderList(dark)),

              const SizedBox(height: 12),
              _buildBottomBlock(dark),
            ],
          ),
        ),
      ),
    );
  }

  /// ① 사용자 부분입니다.
  Widget _buildUserBlock(AppPalette dark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark.surface,
        borderRadius: BorderRadius.circular(appCornerRadius),
        border: Border.all(color: dark.border),
      ),
      child: Row(
        children: <Widget>[
          // 사진이 없으므로 이름 첫 글자로 대신합니다.
          CircleAvatar(
            radius: 18,
            backgroundColor: dark.accentSoft,
            child: Text(
              _initial(),
              style: TextStyle(
                color: dark.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dark.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  // 로그인 기능이 없다는 것을 숨기지 않고 그대로 적습니다.
                  // 가짜 계정 아이디를 지어내면 나중에 진짜 로그인을 붙일 때
                  // 사용자가 혼란스러워집니다.
                  '로그인 안 함',
                  style: AppText.meta.copyWith(color: dark.textDim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 무드보드로 가는 줄입니다.
  Widget _buildBoardsBlock(AppPalette dark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: dark.surface,
        borderRadius: BorderRadius.circular(appCornerRadius),
        border: Border.all(color: dark.border),
      ),
      child: _buildNavItem(
        dark,
        icon: Icons.dashboard_outlined,
        label: '무드보드',

        // 고른 상태로 표시하지 않습니다. 여기는 "머무는 자리"가 아니라
        // 다른 화면으로 가는 문이라, 켜져 있으면 지금 그 화면인 줄 오해합니다.
        isSelected: false,
        onTap: onOpenBoards,
      ),
    );
  }

  /// ② 폴더 목록입니다. 이 프로젝트의 레퍼런스 묶음으로 나눠 봅니다.
  ///
  /// 맨 위의 "전체 레퍼런스"는 폴더를 안 가리는 상태입니다. 폴더가 여럿일 때
  /// 전부 훑어보려면 이게 필요합니다.
  Widget _buildFolderList(AppPalette dark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: dark.surface,
        borderRadius: BorderRadius.circular(appCornerRadius),
        border: Border.all(color: dark.border),
      ),

      // 폴더가 많아지면 사이드바 밖으로 넘칩니다. 스크롤되게 둡니다.
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildNavItem(
            dark,
            icon: Icons.photo_library_outlined,
            label: '전체 레퍼런스',
            isSelected: selectedFolderId == null,
            onTap: () => onSelectFolder(null),
          ),

          for (final TaxonomyItem folder in folders)
            _buildNavItem(
              dark,
              icon: Icons.folder_copy_outlined,
              label: folder.name,
              isSelected: selectedFolderId == folder.id,
              onTap: () => onSelectFolder(folder.id),
            ),
        ],
      ),
    );
  }

  /// ③ 아래쪽 설정·로그인 부분입니다.
  Widget _buildBottomBlock(AppPalette dark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: dark.surface,
        borderRadius: BorderRadius.circular(appCornerRadius),
        border: Border.all(color: dark.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 휴지통은 폴더 목록(②)이 아니라 여기 둡니다. 폴더는 "레퍼런스를
          // 어떻게 나눠 볼까"인데, 휴지통은 설정처럼 가끔 들르는 도구라
          // 성격이 다릅니다.
          _buildNavItem(
            dark,
            icon: Icons.delete_outline,
            label: '휴지통',
            isSelected: false,
            onTap: onOpenTrash,
          ),
          _buildNavItem(
            dark,
            icon: Icons.settings_outlined,
            label: '설정',
            isSelected: false,
            onTap: onOpenSettings,
          ),
          _buildNavItem(
            dark,
            icon: Icons.login_outlined,
            label: '로그인',
            isSelected: false,
            onTap: onLogInOut,
          ),
        ],
      ),
    );
  }

  /// 사이드바 안의 누를 수 있는 줄 하나를 만듭니다.
  ///
  /// ②와 ③이 같은 모양이라 하나로 만들어 돌려씁니다.
  Widget _buildNavItem(
    AppPalette dark, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // 고른 항목은 배경을 밝게 깔아 구분합니다.
    final Color foreground = isSelected ? dark.accent : dark.textDim;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(inputCornerRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? dark.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(inputCornerRadius),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.folderChip.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 이름의 첫 글자를 돌려줍니다. 아바타 자리에 씁니다.
  String _initial() {
    final String trimmed = userName.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return trimmed.substring(0, 1);
  }
}
```

- [ ] **Step 2: `home_screen.dart`의 파트 관련 상태·메서드를 폴더로**

`lib/screens/home_screen.dart`에서 아래 네 군데를 고칩니다.

**(a) 153~154번 줄** (상태 필드):

```dart
  /// 지금 사이드바에서 고른 폴더의 id입니다. null이면 "전체"를 보는 중입니다.
  String? _selectedFolderId;
```

**(b) 194~199번 줄** (새 레퍼런스가 들어갈 폴더 — 이제 선택적이라 `?? defaultPartId`가
사라지고 그냥 `_selectedFolderId`를 돌려줍니다):

```dart
  /// 새로 넣는 레퍼런스를 어느 폴더에 넣을지 정합니다.
  ///
  /// 사이드바에서 폴더를 고르고 있으면 그 폴더로, "전체"를 보고 있으면
  /// 폴더 없음(null)으로 들어갑니다. 폴더는 파트와 달리 없어도 정상
  /// 상태이기 때문에 기본값으로 채울 필요가 없습니다.
  String? get _folderIdForNewItems => _selectedFolderId;
```

**(c) 793~830번 줄**(`_buildSidebar`/`_selectPart`)을 아래로 바꿉니다:

```dart
  /// 왼쪽 사이드바를 만듭니다. (①②③)
  Widget _buildSidebar() {
    return AppSidebar(
      userName: widget.settings.userName,
      folders: _taxonomyOptions[TaxonomyKind.folder] ?? <TaxonomyItem>[],
      selectedFolderId: _selectedFolderId,
      onSelectFolder: _selectFolder,
      onOpenBoards: _openBoards,
      onOpenTrash: _openTrash,
      onOpenSettings: _openSettings,
      onLogInOut: _showLoginNotReady,
    );
  }

  /// 사이드바에서 폴더를 골랐을 때 실행됩니다. null이면 "전체"입니다.
  void _selectFolder(String? folderId) {
    // 좁은 창이면 사이드바가 서랍으로 열려 있습니다. 고른 뒤 닫아줍니다.
    // 안 닫으면 서랍에 가려서 결과가 안 보입니다.
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }

    // 폴더를 옮기면 고르던 것을 놓습니다.
    // 안 보이게 된 것을 골라둔 채로 두면 엉뚱한 것에 작업하게 됩니다.
    _exitSelectionMode();

    setState(() {
      _selectedFolderId = folderId;
    });

    // clearFilter가 아니라 copyWith로 넣습니다. null을 넣어야 하는 경우
    // ("전체")는 clearFilter(folder)로 처리합니다.
    if (folderId == null) {
      _applyQuery(_query.clearFilter(TaxonomyKind.folder));
    } else {
      _applyQuery(_query.copyWith(folderId: folderId));
    }
  }
```

**(d) 네 곳의 호출부**를 `partId: _partIdForNewItems` →
`folderId: _folderIdForNewItems`로 바꿉니다.

- 500번 줄: `() => _importer.importYoutube(videoId, folderId: _folderIdForNewItems),`
- 727~729번 줄과 734~736번 줄(Ctrl+V 둘 다):
  `() => _importer.importFromClipboard(folderId: _folderIdForNewItems),`
- 851~853번 줄: `() => _importer.importFromFilePicker(folderId: _folderIdForNewItems),`

- [ ] **Step 3: 커밋**

```bash
git add lib/widgets/app_sidebar.dart lib/screens/home_screen.dart
git commit -m "왼쪽 사이드바의 파트 목록을 폴더 목록으로 바꾼다

새 개념을 도입하지 않습니다 — 폴더(TaxonomyKind.folder)는 이미 있던
분류입니다. 사이드바가 '지금 보고 있는 자리'로 폴더를 쓰게 됩니다.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 5: 목록 위 필터줄에서 폴더 드롭다운 제거

**Files:**
- Modify: `lib/widgets/reference_filter_bar.dart`

**Interfaces:**
- Consumes: Task 1의 `ReferenceQuery`(folderId가 이제 "자리" 역할)
- Produces: 없음(이 화면의 마지막 소비자)

- [ ] **Step 1: 파트 케이스 삭제, 폴더를 필터줄에서 제외**

`_selectedIdFor`(54~69번 줄)에서 `case TaxonomyKind.part: return null;`
두 줄을 지웁니다.

```dart
  String? _selectedIdFor(TaxonomyKind kind) {
    switch (kind) {
      case TaxonomyKind.folder:
        return query.folderId;
      case TaxonomyKind.category:
        return query.categoryId;
      case TaxonomyKind.tag:
        return query.tagId;
      case TaxonomyKind.project:
        return query.projectId;
    }
  }
```

`_changeFilter`(75~95번 줄)에서 `case TaxonomyKind.part: break;` 두 줄을
지웁니다.

```dart
  void _changeFilter(TaxonomyKind kind, String? id) {
    if (id == null) {
      onQueryChanged(query.clearFilter(kind));
      return;
    }

    switch (kind) {
      case TaxonomyKind.folder:
        onQueryChanged(query.copyWith(folderId: id));
      case TaxonomyKind.category:
        onQueryChanged(query.copyWith(categoryId: id));
      case TaxonomyKind.tag:
        onQueryChanged(query.copyWith(tagId: id));
      case TaxonomyKind.project:
        onQueryChanged(query.copyWith(projectId: id));
    }
  }
```

파일 맨 아래(296~298번 줄) `filterableTaxonomyKinds`를 아래로 바꿉니다 —
이제 `part`가 아니라 `folder`를 뺍니다(사이드바로 이사했으므로).

```dart
/// 이 줄에서 고를 수 있는 분류 종류들입니다.
///
/// **폴더만 빠져 있습니다.** 폴더는 왼쪽 사이드바에서 고르는 "지금 보고
/// 있는 자리"입니다(2026-09-06까지는 파트가 이 역할이었습니다 — 파트를
/// 없애면서 폴더가 그 자리를 이어받았습니다). 여기에도 두면 같은 것을
/// 두 군데서 고르게 되어 "어느 쪽이 진짜지?" 하게 됩니다.
final List<TaxonomyKind> filterableTaxonomyKinds = TaxonomyKind.values
    .where((TaxonomyKind kind) => kind != TaxonomyKind.folder)
    .toList();
```

- [ ] **Step 2: 커밋**

```bash
git add lib/widgets/reference_filter_bar.dart
git commit -m "목록 위 필터줄에서 폴더 드롭다운을 없앤다 (사이드바로 이사)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 6: 분류 관리 화면에서 파트 탭 제거

**Files:**
- Modify: `lib/screens/taxonomy_manage_screen.dart`

**Interfaces:**
- Consumes: Task 1의 `TaxonomyKind`(part 없음 → 탭이 자동으로 4개로 줄어듦)
- Produces: 없음

- [ ] **Step 1: 기본 파트 보호 코드 삭제**

`_confirmDelete`(144~195번 줄)에서 `else if (item.kind == TaxonomyKind.part)`
분기(154~161번 줄)를 지웁니다 — 남는 것은 "쓰는 곳 없음"과 "일반" 두
갈래입니다.

```dart
    final String message;
    if (usageCount == 0) {
      message = '"${item.name}" ${withObjectParticle(kindName)} 지웁니다.\n'
          '이 ${withObjectParticle(kindName)} 쓰는 레퍼런스는 없습니다.';
    } else {
      message = '"${item.name}" ${withObjectParticle(kindName)} 지웁니다.\n\n'
          '이 ${withObjectParticle(kindName)} 쓰는 레퍼런스가 $usageCount개 있습니다.\n'
          '레퍼런스 자체는 지워지지 않지만, 그 $kindName 연결이 사라지며 '
          '되돌릴 수 없습니다.';
    }
```

`_buildList`의 `itemBuilder`(251~292번 줄)에서 `isDefaultPart` 관련
부분을 지웁니다:

```dart
      itemBuilder: (BuildContext context, int index) {
        final TaxonomyItem item = items[index];
        final int usageCount = _usageCounts[item.id] ?? 0;

        return ListTile(
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
```

**Step 2: 파일 맨 위 설명 주석 정리**

14~19번 줄("파트만 두 가지가 다릅니다" 절)을 지웁니다 — 더 이상 예외가
없습니다.

```dart
// 폴더·카테고리·태그·프로젝트를 관리하는 화면입니다.
//
// 하는 일:
//   - 종류별로 만들어둔 항목 목록 보기 (각 항목을 몇 개의 레퍼런스가 쓰는지 함께)
//   - 이름 바꾸기
//   - 삭제 (쓰는 레퍼런스가 있으면 몇 개인지 알려주고 확인받음)
//   - 새로 만들기
//
// ── 왜 삭제할 때 확인을 받나 ──
// 분류 항목을 지우면 그걸 쓰던 레퍼런스에서 조용히 연결이 끊깁니다.
// 레퍼런스 자체는 살아있지만, "인물" 폴더에 있던 사진 50장이 폴더 없음이 되고
// **되돌릴 방법이 없습니다.** 그래서 지우기 전에 몇 개가 영향을 받는지
// 반드시 보여주고 확인을 받습니다.
```

- [ ] **Step 3: 커밋**

```bash
git add lib/screens/taxonomy_manage_screen.dart
git commit -m "분류 관리 화면에서 기본 파트 보호 로직을 지운다

파트 탭 자체는 TaxonomyKind.values에서 이미 지워졌으므로 자동으로
4개(폴더/카테고리/태그/프로젝트)로 줄어듭니다.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 7: 레퍼런스 상세 화면에서 파트 칸 제거

**Files:**
- Modify: `lib/screens/reference_taxonomy_edit_controller.dart`
- Modify: `lib/widgets/reference_detail_taxonomy_fields.dart`
- Modify: `lib/screens/reference_detail_screen.dart:243`

**Interfaces:**
- Consumes: Task 1의 `TaxonomyKind`(part 없음)
- Produces: `ReferenceTaxonomyEditController`에 더 이상 `partId`/`setPart`가
  없음.

- [ ] **Step 1: `reference_taxonomy_edit_controller.dart`에서 파트 상태 삭제**

`String? get partId => _partId;`와 `String? _partId;`(47~48번 줄) 삭제.
`initFrom()`에서 `_partId = item.partId;`(64번 줄) 삭제. `setPart()`
메서드(115~119번 줄) 전체 삭제. `handleCreated()`의 `switch`에서
`case TaxonomyKind.part: _partId = created.id; break;`(151~153번 줄) 삭제.

```dart
  Future<void> handleCreated(
    TaxonomyRepository repository,
    TaxonomyKind kind,
    TaxonomyItem created,
  ) async {
    await reloadFor(repository, kind);

    if (_disposed) {
      return;
    }

    switch (kind) {
      case TaxonomyKind.folder:
        _folderId = created.id;
        break;
      case TaxonomyKind.category:
        _categoryId = created.id;
        break;
      case TaxonomyKind.tag:
        _tagIds = <String>[..._tagIds, created.id];
        break;
      case TaxonomyKind.project:
        _projectIds = <String>[..._projectIds, created.id];
        break;
    }
    notifyListeners();
  }
```

- [ ] **Step 2: `reference_detail_taxonomy_fields.dart`에서 파트 칸 삭제**

38~49번 줄의 파트 `TaxonomySingleField` 블록 전체와 그 위 주석, 뒤따르는
`const SizedBox(height: 16),`을 지웁니다. 폴더가 맨 위로 옵니다.

```dart
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TaxonomySingleField(
          kind: TaxonomyKind.folder,
          options: controller.options[TaxonomyKind.folder] ?? <TaxonomyItem>[],
          selectedId: controller.folderId,
          repository: repository,
          onChanged: controller.setFolder,
          onCreated: (TaxonomyItem created) => controller.handleCreated(
            repository,
            TaxonomyKind.folder,
            created,
          ),
        ),
        const SizedBox(height: 16),
        // ... (카테고리 이하는 그대로)
```

- [ ] **Step 3: `reference_detail_screen.dart:243`에서 partId 인자 삭제**

`ReferenceItem(...)`을 만드는 곳에서 `partId: _taxonomyEdit.partId,` 줄을
지웁니다(주변 줄은 그대로 둡니다 — `folderId: _taxonomyEdit.folderId,` 등은
안 건드립니다).

- [ ] **Step 4: 커밋**

```bash
git add lib/screens/reference_taxonomy_edit_controller.dart lib/widgets/reference_detail_taxonomy_fields.dart lib/screens/reference_detail_screen.dart
git commit -m "레퍼런스 편집 화면에서 파트 고르는 칸을 지운다

폴더·카테고리·태그·프로젝트 네 칸만 남습니다.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 8: 무드보드 외부 드롭/붙여넣기가 판의 폴더를 쓰도록

**Files:**
- Modify: `lib/screens/board_screen.dart`

**Interfaces:**
- Consumes: Task 3의 `ReferenceImporter.importFromDrop/importFromClipboard({String? folderId})`
- Produces: 없음

- [ ] **Step 1: import 정리**

37번 줄 `import '../models/taxonomy_item.dart' show defaultPartId;`를
지웁니다(이 파일에서 더 이상 쓰지 않습니다).

- [ ] **Step 2: 두 호출부를 판의 폴더로**

`_onExternalFilesDropped`(308~335번 줄)의 `partId: defaultPartId,`를
`folderId: widget.board.folderId,`로 바꾸고, 그 위 문서 주석도 갱신합니다.

```dart
  /// 탐색기·브라우저에서 파일을 이 판 위로 직접 끌어다 놓았을 때 실행됩니다.
  /// (BoardViewport.onExternalFilesDropped)
  ///
  /// home_drop_area.dart(메인 화면)와 같은 가져오기 도구를 그대로 쓰되,
  /// 새로 만들어진 레퍼런스를 **놓은 자리에 곧바로 카드로도 배치**합니다.
  /// 새 레퍼런스는 **이 판이 연결된 폴더**로 들어갑니다(연결 안 됐으면
  /// 폴더 없음) — "이 프로젝트 폴더용 무드보드에 사진을 끌어다 놓으면
  /// 그 프로젝트 폴더에 알아서 들어간다"는 자연스러운 규칙입니다.
  Future<void> _onExternalFilesDropped(
    PerformDropEvent event,
    Offset canvasPosition,
  ) async {
    final ImportOutcome outcome = await _importer.importFromDrop(
      event,
      folderId: widget.board.folderId,
    );
```

`_onPasteFromClipboard`(345~348번 줄)도 같은 방식으로 바꿉니다.

```dart
  Future<void> _onPasteFromClipboard() async {
    final ImportOutcome outcome = await _importer.importFromClipboard(
      folderId: widget.board.folderId,
    );
```

- [ ] **Step 3: 커밋**

```bash
git add lib/screens/board_screen.dart
git commit -m "무드보드에 파일을 끌어다 놓거나 붙여넣으면 그 판의 폴더로 들어가게 한다

예전에는 무조건 기본 파트로 들어갔습니다. 파트가 없어지면서, 판이
폴더에 연결돼 있으면(PR #59) 그 폴더로, 아니면 폴더 없음으로 바뀝니다.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 9: 데이터베이스 마이그레이션 (schemaVersion 5 → 6)

**Files:**
- Modify: `lib/data/tables.dart:60-67` (References.partId 칼럼 정의 삭제)
- Modify: `lib/data/app_database.dart` (schemaVersion, onCreate, onUpgrade,
  _upgradeToVersion6, _createDefaultPart 삭제)
- Generate: `lib/data/app_database.g.dart` (`dart run build_runner build`로 생성 — 손대지 않음)

**Interfaces:**
- Consumes: Task 1~8에서 이미 `partId`를 안 쓰게 된 앱 코드 전체
- Produces: 실제 sqlite 파일에서 `references.part_id` 칼럼이 없어지고,
  `taxonomy_items`에 `kind='part'` 행이 없어짐(Task 10의 마이그레이션
  테스트가 이 계약을 검증한다).

- [ ] **Step 1: `tables.dart`에서 partId 칼럼 정의 삭제**

`lib/data/tables.dart`의 60~67번 줄(`/// 어느 파트에 들어있는지.` 주석부터
`TextColumn get partId => text().nullable()();`까지)을 지웁니다.

```dart
  /// 어느 카테고리에 들어있는지. 카테고리도 하나만 가질 수 있습니다.
  TextColumn get categoryId => text().nullable()();

  /// 목록 맨 위에 고정할지 여부입니다. 정렬 방식과 무관하게 항상 위에 옵니다.
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
```

- [ ] **Step 2: `dart run build_runner build`로 생성 파일 갱신**

Run: `dart run build_runner build`
Expected: `lib/data/app_database.g.dart`가 다시 생성되고, `partId` 관련
생성 코드(`$ReferencesTable.partId`, `ReferenceRow.partId` 등)가
사라집니다. (5~7분 걸립니다 — CLAUDE.md 참고)

- [ ] **Step 3: `app_database.dart` 수정**

`schemaVersion`을 6으로 올리고 버전 기록에 한 줄 추가합니다(62~63번 줄
근처):

```dart
  ///   5 — Boards에 folderId 추가 (무드보드를 폴더/프로젝트에 연결)
  ///   6 — 파트(Part) 개념을 없앰. References.partId 칼럼 삭제,
  ///       taxonomy_items의 kind='part' 행 삭제
  @override
  int get schemaVersion => 6;
```

`onCreate`(70~73번 줄)에서 기본 파트를 만들던 줄을 지웁니다 — 새로
설치하는 사람은 처음부터 파트 개념 자체가 없어야 합니다.

```dart
      onCreate: (Migrator m) async {
        await m.createAll();
      },
```

`onUpgrade`(79~112번 줄) 끝에 v6 단계를 추가합니다. **부등호로 씁니다**
(CLAUDE.md 규칙) — v6은 "이미 있는 칼럼을 지우는" 마이그레이션이라
PR #59의 `from >= 3 && from < 5`같은 특수 조건이 필요 없습니다(뒤
"왜 `from < 6`으로 충분한가" 참고).

```dart
        if (from >= 3 && from < 5) {
          await _upgradeToVersion5(m);
        }

        // v6은 반대로 "이미 있는 칼럼을 지우는" 마이그레이션이라 PR #59의
        // v5처럼 특수한 부등호 조건이 필요 없습니다. createTable이 현재
        // 시점의 tables.dart를 쓰는 문제는 "칼럼을 새로 만들 때"만
        // 생기는데, 여기서는 어차피 안 만들기 때문입니다. v1이든 v5든
        // partId가 있었던 사람이든(v1은 애초에 없었지만 v2 단계에서
        // 이미 추가되고 채워진 뒤라 v6 시점에는 모두가 갖고 있습니다)
        // 그냥 지우면 됩니다.
        if (from < 6) {
          await _upgradeToVersion6(m);
        }
```

새 메서드를 `_upgradeToVersion5` 바로 아래에 추가합니다:

```dart
  /// 버전 5 → 6. 파트(Part) 개념을 완전히 없앱니다.
  ///
  /// 두 가지를 합니다.
  ///   1. References.partId 칼럼을 지웁니다.
  ///   2. taxonomy_items에서 kind='part'인 행(기본 파트 포함)을 지웁니다.
  ///
  /// ── 소프트 삭제가 아니라 진짜로 지우는 이유 ──
  /// 다른 분류 항목(폴더 등)을 지울 때는 deletedAt만 찍습니다(원칙 5,
  /// 소프트 삭제) — "이 기기에서 지운 건지 다른 기기에서 새로 만든
  /// 건지" 구분해야 하기 때문입니다. 하지만 파트는 **개념 자체가
  /// 사라지는 것**이라 이 구분이 필요 없습니다. 소프트 삭제로 남겨두면
  /// 영원히 안 보이는 죽은 행만 쌓입니다.
  ///
  /// ── dropColumn이 SQLite 3.35.0을 요구합니다 ──
  /// 이 프로젝트가 쓰는 sqlite3_flutter_libs는 훨씬 최신 SQLite를
  /// 번들하므로 문제없이 될 것으로 보입니다. Task 10의 마이그레이션
  /// 테스트가 실제로 되는지 확인합니다.
  Future<void> _upgradeToVersion6(Migrator m) async {
    await m.dropColumn(references, references.partId);

    await customStatement(
      "DELETE FROM taxonomy_items WHERE kind = 'part'",
    );
  }
```

`_createDefaultPart()` 메서드(227~245번 줄) 전체를 지웁니다 — 더 이상
아무도 부르지 않습니다(`onCreate`도, `_upgradeToVersion2`는 **역사적
동작이라 그대로 둡니다** — 아래 설명 참고).

**중요 — `_upgradeToVersion2`는 그대로 둡니다.** v1에서 시작하는 사용자는
반드시 v2 단계(파트 칼럼 추가 + 기본 파트 생성)를 거쳐야 하고, 그 다음
v6 단계가 그걸 도로 지웁니다. 잠깐 만들었다가 지우는 것이라 낭비처럼
보이지만, `_upgradeToVersion2`를 건드리면 그 자체가 "역사를 다시 쓰는"
일이라 CLAUDE.md가 경고하는 함정(과거 마이그레이션 단계는 그 시절
그대로 둬야 한다)에 걸립니다. 손대지 마세요.

- [ ] **Step 4: `flutter analyze lib`로 앱 코드 전체 확인**

Run: `flutter analyze lib`
Expected: 0 issues. Task 1~9를 전부 마쳤으므로 `lib/` 폴더 전체가
깨끗해야 합니다(테스트 폴더는 Task 10~11에서 고칩니다).

- [ ] **Step 5: 커밋**

```bash
git add lib/data/tables.dart lib/data/app_database.dart lib/data/app_database.g.dart
git commit -m "저장 구조 v6: References.partId 칼럼과 파트 데이터를 지운다

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 10: v5→v6 마이그레이션 테스트 (새 파일)

**Files:**
- Create: `test/data/migration_v5_to_v6_test.dart`

**Interfaces:**
- Consumes: Task 9의 `AppDatabase`(schemaVersion 6, `_upgradeToVersion6`)
- Produces: 없음

- [ ] **Step 1: 실패하는 테스트부터 작성**

`migration_v4_to_v5_test.dart`와 같은 패턴(진짜 파일 기반 sqlite)입니다.
아래 파일 전체를 작성합니다.

```dart
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
```

- [ ] **Step 2: 테스트 실행**

Run: `flutter test test/data/migration_v5_to_v6_test.dart`
Expected: 모든 테스트 PASS. 실패한다면 `_upgradeToVersion6`의
`dropColumn` 호출이나 `DELETE FROM taxonomy_items` 조건을 다시 확인합니다
(예: `dropColumn`이 이 환경의 SQLite 버전에서 안 된다면, 스펙 문서의
대안 — `Migrator.alterTable`로 References 테이블을 partId 없이
재생성하는 방식 — 으로 바꿉니다).

- [ ] **Step 3: 커밋**

```bash
git add test/data/migration_v5_to_v6_test.dart
git commit -m "v5→v6(파트 제거) 마이그레이션 테스트를 추가한다

v1에서 곧장 v6로 건너뛰는 경우를 포함해 6가지를 확인한다.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 11: 기존 테스트 정리

**Files:**
- Modify: `test/data/migration_v1_to_v2_test.dart`
- Modify: `test/data/migration_v2_to_v3_test.dart`
- Modify: `test/data/migration_v3_to_v4_test.dart`
- Modify: `test/data/migration_v4_to_v5_test.dart`
- Modify: `test/services/reference_importer_saved_ids_test.dart`
- Modify: `test/services/reference_importer_hash_test.dart`
- Modify: `test/screens/taxonomy_manage_screen_test.dart`
- Delete: `test/repositories/part_delete_test.dart`
- Create (rewrite): `test/screens/home_folders_sidebar_test.dart` (기존
  `test/screens/home_parts_test.dart`를 지우고 대체)

**Interfaces:**
- Consumes: Task 1~10에서 확정된 모든 시그니처
- Produces: 전체 테스트 스위트가 통과함(Task 12에서 확인)

- [ ] **Step 1: `migration_v1_to_v2_test.dart` 정리**

이 파일은 원래 "v1→v2가 파트를 만든다"를 확인하던 파일입니다. 파트가
없어졌으니 파트 관련 테스트 5개(`예전 레퍼런스가 전부 기본 파트에
들어간다`, `기본 파트가 만들어져 있다`, `원래 있던 폴더는 그대로
남는다` 바로 앞까지, `두 번 열어도 기본 파트가 하나만 생긴다`, `기본
파트 이름을 바꿔뒀으면...`)를 지웁니다 — 즉 138~244번 줄 전체(다섯
개의 `test(...)` 블록)를 지웁니다. 남기는 것은 맨 처음
`'옛 구조의 파일을 열어도 앱이 켜지고 레퍼런스가 남아 있다'`(120~136번
줄)와 `'원래 있던 폴더는 그대로 남는다'`(175~192번 줄) 둘입니다.

결과는 아래와 같은 모습이어야 합니다(파일 나머지는 그대로 두고 이
부분만 남깁니다):

```dart
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
```

`import 'package:reference_archive_app/models/taxonomy_item.dart';`는
`TaxonomyItem` 클래스가 여전히 쓰이므로 **그대로 둡니다**(안의
`defaultPartId`/`defaultPartName`만 안 쓰게 될 뿐입니다). 파일 맨 위
50~51번 줄 주석(`**partId 칸이 없습니다.**`)도 그대로 둡니다 — 사실
그대로입니다.

- [ ] **Step 2: `migration_v2_to_v3_test.dart` 정리**

`expect(items.first.partId, defaultPartId, ...)`(155번 줄)와 그 아래
"v2가 해줘야 할 일" 관련 파트 확인 블록(235~242번 줄, `expect(items.first.partId, ...)`
와 `TaxonomyKind.part`로 개수 세는 부분)을 지웁니다. 파트 데이터를 fixture에
심는 부분(`partColumn`, 112번 줄 INSERT의 `part_id` 값, 117~121번 줄의
`defaultPartId`/`defaultPartName`을 이용한 INSERT)은 **그대로 둡니다** —
이건 "v2 시절엔 파트 칸이 있었다"는 역사적 사실을 흉내내는 fixture일
뿐이고, `defaultPartId`/`defaultPartName` 대신 리터럴 문자열
(`'old-default-part'`, `'기본'`)을 직접 씁니다(그 상수들이 앱에서
지워졌으므로). 어느 줄에서 이 상수를 쓰고 있었는지는
`grep -n "defaultPartId\|defaultPartName" test/data/migration_v2_to_v3_test.dart`로
확인한 뒤 전부 리터럴로 바꿉니다. `import '.../taxonomy_item.dart';`는
`TaxonomyItem` 클래스를 계속 쓰면 그대로 두고, 안 쓰면(파일을 다시 봐서
확인) 지웁니다.

- [ ] **Step 3: `migration_v3_to_v4_test.dart` 정리**

같은 방식입니다. `expect(items.first.partId, defaultPartId, ...)`(231번
줄)와 파트 개수를 세는 부분(233~236번 줄)을 지웁니다. fixture의
`defaultPartId`/`defaultPartName` 리터럴 대체는 Step 2와 동일합니다.

- [ ] **Step 4: `migration_v4_to_v5_test.dart` 정리**

137번 줄의 `<Object>[defaultPartId, 'part', defaultPartName, now, now],`를
`<Object>['old-default-part', 'part', '기본', now, now],`로 바꾸고,
`import 'package:reference_archive_app/models/taxonomy_item.dart';`(24번
줄)를 지웁니다(이 파일에서는 `TaxonomyItem` 클래스 자체를 쓰지 않고
`defaultPartId`/`defaultPartName`만 쓰고 있었습니다 — Step 1 전에
`grep -n "TaxonomyItem" test/data/migration_v4_to_v5_test.dart`로
한 번 더 확인하세요).

- [ ] **Step 5: `reference_importer_saved_ids_test.dart` 정리**

`import 'package:reference_archive_app/models/taxonomy_item.dart';`(17번
줄)를 지웁니다. 네 곳의 `partId: defaultPartId,`를 전부 지웁니다(폴더는
선택적이라 아예 안 넘겨도 됩니다 — `importFromClipboard()`,
`importYoutube('dQw4w9WgXcQ')`처럼 인자 없이 호출).

```dart
    final ImportOutcome outcome = await importer.importFromClipboard();
    ...
    final ImportOutcome outcome = await importer.importFromClipboard();
    ...
    final ImportOutcome outcome = await importer.importYoutube('dQw4w9WgXcQ');
    ...
    final ImportOutcome outcome = await importer.importFromClipboard();
```

- [ ] **Step 6: `reference_importer_hash_test.dart` 정리**

`import 'package:reference_archive_app/models/taxonomy_item.dart';`(16번
줄)를 지웁니다. 세 곳의 `partId: defaultPartId` 인자를 지웁니다.

```dart
    await importer.importFromClipboard();
    ...
    await importer.saveYoutube('dQw4w9WgXcQ');
    ...
    await importer.importFromClipboard();
```

- [ ] **Step 7: `taxonomy_manage_screen_test.dart` 정리**

`group('파트 탭', ...)` 블록 전체(298~412번 줄)를 지웁니다. 파일은
그 앞의 다른 그룹(폴더·카테고리·태그·프로젝트 탭)까지만 남습니다.

- [ ] **Step 8: `part_delete_test.dart` 삭제**

이 파일 전체가 "파트를 지우면 기본 파트로 옮겨진다"는, 이제 존재하지
않는 동작을 테스트합니다. 마지막 그룹(`'다른 분류는 예전 그대로다
(회귀 확인)'`)의 "폴더를 지우면 폴더 없음이 된다" 테스트는
`local_taxonomy_repository_test.dart`가 이미 같은 내용을 다루고 있는지
`grep -n "폴더 없음\|clearFolder\|folderId, isNull" test/repositories/local_taxonomy_repository_test.dart`로
확인한 뒤, 없다면 그 파일로 옮기고, 있다면 그냥 파일을 지웁니다.

```bash
git rm test/repositories/part_delete_test.dart
```

- [ ] **Step 9: `home_parts_test.dart`를 폴더 사이드바 테스트로 재작성**

기존 파일을 지우고 같은 시나리오를 폴더 기준으로 다시 씁니다.

```bash
git rm test/screens/home_parts_test.dart
```

`test/screens/home_folders_sidebar_test.dart`를 새로 만듭니다:

```dart
// 사이드바에서 폴더를 골라 레퍼런스를 나눠 보는 흐름을 확인하는 테스트입니다.
//
// ── 폴더가 다른 분류와 다른 점 (사이드바에 있을 때) ──
// 카테고리·태그는 목록 위에서 잠깐 걸었다 푸는 **조건**이지만, 폴더는
// 사이드바에서 고르는 **지금 보고 있는 자리**에 가깝습니다(2026-09-06
// 이전에는 이 역할을 파트가 맡았습니다 — CLAUDE.md "단계 밖 작업: 파트를
// 없애고 사이드바를 폴더로 바꾸기" 참고). 그래서 다르게 다뤄야 하는
// 곳이 있고, 그 부분을 여기서 확인합니다.
//
//   - 폴더를 고른 채로 새 레퍼런스를 넣으면 **그 폴더에** 들어가야 합니다
//   - "조건 지우기"를 눌러도 **폴더는 유지**돼야 합니다

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/main.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';
import 'package:reference_archive_app/repositories/local_board_repository.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/repositories/local_taxonomy_repository.dart';
import 'package:reference_archive_app/services/app_settings.dart';
import 'package:reference_archive_app/utils/id_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_image_source.dart';
import '../fakes/fake_image_storage.dart';
import '../fakes/fake_youtube_info_source.dart';

void main() {
  late AppDatabase db;
  late LocalReferenceRepository repository;
  late LocalTaxonomyRepository taxonomyRepository;
  late FakeImageSource imageSource;
  late AppSettings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalReferenceRepository(db);
    taxonomyRepository = LocalTaxonomyRepository(db);
    imageSource = FakeImageSource();

    settings = AppSettings();
    await settings.load();
  });

  tearDown(() async {
    await db.close();
  });

  /// 테스트용 화면을 넓게 만듭니다. 사이드바가 늘 펼쳐져 있어야 폴더를 누를 수 있습니다.
  void useWideScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// 테스트용 앱을 만들어 돌려줍니다.
  Widget makeApp() {
    return ReferenceArchiveApp(
      referenceRepository: repository,
      taxonomyRepository: taxonomyRepository,
      boardRepository: LocalBoardRepository(db),
      imageStorage: FakeImageStorage(),
      imageSource: imageSource,
      youtubeInfoSource: FakeYoutubeInfoSource(),
      settings: settings,
    );
  }

  /// 화면을 띄우고 다 그려질 때까지 기다립니다.
  Future<void> openApp(WidgetTester tester) async {
    useWideScreen(tester);
    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();
  }

  /// 폴더를 하나 만들고 그 id를 돌려줍니다.
  Future<String> saveFolder(String name) async {
    final DateTime now = DateTime.now().toUtc();
    final TaxonomyItem item = TaxonomyItem(
      id: newId(),
      kind: TaxonomyKind.folder,
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    await taxonomyRepository.save(item);
    return item.id;
  }

  /// 레퍼런스를 하나 저장합니다.
  Future<void> saveReference({required String title, String? folderId}) async {
    final DateTime now = DateTime.now().toUtc();
    await repository.save(
      ReferenceItem(
        id: newId(),
        type: ReferenceType.image,
        title: title,
        folderId: folderId,
        fileName: 'not-a-real-file.jpg',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  testWidgets('폴더가 하나도 없으면 "전체 레퍼런스"만 보인다', (WidgetTester tester) async {
    await openApp(tester);

    expect(find.text('전체 레퍼런스'), findsOneWidget);
  });

  testWidgets('만든 폴더가 사이드바에 보인다', (WidgetTester tester) async {
    await saveFolder('겨울 프로젝트');

    await openApp(tester);

    expect(find.text('겨울 프로젝트'), findsOneWidget);
  });

  testWidgets('폴더를 고르면 그 폴더 것만 보인다', (WidgetTester tester) async {
    final String winterId = await saveFolder('겨울 프로젝트');

    await saveReference(title: '미분류 사진');
    await saveReference(title: '겨울 사진', folderId: winterId);

    await openApp(tester);

    // 처음에는 "전체"라 둘 다 보입니다.
    expect(find.text('미분류 사진'), findsOneWidget);
    expect(find.text('겨울 사진'), findsOneWidget);

    await tester.tap(find.text('겨울 프로젝트'));
    await tester.pumpAndSettle();

    expect(find.text('겨울 사진'), findsOneWidget);
    expect(find.text('미분류 사진'), findsNothing);
  });

  testWidgets('"전체 레퍼런스"를 고르면 다시 다 보인다', (WidgetTester tester) async {
    final String winterId = await saveFolder('겨울 프로젝트');
    await saveReference(title: '미분류 사진');
    await saveReference(title: '겨울 사진', folderId: winterId);

    await openApp(tester);

    await tester.tap(find.text('겨울 프로젝트'));
    await tester.pumpAndSettle();
    expect(find.text('미분류 사진'), findsNothing);

    await tester.tap(find.text('전체 레퍼런스'));
    await tester.pumpAndSettle();

    expect(find.text('미분류 사진'), findsOneWidget);
    expect(find.text('겨울 사진'), findsOneWidget);
  });

  testWidgets('폴더를 고른 채로 넣으면 그 폴더에 들어간다', (WidgetTester tester) async {
    // ── 이게 이 파일의 핵심입니다 ──
    // "겨울 프로젝트" 폴더를 보면서 사진을 넣었는데 미분류로 들어가면,
    // 방금 넣은 것이 화면에서 곧바로 사라집니다. 사용자는 저장이 안 된 줄 압니다.
    final String winterId = await saveFolder('겨울 프로젝트');

    imageSource.hasClipboardImage = true;

    await openApp(tester);

    await tester.tap(find.text('겨울 프로젝트'));
    await tester.pumpAndSettle();

    // 붙여넣기로 하나 넣습니다.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.length, 1);
    expect(items.first.folderId, winterId);
  });

  testWidgets('"전체"를 보면서 넣으면 미분류로 들어간다', (WidgetTester tester) async {
    // "전체"는 자리가 아니라 보기 방식이라 거기에 넣을 수는 없습니다.
    imageSource.hasClipboardImage = true;

    await openApp(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.length, 1);
    expect(items.first.folderId, isNull);
  });

  testWidgets('폴더를 고른 채로 검색해도 그 폴더 안에서만 찾는다', (WidgetTester tester) async {
    final String winterId = await saveFolder('겨울 프로젝트');
    await saveReference(title: '노을 미분류');
    await saveReference(title: '노을 겨울', folderId: winterId);

    await openApp(tester);

    await tester.tap(find.text('겨울 프로젝트'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '노을');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('노을 겨울'), findsOneWidget);
    expect(find.text('노을 미분류'), findsNothing);
  });

  testWidgets('"조건 지우기"를 눌러도 보고 있던 폴더는 그대로다', (WidgetTester tester) async {
    // 조건을 지웠다고 보고 있던 자리에서 튕겨 나가면 당황스럽습니다.
    final String winterId = await saveFolder('겨울 프로젝트');
    await saveReference(title: '미분류 사진');
    await saveReference(title: '겨울 사진', folderId: winterId);

    await openApp(tester);

    await tester.tap(find.text('겨울 프로젝트'));
    await tester.pumpAndSettle();

    // 검색어를 넣어 "조건 지우기" 버튼이 나오게 합니다.
    await tester.enterText(find.byType(TextField).first, '겨울');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('조건 지우기'));
    await tester.pumpAndSettle();

    // 검색어는 풀렸지만 폴더는 그대로여야 합니다.
    expect(find.text('겨울 사진'), findsOneWidget);
    expect(find.text('미분류 사진'), findsNothing);

    // 검색 입력창도 함께 비워져야 합니다.
    final TextField searchField = tester.widget<TextField>(
      find.byType(TextField).first,
    );
    expect(searchField.controller?.text, isEmpty);
  });

  testWidgets('폴더는 위쪽 필터 줄에 나오지 않는다', (WidgetTester tester) async {
    // 같은 것을 두 군데서 고르면 "어느 쪽이 진짜지?" 하게 됩니다.
    // 폴더는 사이드바에서만 고릅니다.
    await saveFolder('겨울 프로젝트');

    await openApp(tester);

    // 필터 줄의 버튼들은 "카테고리"/"태그"처럼 종류 이름으로 뜹니다.
    // 폴더 버튼이 있으면 안 됩니다.
    expect(
      find.widgetWithText(OutlinedButton, TaxonomyKind.folder.displayName),
      findsNothing,
    );
  });
}
```

- [ ] **Step 10: 남은 comment-only 파일 정리**

`test/screens/app_shell_test.dart:176`의 주석 `// 무드보드는 파트
목록과 성격이 달라서 한 칸 띄워 따로 뒀습니다.`를 `// 무드보드는 폴더
목록과 성격이 달라서 한 칸 띄워 따로 뒀습니다.`로 바꿉니다.

`test/repositories/local_taxonomy_repository_test.dart:95-96`의 주석을
아래로 바꿉니다(더 이상 기본 파트가 안 생기므로 "기본 파트가 하나
들어있어서" 부분이 사실이 아니게 됩니다):

```dart
    // 폴더만 골라서 셉니다. 다른 종류(카테고리 등)를 만든 적이 있다면
    // 그것까지 딸려올 수 있어서 kind로 걸러서 셉니다.
```

`test/screens/reference_detail_screen_test.dart:234`의 주석
`// (실제로 파트 항목이 맨 위에 추가되면서 한 번 깨졌습니다)`는 역사적
사실 기록이라 그대로 둬도 무방하지만, 헷갈리지 않도록
`// (실제로 분류 항목 하나가 맨 위에 추가되면서 한 번 깨졌습니다)`로
다듬습니다.

- [ ] **Step 11: 커밋**

```bash
git add test/
git commit -m "파트 관련 테스트를 정리하고 폴더 기준으로 다시 쓴다

- migration_v1_to_v2/v2_to_v3/v3_to_v4/v4_to_v5_test.dart: 이제 없는
  defaultPartId/defaultPartName/item.partId 참조를 지운다
- reference_importer_saved_ids/hash_test.dart: partId 인자를 지운다
- taxonomy_manage_screen_test.dart: 파트 탭 그룹을 지운다
- part_delete_test.dart: 삭제 (파트를 지우면 기본 파트로 옮기는 동작
  자체가 없어졌다)
- home_parts_test.dart → home_folders_sidebar_test.dart: 같은 시나리오를
  폴더 기준으로 재작성

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 12: 전체 회귀 확인 + 문서 정리

**Files:**
- Modify: `CLAUDE.md`
- Modify: `update.md`

**Interfaces:**
- Consumes: Task 1~11 전체
- Produces: 없음 (마무리 Task)

- [ ] **Step 1: 전체 분석·테스트**

Run: `flutter analyze`
Expected: 0 issues.

Run: `flutter test`
Expected: 전부 PASS. 실패하는 테스트가 있으면 Task 11에서 놓친 partId/
TaxonomyKind.part 참조가 남아있는지 `grep -rn "partId\|TaxonomyKind\.part\|defaultPartId\|defaultPartName" lib test`로
다시 확인합니다(이 시점엔 아무 결과도 없어야 합니다).

- [ ] **Step 2: `CLAUDE.md`에 이번 작업 기록**

"화면 구조" 절의 사이드바 표(②)와 "의뢰인이 정한 것" 목록 중 파트 관련
설명(파트는 사용자가 직접 추가·삭제, `filterableTaxonomyKinds` 등)을
찾아 "폴더가 그 자리를 대신한다"는 사실로 갱신하고, "단계 밖 작업" 목록
끝에 아래 절을 추가합니다(다른 "단계 밖 작업" 항목들과 같은 형식):

```markdown
### 단계 밖 작업: 파트를 없애고 사이드바를 폴더로 바꾸기 ✅ 완료 (별도 PR — "remove-part-sidebar-folders")

의뢰인이 분류 관리 화면에서 폴더를 만들었는데 메인 화면 어디에도 안
보인다고 보고했습니다. 확인해보니 버그가 아니라 "폴더는 사이드바가
아니라 위쪽 필터줄에 있다"는 것 자체를 몰랐던 것이었습니다. 스크린샷을
보여준 뒤, 의뢰인이 "사이드바의 파트 자리가 폴더랑 겹치니 파트를
없애고 그 자리를 폴더로 바꾸자"고 정리했습니다.

**왜 겹쳤나**: `References` 테이블에는 이미 `folderId`와 `partId`가
따로 있었습니다. 폴더는 위쪽 필터줄의 조건, 파트는 사이드바의 "지금
보고 있는 자리"로 성격이 나뉘어 있었는데, 사이드바 파트 아이콘부터가
이미 폴더 모양(`folder_copy_outlined`)이라 사용자 입장에서 구분할
이유가 없었습니다.

**확정된 동작:**

- 왼쪽 사이드바의 파트 목록 자리가 폴더 목록으로 바뀌었습니다.
  `References.folderId` 하나가 "폴더 소속"과 "사이드바에서 지금 보고
  있는 자리" 역할을 둘 다 맡습니다.
- 목록 위 필터줄의 "폴더" 드롭다운은 없어졌습니다(사이드바로 이사).
  카테고리·태그·프로젝트만 남습니다.
- 사이드바에서 특정 폴더를 보고 있을 때 새 레퍼런스를 추가하면 그
  폴더로 자동 배정됩니다(예전 파트와 같은 규칙).
- 무드보드에 파일을 끌어다 놓거나 붙여넣으면, 그 판이 폴더에 연결돼
  있으면(PR #59) 그 폴더로, 아니면 폴더 없음(미분류)으로 들어갑니다
  (예전 "무조건 기본 파트" 규칙의 대체 — 오히려 쓸모가 늘었습니다).
- 분류 관리 화면의 탭이 5개(폴더/카테고리/태그/프로젝트/파트)에서
  4개로 줄었습니다. "기본 파트는 지울 수 없다"는 보호 로직도 없어졌습니다
  — 폴더는 지워도 그냥 "폴더 없음"이 되는, 다른 분류와 같은 취급입니다.

**어떻게 되어 있나 (나중에 고칠 때 볼 곳):**

- **저장 구조 v6.** `References.partId` 칼럼을 `Migrator.dropColumn`으로
  지우고, `taxonomy_items`에서 `kind='part'` 행을 전부 지웁니다(소프트
  삭제 아님 — 개념 자체가 없어졌으므로). `_upgradeToVersion2`(v1→v2,
  파트를 처음 만들던 단계)는 **역사 그대로 손대지 않았습니다** — v1
  사용자는 v2에서 파트 칼럼·기본 파트가 잠깐 생겼다가 v6에서 바로
  지워지는 경로를 지나갑니다. 마이그레이션 조건은 PR #59의
  `from >= 3 && from < 5`같은 특수 조건이 필요 없어서 그냥
  `if (from < 6)`로 뒀습니다 — v6은 "이미 있는 칼럼을 지우는" 마이그레이션이라
  `createTable`이 현재 시점 정의를 쓰는 문제(칼럼을 새로 만들 때만
  생기는 문제)가 생기지 않기 때문입니다.
- **`ReferenceQuery.folderId`가 예전 `partId`의 역할을 이어받았습니다.**
  `hasAnyFilter`에서 안 세고, `clearAll()`("조건 지우기")로도 안
  풀립니다. `lib/models/reference_query.dart` 참고.
- **`ReferenceImporter`의 공개 메서드 전부가 `required String partId`
  대신 `String? folderId`(선택적)를 받습니다.** 폴더는 파트와 달리
  없어도(null) 정상 상태이기 때문입니다.
- **`lib/widgets/app_sidebar.dart`**가 `parts`/`selectedPartId`/
  `onSelectPart` 대신 `folders`/`selectedFolderId`/`onSelectFolder`를
  받습니다. `home_screen.dart`의 `_selectFolder`/`_folderIdForNewItems`가
  이걸 잇습니다.
- **저장 구조는 이번이 전부입니다.** 카테고리·태그·프로젝트는 손대지
  않았습니다.
```

- [ ] **Step 3: `update.md`에 PR 항목 추가**

파일 맨 위(가장 최근 PR)에 아래 절을 추가합니다.

```markdown
## PR — 파트(Part)를 없애고 사이드바를 폴더로 바꾼다

**무엇을**: 왼쪽 사이드바의 "파트" 목록 자리를 "폴더" 목록으로 바꾸고,
파트라는 분류 체계 자체를 앱에서 완전히 지웠습니다.

**왜**: 의뢰인이 분류 관리 화면에서 폴더를 만들었는데 메인 화면
어디에도 안 보인다고 보고했습니다. 확인해보니 버그가 아니라 "폴더는
사이드바가 아니라 위쪽 필터줄에 있다"는 것 자체를 몰랐던 것이었고,
실제로 코드를 보니 폴더와 파트가 이미 비슷한 역할(레퍼런스를 큰
갈래로 나누기)을 서로 다른 자리에서 하고 있었습니다. 사이드바 파트
아이콘부터가 이미 폴더 모양이라 사용자가 구분할 이유가 없었습니다.

**어떻게**:
- `References.folderId` 칼럼 하나가 "폴더 소속"과 "사이드바에서 지금
  보고 있는 자리" 역할을 둘 다 맡게 됐습니다.
- 저장 구조 v6: `References.partId` 칼럼 삭제, `taxonomy_items`의
  `kind='part'` 행 삭제. 기존 `_upgradeToVersion2`(파트를 처음 만들던
  단계)는 역사 그대로 두고, v6이 그 결과물을 지우는 방식입니다.
- 사이드바(`app_sidebar.dart`)가 폴더 목록을 보여줍니다. 폴더를 고르면
  그 폴더로 좁혀 보이고, 그 상태로 새 레퍼런스를 넣으면 자동으로
  그 폴더에 들어갑니다(예전 파트와 같은 규칙).
- 목록 위 필터줄의 "폴더" 드롭다운은 없어졌습니다(사이드바로 이사).
- 무드보드에 파일을 끌어다 놓거나 붙여넣으면, 그 판이 폴더에
  연결돼 있으면(PR #59) 그 폴더로 들어갑니다.
- 분류 관리 화면 탭이 5개에서 4개로 줄었습니다.

**나중에 이 부분을 고치려면**:

| 무엇을 고치고 싶은가 | 어디를 보면 되는가 |
|---|---|
| 사이드바 폴더 목록의 생김새 | `lib/widgets/app_sidebar.dart`의 `_buildFolderList` |
| 새 레퍼런스가 어느 폴더로 자동 배정되는지 | `lib/screens/home_screen.dart`의 `_folderIdForNewItems` |
| 무드보드 드롭 시 폴더 배정 규칙 | `lib/screens/board_screen.dart`의 `_onExternalFilesDropped`/`_onPasteFromClipboard` |
| "조건 지우기"를 눌러도 폴더가 안 풀리는 이유 | `lib/models/reference_query.dart`의 `clearAll()`/`hasAnyFilter` |
| 마이그레이션 세부 사항 | `lib/data/app_database.dart`의 `_upgradeToVersion6` |

**어떻게 테스트했나**: `flutter analyze` 0 issues, `flutter test` 전체
통과(신규 `migration_v5_to_v6_test.dart` 6개 포함). 실제 앱은
`flutter run -d windows`로 의뢰인이 직접 사이드바 폴더 목록·자동
배정·무드보드 지름길 버튼·분류 관리 탭 개수를 확인해야 합니다.

**한계**: 폴더 중첩(하위 폴더)은 없습니다. 계속 평평한 목록입니다.
```

- [ ] **Step 4: 커밋**

```bash
git add CLAUDE.md update.md
git commit -m "CLAUDE.md와 update.md에 파트 제거 작업을 정리한다

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

- [ ] **Step 5: 푸시하고 PR 열기**

```bash
git push -u origin remove-part-sidebar-folders
```

`gh pr create`로 Summary + Test plan + "나중에 여기를 고치려면 어디를
보면 되는지" 표(위 update.md 내용 재사용) + 새 개념 설명(이번 PR에는
새로운 프로그래밍 개념이 없으므로 생략) 포함해 PR을 엽니다. **의뢰인의
명시적 "병합해줘" 전까지 병합하지 않고 대기합니다.**

---

## Self-Review 메모

- **스펙 커버리지**: 스펙의 "포함" 6개 항목 전부 Task로 매핑됨(1↔Task1,
  2↔Task4, 3↔Task5, 4↔Task6/9/10, 5↔Task4, 6↔Task8). "제거 범위"의
  파일별 항목 전부 Task 1~10에 반영됨. "마이그레이션 테스트 계획"의
  5가지 확인 전부 Task 10에 반영됨(+ "두 번 열어도" 하나 추가).
- **플레이스홀더 스캔**: "TODO"/"나중에"/"적절히 처리" 부류 없음. 모든
  코드 스텝에 실제 코드가 있음.
- **타입 일관성**: `ReferenceImporter`의 `folderId` 매개변수 이름과
  타입(`String?`)이 Task 3(정의)과 Task 4/8(호출부) 전부에서 동일함.
  `AppSidebar`의 `folders`/`selectedFolderId`/`onSelectFolder`도
  Task 4의 정의와 호출부(`_buildSidebar`)에서 동일함.
- **알려진 리스크**: `Migrator.dropColumn`이 이 환경의 SQLite 버전에서
  실제로 되는지는 Task 10을 실행해봐야 확정된다 — 안 되면 스펙 문서에
  적어둔 대안(`alterTable`로 테이블 재생성)으로 Task 9 Step 3을 다시
  쓴다.
