// 메인 목록에서 Delete 키로 지우고 Ctrl+Z로 되돌리는 흐름을 확인하는
// 테스트입니다.
//
// 낱장 삭제·일괄 삭제 자체(확인 대화상자 포함)는
// home_bulk_select_test.dart와 widget_test.dart가 이미 확인했습니다.
// 여기서는 **그 위에 새로 얹은 것**만 봅니다 — Delete 키가 기존 삭제
// 버튼과 똑같이 동작하는지, Ctrl+Z(또는 스낵바의 "실행취소" 버튼)를
// 누르면 지운 것이 정말 되살아나는지입니다.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// 화면을 넓게 만듭니다. 기본 크기에서는 카드·버튼이 화면 밖으로
  /// 나가서 테스트가 못 찾습니다.
  void useWideScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

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

  Future<void> openApp(WidgetTester tester) async {
    useWideScreen(tester);
    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();
  }

  Future<String> saveReference(String title) async {
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
    return item.id;
  }

  Future<void> enterSelectionMode(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(OutlinedButton, '고르기'));
    await tester.pumpAndSettle();
  }

  Future<void> tapCard(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  Future<void> tapInDialog(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text(label)),
    );
    await tester.pumpAndSettle();
  }

  /// Ctrl+Z를 눌렀을 때와 같은 키 입력을 흘려보냅니다.
  Future<void> pressUndo(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
  }

  /// Delete 키를 눌렀을 때와 같은 키 입력을 흘려보냅니다.
  Future<void> pressDelete(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
  }

  testWidgets('낱장을 지운 뒤 Ctrl+Z로 되돌린다', (WidgetTester tester) async {
    final String id = await saveReference('노을');
    await openApp(tester);

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(find.text('노을'), findsNothing);
    expect(await repository.getById(id), isNull);
    expect(find.text('지웠습니다.'), findsOneWidget);

    await pressUndo(tester);

    expect(find.text('노을'), findsOneWidget);
    expect(await repository.getById(id), isNotNull);
  });

  testWidgets('스낵바의 "실행취소" 버튼을 눌러도 똑같이 되돌아간다', (
    WidgetTester tester,
  ) async {
    final String id = await saveReference('노을');
    await openApp(tester);

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('실행취소'));
    await tester.pumpAndSettle();

    expect(find.text('노을'), findsOneWidget);
    expect(await repository.getById(id), isNotNull);
  });

  testWidgets('일괄 삭제를 되돌리면 고른 것 전부 되살아난다', (WidgetTester tester) async {
    final String idA = await saveReference('가');
    final String idB = await saveReference('나');
    await openApp(tester);

    await enterSelectionMode(tester);
    await tapCard(tester, '가');
    await tapCard(tester, '나');

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tapInDialog(tester, '삭제');

    expect(await repository.getById(idA), isNull);
    expect(await repository.getById(idB), isNull);

    await pressUndo(tester);

    expect(await repository.getById(idA), isNotNull);
    expect(await repository.getById(idB), isNotNull);
    expect(find.text('가'), findsOneWidget);
    expect(find.text('나'), findsOneWidget);
  });

  testWidgets('지운 적이 없으면 Ctrl+Z를 눌러도 아무 일도 안 난다', (
    WidgetTester tester,
  ) async {
    await saveReference('노을');
    await openApp(tester);

    await pressUndo(tester);

    // 오류 없이 그대로여야 합니다.
    expect(find.text('노을'), findsOneWidget);
  });

  testWidgets('한 번 되돌린 뒤 다시 Ctrl+Z를 눌러도 아무 일도 안 난다', (
    WidgetTester tester,
  ) async {
    final String id = await saveReference('노을');
    await openApp(tester);

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await pressUndo(tester);
    expect(await repository.getById(id), isNotNull);

    // 되돌릴 것이 이미 없는 상태에서 한 번 더 눌러도 문제없어야 합니다.
    await pressUndo(tester);
    expect(find.text('노을'), findsOneWidget);
  });

  testWidgets('고르기 모드가 아니면 Delete 키는 아무 일도 안 한다', (
    WidgetTester tester,
  ) async {
    await saveReference('노을');
    await openApp(tester);

    await pressDelete(tester);

    // 지울 대상(고른 것)이 없으니 그대로 남아야 합니다.
    expect(find.text('노을'), findsOneWidget);
  });

  testWidgets('고르기 모드에서 Delete 키는 고른 것을 지운다 (확인 포함)', (
    WidgetTester tester,
  ) async {
    final String id = await saveReference('노을');
    await openApp(tester);
    await enterSelectionMode(tester);
    await tapCard(tester, '노을');

    await pressDelete(tester);

    // 일괄 삭제는 확인을 받습니다 — 대화상자가 떠 있어야 합니다.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(await repository.getById(id), isNotNull, reason: '아직 확인 전입니다');

    await tapInDialog(tester, '삭제');

    expect(await repository.getById(id), isNull);
  });
}
