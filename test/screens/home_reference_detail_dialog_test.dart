// 레퍼런스 편집 화면이 화면 너비에 따라 대화상자로 뜨는지, 화면 전체로
// 뜨는지를 확인하는 테스트입니다.
//
// ── 왜 확인하나 ──
// 화면이 넓을 때(데스크톱)는 옛 웹앱처럼 가운데 뜨는 작은 대화상자로,
// 좁을 때(폰)는 지금까지처럼 화면 전체로 열려야 합니다. 이 갈림길이
// 조용히 반대로 바뀌어도 겉으로는 "레퍼런스 편집 화면이 뜬다"는 점에서
// 똑같아 보이므로, 어느 모습으로 뜨는지 직접 확인해둡니다.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/main.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/repositories/local_board_repository.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/repositories/local_taxonomy_repository.dart';
import 'package:reference_archive_app/services/app_settings.dart';
import 'package:reference_archive_app/utils/id_generator.dart';

import '../fakes/fake_image_source.dart';
import '../fakes/fake_image_storage.dart';
import '../fakes/fake_youtube_info_source.dart';

void main() {
  late AppDatabase db;
  late LocalReferenceRepository repository;
  late LocalTaxonomyRepository taxonomyRepository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalReferenceRepository(db);
    taxonomyRepository = LocalTaxonomyRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// 테스트용 앱을 만들어 돌려줍니다.
  Widget makeApp() {
    return ReferenceArchiveApp(
      referenceRepository: repository,
      taxonomyRepository: taxonomyRepository,
      boardRepository: LocalBoardRepository(db),
      imageStorage: FakeImageStorage(),
      imageSource: FakeImageSource(),
      youtubeInfoSource: FakeYoutubeInfoSource(),
      settings: AppSettings(),
    );
  }

  /// 화면을 [size]로 만들고 앱을 띄웁니다.
  Future<void> openApp(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();
  }

  /// 테스트용 레퍼런스를 하나 저장하고 돌려줍니다.
  Future<ReferenceItem> saveReference(String title) async {
    final DateTime now = DateTime.now().toUtc();
    final ReferenceItem item = ReferenceItem(
      id: newId(),
      type: ReferenceType.image,
      title: title,
      fileName: 'not-a-real-file.jpg',
      createdAt: now,
      updatedAt: now,
    );
    await repository.save(item);
    return item;
  }

  testWidgets('넓은 화면에서는 대화상자로 뜬다', (WidgetTester tester) async {
    await saveReference('노을 사진');

    // sidebarBreakpoint(900)보다 넓은 화면입니다.
    await openApp(tester, const Size(1400, 900));

    await tester.tap(find.text('노을 사진'));
    await tester.pumpAndSettle();

    // 대화상자로 떴으면 AlertDialog가 있고, 뒤쪽 목록 화면은
    // 그대로 화면에 남아 있습니다(가려질 뿐 사라지지 않습니다).
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.widgetWithText(TextField, '노을 사진'),
      findsOneWidget,
      reason: '대화상자 안에 제목 입력창이 있어야 합니다',
    );

    // 취소를 누르면 저장 없이 닫힙니다.
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    // 목록 화면으로 돌아와 있어야 합니다.
    expect(find.text('노을 사진'), findsOneWidget);
  });

  testWidgets('좁은 화면(폰)에서는 화면 전체로 뜬다', (WidgetTester tester) async {
    await saveReference('노을 사진');

    // sidebarBreakpoint(900)보다 좁은 화면입니다.
    await openApp(tester, const Size(700, 900));

    await tester.tap(find.text('노을 사진'));
    await tester.pumpAndSettle();

    // 대화상자가 아니라 화면 전체(AppBar가 있는 새 화면)로 떠야 합니다.
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.widgetWithText(AppBar, '레퍼런스 편집'), findsOneWidget);

    // 뒤로 가면 원래 목록으로 돌아옵니다.
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '레퍼런스 편집'), findsNothing);
  });
}
