// 태그나 프로젝트처럼 **여러 개** 고를 수 있는 항목을 선택하는 칸입니다.
//
// 항목들을 알약 모양 칩(chip)으로 늘어놓고, 누르면 켜지고 다시 누르면 꺼집니다.
// 맨 끝의 + 칩으로 새 항목을 그 자리에서 만들 수 있습니다.
//
// 폴더·카테고리처럼 하나만 고르는 것은 taxonomy_single_field.dart를 보세요.

import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/taxonomy_item.dart';
import '../repositories/taxonomy_repository.dart';
import 'create_taxonomy_dialog.dart';

/// 분류 항목을 여러 개 고르는 칸입니다.
class TaxonomyMultiField extends StatelessWidget {
  const TaxonomyMultiField({
    super.key,
    required this.kind,
    required this.options,
    required this.selectedIds,
    required this.repository,
    required this.onChanged,
    required this.onCreated,
  });

  /// 태그인지 프로젝트인지
  final TaxonomyKind kind;

  /// 고를 수 있는 항목 목록입니다.
  final List<TaxonomyItem> options;

  /// 지금 골라져 있는 항목들의 id입니다.
  final List<String> selectedIds;

  /// 새 항목을 만들 때 쓸 저장소입니다.
  final TaxonomyRepository repository;

  /// 고른 목록이 바뀌었을 때 **바뀐 전체 목록**을 알려줍니다.
  ///
  /// "하나 추가/하나 제거"가 아니라 최종 목록을 통째로 넘기는 이유는
  /// 저장소의 setLinkedTaxonomyIds()와 모양을 맞추기 위해서입니다.
  /// 중간 상태가 어긋날 일이 없어집니다.
  final ValueChanged<List<String>> onChanged;

  /// + 칩으로 새 항목을 만들었을 때 알려줍니다.
  final ValueChanged<TaxonomyItem> onCreated;

  /// 칩 하나를 눌렀을 때 켜거나 끕니다.
  void _toggle(String id) {
    // 원래 목록을 직접 고치지 않고 사본을 만들어 고칩니다.
    // 넘겨받은 목록을 직접 건드리면 부모 화면이 "안 바뀌었다"고 착각할 수 있습니다.
    final List<String> updated = List<String>.from(selectedIds);

    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }

    onChanged(updated);
  }

  /// + 칩을 눌렀을 때 새 항목 만들기 대화상자를 띄웁니다.
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
    final TextTheme textStyles = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(kind.displayName, style: textStyles.labelLarge),
        const SizedBox(height: 8),

        // Wrap은 자리가 모자라면 다음 줄로 넘겨줍니다.
        // Row를 쓰면 칩이 많을 때 화면 밖으로 삐져나가며 오류가 납니다.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            ...options.map((TaxonomyItem item) {
              final bool isSelected = selectedIds.contains(item.id);
              return FilterChip(
                label: Text(item.name),
                selected: isSelected,
                onSelected: (bool _) => _toggle(item.id),
              );
            }),

            // 맨 끝의 새로 만들기 칩입니다.
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: Text('새 ${kind.displayName}'),
              onPressed: () => _createNew(context),
            ),
          ],
        ),
      ],
    );
  }
}
