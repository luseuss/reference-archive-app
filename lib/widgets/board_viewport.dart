// 판을 **확대·축소하고 이동해서** 보여주는 창입니다.
//
// ── 이 파일은 카드가 뭔지 모릅니다 ──
// 하는 일은 딱 하나입니다. "받은 크기의 무언가를, 지금 배율과 위치대로
// 화면에 그려준다." 그 안에 뭐가 그려지는지는 board_canvas.dart가 정합니다.
//
// 나눠둔 이유: 줌·팬은 그 자체로 헷갈리는 계산이라, 카드 배치와 뒤섞이면
// 어느 쪽이 잘못됐는지 알기 어려워집니다. 따로 두면 "판이 안 움직인다"와
// "카드가 안 잡힌다"를 각각 다른 파일에서 찾을 수 있습니다.
//
// ── 판에 끝이 없습니다 (4단계 3번) ──
// 전에는 1920×1200짜리 판이 있고 그 안에서만 놀았습니다. 이제는 카드를
// 오른쪽·아래로 얼마든지 옮길 수 있고, **그릴 자리도 카드를 따라 늘어납니다.**
// 그 크기는 부르는 쪽(board_screen.dart)이 계산해서 넘겨줍니다.
//
// 그래서 이 파일은 **판 바탕(테두리 있는 네모)을 더 이상 그리지 않습니다.**
// 경계가 없으니 그릴 테두리도 없습니다.
//
// ── 조작 방법 ──
//   빈 곳을 끌기      → 판 이동
//   마우스 휠         → 커서 자리를 기준으로 확대·축소
//   오른쪽 아래 버튼  → 확대 / 축소 / 카드 전부 보기
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
import '../utils/board_view.dart';
import 'board_zoom_controls.dart';

/// 판을 확대·이동해서 보여주는 창입니다.
class BoardViewport extends StatefulWidget {
  const BoardViewport({
    super.key,
    required this.canvasSize,
    required this.contentBounds,
    required this.viewResetCount,
    required this.child,
  });

  /// 카드를 그릴 자리의 크기입니다. (`boardCanvasSize`로 구합니다)
  ///
  /// 카드가 오른쪽·아래로 갈수록 커집니다. 왼쪽 위(0, 0)는 고정입니다.
  final Size canvasSize;

  /// 지금 카드들이 놓인 범위입니다. (`boardContentBounds`로 구합니다)
  ///
  /// 두 곳에 씁니다.
  ///   - ⛶(카드 전부 보기)가 여기에 화면을 맞춥니다.
  ///   - 판을 옮길 때 이 범위가 화면 밖으로 완전히 나가지 않게 붙잡습니다.
  ///
  /// 카드가 없으면 빈 네모(`Rect.zero`)가 옵니다.
  final Rect contentBounds;

  /// 이 숫자가 바뀌면 **보던 화면을 ⛶ 상태로 되돌립니다.**
  ///
  /// ── 왜 이런 게 필요한가 ──
  /// 레퍼런스를 새로 담으면 카드가 늘어납니다. 그런데 저 멀리 확대해서 보고
  /// 있었다면 새 카드가 화면 밖에 생겨서 **안 담긴 것처럼 보입니다.**
  /// 그래서 담은 직후에 한 번 전체 보기로 되돌립니다.
  ///
  /// 숫자 자체에는 뜻이 없습니다. **바뀌었다는 사실만** 봅니다.
  /// 부르는 쪽에서 1씩 올려주면 됩니다.
  final int viewResetCount;

  /// 판 안에 그릴 것입니다. 크기가 [canvasSize]라고 보고 그립니다.
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
  /// 처음 그릴 때 "카드 전부가 보이는 배율"로 한 번 채워지고(_ensureFitted),
  /// 그 뒤로는 사용자가 움직이는 대로 둡니다. 다시 null이 되는 것은
  /// **⛶ 버튼**과 **레퍼런스를 새로 담았을 때**뿐입니다.
  ///
  /// 처음부터 숫자를 넣어두지 않은 이유: 화면이 얼마나 큰지는 **그려볼 때까지**
  /// 알 수 없습니다. initState에서는 아직 모릅니다.
  double? _scale;

  /// 지금 이동값입니다(화면 좌표). null이면 아직 손대지 않은 상태입니다.
  Offset? _offset;

