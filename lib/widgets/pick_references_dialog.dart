// 무드보드 판에 올릴 레퍼런스를 고르는 대화상자입니다.
//
// 여러 장을 한 번에 고를 수 있습니다. 무드보드는 보통 "이 열 장을 늘어놓고 보자"로
// 시작하지, 한 장씩 올리는 일은 드물기 때문입니다.
//
// 고른 레퍼런스의 번호 목록을 돌려줍니다. 취소하면 null입니다.
// **판에 올리는 일은 여기서 하지 않습니다.** 그건 화면(board_screen.dart)이 합니다.
// 대화상자는 "무엇을 골랐는가"만 알려주고 끝내는 편이 나중에 고치기 쉽습니다.

import 'dart:io';

import 'package:flutter/material.dart';

import '../models/reference_item.dart';
import '../repositories/reference_repository.dart';
import '../services/image_storage.dart';
import '../services/reference_lookup.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text.dart';

/// 판에 올릴 레퍼런스를 고르는 대화상자를 띄웁니다.
///
/// [alreadyOnBoard]에 이미 판에 올라가 있는 레퍼런스 번호를 넘기면 표시해줍니다.
/// 같은 것을 또 올리는 것 자체는 막지 않습니다 — 같은 사진을 좌우에 나란히 두고
/// 비교하는 식으로 쓸 수 있기 때문입니다. 다만 모르고 두 번 올리는 일은 줄여줍니다.
Future<List<String>?> showPickReferencesDialog({
  required BuildContext context,
  required ReferenceRepository repository,
  required ImageStorage imageStorage,
  Set<String> alreadyOnBoard = const <String>{},
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (BuildContext context) {
      return _PickReferencesDialog(
        repository: repository,
        imageStorage: imageStorage,
        alreadyOnBoard: alreadyOnBoard,
      );
    },
  );
}

/// 레퍼런스를 여러 장 고르는 대화상자입니다.
class _PickReferencesDialog extends StatefulWidget {
  const _PickReferencesDialog({
    required this.repository,
    required this.imageStorage,
    required this.alreadyOnBoard,
  });

  final ReferenceRepository repository;
  final ImageStorage imageStorage;
  final Set<String> alreadyOnBoard;

  @override
  State<_PickReferencesDialog> createState() => _PickReferencesDialogState();
}

class _PickReferencesDialogState extends State<_PickReferencesDialog> {
  /// 고를 수 있는 레퍼런스와 그 그림 경로입니다.
  ///
  /// 무드보드 판(board_screen.dart)도 같은 것을 씁니다.
  /// (services/reference_lookup.dart 설명 참고)
  ReferenceLookup _lookup = const ReferenceLookup.empty();

  /// 지금까지 고른 레퍼런스의 번호들입니다.
  ///
  /// ── List가 아니라 Set인 이유 ──
  /// Set은 같은 값이 두 번 들어가지 않고, "들어있는지" 확인이 빠릅니다.
  /// 칸을 그릴 때마다 "이건 골라졌나?"를 묻는데, List로 하면 매번 처음부터
  /// 훑어야 해서 레퍼런스가 많아질수록 느려집니다.
  final Set<String> _selectedIds = <String>{};

  /// 아직 목록을 읽어오는 중인지 여부입니다.
  bool _isLoading = true;

  /// 검색어입니다. 제목으로 걸러 보여줍니다.
  String _searchText = '';

  /// 입력창의 글자를 읽고 관리하는 도구입니다.
  final TextEditingController _searchController = TextEditingController();

  /// 대화상자가 만들어질 때 레퍼런스 목록을 읽어옵니다.
  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  /// 화면이 사라질 때 입력창 도구를 정리합니다.
  /// 만들었으면 반드시 dispose 해야 메모리에 남지 않습니다.
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 레퍼런스 목록과 그림 경로를 읽어옵니다.
  Future<void> _loadItems() async {
    final ReferenceLookup lookup = await ReferenceLookup.load(
      repository: widget.repository,
      imageStorage: widget.imageStorage,
    );

    // 기다리는 사이에 사용자가 대화상자를 닫았을 수 있습니다.
    // 그때 setState를 부르면 "없는 화면을 고치려 한다"며 오류가 납니다.
    if (!mounted) {
      return;
    }

    setState(() {
      _lookup = lookup;
      _isLoading = false;
    });
  }

