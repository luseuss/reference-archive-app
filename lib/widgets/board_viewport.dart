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
//   빈 곳을 끌기              → 마퀴(선택 네모) 그리기
//   마우스 휠 버튼으로 끌기    → 판 이동
//   빈 곳을 그냥 클릭         → 선택 지우기
//   마우스 휠을 굴리기        → 커서 자리를 기준으로 확대·축소
//   오른쪽 아래 버튼          → 확대 / 축소 / 카드 전부 보기
//
// ── 왜 이렇게 나눴나 (마우스 휠 "버튼"과 "굴리기"는 다른 동작입니다) ──
// 처음에는 "빈 곳 끌기 = 판 이동, Alt+빈 곳 끌기 = 마퀴"였습니다. 의뢰인이
// 써보니 **마퀴를 훨씬 자주 쓰는데 그게 곁다리(Alt) 취급**이라 불편했습니다.
// 그림 편집 프로그램들이 흔히 쓰는 배치(빈 드래그 = 선택, 휠 버튼 드래그 =
// 화면 이동)로 바꿨습니다. Alt는 여전히 스냅에 씁니다(카드를 끌 때만 —
// board_interaction_controller.dart의 `snapEnabled`) — 이 파일의 마퀴/판
// 이동과는 아무 관계가 없습니다.
//
// ── 마퀴는 왜 여기 있나 (5단계 마퀴 다중선택) ──
// 이 파일이 카드가 뭔지 모른다는 원칙은 그대로입니다. 마퀴 네모를
// **화면 좌표로 그리고, 판 좌표로 바꿔서 위로 보고할 뿐** — "어느 카드가
// 걸렸는지"는 이 파일이 아니라 board_interaction_controller.dart가
// 정합니다. 판을 옮기는 손잡이와 같은 층에 있어서, 판 이동과 마퀴가
// 같은 "빈 곳 끌기" 하나를 **누른 버튼**으로 나눠 쓰게 만들기 쉬웠습니다.
//
// ── 왜 스크롤 위젯을 안 쓰나 (중요) ──
// 1단계에서 스크롤로 만들었다가 **끌기가 스크롤에 져서 카드가 아예 안 잡혔습니다.**
// 손가락 하나에 여러 위젯이 반응하려 하면 Flutter가 "누가 가져갈지" 겨루게 하는데
// (제스처 아레나), 스크롤이 이겼습니다.
//
// 지금 방식에는 그 다툼이 없습니다. 판을 움직이는 손잡이가 **카드보다 아래층**에
// 깔려 있어서, 카드 위에서 시작한 끌기는 카드가, 빈 곳에서 시작한 끌기는 판이
// 가져갑니다. 겨룰 일 없이 "누구를 눌렀는가"로 갈립니다.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_clipboard/super_clipboard.dart' show DataReader;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../services/board_window_sync.dart';
import '../services/dropped_item_reader.dart' show dropRegionFormats;
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../utils/board_view.dart';
import '../utils/reference_drag_payload.dart';
import 'board_viewport_gestures.dart';
import 'board_zoom_controls.dart';

/// 판을 확대·이동해서 보여주는 창입니다.
class BoardViewport extends StatefulWidget {
  const BoardViewport({
    super.key,
    required this.canvasRect,
    required this.contentBounds,
    required this.viewResetCount,
    required this.onMarqueeBegin,
    required this.onMarqueeUpdate,
    required this.onMarqueeEnd,
    required this.onEmptyTap,
    required this.child,
    this.onReferenceDropped,
    this.onExternalFilesDropped,
    this.initialScale,
    this.initialOffset,
    this.onViewChanged,
    this.onViewReset,
  });

  /// 카드를 그릴 자리입니다. (`boardCanvasRect`로 구합니다)
  ///
  /// **왼쪽 위 모서리가 고정이 아닙니다.** 카드가 어느 쪽으로 가든 상자가
  /// 따라 움직입니다. 그래야 음수 자리에 놓인 카드도 클릭이 닿습니다.
  ///
  /// 상자를 놓을 때 그 모서리만큼 다시 더해주기 때문에, 상자가 움직여도
  /// 화면에서 카드는 제자리에 있습니다.
  /// (board_layout.dart의 boardCanvasRect 설명 참고)
  final Rect canvasRect;

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

