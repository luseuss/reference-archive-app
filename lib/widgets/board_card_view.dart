// 무드보드 판 위에 놓인 카드 한 장의 생김새입니다.
//
// ── 목록의 카드(reference_card.dart)와 왜 다른가 ──
// 목록 카드는 제목·폴더·태그·메모·날짜를 전부 보여줍니다. 찾기 위한 화면이기 때문입니다.
// 무드보드는 **분위기를 보는 곳**이라 글자가 많으면 오히려 방해가 됩니다.
// 그래서 평소에는 그림만 보이고, 마우스를 올렸을 때만 제목·내리기 버튼·크기 조절
// 손잡이가 나타납니다.
//
// 이 위젯은 자리(x, y)를 모릅니다. 어디에 놓을지는 판(board_canvas.dart)이 정하고,
// 여기는 "한 장이 어떻게 생겼는가"만 책임집니다. 크기도 직접 바꾸지 않고
// "손잡이를 이만큼 끌었다"고 알리기만 합니다.

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../models/reference_item.dart';
import '../services/system_fonts.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';
import '../utils/board_card_actions.dart' show BoardResizeCorner;
import '../utils/rich_text_memo.dart';
import 'context_menu.dart';
import 'font_picker_popup.dart';
import 'font_size_stepper.dart';

/// 크기 조절 손잡이의 한 변 길이입니다.
///
/// 너무 작으면 못 잡고, 너무 크면 그림을 가립니다. 20이면 마우스로 집기에
/// 무리가 없으면서 카드 구석에 얌전히 들어갑니다.
const double boardResizeHandleSize = 20;

/// 무드보드 위의 카드 한 장입니다.
class BoardCardView extends StatefulWidget {
  const BoardCardView({
    super.key,
    required this.item,
    required this.imagePath,
    required this.onRemove,
    required this.onMeasured,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
    this.isActive = false,
    this.isSelected = false,
    this.isGrouped = false,
    this.isPlaying = false,
    this.playerUrl,
    this.onPlayPressed,
    this.onStopPlaying,
    this.onOpenDetail,
    this.onUngroupSelected,
    this.textContent,
    this.fontFamily,
    this.onTextChanged,
    this.onTextFocusNodeCreated,
    this.onTextFocusNodeDisposed,
    this.onRequestBoardFocus,
  });

  /// 이 카드가 보여주는 레퍼런스입니다. **텍스트 카드는 null입니다** —
  /// 그때는 [textContent]를 대신 봅니다(schemaVersion 9).
  final ReferenceItem? item;

  /// 텍스트 카드의 내용(서식 있는 Delta JSON)입니다. [item]이 null일
  /// 때만 뜻이 있습니다.
  final String? textContent;

  /// 텍스트 카드의 기본 글꼴입니다. null이면 앱 기본 글꼴입니다.
  final String? fontFamily;

  /// 텍스트 카드의 내용이 바뀔 때마다(글자를 치거나 서식을 바꿀 때마다)
  /// 새 Delta(JSON) 문자열을 알려줍니다. 저장은 이 카드가 아니라
  /// board_screen.dart가 합니다 — reference_card.dart의 onDelete와
  /// 같은 원칙입니다.
  final ValueChanged<String>? onTextChanged;

  /// 텍스트 카드 편집기의 키보드 초점 노드([_textFocusNode])가 **만들어지는
  /// 순간** 한 번 알려줍니다(카드 하나가 사는 동안 딱 한 번 — 편집을
  /// 시작·종료할 때마다가 아닙니다). board_screen.dart가 "이 노드는
  /// 텍스트 편집기의 것"이라고 기억해뒀다가, 판의 단축키(아래
  /// [onTextFocusNodeDisposed] 설명 참고)를 지금 실행해도 되는지 판단할
  /// 때 씁니다.
  final ValueChanged<FocusNode>? onTextFocusNodeCreated;

  /// 이 카드가 없어질 때(dispose) [_textFocusNode]를 잊어달라고 알립니다.
  ///
  /// ── 왜 이런 방식으로 만들었나 ──
  /// 판 화면 전체를 감싼 단축키(Delete·Ctrl+V·Ctrl+Z, board_screen.dart의
  /// `_handleBoardKeyEvent`)는 지금 초점이 어디 있는지와 상관없이 키를
  /// 그대로 가로챕니다. 텍스트 카드 편집기가 안에서 Ctrl+V(글자
  /// 붙여넣기)나 Backspace(글자 지우기)를 자기 것으로 처리하기 **전에**
  /// 판의 단축키가 먼저 채가서, "글을 붙여넣으려 했는데 판이 새
  /// 레퍼런스를 만들려 하고, 글자를 지우려 했는데 카드 자체가
  /// 삭제되는" 문제가 실제로 있었습니다.
  ///
  /// **처음에는 "지금 편집 중"이라는 참/거짓 값을 직접 알리는 방식으로
  /// 고쳤는데, 그러면 "완료" 버튼을 누르지 않고 그냥 다른 곳을 클릭해
  /// 편집을 벗어나면 값이 거짓으로 안 바뀌어 판의 단축키가 계속 꺼진
  /// 채로 남는** 새 버그가 생겼습니다(의뢰인 보고 — 텍스트도 이미지도
  /// 붙여넣기가 안 됨). 그래서 지금은 참/거짓을 직접 들고 있지 않고,
  /// board_screen.dart가 **키를 누르는 바로 그 순간** `FocusManager`에게
  /// "지금 실제로 초점이 잡힌 위젯이 이 카드의 편집기인가"를 직접
  /// 물어봅니다(`_isTextEditorFocused` 참고) — 초점은 클릭 한 번으로
  /// 다른 곳으로 자연스럽게 옮겨가므로, "완료"를 누르든 그냥 클릭해서
  /// 벗어나든 항상 정확합니다.
  final ValueChanged<FocusNode>? onTextFocusNodeDisposed;

  /// "완료"를 눌러 편집을 끝낼 때, 키보드 초점을 판 자신에게 돌려달라고
  /// board_screen.dart에 부탁합니다. (자세한 이유는 `_finishEditingText()`
  /// 안의 설명 참고 — `FocusNode.unfocus()`만으로는 초점이 엉뚱한
  /// 곳(앱 뿌리 쪽 스코프)으로 가버려서 판의 단축키가 먹통이 됩니다)
  final VoidCallback? onRequestBoardFocus;

