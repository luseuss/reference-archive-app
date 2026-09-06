// 휴지통 화면을 확인하는 테스트입니다.
//
// ── 여기서 특히 보는 것 ──
// **되살리기는 안 묻고, 영영 지우기는 반드시 묻는지**입니다. 이 화면에서
// 되돌릴 수 없는 일은 "영영 지우기"와 "휴지통 비우기" 둘뿐이라, 그 둘만
// 확인 대화상자를 거쳐야 합니다.
//
// 사진 파일이 실제로 지워지는지는 FakeImageStorage가 지운 파일 이름을
// 기록해두므로 그것으로 확인합니다.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/screens/trash_screen.dart';
import 'package:reference_archive_app/utils/id_generator.dart';

import '../fakes/fake_image_storage.dart';

void main() {
  late AppDatabase db;
  late LocalReferenceRepository repository;
  late FakeImageStorage imageStorage;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalReferenceRepository(db);
    imageStorage = FakeImageStorage();
  });

  tearDown(() async {
    await db.close();
  });

  /// 레퍼런스를 하나 저장했다가 지웁니다(= 휴지통에 넣습니다).
  Future<ReferenceItem> throwAway(String title) async {
    final DateTime now = DateTime.now().toUtc();
    final ReferenceItem item = ReferenceItem(
      id: newId(),
      type: ReferenceType.image,
      title: title,
      fileName: '$title.jpg',
      createdAt: now,
      updatedAt: now,
    );
    await repository.save(item);
    await repository.delete(item.id);
    return item;
  }

  /// 휴지통 화면을 띄우고 다 그려질 때까지 기다립니다.
  Future<void> openTrash(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: TrashScreen(repository: repository, imageStorage: imageStorage),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('지운 것이 없으면 안내가 보인다', (WidgetTester tester) async {
    await openTrash(tester);

    expect(find.text('휴지통이 비어 있습니다'), findsOneWidget);
  });

  testWidgets('지운 레퍼런스가 휴지통에 보인다', (WidgetTester tester) async {
    await throwAway('노을');

    await openTrash(tester);

    expect(find.text('노을'), findsOneWidget);
    expect(find.text('휴지통이 비어 있습니다'), findsNothing);
  });

  testWidgets('되살리기는 묻지 않고 바로 되살린다', (WidgetTester tester) async {
    // ── 이게 이 파일의 핵심 절반입니다 ──
    // 되돌리기 쉬운 일에까지 확인을 받으면, 사용자는 확인 창을 안 읽고
    // 누르는 버릇이 들어 정작 위험한 확인도 그냥 넘기게 됩니다.
    final ReferenceItem item = await throwAway('노을');

    await openTrash(tester);

    await tester.tap(find.text('되살리기'));
    await tester.pumpAndSettle();

    // 대화상자 없이 곧바로 처리되고, 목록에서 빠집니다.
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('휴지통이 비어 있습니다'), findsOneWidget);

    // 진짜로 되살아났는지 데이터로도 확인합니다.
    final List<ReferenceItem> alive = await repository.getAll();
    expect(alive.single.id, item.id);

    // 되살린 것뿐이므로 사진 파일은 지워지면 안 됩니다.
    expect(imageStorage.deletedFileNames, isEmpty);
  });

  testWidgets('영영 지우기는 반드시 확인을 받는다', (WidgetTester tester) async {
    // ── 이게 이 파일의 핵심 나머지 절반입니다 ──
    await throwAway('노을');

    await openTrash(tester);

    await tester.tap(find.byTooltip('영영 지우기'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('되돌릴 수 없습니다'), findsOneWidget);

    // 취소하면 아무 일도 안 일어나야 합니다.
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(find.text('노을'), findsOneWidget);
    expect(imageStorage.deletedFileNames, isEmpty);
    expect((await repository.getDeleted()).length, 1);
  });

  testWidgets('확인하면 사진 파일까지 영영 지운다', (WidgetTester tester) async {
    await throwAway('노을');

    await openTrash(tester);

    await tester.tap(find.byTooltip('영영 지우기'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '영영 지우기'));
    await tester.pumpAndSettle();

    expect(find.text('휴지통이 비어 있습니다'), findsOneWidget);
    expect(await repository.getDeleted(), isEmpty);

    // 사진 파일도 함께 지워져야 합니다. 안 지우면 계속 쌓이기만 합니다.
    expect(imageStorage.deletedFileNames, <String>['노을.jpg']);
  });

  testWidgets('휴지통 비우기는 확인을 받고 전부 지운다', (WidgetTester tester) async {
    await throwAway('가');
    await throwAway('나');

    await openTrash(tester);

    await tester.tap(find.text('휴지통 비우기'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2개가'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '비우기'));
    await tester.pumpAndSettle();

    expect(find.text('휴지통이 비어 있습니다'), findsOneWidget);
    expect(imageStorage.deletedFileNames.length, 2);
  });

  testWidgets('비어 있으면 휴지통 비우기를 누를 수 없다', (WidgetTester tester) async {
    // 눌러도 아무 일이 안 일어나는 것보다, 처음부터 못 누르게 하는 편이
    // 헷갈리지 않습니다(board_selection_bar.dart와 같은 기준).
    await openTrash(tester);

    final TextButton button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '휴지통 비우기'),
    );
    expect(button.onPressed, isNull);
  });
}
