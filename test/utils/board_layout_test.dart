// 무드보드에서 "카드를 어디에 둘 것인가"를 계산하는 함수들을 확인하는 테스트입니다.
//
// 화면 없이 숫자만 확인합니다. 앱을 띄우고 카드를 끌어볼 필요가 없어서 빠릅니다.
// 이런 계산을 화면 파일에서 따로 빼둔 이유가 바로 이것입니다.

import 'dart:ui' show Size;

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

  group('판 전체가 보이는 배율 구하기', () {
    test('화면이 판보다 작으면 줄여서 맞춘다', () {
      // 가로가 더 빡빡한 경우입니다. 세로에 맞추면 가로가 넘칩니다.
      final double scale = fitBoardScale(
        Size(boardWidth / 2, boardHeight),
      );

      expect(scale, 0.5);
    });

    test('가로·세로 중 더 빡빡한 쪽에 맞춘다', () {
      final double scale = fitBoardScale(
        Size(boardWidth, boardHeight / 4),
      );

      expect(scale, 0.25);
    });

    test('화면이 판보다 커도 1배를 넘지 않는다', () {
      // 억지로 늘리면 그림이 흐려집니다. 원래 크기로 가운데에 두는 편이 낫습니다.
      final double scale = fitBoardScale(
        Size(boardWidth * 3, boardHeight * 3),
      );

      expect(scale, 1.0);
    });
  });

  group('배율 붙잡기', () {
    test('판 전체가 보이는 배율보다 더 줄일 수 없다', () {
      // 더 줄여봐야 판 주위의 빈 공간만 넓어질 뿐입니다.
      final Size viewport = Size(boardWidth / 2, boardHeight / 2);

      expect(clampBoardScale(0.01, viewport), fitBoardScale(viewport));
    });

    test('최대 배율보다 더 키울 수 없다', () {
      final Size viewport = Size(boardWidth, boardHeight);

      expect(clampBoardScale(100, viewport), maxBoardScale);
    });

    test('그 사이 값은 그대로 둔다', () {
      final Size viewport = Size(boardWidth, boardHeight);

      expect(clampBoardScale(1.5, viewport), 1.5);
    });

    test('화면이 아주 작아도 오류가 나지 않는다', () {
      // 이때는 "판 전체가 보이는 배율"이 최대 배율보다 클 수도 있습니다.
      // 막아두지 않으면 clamp가 "최솟값이 최댓값보다 크다"며 오류를 냅니다.
      final Size viewport = Size(boardWidth * 10, boardHeight * 10);

      expect(clampBoardScale(1, viewport), isNotNull);
    });
  });

  group('판이 화면 밖으로 밀려나지 않게 붙잡기', () {
    test('판이 화면보다 작으면 가운데에 둔다', () {
      final Size viewport = Size(boardWidth * 2, boardHeight * 2);

      final Offset result = clampBoardOffset(Offset.zero, 1.0, viewport);

      expect(result.dx, (viewport.width - boardWidth) / 2);
      expect(result.dy, (viewport.height - boardHeight) / 2);
    });

    test('판이 화면보다 크면 왼쪽 끝을 넘겨 밀 수 없다', () {
      // 여기서 안 막으면 판을 화면 밖으로 완전히 밀어내고 빈 화면만 보게 됩니다.
      final Size viewport = Size(boardWidth / 2, boardHeight / 2);

      final Offset result = clampBoardOffset(const Offset(500, 500), 1.0, viewport);

      expect(result.dx, 0);
      expect(result.dy, 0);
    });

    test('판이 화면보다 크면 오른쪽 끝도 넘길 수 없다', () {
      final Size viewport = Size(boardWidth / 2, boardHeight / 2);

      final Offset result = clampBoardOffset(
        const Offset(-99999, -99999),
        1.0,
        viewport,
      );

      expect(result.dx, viewport.width - boardWidth);
      expect(result.dy, viewport.height - boardHeight);
    });
  });

  group('가리키는 자리를 붙잡은 채 확대하기', () {
    test('가리킨 지점은 확대해도 같은 자리에 남는다', () {
      // ── 이게 이 계산의 전부입니다 ──
      // 안 그러면 확대할 때마다 보고 있던 곳이 화면 밖으로 밀려나서,
      // 확대하고 다시 찾아가고를 반복하게 됩니다.
      const Offset focal = Offset(300, 200);
      const Offset offset = Offset(50, 20);

      final Offset next = zoomAroundPoint(
        focalPoint: focal,
        offset: offset,
        fromScale: 1.0,
        toScale: 2.0,
      );

      // 확대 전에 손가락 밑에 있던 판 좌표
      final Offset boardPoint = (focal - offset) / 1.0;

      // 확대 후에도 같은 화면 자리에 와야 합니다. (화면 = 이동 + 판×배율)
      final Offset shownAgain = next + boardPoint * 2.0;

      expect(shownAgain.dx, closeTo(focal.dx, 0.001));
      expect(shownAgain.dy, closeTo(focal.dy, 0.001));
    });

    test('축소할 때도 마찬가지다', () {
      const Offset focal = Offset(640, 400);
      const Offset offset = Offset(-100, -60);

      final Offset next = zoomAroundPoint(
        focalPoint: focal,
        offset: offset,
        fromScale: 2.0,
        toScale: 0.5,
      );

      final Offset boardPoint = (focal - offset) / 2.0;
      final Offset shownAgain = next + boardPoint * 0.5;

      expect(shownAgain.dx, closeTo(focal.dx, 0.001));
      expect(shownAgain.dy, closeTo(focal.dy, 0.001));
    });

    test('배율이 그대로면 이동값도 그대로다', () {
      const Offset offset = Offset(12, 34);

      final Offset next = zoomAroundPoint(
        focalPoint: const Offset(100, 100),
        offset: offset,
        fromScale: 1.0,
        toScale: 1.0,
      );

      expect(next.dx, closeTo(offset.dx, 0.001));
      expect(next.dy, closeTo(offset.dy, 0.001));
    });
  });

  group('크기 조절 중 카드 가로 크기 붙잡기', () {
    test('너무 작게는 못 줄인다', () {
      // 더 작아지면 손잡이와 내리기 버튼이 카드보다 커져서 잡을 수가 없습니다.
      expect(clampResizedCardWidth(1, 0), minBoardCardWidth);
    });

    test('너무 크게는 못 키운다', () {
      expect(clampResizedCardWidth(99999, 0), maxBoardCardWidth);
    });

    test('판 오른쪽 끝을 넘지 않는다', () {
      // 카드가 판 끝에서 300만큼 앞에 있으면, 아무리 끌어도 300까지입니다.
      const double cardX = boardWidth - 300;

      expect(clampResizedCardWidth(99999, cardX), 300);
    });

    test('판 끝에 바짝 붙어 있어도 오류가 나지 않는다', () {
      // 남은 자리가 최소 크기보다 작은 경우입니다.
      expect(clampResizedCardWidth(200, boardWidth - 10), minBoardCardWidth);
    });
  });
}
