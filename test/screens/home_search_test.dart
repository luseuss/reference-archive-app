// 목록 화면의 검색·필터·정렬이 화면에서 실제로 동작하는지 확인하는 테스트입니다.
//
// 검색 로직 자체(SQL)는 test/repositories/reference_search_test.dart에서
// 이미 검증했습니다. 여기서는 **화면과 검색이 제대로 연결됐는지**를 봅니다.
// 예를 들어 검색창에 글자를 넣으면 목록이 실제로 줄어드는지 같은 것입니다.

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
  /// 기본 800x600에서는 필터 버튼들이 화면 밖으로 나가는데,
  /// 화면 밖 위젯은 아예 만들어지지 않아서 테스트가 못 찾습니다.
  void useWideScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// 테스트용 레퍼런스를 하나 저장합니다.
  Future<ReferenceItem> saveReference({
    required String title,
    String? folderId,
    List<String> tagIds = const <String>[],
    bool isFavorite = false,
  }) async {
    final DateTime now = DateTime.now().toUtc();
    final ReferenceItem item = ReferenceItem(
      id: newId(),
      type: ReferenceType.image,
      title: title,
      folderId: folderId,
      tagIds: tagIds,
      isFavorite: isFavorite,
      fileName: 'not-a-real-file.jpg',
      createdAt: now,
      updatedAt: now,
    );
    await repository.save(item);
    return item;
  }

  /// 테스트용 분류 항목을 만들어 저장하고 그 id를 돌려줍니다.
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

  /// 화면에 그려진 위치를 "읽는 순서"를 나타내는 숫자 하나로 바꿔 돌려줍니다.
  ///
  /// 위에서 아래로, 같은 줄이면 왼쪽에서 오른쪽 순서입니다.
  /// 세로 위치에 큰 수를 곱해서, 줄이 다르면 무조건 그쪽이 먼저 오게 만듭니다.
  double readingOrderOf(WidgetTester tester, String text) {
    final Offset position = tester.getTopLeft(find.text(text));
    return position.dy * 100000 + position.dx;
  }

  /// 검색창에 글자를 넣고 디바운스가 끝날 때까지 기다립니다.
  ///
  /// 검색은 타이핑을 멈춘 뒤 300밀리초 있다가 실행되므로,
  /// 바로 확인하면 아직 안 바뀐 목록을 보게 됩니다.
  Future<void> typeSearch(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  group('검색', () {
    testWidgets('검색어를 넣으면 맞는 것만 남는다', (WidgetTester tester) async {
      useWideScreen(tester);
      await saveReference(title: '노을 사진');
      await saveReference(title: '건물 사진');

      await tester.pumpWidget(makeApp());
      await tester.pumpAndSettle();

      // 처음에는 둘 다 보입니다.
      expect(find.text('노을 사진'), findsOneWidget);
      expect(find.text('건물 사진'), findsOneWidget);

      await typeSearch(tester, '노을');

      expect(find.text('노을 사진'), findsOneWidget);
      expect(find.text('건물 사진'), findsNothing);
    });

    testWidgets('검색어를 지우면 다시 전부 나온다', (WidgetTester tester) async {
      useWideScreen(tester);
      await saveReference(title: '노을 사진');
      await saveReference(title: '건물 사진');

      await tester.pumpWidget(makeApp());
      await tester.pumpAndSettle();

      await typeSearch(tester, '노을');
      expect(find.text('건물 사진'), findsNothing);

      await typeSearch(tester, '');
      expect(find.text('건물 사진'), findsOneWidget);
    });

    testWidgets('결과가 없으면 "조건에 맞는 게 없다"고 안내한다', (WidgetTester tester) async {
      useWideScreen(tester);
      await saveReference(title: '노을 사진');

      await tester.pumpWidget(makeApp());
      await tester.pumpAndSettle();

      await typeSearch(tester, '없는단어');

      // "아직 아무것도 없습니다"가 아니라 조건 때문이라고 알려줘야 합니다.
      // 사진이 있는데 "아직 없다"고 하면 데이터가 날아간 줄 알고 놀랍니다.
      expect(find.text('조건에 맞는 레퍼런스가 없습니다'), findsOneWidget);
      expect(find.text('아직 모아둔 레퍼런스가 없습니다'), findsNothing);
    });

    testWidgets('레퍼런스가 아예 없으면 "아직 없다"고 안내한다', (WidgetTester tester) async {
      useWideScreen(tester);

      await tester.pumpWidget(makeApp());
      await tester.pumpAndSettle();

      expect(find.text('아직 모아둔 레퍼런스가 없습니다'), findsOneWidget);
      expect(find.text('조건에 맞는 레퍼런스가 없습니다'), findsNothing);
    });
  });

  group('필터', () {
    testWidgets('즐겨찾기 칩을 누르면 즐겨찾기한 것만 남는다', (WidgetTester tester) async {
      useWideScreen(tester);
      await saveReference(title: '즐겨찾기 한 것', isFavorite: true);
      await saveReference(title: '안 한 것');

      await tester.pumpWidget(makeApp());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, '즐겨찾기'));
      await tester.pumpAndSettle();

      expect(find.text('즐겨찾기 한 것'), findsOneWidget);
      expect(find.text('안 한 것'), findsNothing);
    });

    testWidgets('폴더 필터 메뉴에서 고르면 그 폴더 것만 남는다', (WidgetTester tester) async {
      useWideScreen(tester);
      final String folder = await saveTaxonomy(TaxonomyKind.folder, '인물');
      await saveReference(title: '인물 사진', folderId: folder);
      await saveReference(title: '풍경 사진');

      await tester.pumpWidget(makeApp());
      await tester.pumpAndSettle();

      // 필터 메뉴를 열고 폴더를 고릅니다.
      await tester.tap(find.widgetWithText(OutlinedButton, '폴더'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('인물').last);
      await tester.pumpAndSettle();

      expect(find.text('인물 사진'), findsOneWidget);
      expect(find.text('풍경 사진'), findsNothing);
    });

    testWidgets('만들어둔 분류가 없으면 그 필터 메뉴는 안 보인다', (WidgetTester tester) async {
      useWideScreen(tester);
      await saveReference(title: '사진');

      await tester.pumpWidget(makeApp());
      await tester.pumpAndSettle();

      // 눌러도 텅 빈 메뉴만 뜨면 사용자가 당황하므로 아예 숨깁니다.
      expect(find.widgetWithText(OutlinedButton, '폴더'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, '태그'), findsNothing);
    });

    testWidgets('"조건 지우기"를 누르면 검색어와 필터가 모두 풀린다', (WidgetTester tester) async {
      useWideScreen(tester);
      await saveReference(title: '노을 사진', isFavorite: true);
      await saveReference(title: '건물 사진');

      await tester.pumpWidget(makeApp());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, '즐겨찾기'));
      await tester.pumpAndSettle();
      await typeSearch(tester, '노을');

      expect(find.text('건물 사진'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, '조건 지우기'));
      await tester.pumpAndSettle();

      expect(find.text('건물 사진'), findsOneWidget);
      expect(find.text('노을 사진'), findsOneWidget);
    });
  });

  group('정렬', () {
    testWidgets('정렬 메뉴에서 제목순을 고르면 순서가 바뀐다', (WidgetTester tester) async {
      useWideScreen(tester);
      await saveReference(title: '하하하');
      await saveReference(title: '가나다');

      await tester.pumpWidget(makeApp());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, '최근 수정순'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('제목순').last);
      await tester.pumpAndSettle();

      // 버튼 이름이 고른 것으로 바뀌어야 지금 어떤 순서인지 알 수 있습니다.
      expect(find.widgetWithText(OutlinedButton, '제목순'), findsOneWidget);

      // 화면에 그려진 순서를 확인합니다.
      //
      // 격자라서 세로 위치(dy)만 비교하면 안 됩니다. 카드 두 개가 같은 줄에
      // 나란히 놓이면 dy가 똑같기 때문입니다. 그래서 "읽는 순서"
      // (위에서 아래로, 같은 줄이면 왼쪽에서 오른쪽으로)로 비교합니다.
      expect(readingOrderOf(tester, '가나다'), lessThan(readingOrderOf(tester, '하하하')));
    });
  });
}
