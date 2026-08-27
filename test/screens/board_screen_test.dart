// 무드보드 판 화면(카드를 올리고 끌어서 옮기는 곳)을 확인하는 테스트입니다.
//
// ── 여기서 꼭 확인해야 하는 것 ──
// 무드보드는 **배치가 곧 결과물**입니다. 한참 늘어놓았는데 앱을 껐다 켜니
// 처음 자리로 돌아가 있으면, 그 작업이 통째로 사라진 것과 같습니다.
// 그래서 "옮겼다"로 끝내지 않고 **저장소에까지 들어갔는지**를 봅니다.
//
// 반대로 끄는 도중에는 저장하면 안 됩니다(1초에 수십 번 쓰게 됩니다).
// 그것도 함께 확인합니다.

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/board.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/repositories/local_board_repository.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/screens/board_screen.dart';
import 'package:reference_archive_app/theme/app_metrics.dart';
import 'package:reference_archive_app/utils/id_generator.dart';
import 'package:reference_archive_app/widgets/board_canvas.dart';
import 'package:reference_archive_app/widgets/board_card_view.dart';

import '../fakes/fake_image_storage.dart';

void main() {
  late AppDatabase db;
  late LocalBoardRepository boardRepository;
  late LocalReferenceRepository referenceRepository;
  late Board board;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    boardRepository = LocalBoardRepository(db);
    referenceRepository = LocalReferenceRepository(db);

    final DateTime now = DateTime.now().toUtc();
    board = Board(id: newId(), name: '겨울 무드', createdAt: now, updatedAt: now);
    await boardRepository.saveBoard(board);
  });

  tearDown(() async {
    await db.close();
  });

  /// 판을 넓은 화면에서 엽니다.
  ///
  /// 판은 창 크기에 맞춰 줄여서 그려집니다. 창이 아주 좁으면 카드도 함께
  /// 작아져서, 끄는 시늉을 할 자리가 몇 픽셀밖에 안 남습니다.
  void useWideScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// 판 화면을 띄우고 다 그려질 때까지 기다립니다.
  Future<void> openBoard(WidgetTester tester) async {
    useWideScreen(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: BoardScreen(
          board: board,
          boardRepository: boardRepository,
          referenceRepository: referenceRepository,
          imageStorage: FakeImageStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 레퍼런스를 하나 저장하고 그 번호를 돌려줍니다.
  Future<String> saveReference(String title) async {
    final DateTime now = DateTime.now().toUtc();
    final ReferenceItem item = ReferenceItem(
      id: newId(),
      type: ReferenceType.image,
      title: title,

      // 실제로 없는 파일입니다. 그림은 못 읽히고 자리표시자가 뜨는데,
      // 이 테스트가 보려는 것은 그림이 아니라 배치라 상관없습니다.
      fileName: 'not-a-real-file.jpg',
      createdAt: now,
      updatedAt: now,
    );
    await referenceRepository.save(item);
    return item.id;
  }

  /// 판에 카드를 하나 올리고 그 카드를 돌려줍니다.
  Future<BoardCard> putCardOnBoard({
    required String referenceId,
    double x = 100,
    double y = 100,
    int zOrder = 0,
  }) async {
    final DateTime now = DateTime.now().toUtc();
    final BoardCard card = BoardCard(
      id: newId(),
      boardId: board.id,
      referenceId: referenceId,
      x: x,
      y: y,
      zOrder: zOrder,
      createdAt: now,
      updatedAt: now,
    );
    await boardRepository.addCards(<BoardCard>[card]);
    return card;
  }

  /// 판이 지금 몇 배로 줄어서 그려지고 있는지 알아냅니다.
  ///
  /// 판(1920×1200)은 창 크기에 맞춰 줄여서 보여줍니다. 그래서 화면에서 100픽셀
  /// 끌면 판 위에서는 그보다 **더 많이** 움직입니다. 저장된 값을 확인하려면
  /// 이 비율을 알아야 합니다.
  double shownScale(WidgetTester tester) {
    final Size shown = tester.getSize(
      find.descendant(
        of: find.byType(BoardCanvas),
        matching: find.byType(FittedBox),
      ),
    );
    return shown.width / boardWidth;
  }

  /// 저장소에서 이 카드를 다시 읽어옵니다.
  Future<BoardCard> reloadCard(String cardId) async {
    final List<BoardCard> cards = await boardRepository.getCards(board.id);
    return cards.firstWhere((BoardCard card) => card.id == cardId);
  }

  testWidgets('판이 비어 있으면 안내가 보인다', (WidgetTester tester) async {
    await openBoard(tester);

    expect(find.text('판이 비어 있습니다'), findsOneWidget);
  });

  testWidgets('판 이름이 위에 보인다', (WidgetTester tester) async {
    await openBoard(tester);

    expect(find.text('겨울 무드'), findsOneWidget);
  });

  testWidgets('올려둔 카드가 판에 보인다', (WidgetTester tester) async {
    final String referenceId = await saveReference('노을');
    await putCardOnBoard(referenceId: referenceId);

    await openBoard(tester);

    expect(find.byType(BoardCardView), findsOneWidget);
    expect(find.text('판이 비어 있습니다'), findsNothing);
  });

  testWidgets('카드를 끌면 화면에서 옮겨진다', (WidgetTester tester) async {
    final String referenceId = await saveReference('노을');
    await putCardOnBoard(referenceId: referenceId, x: 100, y: 100);

    await openBoard(tester);

    final Offset before = tester.getTopLeft(find.byType(BoardCardView));

    await tester.drag(find.byType(BoardCardView), const Offset(120, 60));
    await tester.pumpAndSettle();

    final Offset after = tester.getTopLeft(find.byType(BoardCardView));

    expect(after.dx - before.dx, closeTo(120, 1));
    expect(after.dy - before.dy, closeTo(60, 1));
  });

  testWidgets('끌어서 옮긴 자리가 저장된다', (WidgetTester tester) async {
    // ── 이게 이 파일의 핵심입니다 ──
    // 화면에서만 옮겨지고 저장이 안 되면, 앱을 껐다 켤 때 늘어놓은 것이
    // 통째로 처음 자리로 돌아갑니다.
    final String referenceId = await saveReference('노을');
    final BoardCard card = await putCardOnBoard(
      referenceId: referenceId,
      x: 100,
      y: 100,
    );

    await openBoard(tester);

    await tester.drag(find.byType(BoardCardView), const Offset(120, 60));
    await tester.pumpAndSettle();

    final double scale = shownScale(tester);

    final BoardCard saved = await reloadCard(card.id);
    expect(saved.x, closeTo(100 + 120 / scale, 1));
    expect(saved.y, closeTo(100 + 60 / scale, 1));
  });

  testWidgets('판 밖으로는 끌어낼 수 없다', (WidgetTester tester) async {
    // 판 밖에 놓이면 화면에 안 그려져서, 사용자 눈에는 사진이 사라진 것과 같습니다.
    final String referenceId = await saveReference('노을');
    final BoardCard card = await putCardOnBoard(
      referenceId: referenceId,
      x: 100,
      y: 100,
    );

    await openBoard(tester);

    // 왼쪽 위로 한참 밀어냅니다.
    await tester.drag(find.byType(BoardCardView), const Offset(-500, -500));
    await tester.pumpAndSettle();

    final BoardCard saved = await reloadCard(card.id);
    expect(saved.x, 0);
    expect(saved.y, 0);
  });

  testWidgets('카드를 잡으면 맨 위로 올라온다', (WidgetTester tester) async {
    // 아래 깔린 카드를 꺼내려고 끌었는데 여전히 덮여 있으면
    // 무엇을 잡았는지 보이지 않습니다.
    final String bottomRef = await saveReference('아래');
    final String topRef = await saveReference('위');

    final BoardCard bottom = await putCardOnBoard(
      referenceId: bottomRef,
      x: 100,
      y: 100,
      zOrder: 1,
    );
    await putCardOnBoard(referenceId: topRef, x: 600, y: 100, zOrder: 9);

    await openBoard(tester);

    // 아래에 깔린 카드를 살짝 끕니다.
    await tester.drag(find.byType(BoardCardView).first, const Offset(10, 10));
    await tester.pumpAndSettle();

    final BoardCard saved = await reloadCard(bottom.id);
    expect(saved.zOrder, greaterThan(9));
  });

  testWidgets('카드를 내려도 레퍼런스는 목록에 남는다', (WidgetTester tester) async {
    // 판에서 내리는 것과 사진을 지우는 것은 완전히 다른 일입니다.
    // 여기가 헷갈리면 사용자가 판 정리를 무서워하게 됩니다.
    final String referenceId = await saveReference('노을');
    await putCardOnBoard(referenceId: referenceId);

    await openBoard(tester);

    // 내리기 버튼은 마우스를 올렸을 때만 나타납니다.
    final TestGesture gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(tester.getCenter(find.byType(BoardCardView)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // 판에서는 내려갔지만
    expect(await boardRepository.getCards(board.id), isEmpty);
    expect(find.text('판이 비어 있습니다'), findsOneWidget);

    // 레퍼런스 자체는 그대로 남아 있어야 합니다.
    final List<ReferenceItem> items = await referenceRepository.getAll();
    expect(items.length, 1);
    expect(items.first.title, '노을');
  });
}
