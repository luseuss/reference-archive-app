// 앱의 시작점(entry point)입니다.
//
// 하는 일은 세 가지뿐입니다.
//   1. 데이터베이스와 저장소를 딱 한 번 만듭니다.
//   2. 앱 전체에 적용될 테마(밝은 모드 / 어두운 모드)를 정합니다.
//   3. 첫 화면으로 HomeScreen을 띄우면서 저장소를 넘겨줍니다.
//
// 화면 내용 자체는 여기 두지 않고 lib/screens/ 아래에 따로 둡니다.
// 이 파일이 계속 커지면 "앱 설정"과 "화면 내용"이 뒤섞여서 나중에 고치기 어려워집니다.
//
// ── 저장소를 왜 여기서 만드나 ──
// 데이터베이스는 앱 전체에서 하나만 열어야 합니다. 화면마다 새로 열면
// 같은 파일을 여러 번 여는 셈이라 데이터가 꼬입니다. 그래서 앱이 시작할 때
// 한 번만 만들고, 필요한 화면에 넘겨줍니다.
//
// 지금은 화면이 하나뿐이라 그냥 넘겨주면 되지만, 화면이 여러 개로 늘어나면
// 매번 손으로 넘기기 번거로워집니다. 그때 상태 관리 도구(Provider 등)를
// 붙이게 됩니다. 필요해지기 전에 미리 붙이면 코드만 복잡해집니다.

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:window_manager/window_manager.dart';

import 'data/app_database.dart';
import 'repositories/board_repository.dart';
import 'repositories/local_board_repository.dart';
import 'repositories/local_reference_repository.dart';
import 'repositories/local_taxonomy_repository.dart';
import 'repositories/reference_repository.dart';
import 'repositories/taxonomy_repository.dart';
import 'screens/board_popup_app.dart';
import 'screens/board_popup_controller.dart';
import 'screens/home_screen.dart';
import 'services/board_window_sync.dart';
import 'services/image_source.dart';
import 'services/image_storage.dart';
import 'services/local_image_storage.dart';
import 'services/app_settings.dart';
import 'services/network_image_source.dart';
import 'services/youtube_info_source.dart';
import 'theme/app_theme.dart';

/// 앱을 실행합니다. Dart 프로그램은 언제나 main() 함수부터 시작합니다.
///
/// ── 왜 갈림길이 생겼나 (무드보드 팝업 창) ──
/// desktop_multi_window로 만든 팝업 창은 "같은 실행 파일을 다시
/// 시작"하는 방식으로 뜹니다. 그래서 main()이 "나는 메인 창인가,
/// 팝업 창인가"부터 가려야 합니다. WindowController.fromCurrentEngine()의
/// arguments가 비어 있으면 메인 창(맨 처음 뜬 창), 아니면 팝업 창(그
/// 값이 보여줄 판 번호)입니다.
void main() async {
  // Flutter가 완전히 준비되기 전에 데이터베이스 같은 플러그인을 건드리면 오류가 납니다.
  // 이 한 줄이 "준비될 때까지 기다려라"는 뜻입니다.
  WidgetsFlutterBinding.ensureInitialized();

  if (!supportsBoardPopupWindow) {
    // 폰·태블릿에는 여러 창이라는 개념이 없어서 갈림길 자체가 필요
    // 없습니다. WindowController.fromCurrentEngine()을 부르면 오히려
    // 이 플랫폼에서 없는 기능을 억지로 부르는 셈이라 건너뜁니다.
    await _runMainWindow();
    return;
  }

  final WindowController windowController =
      await WindowController.fromCurrentEngine();

  if (windowController.arguments.isEmpty) {
    await _runMainWindow();
  } else {
    // 팝업 창입니다. arguments가 곧 보여줄 판 번호입니다.
    BoardWindowSync.ensureInitialized();
    runApp(BoardPopupApp(initialBoardId: windowController.arguments));
  }
}

/// 메인 창(앱의 진짜 첫 화면)을 준비하고 띄웁니다.
Future<void> _runMainWindow() async {
  final AppDatabase database = AppDatabase();

  // 저장해둔 설정(밝기 모드, 사용자 이름)을 먼저 읽습니다.
  // 화면을 띄운 뒤에 읽으면 밝은 화면이 잠깐 번쩍였다가 어두워집니다.
  final AppSettings settings = AppSettings();
  await settings.load();

  if (supportsBoardPopupWindow) {
    BoardWindowSync.ensureInitialized();
    await _installMainWindowCloseGuard();
  }

  runApp(
    ReferenceArchiveApp(
      referenceRepository: LocalReferenceRepository(database),
      boardRepository: LocalBoardRepository(database),
      taxonomyRepository: LocalTaxonomyRepository(database),
      imageStorage: LocalImageStorage(),
      imageSource: NetworkImageSource(),
      settings: settings,
      youtubeInfoSource: NetworkYoutubeInfoSource(),
    ),
  );
}