  /// 검색어에 걸리는 레퍼런스만 골라 돌려줍니다.
  ///
  /// ── 데이터베이스에 다시 묻지 않고 여기서 거르는 이유 ──
  /// 이 대화상자는 그림을 보여주려고 **이미 전부 읽어와 손에 들고 있습니다.**
  /// 그 상태에서 다시 묻는 것은 같은 일을 두 번 하는 셈입니다.
  /// (목록 화면은 다릅니다. 거기는 수천 장이 될 수 있어서 데이터베이스가 거릅니다.)
  ///
  /// 언젠가 레퍼런스가 수천 장이 되어 이 대화상자가 느려지면, 그때는 여기서도
  /// repository.search()로 바꿔야 합니다.
  List<ReferenceItem> _visibleItems() {
    final String keyword = _searchText.trim().toLowerCase();
    if (keyword.isEmpty) {
      return _lookup.items;
    }

    return _lookup.items
        .where(
          (ReferenceItem item) => item.title.toLowerCase().contains(keyword),
        )
        .toList();
  }

  /// 칸을 눌렀을 때 고르거나 고르기를 취소합니다.
  void _toggle(ReferenceItem item) {
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        _selectedIds.add(item.id);
      }
    });
  }

  /// 대화상자의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('판에 올릴 레퍼런스 고르기'),

      // 대화상자 안의 목록은 크기를 정해줘야 합니다. 안 정하면 "얼마나 커야
      // 하는지 모르겠다"며 오류가 납니다.
      content: SizedBox(width: 560, height: 420, child: _buildContent()),

      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          // 하나도 안 골랐으면 누를 수 없게 잠급니다.
          // 눌렀는데 아무 일도 안 일어나면 고장난 줄 알게 됩니다.
          onPressed: _selectedIds.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selectedIds.toList()),
          child: Text(
            _selectedIds.isEmpty ? '올리기' : '${_selectedIds.length}장 올리기',
          ),
        ),
      ],
    );
  }

  /// 대화상자 안쪽을 만듭니다. 상황에 따라 셋 중 하나입니다.
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_lookup.items.isEmpty) {
      return const Center(
        child: Text(
          '아직 모아둔 레퍼런스가 없습니다.\n먼저 목록에서 이미지를 추가해주세요.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final List<ReferenceItem> visible = _visibleItems();

    return Column(
      children: <Widget>[
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: '제목으로 찾기',
            isDense: true,
          ),
          onChanged: (String value) => setState(() => _searchText = value),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: visible.isEmpty
              ? const Center(child: Text('검색어에 맞는 레퍼런스가 없습니다.'))
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 140,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,

                    // 그림 아래 제목 한 줄이 들어갈 만큼 세로로 길게 잡습니다.
                    childAspectRatio: 0.82,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (BuildContext context, int index) {
                    return _buildTile(visible[index]);
                  },
                ),
        ),
      ],
    );
  }

  /// 고를 수 있는 레퍼런스 한 칸을 만듭니다.
  Widget _buildTile(ReferenceItem item) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    final bool isSelected = _selectedIds.contains(item.id);
    final bool isOnBoard = widget.alreadyOnBoard.contains(item.id);

    return InkWell(
      onTap: () => _toggle(item),
      borderRadius: BorderRadius.circular(inputCornerRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(inputCornerRadius),
                border: Border.all(
                  color: isSelected ? colors.primary : colors.outlineVariant,
                  width: isSelected ? 3 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _buildThumbnail(item, colors),

                  // 이미 판에 올라가 있는 것은 왼쪽 위에 표시해둡니다.
                  if (isOnBoard)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(tagCornerRadius),
                        ),
                        child: Text(
                          '올림',
                          style: AppText.meta.copyWith(color: colors.primary),
                        ),
                      ),
                    ),

                  if (isSelected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(
                        Icons.check_circle,
                        color: colors.primary,
                        size: 22,

                        // 밝은 사진 위에서도 보이게 그림자를 줍니다.
                        shadows: const <Shadow>[
                          Shadow(color: Colors.black45, blurRadius: 6),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.title.isEmpty ? '(제목 없음)' : item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.meta.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// 한 칸의 그림입니다. 여기서는 칸에 꽉 채워 보여줍니다.
  ///
  /// 목록이나 무드보드와 달리 **잘라서 채웁니다(cover).** 고르는 화면이라
  /// 칸 크기가 들쭉날쭉하면 훑어보기 어렵기 때문입니다. 구도를 봐야 하는
  /// 무드보드 판에서는 반대로 원본 비율을 지킵니다.
  Widget _buildThumbnail(ReferenceItem item, ColorScheme colors) {
    final String? path = _lookup.imagePaths[item.id];

    if (path == null) {
      return Container(
        color: colors.surfaceContainerHighest,
        child: Icon(Icons.image_outlined, color: colors.onSurfaceVariant),
      );
    }

    return Image.file(
      File(path),
      fit: BoxFit.cover,

      // 파일이 지워졌거나 깨졌을 때 대화상자 전체가 오류 화면이 되지 않게 막습니다.
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        return Container(
          color: colors.surfaceContainerHighest,
          child: Icon(
            Icons.broken_image_outlined,
            color: colors.onSurfaceVariant,
          ),
        );
      },
    );
  }
}
