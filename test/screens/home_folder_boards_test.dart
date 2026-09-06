// 메인 화면에서 폴더를 고르면 나타나는 "무드보드" 버튼(이 폴더의
// 무드보드로 바로 넘어가는 지름길)을 확인하는 테스트입니다.
//
// 무드보드 목록 화면 자체가 폴더로 좁혀 보여주는 로직은
// test/screens/board_list_screen_test.dart에서 이미 확인했습니다.
// 여기서는 **메인 화면과 그 화면이 제대로 이어졌는지**만 봅니다.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/main.dart';
import 'package:reference_archive_app/models/board.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';
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
  late LocalBoardRepository boardRepository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalReferenceRepository(db);
    taxonomyRepository = LocalTaxonomyRepository(db);
    boardRepository = LocalBoardRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// 필터 버튼들이 화면 밖으로 나가지 않게 넓게 만듭니다.
  void useWideScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<String> saveFolder(String name) async {
    final DateTime now = DateTime.now().toUtc();
    final String id = newId();
    await taxonomyRepository.save(
      TaxonomyItem(
        id: id,
        kind: TaxonomyKind.folder,
        name: name,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Widget makeApp() {
    return ReferenceArchiveApp(
      referenceRepository: repository,
      taxonomyRepository: taxonomyRepository,
      boardRepository: boardRepository,
      imageStorage: FakeImageStorage(),
      imageSource: FakeImageSource(),
      youtubeInfoSource: FakeYoutubeInfoSource(),
      settings: AppSettings(),
    );
  }

  testWidgets('폴더를 고르지 않았으면 "무드보드" 버튼이 안 보인다', (
    WidgetTester tester,
  ) async {
    useWideScreen(tester);
    await saveFolder('겨울 프로젝트');

    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, '무드보드'), findsNothing);
  });

  testWidgets('폴더를 고르면 "무드보드" 버튼이 나타난다', (WidgetTester tester) async {
    useWideScreen(tester);
    await saveFolder('겨울 프로젝트');

    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '폴더'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('겨울 프로젝트').last);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, '무드보드'), findsOneWidget);
  });

  testWidgets('"무드보드" 버튼을 누르면 그 폴더로 좁혀진 무드보드 화면이 열린다', (
    WidgetTester tester,
  ) async {
    useWideScreen(tester);
    final String folderId = await saveFolder('겨울 프로젝트');
    final DateTime now = DateTime.now().toUtc();
    await boardRepository.saveBoard(
      Board(
        id: newId(),
        name: '겨울 무드',
        createdAt: now,
        updatedAt: now,
        folderId: folderId,
      ),
    );
    await boardRepository.saveBoard(
      Board(id: newId(), name: '미분류 무드', createdAt: now, updatedAt: now),
    );

    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '폴더'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('겨울 프로젝트').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '무드보드'));
    await tester.pumpAndSettle();

    expect(find.text('겨울 프로젝트의 무드보드'), findsOneWidget);
    expect(find.text('겨울 무드'), findsOneWidget);
    expect(find.text('미분류 무드'), findsNothing);
  });
}
