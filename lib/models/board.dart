// 무드보드(판)와 판 위에 놓인 카드 하나를 나타내는 모델 클래스들입니다.
//
// ── 무드보드가 뭔가 ──
// 레퍼런스 목록은 컴퓨터가 정한 순서대로 줄을 세웁니다. 무드보드는 반대로
// **사람이 직접 원하는 자리에 늘어놓는 판**입니다. 색감이 비슷한 것끼리 모아두거나,
// 왼쪽에는 배경 오른쪽에는 인물처럼 의미를 담아 배치해볼 수 있습니다.
//
// ── 왜 클래스가 둘인가 ──
//   Board     — 판 그 자체 (이름)
//   BoardCard — 그 판 위에 "이 레퍼런스가 여기 놓였다"는 한 장의 배치 정보
//
// 판 하나에 카드가 여러 장 올라가고, 같은 레퍼런스를 여러 판에 올릴 수도 있어서
// 둘을 나눠야 합니다. 자세한 이유는 lib/data/tables.dart의 BoardCards 설명을 보세요.
//
// drift가 만들어주는 BoardRow / BoardCardRow가 아니라 이 클래스를 화면이 쓰는 이유는
// lib/models/reference_item.dart 맨 위 설명과 같습니다.

/// 무드보드 판 하나입니다.
class Board {
  Board({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 고유 번호(UUID v4)
  final String id;

  /// 사용자가 붙인 이름
  final String name;

  /// 만든 시각 (UTC)
  final DateTime createdAt;

  /// 마지막으로 고친 시각 (UTC)
  final DateTime updatedAt;

  /// 몇 가지만 바꾼 사본을 만들어 돌려줍니다.
  /// 왜 이런 방식인지는 reference_item.dart의 copyWith 설명을 보세요.
  Board copyWith({String? name, DateTime? updatedAt}) {
    return Board(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 무드보드 위에 놓인 카드 한 장입니다.
///
/// "어느 레퍼런스가, 판 위 어디에, 얼마만 한 크기로" 놓였는지를 담습니다.
/// 레퍼런스의 내용(제목·그림)은 여기 없습니다. 그건 ReferenceItem에 있고,
/// 화면이 [referenceId]로 짝을 지어 씁니다.
class BoardCard {
  BoardCard({
    required this.id,
    required this.boardId,
    required this.referenceId,
    required this.x,
    required this.y,
    required this.createdAt,
    required this.updatedAt,
    this.width = defaultBoardCardWidth,
    this.height,
    this.zOrder = 0,
    this.groupId,
  });

  /// 이 배치의 고유 번호(UUID v4)
  ///
  /// 레퍼런스의 번호가 아닙니다. 같은 사진을 한 판에 두 장 올리면
  /// referenceId는 같고 이 번호만 다릅니다.
  final String id;

  /// 어느 판에 놓였는지
  final String boardId;

  /// 어느 레퍼런스인지
  final String referenceId;

  /// 판 왼쪽 끝에서부터의 가로 위치
  final double x;

  /// 판 위쪽 끝에서부터의 세로 위치
  final double y;

  /// 카드의 가로 크기
  final double width;

  /// 카드의 세로 크기. **null이면 "그림 비율대로 알아서"** 라는 뜻입니다.
  ///
  /// 처음 올린 카드는 여기가 null이라 원본 비율 그대로 보입니다.
  /// 크기 조절 기능(2단계)을 붙이면 그때 값이 채워집니다.
  final double? height;

  /// 겹쳤을 때 누가 위로 오는지. 클수록 위입니다.
  final int zOrder;

  /// 이 카드가 속한 그룹의 번호입니다. 그룹에 안 속해 있으면 null입니다.
  ///
  /// 같은 groupId를 가진 카드들은 하나처럼 다뤄집니다 — 아무거나 골라도
  /// 전부 같이 골라지고, 하나를 끌면 다 같이 끌립니다. 카드의 고유 번호
  /// ([id])와는 다른 값입니다. 자세한 설명은 lib/data/tables.dart의
  /// BoardCards.groupId를 보세요.
  final String? groupId;

  /// 판에 올린 시각 (UTC)
  final DateTime createdAt;

  /// 마지막으로 옮기거나 고친 시각 (UTC)
  final DateTime updatedAt;

  /// 몇 가지만 바꾼 사본을 만들어 돌려줍니다.
  ///
  /// height·groupId는 여기서 null로 되돌릴 수 없습니다. 인자를 안 넘긴
  /// 것과 null을 넘긴 것을 구분할 수 없기 때문입니다(reference_item.dart와
  /// 같은 사정). groupId를 비우려면(그룹 해제) [ungroup]을 쓰세요.
  BoardCard copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    int? zOrder,
    String? groupId,
    DateTime? updatedAt,
  }) {
    return BoardCard(
      id: id,
      boardId: boardId,
      referenceId: referenceId,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      zOrder: zOrder ?? this.zOrder,
      groupId: groupId ?? this.groupId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 그룹에서 뺀 사본을 돌려줍니다. (그룹 해제)
  ///
  /// copyWith로는 안 됩니다 — groupId에 null을 넘겨도 "안 바꿈"으로
  /// 취급되기 때문입니다(위 copyWith 설명 참고). reference_item.dart의
  /// clearFolder()와 같은 이유로, 값을 하나하나 다시 적는 생성자를 씁니다.
  BoardCard ungroup() {
    return BoardCard(
      id: id,
      boardId: boardId,
      referenceId: referenceId,
      x: x,
      y: y,
      width: width,
      height: height,
      zOrder: zOrder,
      groupId: null,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// 판에 처음 올린 카드의 기본 가로 크기입니다.
///
/// 화면과 데이터베이스가 이 값을 함께 씁니다(lib/data/tables.dart의 `withDefault`).
/// 두 곳에 따로 적어두면 언젠가 한쪽만 고쳐서, 새로 올린 카드의 크기가
/// 화면과 저장된 값에서 서로 달라집니다. 그래서 여기 한 곳에만 둡니다.
///
/// 220으로 정한 이유: 목록 카드(최대 300)보다 조금 작습니다. 무드보드는
/// 여러 장을 한눈에 늘어놓고 보는 곳이라 한 장이 너무 크면 비교가 안 됩니다.
const double defaultBoardCardWidth = 220;

/// 카드를 줄일 수 있는 가장 작은 가로 크기입니다.
///
/// 더 작아지면 그림이 뭔지 알아볼 수 없고, 크기 조절 손잡이와 내리기 버튼이
/// 카드보다 커져서 **잡을 수가 없게** 됩니다.
const double minBoardCardWidth = 80;

/// 카드를 키울 수 있는 가장 큰 가로 크기입니다.
///
/// 판이 1920 넓이인데 카드 한 장이 그 절반을 넘으면 무드보드가 아니라
/// 그냥 큰 사진 한 장이 됩니다. 크게 보고 싶을 때는 줌을 쓰면 됩니다.
const double maxBoardCardWidth = 960;
