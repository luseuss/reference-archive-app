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
