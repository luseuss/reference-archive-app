# 변경 이력 (PR 단위)

PR이 병합될 때마다 여기에 **무엇을 왜 어떻게 고쳤는지, 어떻게 테스트했는지,
그리고 검증하지 못한 한계**를 적습니다. 새 세션에서 "지금까지 뭘 했지?"를 파악하는 기록입니다.

프로젝트 구조·기술 결정·워크플로우 같은 절차적인 내용은 `CLAUDE.md`에 있습니다.

---

## PR #1 — Flutter 프로젝트 초기화 + 프로젝트 메모리 문서

**무엇을 했나**

기존 HTML/JS 웹앱을 Flutter로 재구축하는 새 저장소의 뼈대를 세웠습니다.

1. **Flutter 프로젝트 생성** — `flutter create`로 Windows / macOS / Linux / Android / iOS
   5개 플랫폼용 스캐폴딩 생성. 패키지명 `reference_archive_app`, org `com.luseuss`.
   웹은 제외했습니다(설치형 앱이 목표라 PWA 개념이 불필요 — `CLAUDE.md`의 플랫폼 차이표 참고).
2. **기본 카운터 데모를 실제 앱 뼈대로 교체** — `flutter create`가 만들어주는 예제
   카운터 앱은 영어 주석이라 이 프로젝트의 "모든 주석은 한국어" 규칙에 어긋납니다.
   PR #1부터 규칙을 실제로 보여주기 위해 처음부터 다시 썼습니다.
3. **Windows 창 제목을 한글로** — 빌드해서 실행해보니 창 제목이
   `reference_archive_app`으로 떴습니다. Windows 네이티브 창 제목은 Dart 쪽
   `MaterialApp(title: ...)`이 아니라 C++ 러너(`windows/runner/main.cpp`)에서
   따로 정해지기 때문입니다. **둘 다 고쳐야 합니다.**

   그런데 한글을 그냥 넣으면 깨집니다. Flutter가 만들어주는 기본 CMake 설정에는
   `/utf-8` 컴파일 옵션이 없어서, MSVC가 소스를 시스템 코드페이지(한국어 Windows는
   949)로 읽어버립니다. `windows/CMakeLists.txt`의 `APPLY_STANDARD_SETTINGS`에
   `/utf-8`을 추가해서 해결했습니다. 앞으로 C++ 쪽에 한글을 더 넣어도 안전합니다.

4. **`CLAUDE.md` / `update.md` 작성** — 다음 세션의 외부 기억 장치.

**나중에 이 부분을 고치려면 어디를 보면 되나**

| 고치고 싶은 것 | 봐야 할 곳 |
|---|---|
| 앱 전체 색감 | `lib/main.dart`의 `_seedColor` 상수 하나만 바꾸면 밝은/어두운 테마 양쪽에 반영됩니다 |
| 밝은/어두운 모드 동작 | `lib/main.dart`의 `_buildLightTheme()` / `_buildDarkTheme()` / `themeMode` |
| 첫 화면 내용 | `lib/screens/home_screen.dart`의 `build()` 안 `body:` 부분 |
| 앱 이름(Windows 창 제목) | `windows/runner/main.cpp`의 `window.Create(L"...")` |
| 앱 이름(Dart 쪽) | `lib/main.dart`의 `MaterialApp(title: ...)` |
| C++ 코드에 한글 넣기 | `windows/CMakeLists.txt`의 `/utf-8` 옵션이 이미 켜져 있습니다 |
| 테스트가 기대하는 문구 | `test/widget_test.dart` |

**새로 나온 개념 2가지**

- **위젯(Widget)** — Flutter에서는 화면의 모든 것이 위젯입니다. 버튼도, 글자도, 여백도,
  화면 전체도 위젯입니다. 위젯을 레고처럼 안에 넣어 쌓아서 화면을 만듭니다.
  `StatelessWidget`은 스스로 바뀌는 값이 없는 위젯, `StatefulWidget`은 값이 바뀌면
  화면을 다시 그리는 위젯입니다. 지금은 바뀌는 값이 없어서 전부 Stateless입니다.