  /// Alt+빈 곳 끌기로 마퀴를 시작하는 순간 알려줍니다.
  ///
  /// [additive]는 그 순간 Shift가 눌려 있었는지입니다. 참이면 "지금까지의
  /// 선택에 더하기", 거짓이면 "마퀴로 통째로 바꾸기"라는 뜻입니다.
  final void Function({required bool additive}) onMarqueeBegin;

  /// 마퀴를 끄는 동안, 지금까지 그려진 네모를 **판 좌표**로 알려줍니다.
  ///
  /// 화면 좌표가 아닙니다 — 카드 자리와 견주려면 판 좌표라야 하는데,
  /// 그 변환(이동·배율 되돌리기)은 이 파일만 압니다.
  final ValueChanged<Rect> onMarqueeUpdate;

  /// 마퀴에서 손을 뗐을 때 알려줍니다.
  final VoidCallback onMarqueeEnd;

  /// 빈 곳을 **끌지 않고 그냥 클릭**했을 때 알려줍니다.
  ///
  /// [shiftHeld]는 그때 Shift가 눌려 있었는지입니다. 대개 "선택을
  /// 지워라"는 뜻으로 쓰지만, Shift가 눌려 있었다면 아무것도 안 지웁니다.
  final void Function({required bool shiftHeld}) onEmptyTap;

  /// 판 안에 그릴 것입니다. 크기가 [canvasRect]의 크기라고 보고 그립니다.
  ///
  /// 빈 자리는 **클릭을 받지 않아야** 합니다. 받아버리면 빈 곳을 끌어도
  /// 판이 안 움직입니다. (board_canvas.dart가 바탕을 안 그리는 이유입니다)
  final Widget child;

  /// 메인 화면에서 레퍼런스 카드를 이 판 위로 끌어다 놓았을 때 알려줍니다.
  /// [referenceId]는 놓은 레퍼런스의 번호, [canvasPosition]은 놓은 자리를
  /// **판 좌표**로 바꾼 값입니다(화면 좌표가 아닙니다 — 이 파일만 아는
  /// 배율·이동값을 반영해 바꿔서 넘겨줍니다).
  ///
  /// null이면 드롭을 아예 안 받습니다. `supportsBoardPopupWindow`가
  /// 거짓인 플랫폼(모바일·태블릿)에서는 이 콜백을 안 만들어도 되게
  /// 선택적으로 뒀습니다.
  final void Function(String referenceId, Offset canvasPosition)?
  onReferenceDropped;

  /// 탐색기·브라우저에서 파일을 이 판 위로 직접 끌어다 놓았을 때
  /// 알려줍니다. [event]는 놓인 것을 그대로 넘깁니다(안에 이미지
  /// 여러 개가 들어있을 수 있습니다 — 무엇을 읽어내고 어떻게 저장할지는
  /// 이 파일이 몰라도 되는 일이라 그대로 넘깁니다). [canvasPosition]은
  /// 놓은 자리를 **판 좌표**로 바꾼 값입니다.
  ///
  /// null이면 이 종류의 드롭을 아예 안 받습니다. [onReferenceDropped]와
  /// 달리 `supportsBoardPopupWindow`(데스크톱 전용)로 가리지 않습니다 —
  /// 판 안 레퍼런스 끌어다 놓기는 서로 다른 창(엔진) 사이의 일이라 그
  /// 제약이 있지만, 이건 그냥 OS가 주는 파일 드롭이라 팝업 여부와
  /// 상관없습니다.
  final Future<void> Function(PerformDropEvent event, Offset canvasPosition)?
  onExternalFilesDropped;

  /// 이 판을 열 때 처음부터 쓸 배율입니다. null이면 평소처럼 "카드
  /// 전부 보기"로 시작합니다.
  ///
  /// 이 위젯은 "판이 뭔지" 모르므로(파일 위쪽 설명 참고), 지난번에
  /// 보던 자리를 기억해뒀다가 다시 넣어주는 일은 board_screen.dart가
  /// board_view_state_storage.dart로 읽어와서 여기 넘겨줍니다.
  final double? initialScale;

