// 화면 왼쪽에 붙는 사이드바입니다.
//
// 의뢰인이 정해준 목업의 ①②③에 해당합니다.
//
//   ① 위   — 사용자 (지금은 이름만. 로그인 기능은 아직 없습니다)
//   ② 가운데 — 폴더 목록 (이 프로젝트의 레퍼런스 묶음으로 나눠 보기)
//   ③ 아래  — 설정 · 로그인/로그아웃
//
// ── 여기 있던 "파트"는 없앴습니다 (2026-09-06) ──
// 원래 ②는 "파트"(디자인/파티클 같은 큰 갈래) 목록이었습니다. 그런데
// References 테이블에는 폴더도 이미 있었고, 폴더와 파트가 하는 일이
// 실제로는 겹쳤습니다(의뢰인이 직접 지적한 부분 — CLAUDE.md
// "단계 밖 작업: 파트를 없애고 사이드바를 폴더로 바꾸기" 참고). 그래서
// 이 자리를 폴더 목록으로 바꾸고 파트는 앱에서 완전히 지웠습니다.
//
// ── 폴더가 하위 폴더를 가질 수 있습니다 (2026-09-11) ──
// ②가 평평한 목록이 아니라 트리입니다. 들여쓰기 + 펼치기/접기 화살표로
// 구조를 보여주고, 폴더 줄의 메뉴(⋮)로 하위 폴더 만들기/이름 바꾸기/
// 삭제를 하고, 드래그로 다른 폴더 위에 놓으면 그 하위로 옮겨집니다.
// 그래서 이 위젯은 StatefulWidget입니다(펼침 상태를 기억해야 해서).
//
// ── 색이 본문과 다릅니다 ──
// 목업에서 사이드바만 짙은 색입니다. 본문은 밝은데 사이드바는 어둡게 두면
// "여기는 성격이 다른 영역"이라는 것이 한눈에 보입니다.
// 그래서 밝은 모드에서도 사이드바는 어두운 색을 씁니다.
//
// ── 블록마다 있던 테두리 상자를 없앴습니다 (2026-09-11 "라이트테이블") ──
// 전에는 ①②③ 블록마다 각각 테두리 있는 둥근 상자로 감쌌습니다. 이러면
// "똑같이 둥근 상자를 계속 쌓아올린" 모양이 되어 사이드바 자체가
// 시끄러워집니다. 지금은 상자를 걷어내고 얇은 구분선(_buildDivider)과
// 여백만으로 블록을 나눕니다 — 본문의 사진 격자가 조용한 배경 위에서
// 도드라지게 하려는 것과 같은 방향입니다.

import 'package:flutter/material.dart';

import '../models/taxonomy_item.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';
import '../utils/folder_tree.dart';

/// 사이드바의 너비입니다. (기존 웹앱의 `flex: 0 0 176px`보다 조금 넓게)
const double sidebarWidth = 232;

/// 사이드바를 항상 펼쳐둘 최소 창 너비입니다.
///
/// 이보다 좁으면 사이드바가 목록을 너무 많이 잡아먹습니다. 그래서 폰이나
/// 좁은 창에서는 평소엔 숨겨두고 메뉴 버튼으로 꺼내 씁니다.
const double sidebarBreakpoint = 900;

/// 화면 왼쪽 사이드바입니다.
class AppSidebar extends StatefulWidget {
  const AppSidebar({
    super.key,
    required this.userName,
    required this.folders,
    required this.selectedFolderId,
    required this.onSelectFolder,
    required this.onCreateSubfolder,
    required this.onRenameFolder,
    required this.onDeleteFolder,
    required this.onMoveFolder,
    required this.onOpenBoards,
    required this.onOpenTrash,
    required this.onOpenSettings,
    required this.onLogInOut,
  });

  /// ①에 보여줄 사용자 이름입니다.
  final String userName;

  /// ②에 보여줄 폴더 목록입니다.
  final List<TaxonomyItem> folders;

  /// 지금 고른 폴더의 id입니다. null이면 "전체"를 보고 있는 것입니다.
  final String? selectedFolderId;

  /// 폴더를 골랐을 때 알려줍니다. null을 넘기면 "전체"입니다.
  final ValueChanged<String?> onSelectFolder;

  /// "하위 폴더 만들기"를 눌렀을 때 실행합니다. 어느 폴더 밑에 만들지 알려줍니다.
  final ValueChanged<TaxonomyItem> onCreateSubfolder;

