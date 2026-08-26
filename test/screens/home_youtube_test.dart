// 목록 화면에서 유튜브 영상을 추가하는 흐름을 확인하는 테스트입니다.
//
// 주소를 뜯어보는 부분(youtube_url.dart)과 유튜브에서 정보를 가져오는 부분
// (youtube_info_source.dart)은 각자 테스트가 따로 있습니다.
// 여기서는 **화면과 그것들이 제대로 이어졌는지**를 봅니다.
//
// 특히 중요한 것: 유튜브 주소를 붙여넣었을 때 **이미지로 내려받으려 하지 않는지**입니다.
// 유튜브 페이지를 내려받아 봐야 HTML이라 "그림이 아니다"로 실패합니다.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/main.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/repositories/local_taxonomy_repository.dart';

import '../fakes/fake_image_source.dart';
import '../fakes/fake_image_storage.dart';
import '../fakes/fake_youtube_info_source.dart';

void main() {
  const String videoId = 'dQw4w9WgXcQ';
  const String videoUrl = 'https://www.youtube.com/watch?v=$videoId';

  late AppDatabase db;
  late LocalReferenceRepository repository;
  late LocalTaxonomyRepository taxonomyRepository;
  late FakeImageSource imageSource;
  late FakeImageStorage imageStorage;
  late FakeYoutubeInfoSource youtubeInfoSource;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalReferenceRepository(db);
    taxonomyRepository = LocalTaxonomyRepository(db);
    imageSource = FakeImageSource();
    imageStorage = FakeImageStorage();
    youtubeInfoSource = FakeYoutubeInfoSource();
  });

  tearDown(() async {
    await db.close();
  });

  /// 테스트용 화면을 넓게 만듭니다.
  ///
  /// 기본 800x600에서는 버튼이 화면 밖으로 나가는데,
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
      imageStorage: imageStorage,
      imageSource: imageSource,
      youtubeInfoSource: youtubeInfoSource,
    );
  }

  /// 화면을 띄우고 다 그려질 때까지 기다립니다.
  Future<void> openApp(WidgetTester tester) async {
    useWideScreen(tester);
    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();
  }

  /// 오른쪽 아래 유튜브 버튼을 눌러 대화상자를 엽니다.
  Future<void> openYoutubeDialog(WidgetTester tester) async {
    await tester.tap(find.byTooltip('유튜브 영상 추가'));
    await tester.pumpAndSettle();
  }

  /// 대화상자에 주소를 적고 "추가"를 누릅니다.
  Future<void> submitUrl(WidgetTester tester, String url) async {
    await tester.enterText(find.byType(TextField).last, url);
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pumpAndSettle();
  }

  /// Ctrl+V를 눌렀을 때와 같은 키 입력을 흘려보냅니다.
  Future<void> pressPaste(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
  }

  group('대화상자로 추가하기', () {
    testWidgets('주소를 넣으면 유튜브 레퍼런스가 저장된다', (WidgetTester tester) async {
      await openApp(tester);
      await openYoutubeDialog(tester);
      await submitUrl(tester, videoUrl);

      final List<ReferenceItem> items = await repository.getAll();
      expect(items.length, 1);

      final ReferenceItem saved = items.first;
      expect(saved.type, ReferenceType.youtube);
      // 주소 전체가 아니라 영상 번호만 저장합니다.
      expect(saved.youtubeVideoId, videoId);
      // 제목은 유튜브에서 가져온 것이 들어갑니다.
      expect(saved.title, '가짜 영상 제목');
    });

    testWidgets('썸네일을 파일로 저장해둔다', (WidgetTester tester) async {
      // 화면에 띄울 때마다 유튜브에서 가져오지 않고 파일로 갖고 있어야
      // 인터넷이 없을 때도 목록이 보입니다.
      await openApp(tester);
      await openYoutubeDialog(tester);
      await submitUrl(tester, videoUrl);

      final ReferenceItem saved = (await repository.getAll()).first;
      expect(saved.fileName, isNotNull);
      expect(imageStorage.saveCallCount, 1);
    });

    testWidgets('썸네일을 못 가져와도 저장은 된다', (WidgetTester tester) async {
      // 오래된 영상이거나 인터넷이 끊긴 경우입니다.
      // 여기서 실패시키면 멀쩡한 영상을 못 넣게 됩니다.
      youtubeInfoSource.hasThumbnail = false;

      await openApp(tester);
      await openYoutubeDialog(tester);
      await submitUrl(tester, videoUrl);

      final List<ReferenceItem> items = await repository.getAll();
      expect(items.length, 1);
      expect(items.first.youtubeVideoId, videoId);
      expect(items.first.fileName, isNull);
    });

    testWidgets('제목을 못 가져와도 저장은 된다', (WidgetTester tester) async {
      // 비공개 영상이면 제목을 알 수 없습니다. 제목은 나중에 직접 적으면 됩니다.
      youtubeInfoSource.title = '';

      await openApp(tester);
      await openYoutubeDialog(tester);
      await submitUrl(tester, videoUrl);

      final List<ReferenceItem> items = await repository.getAll();
      expect(items.length, 1);
      expect(items.first.title, '');
      // 목록에서는 "(제목 없음)"으로 보입니다.
      expect(find.text('(제목 없음)'), findsOneWidget);
    });

    testWidgets('짧은 주소(youtu.be)도 받는다', (WidgetTester tester) async {
      await openApp(tester);
      await openYoutubeDialog(tester);
      await submitUrl(tester, 'https://youtu.be/$videoId?si=AbCdEfGh');

      expect((await repository.getAll()).first.youtubeVideoId, videoId);
    });

    testWidgets('유튜브 주소가 아니면 무엇이 잘못됐는지 알려주고 저장하지 않는다', (
      WidgetTester tester,
    ) async {
      await openApp(tester);
      await openYoutubeDialog(tester);
      await submitUrl(tester, 'https://example.com/그냥주소');

      // 대화상자가 닫히지 않고 오류를 보여줍니다.
      expect(find.textContaining('유튜브 영상 주소가 아닙니다'), findsOneWidget);
      expect(await repository.getAll(), isEmpty);
      // 유튜브에 물어보지도 않았어야 합니다.
      expect(youtubeInfoSource.requestedVideoIds, isEmpty);
    });

    testWidgets('취소하면 아무것도 안 한다', (WidgetTester tester) async {
      await openApp(tester);
      await openYoutubeDialog(tester);

      await tester.enterText(find.byType(TextField).last, videoUrl);
      await tester.tap(find.widgetWithText(TextButton, '취소'));
      await tester.pumpAndSettle();

      expect(await repository.getAll(), isEmpty);
      expect(youtubeInfoSource.requestedVideoIds, isEmpty);
    });

    testWidgets('클립보드에 유튜브 주소가 있으면 미리 채워준다', (WidgetTester tester) async {
      // 방금 복사해온 것을 또 붙여넣게 하는 것은 번거롭기만 합니다.
      imageSource.clipboardText = videoUrl;

      await openApp(tester);
      await openYoutubeDialog(tester);

      expect(find.text(videoUrl), findsOneWidget);
    });

    testWidgets('클립보드가 유튜브 주소가 아니면 채우지 않는다', (WidgetTester tester) async {
      imageSource.clipboardText = 'https://example.com/photo.jpg';

      await openApp(tester);
      await openYoutubeDialog(tester);

      expect(find.text('https://example.com/photo.jpg'), findsNothing);
    });
  });

  group('붙여넣기로 추가하기', () {
    testWidgets('유튜브 주소를 붙여넣으면 영상으로 저장된다', (WidgetTester tester) async {
      imageSource.hasClipboardImage = false;
      imageSource.clipboardText = videoUrl;

      await openApp(tester);
      await pressPaste(tester);

      final List<ReferenceItem> items = await repository.getAll();
      expect(items.length, 1);
      expect(items.first.type, ReferenceType.youtube);
      expect(items.first.youtubeVideoId, videoId);
    });

    testWidgets('유튜브 주소를 이미지로 내려받으려 하지 않는다', (WidgetTester tester) async {
      // 이게 핵심입니다. 유튜브 페이지를 내려받아 봐야 HTML이라
      // "그림이 아니다"로 실패하고, 사용자는 이유를 알 수 없습니다.
      imageSource.hasClipboardImage = false;
      imageSource.clipboardText = videoUrl;

      await openApp(tester);
      await pressPaste(tester);

      expect(imageSource.requestedUrl, isNull);
    });

    testWidgets('클립보드에 이미지가 있으면 이미지가 우선이다', (WidgetTester tester) async {
      // 이미지를 복사했는데 예전에 복사해둔 유튜브 주소가 남아 있을 수 있습니다.
      imageSource.hasClipboardImage = true;
      imageSource.clipboardText = videoUrl;

      await openApp(tester);
      await pressPaste(tester);

      final List<ReferenceItem> items = await repository.getAll();
      expect(items.length, 1);
      expect(items.first.type, ReferenceType.image);
      expect(youtubeInfoSource.requestedVideoIds, isEmpty);
    });
  });

  group('목록에서 보이는 모습', () {
    testWidgets('유튜브 카드에는 재생 버튼이 보인다', (WidgetTester tester) async {
      await openApp(tester);
      await openYoutubeDialog(tester);
      await submitUrl(tester, videoUrl);

      expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    });

    testWidgets('이미지 카드에는 재생 버튼이 없다', (WidgetTester tester) async {
      imageSource.hasClipboardImage = true;

      await openApp(tester);
      await pressPaste(tester);

      expect(find.byIcon(Icons.play_circle_fill), findsNothing);
    });

    testWidgets('재생 버튼을 누르면 재생 화면이 열린다', (WidgetTester tester) async {
      await openApp(tester);
      await openYoutubeDialog(tester);
      await submitUrl(tester, videoUrl);

      await tester.tap(find.byIcon(Icons.play_circle_fill));
      await tester.pumpAndSettle();

      // 재생 화면에만 있는 버튼입니다.
      expect(find.byTooltip('브라우저에서 열기'), findsOneWidget);

      // ── 이 테스트가 확인하지 못하는 것 ──
      // 테스트에서는 웹뷰 부품이 안 켜지기 때문에, 실제로 영상이 재생되는지는
      // 여기서 알 수 없습니다. 확인되는 것은 "재생 버튼을 누르면 재생 화면으로
      // 간다"와 "웹뷰를 못 쓰는 환경에서도 화면이 깨지지 않고 브라우저로 갈
      // 길을 준다"까지입니다.
      //
      // 영상이 실제로 나오는지는 `flutter run -d windows`로 직접 봐야 합니다.
      expect(find.textContaining('앱 안에서 재생할 수 없습니다'), findsOneWidget);
    });

    testWidgets('고르기 모드에서는 재생 버튼이 숨는다', (WidgetTester tester) async {
      // 여러 장 고르는 중에 영상이 재생되기 시작하면 곤란합니다.
      await openApp(tester);
      await openYoutubeDialog(tester);
      await submitUrl(tester, videoUrl);

      await tester.tap(find.byTooltip('여러 장 고르기'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_circle_fill), findsNothing);
      expect(find.byType(Checkbox), findsOneWidget);
    });
  });
}
