# 폴더 중첩(하위 폴더) — 설계

**작성일**: 2026-09-11
**분류**: 아키텍처(데이터 모델에 부모-자식 관계 추가 + 사이드바/분류 관리
화면 구조 변경) — `superpowers:brainstorming` 절차를 따름
**선행 작업**: PR #60("파트를 없애고 사이드바를 폴더로 바꾼다")이 main에
병합되어 있어야 합니다. 이 작업은 그 위에서 진행합니다.

## 배경

PR #60에서 사이드바를 "파트" 목록 대신 "폴더" 목록으로 바꾸면서, 알려진
한계로 다음을 남겨뒀습니다(`update.md` PR #60 "한계").

> 폴더 중첩(하위 폴더)은 없습니다. 계속 평평한 목록입니다.

의뢰인이 이제 이 한계를 풀어달라고 요청했습니다 — 폴더 안에 폴더를 만들 수
있게(예: "인물" 폴더 안에 "얼굴", "포즈" 하위 폴더).

## 범위

**포함**
1. 폴더(`TaxonomyKind.folder`)에 부모-자식 관계 추가. 깊이 **무제한**.
2. 사이드바에서 상위 폴더를 고르면 **그 폴더 자신 + 모든 하위 폴더**의
   레퍼런스를 함께 보여줍니다. 이 규칙은 `local_reference_repository.dart`의
   `getAll()` 한 곳에서 적용되므로, 폴더 필터를 쓰는 모든 화면(메인 목록,
   무드보드에 기존 레퍼런스를 고르는 화면 등)에 자동으로 적용됩니다.
3. 하위 폴더가 있는 폴더를 지우면 하위 전체(손자 포함)도 함께 소프트
   삭제되고, 그 안의 레퍼런스는 전부 "폴더 없음"이 됩니다. 삭제 확인창에
   영향받는 하위 폴더 개수를 명시합니다.
4. 폴더 이름 중복 금지 범위를 **전체 → 같은 부모 밑**으로 좁힙니다(다른
   가지에서는 같은 이름을 쓸 수 있게).
5. 사이드바에 폴더를 **트리**로(들여쓰기 + 펼치기/접기) 보여주고, 폴더
   줄의 팝업 메뉴로 "하위 폴더 만들기 / 이름 바꾸기 / 삭제"를 제공하고,
   폴더 줄을 **드래그해서 다른 폴더 위에 놓으면** 그 폴더의 하위로
   옮겨집니다.
6. 분류 관리 화면(설정 안)의 폴더 탭도 트리(들여쓰기)로 보여주고, 새로
   만들기/이름 바꾸기 대화상자에 폴더일 때만 "상위 폴더" 선택 칸을
   추가합니다(드래그가 아직 낯선 사용자를 위한 대안 경로).
7. 레퍼런스 편집 화면의 폴더 선택 칸은 깊이만큼 들여쓴 평평한 목록으로
   보여줍니다(모달 안이라 접고 펼 필요까지는 없다고 판단).

**포함하지 않음 (이번 범위 밖)**
- 무드보드의 새 레퍼런스 자동 배정(`_folderIdForNewItems`)과 무드보드-폴더
  연결(`board.folderId`)은 지금처럼 **정확히 그 폴더 하나**만 가리킵니다.
  하위로 확장하지 않습니다 — "이 판은 이 폴더 전용"이라는 뜻이 흐려지지
  않게 하려는 것입니다.
- 폴더별 무드보드 목록(`_openFolderBoards`/`BoardListScreen.filterFolderId`)도
  지금처럼 정확 일치 그대로 둡니다.
- 폴더 순서를 사용자가 직접 정렬하는 것 — 지금처럼 이름 가나다순
  그대로입니다(같은 부모 밑 형제끼리도 가나다순).
- 사이드바 펼침/접힘 상태를 앱 재시작 후에도 기억하는 것 — 이번엔 화면을
  벗어나면(=StatefulWidget이 다시 만들어지면) 초기화됩니다.
- 카테고리·태그·프로젝트에 중첩을 넣는 것. 폴더만 대상입니다.

## 데이터 모델 변경

**저장 구조 v6 → v7**

- `lib/data/tables.dart`의 `TaxonomyItems`에 칼럼 하나를 추가합니다.

  ```dart
  /// 상위 폴더의 id입니다. null이면 최상위(하위 폴더가 아님)입니다.
  /// 폴더(kind='folder')만 씁니다 — 카테고리·태그·프로젝트는 항상 null입니다.
  TextColumn get parentId => text().nullable()();
  ```

- `lib/data/app_database.dart`: `schemaVersion`을 7로 올리고
  `_upgradeToVersion7(Migrator m)`을 추가해 `m.addColumn(taxonomyItems,
  taxonomyItems.parentId)`만 실행합니다. 기존 행은 전부 `parentId = null`이
  되어 자동으로 최상위 폴더가 되므로 데이터 손실이 없습니다. PR #60과
  달리 **칼럼을 새로 만드는 것**이라 `_upgradeToVersion4`가 겪었던
  "createTable이 현재 시점 정의를 쓰는" 함정을 다시 점검해야 합니다 —
  `_upgradeToVersion3`(폴더가 처음 생긴 단계, `createTable` 사용)가 지금
  시점의 `TaxonomyItems` 정의(=parentId 포함)를 쓰게 되는지 반드시
  마이그레이션 테스트로 확인합니다. 만약 그렇다면 PR #59가 했던 것처럼
  `_upgradeToVersion3`도 원시 SQL로 다시 써야 합니다.
- `lib/models/taxonomy_item.dart`: `parentId` 필드 추가. `copyWith`는
  이름/수정시각만 다루던 지금 방식으로는 "부모를 null로 되돌리기"를 표현할
  수 없으므로(다른 모델들이 겪은 것과 같은 문제), 부모를 바꾸는 용도의
  전용 메서드를 따로 둡니다(아래 "저장소 동작" 참고).

## 저장소(Repository) 동작

**순환 참조 방지**

폴더 A를 폴더 B의 하위로 옮기려 할 때:
- B가 A 자신이면 거부.
- B가 A의 하위(자식, 손자, …)이면 거부 — A의 조상 자리에 A의 자손을 놓을
  수 없습니다.

`lib/repositories/taxonomy_repository.dart`에 전용 메서드를 추가합니다.

```dart
/// 폴더의 상위 폴더를 바꿉니다. [newParentId]가 null이면 최상위로 옮깁니다.
///
/// 순환이 되는 이동(자기 자신이나 자기 하위를 상위로 지정)은
/// CycleException을 던지고 아무것도 바꾸지 않습니다.
Future<void> moveFolder(String id, String? newParentId);
```

`local_taxonomy_repository.dart` 구현은 전체 폴더 목록을 메모리에 올려
`newParentId`부터 `parentId` 체인을 따라 올라가며 `id`가 나오는지
검사합니다(폴더 개수가 개인용 앱 규모라 전부 불러와도 비쌀 일이 없습니다).

**삭제 시 하위 폴더 연쇄 처리**

`delete(id)`가 폴더를 지울 때는 먼저 `id`의 모든 하위(자식, 손자, …) id를
모읍니다. 그 다음 지금 로직(레퍼런스 폴더 없음 처리, 소프트 삭제)을 **이
id 집합 전체**에 대해 적용합니다. 카테고리·태그·프로젝트는 하위 개념이
없으니 지금처럼 자기 자신만 처리합니다.

`taxonomy_manage_screen.dart`의 삭제 확인 대화상자(`_confirmDelete`)는
폴더일 때 하위 폴더 개수도 함께 보여주도록 문구를 바꿉니다. 예: `"인물"
폴더를 지웁니다. 하위 폴더 2개도 함께 지워집니다.`

**이름 중복 검사 범위**

`existsWithName`에 `parentId`를 추가로 받습니다.

```dart
Future<bool> existsWithName(
  TaxonomyKind kind,
  String name, {
  String? excludeId,
  String? parentId, // 폴더일 때만 의미 있음. 그 외 kind는 항상 null.
});
```

폴더는 "같은 `parentId`를 가진 형제들" 안에서만 이름이 겹치는지
확인합니다. 카테고리·태그·프로젝트는 `parentId`가 항상 null이라 지금과
동작이 같습니다(전체 안에서 하나만).

## 레퍼런스 조회 범위 확장

**새 순수 함수**: `lib/utils/folder_tree.dart`

```dart
/// [rootId]를 포함해, 그 아래 모든 하위 폴더의 id를 모아 돌려줍니다.
/// (이 프로젝트의 board_layout.dart처럼 앱을 안 띄우고 테스트할 수 있는
/// 순수 함수로 둡니다)
Set<String> collectFolderAndDescendantIds(
  String rootId,
  List<TaxonomyItem> allFolders,
);
```

`local_reference_repository.dart`의 `getAll()`에서 `query.folderId != null`일
때, 지금의 `t.folderId.equals(folderId)` 대신 **먼저 살아있는 폴더 전체를
불러와** `collectFolderAndDescendantIds`로 id 집합을 구하고
`t.folderId.isIn(idSet)`으로 거릅니다.

`ReferenceQuery`나 이걸 쓰는 화면 코드(`home_screen.dart`,
`board_screen.dart` 등)는 **바뀌지 않습니다** — 폴더 필터의 의미만
저장소 한 곳에서 넓어지고, 쓰는 쪽은 지금처럼 "폴더 하나의 id"만 넘기면
됩니다.

## 사이드바 (`app_sidebar.dart`)

- `_buildFolderList`가 평평한 `for` 루프 대신, `folders`(부모-자식이 섞인
  평평한 리스트)를 받아 트리로 구성해서 그립니다. 화면 쪽 위젯은
  펼침/접힘 상태를 `Set<String> _expandedFolderIds`로 들고 있습니다(이
  `StatefulWidget`의 로컬 상태 — 화면을 나가면 초기화됨, 위 "포함하지
  않음" 참고).
- 자식이 있는 폴더에만 펼치기/접기 화살표가 붙습니다. 깊이는
  `12px * depth`만큼 왼쪽 여백으로 표현합니다.
- 폴더 줄 오른쪽에 `board_list_screen.dart`의 보드 줄과 같은 패턴으로
  **`PopupMenuButton`**("하위 폴더 만들기" / "이름 바꾸기" / "삭제")을
  둡니다. (당초 "우클릭 메뉴"로 이야기했지만, 이 앱에 실제 `onSecondaryTap`
  우클릭 패턴이 없고 `board_list_screen.dart`가 이미 같은 문제를
  `PopupMenuButton`으로 풀어뒀어서 그걸 따릅니다 — 데스크톱·모바일 모두
  같은 코드로 동작합니다.)
- 폴더 줄을 `Draggable<String>`(폴더 id)로, 폴더 줄 영역을
  `DragTarget<String>`으로 감쌉니다. 드롭되면 `AppSidebar`가
  `onMoveFolder(draggedId, targetParentId)` 콜백을 부르고,
  `home_screen.dart`가 `taxonomyRepository.moveFolder(...)`를 호출합니다.
  실패(순환)하면 스낵바로 "폴더를 그 위치로 옮길 수 없습니다"를 보여줍니다.
  "전체 레퍼런스" 줄이나 목록의 빈 공간도 `DragTarget<String>`으로 감싸
  거기 놓으면 `newParentId = null`(최상위로)이 됩니다.

## 분류 관리 화면 (`taxonomy_manage_screen.dart`)

- `_buildList(TaxonomyKind.folder)`만 트리로 그립니다(사이드바와 같은
  들여쓰기 방식). 다른 세 탭은 지금 그대로 평평한 `ListView.builder`.
- `create_taxonomy_dialog.dart`/`rename_taxonomy_dialog.dart`에 폴더
  종류일 때만 "상위 폴더" 드롭다운을 추가합니다. 목록에서 **자기 자신과
  자기 하위**는 골라도 될 후보에서 아예 뺍니다(순환을 UI에서부터 막아
  저장소의 방어 로직과 이중으로 보호).

## 레퍼런스 편집 화면 폴더 선택 칸

`taxonomy_single_field.dart`(폴더 고르는 칸)는 트리 인터랙션 없이, 깊이만큼
공백을 붙인 이름으로 평평하게 보여줍니다. 예:

```
전체 레퍼런스
인물
　얼굴
　포즈
배경
```

## 마이그레이션 테스트 계획

- `test/data/migration_v6_to_v7_test.dart`(신규): v6 상태에서 앱을 열고,
  기존 폴더가 전부 `parentId == null`로 남아있는지 확인.
- v1→v7, v3→v7처럼 여러 단계를 건너뛰는 경로도 최소 한 개씩 확인해,
  `_upgradeToVersion3`이 현재 시점 정의(=parentId 포함)를 쓰게 되는
  문제가 있는지 검증(위 "데이터 모델 변경" 절 참고).

## 테스트 전략 (전체)

- `lib/utils/folder_tree.dart`의 `collectFolderAndDescendantIds`는 순수
  함수라 앱을 안 띄우고 단위 테스트로 다양한 트리 모양(깊이 3단계,
  형제만 있는 경우, 자기 자신만 있는 경우)을 확인합니다.
- `LocalTaxonomyRepository.moveFolder`의 순환 방지: 자기 자신으로 이동,
  손자를 부모로 지정하는 두 경우를 테스트.
- `LocalTaxonomyRepository.delete`의 연쇄 삭제: 하위 폴더 2단계 + 각
  폴더의 레퍼런스가 전부 "폴더 없음"이 되는지 테스트.
- `existsWithName`의 형제 범위 검사: 같은 이름이 다른 부모 밑에서는
  허용되고 같은 부모 밑에서는 막히는지 테스트.
- `LocalReferenceRepository.getAll`의 하위 포함 조회: 상위 폴더를 골랐을
  때 하위 폴더 레퍼런스까지 나오는지, "폴더 없음"과는 안 섞이는지 테스트.
- `app_sidebar_test.dart`: 트리 들여쓰기·펼치기/접기 토글·드래그로 옮기기
  콜백 호출을 위젯 테스트로 확인(`tester.startGesture` + `moveBy` +
  `pump` 방식 — `board_screen_test.dart`에서 쓰던 것과 동일. 이유는
  CLAUDE.md "끄는 도중의 상태 변화" 절 참고).
- `flutter analyze`와 `flutter test` 전체 통과, 실제 `flutter run -d
  windows`로 의뢰인이 트리·드래그·삭제 확인창을 눈으로 확인.

## 알려진 한계 (이번 범위에서 의도적으로 남기는 것)

- 폴더를 사용자가 직접 원하는 순서로 정렬할 수 없습니다(항상 가나다순).
- 사이드바 펼침/접힘 상태가 앱을 재시작하면 초기화됩니다.
- 무드보드의 폴더 연결·자동 배정은 하위 폴더로 확장되지 않습니다(정확히
  그 폴더 하나).
