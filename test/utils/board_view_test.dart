// 무드보드를 "어느 배율로 어디를 보고 있는가"를 계산하는 함수들을 확인합니다.
//
// ── 여기서 특히 확인하는 것 ──
// 판에 끝이 없어진 뒤로 **⛶(카드 전부 보기)가 유일한 안전장치**입니다.
// 카드를 아무리 멀리 옮겨두어도 이것만 누르면 전부 다시 보여야 합니다.
// 이게 깨지면 사용자는 사진을 잃어버립니다.
//
// 화면 없이 숫자만 봅니다. 실제 창에서도 그런지는
// test/widgets/board_viewport_test.dart가 봅니다.

import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/theme/app_metrics.dart';
import 'package:reference_archive_app/utils/board_view.dart';

void main() {
  /// 테스트에 쓸 화면 크기입니다.
  const Size viewport = Size(1000, 800);

  group('카드 전부가 보이는 배율', () {
    test('카드가 없으면 1배다', () {
      // 맞출 것이 없습니다.
      expect(fitAllScale(Rect.zero, viewport), 1.0);
    });

    test('카드가 화면보다 넓게 퍼져 있으면 줄인다', () {
      // 가로 2000짜리 범위를 가로 1000 화면에 넣으려면 절반 아래로 줄여야
      // 합니다. 여백(fitAllPadding)까지 빼므로 0.5보다 조금 더 작습니다.
      final double scale = fitAllScale(
        const Rect.fromLTWH(0, 0, 2000, 400),
        viewport,
      );

      expect(scale, lessThan(0.5));
      expect(scale, greaterThan(0.4));
    });

    test('가로·세로 중 더 빡빡한 쪽에 맞춘다', () {
      // 세로가 훨씬 빡빡한 경우입니다. 세로 기준으로 정해져야 전부 들어옵니다.
      final double scale = fitAllScale(
        const Rect.fromLTWH(0, 0, 500, 4000),
        viewport,
      );

      expect(scale * 4000, lessThanOrEqualTo(viewport.height));
    });

    test('카드가 작아도 1배를 넘지 않는다', () {
      // 억지로 늘리면 그림이 흐려집니다.
      expect(fitAllScale(const Rect.fromLTWH(0, 0, 100, 80), viewport), 1.0);
    });

    test('아주 멀리 떨어진 카드들도 담긴다', () {
      // ── 이게 핵심입니다 ──
      // 판에 끝이 없으니 카드가 만 단위 좌표에 있을 수 있습니다.
      // 그래도 ⛶ 한 번으로 전부 보여야 합니다.
      final Rect far = const Rect.fromLTWH(9000, 9000, 500, 500);

      final double scale = fitAllScale(far, viewport);

      expect(scale, greaterThanOrEqualTo(minBoardScale));
      expect(scale * far.width, lessThanOrEqualTo(viewport.width));
    });
  });

  group('카드 전부가 보이는 이동값', () {
    test('카드가 없으면 이동하지 않는다', () {
      expect(fitAllOffset(Rect.zero, viewport, 1.0), Offset.zero);
    });

    test('범위의 한가운데가 화면 한가운데에 온다', () {
      const Rect bounds = Rect.fromLTWH(0, 0, 500, 400);
      const double scale = 1.0;

      final Offset offset = fitAllOffset(bounds, viewport, scale);

      // 화면 위치 = 이동 + 판 위치 × 배율
      final Offset centerOnScreen = offset + bounds.center * scale;

      expect(centerOnScreen.dx, closeTo(viewport.width / 2, 0.001));
      expect(centerOnScreen.dy, closeTo(viewport.height / 2, 0.001));
    });

    test('멀리 떨어진 카드도 화면 한가운데로 데려온다', () {
      const Rect far = Rect.fromLTWH(8000, 6000, 400, 300);
      const double scale = 0.5;

      final Offset offset = fitAllOffset(far, viewport, scale);
      final Offset centerOnScreen = offset + far.center * scale;

      expect(centerOnScreen.dx, closeTo(viewport.width / 2, 0.001));
      expect(centerOnScreen.dy, closeTo(viewport.height / 2, 0.001));
    });
  });

  group('배율 한계', () {
    test('너무 작게는 못 줄인다', () {
      expect(clampBoardScale(0.0001), minBoardScale);
    });

    test('너무 크게는 못 키운다', () {
      expect(clampBoardScale(99), maxBoardScale);
    });

    test('그 사이 값은 그대로 둔다', () {
      expect(clampBoardScale(1.5), 1.5);
    });
  });

  group('판을 옮길 때의 한계', () {
    const Rect bounds = Rect.fromLTWH(0, 0, 500, 400);

    test('카드가 없으면 붙잡지 않는다', () {
      // 잡아둘 카드가 없습니다.
      const Offset wild = Offset(-9999, -9999);

      expect(clampCanvasOffset(wild, 1.0, viewport, Rect.zero), wild);
    });

    test('웬만한 자리는 그대로 둔다', () {
      // ── 전에는 여기서 가운데로 잡아끌었습니다 ──
      // 그래서 판이 다 보이는 동안에는 빈 곳을 끌어도 아무 일이 없었습니다.
      // 이제는 그냥 움직입니다.
      const Offset moved = Offset(120, 60);

      expect(clampCanvasOffset(moved, 1.0, viewport, bounds), moved);
    });

    test('왼쪽 위로 완전히 밀어낼 수 없다', () {
      // 카드를 화면 밖으로 다 밀어버리면 "내 사진 어디 갔지"가 됩니다.
      final Offset clamped = clampCanvasOffset(
        const Offset(-99999, -99999),
        1.0,
        viewport,
        bounds,
      );

      // 범위의 오른쪽 아래 끝이 화면 안에 조금은 남아 있어야 합니다.
      expect(clamped.dx + bounds.right, greaterThanOrEqualTo(canvasKeepVisible));
      expect(
        clamped.dy + bounds.bottom,
        greaterThanOrEqualTo(canvasKeepVisible),
      );
    });

    test('오른쪽 아래로도 완전히 밀어낼 수 없다', () {
      final Offset clamped = clampCanvasOffset(
        const Offset(99999, 99999),
        1.0,
        viewport,
        bounds,
      );

      // 범위의 왼쪽 위 끝이 화면 안에 조금은 남아 있어야 합니다.
      expect(
        clamped.dx + bounds.left,
        lessThanOrEqualTo(viewport.width - canvasKeepVisible),
      );
      expect(
        clamped.dy + bounds.top,
        lessThanOrEqualTo(viewport.height - canvasKeepVisible),
      );
    });

    test('확대한 상태에서도 붙잡는다', () {
      const double scale = 3.0;

      final Offset clamped = clampCanvasOffset(
        const Offset(-99999, -99999),
        scale,
        viewport,
        bounds,
      );

      expect(
        clamped.dx + bounds.right * scale,
        greaterThanOrEqualTo(canvasKeepVisible),
      );
    });
  });

  group('가리킨 지점을 기준으로 확대', () {
    test('가리킨 지점은 확대해도 같은 자리에 남는다', () {
      const Offset focal = Offset(300, 200);
      const Offset offset = Offset(50, 20);
      const double fromScale = 1.0;
      const double toScale = 2.0;

      // 확대하기 전, 손가락 밑에 있던 판 좌표
      final Offset boardPoint = (focal - offset) / fromScale;

      final Offset next = zoomAroundPoint(
        focalPoint: focal,
        offset: offset,
        fromScale: fromScale,
        toScale: toScale,
      );

      // 확대한 뒤에도 그 판 좌표가 같은 화면 자리에 있어야 합니다.
      final Offset afterOnScreen = next + boardPoint * toScale;

      expect(afterOnScreen.dx, closeTo(focal.dx, 0.001));
      expect(afterOnScreen.dy, closeTo(focal.dy, 0.001));
    });

    test('축소할 때도 마찬가지다', () {
      const Offset focal = Offset(700, 500);
      const Offset offset = Offset(-100, -80);
      const double fromScale = 2.0;
      const double toScale = 0.5;

      final Offset boardPoint = (focal - offset) / fromScale;

      final Offset next = zoomAroundPoint(
        focalPoint: focal,
        offset: offset,
        fromScale: fromScale,
        toScale: toScale,
      );

      final Offset afterOnScreen = next + boardPoint * toScale;

      expect(afterOnScreen.dx, closeTo(focal.dx, 0.001));
      expect(afterOnScreen.dy, closeTo(focal.dy, 0.001));
    });

    test('배율이 그대로면 이동값도 그대로다', () {
      const Offset offset = Offset(33, 44);

      final Offset next = zoomAroundPoint(
        focalPoint: const Offset(500, 400),
        offset: offset,
        fromScale: 1.5,
        toScale: 1.5,
      );

      expect(next.dx, closeTo(offset.dx, 0.001));
      expect(next.dy, closeTo(offset.dy, 0.001));
    });
  });
}