  /// 이 판을 열 때 처음부터 쓸 이동값입니다. [initialScale]과 항상 짝을
  /// 이룹니다 — 배율만 있고 자리가 없으면(또는 그 반대) 뜻이 없습니다.
  final Offset? initialOffset;

  /// 판을 옮기거나(팬) 확대·축소를 마쳤을 때 지금 배율·자리를 알려줍니다.
  ///
  /// 화면을 확대·이동하는 도중(끄는 동안) 매 프레임 불리지 않습니다 —
  /// 끝났을 때만 한 번 불립니다. null이면 아무에게도 안 알립니다(예:
  /// 저장할 곳이 없는 화면).
  final void Function(double scale, Offset offset)? onViewChanged;

  /// "카드 전부 보기"(⛶)를 눌러 기본 상태로 되돌렸을 때 알려줍니다.
  ///
  /// 저장해뒀던 배율·자리가 있다면 이제 뜻이 없어졌으니 지우라는
  /// 신호입니다.
  final VoidCallback? onViewReset;

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

  /// 마퀴(다중선택 네모)가 화면 어디에 있는지 담고 있습니다.
  /// (board_viewport_gestures.dart 참고)
  final MarqueeState _marquee = MarqueeState();

  /// 레퍼런스를 이 판 위로 끌고 온 동안(아직 놓지는 않은 상태) 참입니다.
  /// 가장자리를 강조해서 "여기 놓으면 된다"를 알려주는 데만 씁니다.
  bool _isDropHighlighted = false;

  /// 저장해둔 배율·자리가 있으면 그대로 시작합니다.
  ///
  /// [BoardViewport.initialScale]/[BoardViewport.initialOffset]이 둘 다
  /// 있을 때만 씁니다. 하나만 있으면(정상적으로는 안 생기지만) 무시하고
  /// 평소처럼 "카드 전부 보기"로 시작합니다 — _ensureFitted가 그 경우를
  /// 이미 처리합니다.
  @override
  void initState() {
    super.initState();

    final double? scale = widget.initialScale;
    final Offset? offset = widget.initialOffset;
    if (scale != null && offset != null) {
      _scale = scale;
      _offset = offset;
    }
  }

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

  /// "클릭인지 끌기인지"와 "어느 버튼이었는지"를 가리는 데 씁니다.
  /// (board_viewport_gestures.dart 참고)
  final EmptyPointerGesture _emptyPointer = EmptyPointerGesture();

  /// 빈 곳을 눌렀을 때 실행됩니다. **끌기가 시작되기(_onEmptyDragStart) 전에
  /// 먼저 도착합니다** — Listener는 GestureDetector의 손이 아니라, 손가락이
  /// 닿는 순간 곧바로 불립니다.
  void _onEmptyPointerDown(PointerDownEvent event) {
    _emptyPointer.onDown(event);
  }

  /// 눌린 채로 움직이는 동안 실행됩니다.
  void _onEmptyPointerMove(PointerMoveEvent event) {
    _emptyPointer.onMove(event);
  }

  /// 빈 곳에서 손을 뗐을 때 실행됩니다.
  ///
  /// 눌린 뒤로 움직이지 않았다면 **클릭**입니다. 그때만
  /// [BoardViewport.onEmptyTap]을 부릅니다. 판을 끌었을 때는(움직였을
  /// 때는) 부르지 않습니다 — 판을 옮기다 손을 뗀 것뿐인데 선택이
  /// 지워지면 당황스럽습니다.
  void _onEmptyPointerUp(PointerUpEvent event) {
    if (!_emptyPointer.moved) {
      widget.onEmptyTap(shiftHeld: HardwareKeyboard.instance.isShiftPressed);
    }
    _emptyPointer.downAt = null;
  }

