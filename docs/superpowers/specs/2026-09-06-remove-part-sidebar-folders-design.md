# 파트를 없애고 사이드바를 폴더로 바꾸기 — 설계

**작성일**: 2026-09-06
**분류**: 아키텍처(핵심 분류 체계 제거 + 사이드바 구조 변경) — `superpowers:brainstorming` 절차를 따름
**선행 작업**: PR #59("무드보드를 폴더에 연결한다")를 이 설계 확정 전에 main에 병합했습니다.
이번 작업은 그 위에서 진행합니다.

## 배경

의뢰인이 분류 관리 화면에서 폴더("aa")를 만들었는데 메인 화면 어디에도 안
보인다고 보고했습니다. 확인해보니 버그가 아니었습니다 — **폴더는 원래부터
사이드바가 아니라 목록 위쪽 필터줄에 있었고**, 의뢰인은 사이드바의 "파트"
목록 자리(무드보드 버튼 바로 아래)에 폴더가 나타날 거라 기대하고 있었습니다.

스크린샷으로 실제 화면을 보여준 뒤, 의뢰인이 정리한 진짜 요청은 이렇습니다.

> "무드보드 버튼 아래 있는 파트 부분이 폴더랑 비슷한 결로 겹쳐서 필요가
> 없어, 저 부분을 폴더로 바꾸고 파트는 지우자."

## 왜 "겹친다"고 느꼈나 (설계의 핵심 통찰)

코드를 읽어보니 `References` 테이블에는 이미 `folderId`와 `partId`가
**따로** 있었습니다. 성격도 이미 이렇게 나뉘어 있었습니다.

| | 폴더 (`folderId`) | 파트 (`partId`) |
|---|---|---|
| 자리 | 목록 위 필터줄 | 왼쪽 사이드바 |
| 성격 | 잠깐 거는 **조건** (`ReferenceQuery.folderId`, `clearAll()`로 풀림) | 지금 보고 있는 **자리** (`ReferenceQuery.partId`, `clearAll()`로도 안 풀림) |
| 없을 때 | "폴더 없음(미분류)" — 정상 상태 | 없을 수 없음 — 반드시 "기본 파트"로 들어감 |
| 사이드바 아이콘 | (없음, 위쪽 필터줄에만 있었음) | `Icons.folder_copy_outlined` (**이미 폴더 모양 아이콘**) |

즉 두 개념이 실제로 겹치는 게 아니라, **파트가 "사이드바 자리" 역할을,
폴더가 "이 프로젝트 묶음" 역할을 나눠 맡고 있었는데 둘 다 결국 "레퍼런스를
큰 갈래로 나눈다"는 같은 일**을 하고 있었습니다. 아이콘까지 폴더 모양이라
사용자 입장에서 구분할 이유가 없었던 것이 당연합니다.

이번 작업은 **이 두 역할을 폴더 하나로 합치는 일**입니다. 폴더가 "사이드바
자리" 역할까지 겸하게 되고, 파트라는 별도 개념은 사라집니다.

## 범위

**포함**
1. `References.folderId`가 기존 역할(폴더 소속)과 파트의 옛 역할(사이드바
   "지금 보고 있는 자리")을 **둘 다** 맡습니다.
2. 왼쪽 사이드바의 파트 목록 자리가 **폴더 목록**으로 바뀝니다.
3. 목록 위 필터줄의 "폴더" 드롭다운은 없어집니다 (사이드바로 이사했으므로
   같은 것을 두 군데서 고르지 않습니다 — 기존에 파트를 필터줄에 안 넣은
   것과 같은 원칙).
4. 파트(`TaxonomyKind.part`) 관련 데이터·코드·화면을 전부 지웁니다
   (아래 "제거 범위" 참고).
5. 사이드바에서 특정 폴더를 보고 있을 때 새 레퍼런스를 추가하면 **그
   폴더로 자동 배정**됩니다 (파트가 하던 것과 같은 규칙).
6. 무드보드에 외부 파일을 끌어다 놓거나 붙여넣을 때: **그 판이 폴더에
   연결돼 있으면 그 폴더로, 아니면 폴더 없음(미분류)으로** 새 레퍼런스가
   들어갑니다 (기존 "기본 파트로 들어간다" 규칙의 대체).

