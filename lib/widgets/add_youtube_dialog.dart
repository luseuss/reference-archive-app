// 유튜브 주소를 입력받는 대화상자입니다.
//
// 하는 일은 하나뿐입니다 — **주소를 받아서 영상 번호로 바꿔 돌려주기.**
// 인터넷에서 제목이나 썸네일을 가져오는 일은 여기서 하지 않습니다.
// 그건 시간이 걸리는 일이라, 대화상자를 닫고 목록 화면에서 처리해야
// 사용자가 "창이 멈췄나?" 하고 기다리지 않습니다.

import 'package:flutter/material.dart';

import '../services/youtube_url.dart';

/// 유튜브 주소를 입력받는 대화상자를 띄웁니다.
///
/// 올바른 주소를 넣으면 **영상 번호**를, 취소하면 null을 돌려줍니다.
/// 주소 자체가 아니라 영상 번호를 돌려주는 이유: 주소는 모양이 여러 가지지만
/// 영상 번호는 하나뿐이라, 앱 안에서는 이것만 들고 다니는 편이 단순합니다.
Future<String?> showAddYoutubeDialog({
  required BuildContext context,
  String? initialUrl,
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return _AddYoutubeDialog(initialUrl: initialUrl);
    },
  );
}

/// 유튜브 주소를 입력받는 대화상자입니다.
class _AddYoutubeDialog extends StatefulWidget {
  const _AddYoutubeDialog({this.initialUrl});

  /// 입력창에 미리 채워둘 주소입니다.
  ///
  /// 클립보드에 이미 유튜브 주소가 있으면 채워서 띄웁니다.
  /// 방금 복사해온 것을 또 붙여넣게 하는 것은 번거롭기만 합니다.
  final String? initialUrl;

  @override
  State<_AddYoutubeDialog> createState() => _AddYoutubeDialogState();
}

class _AddYoutubeDialogState extends State<_AddYoutubeDialog> {
  /// 입력창의 글자를 읽고 관리하는 도구입니다.
  late final TextEditingController _controller;

  /// 입력창 아래에 보여줄 오류 문구입니다. 문제가 없으면 null입니다.
  String? _errorText;

  /// 화면이 처음 만들어질 때 입력창을 준비합니다.
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl ?? '');
  }

  /// 화면이 사라질 때 입력창 도구를 정리합니다.
  ///
  /// TextEditingController를 만들었으면 반드시 짝으로 dispose를 해야 합니다.
  /// 안 하면 화면을 닫아도 메모리에 남습니다.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 입력한 주소에서 영상 번호를 뽑아 돌려주고 대화상자를 닫습니다.
  void _submit() {
    final String? videoId = youtubeVideoIdFrom(_controller.text);

    if (videoId == null) {
      setState(() {
        // "올바르지 않습니다"로 끝내면 무엇이 잘못됐는지 알 수 없습니다.
        // 어떤 모양이면 되는지 예를 들어줍니다.
        _errorText =
            '유튜브 영상 주소가 아닙니다.\n'
            '예: https://www.youtube.com/watch?v=... 또는 https://youtu.be/...';
      });
      return;
    }

    Navigator.of(context).pop(videoId);
  }

  /// 대화상자의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('유튜브 영상 추가'),
      content: SizedBox(
        // 너비를 정해주지 않으면 주소 길이에 따라 대화상자 폭이 들쭉날쭉합니다.
        width: 420,
        child: TextField(
          controller: _controller,

          // 대화상자가 뜨자마자 바로 붙여넣을 수 있게 커서를 놓습니다.
          autofocus: true,

          decoration: InputDecoration(
            labelText: '유튜브 주소',
            hintText: 'https://www.youtube.com/watch?v=...',
            errorText: _errorText,
            border: const OutlineInputBorder(),
          ),

          // 키보드의 확인 키를 눌러도 추가되게 합니다.
          onSubmitted: (String _) => _submit(),

          // 글자를 고치면 이전 오류 문구를 지웁니다.
          // 고쳤는데도 빨간 글씨가 남아 있으면 아직 틀린 줄 알게 됩니다.
          onChanged: (String _) {
            if (_errorText != null) {
              setState(() {
                _errorText = null;
              });
            }
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('추가')),
      ],
    );
  }
}
