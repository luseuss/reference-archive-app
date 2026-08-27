// 카드를 다른 카드에 착 붙게 하는 계산을 확인하는 테스트입니다.
//
// ── 여기서 특히 확인하는 것 ──
// 스냅은 **안 붙어야 할 때 안 붙는 것**이 붙는 것만큼 중요합니다.
// 아무 데나 붙으면 원하는 자리에 못 놓고, 사용자는 "왜 자꾸 끌려가지"
// 하게 됩니다. 그래서 임계값 밖에서 안 붙는지도 함께 봅니다.
//
// 화면 없이 숫자만 봅니다.

import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/theme/app_metrics.dart';
import 'package:reference_archive_app/utils/board_snap.dart';

void main() {
  /// 판 위의 네모 하나를 만듭니다.
  Rect rect(double left, double top, [double width = 200, double height = 100]) {
    return Rect.fromLTWH(left, top, width, height);
  }

  group('옮길 때 카드끼리 붙기', () {
    test('왼쪽 끝이 가까우면 붙는다', () {
      // 다른 카드의 왼쪽이 500. 내 왼쪽이 505면 5만큼 당겨져야 합니다.
      final BoardSnapResult result = snapMovingCard(
        moving: rect(505, 900),
        others: <Rect>[rect(500, 100)],
        useGrid: false,
      );

      expect(result.offset.dx, -5);
      expect(result.guideX, 500);
    });

    test('임계값 밖이면 안 붙는다', () {
      // 8보다 멀면 그대로 둡니다. 아무 데나 붙으면 원하는 자리에 못 놓습니다.
      final BoardSnapResult result = snapMovingCard(
        moving: rect(500 + boardSnapThreshold + 1, 900),
        others: <Rect>[rect(500, 100)],
        useGrid: false,
      );

      expect(result.offset, Offset.zero);
      expect(result.guideX, isNull);
    });

    test('오른쪽 끝끼리도 붙는다', () {
      // 다른 카드의 오른쪽은 500+200=700. 내 오른쪽이 703이면 3 당겨집니다.
      final BoardSnapResult result = snapMovingCard(
        moving: rect(503, 900),
        others: <Rect>[rect(500, 100)],
        useGrid: false,
      );

      expect(result.offset.dx, -3);
    });

    test('가운데끼리도 붙는다', () {
      // 가운데를 넣지 않으면 두 카드의 중심을 맞출 수 없습니다.
      //
      // 폭을 일부러 다르게 잡았습니다. 폭이 같으면 왼쪽·가운데·오른쪽이
      // 동시에 맞아버려서, 가운데 덕분에 붙은 것인지 구분이 안 됩니다.
      //
      // 상대: 왼쪽 500, 가운데 600, 오른쪽 700
      // 나  : 왼쪽 554, 가운데 604, 오른쪽 654  → 가운데만 가깝습니다
      final BoardSnapResult result = snapMovingCard(
        moving: rect(554, 900, 100),
        others: <Rect>[rect(500, 100, 200)],
        useGrid: false,
      );

      expect(result.offset.dx, -4);
      expect(result.guideX, 600);
    });

    test('가로·세로를 따로 본다', () {
      // 가로만 맞고 세로는 멀리 있는 경우입니다.
      // "왼쪽만 맞추고 위아래는 자유"가 되어야 합니다.
      final BoardSnapResult result = snapMovingCard(
        moving: rect(503, 5000),
        others: <Rect>[rect(500, 100)],
        useGrid: false,
      );

      expect(result.offset.dx, -3);
      expect(result.offset.dy, 0);
      expect(result.guideY, isNull);
    });

    test('가장 가까운 것에 붙는다', () {
      // 후보가 여럿이면 제일 가까운 것을 골라야 예측이 됩니다.
      final BoardSnapResult result = snapMovingCard(
        moving: rect(506, 900),
        others: <Rect>[rect(500, 100), rect(510, 100)],
        useGrid: false,
      );

      // 500까지는 6, 510까지는 4 → 510이 더 가깝습니다.
      expect(result.offset.dx, 4);
      expect(result.guideX, 510);
    });

    test('붙을 카드가 없으면 그대로 둔다', () {
      final BoardSnapResult result = snapMovingCard(
        moving: rect(503, 900),
        others: <Rect>[],
        useGrid: false,
      );

      expect(result.offset, Offset.zero);
    });
  });

  group('격자에 붙기', () {
    test('격자를 끄면 안 붙는다', () {
      final BoardSnapResult result = snapMovingCard(
        moving: rect(103, 203),
        others: <Rect>[],
        useGrid: false,
      );

      expect(result.offset, Offset.zero);
    });

    test('격자를 켜면 눈금에 맞춰진다', () {
      // 눈금이 20이므로 103은 100으로, 203은 200으로 당겨집니다.
      final BoardSnapResult result = snapMovingCard(
        moving: rect(103, 203),
        others: <Rect>[],
        useGrid: true,
      );

      expect(result.offset.dx, -3);
      expect(result.offset.dy, -3);
    });

    test('격자에 붙어도 안내선은 안 그린다', () {
      // 격자는 눈에 안 보이는 것이라, 아무것도 없는 자리에 선이 뜨면
      // "저 선은 뭐지?" 하게 됩니다.
      final BoardSnapResult result = snapMovingCard(
        moving: rect(103, 203),
        others: <Rect>[],
        useGrid: true,
      );

      expect(result.guideX, isNull);
      expect(result.guideY, isNull);
    });

    test('눈금에서 멀면 격자에도 안 붙는다', () {
      // 110은 100에서도 120에서도 10만큼 떨어져 있어 임계값(8) 밖입니다.
      final BoardSnapResult result = snapMovingCard(
        moving: rect(110, 110),
        others: <Rect>[],
        useGrid: true,
      );

      expect(result.offset, Offset.zero);
    });

    test('카드끼리 맞으면 격자보다 카드를 따른다', () {
      // ── 이 순서가 중요합니다 ──
      // 격자를 먼저 보면, 격자를 켜둔 동안 카드끼리는 절대 안 맞게 됩니다.
      // 격자에 먼저 붙어버려서 카드 가장자리까지 갈 일이 없기 때문입니다.
      //
      // 내 왼쪽이 103입니다. 격자로는 100, 다른 카드 왼쪽은 105입니다.
      final BoardSnapResult result = snapMovingCard(
        moving: rect(103, 900),
        others: <Rect>[rect(105, 100)],
        useGrid: true,
      );

      expect(result.offset.dx, 2, reason: '격자(100)가 아니라 카드(105)를 따라야 합니다');
      expect(result.guideX, 105);
    });
  });

  group('크기 바꿀 때 붙기', () {
    test('오른쪽 모서리가 다른 카드에 붙는다', () {
      // 내 오른쪽이 703, 다른 카드의 오른쪽이 700이면 3만큼 줄어듭니다.
      final BoardSnapResult result = snapResizingCard(
        resizing: rect(500, 900, 203),
        others: <Rect>[rect(500, 100, 200)],
        useGrid: false,
      );

      expect(result.offset.dx, -3);
      expect(result.guideX, 700);
    });

    test('세로는 안 본다', () {
      // 크기 조절은 비율을 고정합니다. 아래 모서리를 따로 붙이면
      // 비율이 깨지므로 일부러 안 봅니다.
      final BoardSnapResult result = snapResizingCard(
        resizing: rect(500, 900, 200, 203),
        others: <Rect>[rect(5000, 900, 200, 200)],
        useGrid: false,
      );

      expect(result.offset.dy, 0);
      expect(result.guideY, isNull);
    });

    test('임계값 밖이면 안 붙는다', () {
      final BoardSnapResult result = snapResizingCard(
        resizing: rect(500, 900, 220),
        others: <Rect>[rect(500, 100, 200)],
        useGrid: false,
      );

      expect(result.offset.dx, 0);
    });
  });
}