/// 메인 창을 닫으면 떠 있는 무드보드 팝업 창도 같이 닫히게 합니다.
///
/// ── 왜 필요한가 ──
/// desktop_multi_window의 창들은 같은 프로세스 안에서 돌지만, 메인
/// 창을 그냥 닫으면 팝업 창은 자기가 알아서 안 닫힙니다(서로 다른
/// 엔진이라 "메인이 사라졌다"는 것을 저절로 알 수 없습니다). 그래서
/// 메인 창의 닫기 버튼을 가로채서, 팝업부터 닫고 나서 진짜로 닫습니다.
Future<void> _installMainWindowCloseGuard() async {
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  windowManager.addListener(_MainWindowCloseGuard());
}

class _MainWindowCloseGuard extends WindowListener {
  @override
  void onWindowClose() async {
    await BoardPopupController.instance.closeIfOpen();

    // setPreventClose로 걸어둔 것을 풀어야 진짜로 닫힙니다. 다시
    // 걸 필요는 없습니다 — 앱이 곧 종료됩니다.
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }
}

/// 앱 전체를 감싸는 최상위 위젯입니다. 테마와 첫 화면을 지정합니다.
class ReferenceArchiveApp extends StatelessWidget {
  const ReferenceArchiveApp({
    super.key,
    required this.referenceRepository,
    required this.taxonomyRepository,
    required this.boardRepository,
    required this.imageStorage,
    required this.imageSource,
    required this.youtubeInfoSource,
    required this.settings,
  });

  /// 레퍼런스를 읽고 쓰는 통로입니다.
  ///
  /// 타입이 구현체(LocalReferenceRepository)가 아니라 약속(ReferenceRepository)인 점이
  /// 중요합니다. 이렇게 해두면 나중에 서버용 구현체로 바꿀 때 이 파일의 한 줄만
  /// 고치면 되고, 화면 코드는 전혀 안 건드려도 됩니다.
  final ReferenceRepository referenceRepository;

  /// 폴더·카테고리·태그·프로젝트를 읽고 쓰는 통로입니다.
  final TaxonomyRepository taxonomyRepository;

  /// 무드보드와 카드 배치를 읽고 쓰는 통로입니다.
  final BoardRepository boardRepository;

  /// 이미지 파일을 저장하고 경로를 알려주는 도구입니다.
  final ImageStorage imageStorage;

  /// 유튜브에서 제목과 썸네일을 가져오는 도구입니다.
  final YoutubeInfoSource youtubeInfoSource;

  /// 주소나 클립보드에서 이미지를 가져오는 도구입니다.
  final ImageSource imageSource;

  /// 앱 설정입니다. 사이드바의 사용자 이름과 설정 화면에 씁니다.
  final AppSettings settings;

  /// 앱의 화면 구조를 만들어 돌려줍니다.
  /// Flutter는 화면을 새로 그려야 할 때마다 이 build() 함수를 다시 호출합니다.
  @override
  Widget build(BuildContext context) {
    // ListenableBuilder = 설정이 바뀌면 이 안을 다시 그려주는 위젯입니다.
    // 설정 화면에서 "어둡게"를 고르는 순간 앱 전체가 어두워지는 것이 이 덕분입니다.
    // 이게 없으면 앱을 껐다 켜야 반영됩니다.
    return ListenableBuilder(
      listenable: settings,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          title: '레퍼런스 아카이브',

          // 오른쪽 위에 뜨는 "DEBUG" 리본을 숨깁니다.
          // 개발 중에도 실제 모습을 보기 위함입니다.
          debugShowCheckedModeBanner: false,

          // flutter_quill과 Flutter 표준 위젯들의 로컬라이제이션 설정입니다.
          // RichMemoEditor(Task 4)가 QuillToolbar를 사용하기 위해 필요합니다.
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            FlutterQuillLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const <Locale>[
            Locale('ko'),
            Locale('en'),
          ],

          // 밝은 모드 / 어두운 모드 테마를 각각 지정하고,
          // 어느 쪽을 쓸지는 themeMode로 정합니다.
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),

          // 설정 화면에서 고른 값입니다. 기본값은 기기 설정 따라가기입니다.
          themeMode: settings.themeMode,

          home: HomeScreen(
            repository: referenceRepository,
            taxonomyRepository: taxonomyRepository,
            boardRepository: boardRepository,
            imageStorage: imageStorage,
            imageSource: imageSource,
            youtubeInfoSource: youtubeInfoSource,
            settings: settings,
          ),
        );
      },
    );
  }
}
