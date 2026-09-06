// 사이드바에서 폴더를 골라 레퍼런스를 나눠 보는 흐름을 확인하는 테스트입니다.
//
// ── 폴더가 다른 분류와 다른 점 (사이드바에 있을 때) ──
// 카테고리·태그는 목록 위에서 잠깐 걸었다 푸는 **조건**이지만, 폴더는
// 사이드바에서 고르는 **지금 보고 있는 자리**에 가깝습니다(2026-09-06
// 이전에는 이 역할을 파트가 맡았습니다 — CLAUDE.md "단계 밖 작업: 파트를
// 없애고 사이드바를 폴더로 바꾸기" 참고). 그래서 다르게 다뤄야 하는
// 곳이 있고, 그 부분을 여기서 확인합니다.
//
//   - 폴더를 고른 채로 새 레퍼런스를 넣으면 **그 폴더에** 들어가야 합니다
//   - "조건 지우기"를 눌러도 **폴더는 유지**돼야 합니다

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/main.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';
import 'package:reference_archive_app/repositories/local_board_repository.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/repositories/local_taxonomy_repository.dart';
import 'package:reference_archive_app/services/app_settings.dart';
import 'package:reference_archive_app/utils/id_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_image_source.dart';
import '../fakes/fake_image_storage.dart';
import '../fakes/fake_youtube_info_source.dart';

