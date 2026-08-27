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
import 'package:reference_archive_app/utils/id_generator.dart';
import 'package:reference_archive_app/widgets/board_viewport.dart';
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
  ///
  /// [height]를 넣으면 **크기를 이미 조절해둔 카드**가 됩니다. 비워두면
  /// 그림 비율대로 그려집니다(실제 앱에서 새로 담은 카드와 같은 상태).
  Future<BoardCard> putCardOnBoard({
    required String referenceId,
    double x = 100,
    double y = 100,
    int zOrder = 0,
    double width = defaultBoardCardWidth,
    double? height,
  }) async {
    final DateTime now = DateTime.now().toUtc();
    final BoardCard card = BoardCard(
      id: newId(),
      boardId: board.id,
      referenceId: referenceId,
      x: x,
      y: y,
      width: width,
      height: height,
      zOrder: zOrder,
      createdAt: now,
      updatedAt: now,
    );
    await boardRepository.addCards(<BoardCard>[card]);
    return card;
  }

  /// 판이 지금 몇 배로 확대·축소되어 그려지고 있는지 알아냅니다.
  ///
  /// 판(1920×1200)은 창 크기에 맞춰 줄여서 보여줍니다. 그래서 화면에서 100픽셀
  /// 끌면 판 위에서는 그보다 **더 많이** 움직입니다. 저장된 값을 확인하려면
  /// 이 비율을 알아야 합니다.
  ///
  /// 배율은 BoardViewport가 정하므로, 실제로 그려진 크기를 재서 되짚습니다.
  double shownScale(WidgetTester tester) {
    final Finder fitted = find.descendant(
      of: find.byType(BoardViewport),
      matching: find.byType(FittedBox),
    );

    // FittedBox가 화면에 실제로 차지한 크기 (배율이 곱해진 값)
    final Size shown = tester.getSize(fitted);

    // 그 안의 상자는 배율 이전의 크기입니다. 판에 끝이 없어져서
    // 이 크기는 카드가 놓인 만큼 달라지므로, 고정값 대신 재서 씁니다.
    final Size canvas = tester.getSize(
      find.descendant(of: fitted, matching: find.byType(SizedBox)).first,
    );

    return shown.width / canvas.width;
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


  testWidgets('여러 장이 놓여 있어도 잡은 카드만 움직인다', (WidgetTester tester) async {
    // ── 왜 여러 장이어야 하나 ──
    // 카드를 잡으면 그 카드가 목록 맨 뒤로 옮겨집니다(맨 위에 그리려고).
    // 한 장뿐이면 순서를 바꿔도 그대로라 아무 문제가 안 드러납니다.
    // 실제 무드보드에는 여러 장이 놓입니다.
    final String refA = await saveReference('가');
    final String refB = await saveReference('나');
    final String refC = await saveReference('다');

    final BoardCard a = await putCardOnBoard(referenceId: refA, x: 100, y: 100);
    final BoardCard b = await putCardOnBoard(referenceId: refB, x: 700, y: 100);
    final BoardCard c = await putCardOnBoard(
      referenceId: refC,
      x: 1300,
      y: 100,
    );

    await openBoard(tester);

    // ── 끄는 도중에 화면을 다시 그립니다 ──
    // tester.drag는 누르고-옮기고-떼기를 다시 그리지 않고 한 번에 합니다.
    // 실제 앱은 매 순간 다시 그리므로, 그 사이에 목록 순서가 바뀝니다.
    // 그 차이를 흉내내려고 손으로 pump를 넣습니다.
    final TestGesture drag = await tester.startGesture(
      tester.getCenter(find.byType(BoardCardView).first),
    );
    await tester.pump();

    await drag.moveBy(const Offset(75, 0));
    await tester.pump();

    await drag.moveBy(const Offset(75, 0));
    await tester.pump();

    await drag.up();
    await tester.pumpAndSettle();

    // 잡은 카드만 움직여야 합니다.
    expect(
      (await reloadCard(a.id)).x,
      greaterThan(100),
      reason: '잡은 카드가 안 움직였습니다',
    );
    expect(
      (await reloadCard(b.id)).x,
      700,
      reason: '안 잡은 카드가 움직였습니다',
    );
    expect((await reloadCard(c.id)).x, 1300);
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

  /// 카드의 크기 조절 손잡이를 [dx]만큼 오른쪽으로 끕니다. (화면 좌표 기준)
  ///
  /// 손잡이는 마우스를 올렸을 때만 나타나므로, 진짜 마우스처럼 움직이는
  /// 포인터를 만들어 카드 위로 옮긴 뒤 끕니다.
  Future<TestGesture> dragResizeHandle(WidgetTester tester, double dx) async {
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);

    await mouse.moveTo(tester.getCenter(find.byType(BoardCardView)));
    await tester.pumpAndSettle();

    final Offset handle = tester.getCenter(find.byIcon(Icons.open_in_full));
    await mouse.moveTo(handle);
    await tester.pumpAndSettle();

    await mouse.down(handle);
    await tester.pump();

    // 두 번에 나눠 움직입니다. 한 번에 끝내면 "그냥 누른 것"과 구분되는
    // 최소 거리를 못 넘길 수 있습니다.
    await mouse.moveBy(Offset(dx / 2, 0));
    await tester.pump();
    await mouse.moveBy(Offset(dx / 2, 0));
    await tester.pump();

    await mouse.up();
    await tester.pumpAndSettle();

    // 마우스를 그대로 돌려줍니다. 한 화면에 마우스를 두 개 만들면
    // Flutter가 "같은 장치가 두 번 들어왔다"며 멈춥니다.
    return mouse;
  }

  testWidgets('손잡이를 끌면 카드가 커지고 그 크기가 저장된다', (WidgetTester tester) async {
    final String referenceId = await saveReference('노을');
    final BoardCard card = await putCardOnBoard(referenceId: referenceId);

    await openBoard(tester);

    final double scale = shownScale(tester);
    await dragResizeHandle(tester, 60);

    final BoardCard saved = await reloadCard(card.id);

    // 화면에서 60픽셀 끌었으니 판 위에서는 60 / 배율 만큼 늘어납니다.
    expect(saved.width, closeTo(defaultBoardCardWidth + 60 / scale, 2));
  });

  testWidgets('크기를 바꿔도 가로세로 비율은 그대로다', (WidgetTester tester) async {
    // ── 이게 이 기능에서 가장 중요합니다 ──
    // 가로만 늘어나고 세로가 그대로면 그림이 찌그러집니다. 무드보드는 그림을
    // 있는 그대로 보려고 만든 판이라, 찌그러진 그림이 놓이면 만든 이유가 없어집니다.
    final String referenceId = await saveReference('노을');
    final BoardCard card = await putCardOnBoard(referenceId: referenceId);

    await openBoard(tester);

    // 그림 파일이 없어서 4:3 자리표시자가 뜹니다. 그래서 처음 비율은 0.75입니다.
    await dragResizeHandle(tester, 80);

    final BoardCard saved = await reloadCard(card.id);

    expect(saved.height, isNotNull, reason: '크기를 바꾸면 높이가 채워져야 합니다');
    expect(saved.height! / saved.width, closeTo(3 / 4, 0.02));
  });

  testWidgets('너무 작게는 못 줄인다', (WidgetTester tester) async {
    // 더 작아지면 손잡이와 내리기 버튼이 카드보다 커져서 잡을 수가 없습니다.
    final String referenceId = await saveReference('노을');
    final BoardCard card = await putCardOnBoard(referenceId: referenceId);

    await openBoard(tester);

    await dragResizeHandle(tester, -1000);

    final BoardCard saved = await reloadCard(card.id);
    expect(saved.width, minBoardCardWidth);
  });

  testWidgets('손잡이를 끌어도 카드가 움직이지는 않는다', (WidgetTester tester) async {
    // 손잡이의 끌기와 카드 옮기기가 섞이면, 크기를 바꾸려다 카드가 딸려갑니다.
    // 손잡이가 카드보다 안쪽에 있어서 Flutter가 손잡이를 먼저 챙겨줍니다.
    final String referenceId = await saveReference('노을');
    final BoardCard card = await putCardOnBoard(
      referenceId: referenceId,
      x: 300,
      y: 200,
    );

    await openBoard(tester);

    await dragResizeHandle(tester, 60);

    final BoardCard saved = await reloadCard(card.id);
    expect(saved.x, 300);
    expect(saved.y, 200);
  });

  testWidgets('세로 사진을 한껏 키워도 손잡이를 다시 잡을 수 있다', (
    WidgetTester tester,
  ) async {
    // ── 왜 이걸 확인하나 ──
    // 크기 조절은 가로세로 비율을 고정합니다. 손잡이는 카드의 오른쪽 아래에
    // 있어서, 카드가 그려지는 자리 밖으로 나가면 손잡이도 함께 나가
    // **다시 잡을 수가 없게** 됩니다. 크기는 손을 뗄 때 저장되므로 앱을
    // 껐다 켜도 그대로입니다.
    //
    // 판에 끝이 없어진 뒤로는 그릴 자리가 카드를 따라 늘어나므로 이 일이
    // 구조적으로 안 생겨야 합니다. 정말 그런지 확인합니다.
    //
    // 3:4 세로 사진(220 × 293)을 한껏 키워봅니다.
    final String referenceId = await saveReference('세로 사진');
    final BoardCard card = await putCardOnBoard(
      referenceId: referenceId,
      x: 0,
      y: 0,
      width: 220,
      height: 293,
    );

    await openBoard(tester);

    // 화면에서 900픽셀 오른쪽으로. 판이 줄여서 그려지므로 판 위에서는
    // 이보다 더 많이 움직입니다(그래서 한계까지 닿습니다).
    final TestGesture mouse = await dragResizeHandle(tester, 900);

    // (1) 비율을 지킨 채 커졌어야 합니다.
    final BoardCard saved = await reloadCard(card.id);
    expect(saved.height, isNotNull);
    expect(saved.width, greaterThan(220));
    expect(saved.height! / saved.width, closeTo(293 / 220, 0.01));

    // (2) 크게 키웠으니 손잡이가 화면 밖으로 나갔을 수 있습니다.
    //     ⛶(판 전체 보기)를 누르면 다시 보여야 합니다.
    //
    //     판에 끝이 없어진 뒤로 이것이 되돌아오는 유일한 길입니다.
    //     이게 막히면 카드를 한 번 키운 뒤로 영영 줄일 수 없게 됩니다.
    await tester.tap(find.byTooltip('판 전체 보기'));
    await tester.pumpAndSettle();

    //     손잡이는 마우스를 올렸을 때만 나오므로 다시 올려줍니다.
    //     위젯 트리에 있는 것만으로는 부족해서 hitTestable로 확인합니다.
    await mouse.moveTo(tester.getCenter(find.byType(BoardCardView)));
    await tester.pumpAndSettle();

    expect(
      find.byIcon(Icons.open_in_full).hitTestable(),
      findsOneWidget,
      reason: '⛶를 눌러도 손잡이를 다시 잡을 수 없습니다',
    );
  });

  testWidgets('오른쪽으로 계속 끌어도 막히지 않는다', (WidgetTester tester) async {
    // ── 이게 4단계 3번의 알맹이입니다 ──
    // 전에는 판이 1920 넓이여서 카드가 1700쯤에서 멈췄습니다.
    // 이제는 멈추는 곳이 없어야 합니다.
    final String referenceId = await saveReference('노을');
    final BoardCard card = await putCardOnBoard(
      referenceId: referenceId,
      x: 100,
      y: 100,
    );

    await openBoard(tester);

    final double scale = shownScale(tester);

    await tester.drag(find.byType(BoardCardView), const Offset(2500, 0));
    await tester.pumpAndSettle();

    final BoardCard saved = await reloadCard(card.id);

    // 옛 판 크기(1920)에서 카드가 멈추던 자리를 훌쩍 넘어야 합니다.
    expect(saved.x, greaterThan(1700));
    expect(saved.x, closeTo(100 + 2500 / scale, 2));
  });

  testWidgets('아래로도 계속 끌 수 있다', (WidgetTester tester) async {
    final String referenceId = await saveReference('노을');
    final BoardCard card = await putCardOnBoard(
      referenceId: referenceId,
      x: 100,
      y: 100,
    );

    await openBoard(tester);

    await tester.drag(find.byType(BoardCardView), const Offset(0, 2000));
    await tester.pumpAndSettle();

    // 옛 판 높이(1200)를 넘어야 합니다.
    expect((await reloadCard(card.id)).y, greaterThan(1200));
  });

  testWidgets('왼쪽·위로도 계속 끌 수 있다', (WidgetTester tester) async {
    // ── 사방 무한 (4단계 3번 뒤 보완) ──
    // 전에는 (0, 0)이 벽이었습니다. 음수 자리에서는 클릭이 안 닿기 때문에
    // 막아뒀는데, 실제로 써보니 자주 부딪혔습니다.
    // 이제는 그리는 상자를 통째로 밀어서 그리므로 막을 이유가 없습니다.
    final String referenceId = await saveReference('노을');
    final BoardCard card = await putCardOnBoard(
      referenceId: referenceId,
      x: 100,
      y: 100,
    );

    await openBoard(tester);

    final double scale = shownScale(tester);

    await tester.drag(find.byType(BoardCardView), const Offset(-400, -300));
    await tester.pumpAndSettle();

    final BoardCard saved = await reloadCard(card.id);

    expect(saved.x, lessThan(0), reason: '왼쪽 벽에 막혔습니다');
    expect(saved.y, lessThan(0), reason: '위쪽 벽에 막혔습니다');
    expect(saved.x, closeTo(100 - 400 / scale, 2));
    expect(saved.y, closeTo(100 - 300 / scale, 2));
  });

  testWidgets('음수 자리로 간 카드도 다시 잡을 수 있다', (WidgetTester tester) async {
    // ── 벽을 세웠던 유일한 이유가 이것입니다 ──
    // Flutter는 상자 바깥의 클릭을 자식에게 안 내려보냅니다. 음수 자리에
    // 놓인 카드가 화면에는 보이는데 안 잡히면, 눈에 보이는 채로 못 쓰게 됩니다.
    final String referenceId = await saveReference('노을');
    await putCardOnBoard(
      referenceId: referenceId,
      x: -800,
      y: -600,
    );

    await openBoard(tester);

    expect(
      find.byType(BoardCardView).hitTestable(),
      findsOneWidget,
      reason: '음수 자리 카드가 보이기는 하는데 클릭이 안 닿습니다',
    );
  });

  testWidgets('왼쪽으로 끌어도 다른 카드는 제자리에 있다', (WidgetTester tester) async {
    // 그리는 상자의 원점이 따라 움직이므로, 화면에서는 아무 일도 없어야 합니다.
    // 원점 보정이 잘못되면 한 장을 끌 때 나머지가 우르르 밀립니다.
    final String movingRef = await saveReference('움직일 것');
    final String stayingRef = await saveReference('가만있을 것');

    await putCardOnBoard(referenceId: movingRef, x: 100, y: 300);
    final BoardCard staying = await putCardOnBoard(
      referenceId: stayingRef,
      x: 900,
      y: 300,
    );

    await openBoard(tester);

    // ── 이름표로 찾습니다 ──
    // 카드를 잡으면 목록 맨 뒤로 옮겨지므로(맨 위에 그리려고), 몇 번째냐로
    // 찾으면 엉뚱한 카드를 보게 됩니다. (PR #18에서 겪은 것과 같은 이유)
    final Finder stayingCard = find.byKey(ValueKey<String>(staying.id));

    final Offset before = tester.getTopLeft(stayingCard);

    await tester.drag(find.byType(BoardCardView).first, const Offset(-400, 0));
    await tester.pumpAndSettle();

    final Offset after = tester.getTopLeft(stayingCard);

    expect(after.dx, closeTo(before.dx, 1), reason: '가만있어야 할 카드가 밀렸습니다');
    expect((await reloadCard(staying.id)).x, 900);
  });
}
