// 분류 항목의 이름을 바꾸는 대화상자입니다.
//
// 새로 만들기(create_taxonomy_dialog.dart)와 거의 같지만 두 가지가 다릅니다.
//   1. 입력창이 기존 이름으로 채워져 있습니다.
//   2. 중복 검사에서 **자기 자신은 빼고** 봅니다.
//      안 그러면 이름을 안 바꾸고 저장할 때 "이미 있다"며 막힙니다.
//
// ── 폴더일 때는 "상위 폴더" 칸도 함께 바꿀 수 있습니다 (2026-09-11, 폴더 중첩) ──
// 이름과 상위 폴더를 한 대화상자에서 동시에 바꿀 수 있습니다. 저장하는
// 순서가 중요합니다 — _save()의 주석을 보세요.

import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/taxonomy_item.dart';
import '../repositories/taxonomy_repository.dart';
import '../utils/folder_tree.dart';
import '../utils/korean_particle.dart';
import 'pick_taxonomy_dialog.dart';

/// 이름 바꾸기 대화상자를 띄웁니다.
///
/// 이름을 바꿨으면(또는 폴더의 상위 폴더를 바꿨으면) true, 취소했으면
/// false를 돌려줍니다.
///
/// [allFolders]는 [item]이 폴더일 때만 씁니다 — "상위 폴더" 칸의 후보
/// 목록입니다.
Future<bool> showRenameTaxonomyDialog({
  required BuildContext context,
  required TaxonomyItem item,
  required TaxonomyRepository repository,
  List<TaxonomyItem> allFolders = const <TaxonomyItem>[],
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return _RenameTaxonomyDialog(
        item: item,
        repository: repository,
        allFolders: allFolders,
      );
    },
  );

  // 바깥을 눌러 닫으면 null이 옵니다. 그때는 안 바꾼 것으로 봅니다.
  return result ?? false;
}

/// 이름을 입력받아 분류 항목의 이름을 바꾸는 대화상자입니다.
class _RenameTaxonomyDialog extends StatefulWidget {
  const _RenameTaxonomyDialog({
    required this.item,
    required this.repository,
    this.allFolders = const <TaxonomyItem>[],
  });

  final TaxonomyItem item;
  final TaxonomyRepository repository;

  /// item이 폴더일 때만 씁니다. "상위 폴더" 칸을 채울 후보들입니다.
  final List<TaxonomyItem> allFolders;

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

  /// 폴더일 때만 씁니다. 지금 고른 상위 폴더의 id입니다.
  late String? _selectedParentId = widget.item.parentId;

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

  /// 새 이름과(폴더라면) 새 상위 폴더로 저장합니다.
  Future<void> _save() async {
    final String name = _controller.text.trim();

    if (name.isEmpty) {
      setState(() {
        _errorText = '이름을 입력해주세요.';
      });
      return;
    }

    final bool isFolder = widget.item.kind == TaxonomyKind.folder;
    final String? targetParentId = isFolder ? _selectedParentId : null;
    final bool nameChanged = name != widget.item.name;
    final bool parentChanged = isFolder && targetParentId != widget.item.parentId;

    // 이름도 상위 폴더도 안 바뀌었으면 저장할 것도 없이 그냥 닫습니다.
    if (!nameChanged && !parentChanged) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    if (nameChanged) {
      // excludeId로 자기 자신을 빼고 검사합니다.
      // 안 빼면 대소문자만 바꾸는 경우에 "이미 있다"며 막힙니다.
      final bool alreadyExists = await widget.repository.existsWithName(
        widget.item.kind,
        name,
        excludeId: widget.item.id,
        parentId: targetParentId,
      );

      if (!mounted) {
        return;
      }

      if (alreadyExists) {
        setState(() {
          _isSaving = false;
          _errorText =
              '같은 이름의 ${withSubjectParticle(widget.item.kind.displayName)} 이미 있습니다.';
        });
        return;
      }
    }

    // ── 순서가 중요합니다 ──
    // save()는 항목을 통째로 다시 써서 parentId도 함께 저장합니다. 그런데
    // widget.item은 이 대화상자가 열릴 때의 옛 parentId를 그대로 들고
    // 있습니다(copyWith(name: name)은 parentId를 안 건드립니다). 그래서
    // moveFolder로 새 parentId를 먼저 넣은 뒤 save()를 부르면, save()가
    // 그 값을 옛 parentId로 도로 덮어씁니다. **이름을 먼저 저장하고,
    // 상위 폴더 이동은 마지막에** 합니다.
    if (nameChanged) {
      await widget.repository.save(widget.item.copyWith(name: name));
    }
    if (!mounted) {
      return;
    }

    if (parentChanged) {
      await widget.repository.moveFolder(widget.item.id, targetParentId);
    }
    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  /// "상위 폴더" 칸을 눌렀을 때 고르는 대화상자를 띄웁니다.
  ///
  /// 자기 자신과 자기 하위는 후보에서 뺍니다 — 순환을 UI에서부터 막아,
  /// 저장소의 moveFolder 예외(FolderMoveCycleException)는 이 경로에서는
  /// 사실상 일어나지 않습니다(방어선은 저장소 쪽에도 남아 있습니다).
  Future<void> _pickParent() async {
    final Set<String> excludeIds = collectFolderAndDescendantIds(
      widget.item.id,
      parentIdMap(widget.allFolders),
    );
    final List<FolderTreeEntry> tree = buildFolderTree(
      widget.allFolders,
      excludeIds: excludeIds,
    );
    final PickedTaxonomy? picked = await showPickTaxonomyDialog(
      context: context,
      kind: TaxonomyKind.folder,
      items: tree.map((FolderTreeEntry e) => e.folder).toList(),
      depthById: <String, int>{
        for (final FolderTreeEntry e in tree) e.folder.id: e.depth,
      },
      title: '상위 폴더',
      allowNone: true,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedParentId = picked.item?.id;
    });
  }

  /// 대화상자의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    final String kindName = widget.item.kind.displayName;
    final bool isFolder = widget.item.kind == TaxonomyKind.folder;
    final String parentLabel = _selectedParentId == null
        ? '최상위'
        : widget.allFolders
            .firstWhere((TaxonomyItem f) => f.id == _selectedParentId)
            .name;

    return AlertDialog(
      title: Text('$kindName 이름 바꾸기'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
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
          if (isFolder) ...<Widget>[
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_outlined),
              title: const Text('상위 폴더'),
              subtitle: Text(parentLabel),
              onTap: _isSaving ? null : _pickParent,
            ),
          ],
        ],
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