- **위젯 테스트(`flutter test`)** — 실제 창을 띄우지 않고 메모리 안에서 위젯을 그려본 뒤
  "이 글자가 화면에 있는가"를 자동으로 확인합니다. 기존 웹앱에서는 브라우저를 띄우고
  가짜 클릭 이벤트를 쏘는 번거로운 방식으로 테스트했는데, Flutter에서는 이게 기본 기능입니다.

**어떻게 테스트했나**

- `flutter analyze` — 문제 없음 (No issues found)
- `flutter test` — 위젯 테스트 1건 통과. 홈 화면의 제목·안내 문구·아이콘이 실제로
  그려지는지 확인합니다.
- `flutter doctor` — Flutter 3.47.1 / Dart 3.13.1 정상, Visual Studio / Windows 기기 모두 인식
- `flutter build windows` — 릴리스 빌드 성공 (`reference_archive_app.exe`, 25MB)
- **빌드된 exe를 실제로 실행해서 확인** — 창이 정상적으로 뜨고,
  제목 표시줄에 "레퍼런스 아카이브"가 깨짐 없이 출력되는 것까지 확인했습니다.

**한계 / 아직 확인 못 한 것**

- **Android 빌드는 검증하지 못했습니다.** 이 PC에 Android SDK를 아직 설치하지 않았습니다
  (약 10GB 추가 필요). 폰에서 실제로 볼 준비가 됐을 때 설치하고 그때 검증합니다.
  프로젝트에는 `android/` 폴더가 이미 생성되어 있어 SDK만 설치하면 바로 빌드 가능합니다.

---

## PR #2 — 데이터 모델 + Repository + drift 로컬 저장소

**무엇을 했나**

1단계(뼈대와 저장) 중 **저장 계층**을 만들었습니다. 화면은 아직 없습니다.
저장이 단단해야 화면 작업이 편하고, 한 PR에 다 넣으면 너무 커져서 나눴습니다.

1. **drift 데이터베이스 정의** (`lib/data/`)
   - `tables.dart` — 표 3개: `References`(레퍼런스), `TaxonomyItems`(폴더/카테고리/
     태그/프로젝트), `ReferenceTaxonomyLinks`(레퍼런스↔태그·프로젝트 연결)
   - `app_database.dart` — 데이터베이스를 열고 닫는 곳. 파일 위치는 `driftDatabase()`가
     기기별 앱 데이터 폴더를 알아서 찾습니다(설계 원칙 4-4).

2. **폴더·카테고리·태그·프로젝트를 한 표로 통합**
   넷 다 담는 정보가 (이름 + 시각)으로 완전히 같아서 표를 네 개 만들지 않고
   `kind` 칸으로 구분합니다. 기존 웹앱에서 `makeTaxonomy()` 하나로 폴더와 카테고리를
   함께 처리했던 것과 같은 방식입니다. 코드가 1/4로 줄고 고칠 곳도 한 군데뿐입니다.

3. **Repository 패턴** (`lib/repositories/`) — 설계 원칙 4-3의 실물
   - `reference_repository.dart` / `taxonomy_repository.dart` — **약속만** 적은 파일
   - `local_reference_repository.dart` / `local_taxonomy_repository.dart` — 실제 구현
   - **drift 코드는 `local_*.dart` 두 파일 안에만 있습니다.** 나중에 서버를 붙일 때
     `synced_*.dart`를 만들어 갈아끼우면 화면 코드는 안 건드려도 됩니다.

4. **화면용 모델** (`lib/models/`) — `ReferenceItem`, `TaxonomyItem`, `enums.dart`
   drift가 만들어주는 행 클래스(`ReferenceRow`, `TaxonomyItemRow`)와 이름으로 구분합니다.
   **`~Row`는 데이터베이스 한 줄, `~Item`은 화면이 쓰는 모델**입니다.

5. **UUID 생성기** (`lib/utils/id_generator.dart`) — `newId()` 하나뿐입니다.

**잡은 버그: 시각이 UTC로 저장되지 않고 있었음**

테스트를 쓰다가 발견했습니다. `DateTime.utc(2020,1,1)`을 저장했는데
`2020-01-01 09:00:00` **현지 시각(KST)** 으로 돌아왔습니다.
drift는 기본적으로 시각을 정수 타임스탬프로 저장하고 읽을 때 현지 시각으로 바꿔주는데,
그러면 설계 원칙 4-2("UTC로 저장")가 조용히 깨집니다. 시차가 다른 기기끼리 데이터를
합칠 때 "어느 쪽이 최신인가" 판단이 틀어지는, 나중에 찾기 아주 어려운 종류의 버그입니다.