  /// "이름 바꾸기"를 눌렀을 때 실행합니다.
  final ValueChanged<TaxonomyItem> onRenameFolder;

  /// "삭제"를 눌렀을 때 실행합니다.
  final ValueChanged<TaxonomyItem> onDeleteFolder;

  /// 폴더를 드래그해서 다른 폴더(또는 "전체 레퍼런스"/빈 자리) 위에
  /// 놓았을 때 실행합니다. newParentId가 null이면 최상위로 옮기라는
  /// 뜻입니다.
  final void Function(String draggedFolderId, String? newParentId) onMoveFolder;

  /// 무드보드 목록을 눌렀을 때 실행할 동작입니다.
  final VoidCallback onOpenBoards;

  /// 휴지통을 눌렀을 때 실행할 동작입니다.
  final VoidCallback onOpenTrash;

  /// 설정을 눌렀을 때 실행할 동작입니다.
  final VoidCallback onOpenSettings;

  /// 로그인/로그아웃을 눌렀을 때 실행할 동작입니다.
  final VoidCallback onLogInOut;

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  /// 지금 펼쳐진 폴더의 id들입니다. 화면을 나가면(위젯이 다시 만들어지면)
  /// 초기화됩니다 — 이번 범위에서는 영구 저장하지 않습니다. 기본은
  /// "전부 펼침"입니다 — 갑자기 하위 폴더가 안 보이면 사용자가 당황하기
  /// 때문에, 접는 것은 사용자가 직접 고르게 합니다.
  final Set<String> _expandedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _expandedIds.addAll(widget.folders.map((TaxonomyItem f) => f.id));
  }

  /// 새로 생긴 폴더도 기본으로 펼쳐둡니다.
  @override
  void didUpdateWidget(covariant AppSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Set<String> oldIds =
        oldWidget.folders.map((TaxonomyItem f) => f.id).toSet();
    for (final TaxonomyItem folder in widget.folders) {
      if (!oldIds.contains(folder.id)) {
        _expandedIds.add(folder.id);
      }
    }
  }

  /// 폴더 하나의 펼침 상태를 뒤집습니다.
  void _toggleExpanded(String folderId) {
    setState(() {
      if (!_expandedIds.remove(folderId)) {
        _expandedIds.add(folderId);
      }
    });
  }

  /// 사이드바의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    // 사이드바는 밝은 모드에서도 어두운 색을 씁니다.
    // 그래서 지금 모드와 상관없이 어두운 모드 색을 가져다 씁니다.
    const AppPalette dark = AppPalette.dark;

    return Container(
      width: sidebarWidth,
      color: dark.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildUserBlock(dark),

              _buildDivider(dark),

              // 무드보드로 가는 길입니다. 폴더 목록 위에 따로 둡니다.
              //
              // ── 왜 폴더 목록 안에 넣지 않았나 ──
              // 폴더는 "레퍼런스를 어떻게 나눠 볼까"이고, 무드보드는 "레퍼런스로
              // 무엇을 할까"입니다. 성격이 달라서 같은 목록에 섞으면 폴더 중
              // 하나처럼 보입니다. 구분선으로 나눠 두면 다른 종류라는 것이 드러납니다.
              _buildBoardsBlock(dark),

              _buildDivider(dark),

              _buildSectionLabel(dark, '폴더'),

              // ② 폴더 목록입니다. Expanded로 감싸 남는 공간을 다 차지하게 하면,
              // ③(설정)이 언제나 맨 아래에 붙습니다.
              Expanded(child: _buildFolderList(dark)),

              _buildDivider(dark),
              _buildBottomBlock(dark),
            ],
          ),
        ),
      ),
    );
  }

  /// 블록 사이를 나누는 얇은 구분선입니다. 테두리 상자 대신 씁니다.
  Widget _buildDivider(AppPalette dark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(height: 1, thickness: 1, color: dark.border),
    );
  }

  /// "폴더"처럼 구역 앞에 붙는 작은 이름표입니다.
  Widget _buildSectionLabel(AppPalette dark, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(label, style: AppText.sectionLabel.copyWith(color: dark.textDim)),
    );
  }

  /// ① 사용자 부분입니다.
  Widget _buildUserBlock(AppPalette dark) {
    return Row(
      children: <Widget>[
        // 사진이 없으므로 이름 첫 글자로 대신합니다.
        CircleAvatar(
          radius: 18,
          backgroundColor: dark.accentSoft,
          child: Text(
            _initial(),
            style: TextStyle(color: dark.accent, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: dark.text, fontWeight: FontWeight.w700),
              ),
              Text(
                // 로그인 기능이 없다는 것을 숨기지 않고 그대로 적습니다.
                // 가짜 계정 아이디를 지어내면 나중에 진짜 로그인을 붙일 때
                // 사용자가 혼란스러워집니다.
                '로그인 안 함',
                style: AppText.meta.copyWith(color: dark.textDim),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 무드보드로 가는 줄입니다.
  Widget _buildBoardsBlock(AppPalette dark) {
    return _buildNavItem(
      dark,
      icon: Icons.dashboard_outlined,
      label: '무드보드',

      // 고른 상태로 표시하지 않습니다. 여기는 "머무는 자리"가 아니라
      // 다른 화면으로 가는 문이라, 켜져 있으면 지금 그 화면인 줄 오해합니다.
      isSelected: false,
      onTap: widget.onOpenBoards,
    );
  }

  /// ② 폴더 목록입니다. 이 프로젝트의 레퍼런스 묶음으로 나눠 봅니다.
  /// 트리(들여쓰기 + 펼치기/접기)로 보여줍니다.
  ///
  /// 맨 위의 "전체 레퍼런스"는 폴더를 안 가리는 상태입니다. 폴더가 여럿일 때
  /// 전부 훑어보려면 이게 필요합니다.
  Widget _buildFolderList(AppPalette dark) {
    final List<FolderTreeEntry> tree = buildFolderTree(widget.folders);
    final List<FolderTreeEntry> visible = _visibleEntries(tree);

    // 폴더가 많아지면 사이드바 밖으로 넘칩니다. 스크롤되게 둡니다.
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        _buildAllReferencesRow(dark),
        for (final FolderTreeEntry entry in visible)
          _buildFolderRow(dark, entry, tree),
      ],
    );
  }

  /// [tree]에서, 접힌 폴더의 하위는 뺀 "지금 눈에 보여야 할" 목록을 돌려줍니다.
  List<FolderTreeEntry> _visibleEntries(List<FolderTreeEntry> tree) {
    final List<FolderTreeEntry> visible = <FolderTreeEntry>[];
    int? hiddenBelowDepth;

    for (final FolderTreeEntry entry in tree) {
      if (hiddenBelowDepth != null) {
        if (entry.depth > hiddenBelowDepth) {
          continue;
        }
        hiddenBelowDepth = null;
      }

      visible.add(entry);

      final bool hasChildren =
          tree.any((FolderTreeEntry e) => e.folder.parentId == entry.folder.id);
      if (hasChildren && !_expandedIds.contains(entry.folder.id)) {
        hiddenBelowDepth = entry.depth;
      }
    }
    return visible;
  }

  /// "전체 레퍼런스" 줄입니다. 폴더를 여기로 끌어다 놓으면 최상위로 옮겨집니다.
  Widget _buildAllReferencesRow(AppPalette dark) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (DragTargetDetails<String> details) => true,
      onAcceptWithDetails: (DragTargetDetails<String> details) =>
          widget.onMoveFolder(details.data, null),
      builder: (
        BuildContext context,
        List<String?> candidateData,
        List<Object?> rejectedData,
      ) {
        return _buildNavItem(
          dark,
          icon: Icons.photo_library_outlined,
          label: '전체 레퍼런스',
          isSelected: widget.selectedFolderId == null,
          onTap: () => widget.onSelectFolder(null),
        );
      },
    );
  }

  /// 폴더 하나의 줄입니다. 들여쓰기, 펼치기/접기 화살표(자식이 있을 때만),
  /// 메뉴(⋮), 드래그로 옮기기를 담당합니다.
  Widget _buildFolderRow(
    AppPalette dark,
    FolderTreeEntry entry,
    List<FolderTreeEntry> tree,
  ) {
    final TaxonomyItem folder = entry.folder;
    final bool hasChildren =
        tree.any((FolderTreeEntry e) => e.folder.parentId == folder.id);
    final bool isExpanded = _expandedIds.contains(folder.id);

    // 이름 부분만 드래그로 잡을 수 있게 합니다. 메뉴 버튼까지 드래그
    // 대상으로 감싸면 메뉴를 누르려는 손짓과 드래그 손짓이 부딪힙니다.
    final Widget navItem = _buildNavItem(
      dark,
      icon: Icons.folder_copy_outlined,
      label: folder.name,
      isSelected: widget.selectedFolderId == folder.id,
      onTap: () => widget.onSelectFolder(folder.id),
    );

    final Widget draggableLabel = Draggable<String>(
      data: folder.id,
      feedback: Material(
        color: Colors.transparent,
        child: Chip(label: Text(folder.name)),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: navItem),
      child: navItem,
    );

    final Widget row = Padding(
      padding: EdgeInsets.only(left: entry.depth * 16.0),
      child: Row(
        children: <Widget>[
          // 자식이 있으면 펼치기/접기 화살표, 없으면 그만큼 빈 자리.
          SizedBox(
            width: 24,
            child: hasChildren
                ? IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    color: dark.textDim,
                    icon: Icon(isExpanded ? Icons.expand_more : Icons.chevron_right),
                    onPressed: () => _toggleExpanded(folder.id),
                  )
                : null,
          ),
          Expanded(child: draggableLabel),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 18, color: dark.textDim),
            onSelected: (String value) {
              if (value == 'subfolder') {
                widget.onCreateSubfolder(folder);
              } else if (value == 'rename') {
                widget.onRenameFolder(folder);
              } else if (value == 'delete') {
                widget.onDeleteFolder(folder);
              }
            },
            itemBuilder: (BuildContext context) {
              return const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(value: 'subfolder', child: Text('하위 폴더 만들기')),
                PopupMenuItem<String>(value: 'rename', child: Text('이름 바꾸기')),
                PopupMenuItem<String>(value: 'delete', child: Text('삭제')),
              ];
            },
          ),
        ],
      ),
    );

    return DragTarget<String>(
      // 자기 자신 위로는 못 옮깁니다. 자기 하위로 옮기는 순환은 여기서
      // 안 막고 저장소(moveFolder)가 막습니다 — 드래그하는 시점에는
      // "자기 하위가 누구인지" 매번 계산하기보다, 실제로 놓았을 때
      // home_screen.dart의 onMoveFolder가 예외를 받아 안내합니다.
      onWillAcceptWithDetails: (DragTargetDetails<String> details) =>
          details.data != folder.id,
      onAcceptWithDetails: (DragTargetDetails<String> details) =>
          widget.onMoveFolder(details.data, folder.id),
      builder: (
        BuildContext context,
        List<String?> candidateData,
        List<Object?> rejectedData,
      ) {
        final bool isHovering = candidateData.isNotEmpty;
        return Container(
          decoration: isHovering
              ? BoxDecoration(
                  border: Border.all(color: dark.accent),
                  borderRadius: BorderRadius.circular(inputCornerRadius),
                )
              : null,
          child: row,
        );
      },
    );
  }

  /// ③ 아래쪽 설정·로그인 부분입니다.
  Widget _buildBottomBlock(AppPalette dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 휴지통은 폴더 목록(②)이 아니라 여기 둡니다. 폴더는 "레퍼런스를
        // 어떻게 나눠 볼까"인데, 휴지통은 설정처럼 가끔 들르는 도구라
        // 성격이 다릅니다.
        _buildNavItem(
          dark,
          icon: Icons.delete_outline,
          label: '휴지통',
          isSelected: false,
          onTap: widget.onOpenTrash,
        ),
        _buildNavItem(
          dark,
          icon: Icons.settings_outlined,
          label: '설정',
          isSelected: false,
          onTap: widget.onOpenSettings,
        ),
        _buildNavItem(
          dark,
          icon: Icons.login_outlined,
          label: '로그인',
          isSelected: false,
          onTap: widget.onLogInOut,
        ),
      ],
    );
  }

  /// 사이드바 안의 누를 수 있는 줄 하나를 만듭니다.
  ///
  /// ②와 ③이 같은 모양이라 하나로 만들어 돌려씁니다.
  Widget _buildNavItem(
    AppPalette dark, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // 고른 항목은 배경을 밝게 깔아 구분합니다.
    final Color foreground = isSelected ? dark.accent : dark.textDim;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(inputCornerRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? dark.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(inputCornerRadius),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.folderChip.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 이름의 첫 글자를 돌려줍니다. 아바타 자리에 씁니다.
  String _initial() {
    final String trimmed = widget.userName.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return trimmed.substring(0, 1);
  }
}
