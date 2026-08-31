// 레퍼런스 메모를 리치텍스트(글자색·형광펜·굵게/기울임/밑줄·목록·링크·
// 정렬)로 고칠 수 있는 편집기입니다.
//
// ── 이 위젯이 하는 일과 안 하는 일 ──
// 한다  — flutter_quill 편집창 + 툴바를 감싸 보여주고, 바뀐 내용을
//        Delta(JSON) 문자열로 바꿔 [onChanged]로 알립니다.
// 안 한다 — 저장하지 않습니다. "언제 저장할지"는 이 위젯을 쓰는 화면
//          (reference_detail_screen.dart)이 정합니다 — 그 화면은 "저장"
//          버튼을 눌렀을 때만 데이터베이스에 씁니다.
//
// ── Delta가 무엇인가 ──
// flutter_quill(그리고 원래 Quill.js)이 서식 있는 글을 표현하는 JSON
// 형식입니다. "이 글자를 넣어라" "이만큼 굵게 해라" 같은 명령들의 목록으로
// 문서를 나타냅니다. 순수 텍스트보다 복잡하지만, 색·목록·링크 같은 것을
// 다 담을 수 있습니다. (utils/rich_text_memo.dart 설명 참고)

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../utils/rich_text_memo.dart';

/// 리치텍스트 메모 편집기입니다.
class RichMemoEditor extends StatefulWidget {
  const RichMemoEditor({
    super.key,
    required this.initialMemo,
    required this.onChanged,
  });

  /// 지금까지 저장된 메모입니다(Delta JSON 문자열). 없으면 null입니다.
  final String? initialMemo;

  /// 내용이 바뀔 때마다 새 Delta(JSON) 문자열을 알려줍니다.
  final ValueChanged<String> onChanged;

  @override
  State<RichMemoEditor> createState() => _RichMemoEditorState();
}

class _RichMemoEditorState extends State<RichMemoEditor> {
  /// 편집기의 내용과 커서 위치를 관리하는 도구입니다.
  late final QuillController _controller;

  /// 화면이 만들어질 때 지금까지의 메모로 편집기를 채웁니다.
  @override
  void initState() {
    super.initState();

    _controller = QuillController(
      document: documentFromMemo(widget.initialMemo),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _controller.addListener(_handleChanged);
  }

  /// 편집기 내용이 바뀔 때마다 저장용 문자열로 바꿔 바깥에 알립니다.
  void _handleChanged() {
    widget.onChanged(memoFromDocument(_controller.document));
  }

  /// 화면이 사라질 때 컨트롤러를 정리합니다.
  @override
  void dispose() {
    _controller.removeListener(_handleChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(appCornerRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          // 정렬 버튼은 flutter_quill 기본값이 꺼져 있습니다(showAlignmentButtons
          // 기본값 false). 5단계 요구사항에 정렬이 있으므로 여기서 켭니다.
          QuillSimpleToolbar(
            controller: _controller,
            config: const QuillSimpleToolbarConfig(
              showAlignmentButtons: true,
              showJustifyAlignment: false, // 왼쪽/가운데/오른쪽만 필요합니다(양쪽 정렬은 요구사항에 없음)
            ),
          ),
          Divider(height: 1, color: palette.border),

          // 판을 딱 하나만 두는 이유: QuillEditor는 세로 크기가 정해져
          // 있어야 합니다(ListView 안에 그냥 두면 "세로로 끝이 없다"는
          // 오류가 납니다). 기존 TextField의 maxLines: 4와 비슷한
          // 자리를 잡아둡니다.
          SizedBox(height: 200, child: QuillEditor.basic(controller: _controller)),
        ],
      ),
    );
  }
}