  /// 떨어진 항목에서 글자값을 읽어 돌려줍니다. 못 읽으면 null입니다.
  ///
  /// getValue()가 결과를 콜백으로 주기 때문에 Completer로 감싸 await할
  /// 수 있게 바꿉니다. (dropped_item_reader.dart의 `_readValue`와 같은
  /// 이유·같은 모양입니다 — 그 파일은 여러 형식을 다루지만 여기는
  /// plainText 하나만 보면 되어 따로 작은 것을 뒀습니다)
  Future<String?> _readPlainText(DataReader reader) {
    final Completer<String?> completer = Completer<String?>();

    reader.getValue<String>(
      Formats.plainText,
      (String? value) {
        if (!completer.isCompleted) {
          completer.complete(value);
        }
      },
      onError: (Object error) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    return completer.future;
  }

  /// 화면 좌표를 판 좌표로 바꿉니다. 확대·이동의 반대 방향 계산입니다.
  ///
  ///   화면 = 이동 + 판×배율   →   판 = (화면 − 이동) ÷ 배율
  Offset _toCanvasPoint(Offset screenPoint, Size viewport) {
    final double scale = _scaleFor(viewport);
    final Offset offset = _offsetFor(viewport, scale);
    return (screenPoint - offset) / scale;
  }

  /// 빈 곳에서 끌기가 시작될 때 실행됩니다.
  ///
  /// **마우스 휠 버튼(가운데 버튼)으로 눌렀으면 판 이동**, 그 외(왼쪽 버튼,
  /// 터치)는 전부 마퀴입니다. **여기서 한 번만** 확인합니다 — 끄는 도중에
  /// 버튼을 더 누르거나 떼도 이미 정해진 쪽으로 계속 갑니다. 도중에
  /// 바뀌면 마퀴가 판이 됐다 다시 마퀴가 됐다 하며 뒤죽박죽이 됩니다.
  void _onEmptyDragStart(DragStartDetails details) {
    if (_emptyPointer.isPanning) {
      // 아무것도 안 하면 _onEmptyDragUpdate가 (marquee.active가 거짓인 채로)
      // 기본값인 판 이동으로 처리합니다.
      return;
    }

    setState(() => _marquee.begin(details.localPosition));
    widget.onMarqueeBegin(additive: HardwareKeyboard.instance.isShiftPressed);
  }

  /// 빈 곳을 끄는 동안 실행됩니다. 마퀴 중이면 마퀴를, 아니면 판을 옮깁니다.
  void _onEmptyDragUpdate(DragUpdateDetails details, Size viewport) {
    if (!_marquee.active) {
      _pan(details.delta, viewport);
      return;
    }

    setState(() => _marquee.moveBy(details.delta));

    final Offset a = _toCanvasPoint(_marquee.start!, viewport);
    final Offset b = _toCanvasPoint(_marquee.current!, viewport);
    widget.onMarqueeUpdate(Rect.fromPoints(a, b));
  }

  /// 빈 곳에서 손을 뗐을 때 실행됩니다. 마퀴 중이었으면 마무리하고,
  /// 아니었으면(=판을 옮긴 것이면) 지금 자리를 알립니다.
  void _onEmptyDragEnd(DragEndDetails details) {
    if (!_marquee.active) {
      _notifyViewChanged();
      return;
    }

    setState(_marquee.finish);
    widget.onMarqueeEnd();
  }

  /// 지금 배율·자리를 [BoardViewport.onViewChanged]로 알립니다.
  ///
  /// 판을 옮기거나(_onEmptyDragEnd) 확대·축소를 마쳤을 때(_zoomTo)만
  /// 부릅니다 — 끄는 도중 매 프레임 부르면 저장 요청이 쉴 새 없이
  /// 나갑니다.
  void _notifyViewChanged() {
    final double? scale = _scale;
    final Offset? offset = _offset;
    if (scale != null && offset != null) {
      widget.onViewChanged?.call(scale, offset);
    }
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

    _notifyViewChanged();
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

    // 저장해뒀던 배율·자리가 있었다면 이제 뜻이 없어졌습니다. 안 지우면
    // 다음에 이 판을 열었을 때 방금 되돌린 "전부 보기"가 아니라 예전
    // 자리로 다시 돌아가 버립니다.
    widget.onViewReset?.call();
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
    final ColorScheme colors = Theme.of(context).colorScheme;

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
        final Widget content = Listener(
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
                  // 기본 커서로 둡니다. 빈 곳에서의 기본 동작은 이제 **마퀴
                  // 선택**이라, 손 모양(잡기) 커서를 두면 판이 움직일 것처럼
                  // 보여 오해를 줍니다. 휠 버튼으로 눌러야 판이 움직입니다.
                  cursor: SystemMouseCursors.basic,

                  // ── 클릭 여부는 Listener로 따로 봅니다 ──
                  // 처음에는 GestureDetector.onTap을 같이 뒀는데, 그러면
                  // 판 이동 인식기가 **탭 인식기와 경쟁하게 됩니다.** 그
                  // 결과 짧게 끄는 순간 처음 몇 픽셀이 더 버려져서, 90픽셀
                  // 끌었는데 70픽셀만 움직이는 회귀가 생겼습니다(제스처
                  // 아레나 문제). Listener는 아레나에 안 끼므로 아래
                  // GestureDetector의 판 이동은 전혀 안 건드립니다.
                  child: Listener(
                    onPointerDown: _onEmptyPointerDown,
                    onPointerMove: _onEmptyPointerMove,
                    onPointerUp: _onEmptyPointerUp,

                    // ── GestureDetector가 아니라 RawGestureDetector를 쓰는 이유 ──
                    // 보통의 GestureDetector.onPanStart는 **왼쪽 버튼만** 받습니다
                    // (Flutter의 PanGestureRecognizer 기본 동작). 그래서 휠 버튼
                    // 끌기를 판 이동에 쓰려면, 버튼을 직접 고를 수 있는
                    // RawGestureDetector로 PanGestureRecognizer를 만들어야 합니다.
                    child: RawGestureDetector(
                      // opaque = 색이 없는 곳도 눌린 것으로 칩니다.
                      // 안 그러면 투명한 부분에서는 끌기가 시작되지 않습니다.
                      behavior: HitTestBehavior.opaque,

                      gestures: <Type, GestureRecognizerFactory>{
                        PanGestureRecognizer:
                            GestureRecognizerFactoryWithHandlers<
                              PanGestureRecognizer
                            >(
                              () => PanGestureRecognizer(
                                // 왼쪽 버튼(마퀴)과 휠 버튼(판 이동) 둘 다
                                // 받습니다. 어느 쪽이었는지는
                                // _onEmptyDragStart가 _emptyPointer.isPanning으로
                                // 가릅니다.
                                allowedButtonsFilter: (int buttons) =>
                                    buttons == kPrimaryButton ||
                                    buttons == kMiddleMouseButton,
                              ),
                              (PanGestureRecognizer instance) {
                                // ── 화살표 함수(=>)가 아니라 블록({ })을 씁니다 ──
                                // 화살표 함수는 다음 `..`까지를 자기 몸통으로
                                // 삼켜버려서, `..onEnd = ...`가 이 함수의 반환값
                                // (void)에 캐스케이드로 붙으려다 컴파일 오류가
                                // 납니다. 블록으로 몸통을 확실히 닫아야 합니다.
                                instance
                                  ..onStart = _onEmptyDragStart
                                  ..onUpdate = (DragUpdateDetails details) {
                                    _onEmptyDragUpdate(details, viewport);
                                  }
                                  ..onEnd = _onEmptyDragEnd;
                              },
                            ),
                      },

                      child: ColoredBox(color: palette.background),
                    ),
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
                // 상자의 왼쪽 위 모서리(판 좌표)를 화면 좌표로 옮겨 더합니다.
                // 카드를 놓을 때 뺀 만큼을 여기서 도로 더하는 것입니다.
                //
                //   화면 = 이동 + 원점×배율 + (카드 - 원점)×배율
                //        = 이동 + 카드×배율      ← 원점이 사라집니다
                //
                // 그래서 상자가 움직여도 카드는 화면에서 안 움직입니다.
                left: offset.dx + widget.canvasRect.left * scale,
                top: offset.dy + widget.canvasRect.top * scale,
                width: widget.canvasRect.width * scale,
                height: widget.canvasRect.height * scale,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: widget.canvasRect.width,
                    height: widget.canvasRect.height,
                    child: widget.child,
                  ),
                ),
              ),

              // ── 3층: 마퀴 네모 ──
              // 화면 좌표를 그대로 씁니다(판 좌표로 안 바꿉니다). 카드 위에
              // 그려서 뭐가 걸리는지 보이게 하고, IgnorePointer로 감싸
              // 클릭을 가로채지 않게 합니다. (board_guides.dart와 같은 이유)
              if (_marquee.rect != null)
                Positioned.fromRect(
                  rect: _marquee.rect!,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        border: Border.all(color: colors.primary, width: 1.5),
                      ),
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
                  onResetToFit: _resetToFitAll,
                ),
              ),
            ],
          ),
        );

        // 두 가지 드롭을 받을 수 있습니다. 판이 뭔지 모른다는 원칙은
        // 그대로라, "레퍼런스 번호를 받았다"/"파일을 받았다"만 위로
        // 넘기고 실제로 무엇을 할지는 board_screen.dart가 정합니다.
        //
        //   레퍼런스 끌어다 놓기 — 다른 창(메인 ↔ 팝업)에서 카드를 끄는
        //     것이라 `supportsBoardPopupWindow`(데스크톱 전용)로 가립니다.
        //   외부 파일 끌어다 놓기 — 그냥 OS가 주는 드롭이라 팝업 여부와
        //     상관없습니다.
        //
        // 둘 다 안 쓰겠다고 하면(콜백이 전부 null이면) DropRegion으로
        // 감싸지 않고 그대로 돌려줍니다. super_drag_and_drop이 이미 제
        // 역할을 하는 곳(home_drop_area.dart) 밖에서까지 켜둘 필요가
        // 없습니다.
        final bool acceptsReferenceDrag =
            supportsBoardPopupWindow && widget.onReferenceDropped != null;
        final bool acceptsExternalDrop = widget.onExternalFilesDropped != null;

        if (!acceptsReferenceDrag && !acceptsExternalDrop) {
          return content;
        }

        return DropRegion(
          // 우리가 보내는 내부 페이로드(Formats.plainText에 접두사 붙인
          // 문자열)와, 탐색기·브라우저가 주는 형식(dropped_item_reader.dart의
          // dropRegionFormats)을 함께 받습니다. 접두사가 없는 글자나
          // 알아보지 못하는 것은 onPerformDrop에서 조용히 무시합니다.
          formats: <DataFormat<Object>>[
            if (acceptsReferenceDrag) Formats.plainText,
            if (acceptsExternalDrop) ...dropRegionFormats,
          ],

          // 끌고 지나가는 동안 "놓을 수 있다"고 알려줍니다. 진짜 우리
          // 페이로드인지는 onPerformDrop에서 가립니다 —
          // home_drop_area.dart와 같은 수준의 단순함입니다.
          onDropOver: (DropOverEvent event) => DropOperation.copy,

          onDropEnter: (DropEvent event) {
            setState(() => _isDropHighlighted = true);
          },
          onDropLeave: (DropEvent event) {
            setState(() => _isDropHighlighted = false);
          },

          onPerformDrop: (PerformDropEvent event) async {
            setState(() => _isDropHighlighted = false);

            final Offset canvasPoint = _toCanvasPoint(
              event.position.local,
              viewport,
            );

            // 내부 레퍼런스 드래그인지 먼저 봅니다. 우리가 보낸 것이
            // 아니면(접두사가 안 맞으면) null이 돌아와서 아래 외부 파일
            // 경로로 자연스럽게 넘어갑니다.
            if (acceptsReferenceDrag) {
              final DataReader? reader = event.session.items.first.dataReader;
              if (reader != null && reader.canProvide(Formats.plainText)) {
                final String? value = await _readPlainText(reader);
                final String? referenceId = tryDecodeReferenceDragPayload(
                  value,
                );
                if (referenceId != null) {
                  widget.onReferenceDropped?.call(referenceId, canvasPoint);
                  return;
                }
              }
            }

            if (acceptsExternalDrop) {
              await widget.onExternalFilesDropped?.call(event, canvasPoint);
            }
          },

          child: Stack(
            children: <Widget>[
              content,

              // 끄는 동안에만 가장자리를 강조합니다. 격자 스냅 안내선과
              // 같은 이유로 IgnorePointer로 감쌉니다 — 안 그러면 이
              // 겹치는 네모가 클릭을 가로채 판이 안 움직입니다.
              if (_isDropHighlighted)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.primary, width: 3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
