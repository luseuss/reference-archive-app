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
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/board.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/repositories/local_board_repository.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/screens/board_screen.dart';
import 'package:reference_archive_app/utils/id_generator.dart';
import 'package:reference_archive_app/widgets/board_canvas.dart';
import 'package:reference_archive_app/widgets/board_viewport.dart';
import 'package:reference_archive_app/widgets/board_card_view.dart';
import 'package:reference_archive_app/widgets/board_guides.dart';
import 'package:reference_archive_app/widgets/board_selection_bar.dart';

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

  /// "이미지로 내보내기" 아이콘 버튼을 찾습니다.
  ///
  /// `find.byTooltip`은 Tooltip 위젯 자체를 찾아주기 때문에, 그 안의
  /// IconButton까지 한 번 더 내려가야 합니다.
  Finder findExportButton() {
    return find.ancestor(
      of: find.byTooltip('이미지로 내보내기'),
      matching: find.byType(IconButton),
    );
  }

  testWidgets('판이 비어 있으면 이미지로 내보내기 버튼이 안 눌린다', (
    WidgetTester tester,
  ) async {
    await openBoard(tester);

    final IconButton button = tester.widget<IconButton>(findExportButton());

    // 내보낼 카드가 하나도 없으면 눌러도 뜻이 없습니다.
    expect(button.onPressed, isNull);
  });

  testWidgets('카드가 있으면 이미지로 내보내기 버튼이 눌린다', (
    WidgetTester tester,
  ) async {
    final String referenceId = await saveReference('노을');
    await putCardOnBoard(referenceId: referenceId);

    await openBoard(tester);

    final IconButton button = tester.widget<IconButton>(findExportButton());

    expect(button.onPressed, isNotNull);

    // 실제로 눌러서 저장 대화상자까지 여는 것은 여기서 확인하지 않습니다.
    // file_picker가 진짜 운영체제 창을 띄우려고 해서, 위젯 테스트 안에서는
    // 끝없이 멈춥니다. 사진이 제대로 찍히는지·저장되는지는 앱을 켜서
    // 눈으로 확인합니다. (update.md 참고)
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

  /// [body]를 실행하는 동안 Alt 키를 누르고 있는 것처럼 만듭니다.
  ///
  /// ── 왜 필요한가 ──
  /// 스냅은 **기본은 꺼져 있고 Alt를 누르고 있을 때만 켜집니다.** 스냅이
  /// 걸리는지 확인하려는 테스트는 실제로 Alt가 눌린 척을 해야 합니다.
  /// 안 그러면 board_screen.dart의 `_snapEnabled`가 늘 거짓이라 스냅이
  /// 한 번도 안 걸립니다.
  Future<void> withAltPressed(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    try {
      await body();
    } finally {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    }
  }

  /// 카드의 **오른쪽 아래** 크기 조절 손잡이를 [dx]만큼 오른쪽으로 끕니다.
  /// (화면 좌표 기준)
  ///
  /// 손잡이가 이제 네 모서리라 아이콘만으로는 어느 것인지 구분할 수
  /// 없습니다. 이름표(Key)로 오른쪽 아래를 콕 집습니다 — 기존 동작(오른쪽
  /// 아래만 붙던 시절)과 같은 결과를 확인하는 테스트들이라, 그 손잡이를
  /// 그대로 씁니다.
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

    final Offset handle = tester.getCenter(
      find.byKey(const ValueKey<String>('resize-handle-bottomRight')),
    );
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
      find
          .byKey(const ValueKey<String>('resize-handle-bottomRight'))
          .hitTestable(),
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

  testWidgets('평소에는 가까이 있어도 안 붙는다', (WidgetTester tester) async {
    // ── 기본이 뒤집혔습니다 (2026-08-28) ──
    // 처음에는 "평소 붙고 Alt로 끄기"였는데, 의뢰인이 써보니 반대가
    // 손에 맞았습니다. 카드를 대충 늘어놓는 시간이 훨씬 많고, 줄을 딱
    // 맞추고 싶을 때만 가끔 스냅을 켭니다.
    final String movingRef = await saveReference('움직일 것');
    final String anchorRef = await saveReference('기준');

    // 기준 카드의 왼쪽은 600입니다.
    await putCardOnBoard(referenceId: anchorRef, x: 600, y: 200);
    final BoardCard moving = await putCardOnBoard(
      referenceId: movingRef,
      x: 100,
      y: 700,
    );

    await openBoard(tester);

    final double scale = shownScale(tester);

    // 기준의 왼쪽(600)에서 5만큼 못 미치는 자리로 끕니다. Alt를 안 눌렀으니
    // 붙지 않고 끈 만큼 그대로 595에 놓여야 합니다.
    final double target = 595;
    await tester.drag(
      find.byKey(ValueKey<String>(moving.id)),
      Offset((target - 100) * scale, 0),
    );
    await tester.pumpAndSettle();

    expect(
      (await reloadCard(moving.id)).x,
      closeTo(595, 1),
      reason: 'Alt를 안 눌렀는데 스냅이 걸렸습니다',
    );
  });

  testWidgets('Alt를 누르고 가까이 끌면 다른 카드에 착 붙는다', (
    WidgetTester tester,
  ) async {
    // ── 규칙이 맞는지는 board_snap_test가 봅니다 ──
    // 여기서는 그 규칙이 **실제 끌기에 연결됐는지**를 봅니다. 계산은 맞는데
    // 화면에 안 이어져 있으면 사용자에게는 없는 기능입니다.
    final String movingRef = await saveReference('움직일 것');
    final String anchorRef = await saveReference('기준');

    // 기준 카드의 왼쪽은 600입니다.
    await putCardOnBoard(referenceId: anchorRef, x: 600, y: 200);
    final BoardCard moving = await putCardOnBoard(
      referenceId: movingRef,
      x: 100,
      y: 700,
    );

    await openBoard(tester);

    final double scale = shownScale(tester);

    // 기준의 왼쪽(600)에서 5만큼 못 미치는 자리로 끕니다.
    // Alt가 눌려 있으면 스냅이 걸려 600으로 당겨져야 합니다.
    final double target = 595;
    await withAltPressed(tester, () async {
      await tester.drag(
        find.byKey(ValueKey<String>(moving.id)),
        Offset((target - 100) * scale, 0),
      );
      await tester.pumpAndSettle();
    });

    expect(
      (await reloadCard(moving.id)).x,
      600,
      reason: 'Alt를 눌렀는데 스냅이 안 걸렸습니다',
    );
  });

  testWidgets('Alt를 눌러도 멀리 있으면 안 붙는다', (WidgetTester tester) async {
    // 아무 데나 붙으면 원하는 자리에 못 놓습니다.
    final String movingRef = await saveReference('움직일 것');
    final String anchorRef = await saveReference('기준');

    await putCardOnBoard(referenceId: anchorRef, x: 600, y: 200);
    final BoardCard moving = await putCardOnBoard(
      referenceId: movingRef,
      x: 100,
      y: 700,
    );

    await openBoard(tester);

    final double scale = shownScale(tester);

    // 기준에서 한참 떨어진 자리로 끕니다.
    await withAltPressed(tester, () async {
      await tester.drag(
        find.byKey(ValueKey<String>(moving.id)),
        Offset(200 * scale, 0),
      );
      await tester.pumpAndSettle();
    });

    expect((await reloadCard(moving.id)).x, closeTo(300, 1));
  });

  testWidgets('Alt를 누르고 끄는 동안 안내선이 보인다', (WidgetTester tester) async {
    // 스냅은 눈에 안 보이는 기능이라, 무엇에 맞춰졌는지 알려줘야 합니다.
    final String movingRef = await saveReference('움직일 것');
    final String anchorRef = await saveReference('기준');

    await putCardOnBoard(referenceId: anchorRef, x: 600, y: 200);
    final BoardCard moving = await putCardOnBoard(
      referenceId: movingRef,
      x: 100,
      y: 700,
    );

    await openBoard(tester);

    final double scale = shownScale(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);

    // 끌기를 **끝내지 않고** 붙은 상태에서 확인합니다.
    // 손을 떼면 안내선이 사라지기 때문입니다.
    final TestGesture drag = await tester.startGesture(
      tester.getCenter(find.byKey(ValueKey<String>(moving.id))),
    );
    await tester.pump();

    await drag.moveBy(Offset((595 - 100) * scale / 2, 0));
    await tester.pump();
    await drag.moveBy(Offset((595 - 100) * scale / 2, 0));
    await tester.pump();

    expect(find.byType(BoardGuides), findsOneWidget);
    final BoardGuides guides = tester.widget(find.byType(BoardGuides));
    expect(guides.guideX, 600, reason: '안내선이 안 그려졌습니다');

    await drag.up();
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

    // 손을 떼면 사라져야 합니다. 계속 떠 있으면 판이 지저분해집니다.
    final BoardGuides after = tester.widget(find.byType(BoardGuides));
    expect(after.guideX, isNull, reason: '손을 뗐는데 안내선이 남아 있습니다');
  });

  testWidgets('안내선이 빈 곳 끌기를 가로채지 않는다', (WidgetTester tester) async {
    // 안내선은 판 위에 얹히는 것이라, IgnorePointer로 감싸지 않으면
    // 클릭을 가로채서 판이 안 움직입니다.
    // (board_canvas.dart가 바탕을 안 그리는 것과 같은 이유)
    final String referenceId = await saveReference('노을');
    await putCardOnBoard(referenceId: referenceId, x: 100, y: 100);

    await openBoard(tester);

    expect(
      find.byType(BoardGuides).hitTestable(),
      findsNothing,
      reason: '안내선이 클릭을 받고 있습니다',
    );
  });

  // ── 여기서부터는 5단계 마퀴 다중선택입니다 ──

  /// 카드 하나의 BoardCardView를 찾아 isSelected 값을 돌려줍니다.
  bool isCardSelected(WidgetTester tester, String cardId) {
    final Finder finder = find.descendant(
      of: find.byKey(ValueKey<String>(cardId)),
      matching: find.byType(BoardCardView),
    );
    return tester.widget<BoardCardView>(finder).isSelected;
  }

  testWidgets('Alt+빈 곳 끌기로 걸리는 카드만 선택된다', (WidgetTester tester) async {
    final String refA = await saveReference('가');
    final String refB = await saveReference('나');

    final BoardCard a = await putCardOnBoard(referenceId: refA, x: 100, y: 100);
    final BoardCard b = await putCardOnBoard(referenceId: refB, x: 700, y: 100);

    await openBoard(tester);

    // 창의 빈 구석(화면에 실제로 보이는 자리)에서 카드 a를 완전히 감싸도록
    // 마퀴를 끕니다. 카드 a는 걸리고, 멀리 있는 b는 안 걸려야 합니다.
    //
    // ── BoardCanvas의 왼쪽 위가 아니라 BoardViewport의 왼쪽 위를 씁니다 ──
    // BoardCanvas는 카드 둘레에 넉넉한 여백(canvasBreathingRoom)까지 포함한
    // 큰 상자라 그 모서리가 화면 밖으로 한참 벗어나 있습니다. 실제로 클릭이
    // 닿는 자리는 화면에 보이는 BoardViewport 안쪽이어야 합니다.
    final Offset viewportTopLeft = tester.getTopLeft(find.byType(BoardViewport));
    final Offset start = viewportTopLeft + const Offset(10, 10);
    final Offset aCenter = tester.getCenter(
      find.byKey(ValueKey<String>(a.id)),
    );

    await withAltPressed(tester, () async {
      final TestGesture drag = await tester.startGesture(start);
      await tester.pump();
      await drag.moveTo(aCenter + const Offset(40, 20));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
    });

    expect(isCardSelected(tester, a.id), isTrue, reason: 'a는 마퀴에 걸려야 합니다');
    expect(isCardSelected(tester, b.id), isFalse, reason: 'b는 멀리 있어 안 걸려야 합니다');
    expect(find.byType(BoardSelectionBar), findsOneWidget);
    expect(find.text('1개 선택됨'), findsOneWidget);
  });

  testWidgets('Shift+클릭으로 선택을 더하고 뺀다', (WidgetTester tester) async {
    final String refA = await saveReference('가');
    final String refB = await saveReference('나');

    final BoardCard a = await putCardOnBoard(referenceId: refA, x: 100, y: 100);
    final BoardCard b = await putCardOnBoard(referenceId: refB, x: 700, y: 300);

    await openBoard(tester);

    // 먼저 a를 그냥 클릭합니다. a 하나만 선택돼야 합니다.
    await tester.tap(find.byKey(ValueKey<String>(a.id)));
    await tester.pumpAndSettle();
    expect(isCardSelected(tester, a.id), isTrue);

    // Shift를 누른 채 b를 클릭하면 b가 선택에 더해지고, a는 그대로 남습니다.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.byKey(ValueKey<String>(b.id)));
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    expect(isCardSelected(tester, a.id), isTrue, reason: 'a가 선택에서 빠지면 안 됩니다');
    expect(isCardSelected(tester, b.id), isTrue);
    expect(find.text('2개 선택됨'), findsOneWidget);

    // Shift를 누른 채 a를 다시 클릭하면 a만 선택에서 빠집니다.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.byKey(ValueKey<String>(a.id)));
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    expect(isCardSelected(tester, a.id), isFalse);
    expect(isCardSelected(tester, b.id), isTrue);
  });

  testWidgets('여러 장이 선택된 상태에서 하나를 끌면 다 같이 움직인다', (
    WidgetTester tester,
  ) async {
    final String refA = await saveReference('가');
    final String refB = await saveReference('나');

    final BoardCard a = await putCardOnBoard(referenceId: refA, x: 100, y: 100);
    final BoardCard b = await putCardOnBoard(referenceId: refB, x: 700, y: 300);

    await openBoard(tester);

    // 둘 다 선택해둡니다.
    await tester.tap(find.byKey(ValueKey<String>(a.id)));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.byKey(ValueKey<String>(b.id)));
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    final double scale = shownScale(tester);

    // a를 끌면 선택된 그 전부(a, b)가 같이 움직여야 합니다.
    await tester.drag(
      find.byKey(ValueKey<String>(a.id)),
      Offset(50 * scale, 0),
    );
    await tester.pumpAndSettle();

    final BoardCard savedA = await reloadCard(a.id);
    final BoardCard savedB = await reloadCard(b.id);

    expect(savedA.x, closeTo(150, 1), reason: '잡은 카드가 안 움직였습니다');
    expect(savedB.x, closeTo(750, 1), reason: '같이 선택된 카드가 안 따라왔습니다');
  });

  testWidgets('선택 삭제를 누르면 골라둔 카드가 전부 판에서 내려간다', (
    WidgetTester tester,
  ) async {
    final String refA = await saveReference('가');
    final String refB = await saveReference('나');
    final String refC = await saveReference('다');

    final BoardCard a = await putCardOnBoard(referenceId: refA, x: 100, y: 100);
    await putCardOnBoard(referenceId: refB, x: 700, y: 300);
    await putCardOnBoard(referenceId: refC, x: 1300, y: 100);

    await openBoard(tester);

    // a만 선택하고 삭제합니다. b, c는 남아야 합니다.
    await tester.tap(find.byKey(ValueKey<String>(a.id)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('선택 삭제'));
    await tester.pumpAndSettle();

    final List<BoardCard> remaining = await boardRepository.getCards(board.id);
    expect(remaining.length, 2);
    expect(remaining.any((BoardCard c) => c.id == a.id), isFalse);

    // 선택도 함께 비워져서 선택 띠가 사라져야 합니다.
    expect(find.byType(BoardSelectionBar), findsNothing);
  });

  testWidgets('빈 곳을 그냥 클릭하면 선택이 풀린다', (WidgetTester tester) async {
    final String refA = await saveReference('가');
    final BoardCard a = await putCardOnBoard(referenceId: refA, x: 100, y: 100);

    await openBoard(tester);

    await tester.tap(find.byKey(ValueKey<String>(a.id)));
    await tester.pumpAndSettle();
    expect(isCardSelected(tester, a.id), isTrue);

    // 카드에서 멀리 떨어진 빈 곳을 클릭합니다(끌지 않습니다).
    // BoardCanvas가 아니라 BoardViewport 기준입니다 — 위 테스트의 설명 참고.
    final Offset viewportTopLeft = tester.getTopLeft(find.byType(BoardViewport));
    await tester.tapAt(viewportTopLeft + const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(isCardSelected(tester, a.id), isFalse);
    expect(find.byType(BoardSelectionBar), findsNothing);
  });

  testWidgets('빈 곳을 클릭해도 판 이동에는 영향이 없다', (WidgetTester tester) async {
    // 회귀 확인: 클릭 판정을 Listener로 따로 보느라 판 이동(Pan)이
    // 망가지면 안 됩니다.
    final String refA = await saveReference('가');
    await putCardOnBoard(referenceId: refA, x: 100, y: 100);

    await openBoard(tester);

    final Offset before = tester.getTopLeft(find.byType(BoardCanvas));

    // AppBar 아래, 화면에 실제로 보이는 자리에서 끕니다. (30, 30)처럼
    // 화면 맨 위쪽 좌표를 그대로 쓰면 AppBar 위를 눌러버립니다.
    final Offset viewportTopLeft = tester.getTopLeft(find.byType(BoardViewport));
    await tester.dragFrom(
      viewportTopLeft + const Offset(30, 30),
      const Offset(90, 60),
    );
    await tester.pumpAndSettle();

    final Offset after = tester.getTopLeft(find.byType(BoardCanvas));

    expect(after.dx - before.dx, closeTo(90, 1));
    expect(after.dy - before.dy, closeTo(60, 1));
  });

  // ── 여기서부터는 6단계 정렬·분배 툴바입니다 ──

  testWidgets('왼쪽 정렬을 누르면 선택된 카드들이 나란히 맞춰진다', (
    WidgetTester tester,
  ) async {
    final String refA = await saveReference('가');
    final String refB = await saveReference('나');

    final BoardCard a = await putCardOnBoard(referenceId: refA, x: 100, y: 100);
    final BoardCard b = await putCardOnBoard(referenceId: refB, x: 500, y: 400);

    await openBoard(tester);

    await tester.tap(find.byKey(ValueKey<String>(a.id)));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.byKey(ValueKey<String>(b.id)));
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    await tester.tap(find.byTooltip('왼쪽 정렬'));
    await tester.pumpAndSettle();

    final BoardCard savedA = await reloadCard(a.id);
    final BoardCard savedB = await reloadCard(b.id);

    // a의 왼쪽(100)이 더 왼쪽이라, b가 a의 왼쪽에 맞춰져야 합니다.
    expect(savedA.x, 100);
    expect(savedB.x, 100);
  });

  testWidgets('카드 하나만 선택했을 때는 정렬 버튼이 안 눌린다', (
    WidgetTester tester,
  ) async {
    final String refA = await saveReference('가');
    final BoardCard a = await putCardOnBoard(referenceId: refA, x: 100, y: 100);

    await openBoard(tester);

    await tester.tap(find.byKey(ValueKey<String>(a.id)));
    await tester.pumpAndSettle();

    // 버튼은 떠 있지만 disabled라 눌러도 아무 일이 없어야 합니다.
    // 정렬은 "여럿을 나란히 맞추는" 동작이라 한 장으로는 뜻이 없습니다.
    await tester.tap(find.byTooltip('왼쪽 정렬'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect((await reloadCard(a.id)).x, 100);
  });

  testWidgets('크기 맞추기를 누르면 맨 위 카드 기준으로 크기가 맞춰진다', (
    WidgetTester tester,
  ) async {
    final String refA = await saveReference('가');
    final String refB = await saveReference('나');

    final BoardCard a = await putCardOnBoard(
      referenceId: refA,
      x: 100,
      y: 100,
      width: 300,
      zOrder: 1,
    );
    final BoardCard b = await putCardOnBoard(
      referenceId: refB,
      x: 500,
      y: 400,
      width: 150,
      zOrder: 9, // 맨 위 — 크기 맞추기의 기준이 됩니다.
    );

    await openBoard(tester);

    await tester.tap(find.byKey(ValueKey<String>(a.id)));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.byKey(ValueKey<String>(b.id)));
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    // ── b를 다시 한 번, Shift 없이 눌러 맨 위로 올립니다 ──
    // 카드를 누르면(끌지 않아도) 맨 위로 올라옵니다 — 여러 장이 겹쳐 있을
    // 때 방금 잡은 게 뭔지 보여주려고 만든 동작입니다(board_canvas.dart
    // 설명 참고). b가 이미 선택돼 있고 선택이 2장 이상이라, 이렇게 다시
    // 눌러도 선택은 그대로 유지됩니다("이미 여러 장 선택된 상태에서
    // 그중 하나를 클릭하면 선택 유지" 규칙). 이 방식으로 "크기를 맞출
    // 기준"을 원하는 카드로 고를 수 있습니다.
    await tester.tap(find.byKey(ValueKey<String>(b.id)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('크기 맞추기 (맨 위 카드 기준)'));
    await tester.pumpAndSettle();

    // 맨 위로 올라온 b의 폭(150)으로 a가 맞춰져야 합니다.
    expect((await reloadCard(a.id)).width, 150);
    // 기준이었던 b 자신은 그대로입니다.
    expect((await reloadCard(b.id)).width, 150);
  });
}