두 겹으로 고쳤습니다.
- `build.yaml`에 `store_date_time_values_as_text: true` — 시각을 ISO 8601 글자로
  저장해서 시간대 정보(끝의 `Z`)와 밀리초 정밀도를 함께 보존합니다.
  **저장 형식 자체를 바꾸는 설정**이라 사용자 데이터가 없는 지금이 바꿀 수 있는
  마지막 시점이었습니다.
- 저장소가 모델로 변환할 때 `.toUtc()` — 위 설정을 누가 실수로 지워도 막히도록.

**나중에 이 부분을 고치려면 어디를 보면 되나**

| 고치고 싶은 것 | 봐야 할 곳 |
|---|---|
| 레퍼런스에 저장할 항목 추가 | `lib/data/tables.dart`의 `References` → `schemaVersion` 올리고 `migration`에 추가 → 코드 생성 |
| 목록 정렬 순서 | `lib/repositories/local_reference_repository.dart`의 `getAll()` 안 `orderBy` |
| 폴더/태그 이름 중복 규칙 | `lib/repositories/local_taxonomy_repository.dart`의 `existsWithName()` |
| 폴더를 지울 때 딸린 것 처리 | 같은 파일의 `delete()` |
| 태그를 붙이고 떼는 방식 | `local_reference_repository.dart`의 `_replaceLinks()` |
| 데이터베이스 파일 위치 | `lib/data/app_database.dart`의 `_openConnection()` |
| 새 UUID 만드는 방법 | `lib/utils/id_generator.dart` |

**새로 나온 개념 4가지**

- **abstract class(약속)** — "이런 기능이 있어야 한다"는 목록만 적고 내용은 안 적은
  클래스입니다. 화면과 저장소 사이에 이걸 끼워두면, 저장 방식을 바꿔도 화면은 안 고쳐도 됩니다.
- **Future / async / await** — 데이터베이스를 읽는 데는 시간이 걸립니다. 그동안 화면이
  멈추면 안 되니까 "지금은 없지만 잠시 후 준다"는 약속(Future)을 먼저 돌려줍니다.
  받는 쪽에서 `await`를 붙이면 결과가 올 때까지 기다립니다.
- **transaction(거래)** — 여러 작업을 "전부 성공하거나 전부 실패하거나"로 묶는 것입니다.
  레퍼런스 본체는 저장됐는데 태그 연결에서 오류가 나면 반쪽짜리 데이터가 남기 때문입니다.
- **코드 생성(build_runner)** — 표 정의를 고친 뒤 `dart run build_runner build`를 돌리면
  실제 SQL과 Dart 코드가 자동으로 만들어집니다. **안 돌리면 반영되지 않습니다.**

**어떻게 테스트했나**

- `flutter analyze` — 문제 없음
- `flutter test` — **31건 전부 통과** (기존 위젯 테스트 1건 + 새 저장소 테스트 30건)
  - 저장/조회/덮어쓰기, 소프트 삭제(데이터베이스에 실제로 남아있는지 직접 확인),
    핀 고정 정렬, 태그 붙이고 떼기, 뗐던 태그 되살리기, 태그와 프로젝트가 섞이지 않는지,
    분류 항목을 지웠을 때 딸린 레퍼런스 처리, 이름 중복 검사(공백·대소문자·종류별),
    createdAt 보존과 updatedAt 갱신, **시각이 UTC인지**
- 테스트는 메모리 안에서만 도는 데이터베이스(`NativeDatabase.memory()`)를 씁니다.
  파일을 만들지 않아 흔적이 남지 않고 테스트끼리 영향을 주지 않습니다.

**한계 / 아직 안 한 것**

- **실제 앱으로 실행해보지는 못했습니다.** drift는 SQLite 네이티브 라이브러리를 쓰는
  플러그인이고, Windows에서 플러그인을 빌드하려면 **개발자 모드**가 켜져 있어야 하는데
  아직 꺼져 있습니다. 다만 테스트는 이 제약과 무관하게 실제 SQLite 엔진으로 돌기 때문에,
  저장소 동작 자체는 31건으로 검증된 상태입니다. 개발자 모드를 켜면 바로 앱에서도 됩니다.