  /// 부모가 [BoardViewport.viewResetCount]를 올리면 보던 화면을 되돌립니다.
  ///
  /// didUpdateWidget = "부모가 나에게 넘겨주는 값이 바뀌었다"고 알려주는
  /// Flutter의 기본 장치입니다. 여기서 setState를 불러도 됩니다.
  @override
  void didUpdateWidget(BoardViewport oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.viewResetCount != widget.viewResetCount) {
      _resetToFitAll();
    }
  }

  /// 아직 한 번도 안 맞춰봤으면 **지금 한 번** 맞춥니다.
  ///
  /// ── 왜 한 번만 맞추나 (매번 맞추면 안 되나) ──
  /// 매번 맞추면 **카드를 끌 때 화면이 그 카드를 따라갑니다.** 카드가
  /// 오른쪽으로 가면 카드가 놓인 범위도 오른쪽으로 넓어지고, 거기에 화면을
  /// 다시 맞추니 카드가 제자리에 서 있는 것처럼 보입니다. 아무리 끌어도
  /// 안 움직이는 것과 같습니다. (실제로 테스트가 이걸 잡았습니다)
  ///
  /// 그래서 처음 한 번만 맞춰두고, 그 뒤로는 사용자가 움직이는 대로 둡니다.
  /// 다시 맞추는 것은 **⛶ 버튼**과 **레퍼런스를 새로 담았을 때**뿐입니다.
  ///
  /// ── build 안에서 값을 고쳐도 되나 ──
  /// 여기서 정한 값을 **바로 그 자리에서 그리는 데 쓰기 때문에** 괜찮습니다.
  /// 화면을 다시 그려달라고 할 필요가 없어서 setState도 안 부릅니다.
  void _ensureFitted(Size viewport) {
    if (_scale != null && _offset != null) {
      return;
    }

    final double scale = clampBoardScale(
      fitAllScale(widget.contentBounds, viewport),
    );

    _scale = scale;
    _offset = fitAllOffset(widget.contentBounds, viewport, scale);
  }

  /// 지금 쓸 배율을 돌려줍니다.
  double _scaleFor(Size viewport) {
    _ensureFitted(viewport);

    return clampBoardScale(_scale!);
  }

  /// 지금 쓸 이동값을 돌려줍니다.
  ///
  /// 저장해둔 값을 그대로 쓰되, 카드가 화면 밖으로 완전히 나가지 않을 만큼만
  /// 붙잡습니다. 카드를 지우거나 옮겨서 범위가 줄었을 때를 위한 것입니다.
  Offset _offsetFor(Size viewport, double scale) {
    _ensureFitted(viewport);

    return clampCanvasOffset(_offset!, scale, viewport, widget.contentBounds);
  }

  /// 빈 곳을 끌어 판을 옮깁니다.
  ///
  /// [delta]는 화면에서 움직인 거리입니다. 배율로 나누지 않습니다 —
  /// 이동값 자체가 화면 좌표라서 그대로 더하면 됩니다.
  void _pan(Offset delta, Size viewport) {
    final double scale = _scaleFor(viewport);

    setState(() {
      _scale = scale;
      _offset = clampCanvasOffset(
        _offsetFor(viewport, scale) + delta,
        scale,
        viewport,
        widget.contentBounds,
      );
    });
  }

  /// 배율을 [nextScale]로 바꿉니다. [focalPoint] 자리는 그대로 있게 합니다.
  ///
  /// 확대·축소 버튼과 마우스 휠이 둘 다 이 함수를 씁니다. 다른 것은
  /// "무엇을 기준으로 확대하는가"뿐이라, 그것만 인자로 받습니다.
  void _zoomTo(double nextScale, Offset focalPoint, Size viewport) {
    final double fromScale = _scaleFor(viewport);
    final double toScale = clampBoardScale(nextScale);

    // 이미 최대(또는 최소)라 바뀔 것이 없으면 아무 일도 하지 않습니다.
    // 그냥 두면 눌렀다는 표시로 화면만 다시 그려집니다.
    if (toScale == fromScale) {
      return;
    }

    final Offset fromOffset = _offsetFor(viewport, fromScale);

    setState(() {
      _scale = toScale;
      _offset = clampCanvasOffset(
        zoomAroundPoint(
          focalPoint: focalPoint,
          offset: fromOffset,
          fromScale: fromScale,
          toScale: toScale,
        ),
        toScale,
        viewport,
        widget.contentBounds,
      );
    });
  }

  /// 카드 전부가 보이는 상태로 되돌립니다. (⛶ 버튼)
  ///
  /// 확대하다 길을 잃었을 때 돌아올 곳이 없으면 답답합니다. **판에 끝이
  /// 없어진 뒤로는 이 버튼이 유일한 안전장치입니다.** 카드를 아무리 멀리
  /// 옮겨두어도 이것만 누르면 전부 다시 보입니다.
  ///
  /// null로 되돌려두면 창 크기를 바꾸거나 카드를 담을 때 다시 따라옵니다.
  void _resetToFitAll() {
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
              //
              // 판에 끝이 없어진 뒤로 이 바닥이 곧 판의 바탕이기도 합니다.
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

              // ── 2층: 카드들 ──
              // FittedBox = 안쪽 내용을 바깥 상자 크기에 맞춰 늘리거나 줄이는 위젯입니다.
              // 바깥 상자를 이미 배율만큼 키워뒀으므로 fill로 꽉 채웁니다.
              //
              // 좌표를 손으로 환산하지 않아도 되는 것이 이 방식의 장점입니다.
              // 카드를 끌 때 Flutter가 화면의 손가락 위치를 판 좌표로 되돌려줍니다.
              Positioned(
                left: offset.dx,
                top: offset.dy,
                width: widget.canvasSize.width * scale,
                height: widget.canvasSize.height * scale,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: widget.canvasSize.width,
                    height: widget.canvasSize.height,
                    child: widget.child,
                  ),
                ),
              ),

              // ── 3층: 확대·축소 버튼 ──
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
                  onResetToFit: _resetToFitAll,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