void main() {
  late AppDatabase db;
  late LocalReferenceRepository repository;
  late LocalTaxonomyRepository taxonomyRepository;
  late FakeImageSource imageSource;
  late AppSettings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalReferenceRepository(db);
    taxonomyRepository = LocalTaxonomyRepository(db);
    imageSource = FakeImageSource();

    settings = AppSettings();
    await settings.load();
  });

  tearDown(() async {
    await db.close();
  });

  /// 테스트용 화면을 넓게 만듭니다. 사이드바가 늘 펼쳐져 있어야 폴더를 누를 수 있습니다.
  void useWideScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// 테스트용 앱을 만들어 돌려줍니다.
  Widget makeApp() {
    return ReferenceArchiveApp(
      referenceRepository: repository,
      taxonomyRepository: taxonomyRepository,
      boardRepository: LocalBoardRepository(db),
      imageStorage: FakeImageStorage(),
      imageSource: imageSource,
      youtubeInfoSource: FakeYoutubeInfoSource(),
      settings: settings,
    );
  }

  /// 화면을 띄우고 다 그려질 때까지 기다립니다.
  Future<void> openApp(WidgetTester tester) async {
    useWideScreen(tester);
    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();
  }

  /// 폴더를 하나 만들고 그 id를 돌려줍니다.
  Future<String> saveFolder(String name) async {
    final DateTime now = DateTime.now().toUtc();
    final TaxonomyItem item = TaxonomyItem(
      id: newId(),
      kind: TaxonomyKind.folder,
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    await taxonomyRepository.save(item);
    return item.id;
  }

  /// 레퍼런스를 하나 저장합니다.
  Future<void> saveReference({required String title, String? folderId}) async {
    final DateTime now = DateTime.now().toUtc();
    await repository.save(
      ReferenceItem(
        id: newId(),
        type: ReferenceType.image,
        title: title,
        folderId: folderId,
        fileName: 'not-a-real-file.jpg',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  testWidgets('폴더가 하나도 없으면 "전체 레퍼런스"만 보인다', (WidgetTester tester) async {
    await openApp(tester);

    expect(find.text('전체 레퍼런스'), findsOneWidget);
  });

  testWidgets('만든 폴더가 사이드바에 보인다', (WidgetTester tester) async {
    await saveFolder('겨울 프로젝트');

    await openApp(tester);

    expect(find.text('겨울 프로젝트'), findsOneWidget);
  });

  testWidgets('폴더를 고르면 그 폴더 것만 보인다', (WidgetTester tester) async {
    final String winterId = await saveFolder('겨울 프로젝트');

    await saveReference(title: '미분류 사진');
    await saveReference(title: '겨울 사진', folderId: winterId);

    await openApp(tester);

    // 처음에는 "전체"라 둘 다 보입니다.
    expect(find.text('미분류 사진'), findsOneWidget);
    expect(find.text('겨울 사진'), findsOneWidget);

    await tester.tap(find.text('겨울 프로젝트'));
    await tester.pumpAndSettle();

    expect(find.text('겨울 사진'), findsOneWidget);
    expect(find.text('미분류 사진'), findsNothing);
  });

  testWidgets('"전체 레퍼런스"를 고르면 다시 다 보인다', (WidgetTester tester) async {
    final String winterId = await saveFolder('겨울 프로젝트');
    await saveReference(title: '미분류 사진');
    await saveReference(title: '겨울 사진', folderId: winterId);

    await openApp(tester);

    await tester.tap(find.text('겨울 프로젝트'));
    await tester.pumpAndSettle();
    expect(find.text('미분류 사진'), findsNothing);

    await tester.tap(find.text('전체 레퍼런스'));
    await tester.pumpAndSettle();

    expect(find.text('미분류 사진'), findsOneWidget);
    expect(find.text('겨울 사진'), findsOneWidget);
  });

  testWidgets('폴더를 고른 채로 넣으면 그 폴더에 들어간다', (WidgetTester tester) async {
    // ── 이게 이 파일의 핵심입니다 ──
    // "겨울 프로젝트" 폴더를 보면서 사진을 넣었는데 미분류로 들어가면,
    // 방금 넣은 것이 화면에서 곧바로 사라집니다. 사용자는 저장이 안 된 줄 압니다.
    final String winterId = await saveFolder('겨울 프로젝트');

    imageSource.hasClipboardImage = true;

    await openApp(tester);

    await tester.tap(find.text('겨울 프로젝트'));
    await tester.pumpAndSettle();

    // 붙여넣기로 하나 넣습니다.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.length, 1);
    expect(items.first.folderId, winterId);
  });

  testWidgets('"전체"를 보면서 넣으면 미분류로 들어간다', (WidgetTester tester) async {
    // "전체"는 자리가 아니라 보기 방식이라 거기에 넣을 수는 없습니다.
    imageSource.hasClipboardImage = true;

    await openApp(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.length, 1);
    expect(items.first.folderId, isNull);
  });

  testWidgets('폴더를 고른 채로 검색해도 그 폴더 안에서만 찾는다', (WidgetTester tester) async {
    final String winterId = await saveFolder('겨울 프로젝트');
    await saveReference(title: '노을 미분류');
    await saveReference(title: '노을 겨울', folderId: winterId);

    await openApp(tester);

    await tester.tap(find.text('겨울 프로젝트'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '노을');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('노을 겨울'), findsOneWidget);
    expect(find.text('노을 미분류'), findsNothing);
  });

  testWidgets('"조건 지우기"를 눌러도 보고 있던 폴더는 그대로다', (WidgetTester tester) async {
    // 조건을 지웠다고 보고 있던 자리에서 튕겨 나가면 당황스럽습니다.
    final String winterId = await saveFolder('겨울 프로젝트');
    await saveReference(title: '미분류 사진');
    await saveReference(title: '겨울 사진', folderId: winterId);

    await openApp(tester);

    await tester.tap(find.text('겨울 프로젝트'));
    await tester.pumpAndSettle();

    // 검색어를 넣어 "조건 지우기" 버튼이 나오게 합니다.
    await tester.enterText(find.byType(TextField).first, '겨울');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('조건 지우기'));
    await tester.pumpAndSettle();

    // 검색어는 풀렸지만 폴더는 그대로여야 합니다.
    expect(find.text('겨울 사진'), findsOneWidget);
    expect(find.text('미분류 사진'), findsNothing);

    // 검색 입력창도 함께 비워져야 합니다.
    final TextField searchField = tester.widget<TextField>(
      find.byType(TextField).first,
    );
    expect(searchField.controller?.text, isEmpty);
  });

  testWidgets('폴더는 위쪽 필터 줄에 나오지 않는다', (WidgetTester tester) async {
    // 같은 것을 두 군데서 고르면 "어느 쪽이 진짜지?" 하게 됩니다.
    // 폴더는 사이드바에서만 고릅니다.
    await saveFolder('겨울 프로젝트');

    await openApp(tester);

    // 필터 줄의 버튼들은 "카테고리"/"태그"처럼 종류 이름으로 뜹니다.
    // 폴더 버튼이 있으면 안 됩니다.
    expect(
      find.widgetWithText(OutlinedButton, TaxonomyKind.folder.displayName),
      findsNothing,
    );
  });
}