  /// 이미지 파일의 전체 경로입니다. 아직 못 구했으면 null입니다.
  ///
  /// 유튜브도 여기로 옵니다. 썸네일을 내려받아 파일로 저장해두기 때문입니다.
  final String? imagePath;

  /// 판에서 내리기 버튼을 눌렀을 때 실행할 동작입니다.
  ///
  /// 카드가 직접 내리지 않고 "눌렸다"고 알리기만 합니다.
  /// 실제로 내리는 일은 화면(board_screen.dart)이 합니다.
  final VoidCallback onRemove;

  /// 크기 조절 손잡이를 잡았을 때, **지금 이 카드의 실제 크기**를 알려줍니다.
  ///
  /// 카드 높이는 보통 저장돼 있지 않습니다(= 그림 비율대로). 그래서 지금 높이가
  /// 얼마인지는 **실제로 그려진 것을 재봐야** 알 수 있고, 재는 일은 카드 자신만
  /// 할 수 있습니다.
  /// 이 카드가 **실제로 몇 픽셀로 그려졌는지** 알려줍니다.
  ///
  /// ── 왜 필요한가 ──
  /// 카드 높이는 보통 저장돼 있지 않습니다(= 그림 비율대로). 그래서 판은
  /// 카드가 세로로 얼마나 긴지 **모릅니다.** 전에는 4:3이라고 어림잡았는데,
  /// 세로 사진이면 128픽셀이나 어긋났습니다. 스냅이 붙는 거리가 8픽셀이니
  /// **눈에 보이지도 않는 자리에 붙는** 셈이었습니다.
  ///
  /// 재는 일은 카드 자신만 할 수 있어서 여기서 알려줍니다.
  /// 크기가 바뀌었을 때만 부릅니다. 매번 부르면 화면이 계속 다시 그려집니다.
  final void Function(Size size) onMeasured;

  /// [corner]는 어느 손잡이를 잡았는지입니다. 네 모서리 중 하나입니다.
  final void Function(Size currentSize, BoardResizeCorner corner) onResizeStart;

  /// 손잡이를 끄는 동안 움직인 만큼을 알려줍니다.
  final ValueChanged<Offset> onResizeUpdate;

  /// 손잡이에서 손을 뗐을 때 알려줍니다.
  final VoidCallback onResizeEnd;

  /// 지금 이 카드를 끌거나 크기를 바꾸고 있는 중인지 여부입니다.
  ///
  /// 살짝 들어 올려서 "지금 잡고 있는 것이 이것"임을 보여줍니다.
  /// 표시가 없으면 여러 장이 겹쳐 있을 때 무엇이 따라오는지 알기 어렵습니다.
  final bool isActive;

  /// 지금 이 카드가 **마퀴로 골라져 있는지** 여부입니다. (5단계 마퀴 다중선택)
  ///
  /// ── isActive와 무엇이 다른가 ──
  /// isActive는 "지금 이 카드가 끌리고 있다"는 뜻이라 손을 떼면 사라집니다.
  /// isSelected는 "여러 장을 함께 다루려고 골라뒀다"는 뜻이라, 손을 떼도
  /// **마우스를 올리지 않아도** 계속 보여야 합니다. 안 그러면 뭘 골랐는지
  /// 잊어버립니다.
  final bool isSelected;

  /// 지금 이 카드가 **그룹에 속해 있는지** 여부입니다. (7단계 카드 그룹화)
  ///
  /// 마우스를 올렸을 때 제목 띠에 작은 사슬 모양 표시를 하나 더
  /// 띄웁니다 — "이 카드는 혼자가 아니라 다른 카드와 함께 움직인다"를
  /// 알려주는 용도입니다. isSelected와 달리 마우스를 안 올리면 안
  /// 보입니다 — 그룹인지 아닌지는 늘 알아야 할 정보가 아니라, 만지기
  /// 전에 살짝 참고하면 되는 정보입니다.
  final bool isGrouped;

  /// 지금 이 카드가 **그 자리에서 유튜브 영상을 재생 중인지** 여부입니다.
  ///
  /// 유튜브 레퍼런스 카드에만 뜻이 있습니다. 판 안에서는 한 번에 하나만
  /// 재생됩니다(board_video_playback_controller.dart 참고).
  final bool isPlaying;

  /// 재생기 웹뷰가 열어야 할 주소입니다. [isPlaying]이 참일 때만 씁니다.
  final String? playerUrl;

  /// 재생 버튼을 눌렀을 때 실행할 동작입니다. (유튜브 카드에만 보입니다)
  ///
  /// null이면 재생 버튼 자체를 안 보여줍니다 — 웹뷰 부품이 없는 환경
  /// (리눅스 등)에서 board_screen.dart가 이렇게 넘깁니다.
  final VoidCallback? onPlayPressed;

  /// 우클릭 메뉴의 "레퍼런스 상세 열기"를 눌렀을 때 실행할 동작입니다.
  /// null이면 메뉴에서 이 항목이 안 보입니다.
  final VoidCallback? onOpenDetail;

  /// 우클릭 메뉴의 "그룹 해제"를 눌렀을 때 실행할 동작입니다.
  /// null이면(그룹에 속하지 않은 카드) 메뉴에서 이 항목이 안 보입니다.
  final VoidCallback? onUngroupSelected;

  /// 재생을 멈추고 다시 썸네일로 돌아갈 때 실행할 동작입니다.
  /// [isPlaying]이 참일 때만 보이는 버튼입니다.
  final VoidCallback? onStopPlaying;

  @override
  State<BoardCardView> createState() => _BoardCardViewState();
}

class _BoardCardViewState extends State<BoardCardView> {
  /// 마지막으로 바깥에 알려준 크기입니다. 같은 값을 또 알리지 않으려고 둡니다.
  Size? _reportedSize;

  /// 지금 마우스가 이 카드 위에 올라와 있는지 여부입니다.
  ///
  /// 카드마다 따로 기억합니다. 판 전체가 기억하면 카드 하나에 마우스가 스칠 때마다
  /// 판에 놓인 카드를 전부 다시 그리게 됩니다.
  bool _isHovered = false;

