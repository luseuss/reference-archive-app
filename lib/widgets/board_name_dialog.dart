// 무드보드의 이름을 입력받는 작은 대화상자입니다.
//
// 새로 만들 때와 이름을 바꿀 때 **같은 대화상자**를 씁니다. 둘 다 "이름 한 줄을
// 받는다"는 점에서 똑같아서, 따로 만들면 나중에 한쪽만 고치게 됩니다.
// 무엇이 다른지는 제목과 버튼 글자뿐이라 인자로 받습니다.
//
// ── 분류 항목 대화상자(create_taxonomy_dialog.dart)와 다른 점 ──
// 폴더·태그는 같은 이름이 두 개 생기면 사용자가 어느 쪽에 넣었는지 알 수 없게 되어
// 중복을 막습니다. 무드보드는 목록에서 **직접 눈으로 골라 여는** 것이라 이름이 같아도
// 헷갈릴 뿐 데이터가 어긋나지는 않습니다. 그래서 중복 검사를 하지 않습니다.
// (막아버리면 "겨울 무드"를 두 가지 방향으로 만들어보고 싶을 때 곤란합니다.)

import 'package:flutter/material.dart';

/// 무드보드 이름을 입력받는 대화상자를 띄웁니다.
///
/// 입력한 이름을 돌려줍니다. 취소하면 null입니다.
/// [initialName]을 넘기면 그 이름이 입력창에 미리 채워집니다(이름 바꾸기).
Future<String?> showBoardNameDialog({
  required BuildContext context,
  required String title,
  required String confirmLabel,
  String initialName = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return _BoardNameDialog(
        title: title,
        confirmLabel: confirmLabel,
        initialName: initialName,
      );
    },
  );
}

/// 이름 한 줄을 입력받는 대화상자입니다.
class _BoardNameDialog extends StatefulWidget {
  const _BoardNameDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialName,
  });

  final String title;
  final String confirmLabel;
  final String initialName;

  @override
  State<_BoardNameDialog> createState() => _BoardNameDialogState();
}

class _BoardNameDialogState extends State<_BoardNameDialog> {
  /// 입력창의 글자를 읽고 관리하는 도구입니다.
  late final TextEditingController _controller;

  /// 입력창 아래에 보여줄 오류 문구입니다. 문제가 없으면 null입니다.
  String? _errorText;

  /// 대화상자가 만들어질 때 입력창을 채웁니다.
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  /// 화면이 사라질 때 입력창 도구를 정리합니다.
  /// 만들었으면 반드시 dispose 해야 메모리에 남지 않습니다.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 입력한 이름을 돌려주며 대화상자를 닫습니다.
  void _submit() {
    // 앞뒤 공백은 빼고 다룹니다. "겨울 무드 "와 "겨울 무드"를 다른 것으로
    // 만들 이유가 없고, 목록에서 보면 구분도 안 됩니다.
    final String name = _controller.text.trim();

    if (name.isEmpty) {
      setState(() {
        _errorText = '이름을 입력해주세요.';
      });
      return;
    }

    Navigator.of(context).pop(name);
  }

  /// 대화상자의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,

        // 대화상자가 뜨자마자 바로 입력할 수 있게 커서를 놓습니다.
        autofocus: true,

        decoration: InputDecoration(
          labelText: '무드보드 이름',
          hintText: '예: 겨울 무드',
          errorText: _errorText,
        ),

        // 키보드의 확인 키를 눌러도 저장되게 합니다.
        onSubmitted: (String _) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
