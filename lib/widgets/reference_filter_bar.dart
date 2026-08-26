// 목록 위쪽의 검색창·정렬·필터 줄입니다.
//
// 이 위젯은 조건을 **직접 적용하지 않습니다.** 사용자가 뭔가 바꾸면
// "바뀐 조건"을 만들어서 부모 화면에 알려주기만 합니다.
// 실제로 목록을 다시 불러오는 일은 화면(home_screen.dart)이 합니다.
//
// 이렇게 나눠두면 이 위젯은 생김새만 책임지게 되어 테스트하기도, 고치기도 쉽습니다.

import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/reference_query.dart';
import '../models/taxonomy_item.dart';

/// 검색·정렬·필터를 조작하는 줄입니다.
class ReferenceFilterBar extends StatelessWidget {
  const ReferenceFilterBar({
    super.key,
    required this.query,
    required this.taxonomyOptions,
    required this.onQueryChanged,
    required this.onToggleSelectionMode,
    required this.onOpenTaxonomyManage,
  });

  /// 지금 걸려 있는 조건입니다.
  final ReferenceQuery query;

  /// 고를 수 있는 분류 항목들입니다. (종류별로 나눠 담겨 있습니다)
  final Map<TaxonomyKind, List<TaxonomyItem>> taxonomyOptions;

  /// 조건이 바뀌었을 때 바뀐 조건 전체를 알려줍니다.
  final ValueChanged<ReferenceQuery> onQueryChanged;

  /// "여러 장 고르기"를 눌렀을 때 실행할 동작입니다.
  ///
  /// null이면 버튼이 잠깁니다. 보여줄 것이 없으면 고를 것도 없습니다.
  final VoidCallback? onToggleSelectionMode;

  /// "분류 관리"를 눌렀을 때 실행할 동작입니다.
  final VoidCallback onOpenTaxonomyManage;

  /// 해당 종류에서 지금 골라진 항목의 id를 돌려줍니다.
  String? _selectedIdFor(TaxonomyKind kind) {
    switch (kind) {
      case TaxonomyKind.folder:
        return query.folderId;
      case TaxonomyKind.category:
        return query.categoryId;
      case TaxonomyKind.tag:
        return query.tagId;
      case TaxonomyKind.project:
        return query.projectId;

      // 파트는 이 줄에서 다루지 않습니다. 사이드바에서 고릅니다.
      case TaxonomyKind.part:
        return null;
    }
  }

  /// 해당 종류의 필터를 [id]로 바꾼 조건을 만들어 알려줍니다.
  ///
  /// id가 null이면 그 필터를 끕니다. copyWith로는 끌 수 없어서
  /// clearFilter를 거쳐야 합니다.
  void _changeFilter(TaxonomyKind kind, String? id) {
    if (id == null) {
      onQueryChanged(query.clearFilter(kind));
      return;
    }

    switch (kind) {
      case TaxonomyKind.folder:
        onQueryChanged(query.copyWith(folderId: id));
      case TaxonomyKind.category:
        onQueryChanged(query.copyWith(categoryId: id));
      case TaxonomyKind.tag:
        onQueryChanged(query.copyWith(tagId: id));
      case TaxonomyKind.project:
        onQueryChanged(query.copyWith(projectId: id));

      // 파트는 이 줄에서 안 바꿉니다. 사이드바가 맡습니다.
      case TaxonomyKind.part:
        break;
    }
  }

  /// 줄의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Wrap을 쓰면 창이 좁아졌을 때 다음 줄로 넘어갑니다.
          // Row로 만들면 폰처럼 좁은 화면에서 화면 밖으로 삐져나가며 오류가 납니다.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _buildSortMenu(context),
              _buildFavoritesToggle(),
              // 파트는 빼고 나머지 넷만 여기에 둡니다.
              // 파트는 왼쪽 사이드바에서 고르는 더 큰 갈래입니다.
              ...filterableTaxonomyKinds.map(_buildTaxonomyFilter),
              if (query.hasAnyFilter) _buildClearButton(),