  /// **텍스트 카드**([widget.item]이 null)일 때만 씁니다. 편집기의
  /// 내용과 커서 위치를 관리합니다 — rich_memo_editor.dart의
  /// `_RichMemoEditorState`와 같은 패턴입니다.
  QuillController? _textController;

  /// 텍스트 편집기의 키보드 초점입니다. 편집 모드로 들어갈 때 여기로
  /// 초점을 옮겨서 곧바로 타이핑할 수 있게 합니다.
  final FocusNode _textFocusNode = FocusNode();

  /// 지금 이 텍스트 카드를 고쳐 쓰는 중인지 여부입니다. 참일 때만
  /// 서식 툴바가 뜨고, 안의 글자를 고칠 수 있습니다. 평소에는
  /// 읽기 전용으로 보여서 판을 옮기거나 크기를 바꿀 때 실수로
  /// 글자를 건드리지 않습니다.
  bool _isEditingText = false;

  /// 이 컴퓨터에 설치된 글꼴 목록입니다. 텍스트 카드일 때만 한 번
  /// 읽어옵니다(레지스트리를 읽는 일이라 카드마다 매번 다시 읽을
  /// 필요가 없습니다 — initState에서 한 번만 부릅니다).
  List<SystemFontInfo> _systemFonts = const <SystemFontInfo>[];

  /// 서식 툴바를 카드에 붙이지 않고 **떠 있는 팝업**으로 보여주기
  /// 위한 자리입니다. 열려 있으면 값이 있고, 닫혀 있으면 null입니다.
  /// (자세한 이유는 아래 [_openFloatingToolbar] 설명 참고)
  OverlayEntry? _toolbarEntry;

  /// 마지막으로 두 번 누른 자리(화면 기준)입니다. 편집 모드로 들어가는
  /// 순간 그 자리 근처에 서식 툴바를 띄우려고 기억해둡니다.
  Offset? _lastDoubleTapPosition;

  @override
  void initState() {
    super.initState();

    if (widget.item == null) {
      _textController = QuillController(
        document: documentFromMemo(widget.textContent),
        selection: const TextSelection.collapsed(offset: 0),
        // 이 카드는 순수 리치텍스트 서식만 다룹니다. 그림은 이미
        // "레퍼런스 카드"라는 자기 자리가 있어서, 텍스트 카드 안에
        // 따로 박아 넣는 기능은 없습니다. enableExternalRichPaste(기본값
        // 참)를 켜두면 브라우저·워드 등에서 복사한 서식 있는 글(HTML)을
        // 붙여넣을 때 그 안의 <img> 태그가 그림 삽입 서식(embed)으로
        // 바뀌어 들어가는데, 이 앱은 그걸 그릴 방법(embedBuilders)이
        // 없어서 "UnimplementedError: Embeddable type image is not
        // supported..."로 앱이 죽습니다(의뢰인이 실제로 겪은 크래시 —
        // rich_memo_editor.dart도 같은 이유로 같이 고쳤습니다). 그래서
        // 서식 있는 붙여넣기 자체를 꺼서, 무엇을 붙여넣든 항상 순수
        // 글자로만 들어오게 합니다.
        config: const QuillControllerConfig(
          clipboardConfig: QuillClipboardConfig(
            enableExternalRichPaste: false,
          ),
        ),
      );
      _systemFonts = loadInstalledFontFamilies();
      // board_screen.dart에게 "이 초점 노드는 텍스트 편집기 것"이라고
      // 알려둡니다. 편집을 시작·종료할 때마다가 아니라 카드가 살아있는
      // 동안 딱 한 번입니다(onTextFocusNodeDisposed 설명 참고).
      widget.onTextFocusNodeCreated?.call(_textFocusNode);
    }
  }

