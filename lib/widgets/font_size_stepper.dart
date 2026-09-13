// 무드보드 텍스트 카드 서식 팝업의 "글자 크기" 조절기입니다.
//
// ── 왜 flutter_quill 기본 버튼을 안 쓰나 ──
// flutter_quill의 기본 글자 크기 버튼은 "작게/보통/크게/아주 크게"
// 네 단계 중에서만 고르게 되어 있습니다. 의뢰인이 "px 단위로 세세하게
// 원하는 크기로 조절"을 요청해서, +/- 로 1px씩 움직이거나 숫자를 직접
// 타이핑해서 정확한 값을 넣을 수 있는 되짚기(stepper)를 새로 만들었습니다.
//
// ── 왜 정수 px 문자열을 그대로 서식값으로 쓰나 ──
// flutter_quill은 글자 크기 서식을 "몇 픽셀인지"를 담은 문자열로
// 저장합니다(`Attribute.size`). 'small'/'large'/'huge' 같은 미리 정한
// 이름표 대신 '18'처럼 숫자만 있는 문자열을 넣으면, 그 숫자를 그대로
// 픽셀 크기로 씁니다(설치된 flutter_quill 소스의
// `common/utils/font.dart`의 `getFontSize()`를 직접 읽고 확인했습니다).
// 그래서 이 파일은 항상 순수한 숫자 문자열만 만들어 넣습니다.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../theme/app_palette.dart';

/// 텍스트 카드에서 고를 수 있는 가장 작은 글자 크기(px)입니다.
const double minTextCardFontSize = 8;

/// 텍스트 카드에서 고를 수 있는 가장 큰 글자 크기(px)입니다. 이보다
/// 크게 하고 싶으면 카드 자체를 키우는 편이 자연스럽습니다.
const double maxTextCardFontSize = 200;

/// 서식 지정이 없을 때(글을 처음 쓸 때) 기본으로 보여줄 크기입니다.
/// `AppText.cardMemo`의 기본 크기(12.5)와는 별개로, "글자 크기를
/// 처음 만져보는 사용자"에게 익숙한 값(16)을 기본값으로 둡니다.
const double defaultTextCardFontSize = 16;

/// [size]를 문자열로 바꿉니다. 정수면 소수점 없이("18"), 아니면
/// 소수 첫째 자리까지("18.5") 보여줍니다.
String _formatFontSize(double size) {
  return size.truncateToDouble() == size
      ? size.toInt().toString()
      : size.toStringAsFixed(1);
}

/// "-  [숫자칸]  +" 모양의 글자 크기 조절기입니다.
///
/// [controller]의 지금 커서(또는 선택 범위) 서식을 그대로 보여주고,
/// 버튼을 누르거나 숫자를 입력하면 그 자리에 바로 적용합니다 —
/// flutter_quill 자체 버튼들이 컨트롤러 변화를 듣는 것과 같은 방식으로,
/// 커서를 다른 크기의 글자 위로 옮기면 표시된 숫자도 따라 바뀝니다.
class FontSizeStepper extends StatefulWidget {
  const FontSizeStepper({super.key, required this.controller});

  final QuillController controller;

  @override
  State<FontSizeStepper> createState() => _FontSizeStepperState();
}

class _FontSizeStepperState extends State<FontSizeStepper> {
  late double _size = _readSizeFromController();
  late final TextEditingController _textController = TextEditingController(
    text: _formatFontSize(_size),
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _textController.dispose();
    super.dispose();
  }

  /// 지금 커서(선택 범위)에 걸린 글자 크기 서식을 읽어옵니다. 서식이
  /// 없으면(보통 글자) [defaultTextCardFontSize]입니다.
  double _readSizeFromController() {
    final dynamic raw = widget.controller
        .getSelectionStyle()
        .attributes[Attribute.size.key]
        ?.value;
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      final double? parsed = double.tryParse(raw);
      if (parsed != null) {
        return parsed;
      }
    }
    return defaultTextCardFontSize;
  }

  /// 커서를 옮기거나 선택 범위를 바꾸면 컨트롤러가 알려줍니다. 지금
  /// 보여주는 숫자와 다르면 다시 읽어와 갱신합니다.
  void _handleControllerChanged() {
    final double latest = _readSizeFromController();
    if (latest != _size) {
      setState(() {
        _size = latest;
        _textController.text = _formatFontSize(latest);
      });
    }
  }

  /// [newSize]를 범위 안으로 자르고, 실제 서식으로 적용합니다.
  void _apply(double newSize) {
    final double clamped = newSize.clamp(
      minTextCardFontSize,
      maxTextCardFontSize,
    );
    widget.controller.formatSelection(
      Attribute.fromKeyValue(Attribute.size.key, _formatFontSize(clamped)),
    );
    setState(() {
      _size = clamped;
      _textController.text = _formatFontSize(clamped);
    });
  }

  void _step(double delta) => _apply(_size + delta);

  /// 숫자 칸에 직접 입력을 마쳤을 때(Enter 또는 칸 밖 클릭) 부릅니다.
  /// 숫자로 못 읽으면 원래 값으로 되돌립니다.
  void _submitTyped(String text) {
    final double? parsed = double.tryParse(text.trim());
    if (parsed == null) {
      _textController.text = _formatFontSize(_size);
      return;
    }
    _apply(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: '글자 작게',
          icon: const Icon(Icons.remove, size: 16),
          visualDensity: VisualDensity.compact,
          onPressed: () => _step(-1),
        ),
        SizedBox(
          width: 42,
          child: TextField(
            controller: _textController,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            style: TextStyle(fontSize: 13, color: palette.text),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 4),
              border: OutlineInputBorder(),
            ),
            onSubmitted: _submitTyped,
            onTapOutside: (_) => _submitTyped(_textController.text),
          ),
        ),
        IconButton(
          tooltip: '글자 크게',
          icon: const Icon(Icons.add, size: 16),
          visualDensity: VisualDensity.compact,
          onPressed: () => _step(1),
        ),
      ],
    );
  }
}
