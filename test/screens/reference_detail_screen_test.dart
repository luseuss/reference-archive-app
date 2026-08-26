// 레퍼런스 상세/편집 화면이 제대로 동작하는지 확인하는 테스트입니다.
//
// 화면을 눌러보고 글자를 입력해본 뒤, **데이터베이스에 실제로 저장됐는지**까지
// 확인합니다. 화면에 보이는 것만 확인하면 "화면은 바뀌었는데 저장은 안 되는"
// 문제를 놓치게 됩니다.
//
// 터미널에서 `flutter test` 로 실행합니다.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/repositories/local_taxonomy_repository.dart';
import 'package:reference_archive_app/screens/reference_detail_screen.dart';
import 'package:reference_archive_app/utils/id_generator.dart';

import '../fakes/fake_image_storage.dart';

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

  /// 테스트용 화면을 세로로 길게 만듭니다.
  ///
  /// 위젯 테스트의 기본 화면은 800x600으로 작습니다. 편집 화면은 그보다 길어서
  /// 아래쪽(태그·프로젝트·스위치)이 화면 밖으로 나가는데, **화면 밖 위젯은 아예
  /// 만들어지지 않기 때문에** 테스트가 "그런 버튼 없다"며 실패합니다.
  ///
  /// 스크롤해서 찾는 방법도 있지만, 창을 크게 만들어 한 번에 다 보이게 하는 쪽이
  /// 테스트를 읽기 쉽고 덜 깨지게 합니다.
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;

    // 테스트가 끝나면 원래 크기로 되돌립니다.
    // 안 되돌리면 다음 테스트까지 이 크기가 남아 엉뚱한 결과가 나옵니다.
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// 테스트용 레퍼런스를 하나 만들어 저장하고 돌려줍니다.
  Future<ReferenceItem> saveReference({String title = '노을 사진'}) async {
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

  /// 테스트용 분류 항목을 하나 만들어 저장하고 돌려줍니다.
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

  /// 편집 화면만 띄우는 테스트용 앱을 만들어 돌려줍니다.
  Widget makeScreen(ReferenceItem item) {
    return MaterialApp(
      home: ReferenceDetailScreen(
        item: item,
        referenceRepository: repository,
        taxonomyRepository: taxonomyRepository,
        imageStorage: FakeImageStorage(),
      ),
    );
  }

  testWidgets('기존 제목과 메모가 입력창에 채워져 있다', (WidgetTester tester) async {
    final ReferenceItem item = await saveReference();
    final ReferenceItem withMemo = item.copyWith(memo: '색감 참고');
    await repository.save(withMemo);

    useTallScreen(tester);
    await tester.pumpWidget(makeScreen(withMemo));
    await tester.pumpAndSettle();

    expect(find.text('노을 사진'), findsOneWidget);
    expect(find.text('색감 참고'), findsOneWidget);
  });

  testWidgets('제목을 고치고 저장하면 데이터베이스에 반영된다', (WidgetTester tester) async {
    final ReferenceItem item = await saveReference();

    useTallScreen(tester);
    await tester.pumpWidget(makeScreen(item));
    await tester.pumpAndSettle();

    // 제목 입력창을 찾아 새 글자를 넣습니다.
    await tester.enterText(find.widgetWithText(TextField, '노을 사진'), '바뀐 제목');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    final ReferenceItem? saved = await repository.getById(item.id);
    expect(saved!.title, '바뀐 제목');
  });

  testWidgets('메모를 비우면 저장할 때 null이 된다', (WidgetTester tester) async {
    final ReferenceItem item = await saveReference();
    final ReferenceItem withMemo = item.copyWith(memo: '지울 메모');
    await repository.save(withMemo);

    useTallScreen(tester);
    await tester.pumpWidget(makeScreen(withMemo));
    await tester.pumpAndSettle();

    // 빈 글자와 "적지 않음"을 굳이 구분할 이유가 없어서 null로 저장합니다.
    await tester.enterText(find.widgetWithText(TextField, '지울 메모'), '');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    final ReferenceItem? saved = await repository.getById(item.id);
    expect(saved!.memo, isNull);
  });

  testWidgets('즐겨찾기와 고정을 켜고 저장하면 반영된다', (WidgetTester tester) async {
    final ReferenceItem item = await saveReference();

    useTallScreen(tester);
    await tester.pumpWidget(makeScreen(item));
    await tester.pumpAndSettle();

    await tester.tap(find.text('즐겨찾기'));
    await tester.tap(find.text('맨 위에 고정'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    final ReferenceItem? saved = await repository.getById(item.id);
    expect(saved!.isFavorite, isTrue);
    expect(saved.isPinned, isTrue);
  });

  testWidgets('태그 칩을 눌러 붙이면 저장된다', (WidgetTester tester) async {
    final ReferenceItem item = await saveReference();
    final TaxonomyItem tag = await saveTaxonomy(TaxonomyKind.tag, '노을');

    useTallScreen(tester);
    await tester.pumpWidget(makeScreen(item));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, '노을'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    final ReferenceItem? saved = await repository.getById(item.id);
    expect(saved!.tagIds, <String>[tag.id]);
  });

  testWidgets('이미 붙은 태그를 다시 누르면 떨어진다', (WidgetTester tester) async {
    final TaxonomyItem tag = await saveTaxonomy(TaxonomyKind.tag, '노을');
    final ReferenceItem item = await saveReference();
    await repository.save(item.copyWith(tagIds: <String>[tag.id]));

    final ReferenceItem? loaded = await repository.getById(item.id);

    useTallScreen(tester);
    await tester.pumpWidget(makeScreen(loaded!));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, '노을'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    final ReferenceItem? saved = await repository.getById(item.id);
    expect(saved!.tagIds, isEmpty);
  });

  testWidgets('폴더를 골라 저장하면 반영된다', (WidgetTester tester) async {
    final ReferenceItem item = await saveReference();
    final TaxonomyItem folder = await saveTaxonomy(TaxonomyKind.folder, '인물');

    useTallScreen(tester);
    await tester.pumpWidget(makeScreen(item));
    await tester.pumpAndSettle();

    // 폴더 드롭다운을 열고 항목을 고릅니다.
    await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('인물').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    final ReferenceItem? saved = await repository.getById(item.id);
    expect(saved!.folderId, folder.id);
  });

  testWidgets('폴더를 "없음"으로 바꾸면 폴더에서 빠진다', (WidgetTester tester) async {
    // copyWith는 null을 "안 바꿈"으로 취급해서, 빼내려면 clearFolder()를 써야 합니다.
    // 그 처리가 실제로 되는지 확인합니다.
    final TaxonomyItem folder = await saveTaxonomy(TaxonomyKind.folder, '인물');
    final ReferenceItem item = await saveReference();
    await repository.save(item.copyWith(folderId: folder.id));

    final ReferenceItem? loaded = await repository.getById(item.id);

    useTallScreen(tester);
    await tester.pumpWidget(makeScreen(loaded!));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('없음').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    final ReferenceItem? saved = await repository.getById(item.id);
    expect(saved!.folderId, isNull);
  });

  group('새 분류 항목 만들기', () {
    testWidgets('+ 칩으로 태그를 만들면 바로 골라진 상태가 된다', (WidgetTester tester) async {
      final ReferenceItem item = await saveReference();

      useTallScreen(tester);
      await tester.pumpWidget(makeScreen(item));
      await tester.pumpAndSettle();

      await tester.tap(find.text('새 태그'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '역광');
      await tester.tap(find.text('만들기'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      // 만든 뒤 또 고르게 하면 번거로우므로 바로 붙어 있어야 합니다.
      final ReferenceItem? saved = await repository.getById(item.id);
      expect(saved!.tagIds.length, 1);

      final List<TaxonomyItem> tags = await taxonomyRepository.getAll(TaxonomyKind.tag);
      expect(tags.first.name, '역광');
    });

    testWidgets('같은 이름이 이미 있으면 만들지 않고 알려준다', (WidgetTester tester) async {
      await saveTaxonomy(TaxonomyKind.tag, '노을');
      final ReferenceItem item = await saveReference();

      useTallScreen(tester);
      await tester.pumpWidget(makeScreen(item));
      await tester.pumpAndSettle();

      await tester.tap(find.text('새 태그'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '노을');
      await tester.tap(find.text('만들기'));
      await tester.pumpAndSettle();

      expect(find.text('같은 이름의 태그가 이미 있습니다.'), findsOneWidget);

      // 태그가 두 개로 늘어나지 않아야 합니다.
      final List<TaxonomyItem> tags = await taxonomyRepository.getAll(TaxonomyKind.tag);
      expect(tags.length, 1);
    });

    testWidgets('이름을 비우고 만들려 하면 알려준다', (WidgetTester tester) async {
      final ReferenceItem item = await saveReference();

      useTallScreen(tester);
      await tester.pumpWidget(makeScreen(item));
      await tester.pumpAndSettle();

      await tester.tap(find.text('새 태그'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('만들기'));
      await tester.pumpAndSettle();

      expect(find.text('이름을 입력해주세요.'), findsOneWidget);
    });
  });
}