  @override
  void dispose() {
    _closeFloatingToolbar();
    if (widget.item == null) {
      widget.onTextFocusNodeDisposed?.call(_textFocusNode);
    }
    _textController?.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  /// 텍스트 카드를 편집 모드로 들어갑니다. 서식 툴바(떠 있는 팝업)를
  /// 두 번 누른 자리 근처에 띄우고, 바로 타이핑할 수 있게 초점을 옮깁니다.
  void _startEditingText() {
    setState(() {
      _isEditingText = true;
    });
    _textFocusNode.requestFocus();
    _openFloatingToolbar(_lastDoubleTapPosition ?? Offset.zero);
  }

  /// 텍스트 카드 편집을 끝내고 읽기 전용으로 돌아갑니다. 뜬 서식
  /// 팝업을 닫고, 바뀐 내용을 저장하라고 바깥에 알립니다.
  void _finishEditingText() {
    if (!_isEditingText) {
      return;
    }
    _closeFloatingToolbar();
    setState(() {
      _isEditingText = false;
    });
    // 키보드 초점을 판 자신에게 돌려줍니다. **`_textFocusNode.unfocus()`만
    // 부르면 안 됩니다** — `unfocus()`는 "가장 가까운 FocusScope로
    // 초점을 올려보낼 뿐"이라, 이 판의 자체 단축키 처리
    // (board_screen.dart의 `_handleBoardKeyEvent`)가 있는 자리로
    // 돌아온다는 보장이 없습니다(실제로는 훨씬 위 스코프로 가버려서,
    // 그 뒤로 Ctrl+V·Delete·Ctrl+Z가 전부 어디에도 안 가고 사라지는
    // 문제가 있었습니다). `onRequestBoardFocus`는 board_screen.dart가
    // "판 자신의 초점 노드"에 직접 `requestFocus()`를 불러서, 도착지가
    // 확실합니다.
    widget.onRequestBoardFocus?.call();
    widget.onTextChanged?.call(memoFromDocument(_textController!.document));
  }

  /// [globalPosition](화면 기준) 근처에 서식 툴바 팝업을 띄웁니다.
  ///
  /// ── 왜 카드에 붙이지 않고 떠 있는 팝업으로 만들었나 ──
  /// 처음에는 편집 모드에 들어가면 카드 위쪽에 툴바가 항상 붙어
  /// 그려졌는데, 의뢰인이 "떨어져 있도록, 우클릭하면 뜨는 선택창처럼"
  /// 만들어달라고 요청했습니다. 그래서 지금은 `Overlay`(이 앱
  /// 화면 전체를 덮는 맨 위층 — 카드가 속한 판의 확대·이동과
  /// 무관하게 항상 화면 기준 자리에 그려집니다)에 팝업을 끼워
  /// 넣습니다. 이미 열려 있으면 먼저 닫고 새 자리에 다시 엽니다.
  ///
  /// ── 왜 바깥을 눌러도 안 닫히나 ──
  /// 보통 컨텍스트 메뉴(context_menu.dart)는 바깥을 누르면 닫히는
  /// 투명한 배경이 전체 화면을 덮습니다. 그런데 이 팝업은 "메뉴"가
  /// 아니라 "계속 글을 고치면서 곁에 두고 쓰는 도구"라, 전체 화면을
  /// 덮는 배경을 두면 편집기 안 글자를 클릭해 커서를 옮기는 것조차
  /// 막혀버립니다. 그래서 우클릭으로 다시 토글하거나(_toggleFloatingToolbar)
  /// "완료"를 눌러야만 닫힙니다.
  void _openFloatingToolbar(Offset globalPosition) {
    _closeFloatingToolbar();

    final OverlayState overlay = Overlay.of(context);
    final RenderBox overlayBox =
        overlay.context.findRenderObject()! as RenderBox;
    final Size overlaySize = overlayBox.size;

    const double panelWidth = 420;
    const double panelHeight = 48;
    final double left = globalPosition.dx.clamp(
      0.0,
      (overlaySize.width - panelWidth).clamp(0.0, double.infinity),
    );
    final double top = globalPosition.dy.clamp(
      0.0,
      (overlaySize.height - panelHeight).clamp(0.0, double.infinity),
    );

    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext context) {
        return Positioned(
          left: left,
          top: top,
          child: _buildFloatingToolbarPanel(),
        );
      },
    );
    _toolbarEntry = entry;
    overlay.insert(entry);
  }

  /// 떠 있는 서식 팝업을 닫습니다. 이미 닫혀 있으면 아무 일도 안 합니다.
  void _closeFloatingToolbar() {
    _toolbarEntry?.remove();
    _toolbarEntry = null;
  }

  /// 우클릭한 자리에 팝업이 닫혀 있으면 열고, 열려 있으면 닫습니다.
  /// (컨텍스트 메뉴를 다시 우클릭하면 닫히는 것과 같은 손맛입니다)
  void _toggleFloatingToolbar(Offset globalPosition) {
    if (_toolbarEntry != null) {
      _closeFloatingToolbar();
    } else {
      _openFloatingToolbar(globalPosition);
    }
  }

  /// 손잡이를 잡는 순간 카드의 실제 크기를 재서 바깥에 알려줍니다.
  ///
  /// `context.size`는 **지금 화면에 그려진 이 카드의 크기**입니다.
  /// 판 좌표 기준이라, 판을 확대해서 보고 있어도 값은 그대로입니다.
  void _reportResizeStart(BoardResizeCorner corner) {
    final Size? size = context.size;
    if (size == null) {
      return;
    }
    widget.onResizeStart(size, corner);
  }

  /// 다 그려진 뒤에 실제 크기를 재서 바깥에 알려줍니다.
  ///
  /// ── 왜 build가 끝난 뒤인가 ──
  /// build를 하는 도중에는 아직 크기가 안 정해져 있습니다. 그림을 읽어와
  /// 비율을 알아야 높이가 나오기 때문입니다. addPostFrameCallback은
  /// "이번에 다 그리고 나면 불러줘"라는 뜻입니다.
  ///
  /// 값이 바뀌었을 때만 알립니다. 매번 알리면 화면이 끝없이 다시 그려집니다.
  void _measureAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) {
        return;
      }

      final Size? size = context.size;
      if (size == null) {
        return;
      }
      if (size == _reportedSize) {
        return;
      }

      _reportedSize = size;
      widget.onMeasured(size);
    });
  }

  /// 카드 한 장의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;

    _measureAfterBuild();

    // 잡고 있거나 마우스를 올렸으면 도드라지게 합니다.
    final bool isRaised = widget.isActive || _isHovered;

    // 테두리·그림자는 raised와 selected 둘 중 하나만 있어도 보입니다.
    // 마우스를 안 올려도 "무엇을 골라뒀는지"가 계속 보여야 하기 때문입니다.
    final bool isHighlighted = isRaised || widget.isSelected;

    final Widget cardBody = MouseRegion(
      // 손가락 터치로는 아무 일도 일어나지 않아서 폰에서는 저절로 조용합니다.
      onEnter: (PointerEnterEvent event) => setState(() => _isHovered = true),
      onExit: (PointerExitEvent event) => setState(() => _isHovered = false),

      // 마우스를 올리면 커서가 "잡을 수 있는 손" 모양이 됩니다.
      // 끌 수 있다는 것을 알려주는 가장 익숙한 방법입니다.
      cursor: SystemMouseCursors.grab,

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,

        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(appCornerRadius),
          border: Border.all(
            color: isHighlighted ? colors.primary : palette.border,
            width: isHighlighted ? 2 : 1,
          ),
          boxShadow: isHighlighted
              ? palette.cardShadowHovered
              : palette.cardShadow,
        ),

        // 그림이 둥근 모서리 밖으로 삐져나오지 않게 잘라냅니다.
        clipBehavior: Clip.antiAlias,

        child: Stack(
          children: <Widget>[
            // ── 이 그림이 Stack의 크기를 정합니다 ──
            // Positioned.fill로 감싸면 크기를 정해주는 자식이 하나도 없게 되어
            // "높이를 알 수 없다"는 오류가 납니다. 겹치는 것들만 Positioned로 얹습니다.
            _buildImage(colors),

            // 재생 버튼은 유튜브 카드에서 재생 중이 아닐 때만, 마우스를
            // 올리지 않아도 항상 보입니다. 목록 화면의 재생 버튼과 같은
            // 이유입니다 — "이건 영상이다"를 눈에 띄게 알려야 합니다.
            if (widget.onPlayPressed != null && !widget.isPlaying)
              _buildPlayButton(),

            // 제목·내리기·크기 조절은 마우스를 올렸을 때만 나타납니다.
            // 평소에도 떠 있으면 그림 여러 장을 늘어놓고 볼 때 눈이 어지럽습니다.
            if (isRaised) ...<Widget>[
              _buildTitleBar(colors),
              for (final BoardResizeCorner corner in BoardResizeCorner.values)
                _buildResizeHandle(colors, corner),
            ],

            // 골라진 표시는 마우스를 안 올려도 항상 보입니다. 여러 장을
            // 골라뒀을 때, 마우스를 하나하나 올려보지 않고도 한눈에
            // "이만큼 골랐다"를 알 수 있어야 합니다.
            if (widget.isSelected) _buildSelectedBadge(colors),
          ],
        ),
      ),
    );

    return ContextMenuRegion(
      // 이 카드는 이미 board_canvas.dart의 끌기 GestureDetector 안에
      // 있습니다. 우클릭 인식기를 보통 방식(GestureDetector)으로 더하면
      // 제스처 아레나에 경쟁자가 늘어 "살짝만 끌 때 끌기가 안 먹히는"
      // 회귀가 생깁니다(실제로 겪었습니다 — context_menu.dart의
      // avoidGestureArena 설명 참고). 그래서 이 카드만은 아레나에
      // 안 끼는 방식을 씁니다.
      avoidGestureArena: true,
      buildActions: (_) => <ContextMenuAction>[
        if (widget.onOpenDetail != null)
          ContextMenuAction(
            label: '레퍼런스 상세 열기',
            icon: Icons.open_in_new,
            onSelected: widget.onOpenDetail!,
          ),
        if (widget.onUngroupSelected != null)
          ContextMenuAction(
            label: '그룹 해제',
            icon: Icons.link_off,
            onSelected: widget.onUngroupSelected!,
          ),
        ContextMenuAction(
          label: '판에서 내리기',
          icon: Icons.remove_circle_outline,
          isDestructive: true,
          onSelected: widget.onRemove,
        ),
      ],
      child: cardBody,
    );
  }

  /// 카드의 그림 부분입니다.
  ///
  /// ── 크기를 정해뒀는지에 따라 다르게 그립니다 ──
  /// 아직 크기를 안 바꾼 카드는 **원본 비율 그대로** 둡니다. 무드보드에서 사진을
  /// 네모로 잘라버리면 구도가 사라져서, 애초에 이 판을 만든 이유가 없어집니다.
  ///
  /// 크기를 바꾼 카드는 정해진 높이에 맞춰야 하는데, 이때도 비율은 지켜집니다.
  /// 크기 조절이 **가로세로 비율을 고정한 채** 이뤄지기 때문입니다
  /// (board_screen.dart의 `_onResizeUpdate` 설명 참고).
  Widget _buildImage(ColorScheme colors) {
    // 텍스트 카드는 그림이 아니라 글자를 보여줍니다.
    if (widget.item == null) {
      return _buildTextCard();
    }

    // 재생 중이면 썸네일 대신 진짜 재생기(웹뷰)를 보여줍니다.
    if (widget.isPlaying && widget.playerUrl != null) {
      return _buildSizedPlayer(widget.playerUrl!);
    }

    final String? path = widget.imagePath;

    if (path == null) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: _buildPlaceholder(colors, Icons.image_outlined),
      );
    }

    return Image.file(
      File(path),
      width: double.infinity,
      fit: BoxFit.fitWidth,

      // 아직 안 읽힌 그림은 높이가 0이라 카드가 납작해집니다.
      // 그러면 위에 얹은 버튼들이 카드 밖으로 밀려나 눌리지 않습니다.
      // 읽히기 전까지 4:3 자리를 잡아두고, 다 읽히면 원본 비율로 바뀝니다.
      frameBuilder:
          (
            BuildContext context,
            Widget child,
            int? frame,
            bool wasSynchronouslyLoaded,
          ) {
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }
            return AspectRatio(
              aspectRatio: 4 / 3,
              child: _buildPlaceholder(colors, Icons.image_outlined),
            );
          },

      // 파일이 지워졌거나 깨졌을 때 판 전체가 빨간 오류 화면이 되지 않게 막습니다.
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        return AspectRatio(
          aspectRatio: 4 / 3,
          child: _buildPlaceholder(colors, Icons.broken_image_outlined),
        );
      },
    );
  }

  /// 텍스트 카드의 내용을 그립니다.
  ///
  /// ── 왜 사진과 달리 SizedBox.expand로 채우나 ──
  /// 사진은 원본 비율대로 스스로 높이를 정합니다(card.height가 비어
  /// 있을 수 있음). 텍스트 카드는 그런 "자연스러운 높이"가 없어서,
  /// 처음 만들 때부터 항상 정해진 높이를 갖습니다(board_interaction_controller.dart의
  /// addTextCardAt 참고). 그래서 위(Positioned)에서 내려주는 높이를
  /// 그대로 다 채우면 됩니다 — 재생기 웹뷰가 겪은 것과 같은 "무한
  /// 높이" 문제(위 _buildSizedPlayer 설명 참고)를 애초에 피합니다.
  ///
  /// ── 평소엔 읽기 전용, 두 번 눌러야 고칠 수 있음 ──
  /// 판 위 카드는 대부분의 시간 동안 "옮기거나 크기를 바꾸는" 대상이지
  /// "타이핑하는" 대상이 아닙니다. 한 번 누르면 바로 편집기로 들어가면
  /// 카드를 옮기려고 누른 손짓과 부딪힙니다. 두 번 눌러야 편집 모드로
  /// 들어가게 해서, 평소 끌기는 방해받지 않습니다.
  Widget _buildTextCard() {
    final AppPalette palette = AppPalette.of(context);
    final QuillController controller = _textController!;
    controller.readOnly = !_isEditingText;

    final TextStyle baseStyle = AppText.cardMemo.copyWith(
      color: palette.text,
      fontFamily: widget.fontFamily,
    );

    final Widget editor = QuillEditor.basic(
      controller: controller,
      focusNode: _textFocusNode,
      config: QuillEditorConfig(
        padding: const EdgeInsets.all(12),
        expands: true,
        scrollable: true,
        customStyles: DefaultStyles(
          paragraph: DefaultTextBlockStyle(
            baseStyle,
            HorizontalSpacing.zero,
            VerticalSpacing.zero,
            VerticalSpacing.zero,
            null,
          ),
        ),
      ),
    );

    if (!_isEditingText) {
      // 편집 중이 아닐 때는 두 번 눌러야 편집기로 들어갑니다. 평소
      // 끌기(카드 옮기기)는 이 GestureDetector를 그냥 지나갑니다 —
      // onDoubleTap만 반응하고 onPanStart 같은 건 안 걸었으므로
      // board_canvas.dart의 끌기 인식기와 부딪히지 않습니다.
      // onDoubleTapDown으로 누른 자리를 기억해뒀다가, 편집 모드로
      // 들어가는 순간(_startEditingText) 그 근처에 서식 팝업을 띄웁니다.
      return SizedBox.expand(
        child: GestureDetector(
          onDoubleTapDown: (TapDownDetails details) {
            _lastDoubleTapPosition = details.globalPosition;
          },
          onDoubleTap: _startEditingText,
          child: AbsorbPointer(child: editor),
        ),
      );
    }

    // 편집 중에는 서식 툴바를 카드에 붙이지 않습니다 — 우클릭으로
    // 여닫는 떠 있는 팝업(_openFloatingToolbar)이 대신합니다. 그래서
    // 여기는 편집기만 그리고, `Listener`로 우클릭(마우스 오른쪽 버튼)만
    // 원시 신호로 잡습니다. `Listener`는 제스처 아레나에 안 끼어서
    // 편집기 자신의 클릭·드래그(글자 선택, 커서 옮기기) 인식과 전혀
    // 안 부딪힙니다 — context_menu.dart의 `avoidGestureArena`와 같은
    // 이유입니다.
    return SizedBox.expand(
      child: Listener(
        onPointerDown: (PointerDownEvent event) {
          if (event.kind == PointerDeviceKind.mouse &&
              event.buttons == kSecondaryMouseButton) {
            _toggleFloatingToolbar(event.position);
          }
        },
        child: editor,
      ),
    );
  }

  /// 편집 중일 때 우클릭으로 여닫는 떠 있는 서식 팝업의 내용물입니다.
  /// 굵게·기울임·밑줄·목록·정렬·글자 크기·링크는 flutter_quill의 기본
  /// 툴바를 그대로 쓰고, 글꼴만은 [_buildFontPickerButton]으로 직접
  /// 만든 버튼으로 바꿨습니다(font_picker_popup.dart 설명 참고).
  /// 맨 끝의 "완료" 버튼을 누르면 저장하고 읽기 전용으로 돌아갑니다.
  Widget _buildFloatingToolbarPanel() {
    final AppPalette palette = AppPalette.of(context);
    final QuillController controller = _textController!;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      color: palette.surface,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildFontPickerButton(controller, palette),
            FontSizeStepper(controller: controller),
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: QuillSimpleToolbar(
                  controller: controller,
                  config: const QuillSimpleToolbarConfig(
                    showAlignmentButtons: true,
                    showJustifyAlignment: false,
                    // 글꼴 선택은 우리가 만든 _buildFontPickerButton이
                    // 대신합니다 — 기본 드롭다운은 끕니다.
                    showFontFamily: false,
                    // 글자 크기도 FontSizeStepper(px 단위 직접 입력)로
                    // 대신합니다 — 기본 버튼은 작게/보통/크게/아주 크게
                    // 네 단계뿐입니다.
                    showFontSize: false,
                    showUndo: false,
                    showRedo: false,
                    showClearFormat: false,
                    showSearchButton: false,
                    showSubscript: false,
                    showSuperscript: false,
                    showInlineCode: false,
                    showCodeBlock: false,
                    showQuote: false,
                    showIndent: false,
                    showHeaderStyle: false,
                    showDividers: false,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: '완료',
              icon: const Icon(Icons.check_circle, size: 20),
              color: palette.accent,
              onPressed: _finishEditingText,
            ),
          ],
        ),
      ),
    );
  }

  /// 글꼴을 고르는 버튼입니다. 누르면 그 자리 아래에 작은 글꼴 목록
  /// 팝업(font_picker_popup.dart)을 띄우고, 하나를 고르면 지금 선택된
  /// 글자(또는 커서 위치부터 새로 입력할 글자)에 그 글꼴을 적용합니다.
  ///
  /// ── 왜 flutter_quill 기본 버튼을 안 쓰나 ──
  /// 기본 버튼은 한 줄짜리 드롭다운이라 설치된 글꼴이 많으면 찾기
  /// 어렵고 미리보기도 없습니다. 대신 여기서는 우리가 만든 팝업을
  /// 띄우되, 실제로 글자에 적용하는 방식(`Attribute.font` 서식을
  /// 지금 선택 범위에 입힘)은 flutter_quill 기본 버튼과 똑같이
  /// 맞췄습니다(설치된 flutter_quill 소스의 font_family_button.dart를
  /// 직접 읽고 확인했습니다) — 그래야 굵게·기울임 같은 다른 서식과
  /// 동일하게 "선택한 글자에만" 또는 "커서부터 새로 입력할 글자에"
  /// 자연스럽게 적용됩니다.
  Widget _buildFontPickerButton(QuillController controller, AppPalette palette) {
    return Builder(
      builder: (BuildContext buttonContext) {
        return IconButton(
          tooltip: '글꼴',
          icon: const Icon(Icons.font_download_outlined, size: 20),
          color: palette.text,
          onPressed: () {
            final RenderBox box =
                buttonContext.findRenderObject()! as RenderBox;
            final Offset anchor = box.localToGlobal(
              Offset(0, box.size.height),
            );
            final String? currentFamily =
                controller.getSelectionStyle().attributes[Attribute.font.key]
                        ?.value
                    as String?;
            showFontPickerPopup(
              context: buttonContext,
              anchorGlobalPosition: anchor,
              systemFonts: _systemFonts,
              currentFamily: currentFamily,
              onSelected: (String family) {
                controller.formatSelection(
                  Attribute.fromKeyValue(Attribute.font.key, family),
                );
              },
            );
          },
        );
      },
    );
  }

  /// 재생기(웹뷰)에 카드의 지금 크기를 못 박아 넘겨줍니다.
  ///
  /// ── 실제로 겪은 크래시 ──
  /// 이 Stack은 (재생 중이 아닐 때) `Image.file`이 스스로 정한 실제
  /// 크기로 자기 높이를 정합니다(위 클래스 설명 "카드의 그림 부분"
  /// 참고 — 카드 높이가 저장돼 있지 않은 경우, 즉 `BoardCard.height`가
  /// null인 보통의 카드는 이 방식에 전적으로 기댑니다). 그런데
  /// `InAppWebView`는 그림과 달리 스스로 크기를 정하지 않고 **"줄 수
  /// 있는 만큼 다 달라"**(내부적으로 `SizedBox.expand`를 씁니다)고
  /// 요구합니다. 재생 버튼을 누르는 순간 이 Stack의 크기를 정하는
  /// 자리에 그림 대신 재생기가 들어가면, 위쪽(판 배치)에서 내려온
  /// "높이는 그림이 알아서 정해라"(`0.0<=h<=Infinity`)라는 제약과
  /// 만나 **"무한한 높이를 달라"**는 요청이 되어 레이아웃 계산 자체가
  /// 깨지고 앱이 죽었습니다(정확히는 여러 겹의 레이아웃 단언
  /// 실패로 이어졌습니다 — `integration_test/board_video_playback_test.dart`로
  /// 재현해 확인했습니다).
  ///
  /// 그래서 재생기를 무한한 크기 대신 **지금까지 재둔 카드 크기
  /// (`_reportedSize`)로 못 박아** 넘겨줍니다. 영상은 항상 썸네일
  /// 상태를 먼저 거친 뒤에만 재생 버튼이 눌리므로(항상 보이는 재생
  /// 버튼이 썸네일 위에 얹혀 있음), 이 시점에는 이미 썸네일 크기가
  /// `_measureAfterBuild()`로 측정되어 있는 것이 보통입니다. 혹시라도
  /// 아직 한 번도 안 재졌다면(이론상 일어나기 어렵지만 방어적으로)
  /// 유튜브 썸네일의 표준 비율(16:9)로 대신합니다.
  Widget _buildSizedPlayer(String url) {
    final Size? size = _reportedSize;
    if (size == null) {
      return AspectRatio(aspectRatio: 16 / 9, child: _buildPlayer(url));
    }
    return SizedBox(
      width: size.width,
      height: size.height,
      child: _buildPlayer(url),
    );
  }

  /// 유튜브 영상을 그 자리에서 실제로 재생하는 웹뷰입니다.
  ///
  /// ── 전체화면 재생 화면과 완전히 같은 방식입니다 ──
  /// [url]은 board_video_playback_controller.dart가 LocalPlayerServer로
  /// 띄운 내 컴퓨터 안 임시 주소입니다. 유튜브 재생기(embed)를 진짜
  /// 주소 없이 그냥 열면 "오류 153"이 나기 때문에 꼭 필요합니다
  /// (자세한 사정은 local_player_server.dart 맨 위 설명 참고). 이미
  /// 검증된 방식을 그대로 재사용하는 것이라 여기서 새로 오류가 날
  /// 걱정은 적습니다.
  ///
  /// **소리와 유튜브 기본 조작 버튼이 그대로 나옵니다** — 호버
  /// 미리보기(reference_card_thumbnail.dart)와 달리 재생 버튼을 직접
  /// 눌러서 튼 것이라, 소리 없이 조작도 못 하게 막아둘 이유가
  /// 없습니다. 그래서 IgnorePointer로 감싸지 않습니다 — 눌러서
  /// 일시정지·되감기·소리 조절을 할 수 있어야 합니다.
  Widget _buildPlayer(String url) {
    if (InAppWebViewPlatform.instance == null) {
      // 재생 버튼을 애초에 웹뷰가 있을 때만 보여주므로 평소에는 여기
      // 올 일이 없습니다. 그래도 혹시 몰라 자리표시자로 막아둡니다.
      return const ColoredBox(color: Colors.black);
    }

    return InAppWebView(
      // 다른 영상으로 바뀌면(주소가 바뀌면) 웹뷰를 새로 만들게 합니다.
      key: ValueKey<String>(url),
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        // 재생 버튼을 눌러서 연 것이므로 바로 재생돼야 자연스럽습니다.
        mediaPlaybackRequiresUserGesture: false,
        javaScriptEnabled: true,
        allowsInlineMediaPlayback: true,
        iframeAllowFullscreen: true,
      ),
    );
  }

  /// 눌러서 그 자리에 바로 재생을 시작하는 버튼입니다. (유튜브 카드만)
  ///
  /// 목록 화면의 재생 버튼(reference_card_thumbnail.dart)과 같은
  /// 모양입니다 — 마우스를 올리지 않아도 항상 보여서 "이건 영상이다"를
  /// 알립니다.
  Widget _buildPlayButton() {
    return Positioned.fill(
      child: Center(
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onPlayPressed,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.play_circle_fill,
                size: 48,
                color: Colors.white,
                shadows: <Shadow>[
                  Shadow(color: Colors.black54, blurRadius: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 제목 띠에 보여줄 글자입니다. 레퍼런스 카드는 제목을, 텍스트
  /// 카드는 안의 글자 첫 부분을 보여줍니다(둘 다 없으면 "(제목 없음)"/
  /// "텍스트").
  String _titleBarLabel() {
    final ReferenceItem? item = widget.item;
    if (item != null) {
      return item.title.isEmpty ? '(제목 없음)' : item.title;
    }
    final String plain = plainTextFromMemo(widget.textContent).trim();
    return plain.isEmpty ? '텍스트' : plain;
  }

  /// 마우스를 올렸을 때 카드 아래쪽에 뜨는 제목 띠입니다.
  ///
  /// **내리기(×) 버튼도 여기에 들어있습니다.** 손잡이가 네 모서리 전부로
  /// 늘어나면서 오른쪽 위가 더는 비어있지 않아, 예전처럼 오른쪽 위에 따로
  /// 떠 있는 버튼으로 두면 오른쪽 위 손잡이와 겹칩니다. 제목 띠 안에
  /// 나란히 두면 겹칠 자리가 없습니다.
  Widget _buildTitleBar(ColorScheme colors) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        // 왼쪽 아래·오른쪽 아래 둘 다 크기 조절 손잡이 자리라 양쪽 다
        // 그만큼 비워둡니다. 안 비우면 제목 띠가 손잡이를 덮어서 잡을 수
        // 없게 됩니다. (카드는 이보다 작아지지 않으므로 — minBoardCardWidth —
        // 아무리 좁아져도 이 너비 안에 글자·버튼이 들어갑니다)
        padding: const EdgeInsets.symmetric(
          horizontal: boardResizeHandleSize,
          vertical: 6,
        ),

        // 밝은 사진 위에서도 글씨가 보이도록 검은 반투명 바탕을 깝니다.
        color: Colors.black.withValues(alpha: 0.55),

        child: Row(
          children: <Widget>[
            // 그룹에 속해 있으면 제목 앞에 작은 사슬 표시를 둡니다.
            // (7단계 카드 그룹화)
            if (widget.isGrouped) ...<Widget>[
              const Icon(Icons.link, size: 12, color: Colors.white70),
              const SizedBox(width: 4),
            ],

            Expanded(
              child: Text(
                _titleBarLabel(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.meta.copyWith(color: Colors.white),
              ),
            ),

            // 재생 중일 때만 보입니다. 눌러서 다시 썸네일로 돌아갑니다.
            // "×"(내리기)와 헷갈리지 않도록 사진 아이콘을 씁니다 —
            // 판에서 내리는 게 아니라 재생만 멈추는 것이라 뜻이 다릅니다.
            if (widget.isPlaying)
              InkWell(
                onTap: widget.onStopPlaying,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(1),
                  child: Icon(
                    Icons.image_outlined,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),

            if (widget.isPlaying) const SizedBox(width: 8),

            // **레퍼런스를 지우는 버튼이 아닙니다.** 판에서만 내려가고
            // 목록에는 그대로 남습니다. 그래서 아이콘도 휴지통(🗑)이 아니라
            // 닫기(✕)를 씁니다. 휴지통을 쓰면 사진이 영영 지워지는 줄 알고
            // 누르기를 무서워하게 됩니다.
            InkWell(
              onTap: widget.onRemove,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(1),
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// [corner]가 가리키는 커서 모양입니다. 반대쪽 대각선끼리 같은 모양을
  /// 씁니다(왼쪽 위·오른쪽 아래는 "↖↘", 오른쪽 위·왼쪽 아래는 "↗↙").
  MouseCursor _cursorFor(BoardResizeCorner corner) {
    switch (corner) {
      case BoardResizeCorner.topLeft:
      case BoardResizeCorner.bottomRight:
        return SystemMouseCursors.resizeUpLeftDownRight;
      case BoardResizeCorner.topRight:
      case BoardResizeCorner.bottomLeft:
        return SystemMouseCursors.resizeUpRightDownLeft;
    }
  }

  /// 네 모서리 중 하나에 놓는 크기 조절 손잡이입니다.
  ///
  /// ── 왜 카드 안쪽 구석인가 (바깥으로 튀어나온 점이 아니라) ──
  /// 밖으로 튀어나오게 하려면 카드가 실제 크기보다 커야 하는데, 그러면 카드끼리
  /// 겹칠 때 보이지 않는 여백이 옆 카드를 가려서 **잘 보이는 카드가 안 잡히는**
  /// 일이 생깁니다. 안쪽 구석에 두면 그림을 조금 가리는 대신 그런 문제가 없습니다.
  ///
  /// ── 이 손잡이의 끌기가 카드 옮기기와 안 섞이는 이유 ──
  /// 이 GestureDetector가 카드 전체의 것보다 **안쪽에** 있습니다. Flutter는 손가락이
  /// 닿은 지점에서 가장 안쪽 것부터 챙기기 때문에, 손잡이 위에서 시작한 끌기는
  /// 손잡이가 가져가고 카드는 안 움직입니다.
  ///
  /// ── 이름표(Key)를 붙여둡니다 ──
  /// 손잡이가 네 개라 아이콘만으로는 테스트에서 어느 것이 어느 모서리인지
  /// 구분할 수 없습니다. `resize-handle-topLeft` 식으로 모서리 이름을 넣어둡니다.
  Widget _buildResizeHandle(ColorScheme colors, BoardResizeCorner corner) {
    return Positioned(
      left: corner.isLeft ? 0 : null,
      right: corner.isLeft ? null : 0,
      top: corner.isTop ? 0 : null,
      bottom: corner.isTop ? null : 0,
      child: MouseRegion(
        // 커서를 대각선 화살표로 바꿔 "여기를 끌면 크기가 바뀐다"를 알립니다.
        cursor: _cursorFor(corner),
        child: GestureDetector(
          key: ValueKey<String>('resize-handle-${corner.name}'),

          // 처음 몇 픽셀이 버려지지 않게 합니다.
          // (왜인지는 board_canvas.dart의 같은 줄 설명을 보세요)
          dragStartBehavior: DragStartBehavior.down,

          onPanStart: (DragStartDetails details) => _reportResizeStart(corner),
          onPanUpdate: (DragUpdateDetails details) =>
              widget.onResizeUpdate(details.delta),
          onPanEnd: (DragEndDetails details) => widget.onResizeEnd(),

          child: Container(
            width: boardResizeHandleSize,
            height: boardResizeHandleSize,
            color: colors.primary.withValues(alpha: 0.85),
            child: Icon(
              // 대각선 두 방향 화살표. 크기 조절 손잡이의 흔한 표시입니다.
              Icons.open_in_full,
              size: 12,
              color: colors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }

  /// 카드 위쪽 가운데에 뜨는 "골라짐" 표시입니다. (5단계 마퀴 다중선택)
  ///
  /// ── 왜 구석이 아니라 가운데인가 ──
  /// 네 구석 전부 크기 조절 손잡이 자리라, 어느 구석에 둬도 마우스를 올렸을
  /// 때(=손잡이가 함께 뜰 때) 겹칩니다. 손잡이가 없는 위쪽 가운데로 옮겼습니다.
  Widget _buildSelectedBadge(ColorScheme colors) {
    return Positioned(
      top: 4,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: colors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: colors.surface, width: 1.5),
          ),
          child: Icon(Icons.check, size: 14, color: colors.onPrimary),
        ),
      ),
    );
  }

  /// 그림을 못 보여줄 때 대신 띄우는 회색 상자입니다.
  Widget _buildPlaceholder(ColorScheme colors, IconData icon) {
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(icon, size: 32, color: colors.onSurfaceVariant),
      ),
    );
  }
}
