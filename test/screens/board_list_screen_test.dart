// 무드보드 목록 화면(판을 만들고 고르고 지우는 곳)을 확인하는 테스트입니다.
//
// ── 여기서 특히 중요한 것 ──
// 판을 지울 때 **"레퍼런스는 그대로 남는다"고 알려주는지**를 확인합니다.
// 이 말이 없으면 사용자는 판을 지우면 안에 있던 사진까지 사라지는 줄 알고
// 못 지웁니다. 안 쓰는 판이 계속 쌓이게 됩니다.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/board.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/repositories/local_board_repository.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/screens/board_list_screen.dart';
import 'package:reference_archive_app/screens/board_screen.dart';
import 'package:reference_archive_app/utils/id_generator.dart';

import '../fakes/fake_image_storage.dart';

void main() {
  late AppDatabase db;
  late LocalBoardRepository boardRepository;
  late LocalReferenceRepository referenceRepository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    boardRepository = LocalBoardRepository(db);
    referenceRepository = LocalReferenceRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// 목록 화면을 띄우고 다 그려질 때까지 기다립니다.
  Future<void> openList(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: BoardListScreen(
          boardRepository: boardRepository,
          referenceRepository: referenceRepository,
          imageStorage: FakeImageStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 무드보드를 하나 저장하고 돌려줍니다.
  Future<Board> saveBoard(String name) async {
    final DateTime now = DateTime.now().toUtc();
    final Board board = Board(
      id: newId(),
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    await boardRepository.saveBoard(board);
    return board;
  }

  /// 판에 카드를 [count]장 올립니다.
  Future<void> putCards(Board board, int count) async {
    final DateTime now = DateTime.now().toUtc();
    final List<BoardCard> cards = <BoardCard>[];

    for (int index = 0; index < count; index++) {
      cards.add(
        BoardCard(
          id: newId(),
          boardId: board.id,
          referenceId: 'ref-$index',
          x: 0,
          y: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await boardRepository.addCards(cards);
  }

  testWidgets('만든 무드보드가 없으면 안내가 보인다', (WidgetTester tester) async {
    await openList(tester);

    expect(find.text('아직 만든 무드보드가 없습니다'), findsOneWidget);
  });

  testWidgets('만들어둔 무드보드가 목록에 보인다', (WidgetTester tester) async {
    await saveBoard('겨울 무드');

    await openList(tester);

    expect(find.text('겨울 무드'), findsOneWidget);
    expect(find.text('아직 만든 무드보드가 없습니다'), findsNothing);
  });

  testWidgets('판에 올린 카드 장수가 함께 보인다', (WidgetTester tester) async {
    final Board board = await saveBoard('겨울 무드');
    await putCards(board, 3);

    await openList(tester);

    // 날짜까지 통째로 맞춰보면 오늘 날짜에 따라 테스트가 깨집니다.
    // 장수 부분만 들어있는지 봅니다.
    expect(find.textContaining('카드 3장'), findsOneWidget);
  });

  testWidgets('새 무드보드를 만들면 곧바로 그 판이 열린다', (WidgetTester tester) async {
    // 만들자마자 목록으로 돌아오면 방금 만든 것을 또 눌러야 합니다.
    await openList(tester);

    await tester.tap(find.text('새 무드보드'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '겨울 무드');
    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();

    expect(find.byType(BoardScreen), findsOneWidget);

    final List<Board> boards = await boardRepository.getAllBoards();
    expect(boards.length, 1);
    expect(boards.first.name, '겨울 무드');
  });

  testWidgets('이름 없이 만들려고 하면 알려준다', (WidgetTester tester) async {
    await openList(tester);

    await tester.tap(find.text('새 무드보드'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();

    expect(find.text('이름을 입력해주세요.'), findsOneWidget);
    expect(await boardRepository.getAllBoards(), isEmpty);
  });

  testWidgets('이름을 바꿀 수 있다', (WidgetTester tester) async {
    await saveBoard('겨울 무드');

    await openList(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tap(find.text('이름 바꾸기'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '여름 무드');
    await tester.tap(find.text('바꾸기'));
    await tester.pumpAndSettle();

    expect(find.text('여름 무드'), findsOneWidget);
    expect(find.text('겨울 무드'), findsNothing);
  });

  testWidgets('지우기 전에 레퍼런스는 남는다고 알려준다', (WidgetTester tester) async {
    // ── 이게 이 파일의 핵심입니다 ──
    final Board board = await saveBoard('겨울 무드');
    await putCards(board, 2);

    await openList(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();

    // 목록 줄에도 "카드 2장"이 적혀 있으므로 확인 창 안에서만 찾습니다.
    final Finder dialog = find.byType(AlertDialog);

    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('레퍼런스 자체는 목록에 그대로 남습니다'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.textContaining('카드 2장')),
      findsOneWidget,
    );
  });

  testWidgets('지우면 목록에서 빠지고 레퍼런스는 남는다', (WidgetTester tester) async {
    final Board board = await saveBoard('겨울 무드');
    await putCards(board, 1);

    // 진짜 레퍼런스를 하나 넣어두고, 판을 지운 뒤에도 남아 있는지 봅니다.
    final DateTime now = DateTime.now().toUtc();
    await referenceRepository.save(
      ReferenceItem(
        id: newId(),
        type: ReferenceType.image,
        title: '노을',
        fileName: 'not-a-real-file.jpg',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await openList(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();

    // 확인 창의 "지우기" 버튼을 누릅니다. 메뉴에도 같은 글자가 있었지만
    // 그건 이미 닫혔으므로 지금 화면에는 하나뿐입니다.
    await tester.tap(find.widgetWithText(FilledButton, '지우기'));
    await tester.pumpAndSettle();

    expect(find.text('아직 만든 무드보드가 없습니다'), findsOneWidget);
    expect(await boardRepository.getAllBoards(), isEmpty);

    final List<ReferenceItem> items = await referenceRepository.getAll();
    expect(items.length, 1, reason: '판을 지워도 레퍼런스는 남아야 합니다');
  });

  testWidgets('취소하면 지워지지 않는다', (WidgetTester tester) async {
    await saveBoard('겨울 무드');

    await openList(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(find.text('겨울 무드'), findsOneWidget);
    expect((await boardRepository.getAllBoards()).length, 1);
  });
}