- **무드보드(씬/배치) 표는 아직 안 만들었습니다.** 4단계에서 만듭니다. 특히 메모의
  리치텍스트를 어떤 형식으로 담을지는 5단계에서 정할 문제라, 지금 정하면 섣부릅니다.
  drift에서 표를 나중에 추가하는 것은 `schemaVersion`을 올리고 `migration`에
  `m.createTable(...)` 한 줄을 더하면 되어서 어렵지 않습니다.
- 검색·일괄 선택·정렬 옵션은 2단계 항목이라 아직 없습니다.

---

## PR #3 — 레퍼런스 추가·목록·삭제 화면 + 이미지 자동 리사이즈

**무엇을 했나**

PR #2에서 만든 저장 계층 위에 **실제로 쓸 수 있는 화면**을 올렸습니다.
이걸로 1단계(뼈대와 저장)가 완료됩니다.

1. **이미지 추가** — 오른쪽 아래 버튼으로 파일을 고르면(여러 장 동시 가능)
   크기를 줄여서 앱 폴더에 저장하고 목록에 추가합니다.
2. **목록** — 격자로 표시. 칸 개수를 고정하지 않고 **칸 너비**를 정해서,
   창을 넓히면 칸이 늘고 폰처럼 좁은 화면에서는 저절로 줄어듭니다.
   데스크톱·모바일용 화면을 따로 만들지 않아도 됩니다.
3. **삭제** — 카드의 휴지통 버튼. 소프트 삭제라 **이미지 파일은 남겨둡니다**
   (되살렸을 때 그림 없는 빈 껍데기가 되지 않도록).
4. **이미지 자동 리사이즈** — 긴 변 1600px, JPEG 품질 85 (기존 웹앱과 동일 기준).
   원본이 1600px보다 작으면 억지로 키우지 않습니다.

**구조**

```
lib/services/
  image_resizer.dart        크기 줄이기 계산만 (파일·화면과 무관한 순수 함수)
  image_storage.dart        파일 저장 "약속"
  local_image_storage.dart  실제 파일 저장 구현
lib/widgets/
  reference_card.dart       카드 한 장의 생김새
lib/screens/
  home_screen.dart          목록 화면
```

**설계하다 막혀서 구조를 바꾼 부분 (중요)**

처음에는 `ImageStorageService` 하나에 전부 넣었는데, 위젯 테스트가
**`pumpAndSettle timed out`으로 멈춰버렸습니다.**

원인: `getApplicationSupportDirectory()`는 **플러그인**이라 테스트 환경에는
대답해줄 상대가 없어서 영원히 기다립니다. 화면이 플랫폼 의존 코드에 직접
묶여 있으면 화면을 테스트할 수 없다는 뜻입니다.

그래서 저장소(repositories/)와 **똑같은 방식**으로 나눴습니다.
- `ImageStorage` (약속) ← 화면은 이것만 압니다
- `LocalImageStorage` (실제 구현)
- `FakeImageStorage` (테스트용, 파일을 안 만들고 즉시 대답)

설계 원칙 4-3이 "나중에 서버 붙이기"뿐 아니라 **지금 당장 테스트를 가능하게
하는 것**에도 쓰인 사례입니다.

**잡은 버그 2개**

1. **그림이 아닌 파일을 고르면 앱이 터졌음** — `img.decodeImage()`는 문서상
   "못 읽으면 null"이지만 실제로는 **오류를 내며 터집니다**(내부적으로 여러 형식을
   하나씩 시험해보다가 데이터 범위를 벗어나 읽음). 사용자가 실수로 텍스트 파일을
   고르면 앱이 꺼졌을 것입니다. `image_resizer.dart`의 `_tryDecode()`로 감쌌습니다.

