// 앱과 홈 화면이 제대로 그려지는지 확인하는 위젯 테스트입니다.
//
// 위젯 테스트 = 실제 창을 띄우지 않고 메모리 안에서 위젯을 그려본 뒤,
// 기대한 글자나 아이콘이 실제로 나오는지 확인하는 자동 검사입니다.
// 터미널에서 `flutter test` 로 실행합니다.
//
// 여기서는 진짜 데이터베이스 대신 메모리 데이터베이스를 씁니다.
// 그래서 테스트를 돌려도 실제로 저장해둔 레퍼런스는 바뀌지 않습니다.
//
// 화면을 고친 뒤 이 테스트가 실패한다면, 화면이 깨졌거나
// 이 테스트가 기대하는 문구가 바뀐 것입니다. 둘 중 어느 쪽인지 확인하세요.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/main.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/repositories/local_board_repository.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/repositories/local_taxonomy_repository.dart';
import 'package:reference_archive_app/services/app_settings.dart';
import 'fakes/fake_image_source.dart';
import 'fakes/fake_image_storage.dart';
import 'fakes/fake_youtube_info_source.dart';
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

  /// 테스트용 앱을 만들어 돌려주는 도우미 함수입니다.
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

  /// 테스트용 레퍼런스를 하나 저장합니다.
  Future<void> saveReference({String title = ''}) async {
    final DateTime now = DateTime.now().toUtc();
    await repository.save(
      ReferenceItem(
        id: newId(),
        type: ReferenceType.image,
        title: title,
        // 실제로 존재하지 않는 파일 이름입니다.
        // 카드가 파일을 못 찾아도 깨지지 않고 자리표시자를 보여주는지도 함께 확인됩니다.
        fileName: 'not-a-real-file.jpg',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  testWidgets('레퍼런스가 없으면 안내 문구가 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(makeApp());

    // pumpAndSettle = 화면이 다 그려지고 움직임이 멈출 때까지 기다립니다.
    // 목록을 불러오는 데 잠깐 걸리므로, 이게 없으면 로딩 중 화면만 보입니다.
    await tester.pumpAndSettle();

    expect(find.text('아직 모아둔 레퍼런스가 없습니다'), findsOneWidget);
    expect(find.text('이미지 추가'), findsOneWidget);
  });

  testWidgets('저장된 레퍼런스가 목록에 제목과 함께 보인다', (WidgetTester tester) async {
    await saveReference(title: '노을 사진');

    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();

    expect(find.text('노을 사진'), findsOneWidget);
    // 목록이 있으므로 빈 화면 안내는 사라져야 합니다.
    expect(find.text('아직 모아둔 레퍼런스가 없습니다'), findsNothing);
  });

  testWidgets('제목이 비어 있으면 "(제목 없음)"으로 보인다', (WidgetTester tester) async {
    await saveReference();

    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();

    expect(find.text('(제목 없음)'), findsOneWidget);
  });

  testWidgets('삭제 버튼을 누르면 목록에서 사라진다', (WidgetTester tester) async {
    await saveReference(title: '지울 사진');

    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();

    expect(find.text('지울 사진'), findsOneWidget);

    // 실제로 삭제 버튼을 눌러봅니다.
    // 기존 웹앱과 모양을 맞추면서 휴지통 아이콘이 "삭제" 글자 버튼으로 바뀌고,
    // 자리도 카드 맨 아래 날짜 옆으로 옮겨졌습니다.
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    // 목록에서 사라지고 빈 화면 안내가 다시 나와야 합니다.
    expect(find.text('지울 사진'), findsNothing);
    expect(find.text('아직 모아둔 레퍼런스가 없습니다'), findsOneWidget);

    // 화면뿐 아니라 데이터에서도 빠졌는지 확인합니다.
    expect(await repository.getAll(), isEmpty);
  });
}
