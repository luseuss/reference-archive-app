// 판 위의 카드를 옮기고, 크기를 바꾸고, 맨 위로 올리는 규칙을 확인하는 테스트입니다.
//
// 화면 없이 목록만 넣고 결과 목록을 봅니다. 앱을 띄우고 카드를 끌어볼 필요가
// 없어서 빠르고, 어디가 틀렸는지도 바로 드러납니다.
//
// "실제로 끌었을 때도 이대로 되는가"는 test/screens/board_screen_test.dart가 봅니다.
// 규칙이 맞는지와 그 규칙이 화면에 연결됐는지는 다른 문제라 나눠서 봅니다.

import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/models/board.dart';
import 'package:reference_archive_app/theme/app_metrics.dart';
import 'package:reference_archive_app/utils/board_card_actions.dart';

void main() {
  /// 테스트용 카드를 하나 만들어 돌려줍니다.
  BoardCard makeCard(
    String id, {
    double x = 100,
    double y = 100,
    int zOrder = 0,
  }) {
    final DateTime now = DateTime.now().toUtc();
    return BoardCard(
      id: id,
      boardId: 'board-1',
      referenceId: 'ref-$id',
      x: x,
      y: y,
      zOrder: zOrder,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 목록에서 이 번호의 카드를 꺼내옵니다.
  BoardCard cardOf(List<BoardCard> cards, String id) {
    return cards.firstWhere((BoardCard card) => card.id == id);
  }

  group('맨 위로 올리기', () {
    test('겹침 순서가 가장 큰 값보다 하나 커진다', () {
      final List<BoardCard> cards = <BoardCard>[
        makeCard('a', zOrder: 1),
        makeCard('b', zOrder: 7),
      ];

      final List<BoardCard> result = raiseCardToTop(cards, 'a');

      expect(cardOf(result, 'a').zOrder, 8);
    });

    test('목록의 맨 뒤로 옮겨진다', () {
      // 화면은 목록 순서대로 겹쳐 그립니다. 순서를 안 바꾸면 zOrder만
      // 커지고 화면에서는 여전히 깔려 있습니다.
      final List<BoardCard> cards = <BoardCard>[
        makeCard('a'),
        makeCard('b'),
        makeCard('c'),
      ];

      final List<BoardCard> result = raiseCardToTop(cards, 'a');

      expect(result.map((BoardCard c) => c.id).toList(), <String>[
        'b',
        'c',
        'a',
      ]);
    });

    test('다른 카드는 건드리지 않는다', () {
      final List<BoardCard> cards = <BoardCard>[
        makeCard('a', zOrder: 1),
        makeCard('b', zOrder: 7),
      ];

      final List<BoardCard> result = raiseCardToTop(cards, 'a');

      expect(cardOf(result, 'b').zOrder, 7);
    });

    test('없는 카드를 올리라고 하면 그대로 둔다', () {
      // 카드를 내린 직후처럼 잠깐 어긋날 수 있습니다. 오류가 나면 안 됩니다.
      final List<BoardCard> cards = <BoardCard>[makeCard('a')];

      expect(raiseCardToTop(cards, '없는-번호'), cards);
    });
  });

  group('옮기기', () {
    test('움직인 만큼 자리가 바뀐다', () {
      final List<BoardCard> cards = <BoardCard>[makeCard('a', x: 100, y: 100)];

      final List<BoardCard> result = moveCard(cards, 'a', const Offset(30, 40));

      expect(cardOf(result, 'a').x, 130);
      expect(cardOf(result, 'a').y, 140);
    });

    test('판 밖으로는 나가지 않는다', () {
      final List<BoardCard> cards = <BoardCard>[makeCard('a', x: 10, y: 10)];

      final List<BoardCard> result = moveCard(
        cards,
        'a',
        const Offset(-500, -500),
      );

      expect(cardOf(result, 'a').x, 0);
      expect(cardOf(result, 'a').y, 0);
    });

    test('원래 목록은 그대로 남는다', () {
      // 받은 목록을 직접 뜯어고치면 부른 쪽에서 "언제 바뀐 거지?" 하고 헤맵니다.
      final List<BoardCard> cards = <BoardCard>[makeCard('a', x: 100)];

      moveCard(cards, 'a', const Offset(50, 0));

      expect(cards.first.x, 100);
    });
  });

  group('크기 바꾸기', () {
    test('가로로 끈 만큼 넓어진다', () {
      final List<BoardCard> cards = <BoardCard>[makeCard('a', x: 0)];

      final List<BoardCard> result = resizeCard(
        cards,
        'a',
        startSize: const Size(200, 150),
        movedSoFar: const Offset(100, 0),
      );

      expect(cardOf(result, 'a').width, 300);
    });

    test('가로세로 비율이 그대로 유지된다', () {
      // ── 이게 가장 중요합니다 ──
      // 가로만 늘어나고 세로가 그대로면 그림이 찌그러집니다.
      final List<BoardCard> cards = <BoardCard>[makeCard('a', x: 0)];

      final List<BoardCard> result = resizeCard(
        cards,
        'a',
        startSize: const Size(200, 150),
        movedSoFar: const Offset(100, 0),
      );

      final BoardCard resized = cardOf(result, 'a');
      expect(resized.height! / resized.width, closeTo(150 / 200, 0.001));
    });

    test('세로로 끈 거리는 무시한다', () {
      // 가로세로를 함께 보면 어느 쪽을 따를지 정해야 하는데, 어느 쪽으로
      // 정해도 다른 쪽으로 끌 때 손가락과 모서리가 어긋납니다.
      final List<BoardCard> cards = <BoardCard>[makeCard('a', x: 0)];

      final List<BoardCard> onlyWidth = resizeCard(
        cards,
        'a',
        startSize: const Size(200, 150),
        movedSoFar: const Offset(100, 0),
      );
      final List<BoardCard> withHeight = resizeCard(
        cards,
        'a',
        startSize: const Size(200, 150),
        movedSoFar: const Offset(100, 400),
      );

      expect(cardOf(withHeight, 'a').width, cardOf(onlyWidth, 'a').width);
    });

    test('너무 작게는 못 줄인다', () {
      final List<BoardCard> cards = <BoardCard>[makeCard('a', x: 0)];

      final List<BoardCard> result = resizeCard(
        cards,
        'a',
        startSize: const Size(200, 150),
        movedSoFar: const Offset(-9999, 0),
      );

      expect(cardOf(result, 'a').width, minBoardCardWidth);
    });

    test('판 오른쪽 끝을 넘지 않는다', () {
      const double cardX = boardWidth - 300;
      final List<BoardCard> cards = <BoardCard>[makeCard('a', x: cardX)];

      final List<BoardCard> result = resizeCard(
        cards,
        'a',
        startSize: const Size(200, 150),
        movedSoFar: const Offset(9999, 0),
      );

      expect(cardOf(result, 'a').width, 300);
    });

    test('세로 사진을 키워도 카드 아래가 판 밖으로 안 나간다', () {
      // ── 왜 이걸 확인하나 ──
      // 손잡이는 카드의 **오른쪽 아래**에 있습니다. 카드 아래쪽이 판 밖으로
      // 나가면 손잡이도 함께 나가서, 다시 잡아 줄일 수가 없게 됩니다.
      // 크기는 손을 뗄 때 저장되므로 앱을 껐다 켜도 그대로입니다.
      //
      // 3:4 세로 사진(220 x 293)을 판 맨 위에서 최대한 키워봅니다.
      final List<BoardCard> cards = <BoardCard>[makeCard('a', x: 0, y: 0)];

      final List<BoardCard> result = resizeCard(
        cards,
        'a',
        startSize: const Size(220, 293),
        movedSoFar: const Offset(9999, 0),
      );

      final BoardCard resized = cardOf(result, 'a');

      expect(resized.y + resized.height!, lessThanOrEqualTo(boardHeight));
    });

    test('아래쪽에 놓인 카드는 그만큼만 커진다', () {
      // 판 아래쪽 끝에서 400만큼 위에 있는 4:3 가로 사진입니다.
      // 세로가 400을 넘지 못하므로 가로도 따라서 막힙니다.
      final List<BoardCard> cards = <BoardCard>[
        makeCard('a', x: 0, y: boardHeight - 400),
      ];

      final List<BoardCard> result = resizeCard(
        cards,
        'a',
        startSize: const Size(200, 150),
        movedSoFar: const Offset(9999, 0),
      );

      final BoardCard resized = cardOf(result, 'a');

      expect(resized.height, lessThanOrEqualTo(400));
      expect(resized.y + resized.height!, lessThanOrEqualTo(boardHeight));
    });

    test('처음 크기를 못 쟀으면 그대로 둔다', () {
      // 그림이 아직 안 읽혀서 가로가 0인 경우입니다.
      // 그대로 계산하면 0으로 나누게 됩니다.
      final List<BoardCard> cards = <BoardCard>[makeCard('a')];

      final List<BoardCard> result = resizeCard(
        cards,
        'a',
        startSize: Size.zero,
        movedSoFar: const Offset(100, 0),
      );

      expect(result, cards);
    });
  });

  group('가장 위 겹침 순서 세기', () {
    test('카드가 없으면 0이다', () {
      expect(topZOrderOf(<BoardCard>[]), 0);
    });

    test('가장 큰 값을 돌려준다', () {
      final List<BoardCard> cards = <BoardCard>[
        makeCard('a', zOrder: 2),
        makeCard('b', zOrder: 9),
        makeCard('c', zOrder: 5),
      ];

      expect(topZOrderOf(cards), 9);
    });
  });
}