2. **데이터베이스와 이미지가 사용자 "문서" 폴더에 저장되고 있었음** — drift와
   path_provider의 기본값이 `getApplicationDocumentsDirectory()`인데, Windows에서
   그곳은 사용자의 문서 폴더입니다. 실제로 실행해보니
   `C:\Users\...\Documents\reference_archive.sqlite`가 생겼고, 이미지는
   `Documents\images\`에 들어갈 참이었습니다. **사용자가 직접 만든 images 폴더와
   충돌할 수 있는 위험**입니다. 양쪽 다 `getApplicationSupportDirectory()`
   (`%APPDATA%\com.luseuss\reference_archive_app`)로 바꿨습니다.

**나중에 이 부분을 고치려면 어디를 보면 되나**

| 고치고 싶은 것 | 봐야 할 곳 |
|---|---|
| 리사이즈 기준 (1600px / 품질 85) | `lib/services/image_resizer.dart`의 `maxImageLongEdge`, `jpegQuality` |
| 저장 형식(JPEG 말고 다른 것) | 같은 파일의 `resizeImageBytes()` 안 `encodeJpg` |
| 이미지 저장 위치 | `lib/services/local_image_storage.dart`의 `_getImagesDirectory()` |
| 데이터베이스 파일 위치 | `lib/data/app_database.dart`의 `_openConnection()` |
| 카드 생김새 (제목·버튼·썸네일) | `lib/widgets/reference_card.dart` |
| 격자 칸 크기·간격 | `lib/screens/home_screen.dart`의 `_buildGrid()` |
| 비어 있을 때 안내 문구 | 같은 파일의 `_buildEmptyState()` |
| 추가 후 뜨는 메시지 | 같은 파일의 `_showResultMessage()` |
| 새 레퍼런스의 기본 제목 | 같은 파일의 `_saveOneImage()` |

**새로 나온 개념 3가지**

- **StatefulWidget과 setState** — 화면에 보이는 내용이 변하는 화면은
  StatefulWidget으로 만듭니다. 값을 바꾼 뒤 `setState(...)`를 부르면 Flutter가
  "바뀌었으니 다시 그려라"를 알아듣습니다. setState 없이 값만 바꾸면 화면은 그대로입니다.
- **compute (별도 작업 공간)** — 큰 사진의 크기를 줄이는 건 무거운 일이라,
  그냥 하면 그동안 화면이 얼어붙습니다. `compute()`는 그 일을 옆 작업 공간에서
  처리해줍니다. 단, 넘기는 함수는 **클래스 밖 최상위 함수**여야 합니다.
- **가짜(Fake)로 갈아끼우기** — 테스트에서 진짜 파일 저장 대신 가짜를 넣습니다.
  화면이 구현체가 아니라 약속에 의존하기 때문에 가능한 일입니다.

**어떻게 테스트했나**

- `flutter analyze` — 문제 없음
- `flutter test` — **50건 전부 통과** (기존 30건 + 새로 20건)
  - 화면 4건: 빈 목록 안내, 목록에 제목 표시, 제목 없을 때 "(제목 없음)",
    **휴지통 버튼을 실제로 눌러서** 목록과 데이터베이스 양쪽에서 사라지는지
  - 리사이즈 8건: 가로/세로/정사각형, 작은 이미지는 안 키움, 정확히 1600px,
    PNG→JPEG 변환, 픽셀 수 감소, 그림 아닌 파일
  - 실제 파일 저장 8건: 파일 생성, .jpg 확장자, 저장 후 크기 확인,
    이름 중복 없음, 그림 아닌 파일은 쓰레기 안 남김, 삭제, 없는 파일 삭제,
    앱 폴더 안에 저장되는지
- **실제 앱 실행 확인** — `flutter run -d windows`로 띄워서 데이터베이스가
  올바른 위치(`%APPDATA%\com.luseuss\reference_archive_app`)에 만들어지고,
  사용자 문서 폴더는 깨끗한 것까지 확인했습니다.

**한계 / 아직 확인 못 한 것**

- **파일 고르기 창을 눌러보는 것은 자동으로 못 합니다.** 운영체제가 띄우는
  창이라 테스트에서 조작할 수 없습니다. 다만 창이 닫힌 뒤의 처리(크기 줄이기,
  파일 저장, 목록 추가)는 전부 테스트로 검증했습니다.
  **실제로 이미지를 넣어보는 것은 직접 해보셔야 합니다.**
- **릴리스 exe는 Smart App Control이 막습니다.** 개발 중에는
  `flutter run -d windows`로 실행하면 됩니다.
- 지운 이미지 파일은 디스크에 남습니다. 안 쓰는 파일을 정리하는 기능은
  나중에 따로 만듭니다.
- 제목 고치기, 검색, 폴더 지정 등은 2단계 항목입니다.
