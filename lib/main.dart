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

import 'package:flutter/material.dart';

import 'data/app_database.dart';
import 'repositories/local_reference_repository.dart';
import 'repositories/local_taxonomy_repository.dart';
import 'repositories/reference_repository.dart';
import 'repositories/taxonomy_repository.dart';
import 'screens/home_screen.dart';
import 'services/image_storage.dart';
import 'services/local_image_storage.dart';

/// 앱을 실행합니다. Dart 프로그램은 언제나 main() 함수부터 시작합니다.
void main() {
  // Flutter가 완전히 준비되기 전에 데이터베이스 같은 플러그인을 건드리면 오류가 납니다.
  // 이 한 줄이 "준비될 때까지 기다려라"는 뜻입니다.
  WidgetsFlutterBinding.ensureInitialized();

  final AppDatabase database = AppDatabase();

  runApp(
    ReferenceArchiveApp(
      referenceRepository: LocalReferenceRepository(database),
      taxonomyRepository: LocalTaxonomyRepository(database),
      imageStorage: LocalImageStorage(),
    ),
  );
}

/// 앱 전체를 감싸는 최상위 위젯입니다. 테마와 첫 화면을 지정합니다.
class ReferenceArchiveApp extends StatelessWidget {
  const ReferenceArchiveApp({
    super.key,
    required this.referenceRepository,
    required this.taxonomyRepository,
    required this.imageStorage,
  });

  /// 레퍼런스를 읽고 쓰는 통로입니다.
  ///
  /// 타입이 구현체(LocalReferenceRepository)가 아니라 약속(ReferenceRepository)인 점이
  /// 중요합니다. 이렇게 해두면 나중에 서버용 구현체로 바꿀 때 이 파일의 한 줄만
  /// 고치면 되고, 화면 코드는 전혀 안 건드려도 됩니다.
  final ReferenceRepository referenceRepository;

  /// 폴더·카테고리·태그·프로젝트를 읽고 쓰는 통로입니다.
  final TaxonomyRepository taxonomyRepository;

  /// 이미지 파일을 저장하고 경로를 알려주는 도구입니다.
  final ImageStorage imageStorage;

  /// 앱의 화면 구조를 만들어 돌려줍니다.
  /// Flutter는 화면을 새로 그려야 할 때마다 이 build() 함수를 다시 호출합니다.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '레퍼런스 아카이브',

      // 오른쪽 위에 뜨는 "DEBUG" 리본을 숨깁니다. 개발 중에도 실제 모습을 보기 위함입니다.
      debugShowCheckedModeBanner: false,

      // 밝은 모드 / 어두운 모드 테마를 각각 지정하고,
      // 어느 쪽을 쓸지는 themeMode로 정합니다.
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),

      // ThemeMode.system = 사용자의 운영체제 설정(밝게/어둡게)을 그대로 따라갑니다.
      // 나중에 앱 안에서 직접 토글하게 만들려면 이 값을 상태로 빼내면 됩니다.
      themeMode: ThemeMode.system,

      home: HomeScreen(
        repository: referenceRepository,
        taxonomyRepository: taxonomyRepository,
        imageStorage: imageStorage,
      ),
    );
  }
}

/// 앱의 대표 색상입니다. 이 색 하나에서 밝은/어두운 테마의 나머지 색이 자동으로 만들어집니다.
///
/// 기존 웹앱에서 쓰던 세이지 그린 계열 accent 색을 그대로 가져왔습니다.
/// 앱 전체 색감을 바꾸고 싶으면 이 값 하나만 고치면 됩니다.
const Color _seedColor = Color(0xFF719F89);

/// 밝은 모드 테마를 만들어 돌려줍니다.
ThemeData _buildLightTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );
}

/// 어두운 모드 테마를 만들어 돌려줍니다.
ThemeData _buildDarkTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );
}
