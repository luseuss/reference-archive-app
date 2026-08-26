// 앱을 켰을 때 가장 먼저 보이는 화면입니다. 저장한 레퍼런스 목록을 보여줍니다.
//
// 하는 일:
//   - 저장된 레퍼런스를 불러와 격자로 보여주기
//   - 오른쪽 아래 버튼으로 이미지 추가하기
//   - 카드의 휴지통 버튼으로 삭제하기
//   - 여러 장을 골라 한꺼번에 폴더 이동 / 태그 추가 / 삭제하기
//   - 유튜브 카드에 마우스를 올리면 소리 없이 미리보기 재생 (데스크톱만)
//
// ── 화면이 데이터를 다루는 방식 ──
// 이 화면은 데이터베이스를 직접 만지지 않습니다. 생성자로 받은 repository
// (약속)만 통해서 읽고 씁니다. 그래서 나중에 저장 방식이 서버로 바뀌어도
// 이 파일은 안 고쳐도 됩니다. (CLAUDE.md 설계 원칙 3)

import 'dart:async';

import 'dart:io';

import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../models/enums.dart';
import '../models/reference_item.dart';
import '../models/reference_query.dart';
import '../models/taxonomy_item.dart';
import '../repositories/reference_repository.dart';
import '../repositories/taxonomy_repository.dart';
import '../services/dropped_item_reader.dart';
import '../services/image_source.dart';
import '../services/image_storage.dart';
import '../services/local_player_server.dart';
import '../services/youtube_info_source.dart';
import '../services/youtube_url.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';
import '../utils/id_generator.dart';
import '../widgets/add_youtube_dialog.dart';
import '../widgets/bulk_action_bar.dart';
import '../widgets/pick_taxonomy_dialog.dart';
import '../widgets/reference_card.dart';
import '../widgets/reference_filter_bar.dart';
import 'reference_detail_screen.dart';
import 'taxonomy_manage_screen.dart';
import 'youtube_player_screen.dart';

/// 마우스를 올린 뒤 미리보기를 시작하기까지 기다리는 시간입니다.
///
/// 짧으면 목록을 훑을 때 지나가는 영상이 줄줄이 켜지고, 길면 "왜 안 나오지?"
/// 하게 됩니다. 처음엔 0.4초로 뒀는데 써보니 답답해서 0.2초로 줄였습니다.
/// 너무 부산스럽거나 굼뜨면 이 값을 고치세요.
const Duration hoverPreviewDelay = Duration(milliseconds: 200);

