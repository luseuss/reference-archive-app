// 붙여넣기(Ctrl+V)로 레퍼런스를 추가하는 흐름을 확인하는 테스트입니다.
//
// 끌어다 놓기는 운영체제가 만드는 동작이라 테스트에서 흉내낼 수 없습니다.
// 다만 떨어진 것을 읽는 부분(DroppedItemReader)은 따로 테스트되어 있고,
// 저장하는 부분은 붙여넣기와 **똑같은 함수를 공유**하므로,
// 여기서 붙여넣기가 되면 끌어다 놓기도 같은 경로를 지나갑니다.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/main.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/repositories/local_taxonomy_repository.dart';
import 'package:reference_archive_app/services/app_settings.dart';

import '../fakes/fake_image_source.dart';
import '../fakes/fake_image_storage.dart';
import '../fakes/fake_youtube_info_source.dart';

void main() {
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

  /// 테스트용 앱을 만들어 돌려줍니다.
  Widget makeApp() {
    return ReferenceArchiveApp(
      referenceRepository: repository,
      taxonomyRepository: taxonomyRepository,
      imageStorage: imageStorage,
      imageSource: imageSource,
      youtubeInfoSource: youtubeInfoSource,
      settings: AppSettings(),
    );
  }

  /// Ctrl+V를 눌렀을 때와 같은 키 입력을 흘려보냅니다.
  Future<void> pressPaste(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
  }

  testWidgets('클립보드에 이미지가 있으면 붙여넣기로 추가된다', (WidgetTester tester) async {
    imageSource.hasClipboardImage = true;

    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();

    expect(find.text('아직 모아둔 레퍼런스가 없습니다'), findsOneWidget);

    await pressPaste(tester);

    expect(find.text('1장 추가했습니다.'), findsOneWidget);

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.length, 1);
    // 클립보드 이미지는 제목을 뽑을 데가 없어서 빈 제목입니다.
    expect(items.first.title, '');
  });

  testWidgets('클립보드에 이미지 주소가 있으면 내려받아 추가된다', (WidgetTester tester) async {
    // 브라우저에서 "이미지 주소 복사"를 한 경우입니다.
    imageSource.hasClipboardImage = false;
    imageSource.clipboardText = 'https://example.com/photo.jpg';

    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();

    await pressPaste(tester);

    expect(imageSource.requestedUrl, 'https://example.com/photo.jpg');

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.length, 1);
    // 주소에서 뽑은 제목이 들어갑니다.
    expect(items.first.title, '내려받은것');
  });

  testWidgets('이미지가 우선이고 글자는 그다음이다', (WidgetTester tester) async {
    // 클립보드에 이미지와 글자가 둘 다 있으면 이미지를 씁니다.
    // 이미지를 복사했는데 예전 글자가 남아 있어 엉뚱한 걸 받아오면 안 됩니다.
    imageSource.hasClipboardImage = true;
    imageSource.clipboardText = 'https://example.com/other.jpg';

    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();

    await pressPaste(tester);

    // 주소를 건드리지 않았어야 합니다.
    expect(imageSource.requestedUrl, isNull);
    expect((await repository.getAll()).length, 1);
  });

  testWidgets('클립보드가 비었으면 무엇을 하면 되는지 알려준다', (WidgetTester tester) async {
    imageSource.hasClipboardImage = false;
    imageSource.clipboardText = null;

    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();

    await pressPaste(tester);

    // "실패했습니다"로 끝내면 사용자는 뭘 해야 할지 모릅니다.
    expect(find.textContaining('이미지 복사'), findsOneWidget);
    expect(await repository.getAll(), isEmpty);
  });

  testWidgets('클립보드 글자가 주소가 아니면 내려받지 않는다', (WidgetTester tester) async {
    imageSource.hasClipboardImage = false;
    imageSource.clipboardText = '그냥 복사해둔 글자';

    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();

    await pressPaste(tester);

    expect(imageSource.requestedUrl, isNull);
    expect(await repository.getAll(), isEmpty);
  });

  testWidgets('내려받기가 실패하면 그 이유를 보여준다', (WidgetTester tester) async {
    imageSource.hasClipboardImage = false;
    imageSource.clipboardText = 'https://example.com/photo.jpg';
    imageSource.succeedOnUrl = false;

    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();

    await pressPaste(tester);

    expect(find.text('내려받지 못했습니다.'), findsOneWidget);
    expect(await repository.getAll(), isEmpty);
  });

  testWidgets('그림이 아닌 데이터면 저장하지 않는다', (WidgetTester tester) async {
    // 클립보드에서 가져오긴 했는데 저장 단계에서 그림이 아니라고 판정된 경우입니다.
    imageSource.hasClipboardImage = true;
    imageStorage.failOnSave = true;

    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();

    await pressPaste(tester);

    expect(await repository.getAll(), isEmpty);
  });
}
