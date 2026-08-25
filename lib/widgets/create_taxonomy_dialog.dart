// 폴더·카테고리·태그·프로젝트를 새로 만드는 작은 대화상자입니다.
//
// 넷 다 "이름만 받으면 되는" 똑같은 모양이라 하나로 만들어 돌려씁니다.
// 어느 종류를 만드는지는 TaxonomyKind로 알려주고, 안내 문구는 그 종류의
// 한국어 이름(displayName)에서 자동으로 만들어집니다.
//
// 이름이 이미 있으면 만들지 않고 그 자리에서 알려줍니다.
// 폴더 "인물"이 두 개 생기면 사용자가 어느 쪽에 넣었는지 알 수 없게 되기 때문입니다.

import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/taxonomy_item.dart';
import '../repositories/taxonomy_repository.dart';
import '../utils/korean_particle.dart';
import '../utils/id_generator.dart';

/// 새 분류 항목을 만드는 대화상자를 띄웁니다.
///
/// 사용자가 만들면 그 항목을, 취소하면 null을 돌려줍니다.
/// 돌려받은 항목을 바로 선택 상태로 만들어주면 "만들었는데 또 골라야 하는" 번거로움이 없습니다.
Future<TaxonomyItem?> showCreateTaxonomyDialog({
  required BuildContext context,
  required TaxonomyKind kind,
  required TaxonomyRepository repository,
}) {
  return showDialog<TaxonomyItem>(
    context: context,
    builder: (BuildContext context) {
      return _CreateTaxonomyDialog(kind: kind, repository: repository);
    },
  );
}

/// 이름을 입력받아 새 분류 항목을 만드는 대화상자입니다.
class _CreateTaxonomyDialog extends StatefulWidget {
  const _CreateTaxonomyDialog({required this.kind, required this.repository});

  final TaxonomyKind kind;
  final TaxonomyRepository repository;

  @override
  State<_CreateTaxonomyDialog> createState() => _CreateTaxonomyDialogState();
}

class _CreateTaxonomyDialogState extends State<_CreateTaxonomyDialog> {
  /// 입력창의 글자를 읽고 관리하는 도구입니다.
  final TextEditingController _controller = TextEditingController();

  /// 입력창 아래에 보여줄 오류 문구입니다. 문제가 없으면 null입니다.
  String? _errorText;

  /// 저장하는 중인지 여부입니다. 중복 검사에 잠깐 시간이 걸립니다.
  bool _isSaving = false;

  /// 화면이 사라질 때 입력창 도구를 정리합니다.
  ///
  /// 이걸 안 하면 화면을 닫아도 메모리에 남습니다(메모리 누수).
  /// TextEditingController를 만들었으면 반드시 짝으로 dispose를 해야 합니다.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 입력한 이름으로 새 항목을 만듭니다.
  Future<void> _save() async {
    // 앞뒤 공백은 빼고 다룹니다. "인물 "과 "인물"을 다른 것으로 만들 이유가 없습니다.
    final String name = _controller.text.trim();

    if (name.isEmpty) {
      setState(() {
        _errorText = '이름을 입력해주세요.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final bool alreadyExists =
        await widget.repository.existsWithName(widget.kind, name);

    if (!mounted) {
      return;
    }

    if (alreadyExists) {
      setState(() {
        _isSaving = false;
        // 조사(이/가)는 앞 글자 받침에 따라 달라지므로 자동으로 고릅니다.
        _errorText = '같은 이름의 ${withSubjectParticle(widget.kind.displayName)} 이미 있습니다.';
      });
      return;
    }

    final DateTime now = DateTime.now().toUtc();
    final TaxonomyItem created = TaxonomyItem(
      id: newId(),
      kind: widget.kind,
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    await widget.repository.save(created);

    if (!mounted) {
      return;
    }

    // 만든 항목을 돌려주면서 대화상자를 닫습니다.
    Navigator.of(context).pop(created);
  }

  /// 대화상자의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    final String kindName = widget.kind.displayName;

    return AlertDialog(
      title: Text('새 $kindName 만들기'),
      content: TextField(
        controller: _controller,

        // 대화상자가 뜨자마자 바로 입력할 수 있게 커서를 놓습니다.
        autofocus: true,

        decoration: InputDecoration(
          labelText: '$kindName 이름',
          errorText: _errorText,
        ),

        // 키보드의 확인 키를 눌러도 저장되게 합니다.
        onSubmitted: (String _) {
          if (!_isSaving) {
            _save();
          }
        },
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          // 저장하는 중에는 버튼을 잠가 두 번 눌리는 것을 막습니다.
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('만들기'),
        ),
      ],
    );
  }
}
