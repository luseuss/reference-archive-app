// 폴더나 카테고리처럼 **하나만** 고를 수 있는 항목을 선택하는 칸입니다.
//
// 목록에서 고르거나, 옆의 + 버튼으로 새로 만들어서 바로 고를 수 있습니다.
// "먼저 폴더를 만들어주세요" 같은 안내 없이 그 자리에서 만들 수 있게 하는 것이
// 목적입니다. (기존 웹앱에서도 같은 이유로 + 버튼을 붙였습니다.)
//
// 태그·프로젝트처럼 여러 개 고르는 것은 taxonomy_multi_field.dart를 보세요.

import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/taxonomy_item.dart';
import '../repositories/taxonomy_repository.dart';
import 'create_taxonomy_dialog.dart';

/// 분류 항목을 하나만 고르는 칸입니다.
class TaxonomySingleField extends StatelessWidget {
  const TaxonomySingleField({
    super.key,
    required this.kind,
    required this.options,
    required this.selectedId,
    required this.repository,
    required this.onChanged,
    required this.onCreated,
  });

  /// 폴더인지 카테고리인지
  final TaxonomyKind kind;

  /// 고를 수 있는 항목 목록입니다.
  final List<TaxonomyItem> options;

  /// 지금 골라져 있는 항목의 id입니다. 아무것도 안 골랐으면 null입니다.
  final String? selectedId;

  /// 새 항목을 만들 때 쓸 저장소입니다.
  final TaxonomyRepository repository;

  /// 고른 항목이 바뀌었을 때 알려줍니다. 선택을 지우면 null이 넘어갑니다.
  final ValueChanged<String?> onChanged;

  /// + 버튼으로 새 항목을 만들었을 때 알려줍니다.
  ///
  /// 목록을 다시 불러와야 새로 만든 항목이 보이므로, 화면 쪽에서 처리하도록 넘깁니다.
  final ValueChanged<TaxonomyItem> onCreated;

  /// + 버튼을 눌렀을 때 새 항목 만들기 대화상자를 띄웁니다.
  Future<void> _createNew(BuildContext context) async {
    final TaxonomyItem? created = await showCreateTaxonomyDialog(
      context: context,
      kind: kind,
      repository: repository,
    );

    if (created != null) {
      onCreated(created);
    }
  }

  /// 칸의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    // 목록에 없는 id가 골라져 있으면(예: 그 폴더가 지워졌으면) 화면이 오류를 냅니다.
    // 그런 경우에는 "안 고름" 상태로 취급합니다.
    final bool selectedExists =
        options.any((TaxonomyItem item) => item.id == selectedId);
    final String? safeSelectedId = selectedExists ? selectedId : null;

    return Row(
      children: <Widget>[
        Expanded(
          child: DropdownButtonFormField<String?>(
            initialValue: safeSelectedId,
            decoration: InputDecoration(
              labelText: kind.displayName,
              border: const OutlineInputBorder(),
            ),
            items: <DropdownMenuItem<String?>>[
              // 첫 항목은 "고르지 않음"입니다. 폴더에서 빼낼 수 있어야 하기 때문입니다.
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('없음'),
              ),
              ...options.map((TaxonomyItem item) {
                return DropdownMenuItem<String?>(
                  value: item.id,
                  child: Text(item.name),
                );
              }),
            ],
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: () => _createNew(context),
          icon: const Icon(Icons.add),
          tooltip: '새 ${kind.displayName} 만들기',
        ),
      ],
    );
  }
}
