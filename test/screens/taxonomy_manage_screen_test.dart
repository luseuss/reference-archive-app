// 분류 관리 화면이 제대로 동작하는지 확인하는 테스트입니다.
//
// 특히 **삭제 확인 절차**를 꼼꼼히 봅니다. 분류를 지우면 그걸 쓰던 레퍼런스에서
// 조용히 연결이 끊기고 되돌릴 수 없기 때문에, 확인 없이 지워지거나 개수를
// 틀리게 알려주면 사용자가 실수로 데이터를 망가뜨리게 됩니다.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/repositories/local_taxonomy_repository.dart';
import 'package:reference_archive_app/screens/taxonomy_manage_screen.dart';
import 'package:reference_archive_app/utils/id_generator.dart';

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

  /// 테스트용 화면을 넓게 만듭니다.
  /// 기본 800x600에서는 목록 아래쪽이 화면 밖으로 나가 테스트가 못 찾습니다.
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// 테스트용 분류 항목을 만들어 저장하고 돌려줍니다.
  Future<TaxonomyItem> saveTaxonomy(TaxonomyKind kind, String name) async {
    final DateTime now = DateTime.now().toUtc();
    final TaxonomyItem item = TaxonomyItem(
      id: newId(),
      kind: kind,
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    await taxonomyRepository.save(item);
    return item;
  }

  /// 테스트용 레퍼런스를 하나 저장합니다.
  Future<void> saveReference({String? folderId, List<String> tagIds = const <String>[]}) async {
    final DateTime now = DateTime.now().toUtc();
    await repository.save(
      ReferenceItem(
        id: newId(),
        type: ReferenceType.image,
        title: '사진',
        folderId: folderId,
        tagIds: tagIds,
        fileName: '${newId()}.jpg',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// 관리 화면만 띄우는 테스트용 앱을 만들어 돌려줍니다.
  Widget makeScreen() {
    return MaterialApp(
      home: TaxonomyManageScreen(repository: taxonomyRepository),
    );
  }

  testWidgets('만들어둔 폴더가 목록에 보인다', (WidgetTester tester) async {
    useTallScreen(tester);
    await saveTaxonomy(TaxonomyKind.folder, '인물');
    await saveTaxonomy(TaxonomyKind.folder, '풍경');

    await tester.pumpWidget(makeScreen());
    await tester.pumpAndSettle();

    expect(find.text('인물'), findsOneWidget);
    expect(find.text('풍경'), findsOneWidget);
  });

  testWidgets('쓰는 레퍼런스 개수가 함께 보인다', (WidgetTester tester) async {
    useTallScreen(tester);
    final TaxonomyItem folder = await saveTaxonomy(TaxonomyKind.folder, '인물');
    await saveReference(folderId: folder.id);
    await saveReference(folderId: folder.id);

    await tester.pumpWidget(makeScreen());
    await tester.pumpAndSettle();

    expect(find.text('레퍼런스 2개에서 사용 중'), findsOneWidget);
  });

  testWidgets('안 쓰이는 항목은 "쓰는 레퍼런스 없음"으로 보인다', (WidgetTester tester) async {
    useTallScreen(tester);
    await saveTaxonomy(TaxonomyKind.folder, '빈 폴더');

    await tester.pumpWidget(makeScreen());
    await tester.pumpAndSettle();

    expect(find.text('쓰는 레퍼런스 없음'), findsOneWidget);
  });

  testWidgets('만들어둔 항목이 없으면 안내가 뜬다', (WidgetTester tester) async {
    useTallScreen(tester);

    await tester.pumpWidget(makeScreen());
    await tester.pumpAndSettle();

    expect(find.text('만들어둔 폴더가 없습니다'), findsOneWidget);
  });

  group('이름 바꾸기', () {
    testWidgets('이름을 바꾸면 목록과 데이터베이스에 반영된다', (WidgetTester tester) async {
      useTallScreen(tester);
      final TaxonomyItem folder = await saveTaxonomy(TaxonomyKind.folder, '인물');

      await tester.pumpWidget(makeScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '초상');
      await tester.tap(find.text('바꾸기'));
      await tester.pumpAndSettle();

      expect(find.text('초상'), findsOneWidget);
      expect(find.text('인물'), findsNothing);

      final TaxonomyItem? saved = await taxonomyRepository.getById(folder.id);
      expect(saved!.name, '초상');
    });

    testWidgets('같은 이름이 이미 있으면 막는다', (WidgetTester tester) async {
      useTallScreen(tester);
      await saveTaxonomy(TaxonomyKind.folder, '인물');
      await saveTaxonomy(TaxonomyKind.folder, '풍경');

      await tester.pumpWidget(makeScreen());
      await tester.pumpAndSettle();

      // 첫 항목("인물")의 이름 바꾸기를 누릅니다.
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '풍경');
      await tester.tap(find.text('바꾸기'));
      await tester.pumpAndSettle();

      expect(find.text('같은 이름의 폴더가 이미 있습니다.'), findsOneWidget);
    });

    testWidgets('이름을 안 바꾸고 저장해도 막히지 않는다', (WidgetTester tester) async {
      // excludeId로 자기 자신을 빼고 검사하지 않으면
      // "이미 있다"며 막히는 황당한 상황이 됩니다.
      useTallScreen(tester);
      await saveTaxonomy(TaxonomyKind.folder, '인물');

      await tester.pumpWidget(makeScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('바꾸기'));
      await tester.pumpAndSettle();

      // 대화상자가 그냥 닫히고 오류가 안 떠야 합니다.
      expect(find.text('같은 이름의 폴더가 이미 있습니다.'), findsNothing);
      expect(find.text('인물'), findsOneWidget);
    });
  });

  group('삭제 확인', () {
    testWidgets('쓰는 레퍼런스가 있으면 개수를 알려준다', (WidgetTester tester) async {
      useTallScreen(tester);
      final TaxonomyItem tag = await saveTaxonomy(TaxonomyKind.tag, '노을');
      await saveReference(tagIds: <String>[tag.id]);
      await saveReference(tagIds: <String>[tag.id]);
      await saveReference(tagIds: <String>[tag.id]);

      await tester.pumpWidget(makeScreen());
      await tester.pumpAndSettle();

      // 태그 탭으로 이동합니다.
      await tester.tap(find.text('태그'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.textContaining('레퍼런스가 3개 있습니다'), findsOneWidget);
      expect(find.textContaining('되돌릴 수 없습니다'), findsOneWidget);
    });

    testWidgets('취소하면 지워지지 않는다', (WidgetTester tester) async {
      useTallScreen(tester);
      final TaxonomyItem folder = await saveTaxonomy(TaxonomyKind.folder, '인물');
      await saveReference(folderId: folder.id);

      await tester.pumpWidget(makeScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(find.text('인물'), findsOneWidget);
      expect(await taxonomyRepository.getById(folder.id), isNotNull);
    });

    testWidgets('삭제를 누르면 지워진다', (WidgetTester tester) async {
      useTallScreen(tester);
      final TaxonomyItem folder = await saveTaxonomy(TaxonomyKind.folder, '인물');

      await tester.pumpWidget(makeScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, '삭제'));
      await tester.pumpAndSettle();

      expect(find.text('인물'), findsNothing);
      expect(await taxonomyRepository.getById(folder.id), isNull);
    });

    testWidgets('안 쓰이는 항목은 "쓰는 레퍼런스가 없습니다"로 안내한다', (WidgetTester tester) async {
      // "0개가 영향을 받습니다"는 읽는 사람을 불필요하게 긴장시킵니다.
      useTallScreen(tester);
      await saveTaxonomy(TaxonomyKind.folder, '빈 폴더');

      await tester.pumpWidget(makeScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.textContaining('쓰는 레퍼런스는 없습니다'), findsOneWidget);
      expect(find.textContaining('되돌릴 수 없습니다'), findsNothing);
    });

    testWidgets('폴더를 지워도 레퍼런스 자체는 살아남는다', (WidgetTester tester) async {
      useTallScreen(tester);
      final TaxonomyItem folder = await saveTaxonomy(TaxonomyKind.folder, '인물');
      await saveReference(folderId: folder.id);

      await tester.pumpWidget(makeScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '삭제'));
      await tester.pumpAndSettle();

      // 레퍼런스는 남고 폴더 연결만 끊겨야 합니다.
      final List<ReferenceItem> items = await repository.getAll();
      expect(items.length, 1);
      expect(items.first.folderId, isNull);
    });
  });

  testWidgets('새로 만들기로 항목을 추가할 수 있다', (WidgetTester tester) async {
    useTallScreen(tester);

    await tester.pumpWidget(makeScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('새로 만들기'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '건축');
    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();

    expect(find.text('건축'), findsOneWidget);

    final List<TaxonomyItem> folders =
        await taxonomyRepository.getAll(TaxonomyKind.folder);
    expect(folders.first.name, '건축');
  });

  group('파트 탭', () {
    /// 파트 탭을 엽니다. 파트는 목록의 다섯 번째(마지막) 탭입니다.
    Future<void> openPartTab(WidgetTester tester) async {
      await tester.tap(find.text('파트'));
      await tester.pumpAndSettle();
    }

    testWidgets('기본 파트가 항상 목록에 보인다', (WidgetTester tester) async {
      useTallScreen(tester);

      await tester.pumpWidget(makeScreen());
      await tester.pumpAndSettle();
      await openPartTab(tester);

      expect(find.text(defaultPartName), findsOneWidget);
    });

    testWidgets('기본 파트의 삭제 버튼은 눌리지 않는다', (WidgetTester tester) async {
      // ── 이게 이 그룹의 핵심입니다 ──
      useTallScreen(tester);

      await tester.pumpWidget(makeScreen());
      await tester.pumpAndSettle();
      await openPartTab(tester);

      final IconButton deleteButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_outline),
      );
      expect(deleteButton.onPressed, isNull, reason: '기본 파트는 지울 수 없어야 합니다');

      // 눌러봐도 목록에 여전히 남아 있어야 합니다.
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text(defaultPartName), findsOneWidget);
    });

    testWidgets('사용자가 만든 파트는 지울 수 있다', (WidgetTester tester) async {
      useTallScreen(tester);
      await saveTaxonomy(TaxonomyKind.part, '파티클');

      await tester.pumpWidget(makeScreen());
      await tester.pumpAndSettle();
      await openPartTab(tester);

      // 목록 순서는 이름 가나다순입니다. "기본"과 "파티클" 중 두 번째 삭제
      // 버튼이 사용자가 만든 파트의 것입니다.
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '삭제'));
      await tester.pumpAndSettle();

      expect(find.text('파티클'), findsNothing);
    });

    testWidgets('파트를 지우면 안내에 "기본 파트로 옮겨진다"고 적힌다', (WidgetTester tester) async {
      // 다른 분류의 "연결이 끊긴다" 문구를 그대로 쓰면, 사진이 어디론가
      // 사라지는 줄 알고 못 지웁니다. 어디로 가는지 알려줘야 합니다.
      useTallScreen(tester);
      final TaxonomyItem part = await saveTaxonomy(TaxonomyKind.part, '파티클');
      await saveReference(folderId: null);
      // saveReference는 folderId만 받으므로, 레퍼런스에 파트를 직접 붙입니다.
      await repository.save(
        ReferenceItem(
          id: newId(),
          type: ReferenceType.image,
          title: '불꽃',
          partId: part.id,
          fileName: '${newId()}.jpg',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      await tester.pumpWidget(makeScreen());
      await tester.pumpAndSettle();
      await openPartTab(tester);

      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('"$defaultPartName" 파트로 옮겨집니다'),
        findsOneWidget,
      );
    });

    testWidgets('파트를 지우면 레퍼런스가 기본 파트로 옮겨진다', (WidgetTester tester) async {
      useTallScreen(tester);
      final TaxonomyItem part = await saveTaxonomy(TaxonomyKind.part, '파티클');
      final DateTime now = DateTime.now().toUtc();
      final ReferenceItem photo = ReferenceItem(
        id: newId(),
        type: ReferenceType.image,
        title: '불꽃',
        partId: part.id,
        fileName: '${newId()}.jpg',
        createdAt: now,
        updatedAt: now,
      );
      await repository.save(photo);

      await tester.pumpWidget(makeScreen());
      await tester.pumpAndSettle();
      await openPartTab(tester);

      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '삭제'));
      await tester.pumpAndSettle();

      final ReferenceItem? saved = await repository.getById(photo.id);
      expect(saved!.partId, defaultPartId);
    });
  });
}
