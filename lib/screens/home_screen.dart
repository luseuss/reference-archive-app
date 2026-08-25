// 앱을 켰을 때 가장 먼저 보이는 화면입니다. 저장한 레퍼런스 목록을 보여줍니다.
//
// 하는 일:
//   - 저장된 레퍼런스를 불러와 격자로 보여주기
//   - 오른쪽 아래 버튼으로 이미지 추가하기
//   - 카드의 휴지통 버튼으로 삭제하기
//
// ── 화면이 데이터를 다루는 방식 ──
// 이 화면은 데이터베이스를 직접 만지지 않습니다. 생성자로 받은 repository
// (약속)만 통해서 읽고 씁니다. 그래서 나중에 저장 방식이 서버로 바뀌어도
// 이 파일은 안 고쳐도 됩니다. (CLAUDE.md 설계 원칙 3)


import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/reference_item.dart';
import '../models/reference_query.dart';
import '../models/taxonomy_item.dart';
import '../repositories/reference_repository.dart';
import '../repositories/taxonomy_repository.dart';
import '../services/image_storage.dart';
import '../utils/id_generator.dart';
import '../widgets/reference_card.dart';
import '../widgets/reference_filter_bar.dart';
import 'reference_detail_screen.dart';
import 'taxonomy_manage_screen.dart';

