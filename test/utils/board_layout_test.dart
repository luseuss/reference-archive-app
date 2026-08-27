// 무드보드에서 "카드를 어디에 둘 것인가"를 계산하는 함수들을 확인하는 테스트입니다.
//
// 화면 없이 숫자만 확인합니다. 앱을 띄우고 카드를 끌어볼 필요가 없어서 빠릅니다.
// 이런 계산을 화면 파일에서 따로 빼둔 이유가 바로 이것입니다.

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/models/board.dart';
import 'package:reference_archive_app/theme/app_metrics.dart';
import 'package:reference_archive_app/utils/board_layout.dart';

void main() {
  /// 테스트용 카드를 하나 만들어 돌려줍니다.
  BoardCard makeCard({double x = 0, double y = 0, double? height}) {
    final DateTime now = DateTime.now().toUtc();
    return BoardCard(
      id: 'card-1',
      boardId: 'board-1',
      referenceId: 'ref-1',
      x: x,
      y: y,
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
      // 그림 비율은 파일을 읽어봐야 알 수 있어서, 그 전에는 어림값을 씁니다.
      expect(
        estimatedBoardCardHeight(makeCard()),
        defaultBoardCardWidth * 3 / 4,
      );
    });
  });

  group('판 밖으로 나가지 않게 붙잡기', () {
    test('판 안쪽 위치는 그대로 둔다', () {
      final Offset result = clampToBoard(100, 200, makeCard());

      expect(result.dx, 100);
      expect(result.dy, 200);
    });

    test('왼쪽·위로 넘어가면 0으로 붙인다', () {
      // 이걸 안 막으면 카드가 판 바깥으로 나가서 화면에 아예 안 보이게 됩니다.
      final Offset result = clampToBoard(-50, -80, makeCard());

      expect(result.dx, 0);
      expect(result.dy, 0);
    });

    test('오른쪽으로 넘어가면 카드가 판 안에 다 들어오도록 당긴다', () {
      final Offset result = clampToBoard(boardWidth + 1000, 0, makeCard());

      expect(result.dx, boardWidth - defaultBoardCardWidth);
    });

    test('아래로 넘어가면 카드 윗부분이 판 안에 남도록 당긴다', () {
      final Offset result = clampToBoard(0, boardHeight + 1000, makeCard());

      // 정확한 높이를 모르므로 어림 높이만큼 띄웁니다. 어림이 틀려서 카드가
      // 더 길더라도 **윗부분은 반드시 판 안에 남아** 다시 잡을 수 있습니다.
      expect(result.dy, boardHeight - defaultBoardCardWidth * 3 / 4);
    });

    test('카드가 판보다 커도 오류가 나지 않는다', () {
      // clamp는 "최솟값이 최댓값보다 크면" 오류를 냅니다. 그 경우를 막아뒀는지 봅니다.
      final Offset result = clampToBoard(
        100,
        100,
        makeCard(height: boardHeight * 2),
      );

      expect(result.dy, 0);
    });
  });

  group('새로 올린 카드 자리 정하기', () {
    test('첫 장은 왼쪽 위 여백만큼 띄운 자리에 놓인다', () {
      final Offset first = initialCardPosition(0);

      expect(first.dx, boardPlacementMargin);
      expect(first.dy, boardPlacementMargin);
    });

    test('두 번째 장은 첫 장 오른쪽에 놓인다', () {
      final Offset first = initialCardPosition(0);
      final Offset second = initialCardPosition(1);

      expect(second.dy, first.dy, reason: '같은 줄이어야 합니다');
      expect(
        second.dx,
        first.dx + defaultBoardCardWidth + boardPlacementSpacing,
      );
    });

    test('한 줄이 차면 아랫줄로 넘어간다', () {
      // 몇 장에서 줄이 바뀌는지는 판 너비에 달려 있으므로, 여기서 직접
      // 세지 않고 "언젠가 반드시 아랫줄로 내려간다"만 확인합니다.
      final Offset first = initialCardPosition(0);

      Offset? wrapped;
      for (int index = 1; index < 100; index++) {
        final Offset position = initialCardPosition(index);
        if (position.dy > first.dy) {
          wrapped = position;
          break;
        }
      }

      expect(wrapped, isNotNull, reason: '100장을 놓아도 줄이 안 바뀌면 이상합니다');
      expect(wrapped!.dx, first.dx, reason: '아랫줄은 다시 왼쪽에서 시작해야 합니다');
    });

    test('놓이는 자리는 판 안이다', () {
      // 처음부터 판 밖에 놓이면 사용자는 올린 카드를 찾지 못합니다.
      for (int index = 0; index < 30; index++) {
        final Offset position = initialCardPosition(index);

        expect(position.dx, lessThan(boardWidth));
        expect(position.dy, lessThan(boardHeight));
      }
    });
  });
}
