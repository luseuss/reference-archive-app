// 판을 **확대·축소하고 이동해서** 보여주는 창입니다.
//
// ── 이 파일은 카드가 뭔지 모릅니다 ──
// 하는 일은 딱 하나입니다. "정해진 크기의 무언가를 받아서, 지금 배율과 위치대로
// 화면에 그려준다." 그 안에 뭐가 그려지는지는 board_canvas.dart가 정합니다.
//
// 나눠둔 이유: 줌·팬은 그 자체로 헷갈리는 계산이라, 카드 배치와 뒤섞이면
// 어느 쪽이 잘못됐는지 알기 어려워집니다. 따로 두면 "판이 안 움직인다"와
// "카드가 안 잡힌다"를 각각 다른 파일에서 찾을 수 있습니다.
//
// ── 조작 방법 ──
//   빈 곳을 끌기      → 판 이동
//   마우스 휠         → 커서 자리를 기준으로 확대·축소
//   오른쪽 아래 버튼  → 확대 / 축소 / 판 전체 보기
//
// ── 왜 스크롤 위젯을 안 쓰나 (중요) ──
// 1단계에서 스크롤로 만들었다가 **끌기가 스크롤에 져서 카드가 아예 안 잡혔습니다.**
// 손가락 하나에 여러 위젯이 반응하려 하면 Flutter가 "누가 가져갈지" 겨루게 하는데
// (제스처 아레나), 스크롤이 이겼습니다.
//
// 지금 방식에는 그 다툼이 없습니다. 판을 움직이는 손잡이가 **카드보다 아래층**에
// 깔려 있어서, 카드 위에서 시작한 끌기는 카드가, 빈 곳에서 시작한 끌기는 판이
// 가져갑니다. 겨룰 일 없이 "누구를 눌렀는가"로 갈립니다.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../utils/board_layout.dart';
import 'board_zoom_controls.dart';

/// 판을 확대·이동해서 보여주는 창입니다.
class BoardViewport extends StatefulWidget {
  const BoardViewport({super.key, required this.child});

  /// 판 안에 그릴 것입니다. 크기가 언제나 boardWidth × boardHeight라고 보고 그립니다.
  ///
  /// 빈 자리는 **클릭을 받지 않아야** 합니다. 받아버리면 빈 곳을 끌어도
  /// 판이 안 움직입니다. (board_canvas.dart가 바탕을 안 그리는 이유입니다)
  final Widget child;

  @override
  State<BoardViewport> createState() => _BoardViewportState();
}

class _BoardViewportState extends State<BoardViewport> {
  /// 지금 배율입니다. **null이면 "아직 사용자가 손대지 않았다"**는 뜻입니다.
  ///
  /// null인 동안에는 창 크기에 맞춘 배율을 씁니다. 그래서 창을 넓히면 판도
  /// 따라서 커집니다. 사용자가 한 번이라도 확대·축소하면 값이 들어가고,
  /// 그때부터는 창 크기가 바뀌어도 보던 배율을 지킵니다.
  ///
  /// 처음부터 숫자를 넣어두지 않은 이유: 화면이 얼마나 큰지는 **그려볼 때까지**
  /// 알 수 없습니다. initState에서는 아직 모릅니다.
  double? _scale;

  /// 지금 이동값입니다(화면 좌표). null이면 아직 손대지 않은 상태입니다.
  Offset? _offset;

  /// 지금 쓸 배율을 돌려줍니다. 손대지 않았으면 "판 전체가 보이는 배율"입니다.
  double _scaleFor(Size viewport) {
    return clampBoardScale(_scale ?? fitBoardScale(viewport), viewport);
  }

  /// 지금 쓸 이동값을 돌려줍니다. 손대지 않았으면 가운데입니다.
  ///
  /// clampBoardOffset이 "판이 화면보다 작으면 가운데"를 이미 해주기 때문에,
  /// 처음 값으로 (0, 0)을 넣어도 가운데에서 시작합니다.
  Offset _offsetFor(Size viewport, double scale) {
    return clampBoardOffset(_offset ?? Offset.zero, scale, viewport);
  }

  /// 빈 곳을 끌어 판을 옮깁니다.
  ///
  /// [delta]는 화면에서 움직인 거리입니다. 배율로 나누지 않습니다 —
  /// 이동값 자체가 화면 좌표라서 그대로 더하면 됩니다.
  void _pan(Offset delta, Size viewport) {
    final double scale = _scaleFor(viewport);

    setState(() {
      _scale = scale;
      _offset = clampBoardOffset(
        _offsetFor(viewport, scale) + delta,
        scale,
        viewport,
      );
    });
  }

