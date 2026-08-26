// 분류 항목의 이름을 바꾸는 대화상자입니다.
//
// 새로 만들기(create_taxonomy_dialog.dart)와 거의 같지만 두 가지가 다릅니다.
//   1. 입력창이 기존 이름으로 채워져 있습니다.
//   2. 중복 검사에서 **자기 자신은 빼고** 봅니다.
//      안 그러면 이름을 안 바꾸고 저장할 때 "이미 있다"며 막힙니다.

import 'package:flutter/material.dart';

import '../models/taxonomy_item.dart';
import '../repositories/taxonomy_repository.dart';
import '../utils/korean_particle.dart';

/// 이름 바꾸기 대화상자를 띄웁니다.
///
/// 이름을 바꿨으면 true, 취소했으면 false를 돌려줍니다.
Future<bool> showRenameTaxonomyDialog({
  required BuildContext context,
  required TaxonomyItem item,
  required TaxonomyRepository repository,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return _RenameTaxonomyDialog(item: item, repository: repository);
    },
  );

  // 바깥을 눌러 닫으면 null이 옵니다. 그때는 안 바꾼 것으로 봅니다.
  return result ?? false;
}

/// 이름을 입력받아 분류 항목의 이름을 바꾸는 대화상자입니다.
class _RenameTaxonomyDialog extends StatefulWidget {
  const _RenameTaxonomyDialog({required this.item, required this.repository});

  final TaxonomyItem item;
  final TaxonomyRepository repository;

  @override
  State<_RenameTaxonomyDialog> createState() => _RenameTaxonomyDialogState();
}

class _RenameTaxonomyDialogState extends State<_RenameTaxonomyDialog> {
  /// 입력창의 글자를 읽고 관리하는 도구입니다.
  late final TextEditingController _controller;

  /// 입력창 아래에 보여줄 오류 문구입니다. 문제가 없으면 null입니다.
  String? _errorText;

  /// 저장하는 중인지 여부입니다.
  bool _isSaving = false;

  /// 대화상자가 만들어질 때 기존 이름으로 입력창을 채웁니다.
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.name);
  }

  /// 화면이 사라질 때 입력창 도구를 정리합니다.
  /// 만들었으면 반드시 dispose 해야 메모리에 남지 않습니다.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 새 이름으로 저장합니다.
  Future<void> _save() async {
    final String name = _controller.text.trim();

    if (name.isEmpty) {
      setState(() {
        _errorText = '이름을 입력해주세요.';
      });
      return;
    }

    // 이름이 그대로면 저장할 것도 없이 그냥 닫습니다.
    if (name == widget.item.name) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    // excludeId로 자기 자신을 빼고 검사합니다.
    // 안 빼면 대소문자만 바꾸는 경우에 "이미 있다"며 막힙니다.
    final bool alreadyExists = await widget.repository.existsWithName(
      widget.item.kind,
      name,
      excludeId: widget.item.id,
    );

    if (!mounted) {
      return;
    }

    if (alreadyExists) {
      setState(() {
        _isSaving = false;
        // 조사(이/가)는 앞 글자 받침에 따라 달라지므로 자동으로 고릅니다.
        _errorText = '같은 이름의 ${withSubjectParticle(widget.item.kind.displayName)} 이미 있습니다.';
      });
      return;
    }

    // updatedAt은 저장소가 알아서 갱신하므로 이름만 바꾼 사본을 넘깁니다.
    await widget.repository.save(widget.item.copyWith(name: name));

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  /// 대화상자의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    final String kindName = widget.item.kind.displayName;

    return AlertDialog(
      title: Text('$kindName 이름 바꾸기'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: '$kindName 이름',
          errorText: _errorText,
        ),
        onSubmitted: (String _) {
          if (!_isSaving) {
            _save();
          }
        },
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('바꾸기'),
        ),
      ],
    );
  }
}