**포함하지 않음 (이번 범위 밖)**
- 폴더에 색상·아이콘 등 새 꾸밈 요소를 추가하는 것. 이번은 순수하게
  "파트 자리를 폴더로 교체"하는 작업입니다.
- 태그·카테고리·프로젝트 분류 체계는 손대지 않습니다 — 폴더는 전체 공용
  그대로, 태그도 전체 공용 그대로입니다 (PR #59에서 이미 확정한 원칙).
- 폴더에 하위 폴더(중첩 구조)를 만드는 것. 지금처럼 평평한 목록입니다.

## 제거 범위 (파트 관련)

**데이터베이스 (schemaVersion 5 → 6)**
- `References.partId` 칼럼을 `Migrator.dropColumn`으로 지웁니다.
  drift 2.34.3의 `dropColumn`은 SQLite 3.35.0 이상을 요구합니다 — 이
  프로젝트가 쓰는 `sqlite3_flutter_libs`가 훨씬 최신 SQLite를 번들하므로
  될 것으로 보이지만, **마이그레이션 테스트에서 실제로 확인합니다**
  (안 되면 대안: `Migrator.alterTable`로 테이블을 다시 만드는 방식 —
  drift 문서가 dropColumn 대체 수단으로 안내하는 방법).
- `taxonomy_items`에서 `kind = 'part'`인 행을 전부 지웁니다(기본 파트
  포함). 소프트 삭제가 아니라 **진짜로 지웁니다** — 파트 개념 자체가
  없어지므로 휴지통 같은 되돌리기 대상이 아닙니다.
- **마이그레이션 조건은 `from >= 1 && from < 6`이 아니라 그냥
  `from < 6`으로 둡니다.** PR #59 때와 달리 이번엔 "역사적으로 존재하지
  않던 칼럼을 새로 만드는" 게 아니라 "이미 있는 칼럼을 지우는" 것이라,
  `createTable`이 현재 시점 정의를 쓰는 문제(그 버그의 원인)가 재현되지
  않습니다. 다만 **v1에서 v6로 곧장 건너뛰는 경우를 테스트로 반드시
  확인**해서 이 판단이 맞는지 검증합니다.

**모델·enum**
- `lib/models/enums.dart`: `TaxonomyKind.part` 값 삭제.
- `lib/models/taxonomy_item.dart`: `defaultPartId`/`defaultPartName` 상수 삭제.
- `lib/models/reference_item.dart`: `partId` 필드, 관련 `copyWith` 인자 삭제.
- `lib/models/reference_query.dart`: `partId` 필드 삭제. `folderId`의
  설명 주석을 "지금 보고 있는 자리 역할도 겸한다"로 갱신. `hasAnyFilter`/
  `clearFilter`/`clearAll`에서 지금 `partId`가 받던 특별 취급을
  `folderId`가 그대로 이어받습니다 (아래 "ReferenceQuery" 절 참고).

**저장소**
- `lib/repositories/local_reference_repository.dart`: `partId`로 거르던
  where절 삭제. `_toModel`/저장 로직에서 `partId` 매핑 삭제.
- `lib/repositories/local_taxonomy_repository.dart`의 `delete()`: 파트를
  기본 파트로 옮기던 특수 분기 전체 삭제. `defaultPartId` 보호 로직도
  삭제 — 폴더는 지워도 그냥 "폴더 없음"이 되면 됩니다(카테고리·태그·
  프로젝트와 똑같은 취급).

**화면·위젯**
- `lib/widgets/app_sidebar.dart`: `parts`/`selectedPartId`/`onSelectPart`
  → `folders`/`selectedFolderId`/`onSelectFolder`. `_buildPartList` →
  `_buildFolderList`(내용은 거의 동일, 이름표만 교체).
- `lib/screens/home_screen.dart`: `_selectedPartId`/`_selectPart`/
  `_partIdForNewItems` → `_selectedFolderId`/`_selectFolder`/
  `_folderIdForNewItems`. `_selectFolder(null)`은 지금 `_selectPart(null)`이
  하듯 `_query.clearFilter(TaxonomyKind.folder)`를 부릅니다.
- `lib/widgets/reference_filter_bar.dart`: `filterableTaxonomyKinds`에서
  `folder`도 제외합니다(지금 `part`를 빼는 것과 같은 자리). 카테고리·
  태그·프로젝트 셋만 남습니다. `onOpenFolderBoards`/폴더 무드보드 버튼은
  **그대로 둡니다** — `query.folderId`만 보고 뜨는 버튼이라 값의 출처가
  드롭다운에서 사이드바로 바뀌어도 조건은 똑같습니다.
- `lib/screens/taxonomy_manage_screen.dart`: 탭 목록이
  `TaxonomyKind.values`를 그대로 쓰므로 **enum에서 `part`를 지우는 것만으로
  탭 자체가 자동으로 줄어듭니다.** "기본 파트는 지울 수 없다" 관련 코드
  (`isDefaultPart`, 잠긴 삭제 버튼, 그 툴팁)만 별도로 지웁니다.
- `lib/widgets/reference_detail_taxonomy_fields.dart`: 파트 칸 삭제(폴더·
  카테고리·태그·프로젝트 네 칸만 남음).
- `lib/screens/reference_taxonomy_edit_controller.dart`: `partId` 상태·
  `setPartId`류 메서드 삭제, `handleCreated`의 `switch`에서 `part` 분기 삭제.
- **`lib/services/reference_importer.dart`**: 생각보다 범위가 넓습니다.
  `partId`가 `ReferenceImporter`의 공개 메서드 전부에 **필수(non-nullable)
  매개변수**로 퍼져 있습니다 — `importFromFilePicker`, `importFromClipboard`,
  `importYoutube`, `saveYoutube`, `_saveOneFile`, `importFromDrop` 전부
  `required String partId`를 받아 새로 만드는 `ReferenceItem`에 그대로
  넣어줍니다. 이걸 전부 **`String? folderId`(선택적)**로 바꿉니다 — 파트와
  달리 폴더는 없어도(null) 정상 상태이기 때문입니다.
- **`lib/screens/home_screen.dart`의 호출부**: `_partIdForNewItems`
  (`_selectedPartId ?? defaultPartId`, 항상 값이 있음) →
  `_folderIdForNewItems`(`_selectedFolderId`, "전체"를 보고 있으면 그냥
  `null`)로 바꾸고, `importFromClipboard`/`importFromFilePicker`/
  `importYoutube`/`importFromDrop`을 부르는 자리(대략 4곳) 전부
  `partId: _partIdForNewItems` → `folderId: _folderIdForNewItems`로 고칩니다.
- **`lib/screens/board_screen.dart`의 호출부(2곳)**: `_onExternalFilesDropped`와
  `_onPasteFromClipboard`가 각각 `_importer.importFromDrop(event, partId:
  defaultPartId)`/`_importer.importFromClipboard(partId: defaultPartId)`를
  부릅니다. `widget.board`가 이미 `Board` 객체 전체(= `folderId` 포함,
  PR #59)를 갖고 있으므로, 그냥 `folderId: widget.board.folderId`로
  바꾸면 됩니다 — 판이 폴더에 연결돼 있으면 그 값이, 아니면 `null`이
  자동으로 넘어갑니다. 새로 읽어올 것이 없습니다.

**바뀌지 않는 것**
- 일괄 선택(고르기 모드)의 "폴더 이동" 기능 — 원래부터 폴더 기준이라
  그대로 씁니다.
- 태그·카테고리·프로젝트 CRUD, 검색, 즐겨찾기, 핀 고정, 정렬 — 무관합니다.
- 휴지통·백업/복원 — 파트는 소프트 삭제 대상이 아니었으므로(항상
  하드 존재) 무관합니다.

## ReferenceQuery의 역할 이동

```dart
// 지금 (part가 "자리", folder가 "조건")
final String? partId;    // hasAnyFilter에서 안 셈, clearAll에서 안 풀림
final String? folderId;  // hasAnyFilter에서 셈, clearAll에서 풀림

// 이후 (folder가 "자리"를 겸함, partId 삭제)
final String? folderId;  // hasAnyFilter에서 안 셈, clearAll에서 안 풀림
```

`clearFilter(TaxonomyKind.folder)`는 그대로 남겨둡니다 — 사이드바의
"전체 레퍼런스"를 누르는 것이 내부적으로 이 메서드를 부르는 방식은
안 바뀌고, 그저 부르는 곳이 필터줄 드롭다운이 아니라 사이드바 콜백일
뿐입니다.

## 사이드바 자동 배정 규칙 (메인 화면)

```
사이드바에서 "전체 레퍼런스"를 보고 있음 → 새 레퍼런스는 folderId: null
사이드바에서 특정 폴더를 보고 있음      → 새 레퍼런스는 그 폴더로 자동 배정
```

파트가 하던 것과 똑같은 규칙이라 사용자 입장에서 동작 변화가 없습니다
(자리 이름만 "파트"에서 "폴더"로 바뀝니다).

## 무드보드 외부 드롭 시 폴더 배정 규칙

```
그 판이 폴더에 연결돼 있음(board.folderId != null) → 새 레퍼런스는 그 폴더로
그 판이 폴더에 연결 안 돼 있음                      → 새 레퍼런스는 folderId: null
```

PR #59로 무드보드가 폴더에 연결될 수 있게 된 것을 활용하는 자연스러운
규칙입니다. "이 프로젝트 폴더용 무드보드에 사진을 끌어다 놓으면 그
프로젝트 폴더에 알아서 들어간다"가 되어, 오히려 예전 "무조건 기본
파트"보다 쓸모가 늘어납니다.

## 마이그레이션 테스트 계획

`test/data/migration_v5_to_v6_test.dart` (새 파일), PR #59의
`migration_v4_to_v5_test.dart`와 같은 형태로 최소 이 다섯 가지를 확인합니다.

1. 파트 데이터가 있는 v5 DB를 열면 앱이 정상적으로 켜지는가.
2. `partId` 칼럼이 실제로 없어졌는가 (`PRAGMA table_info`로 확인).
3. `taxonomy_items`에서 `kind='part'` 행이 전부 지워졌는가.
4. 파트에 속해 있던 레퍼런스가 지워지지 않고 남아 있는가(`folderId`는
   원래 값 그대로 보존).
5. **v1에서 곧장 v6로 건너뛰어도 오류 없이 켜지는가** — dropColumn이
   "없는 칼럼을 지우려는" 상황이 되지 않는지 확인하는 핵심 테스트입니다.

## 테스트 전략 (전체)

- 마이그레이션은 위 전용 테스트로.
- `part`/`파트`를 다루던 기존 위젯 테스트(`app_sidebar` 관련,
  `taxonomy_manage_screen` 관련, `reference_detail_screen`의 분류 항목
  관련, `home_screen`의 새 레퍼런스 배정 관련)를 폴더 기준으로 고칩니다.
  이름이 사라지는 것("파트")과 새로 생기는 이름("폴더 사이드바")이
  섞여 있어 **테스트 파일을 지우기보다 내용을 바꿔 재사용**하는 쪽이
  회귀를 더 잘 잡습니다.
- `flutter analyze` + 전체 `flutter test`로 회귀 확인.
- `flutter run -d windows`로 의뢰인이 직접 확인할 것: 사이드바 폴더
  목록·자동 배정·무드보드 지름길 버튼·분류 관리 탭 개수.

## 알려진 한계 (이번 범위에서 의도적으로 남기는 것)

- 폴더 중첩(하위 폴더)은 없습니다. 계속 평평한 목록입니다.
- 폴더가 많아지면 사이드바가 길어집니다 — 지금 파트 목록도 스크롤
  가능한 `ListView`라 같은 방식으로 대응됩니다. 검색·접기 같은 추가
  기능은 이번 범위 밖입니다.
- `Migrator.dropColumn`이 이 프로젝트가 번들한 SQLite 버전에서 실제로
  되는지는 구현 단계의 마이그레이션 테스트에서 처음 확인합니다 — 안
  되면 `alterTable`로 테이블을 재생성하는 방식으로 바꿉니다(계획 문서에
  두 경로 다 명시).