  /// 배율을 [nextScale]로 바꿉니다. [focalPoint] 자리는 그대로 있게 합니다.
  ///
  /// 확대·축소 버튼과 마우스 휠이 둘 다 이 함수를 씁니다. 다른 것은
  /// "무엇을 기준으로 확대하는가"뿐이라, 그것만 인자로 받습니다.
  void _zoomTo(double nextScale, Offset focalPoint, Size viewport) {
    final double fromScale = _scaleFor(viewport);
    final double toScale = clampBoardScale(nextScale, viewport);

    // 이미 최대(또는 최소)라 바뀔 것이 없으면 아무 일도 하지 않습니다.
    // 그냥 두면 눌렀다는 표시로 화면만 다시 그려집니다.
    if (toScale == fromScale) {
      return;
    }

    final Offset fromOffset = _offsetFor(viewport, fromScale);

    setState(() {
      _scale = toScale;
      _offset = clampBoardOffset(
        zoomAroundPoint(
          focalPoint: focalPoint,
          offset: fromOffset,
          fromScale: fromScale,
          toScale: toScale,
        ),
        toScale,
        viewport,
      );
    });
  }

  /// 판 전체가 보이는 상태로 되돌립니다.
  ///
  /// 확대하다 길을 잃었을 때 돌아올 곳이 없으면 답답합니다.
  /// null로 되돌려두면 창 크기를 바꿀 때 다시 따라오기도 합니다.
  void _resetToFit() {
    setState(() {
      _scale = null;
      _offset = null;
    });
  }

  /// 마우스 휠을 굴렸을 때 확대·축소합니다.
  ///
  /// ── 왜 휠이 스크롤이 아니라 확대인가 ──
  /// 이 화면에는 스크롤할 것이 없습니다(판은 끌어서 옮깁니다).
  /// 그림 편집 프로그램들이 대체로 이렇게 동작해서 손에 익기도 합니다.
  void _onPointerSignal(PointerSignalEvent event, Size viewport) {
    if (event is! PointerScrollEvent) {
      return;
    }

    // 휠을 위로 굴리면 dy가 음수입니다. 위로 = 확대.
    final bool zoomIn = event.scrollDelta.dy < 0;
    final double fromScale = _scaleFor(viewport);

    _zoomTo(
      zoomIn ? fromScale * boardZoomStep : fromScale / boardZoomStep,
      event.localPosition,
      viewport,
    );
  }

  /// 창의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    // LayoutBuilder = "지금 내가 쓸 수 있는 자리가 얼마나 되는지" 알려주는 위젯입니다.
    // 창 크기가 바뀌면 다시 실행되므로, 창을 줄이면 판도 따라서 조정됩니다.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size viewport = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        final double scale = _scaleFor(viewport);
        final Offset offset = _offsetFor(viewport, scale);

        // Listener = 손가락·마우스의 날것 신호를 그대로 받는 위젯입니다.
        // 휠 신호는 "끌기"가 아니라서 GestureDetector로는 안 잡힙니다.
        return Listener(
          onPointerSignal: (PointerSignalEvent event) =>
              _onPointerSignal(event, viewport),

          child: Stack(
            children: <Widget>[
              // ── 1층: 판을 옮기는 바닥 ──
              // 카드보다 아래에 깔려 있어서, 카드 위에서 시작한 끌기는
              // 여기까지 내려오지 않습니다. 빈 곳을 끌 때만 이 손잡이가 잡힙니다.
              Positioned.fill(
                child: MouseRegion(
                  // 끌어서 옮길 수 있다는 것을 커서 모양으로 알려줍니다.
                  cursor: SystemMouseCursors.grab,
                  child: GestureDetector(
                    // opaque = 색이 없는 곳도 눌린 것으로 칩니다.
                    // 안 그러면 투명한 부분에서는 끌기가 시작되지 않습니다.
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (DragUpdateDetails details) =>
                        _pan(details.delta, viewport),
                    child: ColoredBox(color: palette.background),
                  ),
                ),
              ),

              // ── 2층: 판의 바탕 ──
              // IgnorePointer로 감싸 **클릭을 통과시킵니다.** 안 그러면 판 안의
              // 빈 곳을 끌었을 때 1층까지 닿지 않아 판이 안 움직입니다.
              Positioned(
                left: offset.dx,
                top: offset.dy,
                width: boardWidth * scale,
                height: boardHeight * scale,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.surface,
                      border: Border.all(color: palette.border),
                    ),
                  ),
                ),
              ),

              // ── 3층: 판 안의 내용(카드들) ──
              // FittedBox = 안쪽 내용을 바깥 상자 크기에 맞춰 늘리거나 줄이는 위젯입니다.
              // 바깥 상자를 이미 배율만큼 키워뒀으므로 fill로 꽉 채웁니다.
              //
              // 좌표를 손으로 환산하지 않아도 되는 것이 이 방식의 장점입니다.
              // 카드를 끌 때 Flutter가 화면의 손가락 위치를 판 좌표로 되돌려줍니다.
              Positioned(
                left: offset.dx,
                top: offset.dy,
                width: boardWidth * scale,
                height: boardHeight * scale,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: boardWidth,
                    height: boardHeight,
                    child: widget.child,
                  ),
                ),
              ),

              // ── 4층: 확대·축소 버튼 ──
              Positioned(
                right: 16,
                bottom: 16,
                child: BoardZoomControls(
                  scale: scale,
                  onZoomIn: () => _zoomTo(
                    scale * boardZoomStep,
                    viewport.center(Offset.zero),
                    viewport,
                  ),
                  onZoomOut: () => _zoomTo(
                    scale / boardZoomStep,
                    viewport.center(Offset.zero),
                    viewport,
                  ),
                  onResetToFit: _resetToFit,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