/// 레퍼런스 목록 화면입니다.
///
/// StatefulWidget인 이유: 목록이 바뀌고(추가/삭제), 불러오는 중인지 아닌지도
/// 바뀝니다. 이렇게 "화면에 보이는 내용이 변하는" 화면은 StatefulWidget이어야 합니다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.taxonomyRepository,
    required this.imageStorage,
  });

  /// 레퍼런스를 읽고 쓰는 통로입니다.
  final ReferenceRepository repository;

  /// 폴더·카테고리·태그·프로젝트를 읽고 쓰는 통로입니다.
  /// 이 화면에서 직접 쓰지는 않고 편집 화면으로 넘겨줍니다.
  final TaxonomyRepository taxonomyRepository;

  /// 이미지 파일을 저장하고 경로를 알려주는 도구입니다.
  final ImageStorage imageStorage;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// 화면에 보여줄 레퍼런스 목록입니다.
  List<ReferenceItem> _items = <ReferenceItem>[];

  /// 각 레퍼런스의 이미지 파일 전체 경로입니다. (레퍼런스 id → 경로)
  ///
  /// 경로를 구하는 데 시간이 걸려서, 미리 한 번 구해두고 재사용합니다.
  /// 카드를 그릴 때마다 매번 구하면 화면이 버벅입니다.
  final Map<String, String> _imagePaths = <String, String>{};

  /// 목록을 불러오는 중인지 여부입니다. 처음 화면을 열 때 잠깐 true가 됩니다.
  bool _isLoading = true;

  /// 이미지를 추가하는 중인지 여부입니다.
  ///
  /// 큰 사진은 크기를 줄이는 데 잠시 걸립니다. 그동안 추가 버튼을 여러 번
  /// 누르면 같은 사진이 여러 장 들어가므로, 진행 중에는 버튼을 잠급니다.
  bool _isAdding = false;

  /// 지금 걸려 있는 검색·필터·정렬 조건입니다.
  ReferenceQuery _query = const ReferenceQuery();

  /// 검색 입력창을 다루는 도구입니다.
  final TextEditingController _searchController = TextEditingController();

  /// 검색을 잠시 미뤄두는 타이머입니다. (디바운스)
  Timer? _searchDebounce;

  /// 고를 수 있는 분류 항목들입니다. 필터 메뉴를 채우는 데 씁니다.
  Map<TaxonomyKind, List<TaxonomyItem>> _taxonomyOptions =
      <TaxonomyKind, List<TaxonomyItem>>{};

  /// 화면이 처음 만들어질 때 딱 한 번 실행됩니다.
  @override
  void initState() {
    super.initState();

    // 검색창에 글자가 바뀔 때마다 알림을 받습니다.
    _searchController.addListener(_onSearchTextChanged);

    _loadTaxonomyOptions();
    _loadItems();
  }

  /// 화면이 사라질 때 만들어둔 것들을 정리합니다.
  ///
  /// 타이머를 안 끄면 화면을 닫은 뒤에 타이머가 깨어나서
  /// 이미 없어진 화면을 고치려다 오류를 냅니다.
  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// 검색창의 글자가 바뀌었을 때 실행됩니다.
  ///
  /// ── 디바운스: 왜 바로 검색하지 않나 ──
  /// "노을"을 치면 ㄴ→노→놀→노으→노을 순으로 다섯 번 바뀝니다. 그때마다
  /// 데이터베이스를 뒤지면 쓸데없는 검색을 네 번 더 하게 되고, 글자가 많아지면
  /// 입력이 버벅입니다.
  ///
  /// 그래서 글자가 바뀌면 바로 검색하지 않고 300밀리초를 기다립니다.
  /// 그 사이에 또 입력하면 타이머를 취소하고 다시 셉니다.
  /// 결과적으로 **타이핑을 멈췄을 때 한 번만** 검색합니다.
  void _onSearchTextChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      final String text = _searchController.text;

      // 글자가 실제로 달라졌을 때만 다시 불러옵니다.
      if (text == _query.searchText) {
        return;
      }

      _applyQuery(_query.copyWith(searchText: text));
    });
  }

  /// 조건을 바꾸고 목록을 다시 불러옵니다.
  void _applyQuery(ReferenceQuery query) {
    setState(() {
      _query = query;
    });
    _loadItems();
  }

  /// 필터 메뉴에 쓸 분류 항목 목록을 불러옵니다.
  Future<void> _loadTaxonomyOptions() async {
    final Map<TaxonomyKind, List<TaxonomyItem>> loaded =
        <TaxonomyKind, List<TaxonomyItem>>{};

    for (final TaxonomyKind kind in TaxonomyKind.values) {
      loaded[kind] = await widget.taxonomyRepository.getAll(kind);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _taxonomyOptions = loaded;
    });
  }

  /// 조건에 맞는 레퍼런스를 불러와 화면에 반영합니다.
  Future<void> _loadItems() async {
    final List<ReferenceItem> items = await widget.repository.search(_query);

    // 각 이미지의 실제 경로를 미리 구해둡니다.
    final Map<String, String> paths = <String, String>{};
    for (final ReferenceItem item in items) {
      final String? fileName = item.fileName;
      if (fileName != null) {
        paths[item.id] = await widget.imageStorage.getFullPath(fileName);
      }
    }

    // 화면이 이미 닫혔는데 setState를 부르면 오류가 납니다.
    // 데이터를 불러오는 동안 사용자가 화면을 나갔을 수 있으므로 확인합니다.
    if (!mounted) {
      return;
    }

    setState(() {
      _items = items;
      _imagePaths
        ..clear()
        ..addAll(paths);
      _isLoading = false;
    });
  }

  /// 이미지 파일을 골라서 레퍼런스로 추가합니다.
  Future<void> _addImages() async {
    // 파일 고르기 창을 띄웁니다. 여러 장을 한 번에 고를 수 있습니다.
    // 사용자가 취소하면 빈 목록이 돌아옵니다.
    final List<PlatformFile> picked = await FilePicker.pickFiles(
      type: FileType.image,
      dialogTitle: '레퍼런스로 추가할 이미지 고르기',
    );

    if (picked.isEmpty) {
      return;
    }

    setState(() {
      _isAdding = true;
    });

    int savedCount = 0;
    int failedCount = 0;

    for (final PlatformFile file in picked) {
      final bool ok = await _saveOneImage(file);
      if (ok) {
        savedCount++;
      } else {
        failedCount++;
      }
    }

    await _loadItems();

    if (!mounted) {
      return;
    }

    setState(() {
      _isAdding = false;
    });

    _showResultMessage(savedCount, failedCount);
  }

  /// 고른 파일 하나를 줄여서 저장하고 레퍼런스로 등록합니다.
  ///
  /// 성공하면 true, 실패하면 false를 돌려줍니다.
  ///
  /// 파일 경로(path)로 읽지 않고 readAsBytes()를 쓰는 이유:
  /// 안드로이드에서는 다른 앱(갤러리 등)이 넘겨준 파일에 실제 경로가 없을 수 있습니다.
  /// readAsBytes()는 그런 경우에도 내용을 읽어줍니다.
  Future<bool> _saveOneImage(PlatformFile file) async {
    final String originalName = file.name;
    try {
      // 파일을 통째로 읽어서 크기를 줄인 뒤 앱 폴더에 저장합니다.
      final String? savedFileName =
          await widget.imageStorage.saveImage(await file.readAsBytes());

      // 그림 파일이 아니거나 깨진 파일이면 null이 돌아옵니다.
      if (savedFileName == null) {
        return false;
      }

      final DateTime now = DateTime.now().toUtc();
      await widget.repository.save(
        ReferenceItem(
          id: newId(),
          type: ReferenceType.image,
          // 제목은 원본 파일 이름에서 확장자를 뗀 것으로 시작합니다.
          // 사용자가 제목을 고치는 기능은 2단계에서 붙입니다.
          title: _stripExtension(originalName),
          fileName: savedFileName,
          createdAt: now,
          updatedAt: now,
        ),
      );
      return true;
    } catch (error) {
      // 파일 하나가 실패해도 나머지는 계속 처리되도록 여기서 잡습니다.
      // 사진 10장 중 1장이 깨졌다고 9장까지 못 넣으면 곤란합니다.
      debugPrint('이미지 저장 실패 ($originalName): $error');
      return false;
    }
  }

  /// 레퍼런스를 지웁니다.
  ///
  /// 이미지 파일은 지우지 않습니다. 삭제가 소프트 삭제(되살릴 수 있음)라서,
  /// 파일까지 지우면 되살렸을 때 그림 없는 빈 껍데기가 되기 때문입니다.
  Future<void> _deleteItem(ReferenceItem item) async {
    await widget.repository.delete(item.id);
    await _loadItems();
  }

  /// 분류 관리 화면을 열고, 돌아오면 목록을 다시 불러옵니다.
  Future<void> _openTaxonomyManage() async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => TaxonomyManageScreen(
          repository: widget.taxonomyRepository,
        ),
      ),
    );

    if (changed != true) {
      return;
    }

    // 분류를 지웠으면 지금 걸어둔 필터가 없어진 항목을 가리킬 수 있습니다.
    // 그대로 두면 아무것도 안 나오는데 이유를 알 수 없으므로 조건을 지웁니다.
    await _loadTaxonomyOptions();
    if (mounted && _query.hasAnyFilter) {
      _searchController.clear();
      _applyQuery(_query.clearAll());
    } else {
      await _loadItems();
    }
  }

  /// 편집 화면을 열고, 돌아오면 목록을 다시 불러옵니다.
  Future<void> _openDetail(ReferenceItem item) async {
    // push는 새 화면을 띄우고, 그 화면이 닫힐 때까지 기다렸다가
    // 닫으면서 돌려준 값을 받습니다.
    // 편집 화면은 저장했을 때만 true를 돌려줍니다.
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => ReferenceDetailScreen(
          item: item,
          referenceRepository: widget.repository,
          taxonomyRepository: widget.taxonomyRepository,
          imageStorage: widget.imageStorage,
        ),
      ),
    );

    // 저장 없이 그냥 뒤로 나왔으면 다시 불러올 필요가 없습니다.
    if (changed == true) {
      // 편집 화면에서 새 폴더나 태그를 만들었을 수 있으므로
      // 필터 메뉴 목록도 함께 갱신합니다. 안 하면 방금 만든 태그가
      // 필터 메뉴에 안 보여서 "왜 없지?" 하게 됩니다.
      await _loadTaxonomyOptions();
      await _loadItems();
    }
  }

  /// 추가 결과를 화면 아래쪽에 잠깐 띄웁니다.
  void _showResultMessage(int savedCount, int failedCount) {
    String message;
    if (failedCount == 0) {
      message = '$savedCount장 추가했습니다.';
    } else if (savedCount == 0) {
      message = '추가하지 못했습니다. 그림 파일이 맞는지 확인해주세요.';
    } else {
      message = '$savedCount장 추가했습니다. $failedCount장은 읽지 못했습니다.';
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 파일 이름에서 확장자를 떼어냅니다. ("노을.jpg" → "노을")
  String _stripExtension(String fileName) {
    final int dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0) {
      return fileName;
    }
    return fileName.substring(0, dotIndex);
  }

  /// 화면의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('레퍼런스 아카이브'),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        actions: <Widget>[
          IconButton(
            onPressed: _openTaxonomyManage,
            icon: const Icon(Icons.folder_special_outlined),
            tooltip: '분류 관리',
          ),
        ],
      ),
      // 검색·필터 줄은 항상 위에 붙어 있고, 그 아래 내용만 바뀝니다.
      // 결과가 없을 때도 검색창이 남아 있어야 조건을 고칠 수 있습니다.
      body: Column(
        children: <Widget>[
          ReferenceFilterBar(
            query: _query,
            searchController: _searchController,
            taxonomyOptions: _taxonomyOptions,
            onQueryChanged: _applyQuery,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // 추가하는 중에는 null을 넣어 버튼을 잠급니다.
        // Flutter에서는 onPressed가 null이면 버튼이 자동으로 비활성화됩니다.
        onPressed: _isAdding ? null : _addImages,
        icon: _isAdding
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_photo_alternate_outlined),
        label: Text(_isAdding ? '추가하는 중...' : '이미지 추가'),
      ),
    );
  }

  /// 화면 가운데 내용을 만듭니다. 상황에 따라 셋 중 하나를 보여줍니다.
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    return _buildGrid();
  }

  /// 보여줄 레퍼런스가 없을 때의 안내입니다.
  ///
  /// **"아직 아무것도 없음"과 "조건에 맞는 게 없음"을 구분해서 보여줍니다.**
  /// 사진이 100장 있는데 "아직 없습니다"라고 하면 사용자가 데이터가 날아간 줄 알고,
  /// 반대로 하나도 없는데 "조건에 맞는 게 없다"고 하면 있지도 않은 조건을
  /// 지우려고 헤매게 됩니다.
  Widget _buildEmptyState() {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textStyles = Theme.of(context).textTheme;

    final bool isFiltered = _query.hasAnyFilter;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              isFiltered ? Icons.search_off : Icons.photo_library_outlined,
              size: 64,
              color: colors.primary,
            ),
            const SizedBox(height: 24),
            Text(
              isFiltered ? '조건에 맞는 레퍼런스가 없습니다' : '아직 모아둔 레퍼런스가 없습니다',
              style: textStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? '검색어나 필터를 바꿔보세요.'
                  : '오른쪽 아래 버튼으로 이미지를 추가해보세요.',
              style: textStyles.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (isFiltered) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () {
                  _searchController.clear();
                  _applyQuery(_query.clearAll());
                },
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('조건 지우기'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 레퍼런스를 격자로 보여줍니다.
  Widget _buildGrid() {
    return GridView.builder(
      // 아래쪽 여백을 크게 준 이유: 안 그러면 마지막 줄의 카드가
      // 오른쪽 아래 떠 있는 추가 버튼에 가려집니다.
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),

      // maxCrossAxisExtent = "칸 하나의 최대 너비".
      // 개수를 고정하지 않고 너비를 정하면, 창을 넓히면 칸이 늘어나고
      // 폰처럼 좁은 화면에서는 저절로 줄어듭니다. 화면 크기별로 따로
      // 만들지 않아도 되어서 데스크톱과 모바일을 함께 지원하기 좋습니다.
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _items.length,
      itemBuilder: (BuildContext context, int index) {
        final ReferenceItem item = _items[index];
        return ReferenceCard(
          item: item,
          imagePath: _imagePaths[item.id],
          onDelete: () => _deleteItem(item),
          onTap: () => _openDetail(item),
        );
      },
    );
  }
}
