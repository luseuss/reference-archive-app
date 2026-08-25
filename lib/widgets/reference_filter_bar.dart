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
    required this.searchController,
    required this.taxonomyOptions,
    required this.onQueryChanged,
  });

  /// 지금 걸려 있는 조건입니다.
  final ReferenceQuery query;

  /// 검색 입력창을 다루는 도구입니다.
  ///
  /// 이 위젯이 직접 만들지 않고 화면에서 받아옵니다.
  /// 목록을 다시 그릴 때마다 새로 만들면 입력하던 글자가 사라지기 때문입니다.
  final TextEditingController searchController;

  /// 고를 수 있는 분류 항목들입니다. (종류별로 나눠 담겨 있습니다)
  final Map<TaxonomyKind, List<TaxonomyItem>> taxonomyOptions;

  /// 조건이 바뀌었을 때 바뀐 조건 전체를 알려줍니다.
  final ValueChanged<ReferenceQuery> onQueryChanged;

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
          _buildSearchField(),
          const SizedBox(height: 12),

          // Wrap을 쓰면 창이 좁아졌을 때 다음 줄로 넘어갑니다.
          // Row로 만들면 폰처럼 좁은 화면에서 화면 밖으로 삐져나가며 오류가 납니다.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _buildSortMenu(context),
              _buildFavoritesToggle(),
              ...TaxonomyKind.values.map(_buildTaxonomyFilter),
              if (query.hasAnyFilter) _buildClearButton(),
            ],
          ),
        ],
      ),
    );
  }

  /// 검색 입력창입니다.
  Widget _buildSearchField() {
    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: '제목이나 메모에서 찾기',
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        isDense: true,

        // 글자를 입력했을 때만 지우기 버튼을 보여줍니다.
        suffixIcon: query.searchText.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                tooltip: '검색어 지우기',
                onPressed: () {
                  searchController.clear();
                  onQueryChanged(query.copyWith(searchText: ''));
                },
              ),
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
  Widget _buildClearButton() {
    return TextButton.icon(
      onPressed: () {
        searchController.clear();
        onQueryChanged(query.clearAll());
      },
      icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
      label: const Text('조건 지우기'),
    );
  }
}
