// 폴더·카테고리·태그·프로젝트를 관리하는 화면입니다.
//
// 하는 일:
//   - 종류별로 만들어둔 항목 목록 보기 (각 항목을 몇 개의 레퍼런스가 쓰는지 함께)
//   - 이름 바꾸기
//   - 삭제 (쓰는 레퍼런스가 있으면 몇 개인지 알려주고 확인받음)
//   - 새로 만들기
//
// ── 왜 삭제할 때 확인을 받나 ──
// 분류 항목을 지우면 그걸 쓰던 레퍼런스에서 조용히 연결이 끊깁니다.
// 레퍼런스 자체는 살아있지만, "인물" 폴더에 있던 사진 50장이 폴더 없음이 되고
// **되돌릴 방법이 없습니다.** 그래서 지우기 전에 몇 개가 영향을 받는지
// 반드시 보여주고 확인을 받습니다.
//
// ── 파트만 두 가지가 다릅니다 ──
//   1. 파트를 지우면 그 안의 레퍼런스는 **기본 파트로 옮겨집니다.** 연결이
//      끊기는 것이 아니라 자리를 옮기는 것이라, 안내 문구도 다릅니다.
//   2. **기본 파트는 지울 수 없습니다.** 지우기 버튼이 잠겨 있습니다.
//      (왜인지는 repositories/taxonomy_repository.dart의 delete 설명 참고)

import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/taxonomy_item.dart';
import '../repositories/taxonomy_repository.dart';
import '../utils/korean_particle.dart';
import '../widgets/create_taxonomy_dialog.dart';
import '../widgets/rename_taxonomy_dialog.dart';

/// 분류 항목 관리 화면입니다.
class TaxonomyManageScreen extends StatefulWidget {
  const TaxonomyManageScreen({super.key, required this.repository});

  final TaxonomyRepository repository;

  @override
  State<TaxonomyManageScreen> createState() => _TaxonomyManageScreenState();
}