/// 이 기기에서 호버 미리보기를 쓸 수 있는지 여부입니다.
///
/// 폰·태블릿에는 마우스가 없어서 "올려두기"라는 동작 자체가 없습니다.
/// 억지로 흉내내지 않고 데스크톱에서만 켭니다. (CLAUDE.md 플랫폼 차이표)
bool get supportsHoverPreview {
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

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
    required this.imageSource,
    required this.youtubeInfoSource,
  });

  /// 레퍼런스를 읽고 쓰는 통로입니다.
  final ReferenceRepository repository;

  /// 폴더·카테고리·태그·프로젝트를 읽고 쓰는 통로입니다.
  /// 이 화면에서 직접 쓰지는 않고 편집 화면으로 넘겨줍니다.
  final TaxonomyRepository taxonomyRepository;

  /// 이미지 파일을 저장하고 경로를 알려주는 도구입니다.
  final ImageStorage imageStorage;

  /// 유튜브에서 제목과 썸네일을 가져오는 도구입니다.
  final YoutubeInfoSource youtubeInfoSource;

  /// 주소나 클립보드에서 이미지를 가져오는 도구입니다.
  final ImageSource imageSource;

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

  /// 분류 항목 id를 이름으로 바꿔주는 표입니다. (id → 이름)
  ///
  /// 카드에는 폴더·카테고리·태그가 **id로만** 들어있어서 그대로는 못 보여줍니다.
  /// 카드마다 이름을 찾아 데이터베이스를 뒤지면 목록이 버벅이므로,
  /// 분류 목록을 불러올 때 **한 번만** 만들어두고 모든 카드가 나눠 씁니다.
  Map<String, String> _taxonomyNames = <String, String>{};

  /// 지금 무언가를 창 위로 끌고 있는 중인지 여부입니다.
  /// 켜져 있으면 "여기 놓으세요" 안내를 덧그립니다.
  bool _isDragging = false;

  /// 지금 여러 장을 고르는 중인지 여부입니다.
  ///
  /// ── 왜 "고른 게 하나라도 있으면 고르기 모드"로 하지 않았나 ──
  /// 그렇게 하면 마지막 한 장의 선택을 풀었을 때 체크박스와 작업 막대가
  /// 통째로 사라집니다. 사용자는 잘못 눌러서 모드가 꺼졌다고 느낍니다.
  /// 그래서 "고르기 모드"와 "무엇을 골랐는지"를 따로 둡니다.
  bool _isSelecting = false;

  /// 지금 골라둔 레퍼런스들의 id입니다.
  ///
  /// List가 아니라 Set인 이유: Set은 같은 값이 두 번 안 들어가고,
  /// "이게 들어있나?"를 확인하는 것이 목록이 길어져도 빠릅니다.
  /// 카드를 그릴 때마다 확인하는 값이라 이 차이가 실제로 체감됩니다.
  final Set<String> _selectedIds = <String>{};

  /// 지금 미리보기 영상을 틀고 있는 카드의 id입니다. 없으면 null입니다.
  ///
  /// **한 번에 하나만 틀 수 있게** 이렇게 하나만 기억합니다.
  /// 카드마다 웹뷰를 두면 목록에 영상이 서른 개일 때 감당이 안 됩니다.
  /// 마우스는 한 곳에만 있으므로 이걸로 충분합니다.
  String? _previewingItemId;

  /// 미리보기 영상을 띄울 주소입니다.
  String? _previewUrl;

  /// 마우스를 올린 뒤 미리보기를 시작하기까지 기다리는 타이머입니다.
  Timer? _hoverTimer;

  /// 미리보기를 시작하려고 마음먹은 카드의 id입니다.
  ///
  /// ── 왜 따로 기억하나 ──
  /// 미리보기를 켜려면 임시 서버를 띄워야 하고, 그동안 사용자는 이미 마우스를
  /// 다른 데로 옮겼을 수 있습니다. 그때 그대로 진행하면 **마우스가 없는 카드에서
  /// 영상이 재생됩니다.** 서버가 준비된 뒤 이 값을 다시 확인해서 막습니다.
  String? _pendingPreviewId;

  /// 미리보기 페이지를 띄워주는 임시 서버입니다.
  ///
  /// 재생 화면이 쓰는 것과 같은 도구입니다. 유튜브 재생기는 진짜 주소를 가진
  /// 페이지 안에 있어야 하기 때문입니다. (local_player_server.dart 참고)
  final LocalPlayerServer _previewServer = LocalPlayerServer();

  /// 끌어다 놓은 것을 읽어 이미지 데이터로 만들어주는 도구입니다.
  ///
  /// late를 붙인 이유: 이 도구를 만들려면 widget.imageSource가 필요한데,
  /// 값을 적어두는 시점에는 아직 widget이 준비되기 전이라 쓸 수 없습니다.
  /// late = "지금 말고 처음 쓸 때 만들어라"라는 뜻입니다.
  late final DroppedItemReader _droppedItemReader = DroppedItemReader(
    widget.imageSource,
  );

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
    _hoverTimer?.cancel();
    _previewServer.stop();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// 마우스가 카드에 올라오거나 벗어났을 때 실행됩니다.
  ///
  /// ── 왜 바로 틀지 않고 기다리나 ──
  /// 목록을 훑을 때 마우스는 카드 여러 장을 스쳐 지나갑니다. 올라오자마자 틀면
  /// 지나가는 길에 있던 영상이 줄줄이 켜졌다 꺼지면서 화면이 정신없어지고,
  /// 볼 생각도 없던 영상을 계속 받아오게 됩니다.
  ///
  /// 그래서 잠깐 머물렀을 때만 켭니다. "보려고 멈춘 것"과 "지나가는 것"의 차이입니다.
  void _onCardHoverChanged(ReferenceItem item, bool isHovering) {
    // 지나가던 타이머는 언제나 취소합니다.
    _hoverTimer?.cancel();

    if (!isHovering) {
      _pendingPreviewId = null;

      // 다른 카드에서 이미 틀고 있는 중이라면 건드리지 않습니다.
      // 카드 A를 벗어나는 알림이 카드 B에 들어온 뒤에 올 수도 있습니다.
      if (_previewingItemId == item.id) {
        _stopPreview();
      }
      return;
    }

    // 고르는 중에는 틀지 않습니다. 여러 장 고르는 데 집중하는 상황이고,
    // 지나갈 때마다 영상이 켜지면 방해만 됩니다.
    if (_isSelecting) {
      return;
    }

    _pendingPreviewId = item.id;
    _hoverTimer = Timer(hoverPreviewDelay, () => _startPreview(item));
  }

  /// 카드 위에서 미리보기 영상을 켭니다.
  Future<void> _startPreview(ReferenceItem item) async {
    final String? videoId = item.youtubeVideoId;
    if (videoId == null) {
      return;
    }

    // 소리는 끕니다. 목록을 훑을 때마다 소리가 나면 쓸 수 없는 기능이 됩니다.
    final String? url = await _previewServer.start(
      youtubePlayerHtml(videoId, muted: true),
    );

    if (!mounted || url == null) {
      return;
    }

    // 서버를 켜는 사이에 마우스가 다른 데로 갔으면 그만둡니다.
    // 이걸 안 보면 마우스가 없는 카드에서 영상이 재생됩니다.
    if (_pendingPreviewId != item.id) {
      await _previewServer.stop();
      return;
    }

    setState(() {
      _previewingItemId = item.id;
      _previewUrl = url;
    });
  }

  /// 미리보기 영상을 끕니다.
  void _stopPreview() {
    _pendingPreviewId = null;

    if (_previewingItemId == null) {
      return;
    }

    setState(() {
      _previewingItemId = null;
      _previewUrl = null;
    });

    // 서버는 끄는 데 시간이 걸리므로 기다리지 않습니다.
    // 화면은 이미 미리보기를 치웠고, 서버는 뒤에서 정리되면 됩니다.
    _previewServer.stop();
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

    // id → 이름 표를 함께 만들어둡니다.
    // 종류(폴더/카테고리/태그/프로젝트)를 구분하지 않고 한 표에 담습니다.
    // 분류 항목 id는 세상에 하나뿐이라 섞여도 헷갈릴 일이 없습니다.
    final Map<String, String> names = <String, String>{};
    for (final List<TaxonomyItem> items in loaded.values) {
      for (final TaxonomyItem item in items) {
        names[item.id] = item.name;
      }
    }

    setState(() {
      _taxonomyOptions = loaded;
      _taxonomyNames = names;
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

      // 화면에 안 보이게 된 것은 골라둔 목록에서도 뺍니다.
      //
      // 예를 들어 세 장을 골라둔 채 검색어를 바꾸면 그중 두 장이 목록에서
      // 사라질 수 있습니다. 그대로 두면 "1장 골랐다"고 보이는데 실제로는
      // 3장이 지워지는, 사용자가 예상할 수 없는 일이 벌어집니다.
      _selectedIds.removeWhere((String id) {
        return !items.any((ReferenceItem item) => item.id == id);
      });
    });
  }

  /// 고르기 모드를 켜거나 끕니다.
  void _toggleSelectionMode() {
    // 고르기로 넘어가면 틀고 있던 미리보기를 끕니다.
    // 체크박스를 누르려는데 뒤에서 영상이 돌아가면 산만합니다.
    _hoverTimer?.cancel();
    _stopPreview();

    setState(() {
      _isSelecting = !_isSelecting;

      // 모드를 끄면 골라둔 것도 함께 비웁니다.
      // 안 비우면 다음에 모드를 켤 때 예전 선택이 되살아나 놀라게 됩니다.
      if (!_isSelecting) {
        _selectedIds.clear();
      }
    });
  }

  /// 고르기 모드를 끝내고 골라둔 것을 모두 비웁니다.
  void _exitSelectionMode() {
    setState(() {
      _isSelecting = false;
      _selectedIds.clear();
    });
  }

  /// 카드 하나를 고르거나 고르기를 취소합니다.
  ///
  /// 고르기 모드가 꺼져 있을 때 불리면(카드를 길게 눌렀을 때) 모드를 켭니다.
  void _toggleSelected(ReferenceItem item) {
    // 길게 눌러 고르기로 들어오는 경로입니다. 여기서도 미리보기를 끕니다.
    _hoverTimer?.cancel();
    _stopPreview();

    setState(() {
      _isSelecting = true;

      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        _selectedIds.add(item.id);
      }
    });
  }

  /// 지금 보이는 것을 전부 고릅니다. 이미 전부 골랐으면 전부 풉니다.
  void _toggleSelectAll() {
    setState(() {
      final bool allSelected = _selectedIds.length == _items.length;

      _selectedIds.clear();

      if (!allSelected) {
        for (final ReferenceItem item in _items) {
          _selectedIds.add(item.id);
        }
      }
    });
  }

  /// 골라둔 것들을 한 폴더로 옮깁니다.
  Future<void> _moveSelectedToFolder() async {
    final List<TaxonomyItem> folders =
        _taxonomyOptions[TaxonomyKind.folder] ?? <TaxonomyItem>[];

    // 폴더가 하나도 없으면 고를 것이 없습니다.
    // "폴더 없음"만 덩그러니 뜨는 대화상자보다, 무엇을 하면 되는지 알려줍니다.
    if (folders.isEmpty) {
      _showMessage('먼저 오른쪽 위 "분류 관리"에서 폴더를 만들어주세요.');
      return;
    }

    final int count = _selectedIds.length;

    final PickedTaxonomy? picked = await showPickTaxonomyDialog(
      context: context,
      kind: TaxonomyKind.folder,
      items: folders,
      title: '$count장을 옮길 폴더',

      // "폴더 없음"을 고르면 폴더에서 빼냅니다.
      allowNone: true,
    );

    // 대화상자를 그냥 닫았으면 아무것도 하지 않습니다.
    if (picked == null) {
      return;
    }

    // picked.item이 null이면 "폴더에서 빼기"입니다. 취소와는 다릅니다.
    await widget.repository.moveManyToFolder(
      _selectedIds.toList(),
      picked.item?.id,
    );

    final String where = picked.item == null ? '폴더에서 빼냈습니다' : '"${picked.item!.name}"으로 옮겼습니다';
    await _finishBulkAction('$count장을 $where.');
  }

  /// 골라둔 것들에 태그를 붙입니다.
  Future<void> _addTagToSelected() async {
    final List<TaxonomyItem> tags =
        _taxonomyOptions[TaxonomyKind.tag] ?? <TaxonomyItem>[];

    if (tags.isEmpty) {
      _showMessage('먼저 오른쪽 위 "분류 관리"에서 태그를 만들어주세요.');
      return;
    }

    final int count = _selectedIds.length;

    final PickedTaxonomy? picked = await showPickTaxonomyDialog(
      context: context,
      kind: TaxonomyKind.tag,
      items: tags,
      title: '$count장에 붙일 태그',
    );

    // 태그 고르기에는 "없음"이 없으므로 item은 반드시 들어 있습니다.
    if (picked == null || picked.item == null) {
      return;
    }

    await widget.repository.addTaxonomyItemToMany(
      _selectedIds.toList(),
      picked.item!.id,
    );

    await _finishBulkAction('$count장에 "${picked.item!.name}" 태그를 붙였습니다.');
  }

  /// 골라둔 것들을 한꺼번에 지웁니다.
  Future<void> _deleteSelected() async {
    final int count = _selectedIds.length;

    final bool confirmed = await _confirmBulkDelete(count);
    if (!confirmed) {
      return;
    }

    await widget.repository.deleteMany(_selectedIds.toList());

    await _finishBulkAction('$count장을 지웠습니다.');
  }

  /// 여러 장을 정말 지울지 확인받습니다.
  ///
  /// 낱장 삭제에는 확인이 없지만 여기에는 둡니다. 한 장을 잘못 지우는 것과
  /// 50장을 잘못 지우는 것은 되돌리는 수고가 완전히 다르기 때문입니다.
  Future<bool> _confirmBulkDelete(int count) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('레퍼런스 삭제'),
          content: Text(
            '고른 $count장을 지웁니다.\n\n'
            '이미지 파일은 남지만 목록에서는 사라집니다.',
          ),
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

    // 바깥을 눌러 닫으면 null이 옵니다. 그때는 안 지웁니다.
    return result ?? false;
  }

  /// 일괄 작업이 끝난 뒤 목록을 새로 고치고 결과를 알려줍니다.
  ///
  /// 셋 다 끝나면 고르기 모드를 **끕니다.** 작업 하나가 끝났는데 선택이
  /// 그대로 남아 있으면, 다음 작업이 방금 그 장들에 또 적용되는 줄 모르고
  /// 두 번 실행하기 쉽습니다.
  Future<void> _finishBulkAction(String message) async {
    _exitSelectionMode();
    await _loadItems();

    if (!mounted) {
      return;
    }

    _showMessage(message);
  }

  /// 화면 아래쪽에 짧은 안내를 띄웁니다.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 유튜브 주소를 입력받아 레퍼런스로 추가합니다.
  Future<void> _addYoutube() async {
    // 클립보드에 이미 유튜브 주소가 있으면 입력창에 채워서 띄웁니다.
    // 방금 복사해온 것을 또 붙여넣게 하는 것은 번거롭기만 합니다.
    final String? clipboardText = await widget.imageSource.readClipboardText();

    String? prefill;
    if (clipboardText != null && isYoutubeVideoUrl(clipboardText)) {
      prefill = clipboardText.trim();
    }

    // 클립보드를 읽는 사이에 화면이 닫혔을 수 있습니다.
    if (!mounted) {
      return;
    }

    final String? videoId = await showAddYoutubeDialog(
      context: context,
      initialUrl: prefill,
    );

    // 취소했으면 아무것도 하지 않습니다.
    if (videoId == null) {
      return;
    }

    await _addYoutubeById(videoId);
  }

  /// 영상 번호로 유튜브 레퍼런스를 추가하고 결과를 알려줍니다.
  ///
  /// 대화상자·붙여넣기·끌어다 놓기가 전부 여기로 모입니다.
  /// 들어오는 길은 셋이지만 저장하는 방식은 하나여야 합니다.
  Future<void> _addYoutubeById(String videoId) async {
    if (_isAdding) {
      return;
    }

    setState(() {
      _isAdding = true;
    });

    final bool ok = await _saveYoutubeReference(videoId);

    await _finishAdding(
      ok ? 1 : 0,
      ok ? 0 : 1,
      ok ? null : '유튜브 영상을 추가하지 못했습니다.',
      successMessage: '유튜브 영상을 추가했습니다.',
    );
  }

  /// 유튜브 영상 하나를 레퍼런스로 저장합니다.
  ///
  /// ── 썸네일을 왜 내려받아 저장하나 ──
  /// 화면에 띄울 때마다 img.youtube.com에서 가져오게 할 수도 있습니다.
  /// 하지만 그러면 **인터넷이 없을 때 목록이 텅 빈 회색 칸으로 보입니다.**
  /// 이 앱은 "내 컴퓨터에 모아두는" 것이 핵심이라, 이미지와 똑같이 파일로
  /// 저장해둡니다. 그러면 비행기 안에서도 목록은 그대로 보입니다.
  ///
  /// 제목이나 썸네일을 못 가져와도 **저장은 합니다.** 영상 번호만 있으면
  /// 나중에 재생할 수 있고, 제목은 편집 화면에서 직접 적을 수 있습니다.
  ///
  /// 성공하면 true, 실패하면 false를 돌려줍니다.
  Future<bool> _saveYoutubeReference(String videoId) async {
    try {
      final YoutubeVideoInfo info = await widget.youtubeInfoSource.fetch(
        videoId,
      );

      // 썸네일은 있으면 저장하고, 없으면 없는 대로 넘어갑니다.
      String? savedFileName;
      final Uint8List? thumbnail = info.thumbnailBytes;
      if (thumbnail != null) {
        savedFileName = await widget.imageStorage.saveImage(thumbnail);
      }

      final DateTime now = DateTime.now().toUtc();
      await widget.repository.save(
        ReferenceItem(
          id: newId(),
          type: ReferenceType.youtube,
          title: info.title,
          fileName: savedFileName,
          youtubeVideoId: videoId,
          createdAt: now,
          updatedAt: now,
        ),
      );
      return true;
    } catch (error) {
      debugPrint('유튜브 저장 실패: $error');
      return false;
    }
  }

  /// 유튜브 재생 화면을 엽니다.
  Future<void> _playYoutube(ReferenceItem item) async {
    final String? videoId = item.youtubeVideoId;

    // 유튜브가 아닌 카드에는 재생 버튼이 없으므로 보통 여기 걸리지 않습니다.
    // 예전 데이터가 어딘가 어긋나 있어도 앱이 죽지는 않게 확인합니다.
    if (videoId == null) {
      return;
    }

    // 크게 보러 가기 전에 미리보기를 끕니다.
    //
    // 재생 버튼을 누르는 시점에는 마우스가 카드 위에 있으므로 미리보기가 돌고
    // 있습니다. 그대로 두면 **뒤에서 같은 영상이 하나 더 돌아갑니다.** 보이지도
    // 않는 영상을 계속 받아오는 셈이고, 웹뷰도 두 개가 됩니다.
    _hoverTimer?.cancel();
    _stopPreview();

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            YoutubePlayerScreen(videoId: videoId, title: item.title),
      ),
    );
  }

  /// 이미지 파일을 골라서 레퍼런스로 추가합니다.
  Future<void> _addImages() async {
    // 파일 고르기 창을 띄웁니다. 여러 장을 한 번에 고를 수 있습니다.
    // 사용자가 취소하면 null이 돌아옵니다.
    //
    // withData: true를 주면 파일 내용을 메모리에 함께 담아줍니다.
    // 안드로이드에서는 다른 앱이 넘겨준 파일에 실제 경로가 없을 수 있어서,
    // 경로 대신 내용을 직접 받는 편이 안전합니다.
    final FilePickerResult? picked = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
      dialogTitle: '레퍼런스로 추가할 이미지 고르기',
    );

    if (picked == null || picked.files.isEmpty) {
      return;
    }

    setState(() {
      _isAdding = true;
    });

    int savedCount = 0;
    int failedCount = 0;

    for (final PlatformFile file in picked.files) {
      final bool ok = await _saveOneImage(file);
      if (ok) {
        savedCount++;
      } else {
        failedCount++;
      }
    }

    await _finishAdding(savedCount, failedCount, null);
  }

  /// 고른 파일 하나를 줄여서 저장하고 레퍼런스로 등록합니다.
  ///
  /// 성공하면 true, 실패하면 false를 돌려줍니다.
  Future<bool> _saveOneImage(PlatformFile file) async {
    final String originalName = file.name;
    try {
      // withData: true로 골랐으므로 bytes에 내용이 들어있습니다.
      // 혹시 없으면(플랫폼 사정) 경로로 읽어봅니다.
      Uint8List? bytes = file.bytes;

      if (bytes == null) {
        final String? path = file.path;
        if (path == null) {
          return false;
        }
        bytes = await File(path).readAsBytes();
      }

      return await _saveImageBytes(bytes, title: _stripExtension(originalName));
    } catch (error) {
      // 파일 하나가 실패해도 나머지는 계속 처리되도록 여기서 잡습니다.
      // 사진 10장 중 1장이 깨졌다고 9장까지 못 넣으면 곤란합니다.
      debugPrint('이미지 저장 실패 ($originalName): $error');
      return false;
    }
  }

  /// 이미지 데이터를 줄여서 저장하고 레퍼런스로 등록합니다.
  ///
  /// **파일 고르기·끌어다 놓기·붙여넣기가 전부 이 함수로 모입니다.**
  /// 가져오는 경로는 셋이지만 저장하는 방식은 하나여야, 어느 쪽으로 넣든
  /// 똑같이 리사이즈되고 똑같이 기록됩니다.
  ///
  /// 성공하면 true, 실패하면 false를 돌려줍니다.
  Future<bool> _saveImageBytes(Uint8List bytes, {String? title}) async {
    try {
      final String? savedFileName = await widget.imageStorage.saveImage(bytes);

      // 그림 파일이 아니거나 깨진 파일이면 null이 돌아옵니다.
      if (savedFileName == null) {
        return false;
      }

      final DateTime now = DateTime.now().toUtc();
      await widget.repository.save(
        ReferenceItem(
          id: newId(),
          type: ReferenceType.image,
          // 제목을 못 뽑아낸 경우(클립보드 등)에는 빈 제목으로 둡니다.
          // 목록에서는 "(제목 없음)"으로 보이고 편집 화면에서 고칠 수 있습니다.
          title: title ?? '',
          fileName: savedFileName,
          createdAt: now,
          updatedAt: now,
        ),
      );
      return true;
    } catch (error) {
      debugPrint('이미지 저장 실패: $error');
      return false;
    }
  }

  /// 앱 창에 무언가를 끌어다 놓았을 때 실행됩니다.
  ///
  /// ── 브라우저에서 끌면 무엇이 오는가 ──
  /// 상황마다 다릅니다. 이미지 데이터가 그대로 오기도 하고, 주소만 오기도 합니다.
  /// 그래서 각 항목마다 **줄 수 있는 형식을 물어보고** 처리 방법을 정합니다.
  ///
  ///   1. 이미지 형식(PNG/JPEG/...)을 줄 수 있으면 → 그대로 받습니다
  ///   2. 주소를 줄 수 있으면 → 내려받습니다
  ///
  /// 이 순서가 중요합니다. 브라우저는 보통 둘 다 줄 수 있다고 하는데,
  /// 이미 갖고 있는 데이터를 쓰는 쪽이 빠르고 실패할 일도 없습니다.
  Future<void> _handleDrop(PerformDropEvent event) async {
    if (_isAdding) {
      return;
    }

    setState(() {
      _isAdding = true;
    });

    int savedCount = 0;
    int failedCount = 0;
    String? lastError;

    for (final DropItem item in event.session.items) {
      final DataReader? reader = item.dataReader;
      if (reader == null) {
        failedCount++;
        continue;
      }

      // 유튜브 링크를 끌어온 것인지 **먼저** 봅니다.
      // 그냥 read()에 넘기면 이미지인 줄 알고 내려받다가 실패합니다.
      // (자세한 이유는 DroppedItemReader.youtubeVideoIdOf() 설명 참고)
      final String? videoId = await _droppedItemReader.youtubeVideoIdOf(reader);
      if (videoId != null) {
        final bool savedVideo = await _saveYoutubeReference(videoId);
        if (savedVideo) {
          savedCount++;
        } else {
          failedCount++;
          lastError = '유튜브 영상을 추가하지 못했습니다.';
        }
        continue;
      }

      final ImageFetchResult fetched = await _droppedItemReader.read(reader);

      if (!fetched.isSuccess) {
        failedCount++;
        lastError = fetched.errorMessage;
        continue;
      }

      final bool ok = await _saveImageBytes(
        fetched.bytes!,
        title: fetched.suggestedTitle,
      );
      if (ok) {
        savedCount++;
      } else {
        failedCount++;
        // 가져오기는 됐는데 그림이 아닌 경우입니다.
        // (예: 이미지가 아니라 웹페이지 주소를 받아온 경우)
        // "그림 파일이 맞는지 확인하세요"보다 다음에 뭘 하면 되는지 알려줍니다.
        lastError =
            '가져온 것이 이미지가 아닙니다. '
            '이미지를 우클릭해 "이미지 복사" 후 붙여넣어 보세요.';
      }
    }

    await _finishAdding(savedCount, failedCount, lastError);
  }

  /// 클립보드에 있는 것을 레퍼런스로 추가합니다. (Ctrl+V)
  ///
  /// 두 가지를 순서대로 시도합니다.
  ///   1. 클립보드에 **이미지**가 있으면 그걸 씁니다. (브라우저에서 "이미지 복사")
  ///   2. 없으면 클립보드의 **글자**가 이미지 주소인지 보고, 맞으면 내려받습니다.
  ///      (브라우저에서 "이미지 주소 복사")
  ///
  /// 사용자는 둘 중 무엇을 복사했는지 신경 쓰지 않아도 되게 하려는 것입니다.
  Future<void> _pasteFromClipboard() async {
    if (_isAdding) {
      return;
    }

    setState(() {
      _isAdding = true;
    });

    ImageFetchResult fetched = await widget.imageSource.fetchFromClipboard();

    // 주소를 실제로 받아보려 시도했는지 기록합니다.
    //
    // 이걸 구분하는 이유: 주소를 받아보다 실패한 경우에는 그쪽에서 온 구체적인
    // 이유("그 사이트가 막고 있습니다" 등)를 그대로 보여줘야 합니다.
    // 그걸 "클립보드에 이미지가 없습니다"로 덮어쓰면, 사용자는 클립보드를
    // 다시 복사하러 가는 엉뚱한 행동을 하게 됩니다.
    bool triedUrl = false;

    if (!fetched.isSuccess) {
      final String? text = await widget.imageSource.readClipboardText();

      // 유튜브 주소면 이미지로 내려받으려 하지 말고 영상으로 저장합니다.
      // 유튜브 페이지를 내려받아 봐야 HTML이라 "그림이 아니다"로 실패합니다.
      final String? videoId = text == null ? null : youtubeVideoIdFrom(text);
      if (videoId != null) {
        final bool savedVideo = await _saveYoutubeReference(videoId);
        await _finishAdding(
          savedVideo ? 1 : 0,
          savedVideo ? 0 : 1,
          savedVideo ? null : '유튜브 영상을 추가하지 못했습니다.',
          successMessage: '유튜브 영상을 추가했습니다.',
        );
        return;
      }

      if (text != null && looksLikeUrl(text)) {
        triedUrl = true;
        fetched = await widget.imageSource.fetchFromUrl(text.trim());
      }
    }

    if (!fetched.isSuccess) {
      await _finishAdding(
        0,
        1,
        triedUrl
            // 주소를 받아보다 실패 → 그쪽 이유를 그대로 전합니다.
            ? fetched.errorMessage
            // 클립보드에 쓸 만한 게 아예 없음 → 무엇을 하면 되는지 알려줍니다.
            : '클립보드에 이미지가 없습니다. 브라우저에서 이미지를 우클릭해 '
                  '"이미지 복사" 또는 "이미지 주소 복사"를 해보세요.',
      );
      return;
    }

    final bool ok = await _saveImageBytes(
      fetched.bytes!,
      title: fetched.suggestedTitle,
    );

    await _finishAdding(ok ? 1 : 0, ok ? 0 : 1, ok ? null : '이미지를 저장하지 못했습니다.');
  }

  /// 추가 작업이 끝난 뒤 목록을 새로 고치고 결과를 알려줍니다.
  ///
  /// 파일 고르기·끌어다 놓기·붙여넣기가 끝날 때 공통으로 하는 일입니다.
  /// [successMessage]를 주면 성공했을 때 그 문구를 대신 보여줍니다.
  /// 유튜브는 "1장 추가했습니다"가 어색해서 따로 문구를 넘깁니다.
  Future<void> _finishAdding(
    int savedCount,
    int failedCount,
    String? errorMessage, {
    String? successMessage,
  }) async {
    await _loadItems();

    if (!mounted) {
      return;
    }

    setState(() {
      _isAdding = false;
    });

    if (successMessage != null && failedCount == 0) {
      _showMessage(successMessage);
      return;
    }

    _showResultMessage(savedCount, failedCount, errorMessage: errorMessage);
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
        builder: (BuildContext context) =>
            TaxonomyManageScreen(repository: widget.taxonomyRepository),
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
  ///
  /// [errorMessage]가 있으면 그걸 우선해서 보여줍니다. 가져오기 쪽에서 온
  /// 구체적인 이유("그 사이트가 막고 있습니다" 등)가 "실패했습니다"보다
  /// 사용자에게 훨씬 쓸모 있기 때문입니다.
  void _showResultMessage(
    int savedCount,
    int failedCount, {
    String? errorMessage,
  }) {
    String message;
    if (failedCount == 0) {
      message = '$savedCount장 추가했습니다.';
    } else if (savedCount == 0) {
      message = errorMessage ?? '추가하지 못했습니다. 그림 파일이 맞는지 확인해주세요.';
    } else {
      message = '$savedCount장 추가했습니다. $failedCount장은 읽지 못했습니다.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        // 안내가 길어질 수 있어서(사이트가 막는 경우 등) 조금 더 오래 띄웁니다.
        duration: const Duration(seconds: 5),
      ),
    );
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
      appBar: _isSelecting ? _buildSelectionAppBar() : _buildNormalAppBar(),
      // CallbackShortcuts는 지정한 키 조합이 눌리면 함수를 실행합니다.
      // Focus(autofocus: true)로 감싸야 화면이 키 입력을 받습니다.
      // 안 감싸면 아무 데도 초점이 없어서 Ctrl+V가 무시됩니다.
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyV, control: true):
              _pasteFromClipboard,
          // macOS는 Ctrl 대신 Command를 씁니다.
          const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
              _pasteFromClipboard,
        },
        child: Focus(
          autofocus: true,
          child: _buildDropArea(
            // 검색·필터 줄은 항상 위에 붙어 있고, 그 아래 내용만 바뀝니다.
            // 결과가 없을 때도 검색창이 남아 있어야 조건을 고칠 수 있습니다.
            Column(
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
          ),
        ),
      ),
      // 고르는 중에는 화면 아래에 일괄 작업 막대가 붙습니다.
      // bottomNavigationBar에 넣으면 목록이 그만큼 위로 줄어들어서,
      // 떠 있는 버튼과 달리 마지막 줄의 카드를 가리지 않습니다.
      bottomNavigationBar: _isSelecting
          ? BulkActionBar(
              selectedCount: _selectedIds.length,
              onMoveToFolder: _moveSelectedToFolder,
              onAddTag: _addTagToSelected,
              onDelete: _deleteSelected,
            )
          : null,

      // 고르는 중에는 추가 버튼을 숨깁니다.
      // 아래 작업 막대와 겹쳐 보이고, 고르는 도중에 새로 추가할 일도 없습니다.
      floatingActionButton: _isSelecting ? null : _buildAddButtons(),
    );
  }

  /// 오른쪽 아래의 추가 버튼들을 만듭니다.
  ///
  /// 유튜브는 작은 버튼으로 이미지 버튼 위에 얹습니다.
  /// 메뉴 안에 감추지 않은 이유: 한 번 더 눌러야 나오는 기능은 잘 안 쓰게 됩니다.
  /// 이미지 쪽을 큰 버튼으로 둔 것은 그쪽이 더 자주 쓰이기 때문입니다.
  Widget _buildAddButtons() {
    // 추가하는 중에는 null을 넣어 버튼을 잠급니다.
    // Flutter에서는 onPressed가 null이면 버튼이 자동으로 비활성화됩니다.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        FloatingActionButton.small(
          heroTag: 'addYoutube',
          onPressed: _isAdding ? null : _addYoutube,
          tooltip: '유튜브 영상 추가',
          child: const Icon(Icons.smart_display_outlined),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          // heroTag를 서로 다르게 줘야 합니다. 화면에 떠 있는 버튼이 둘 이상인데
          // 이름표가 같으면, 화면을 넘나들 때 Flutter가 어느 버튼을 이어서
          // 움직여야 할지 몰라 오류를 냅니다.
          heroTag: 'addImages',
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
      ],
    );
  }

  /// 평소의 위쪽 막대를 만듭니다.
  PreferredSizeWidget _buildNormalAppBar() {
    // 색은 지정하지 않습니다. 테마(app_theme.dart)에 정해둔 것을 씁니다.
    // 여기서 따로 정하면 나중에 앱 색을 바꿀 때 이 줄만 안 바뀌어 튑니다.
    return AppBar(
      title: const Text('레퍼런스 아카이브'),
      actions: <Widget>[
        IconButton(
          // 보여줄 것이 없으면 고를 것도 없으므로 버튼을 잠급니다.
          onPressed: _items.isEmpty ? null : _toggleSelectionMode,
          icon: const Icon(Icons.check_circle_outline),
          tooltip: '여러 장 고르기',
        ),
        IconButton(
          onPressed: _openTaxonomyManage,
          icon: const Icon(Icons.folder_special_outlined),
          tooltip: '분류 관리',
        ),
      ],
    );
  }

  /// 고르는 중일 때의 위쪽 막대를 만듭니다.
  ///
  /// 색과 내용을 통째로 바꿔서 "지금은 평소와 다른 모드"임을 분명히 합니다.
  PreferredSizeWidget _buildSelectionAppBar() {
    final ColorScheme colors = Theme.of(context).colorScheme;

    final bool allSelected =
        _items.isNotEmpty && _selectedIds.length == _items.length;

    return AppBar(
      backgroundColor: colors.primaryContainer,
      foregroundColor: colors.onPrimaryContainer,

      // 왼쪽 X 버튼으로 고르기를 끝냅니다.
      leading: IconButton(
        onPressed: _exitSelectionMode,
        icon: const Icon(Icons.close),
        tooltip: '고르기 끝내기',
      ),

      title: Text(
        _selectedIds.isEmpty ? '고를 카드를 눌러주세요' : '${_selectedIds.length}장 선택',
      ),

      actions: <Widget>[
        IconButton(
          onPressed: _items.isEmpty ? null : _toggleSelectAll,
          icon: Icon(
            allSelected ? Icons.deselect : Icons.select_all,
          ),
          tooltip: allSelected ? '전체 해제' : '전체 선택',
        ),
      ],
    );
  }

  /// 화면 전체를 "끌어다 놓을 수 있는 영역"으로 감쌉니다.
  ///
  /// 끄는 중일 때는 테두리와 안내를 덧그려서 "여기 놓으면 된다"를 알려줍니다.
  /// 아무 표시가 없으면 사용자는 놓아도 되는지 알 수 없습니다.
  Widget _buildDropArea(Widget child) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return DropRegion(
      // 받을 수 있다고 알릴 형식들입니다. 여기 없는 형식은 아예 안 들어옵니다.
      // (앞서 쓰던 desktop_drop은 파일 형식만 받아서 브라우저 드래그가 막혔습니다)
      // 목록 자체는 dropped_item_reader.dart에 있습니다. 받는 쪽과 읽는 쪽이
      // 따로 놀면 "받아는 놓고 읽지 못하는" 형식이 생기기 때문입니다.
      formats: dropRegionFormats,

      // 끌고 지나가는 동안 "복사할 수 있다"고 알려줍니다.
      // none을 돌려주면 커서에 금지 표시가 뜨고 놓을 수 없습니다.
      onDropOver: (DropOverEvent event) => DropOperation.copy,

      onDropEnter: (DropEvent event) {
        setState(() => _isDragging = true);
      },
      onDropLeave: (DropEvent event) {
        setState(() => _isDragging = false);
      },
      onPerformDrop: (PerformDropEvent event) async {
        setState(() => _isDragging = false);
        await _handleDrop(event);
      },
      child: Stack(
        children: <Widget>[
          child,

          // 끄는 중에만 위에 덧그립니다.
          if (_isDragging)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  // 반투명이라 아래 목록이 비쳐 보입니다.
                  color: colors.primary.withValues(alpha: 0.12),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.primary, width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.file_download_outlined,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '여기에 놓으면 레퍼런스로 추가됩니다',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
    final AppPalette palette = AppPalette.of(context);

    final bool isFiltered = _query.hasAnyFilter;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(screenPaddingHorizontal),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              isFiltered ? Icons.search_off : Icons.photo_library_outlined,
              size: 64,

              // 아이콘까지 강조색이면 시선을 너무 끕니다. 안내는 거들 뿐이라
              // 옅게 두고, 눌러야 할 버튼만 또렷하게 남깁니다.
              color: palette.textDim,
            ),
            const SizedBox(height: 24),
            Text(
              isFiltered ? '조건에 맞는 레퍼런스가 없습니다' : '아직 모아둔 레퍼런스가 없습니다',
              style: AppText.emptyTitle.copyWith(color: palette.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isFiltered ? '검색어나 필터를 바꿔보세요.' : '오른쪽 아래 버튼으로 이미지를 추가해보세요.',
              style: AppText.emptyBody.copyWith(color: palette.textDim),
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
    // ── 왜 메이슨리(벽돌 쌓기) 격자인가 ──
    // 보통의 격자는 칸 크기가 정해져 있어서 사진을 그 크기에 맞춰 **잘라냅니다.**
    // 레퍼런스를 모으는 앱에서 사진을 네모로 잘라버리면 구도가 사라집니다.
    //
    // 메이슨리는 칸의 **너비만** 정하고 높이는 사진이 정합니다. 그래서 세로
    // 사진은 길쭉하게, 가로 사진은 납작하게 원본 비율 그대로 쌓입니다.
    // 기존 웹앱이 `column-count`로 하던 것과 같은 모양입니다.
    return MasonryGridView.extent(
      // 아래쪽 여백을 크게 준 이유: 안 그러면 마지막 줄의 카드가
      // 오른쪽 아래 떠 있는 추가 버튼에 가려집니다.
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),

      // maxCrossAxisExtent = "칸 하나의 최대 너비".
      // 개수를 고정하지 않고 너비를 정하면, 창을 넓히면 칸이 늘어나고
      // 폰처럼 좁은 화면에서는 저절로 줄어듭니다. 화면 크기별로 따로
      // 만들지 않아도 되어서 데스크톱과 모바일을 함께 지원하기 좋습니다.
      //
      // 기존 웹앱은 1240px에서 4칸이었습니다. 300px로 잡으면 얼추 같아집니다.
      maxCrossAxisExtent: gridMaxCrossAxisExtent,
      crossAxisSpacing: gridSpacing,
      mainAxisSpacing: gridSpacing,

      itemCount: _items.length,
      itemBuilder: (BuildContext context, int index) {
        final ReferenceItem item = _items[index];
        // 호버 미리보기는 **유튜브 카드**에만, **데스크톱에서만** 붙입니다.
        // null을 넘기면 카드가 호버를 아예 살피지 않습니다.
        final bool canPreview =
            supportsHoverPreview && item.type == ReferenceType.youtube;

        return ReferenceCard(
          item: item,
          imagePath: _imagePaths[item.id],
          onDelete: () => _deleteItem(item),
          onTap: () => _openDetail(item),
          isSelectionMode: _isSelecting,
          isSelected: _selectedIds.contains(item.id),
          onSelectToggle: () => _toggleSelected(item),
          onPlay: () => _playYoutube(item),
          onHoverChanged: canPreview
              ? (bool isHovering) => _onCardHoverChanged(item, isHovering)
              : null,
          isPreviewPlaying: _previewingItemId == item.id,
          previewUrl: _previewUrl,
          taxonomyNames: _taxonomyNames,
        );
      },
    );
  }
}
