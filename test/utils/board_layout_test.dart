// 무드보드에서 "카드가 어디에 놓이는가"를 계산하는 함수들을 확인하는 테스트입니다.
//
// 화면 없이 숫자만 확인합니다. 앱을 띄우고 카드를 끌어볼 필요가 없어서 빠릅니다.
// 이런 계산을 화면 파일에서 따로 빼둔 이유가 바로 이것입니다.
//
// "어느 배율로 어디를 보고 있는가"는 board_view_test.dart가 봅니다.

import 'dart:ui' show Offset, Rect, Size;

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

  group('카드 높이 어림잡기', () {
    test('직접 정해둔 높이가 있으면 그 값을 쓴다', () {
      expect(estimatedBoardCardHeight(makeCard(height: 500)), 500);
    });

    test('정해둔 높이가 없으면 4:3으로 어림잡는다', () {
      expect(estimatedBoardCardHeight(makeCard(width: 200)), 150);
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

  group('카드를 그릴 자리의 크기', () {
    test('카드가 없어도 최소 크기는 나온다', () {
      // 카드가 몇 장 없다고 판이 손바닥만 하면 어색합니다.
      final Size size = boardCanvasSize(<BoardCard>[]);

      expect(size.width, minCanvasWidth);
      expect(size.height, minCanvasHeight);
    });

    test('카드가 오른쪽으로 멀리 가면 그만큼 넓어진다', () {
      // ── 이게 "판에 끝이 없다"의 알맹이입니다 ──
      // 카드를 오른쪽으로 끌면 그릴 자리가 따라 늘어납니다. 그래서 끝에
      // 부딪히는 일이 없습니다.
      final BoardCard far = makeCard(x: 5000, y: 0, width: 200, height: 100);

      final Size size = boardCanvasSize(<BoardCard>[far]);

      expect(size.width, 5200 + canvasBreathingRoom);
    });

    test('아래로 멀리 가도 마찬가지다', () {
      final BoardCard far = makeCard(x: 0, y: 4000, width: 200, height: 100);

      expect(
        boardCanvasSize(<BoardCard>[far]).height,
        4100 + canvasBreathingRoom,
      );
    });

    test('카드가 끝에 닿아도 더 밀 자리가 남는다', () {
      // 카드의 오른쪽 끝보다 자리가 넓어야 계속 끌 수 있습니다.
      final BoardCard card = makeCard(x: 3000, y: 0, width: 200, height: 100);

      expect(
        boardCanvasSize(<BoardCard>[card]).width,
        greaterThan(3200),
      );
    });
  });

  group('카드를 판 안으로 붙잡기', () {
    test('오른쪽·아래로는 얼마든지 갈 수 있다', () {
      // 판에 끝이 없습니다. 아무리 큰 값이어도 그대로 둡니다.
      expect(clampToCanvas(99999, 88888), const Offset(99999, 88888));
    });

    test('왼쪽으로 넘어가면 0으로 붙인다', () {
      // 음수 자리에 놓인 카드는 클릭이 안 닿아서 잡을 수가 없습니다.
      expect(clampToCanvas(-50, 100), const Offset(0, 100));
    });

    test('위로 넘어가도 0으로 붙인다', () {
      expect(clampToCanvas(100, -50), const Offset(100, 0));
    });

    test('둘 다 넘어가면 둘 다 붙인다', () {
      expect(clampToCanvas(-10, -10), Offset.zero);
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
