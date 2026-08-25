// 앱의 시작점(entry point)입니다.
//
// 하는 일은 두 가지뿐입니다.
//   1. 앱 전체에 적용될 테마(밝은 모드 / 어두운 모드)를 정합니다.
//   2. 첫 화면으로 HomeScreen을 띄웁니다.
//
// 화면 내용 자체는 여기 두지 않고 lib/screens/ 아래에 따로 둡니다.
// 이 파일이 계속 커지면 "앱 설정"과 "화면 내용"이 뒤섞여서 나중에 고치기 어려워집니다.

import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

/// 앱을 실행합니다. Dart 프로그램은 언제나 main() 함수부터 시작합니다.
void main() {
  runApp(const ReferenceArchiveApp());
}

/// 앱 전체를 감싸는 최상위 위젯입니다. 테마와 첫 화면을 지정합니다.
class ReferenceArchiveApp extends StatelessWidget {
  const ReferenceArchiveApp({super.key});

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

      home: const HomeScreen(),
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
