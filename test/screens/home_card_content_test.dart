// 카드에 폴더·카테고리·태그·메모·날짜가 제대로 보이는지 확인하는 테스트입니다.
//
// ── 여기서 특히 보는 것 ──
// 레퍼런스에는 폴더·카테고리·태그가 **id로만** 들어있습니다. 화면이 그 id를
// 이름으로 바꿔 카드에 넘겨줘야 하는데, 그 연결이 끊기면 카드에 아무것도
// 안 보이거나 알아볼 수 없는 id가 그대로 보입니다.
//
// 그리고 **없는 항목은 자리를 차지하지 않아야** 합니다. 폴더도 태그도 메모도
// 없는 레퍼런스가 흔한데, 빈 줄이 남으면 카드 높이가 들쭉날쭉해집니다.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/main.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/repositories/local_taxonomy_repository.dart';
import 'package:reference_archive_app/services/app_settings.dart';
import 'package:reference_archive_app/utils/date_format.dart';
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

  /// 테스트용 화면을 넓고 길게 만듭니다.
  ///
  /// 카드 내용이 많아지면 화면 밖으로 나가는데,
  /// 화면 밖 위젯은 아예 만들어지지 않아서 테스트가 못 찾습니다.
  void useBigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1600);
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
      settings: AppSettings(),
    );
  }

  /// 화면을 띄우고 다 그려질 때까지 기다립니다.
  Future<void> openApp(WidgetTester tester) async {
    useBigScreen(tester);
    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();
  }

  /// 테스트용 분류 항목을 하나 만들고 그 id를 돌려줍니다.
  Future<String> saveTaxonomy(TaxonomyKind kind, String name) async {
    final DateTime now = DateTime.now().toUtc();
    final TaxonomyItem item = TaxonomyItem(
      id: newId(),
      kind: kind,
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    await taxonomyRepository.save(item);
    return item.id;
  }

  /// 테스트용 레퍼런스를 하나 저장합니다.
  Future<ReferenceItem> saveReference({
    String title = '사진',
    String? folderId,
    String? categoryId,
    List<String> tagIds = const <String>[],
    String? memo,
    DateTime? createdAt,
  }) async {
    final DateTime now = createdAt ?? DateTime.now().toUtc();
    final ReferenceItem item = ReferenceItem(
      id: newId(),
      type: ReferenceType.image,
      title: title,
      folderId: folderId,
      categoryId: categoryId,
      tagIds: tagIds,
      memo: memo,
      fileName: 'not-a-real-file.jpg',
      createdAt: now,
      updatedAt: now,
    );
    await repository.save(item);
    return item;
  }

  testWidgets('폴더 이름이 카드에 보인다', (WidgetTester tester) async {
    final String folderId = await saveTaxonomy(TaxonomyKind.folder, '인물');
    await saveReference(folderId: folderId);

    await openApp(tester);

    // id가 아니라 이름이 보여야 합니다.
    expect(find.textContaining('인물'), findsOneWidget);
    expect(find.textContaining(folderId), findsNothing);
  });

  testWidgets('카테고리 이름이 카드에 보인다', (WidgetTester tester) async {
    final String categoryId = await saveTaxonomy(TaxonomyKind.category, '조명');
    await saveReference(categoryId: categoryId);

    await openApp(tester);

    expect(find.textContaining('조명'), findsOneWidget);
  });

  testWidgets('태그가 # 붙은 모양으로 보인다', (WidgetTester tester) async {
    final String sunset = await saveTaxonomy(TaxonomyKind.tag, '노을');
    final String sea = await saveTaxonomy(TaxonomyKind.tag, '바다');
    await saveReference(tagIds: <String>[sunset, sea]);

    await openApp(tester);

    expect(find.text('#노을'), findsOneWidget);
    expect(find.text('#바다'), findsOneWidget);
  });

  testWidgets('메모가 카드에 보인다', (WidgetTester tester) async {
    await saveReference(memo: '색감이 마음에 든다');

    await openApp(tester);

    expect(find.text('색감이 마음에 든다'), findsOneWidget);
  });

  testWidgets('넣은 날짜가 카드에 보인다', (WidgetTester tester) async {
    // 현지 시각으로 만든 뒤 UTC로 저장합니다. 실제 저장 경로와 같습니다.
    final DateTime created = DateTime(2026, 3, 9, 21, 40);
    await saveReference(createdAt: created.toUtc());

    await openApp(tester);

    // 저장은 UTC지만 화면에는 넣은 날(9일)이 보여야 합니다.
    expect(find.text(formatCardDate(created.toUtc())), findsOneWidget);
    expect(find.text('2026. 03. 09.'), findsOneWidget);
  });

  testWidgets('없는 항목은 아예 안 보인다', (WidgetTester tester) async {
    // 폴더도 카테고리도 태그도 메모도 없는, 가장 흔한 경우입니다.
    await saveReference(title: '그냥 사진');

    await openApp(tester);

    expect(find.text('그냥 사진'), findsOneWidget);

    // 빈 자리표시자가 남으면 안 됩니다.
    expect(find.textContaining('📁'), findsNothing);
    expect(find.textContaining('🏷'), findsNothing);
    expect(find.textContaining('#'), findsNothing);
  });

  testWidgets('메모가 공백뿐이면 안 보인다', (WidgetTester tester) async {
    // 편집 화면에서 메모를 지우면 빈 글자가 남을 수 있습니다.
    // 그걸 그대로 그리면 카드에 빈 줄만 생깁니다.
    await saveReference(memo: '   ');

    await openApp(tester);

    expect(find.textContaining('📁'), findsNothing);
  });

  testWidgets('이름을 못 찾는 태그는 건너뛴다', (WidgetTester tester) async {
    // 분류를 지운 직후처럼 잠깐 어긋날 수 있습니다.
    // 그때 빈 알약이나 알아볼 수 없는 id가 뜨면 안 됩니다.
    final String tagId = await saveTaxonomy(TaxonomyKind.tag, '노을');
    final ReferenceItem item = await saveReference(tagIds: <String>[tagId]);

    await taxonomyRepository.delete(tagId);

    await openApp(tester);

    expect(find.textContaining(tagId), findsNothing);
    expect(find.text('#'), findsNothing);
    // 카드 자체는 멀쩡히 보여야 합니다.
    expect(find.text(item.title), findsOneWidget);
  });

  testWidgets('분류 관리에서 이름을 바꾸면 카드에도 반영된다', (WidgetTester tester) async {
    // ── 이 테스트가 지키는 것 ──
    // 카드에 이름을 보여주려고 "id → 이름" 표를 **한 번 만들어두고** 씁니다.
    // 빠르지만, 이름이 바뀐 뒤 표를 다시 안 만들면 **카드에는 옛 이름이
    // 그대로 남습니다.** 사용자는 이름을 바꿨는데 안 바뀌었다고 느낍니다.
    final String tagId = await saveTaxonomy(TaxonomyKind.tag, '노을');
    await saveReference(tagIds: <String>[tagId]);

    await openApp(tester);
    expect(find.text('#노을'), findsOneWidget);

    // 실제 사용자가 하는 대로 분류 관리 화면에 들어가 이름을 바꿉니다.
    await tester.tap(find.widgetWithText(OutlinedButton, '분류 관리'));
    await tester.pumpAndSettle();

    // 태그 탭으로 옮깁니다.
    await tester.tap(find.text('태그'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '석양');
    await tester.tap(find.text('바꾸기'));
    await tester.pumpAndSettle();

    // 뒤로 나오면 목록 화면이 이름 표를 다시 만들어야 합니다.
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('#석양'), findsOneWidget);
    expect(find.text('#노을'), findsNothing);
  });
}