class _TaxonomyManageScreenState extends State<TaxonomyManageScreen>
    with SingleTickerProviderStateMixin {
  /// 위쪽 탭(폴더/카테고리/태그/프로젝트)을 다루는 도구입니다.
  late final TabController _tabController;

  /// 종류별 항목 목록입니다.
  Map<TaxonomyKind, List<TaxonomyItem>> _itemsByKind =
      <TaxonomyKind, List<TaxonomyItem>>{};

  /// 각 항목을 쓰는 레퍼런스 개수입니다. (항목 id → 개수)
  Map<String, int> _usageCounts = <String, int>{};

  /// 목록을 불러오는 중인지 여부입니다.
  bool _isLoading = true;

  /// 무언가 바뀌었는지 기록합니다.
  ///
  /// 화면을 닫을 때 이 값을 돌려주면, 목록 화면이 "다시 불러와야겠다"를 압니다.
  /// 아무것도 안 고치고 그냥 나왔으면 다시 불러올 필요가 없습니다.
  bool _hasChanges = false;

  /// 화면이 처음 만들어질 때 딱 한 번 실행됩니다.
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: TaxonomyKind.values.length, vsync: this);
    _loadAll();
  }

  /// 화면이 사라질 때 탭 도구를 정리합니다.
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 모든 종류의 항목과 사용 개수를 불러옵니다.
  Future<void> _loadAll() async {
    final Map<TaxonomyKind, List<TaxonomyItem>> loaded =
        <TaxonomyKind, List<TaxonomyItem>>{};
    final Map<String, int> counts = <String, int>{};

    for (final TaxonomyKind kind in TaxonomyKind.values) {
      final List<TaxonomyItem> items = await widget.repository.getAll(kind);
      loaded[kind] = items;

      for (final TaxonomyItem item in items) {
        counts[item.id] = await widget.repository.countReferencesUsing(item.id);
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _itemsByKind = loaded;
      _usageCounts = counts;
      _isLoading = false;
    });
  }

  /// 새 항목을 만듭니다.
  Future<void> _createItem(TaxonomyKind kind) async {
    final TaxonomyItem? created = await showCreateTaxonomyDialog(
      context: context,
      kind: kind,
      repository: widget.repository,
    );

    if (created != null) {
      _hasChanges = true;
      await _loadAll();
    }
  }

  /// 항목의 이름을 바꿉니다.
  Future<void> _renameItem(TaxonomyItem item) async {
    final bool renamed = await showRenameTaxonomyDialog(
      context: context,
      item: item,
      repository: widget.repository,
    );

    if (renamed) {
      _hasChanges = true;
      await _loadAll();
    }
  }

  /// 항목을 지웁니다. 쓰는 레퍼런스가 있으면 몇 개인지 알려주고 확인받습니다.
  Future<void> _deleteItem(TaxonomyItem item) async {
    final int usageCount = _usageCounts[item.id] ?? 0;
    final bool confirmed = await _confirmDelete(item, usageCount);

    if (!confirmed) {
      return;
    }

    await widget.repository.delete(item.id);
    _hasChanges = true;
    await _loadAll();
  }

  /// 정말 지울지 확인받는 대화상자를 띄웁니다.
  Future<bool> _confirmDelete(TaxonomyItem item, int usageCount) async {
    final String kindName = item.kind.displayName;

    // 쓰는 곳이 있는지에 따라 안내 문구를 다르게 합니다.
    // "0개가 영향을 받습니다"는 읽는 사람을 불필요하게 긴장시킵니다.
    final String message;
    if (usageCount == 0) {
      message = '"${item.name}" ${withObjectParticle(kindName)} 지웁니다.\n'
          '이 ${withObjectParticle(kindName)} 쓰는 레퍼런스는 없습니다.';
    } else if (item.kind == TaxonomyKind.part) {
      // 파트는 연결이 끊기는 것이 아니라 **자리를 옮기는** 것입니다.
      // 다른 분류와 같은 문구를 쓰면 사진이 어디론가 사라지는 줄 알고
      // 못 지웁니다. 어디로 가는지 정확히 적어줍니다.
      message = '"${item.name}" 파트를 지웁니다.\n\n'
          '이 파트에 있는 레퍼런스 $usageCount개는 '
          '"$defaultPartName" 파트로 옮겨집니다.\n'
          '사진이 지워지지는 않습니다.';
    } else {
      message = '"${item.name}" ${withObjectParticle(kindName)} 지웁니다.\n\n'
          '이 ${withObjectParticle(kindName)} 쓰는 레퍼런스가 $usageCount개 있습니다.\n'
          '레퍼런스 자체는 지워지지 않지만, 그 $kindName 연결이 사라지며 '
          '되돌릴 수 없습니다.';
    }

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$kindName 삭제'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    // 대화상자를 바깥을 눌러 닫으면 null이 옵니다. 그때는 안 지웁니다.
    return result ?? false;
  }

  /// 화면의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    // PopScope로 감싸면 뒤로 갈 때 바뀐 게 있었는지 알려줄 수 있습니다.
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, bool? result) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(_hasChanges);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('분류 관리'),
          bottom: TabBar(
            controller: _tabController,
            tabs: TaxonomyKind.values.map((TaxonomyKind kind) {
              return Tab(text: kind.displayName);
            }).toList(),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: TaxonomyKind.values.map(_buildList).toList(),
              ),
        floatingActionButton: _isLoading
            ? null
            : FloatingActionButton.extended(
                onPressed: () {
                  // 지금 보고 있는 탭의 종류로 만듭니다.
                  _createItem(TaxonomyKind.values[_tabController.index]);
                },
                icon: const Icon(Icons.add),
                label: const Text('새로 만들기'),
              ),
      ),
    );
  }

  /// 한 종류의 항목 목록을 만듭니다.
  Widget _buildList(TaxonomyKind kind) {
    final List<TaxonomyItem> items = _itemsByKind[kind] ?? <TaxonomyItem>[];

    if (items.isEmpty) {
      return _buildEmptyState(kind);
    }

    return ListView.builder(
      // 아래쪽 여백은 떠 있는 버튼에 마지막 항목이 가리지 않게 하려는 것입니다.
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final TaxonomyItem item = items[index];
        final int usageCount = _usageCounts[item.id] ?? 0;

        // 기본 파트는 지울 수 없습니다. 다른 파트를 지울 때 레퍼런스가
        // 옮겨갈 자리이고, 새로 넣는 레퍼런스도 여기로 들어갑니다.
        final bool isDefaultPart = item.id == defaultPartId;

        return ListTile(
          title: Text(item.name),
          subtitle: Text(
            usageCount == 0 ? '쓰는 레퍼런스 없음' : '레퍼런스 $usageCount개에서 사용 중',
          ),
          trailing: Row(
            // Row는 기본으로 가로를 다 차지합니다. mainAxisSize.min을 줘야
            // 버튼 두 개 크기만큼만 차지합니다.
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // 이름은 기본 파트도 바꿀 수 있습니다. 번호가 그대로라
              // 레퍼런스 연결이 끊기지 않습니다.
              IconButton(
                onPressed: () => _renameItem(item),
                icon: const Icon(Icons.edit_outlined),
                tooltip: '이름 바꾸기',
              ),

              // onPressed에 null을 넣으면 버튼이 흐려지고 눌리지 않습니다.
              // 버튼을 아예 없애지 않는 이유: 줄마다 버튼 개수가 달라지면
              // 목록이 들쭉날쭉해 보이고, "왜 이것만 없지?" 하게 됩니다.
              // 흐린 버튼에 이유를 적어두는 편이 친절합니다.
              IconButton(
                onPressed: isDefaultPart ? null : () => _deleteItem(item),
                icon: const Icon(Icons.delete_outline),
                tooltip: isDefaultPart
                    ? '$defaultPartName 파트는 지울 수 없습니다 '
                          '(다른 파트를 지울 때 레퍼런스가 옮겨오는 자리입니다)'
                    : '삭제',
              ),
            ],
          ),
        );
      },
    );
  }

  /// 만들어둔 항목이 없을 때 보여줄 안내입니다.
  Widget _buildEmptyState(TaxonomyKind kind) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textStyles = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.label_outline, size: 48, color: colors.primary),
            const SizedBox(height: 16),
            Text(
              '만들어둔 ${withSubjectParticle(kind.displayName)} 없습니다',
              style: textStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '아래 버튼으로 만들거나, 레퍼런스 편집 화면에서도 만들 수 있습니다.',
              style: textStyles.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
