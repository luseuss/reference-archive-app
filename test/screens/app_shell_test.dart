// 새 화면 구조(사이드바 + 본문)를 확인하는 테스트입니다.
//
// ── 여기서 특히 보는 것 ──
// **창이 좁을 때 사이드바가 자리를 차지하지 않는지**입니다.
// 사이드바는 232px인데, 폰 화면은 그것만으로도 절반 가까이 됩니다.
// 좁은 화면에서 사이드바가 그대로 남아 있으면 정작 볼 목록이 손바닥만 해집니다.
//
// 눈으로 보려면 창 크기를 바꿔가며 확인해야 하는데, 테스트에서는 화면 크기를
// 마음대로 정할 수 있어서 이런 것을 확인하기 좋습니다.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/main.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/repositories/local_taxonomy_repository.dart';
import 'package:reference_archive_app/screens/settings_screen.dart';
import 'package:reference_archive_app/services/app_settings.dart';
import 'package:reference_archive_app/widgets/app_sidebar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_image_source.dart';
import '../fakes/fake_image_storage.dart';
import '../fakes/fake_youtube_info_source.dart';

void main() {
  late AppDatabase db;
  late LocalReferenceRepository repository;
  late LocalTaxonomyRepository taxonomyRepository;
  late AppSettings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalReferenceRepository(db);
    taxonomyRepository = LocalTaxonomyRepository(db);

    settings = AppSettings();
    await settings.load();
  });

  tearDown(() async {
    await db.close();
  });

  /// 화면 크기를 정합니다.
  ///
  /// 사이드바를 늘 펼쳐둘지(넓은 창) 서랍에 넣을지(좁은 창)가
  /// 이 크기로 갈립니다.
  void useScreenSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// 테스트용 앱을 만들어 돌려줍니다.
  Widget makeApp() {
    return ReferenceArchiveApp(
      referenceRepository: repository,
      taxonomyRepository: taxonomyRepository,
      imageStorage: FakeImageStorage(),
      imageSource: FakeImageSource(),
      youtubeInfoSource: FakeYoutubeInfoSource(),
      settings: settings,
    );
  }

  /// 화면을 띄우고 다 그려질 때까지 기다립니다.
  Future<void> openApp(WidgetTester tester, {required Size size}) async {
    useScreenSize(tester, size);
    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();
  }

  group('넓은 창 (데스크톱)', () {
    const Size wide = Size(1400, 1000);

    testWidgets('사이드바가 늘 펼쳐져 있다', (WidgetTester tester) async {
      await openApp(tester, size: wide);

      expect(find.byType(AppSidebar), findsOneWidget);
    });

    testWidgets('메뉴 버튼은 없다', (WidgetTester tester) async {
      // 이미 보이는 것을 여는 버튼은 자리만 차지합니다.
      await openApp(tester, size: wide);

      expect(find.byTooltip('메뉴 열기'), findsNothing);
    });

    testWidgets('사용자 이름이 사이드바에 보인다', (WidgetTester tester) async {
      await settings.setUserName('주원');

      await openApp(tester, size: wide);

      expect(find.text('주원'), findsOneWidget);
      // 로그인 기능이 없다는 것을 숨기지 않습니다.
      expect(find.text('로그인 안 함'), findsOneWidget);
    });

    testWidgets('제목과 개수가 위쪽에 보인다', (WidgetTester tester) async {
      await openApp(tester, size: wide);

      expect(find.text('레퍼런스 아카이브'), findsOneWidget);
      expect(find.text('0개'), findsOneWidget);
    });
  });

  group('좁은 창 (폰)', () {
    const Size narrow = Size(500, 900);

    testWidgets('사이드바가 자리를 차지하지 않는다', (WidgetTester tester) async {
      // ── 이게 이 파일의 핵심입니다 ──
      // 232px 사이드바가 500px 화면에 그대로 남으면 목록이 절반으로 줄어듭니다.
      await openApp(tester, size: narrow);

      expect(find.byType(AppSidebar), findsNothing);
    });

    testWidgets('메뉴 버튼으로 사이드바를 꺼낼 수 있다', (WidgetTester tester) async {
      // 안 보이기만 하고 꺼낼 방법이 없으면 설정에 못 들어갑니다.
      await openApp(tester, size: narrow);

      expect(find.byTooltip('메뉴 열기'), findsOneWidget);

      await tester.tap(find.byTooltip('메뉴 열기'));
      await tester.pumpAndSettle();

      expect(find.byType(AppSidebar), findsOneWidget);
    });
  });

  group('설정', () {
    const Size wide = Size(1400, 1000);

    testWidgets('사이드바에서 설정 화면을 연다', (WidgetTester tester) async {
      await openApp(tester, size: wide);

      await tester.tap(find.text('설정'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      // 의뢰인이 정한 세 가지가 다 있어야 합니다.
      expect(find.text('어둡게'), findsOneWidget);
      expect(find.text('만든 사람'), findsOneWidget);
      expect(find.text('버전'), findsOneWidget);
    });

    testWidgets('어두운 모드를 고르면 앱 전체가 곧바로 어두워진다', (WidgetTester tester) async {
      // 설정을 바꿨는데 앱을 껐다 켜야 반영되면 고장난 줄 압니다.
      await openApp(tester, size: wide);

      await tester.tap(find.text('설정'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('어둡게'));
      await tester.pumpAndSettle();

      expect(settings.themeMode, ThemeMode.dark);

      // 앱이 실제로 어두운 테마로 그려지고 있어야 합니다.
      final MaterialApp app = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(app.themeMode, ThemeMode.dark);
    });

    testWidgets('로그인은 아직 없다고 알려준다', (WidgetTester tester) async {
      // 눌렀는데 아무 일도 안 일어나면 고장난 줄 압니다.
      await openApp(tester, size: wide);

      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle();

      expect(find.textContaining('아직 만들지 않았습니다'), findsOneWidget);
    });
  });
}
