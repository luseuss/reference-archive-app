// 앱이 정상적으로 실행되는지 확인하는 위젯 테스트입니다.
//
// 위젯 테스트 = 실제 화면을 띄우지 않고 메모리 안에서 위젯을 그려본 뒤,
// 기대한 글자나 아이콘이 실제로 나오는지 확인하는 자동 검사입니다.
// 터미널에서 `flutter test` 로 실행합니다.
//
// 화면을 고친 뒤 이 테스트가 실패한다면, 화면이 깨졌거나
// 이 테스트가 기대하는 문구가 바뀐 것입니다. 둘 중 어느 쪽인지 확인하세요.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reference_archive_app/main.dart';

void main() {
  testWidgets('앱을 실행하면 홈 화면의 제목과 안내 문구가 보인다', (WidgetTester tester) async {
    // 앱을 메모리 안에서 실행합니다.
    await tester.pumpWidget(const ReferenceArchiveApp());

    // 앱 이름이 화면에 보이는지 확인합니다.
    // AppBar 제목과 본문에 각각 하나씩, 총 두 군데 나오는 것이 정상입니다.
    expect(find.text('레퍼런스 아카이브'), findsNWidgets(2));

    // 1단계 안내 문구가 보이는지 확인합니다.
    expect(
      find.textContaining('1단계: 뼈대와 저장 준비 중입니다.'),
      findsOneWidget,
    );

    // 안내용 아이콘이 보이는지 확인합니다.
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
  });
}
