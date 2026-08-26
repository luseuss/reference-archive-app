// 목록 화면에서 여러 장을 골라 한꺼번에 처리하는 흐름을 확인하는 테스트입니다.
//
// 데이터를 실제로 고치는 부분(moveManyToFolder 등)은
// test/repositories/reference_bulk_test.dart에서 이미 검증했습니다.
// 여기서는 **화면과 그 기능이 제대로 연결됐는지**를 봅니다.
// 예를 들어 카드를 눌러 고른 것이 정말 그 카드인지, 확인 대화상자에서
// 취소했을 때 정말 안 지워지는지 같은 것입니다.

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

  /// 테스트용 화면을 넓게 만듭니다.
  ///
  /// 기본 800x600에서는 카드나 버튼이 화면 밖으로 나가는데,
  /// 화면 밖 위젯은 아예 만들어지지 않아서 테스트가 못 찾습니다.
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
      imageStorage: FakeImageStorage(),
      imageSource: FakeImageSource(),
      youtubeInfoSource: FakeYoutubeInfoSource(),
    );
  }

  /// 테스트용 레퍼런스를 하나 저장하고 그 id를 돌려줍니다.
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

  /// 화면을 띄우고 목록이 다 그려질 때까지 기다립니다.
  Future<void> openApp(WidgetTester tester) async {
    useWideScreen(tester);
    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();
  }

  /// 위쪽 막대의 "여러 장 고르기" 버튼을 눌러 고르기 모드로 들어갑니다.
  Future<void> enterSelectionMode(WidgetTester tester) async {
    await tester.tap(find.byTooltip('여러 장 고르기'));
    await tester.pumpAndSettle();
  }

  /// 제목이 [title]인 카드를 눌러 고릅니다.
  Future<void> tapCard(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  /// 대화상자 안에서 [label]이 적힌 것을 누릅니다.
  ///
  /// 그냥 find.text로 찾으면 뒤에 깔린 화면의 같은 글자까지 걸릴 수 있어서,
  /// 대화상자 안쪽으로 범위를 좁혀서 찾습니다.
  Future<void> tapInDialog(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('고르기 버튼을 누르면 카드에 체크박스가 생긴다', (WidgetTester tester) async {
    await saveReference('A');
    await saveReference('B');
    await openApp(tester);

    // 평소에는 체크박스가 없습니다.
    expect(find.byType(Checkbox), findsNothing);

    await enterSelectionMode(tester);

    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(find.text('고를 카드를 눌러주세요'), findsOneWidget);
  });

  testWidgets('카드를 누르면 골라지고 개수가 보인다', (WidgetTester tester) async {
    await saveReference('A');
    await saveReference('B');
    await openApp(tester);
    await enterSelectionMode(tester);

    await tapCard(tester, 'A');
    expect(find.text('1장 선택'), findsOneWidget);

    await tapCard(tester, 'B');
    expect(find.text('2장 선택'), findsOneWidget);

    // 한 번 더 누르면 고르기가 풀립니다.
    await tapCard(tester, 'B');
    expect(find.text('1장 선택'), findsOneWidget);
  });

  testWidgets('체크박스를 직접 눌러도 한 번만 골라진다', (WidgetTester tester) async {
    // 체크박스는 카드(InkWell) 안에 있습니다. 누를 때 체크박스와 카드가
    // 둘 다 반응하면 두 번 뒤집혀서 아무 일도 안 일어난 것처럼 보입니다.
    await saveReference('A');
    await openApp(tester);
    await enterSelectionMode(tester);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(find.text('1장 선택'), findsOneWidget);
  });

  testWidgets('고르기 모드에서 카드를 눌러도 편집 화면이 열리지 않는다', (WidgetTester tester) async {
    // 이게 안 지켜지면 여러 장 고르기가 아예 불가능합니다.
    await saveReference('A');
    await openApp(tester);
    await enterSelectionMode(tester);

    await tapCard(tester, 'A');

    // 편집 화면에만 있는 버튼입니다. 목록 화면에 남아 있어야 합니다.
    expect(find.text('저장'), findsNothing);
    expect(find.text('1장 선택'), findsOneWidget);
  });

  testWidgets('카드를 길게 누르면 고르기 모드로 들어간다', (WidgetTester tester) async {
    // 폰에는 우클릭이 없어서 길게 누르기가 "여러 개 고르기"의 표준 방법입니다.
    await saveReference('A');
    await openApp(tester);

    await tester.longPress(find.text('A'));
    await tester.pumpAndSettle();

    expect(find.text('1장 선택'), findsOneWidget);
  });

  testWidgets('전체 선택과 전체 해제가 동작한다', (WidgetTester tester) async {
    await saveReference('A');
    await saveReference('B');
    await saveReference('C');
    await openApp(tester);
    await enterSelectionMode(tester);

    await tester.tap(find.byTooltip('전체 선택'));
    await tester.pumpAndSettle();
    expect(find.text('3장 선택'), findsOneWidget);

    // 전부 골랐으면 같은 버튼이 "전체 해제"로 바뀝니다.
    await tester.tap(find.byTooltip('전체 해제'));
    await tester.pumpAndSettle();
    expect(find.text('고를 카드를 눌러주세요'), findsOneWidget);
  });

  testWidgets('X를 누르면 고르기가 끝난다', (WidgetTester tester) async {
    await saveReference('A');
    await openApp(tester);
    await enterSelectionMode(tester);
    await tapCard(tester, 'A');

    await tester.tap(find.byTooltip('고르기 끝내기'));
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('레퍼런스 아카이브'), findsOneWidget);
  });

  testWidgets('고른 것들을 폴더로 옮긴다', (WidgetTester tester) async {
    final String folderId = await saveTaxonomy(TaxonomyKind.folder, '인물');
    final String movedId = await saveReference('A');
    final String untouchedId = await saveReference('B');

    await openApp(tester);
    await enterSelectionMode(tester);
    await tapCard(tester, 'A');

    await tester.tap(find.text('폴더 이동'));
    await tester.pumpAndSettle();

    await tapInDialog(tester, '인물');

    expect((await repository.getById(movedId))!.folderId, folderId);
    expect((await repository.getById(untouchedId))!.folderId, isNull);

    // 작업이 끝나면 고르기 모드가 꺼집니다.
    expect(find.byType(Checkbox), findsNothing);
    expect(find.textContaining('1장을 "인물"으로 옮겼습니다'), findsOneWidget);
  });

  testWidgets('"폴더 없음"을 고르면 폴더에서 빠진다', (WidgetTester tester) async {
    // 취소(대화상자를 그냥 닫기)와 구분되는지 보는 것이 핵심입니다.
    final String folderId = await saveTaxonomy(TaxonomyKind.folder, '인물');
    final String id = await saveReference('A');
    await repository.moveManyToFolder(<String>[id], folderId);

    await openApp(tester);
    await enterSelectionMode(tester);
    await tapCard(tester, 'A');

    await tester.tap(find.text('폴더 이동'));
    await tester.pumpAndSettle();

    await tapInDialog(tester, '폴더 없음');

    expect((await repository.getById(id))!.folderId, isNull);
  });

  testWidgets('폴더 이동을 취소하면 아무것도 안 바뀐다', (WidgetTester tester) async {
    await saveTaxonomy(TaxonomyKind.folder, '인물');
    final String id = await saveReference('A');

    await openApp(tester);
    await enterSelectionMode(tester);
    await tapCard(tester, 'A');

    await tester.tap(find.text('폴더 이동'));
    await tester.pumpAndSettle();

    await tapInDialog(tester, '취소');

    expect((await repository.getById(id))!.folderId, isNull);
    // 취소했으니 고르기 모드는 그대로 남아 있어야 합니다.
    expect(find.text('1장 선택'), findsOneWidget);
  });

  testWidgets('고른 것들에 태그를 붙인다', (WidgetTester tester) async {
    final String tagId = await saveTaxonomy(TaxonomyKind.tag, '노을');
    final String taggedA = await saveReference('A');
    final String taggedB = await saveReference('B');

    await openApp(tester);
    await enterSelectionMode(tester);
    await tapCard(tester, 'A');
    await tapCard(tester, 'B');

    await tester.tap(find.text('태그 추가'));
    await tester.pumpAndSettle();

    await tapInDialog(tester, '노을');

    expect((await repository.getById(taggedA))!.tagIds, <String>[tagId]);
    expect((await repository.getById(taggedB))!.tagIds, <String>[tagId]);
  });

  testWidgets('일괄 삭제는 확인을 받은 뒤에만 지운다', (WidgetTester tester) async {
    final String id = await saveReference('A');
    await openApp(tester);
    await enterSelectionMode(tester);
    await tapCard(tester, 'A');

    // 먼저 취소해봅니다.
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tapInDialog(tester, '취소');

    expect(await repository.getById(id), isNotNull);

    // 이번엔 확인합니다. 대화상자의 "삭제" 버튼을 눌러야 합니다.
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tapInDialog(tester, '삭제');

    expect(await repository.getById(id), isNull);
    expect(find.text('아직 모아둔 레퍼런스가 없습니다'), findsOneWidget);
  });

  testWidgets('폴더가 하나도 없으면 무엇을 하면 되는지 알려준다', (WidgetTester tester) async {
    // 빈 대화상자를 띄우면 사용자는 뭘 해야 할지 모릅니다.
    await saveReference('A');
    await openApp(tester);
    await enterSelectionMode(tester);
    await tapCard(tester, 'A');

    await tester.tap(find.text('폴더 이동'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('먼저'), findsOneWidget);
    expect(find.textContaining('폴더를 만들어주세요'), findsOneWidget);
  });

  testWidgets('하나도 안 골랐으면 작업 버튼이 잠긴다', (WidgetTester tester) async {
    await saveTaxonomy(TaxonomyKind.folder, '인물');
    await saveReference('A');
    await openApp(tester);
    await enterSelectionMode(tester);

    // 아무것도 안 고른 채로 눌러봅니다. 버튼이 잠겨 있어 대화상자가 안 떠야 합니다.
    await tester.tap(find.text('폴더 이동'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('검색으로 안 보이게 된 것은 선택에서 빠진다', (WidgetTester tester) async {
    // 안 보이는 것이 골라진 채로 남아 있으면, 보이는 것만 지우려다
    // 안 보이는 것까지 지우게 됩니다.
    await saveReference('노을 사진');
    await saveReference('인물 사진');

    await openApp(tester);
    await enterSelectionMode(tester);

    await tester.tap(find.byTooltip('전체 선택'));
    await tester.pumpAndSettle();
    expect(find.text('2장 선택'), findsOneWidget);

    // 검색어를 넣어 하나만 남깁니다. (디바운스 때문에 조금 기다립니다)
    await tester.enterText(find.byType(TextField).first, '노을');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('1장 선택'), findsOneWidget);
  });
}
