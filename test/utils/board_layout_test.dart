// 무드보드에서 "카드가 어디에 놓이는가"를 계산하는 함수들을 확인하는 테스트입니다.
//
// 화면 없이 숫자만 확인합니다. 앱을 띄우고 카드를 끌어볼 필요가 없어서 빠릅니다.
// 이런 계산을 화면 파일에서 따로 빼둔 이유가 바로 이것입니다.
//
// "어느 배율로 어디를 보고 있는가"는 board_view_test.dart가 봅니다.

import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/models/board.dart';
import 'package:reference_archive_app/theme/app_metrics.dart';
import 'package:reference_archive_app/utils/board_layout.dart';

void main() {
  /// 테스트용 카드를 하나 만들어 돌려줍니다.
  BoardCard makeCard({
    double x = 0,
    double y = 0,
    double width = defaultBoardCardWidth,
    double? height,
  }) {
    final DateTime now = DateTime.now().toUtc();
    return BoardCard(
      id: 'card-1',
      boardId: 'board-1',
      referenceId: 'ref-1',
      x: x,
      y: y,
      width: width,
      height: height,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('카드 높이 구하기', () {
    test('직접 정해둔 높이가 있으면 그 값을 쓴다', () {
      expect(boardCardHeight(makeCard(height: 500)), 500);
    });

    test('재서 알려준 값이 있으면 그 값을 쓴다', () {
      // ── 이게 스냅에 아주 중요합니다 ──
      // 카드 높이는 보통 저장돼 있지 않고 그림 비율이 정합니다. 어림값에
      // 기대면 세로 스냅이 **눈에 보이지도 않는 자리**에 붙습니다.
      final BoardCard card = makeCard(width: 200);

      expect(
        boardCardHeight(card, measuredHeights: <String, double>{card.id: 267}),
        267,
      );
    });

    test('직접 정해둔 높이가 잰 값보다 우선한다', () {
      // 사용자가 직접 조절한 크기가 가장 확실합니다.
      final BoardCard card = makeCard(width: 200, height: 500);

      expect(
        boardCardHeight(card, measuredHeights: <String, double>{card.id: 267}),
        500,
      );
    });

    test('둘 다 없으면 4:3으로 어림잡는다', () {
      // 그림이 아직 안 읽힌 짧은 순간에만 여기까지 옵니다.
      expect(boardCardHeight(makeCard(width: 200)), 150);
    });
  });

  group('카드가 놓인 범위', () {
    test('카드가 없으면 빈 네모다', () {
      // 빈 네모를 돌려주면 부르는 쪽에서 "비었으면 이렇게 하자"를 정할 수
      // 있습니다. 여기서 기본값을 지어내면 오히려 헷갈립니다.
      expect(boardContentBounds(<BoardCard>[]), Rect.zero);
    });

    test('한 장이면 그 카드의 네모다', () {
      final BoardCard card = makeCard(x: 100, y: 50, width: 200, height: 150);

      expect(
        boardContentBounds(<BoardCard>[card]),
        const Rect.fromLTWH(100, 50, 200, 150),
      );
    });

    test('여러 장이면 전부를 감싼다', () {
      final List<BoardCard> cards = <BoardCard>[
        makeCard(x: 100, y: 100, width: 200, height: 100),
        makeCard(x: 500, y: 400, width: 200, height: 100),
      ];

      // 왼쪽 위는 (100, 100), 오른쪽 아래는 (700, 500)
      expect(
        boardContentBounds(cards),
        const Rect.fromLTRB(100, 100, 700, 500),
      );
    });

    test('높이를 안 정한 카드는 어림 높이로 잰다', () {
      final BoardCard card = makeCard(x: 0, y: 0, width: 200);

      expect(boardContentBounds(<BoardCard>[card]).bottom, 150);
    });
  });

  group('카드를 그릴 자리', () {
    test('카드가 없으면 기본 크기로 왼쪽 위에 둔다', () {
      final Rect rect = boardCanvasRect(<BoardCard>[]);

      expect(rect.topLeft, Offset.zero);
      expect(rect.width, minCanvasWidth);
      expect(rect.height, minCanvasHeight);
    });

    test('카드 둘레로 사방에 여유를 둔다', () {
      // 카드가 상자 끝에 딱 붙어 있으면 그쪽으로 더 밀 자리가 없습니다.
      final BoardCard card = makeCard(x: 100, y: 200, width: 300, height: 200);

      final Rect rect = boardCanvasRect(<BoardCard>[card]);

      expect(rect.left, 100 - canvasBreathingRoom);
      expect(rect.top, 200 - canvasBreathingRoom);
      expect(rect.right, 400 + canvasBreathingRoom);
      expect(rect.bottom, 400 + canvasBreathingRoom);
    });

    test('카드가 음수 자리에 있으면 상자도 따라 간다', () {
      // ── 이게 사방 무한의 알맹이입니다 ──
      // 상자를 (0, 0)에 고정해두면 음수 자리 카드는 상자 바깥이 되어
      // **클릭이 안 닿습니다.** 상자가 따라가면 그럴 일이 없습니다.
      final BoardCard card = makeCard(x: -900, y: -700, width: 200, height: 150);

      final Rect rect = boardCanvasRect(<BoardCard>[card]);

      expect(rect.left, lessThan(-900));
      expect(rect.top, lessThan(-700));
    });

    test('어느 카드든 상자 안에 들어온다', () {
      // 상자 밖으로 삐져나온 카드는 클릭이 안 닿습니다.
      // 어느 방향이든 반드시 안에 있어야 합니다.
      final List<BoardCard> cards = <BoardCard>[
        makeCard(x: -5000, y: 300, width: 200, height: 150),
        makeCard(x: 4000, y: -2000, width: 200, height: 150),
        makeCard(x: 0, y: 0, width: 200, height: 150),
      ];

      final Rect rect = boardCanvasRect(cards);

      for (final BoardCard card in cards) {
        expect(rect.contains(boardCardRect(card).topLeft), isTrue);
        expect(rect.contains(boardCardRect(card).bottomRight), isTrue);
      }
    });

    test('카드가 멀어지면 상자도 넓어진다', () {
      final Rect near = boardCanvasRect(<BoardCard>[
        makeCard(x: 0, y: 0, width: 200, height: 150),
      ]);
      final Rect far = boardCanvasRect(<BoardCard>[
        makeCard(x: 0, y: 0, width: 200, height: 150),
        makeCard(x: 9000, y: 8000, width: 200, height: 150),
      ]);

      expect(far.width, greaterThan(near.width));
      expect(far.height, greaterThan(near.height));
    });
  });

  group('새 카드 놓을 자리', () {
    test('첫 장은 왼쪽 위 여백만큼 띄운 자리에 놓인다', () {
      expect(
        initialCardPosition(0),
        const Offset(boardPlacementMargin, boardPlacementMargin),
      );
    });

    test('두 번째 장은 첫 장 오른쪽에 놓인다', () {
      final Offset first = initialCardPosition(0);
      final Offset second = initialCardPosition(1);

      expect(second.dy, first.dy);
      expect(second.dx, greaterThan(first.dx));
    });

    test('한 줄이 차면 아랫줄로 넘어간다', () {
      // 한 줄에 몇 장이 들어가는지는 boardPlacementRowWidth가 정합니다.
      // 판의 크기가 아니라 "늘어놓는 폭"입니다.
      final Offset first = initialCardPosition(0);

      Offset? wrapped;
      for (int i = 1; i < 50; i++) {
        final Offset position = initialCardPosition(i);
        if (position.dy > first.dy) {
          wrapped = position;
          break;
        }
      }

      expect(wrapped, isNotNull);
      expect(wrapped!.dx, first.dx);
    });

    test('놓이는 자리는 언제나 0 이상이다', () {
      for (int i = 0; i < 30; i++) {
        final Offset position = initialCardPosition(i);
        expect(position.dx, greaterThanOrEqualTo(0));
        expect(position.dy, greaterThanOrEqualTo(0));
      }
    });
  });

  group('크기 조절 중 카드 가로 크기 붙잡기', () {
    test('너무 작게는 못 줄인다', () {
      // 더 작아지면 손잡이와 내리기 버튼이 카드보다 커져서 잡을 수가 없습니다.
      expect(clampResizedCardWidth(1), minBoardCardWidth);
    });

    test('너무 크게는 못 키운다', () {
      expect(clampResizedCardWidth(99999), maxBoardCardWidth);
    });

    test('그 사이 값은 그대로 둔다', () {
      expect(clampResizedCardWidth(400), 400);
    });

    // 판 끝을 넘지 않게 막던 규칙은 없어졌습니다. 판에 끝이 없어서
    // 떨어져 나갈 곳이 없습니다. 크게 키워 화면 밖으로 나가더라도
    // 축소하거나 ⛶를 누르면 다시 보입니다.
  });
}
