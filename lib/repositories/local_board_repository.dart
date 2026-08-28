// BoardRepository 약속을 "내 컴퓨터의 데이터베이스"로 실제로 지키는 구현입니다.
//
// drift 관련 코드는 이 파일 안에만 있습니다.
// 자세한 이유는 local_reference_repository.dart 맨 위 설명을 보세요.

import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../models/board.dart';
import 'board_repository.dart';

/// 무드보드를 이 기기의 데이터베이스에 저장하는 구현체입니다.
class LocalBoardRepository implements BoardRepository {
  LocalBoardRepository(this._db);

  final AppDatabase _db;

  /// 살아있는 무드보드를 최근에 고친 순서로 가져옵니다.
  @override
  Future<List<Board>> getAllBoards() async {
    final SimpleSelectStatement<$BoardsTable, BoardRow> query =
        _db.select(_db.boards)
          ..where(($BoardsTable t) => t.deletedAt.isNull())
          ..orderBy(<OrderClauseGenerator<$BoardsTable>>[
            ($BoardsTable t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          ]);

    final List<BoardRow> rows = await query.get();
    return rows.map(_toBoard).toList();
  }

  /// id로 무드보드 하나를 찾습니다. 없거나 지워졌으면 null입니다.
  @override
  Future<Board?> getBoardById(String id) async {
    final BoardRow? row =
        await (_db.select(_db.boards)..where(
              ($BoardsTable t) => t.id.equals(id) & t.deletedAt.isNull(),
            ))
            .getSingleOrNull();

    if (row == null) {
      return null;
    }
    return _toBoard(row);
  }

  /// 무드보드를 저장합니다. 없으면 새로 만들고, 있으면 덮어씁니다.
  @override
  Future<void> saveBoard(Board board) async {
    // updatedAt은 부르는 쪽에 맡기지 않고 여기서 무조건 갱신합니다.
    // (이유는 local_reference_repository.dart의 save 설명 참고)
    final DateTime now = DateTime.now().toUtc();

    await _db
        .into(_db.boards)
        .insertOnConflictUpdate(
          BoardsCompanion.insert(
            id: board.id,
            name: board.name,
            createdAt: board.createdAt,
            updatedAt: now,
          ),
        );
  }

  /// 무드보드를 지웁니다. 그 판 위의 카드 배치도 함께 지웁니다.
  @override
  Future<void> deleteBoard(String id) async {
    final DateTime now = DateTime.now().toUtc();

    // 둘을 transaction으로 묶습니다. 판만 지워지고 카드가 남으면 주인 없는
    // 배치 정보가 계속 쌓이고, 나중에 기기 간 동기화를 붙일 때 그 찌꺼기가
    // 다른 기기로도 퍼집니다.
    await _db.transaction(() async {
      await (_db.update(
        _db.boards,
      )..where(($BoardsTable t) => t.id.equals(id))).write(
        BoardsCompanion(
          deletedAt: Value<DateTime?>(now),
          updatedAt: Value<DateTime>(now),
        ),
      );

      await (_db.update(_db.boardCards)..where(
            ($BoardCardsTable t) => t.boardId.equals(id) & t.deletedAt.isNull(),
          ))
          .write(
            BoardCardsCompanion(
              deletedAt: Value<DateTime?>(now),
              updatedAt: Value<DateTime>(now),
            ),
          );
    });
  }

  /// 판 위의 카드를 아래에 깔린 것부터 순서대로 가져옵니다.
  @override
  Future<List<BoardCard>> getCards(String boardId) async {
    final SimpleSelectStatement<$BoardCardsTable, BoardCardRow> query =
        _db.select(_db.boardCards)
          ..where(
            ($BoardCardsTable t) =>
                t.boardId.equals(boardId) & t.deletedAt.isNull(),
          )
          ..orderBy(<OrderClauseGenerator<$BoardCardsTable>>[
            ($BoardCardsTable t) => OrderingTerm(expression: t.zOrder),

            // zOrder가 같을 때를 대비한 두 번째 기준입니다.
            // 기준이 하나뿐이면 같은 값끼리의 순서를 데이터베이스가 매번
            // 다르게 줄 수 있어서, 앱을 켤 때마다 겹친 카드의 위아래가 뒤바뀝니다.
            ($BoardCardsTable t) => OrderingTerm(expression: t.createdAt),
          ]);

    final List<BoardCardRow> rows = await query.get();
    return rows.map(_toCard).toList();
  }

  /// 판마다 카드가 몇 장 올라가 있는지 한 번에 세어 돌려줍니다.
  @override
  Future<Map<String, int>> countCardsByBoard() async {
    // count()는 "몇 줄인지 세기"입니다. groupBy와 함께 쓰면
    // "판별로 나눠서 각각 몇 줄인지"를 한 번의 물음으로 알 수 있습니다.
    final Expression<int> howMany = _db.boardCards.id.count();

    final JoinedSelectStatement<HasResultSet, dynamic> query =
        _db.selectOnly(_db.boardCards)
          ..addColumns(<Expression<Object>>[_db.boardCards.boardId, howMany])
          ..where(_db.boardCards.deletedAt.isNull())
          ..groupBy(<Expression<Object>>[_db.boardCards.boardId]);

    final List<TypedResult> rows = await query.get();

    final Map<String, int> counts = <String, int>{};
    for (final TypedResult row in rows) {
      final String boardId = row.read(_db.boardCards.boardId)!;
      counts[boardId] = row.read(howMany) ?? 0;
    }
    return counts;
  }

  /// 판에 카드 여러 장을 한꺼번에 올립니다.
  @override
  Future<void> addCards(List<BoardCard> cards) async {
    if (cards.isEmpty) {
      return;
    }

    // batch = 여러 번의 쓰기를 한 번에 몰아서 보내는 방법입니다.
    // 20장을 올릴 때 하나씩 넣으면 데이터베이스에 20번 오갑니다.
    await _db.batch((Batch batch) {
      batch.insertAll(_db.boardCards, cards.map(_toCompanion).toList());
    });
  }

  /// 카드 한 장의 배치를 저장합니다.
  @override
  Future<void> saveCard(BoardCard card) async {
    await _db.into(_db.boardCards).insertOnConflictUpdate(_toCompanion(card));
  }

  /// 카드 여러 장의 배치를 한꺼번에 저장합니다.
  @override
  Future<void> saveCards(List<BoardCard> cards) async {
    if (cards.isEmpty) {
      return;
    }

    // addCards와 같은 방식입니다. 하나씩 saveCard를 부르면 여러 번 오갑니다.
    await _db.batch((Batch batch) {
      batch.insertAllOnConflictUpdate(
        _db.boardCards,
        cards.map(_toCompanion).toList(),
      );
    });
  }

  /// 카드를 판에서 내립니다(소프트 삭제).
  @override
  Future<void> removeCard(String cardId) async {
    final DateTime now = DateTime.now().toUtc();

    await (_db.update(
      _db.boardCards,
    )..where(($BoardCardsTable t) => t.id.equals(cardId))).write(
      BoardCardsCompanion(
        deletedAt: Value<DateTime?>(now),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  /// 데이터베이스의 한 줄을 화면이 쓰는 모델로 바꿉니다.
  Board _toBoard(BoardRow row) {
    return Board(
      id: row.id,
      name: row.name,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// 데이터베이스의 한 줄을 화면이 쓰는 모델로 바꿉니다.
  BoardCard _toCard(BoardCardRow row) {
    return BoardCard(
      id: row.id,
      boardId: row.boardId,
      referenceId: row.referenceId,
      x: row.x,
      y: row.y,
      width: row.width,
      height: row.height,
      zOrder: row.zOrder,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// 화면이 쓰는 모델을 데이터베이스에 넣을 모양으로 바꿉니다.
  ///
  /// 넣기와 덮어쓰기 양쪽에서 같은 변환을 쓰므로 하나로 빼뒀습니다.
  /// 따로 적어두면 한쪽만 고쳐서 "새로 올릴 때는 되는데 옮기면 값이 날아가는"
  /// 종류의 문제가 생깁니다.
  BoardCardsCompanion _toCompanion(BoardCard card) {
    return BoardCardsCompanion.insert(
      id: card.id,
      boardId: card.boardId,
      referenceId: card.referenceId,
      x: card.x,
      y: card.y,
      width: Value<double>(card.width),
      height: Value<double?>(card.height),
      zOrder: Value<int>(card.zOrder),
      createdAt: card.createdAt,

      // updatedAt은 부르는 쪽 값을 쓰지 않고 지금 시각으로 덮습니다.
      // 부르는 쪽에서 챙기게 하면 언젠가 반드시 빠뜨립니다.
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
