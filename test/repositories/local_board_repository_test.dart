// 무드보드 저장소가 제대로 동작하는지 확인하는 테스트입니다.
//
// 실제 데이터베이스 파일을 만들지 않고 메모리 안에서만 도는 데이터베이스를 씁니다.
// 그래서 테스트를 몇 번 돌려도 흔적이 남지 않고, 테스트끼리 서로 영향을 주지 않습니다.
//
// 터미널에서 `flutter test` 로 실행합니다.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/board.dart';
import 'package:reference_archive_app/repositories/local_board_repository.dart';
import 'package:reference_archive_app/utils/id_generator.dart';

void main() {
  late AppDatabase db;
  late LocalBoardRepository repository;

  // setUp은 테스트 하나하나마다 실행됩니다. 매번 새 데이터베이스로 시작한다는 뜻입니다.
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalBoardRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// 테스트용 무드보드를 하나 만들어 돌려줍니다.
  Board makeBoard(String name) {
    final DateTime now = DateTime.now().toUtc();
    return Board(id: newId(), name: name, createdAt: now, updatedAt: now);
  }

  /// 테스트용 카드를 하나 만들어 돌려줍니다.
  BoardCard makeCard({
    required String boardId,
    String referenceId = 'ref-1',
    double x = 0,
    double y = 0,
    int zOrder = 0,
  }) {
    final DateTime now = DateTime.now().toUtc();
    return BoardCard(
      id: newId(),
      boardId: boardId,
      referenceId: referenceId,
      x: x,
      y: y,
      zOrder: zOrder,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('무드보드 판', () {
    test('저장한 판을 다시 읽어올 수 있다', () async {
      final Board board = makeBoard('겨울 무드');
      await repository.saveBoard(board);

      final Board? loaded = await repository.getBoardById(board.id);

      expect(loaded, isNotNull);
      expect(loaded!.name, '겨울 무드');
    });

    test('목록은 최근에 고친 것이 앞에 온다', () async {
      // 작업 중인 판을 매번 목록 아래에서 찾아 내려가야 하면 불편합니다.
      final Board older = makeBoard('오래된 판');
      final Board newer = makeBoard('새 판');

      await repository.saveBoard(older);

      // saveBoard가 updatedAt을 "지금"으로 찍기 때문에, 시각이 확실히
      // 갈리도록 아주 잠깐 띄웁니다. 안 띄우면 같은 밀리초에 저장되어
      // 순서가 뒤집힐 수 있고, 그러면 이 테스트가 어쩌다 한 번씩 실패합니다.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repository.saveBoard(newer);

      final List<Board> boards = await repository.getAllBoards();

      expect(boards.map((Board b) => b.name).toList(), <String>[
        '새 판',
        '오래된 판',
      ]);
    });

    test('지운 판은 목록과 조회에서 모두 빠진다', () async {
      final Board board = makeBoard('겨울 무드');
      await repository.saveBoard(board);
      await repository.deleteBoard(board.id);

      expect(await repository.getBoardById(board.id), isNull);
      expect(await repository.getAllBoards(), isEmpty);
    });

    test('판을 지우면 그 위의 카드도 함께 내려간다', () async {
      // 판만 지우고 카드를 남겨두면 주인 없는 배치 정보가 계속 쌓입니다.
      final Board board = makeBoard('겨울 무드');
      await repository.saveBoard(board);
      await repository.addCards(<BoardCard>[makeCard(boardId: board.id)]);

      await repository.deleteBoard(board.id);

      expect(await repository.getCards(board.id), isEmpty);
    });

    test('지워도 데이터베이스에는 남아있다 (소프트 삭제)', () async {
      final Board board = makeBoard('겨울 무드');
      await repository.saveBoard(board);
      await repository.deleteBoard(board.id);

      // 저장소를 거치지 않고 데이터베이스를 직접 들여다봅니다.
      // 진짜로 지워졌다면 줄이 아예 없어야 하지만, 소프트 삭제라 남아 있어야 합니다.
      // 나중에 기기 간 동기화를 붙일 때 "지웠다"는 사실 자체가 필요하기 때문입니다.
      final List<BoardRow> rows = await db.select(db.boards).get();

      expect(rows.length, 1);
      expect(rows.first.deletedAt, isNotNull);
    });

    test('저장하면 updatedAt이 갱신되고 createdAt은 그대로다', () async {
      final DateTime past = DateTime.utc(2020, 1, 1);
      final Board board = Board(
        id: newId(),
        name: '겨울 무드',
        createdAt: past,
        updatedAt: past,
      );
      await repository.saveBoard(board);

      final Board? loaded = await repository.getBoardById(board.id);

      expect(loaded!.createdAt, past);
      expect(loaded.updatedAt.isAfter(past), isTrue);
    });

    test('저장하는 시각은 UTC로 기록된다', () async {
      final Board board = makeBoard('겨울 무드');
      await repository.saveBoard(board);

      final Board? loaded = await repository.getBoardById(board.id);

      // 현지 시각으로 저장하면 시차가 다른 기기끼리 합칠 때 순서가 뒤집힙니다.
      expect(loaded!.updatedAt.isUtc, isTrue);
    });
  });

  group('판 위의 카드', () {
    late Board board;

    setUp(() async {
      board = makeBoard('겨울 무드');
      await repository.saveBoard(board);
    });

    test('여러 장을 한 번에 올릴 수 있다', () async {
      await repository.addCards(<BoardCard>[
        makeCard(boardId: board.id, referenceId: 'ref-1'),
        makeCard(boardId: board.id, referenceId: 'ref-2'),
        makeCard(boardId: board.id, referenceId: 'ref-3'),
      ]);

      final List<BoardCard> cards = await repository.getCards(board.id);
      expect(cards.length, 3);
    });

    test('빈 목록을 올려도 아무 일이 없다', () async {
      // 사용자가 아무것도 안 고르고 확인을 눌렀을 때입니다. 오류가 나면 안 됩니다.
      await repository.addCards(<BoardCard>[]);

      expect(await repository.getCards(board.id), isEmpty);
    });

    test('아래에 깔린 것부터 순서대로 나온다', () async {
      // 화면이 이 순서대로 겹쳐 그리므로, 순서가 틀리면 위아래가 뒤바뀝니다.
      await repository.addCards(<BoardCard>[
        makeCard(boardId: board.id, referenceId: 'top', zOrder: 5),
        makeCard(boardId: board.id, referenceId: 'bottom', zOrder: 1),
        makeCard(boardId: board.id, referenceId: 'middle', zOrder: 3),
      ]);

      final List<BoardCard> cards = await repository.getCards(board.id);

      expect(cards.map((BoardCard c) => c.referenceId).toList(), <String>[
        'bottom',
        'middle',
        'top',
      ]);
    });

    test('다른 판의 카드는 섞이지 않는다', () async {
      final Board other = makeBoard('여름 무드');
      await repository.saveBoard(other);

      await repository.addCards(<BoardCard>[makeCard(boardId: board.id)]);
      await repository.addCards(<BoardCard>[
        makeCard(boardId: other.id),
        makeCard(boardId: other.id),
      ]);

      expect((await repository.getCards(board.id)).length, 1);
      expect((await repository.getCards(other.id)).length, 2);
    });

    test('옮긴 위치가 저장된다', () async {
      final BoardCard card = makeCard(boardId: board.id, x: 10, y: 20);
      await repository.addCards(<BoardCard>[card]);

      await repository.saveCard(card.copyWith(x: 300, y: 400));

      final List<BoardCard> cards = await repository.getCards(board.id);
      expect(cards.length, 1, reason: '옮긴 것이 새 카드로 늘어나면 안 됩니다');
      expect(cards.first.x, 300);
      expect(cards.first.y, 400);
    });

    test('내린 카드는 목록에서 빠진다', () async {
      final BoardCard card = makeCard(boardId: board.id);
      await repository.addCards(<BoardCard>[card]);

      await repository.removeCard(card.id);

      expect(await repository.getCards(board.id), isEmpty);
    });

    test('같은 레퍼런스를 한 판에 두 번 올릴 수 있다', () async {
      // 같은 색감을 좌우에 나란히 두고 비교하는 식으로 쓸 수 있어야 합니다.
      // 이게 되려면 배치마다 고유 번호가 있어야 합니다(레퍼런스 번호로는 안 됨).
      await repository.addCards(<BoardCard>[
        makeCard(boardId: board.id, referenceId: 'same', x: 0),
        makeCard(boardId: board.id, referenceId: 'same', x: 500),
      ]);

      final List<BoardCard> cards = await repository.getCards(board.id);
      expect(cards.length, 2);
    });

    test('처음 올린 카드는 높이가 비어 있다 (그림 비율대로)', () async {
      await repository.addCards(<BoardCard>[makeCard(boardId: board.id)]);

      final List<BoardCard> cards = await repository.getCards(board.id);

      // null = "아직 안 정했으니 그림 비율대로". 0이 아닙니다.
      // 0으로 두면 "높이가 0"인지 "안 정했다"인지 구분할 수 없습니다.
      expect(cards.first.height, isNull);
      expect(cards.first.width, defaultBoardCardWidth);
    });
  });

  group('장수 세기', () {
    test('판마다 카드 장수를 한 번에 세어준다', () async {
      final Board first = makeBoard('겨울 무드');
      final Board second = makeBoard('여름 무드');
      final Board empty = makeBoard('빈 판');
      await repository.saveBoard(first);
      await repository.saveBoard(second);
      await repository.saveBoard(empty);

      await repository.addCards(<BoardCard>[
        makeCard(boardId: first.id),
        makeCard(boardId: first.id),
        makeCard(boardId: second.id),
      ]);

      final Map<String, int> counts = await repository.countCardsByBoard();

      expect(counts[first.id], 2);
      expect(counts[second.id], 1);

      // 카드가 없는 판은 아예 안 들어있습니다. 읽는 쪽에서 "없으면 0장"으로 봅니다.
      expect(counts[empty.id], isNull);
    });

    test('내린 카드는 세지 않는다', () async {
      final Board board = makeBoard('겨울 무드');
      await repository.saveBoard(board);

      final BoardCard card = makeCard(boardId: board.id);
      await repository.addCards(<BoardCard>[card, makeCard(boardId: board.id)]);
      await repository.removeCard(card.id);

      final Map<String, int> counts = await repository.countCardsByBoard();
      expect(counts[board.id], 1);
    });
  });
}