              // 목록에 대한 동작들입니다. 조건과 성격이 달라서 오른쪽 끝에 둡니다.
              _buildSelectionButton(),
              _buildManageButton(),
            ],
          ),
        ],
      ),
    );
  }

  /// 정렬 방식을 고르는 메뉴입니다.
  Widget _buildSortMenu(BuildContext context) {
    return MenuAnchor(
      menuChildren: ReferenceSortOrder.values.map((ReferenceSortOrder order) {
        return MenuItemButton(
          onPressed: () => onQueryChanged(query.copyWith(sortOrder: order)),
          leadingIcon: Icon(
            // 지금 고른 것에만 체크 표시를 보여줍니다.
            order == query.sortOrder ? Icons.check : null,
            size: 18,
          ),
          child: Text(order.displayName),
        );
      }).toList(),
      builder: (BuildContext context, MenuController controller, Widget? child) {
        return OutlinedButton.icon(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: const Icon(Icons.sort, size: 18),
          label: Text(query.sortOrder.displayName),
        );
      },
    );
  }

  /// 즐겨찾기만 보기 켜고 끄는 칩입니다.
  Widget _buildFavoritesToggle() {
    return FilterChip(
      avatar: const Icon(Icons.star_outline, size: 18),
      label: const Text('즐겨찾기'),
      selected: query.favoritesOnly,
      onSelected: (bool selected) {
        onQueryChanged(query.copyWith(favoritesOnly: selected));
      },
    );
  }

  /// 폴더·카테고리·태그·프로젝트 필터 메뉴 하나를 만듭니다.
  ///
  /// 네 종류가 생김새와 동작이 같아서 하나로 만들어 돌려씁니다.
  Widget _buildTaxonomyFilter(TaxonomyKind kind) {
    final List<TaxonomyItem> options = taxonomyOptions[kind] ?? <TaxonomyItem>[];

    // 만들어둔 항목이 하나도 없으면 메뉴를 보여주지 않습니다.
    // 눌러도 아무것도 없는 빈 메뉴가 뜨면 사용자가 당황합니다.
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }

    final String? selectedId = _selectedIdFor(kind);
    final bool isFiltering = selectedId != null;

    // 고른 항목의 이름을 버튼에 보여줍니다.
    String label = kind.displayName;
    if (isFiltering) {
      for (final TaxonomyItem item in options) {
        if (item.id == selectedId) {
          label = item.name;
          break;
        }
      }
    }

    return MenuAnchor(
      menuChildren: <Widget>[
        // 첫 항목은 필터 끄기입니다.
        MenuItemButton(
          onPressed: () => _changeFilter(kind, null),
          leadingIcon: Icon(isFiltering ? null : Icons.check, size: 18),
          child: Text('전체 ${kind.displayName}'),
        ),
        ...options.map((TaxonomyItem item) {
          return MenuItemButton(
            onPressed: () => _changeFilter(kind, item.id),
            leadingIcon: Icon(
              item.id == selectedId ? Icons.check : null,
              size: 18,
            ),
            child: Text(item.name),
          );
        }),
      ],
      builder: (BuildContext context, MenuController controller, Widget? child) {
        // 필터가 걸려 있으면 눈에 띄게 채운 버튼으로 보여줍니다.
        // 어떤 조건이 걸려 있는지 한눈에 보이지 않으면
        // "왜 내 사진이 안 보이지?" 하고 헤매게 됩니다.
        void toggle() {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        }

        if (isFiltering) {
          return FilledButton.icon(
            onPressed: toggle,
            icon: const Icon(Icons.filter_alt, size: 18),
            label: Text(label),
          );
        }

        return OutlinedButton.icon(
          onPressed: toggle,
          icon: const Icon(Icons.filter_alt_outlined, size: 18),
          label: Text(label),
        );
      },
    );
  }

  /// 걸린 조건을 한 번에 지우는 버튼입니다.
  ///
  /// 검색어는 여기서 안 지웁니다. 검색창이 위쪽 머리줄로 옮겨가면서
  /// 그 글자를 다루는 일도 화면이 맡게 됐습니다.
  Widget _buildClearButton() {
    return TextButton.icon(
      onPressed: () => onQueryChanged(query.clearAll()),
      icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
      label: const Text('조건 지우기'),
    );
  }

  /// "여러 장 고르기"로 들어가는 버튼입니다.
  Widget _buildSelectionButton() {
    return OutlinedButton.icon(
      onPressed: onToggleSelectionMode,
      icon: const Icon(Icons.check_circle_outline, size: 18),
      label: const Text('고르기'),
    );
  }

  /// 분류 관리 화면을 여는 버튼입니다.
  Widget _buildManageButton() {
    return OutlinedButton.icon(
      onPressed: onOpenTaxonomyManage,
      icon: const Icon(Icons.folder_special_outlined, size: 18),
      label: const Text('분류 관리'),
    );
  }
}

/// 이 줄에서 고를 수 있는 분류 종류들입니다.
///
/// **파트만 빠져 있습니다.** 파트는 디자인/파티클 같은 가장 큰 갈래라
/// 왼쪽 사이드바에서 고릅니다. 여기에도 두면 같은 것을 두 군데서 고르게 되어
/// "어느 쪽이 진짜지?" 하게 됩니다.
final List<TaxonomyKind> filterableTaxonomyKinds = TaxonomyKind.values
    .where((TaxonomyKind kind) => kind != TaxonomyKind.part)
    .toList();
