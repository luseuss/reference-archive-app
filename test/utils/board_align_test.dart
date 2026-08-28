// 선택된 카드들을 나란히 맞추는 계산(6단계 정렬·분배 툴바)을 확인하는
// 테스트입니다.
//
// 화면 없이 숫자만 봅니다. 실제 끌기에 연결됐는지는
// test/screens/board_screen_test.dart가 봅니다.

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/models/board.dart';
import 'package:reference_archive_app/utils/board_align.dart';

void main() {
  /// 테스트용 카드를 하나 만들어 돌려줍니다.
  BoardCard makeCard(
    String id, {
    double x = 0,
    double y = 0,
    double width = 200,
    double? height,
    int zOrder = 0,
  }) {
    final DateTime now = DateTime.now().toUtc();
    return BoardCard(
      id: id,
      boardId: 'board-1',
      referenceId: 'ref-$id',
      x: x,
      y: y,
      width: width,
      height: height,
      zOrder: zOrder,
      createdAt: now,
      updatedAt: now,
    );
  }

  BoardCard cardOf(List<BoardCard> cards, String id) {
    return cards.firstWhere((BoardCard card) => card.id == id);
  }

  group('가로 정렬', () {
    test('왼쪽 정렬 — 선택 범위의 가장 왼쪽에 맞춘다', () {
      final List<BoardCard> cards = <BoardCard>[
        makeCard('a', x: 100, width: 200), // 왼쪽 끝: 100
        makeCard('b', x: 500, width: 200), // 왼쪽 끝: 500
      ];

      final List<BoardCard> result = alignSelectedCards(
        cards,
        <String>{'a', 'b'},
        BoardAlignMode.left,
      );

      expect(cardOf(result, 'a').x, 100);
      expect(cardOf(result, 'b').x, 100);
    });

    test('오른쪽 정렬 — 선택 범위의 가장 오른쪽에 맞춘다', () {
      final List<BoardCard> cards = <BoardCard>[
        makeCard('a', x: 100, width: 200), // 오른쪽 끝: 300
        makeCard('b', x: 500, width: 100), // 오른쪽 끝: 600
      ];

      final List<BoardCard> result = alignSelectedCards(
        cards,
        <String>{'a', 'b'},
        BoardAlignMode.right,
      );

      // a는 오른쪽 끝이 600이 되도록: x = 600 - 200 = 400
      expect(cardOf(result, 'a').x, 400);
      // b는 이미 오른쪽 끝이 600이라 그대로.
      expect(cardOf(result, 'b').x, 500);
    });

    test('가운데 정렬(가로) — 선택 범위의 가로 가운데에 맞춘다', () {
      final List<BoardCard> cards = <BoardCard>[
        makeCard('a', x: 0, width: 100), // 범위: 0~100
        makeCard('b', x: 300, width: 100), // 범위: 300~400
      ];
      // 전체 범위: 0~400, 가운데 x는 200.

      final List<BoardCard> result = alignSelectedCards(
        cards,
        <String>{'a', 'b'},
        BoardAlignMode.hcenter,
      );

      // a(폭 100)의 가운데가 200이 되도록: x = 150
      expect(cardOf(result, 'a').x, 150);
      expect(cardOf(result, 'b').x, 150);
    });
  });

  group('세로 정렬', () {
    test('위 정렬 — 선택 범위의 가장 위에 맞춘다', () {
      final List<BoardCard> cards = <BoardCard>[
        makeCard('a', y: 50, height: 100),
        makeCard('b', y: 400, height: 100),
      ];

      final List<BoardCard> result = alignSelectedCards(
        cards,
        <String>{'a', 'b'},
        BoardAlignMode.top,
      );

      expect(cardOf(result, 'a').y, 50);
      expect(cardOf(result, 'b').y, 50);
    });

    test('아래 정렬 — 선택 범위의 가장 아래에 맞춘다', () {
      final List<BoardCard> cards = <BoardCard>[
        makeCard('a', y: 50, height: 100), // 아래 끝: 150
        makeCard('b', y: 400, height: 200), // 아래 끝: 600
      ];

      final List<BoardCard> result = alignSelectedCards(
        cards,
        <String>{'a', 'b'},
        BoardAlignMode.bottom,
      );

      // a는 아래 끝이 600이 되도록: y = 600 - 100 = 500
      expect(cardOf(result, 'a').y, 500);
      expect(cardOf(result, 'b').y, 400);
    });

    test('가운데 정렬(세로) — 선택 범위의 세로 가운데에 맞춘다', () {
      final List<BoardCard> cards = <BoardCard>[
        makeCard('a', y: 0, height: 100), // 범위: 0~100
        makeCard('b', y: 300, height: 100), // 범위: 300~400
      ];
      // 전체 범위: 0~400, 가운데 y는 200.

      final List<BoardCard> result = alignSelectedCards(
        cards,
        <String>{'a', 'b'},
        BoardAlignMode.vcenter,
      );

      expect(cardOf(result, 'a').y, 150);
      expect(cardOf(result, 'b').y, 150);
    });
  });

  group('그밖의 경우', () {
    test('높이가 비어 있으면 재서 알려준 값을 쓴다', () {
      // 카드 높이는 보통 저장돼 있지 않고 그림 비율이 정합니다. 재서
      // 알려준 값(measuredHeights)이 없으면 정렬이 엉뚱한 자리에 맞춰집니다.
      // (board_layout.dart의 boardCardHeight와 같은 이유)
      final List<BoardCard> cards = <BoardCard>[
        makeCard('a', y: 0, width: 200), // 높이 비어 있음
        makeCard('b', y: 500, height: 100),
      ];

      final List<BoardCard> result = alignSelectedCards(
        cards,
        <String>{'a', 'b'},
        BoardAlignMode.bottom,
        measuredHeights: <String, double>{'a': 50},
      );

      // a의 실제 높이 50을 써서: y = 600 - 50 = 550
      expect(cardOf(result, 'a').y, 550);
    });

    test('선택이 한 장뿐이면 그대로 둔다', () {
      // 정렬은 "여럿을 나란히 맞추는" 동작이라 한 장으로는 뜻이 없습니다.
      final List<BoardCard> cards = <BoardCard>[makeCard('a', x: 100)];

      final List<BoardCard> result = alignSelectedCards(
        cards,
        <String>{'a'},
        BoardAlignMode.left,
      );

      expect(cardOf(result, 'a').x, 100);
    });

    test('선택 안 된 카드는 안 건드린다', () {
      final List<BoardCard> cards = <BoardCard>[
        makeCard('a', x: 100, width: 200),
        makeCard('b', x: 500, width: 200),
        makeCard('outside', x: 999, width: 200),
      ];

      final List<BoardCard> result = alignSelectedCards(
        cards,
        <String>{'a', 'b'},
        BoardAlignMode.left,
      );

      expect(cardOf(result, 'outside').x, 999);
    });

    test('원래 목록은 그대로 남는다', () {
      final List<BoardCard> cards = <BoardCard>[
        makeCard('a', x: 100, width: 200),
        makeCard('b', x: 500, width: 200),
      ];

      alignSelectedCards(cards, <String>{'a', 'b'}, BoardAlignMode.left);

      expect(cardOf(cards, 'a').x, 100, reason: '받은 목록을 직접 고치면 안 됩니다');
    });
  });

  group('크기 맞추기', () {
    test('기준 카드의 크기로 나머지가 바뀐다', () {
      final List<BoardCard> cards = <BoardCard>[
        makeCard('a', width: 200, height: 150),
        makeCard('b', width: 300, height: 300),
      ];

      final List<BoardCard> result = matchSizeSelectedCards(
        cards,
        <String>{'a', 'b'},
        'a',
      );

      expect(cardOf(result, 'b').width, 200);
      expect(cardOf(result, 'b').height, 150);
    });

    test('기준 카드 자신은 안 바뀐다', () {
      final List<BoardCard> cards = <BoardCard>[
        makeCard('a', width: 200, height: 150),
        makeCard('b', width: 300, height: 300),
      ];

      final List<BoardCard> result = matchSizeSelectedCards(
        cards,
        <String>{'a', 'b'},
        'a',
      );

      expect(cardOf(result, 'a').width, 200);
      expect(cardOf(result, 'a').height, 150);
    });

    test('위치(x, y)는 안 건드린다', () {
      final List<BoardCard> cards = <BoardCard>[
        makeCard('a', x: 0, y: 0, width: 200, height: 150),
        makeCard('b', x: 777, y: 888, width: 300, height: 300),
      ];

      final List<BoardCard> result = matchSizeSelectedCards(
        cards,
        <String>{'a', 'b'},
        'a',
      );

      expect(cardOf(result, 'b').x, 777);
      expect(cardOf(result, 'b').y, 888);
    });

    test('기준 카드의 높이가 비어 있으면 재서 알려준 값을 쓴다', () {
      final List<BoardCard> cards = <BoardCard>[
        makeCard('a', width: 200), // 높이 비어 있음(그림 비율대로)
        makeCard('b', width: 300, height: 300),
      ];

      final List<BoardCard> result = matchSizeSelectedCards(
        cards,
        <String>{'a', 'b'},
        'a',
        measuredHeights: <String, double>{'a': 140},
      );

      expect(cardOf(result, 'b').height, 140);
    });

    test('선택 안 된 카드는 안 건드린다', () {
      final List<BoardCard> cards = <BoardCard>[
        makeCard('a', width: 200, height: 150),
        makeCard('b', width: 300, height: 300),
        makeCard('outside', width: 999, height: 999),
      ];

      final List<BoardCard> result = matchSizeSelectedCards(
        cards,
        <String>{'a', 'b'},
        'a',
      );

      expect(cardOf(result, 'outside').width, 999);
    });
  });
}
