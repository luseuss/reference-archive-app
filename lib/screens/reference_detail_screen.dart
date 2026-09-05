// 레퍼런스 한 건을 자세히 보고 고치는 화면입니다.
//
// 목록에서 카드를 누르면 이 화면이 열립니다.
// 제목·메모를 고치고, 폴더·카테고리·태그·프로젝트를 지정하고,
// 즐겨찾기/고정을 켜고 끌 수 있습니다.
//
// ── 저장 시점 ──
// 고칠 때마다 바로 저장하지 않고, 오른쪽 위 "저장"을 눌렀을 때 한 번에 저장합니다.
// 타이핑할 때마다 저장하면 데이터베이스를 계속 건드리게 되고,
// 사용자가 "역시 그만둘래" 하고 나갈 방법도 없어집니다.

import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/reference_item.dart';
import '../repositories/reference_repository.dart';
import '../repositories/taxonomy_repository.dart';
import '../services/image_storage.dart';
import '../services/reference_lookup.dart';
import '../utils/rich_text_memo.dart';
import '../utils/similarity.dart';
import '../widgets/reference_detail_preview.dart';
import '../widgets/reference_detail_taxonomy_fields.dart';
import '../widgets/rich_memo_editor.dart';
import '../widgets/similar_references_section.dart';
import 'reference_taxonomy_edit_controller.dart';
import 'youtube_player_screen.dart';

/// 레퍼런스 상세/편집 화면입니다.
class ReferenceDetailScreen extends StatefulWidget {
  const ReferenceDetailScreen({
    super.key,
    required this.item,
    required this.referenceRepository,
    required this.taxonomyRepository,
    required this.imageStorage,
  });

  /// 고칠 레퍼런스입니다.
  final ReferenceItem item;

  final ReferenceRepository referenceRepository;
  final TaxonomyRepository taxonomyRepository;
  final ImageStorage imageStorage;

  @override
  State<ReferenceDetailScreen> createState() => _ReferenceDetailScreenState();
}

class _ReferenceDetailScreenState extends State<ReferenceDetailScreen> {
  /// 제목 입력창을 다루는 도구입니다.
  late final TextEditingController _titleController;

  /// 지금 편집기에 있는 메모입니다(Delta JSON 문자열). RichMemoEditor의
  /// onChanged가 부를 때마다 갱신됩니다. 저장을 누를 때만 실제로 씁니다.
  String? _memoJson;

  /// 파트·폴더·카테고리·태그·프로젝트를 고르는 부분의 상태와 동작을
  /// 담고 있습니다. (reference_taxonomy_edit_controller.dart 참고)
  final ReferenceTaxonomyEditController _taxonomyEdit =
      ReferenceTaxonomyEditController();

  /// 즐겨찾기·고정은 분류 항목이 아니라 별도로 둡니다.
  /// 저장을 누르기 전까지는 데이터베이스에 반영되지 않습니다.
  bool _isFavorite = false;
  bool _isPinned = false;

  /// 이미지 파일의 전체 경로입니다.
  String? _imagePath;

  /// 이 레퍼런스와 비슷한 것들입니다. (lib/utils/similarity.dart의 similarItems)
  ///
  /// 화면을 열 때 딱 한 번 계산합니다. 편집하는 동안 계속 다시 계산하지
  /// 않습니다 — 태그를 하나 고를 때마다 목록이 바뀌면 산만하고, 애초에
  /// "저장을 누르기 전까지는 반영 안 함"이라는 이 화면의 원칙과도
  /// 어긋납니다(맨 위 "저장 시점" 설명 참고).
  List<ReferenceItem> _similarItems = <ReferenceItem>[];

  /// 비슷한 레퍼런스들의 그림 경로입니다. (id → 경로)
  Map<String, String?> _similarImagePaths = <String, String?>{};

  /// 분류 항목 목록을 불러오는 중인지 여부입니다.
  bool _isLoading = true;

  /// 저장하는 중인지 여부입니다.
  bool _isSaving = false;

  /// 화면이 처음 만들어질 때 딱 한 번 실행됩니다.
  @override
  void initState() {
    super.initState();

    // 넘겨받은 레퍼런스의 값으로 화면을 채웁니다.
    _titleController = TextEditingController(text: widget.item.title);
    _memoJson = widget.item.memo;
    _taxonomyEdit.initFrom(widget.item);
    _isFavorite = widget.item.isFavorite;
    _isPinned = widget.item.isPinned;

    _loadOptions();
  }

  /// 화면이 사라질 때 만들어둔 것들을 정리합니다.
  /// 안 하면 화면을 닫아도 메모리에 남습니다.
  @override
  void dispose() {
    _titleController.dispose();
    _taxonomyEdit.dispose();
    super.dispose();
  }

  /// 고를 수 있는 분류 항목들, 이미지 경로, 비슷한 레퍼런스를 불러옵니다.
  Future<void> _loadOptions() async {
    await _taxonomyEdit.load(widget.taxonomyRepository);

    String? path;
    final String? fileName = widget.item.fileName;
    if (fileName != null) {
      path = await widget.imageStorage.getFullPath(fileName);
    }

    // ── 비슷한 레퍼런스를 찾으려면 전부 읽어야 합니다 ──
    // "이 레퍼런스와 저 레퍼런스가 얼마나 비슷한가"는 데이터베이스가 대신
    // 계산해줄 수 없어서(SQL로 표현이 안 됨), 후보 전부를 손에 들고 있어야
    // 합니다. ReferenceLookup이 그 전부와 그림 경로를 한 번에 구해줍니다
    // (services/reference_lookup.dart) — 판·레퍼런스 고르는 창과 같은 도구입니다.
    final ReferenceLookup lookup = await ReferenceLookup.load(
      repository: widget.referenceRepository,
      imageStorage: widget.imageStorage,
    );
    final List<ReferenceItem> similar = similarItems(
      widget.item,
      lookup.items,
      limit: similarReferencesLimit,
      minScore: similarReferencesThreshold,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _imagePath = path;
      _similarItems = similar;
      _similarImagePaths = lookup.imagePaths;
      _isLoading = false;
    });
  }

  /// 고친 내용을 저장하고 이전 화면으로 돌아갑니다.
  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });

    // 메모는 비어 있으면 null로 저장합니다.
    // 빈 글자와 "적지 않음"을 굳이 구분할 이유가 없습니다. RichMemoEditor는
    // 빈 문서여도 항상 뭔가(최소한의 Delta)를 돌려주므로, 순수 글자만
    // 뽑아봐서 비어 있는지 판단합니다.
    final String? memoJson = _memoJson;
    final bool memoIsEmpty =
        memoJson == null || plainTextFromMemo(memoJson).isEmpty;

    // ── 여기서 copyWith를 쓰지 않는 이유 (중요) ──
    // copyWith는 넘긴 값이 null이면 "안 바꿈"으로 취급합니다. 그래서
    // copyWith(memo: null)로는 메모를 지울 수 없습니다. 원래 메모가 그대로 남습니다.
    // (자세한 설명은 lib/models/reference_item.dart의 copyWith 주석 참고)
    //
    // 이 화면은 폴더·카테고리·메모를 **비우는 것도** 정상적인 편집이라,
    // copyWith를 쓰면 "이 값도 비우는 처리를 했던가?"를 매번 신경 써야 하고
    // 언젠가 반드시 하나를 빠뜨리게 됩니다.
    //
    // 그래서 모든 값을 하나하나 적는 생성자로 새로 만듭니다. 길지만,
    // 빠뜨린 값이 있으면 컴파일이 안 되므로 실수할 여지가 없습니다.
    final ReferenceItem updated = ReferenceItem(
      // 아래 세 값은 사용자가 바꿀 수 없는 값이라 원래 것을 그대로 씁니다.
      id: widget.item.id,
      type: widget.item.type,
      createdAt: widget.item.createdAt,

      // updatedAt은 저장소가 알아서 지금 시각으로 갱신하므로 원래 값을 넘깁니다.
      updatedAt: widget.item.updatedAt,

      fileName: widget.item.fileName,
      youtubeVideoId: widget.item.youtubeVideoId,
      pHash: widget.item.pHash,

      // 아래부터가 이 화면에서 고친 값들입니다.
      title: _titleController.text.trim(),
      memo: memoIsEmpty ? null : memoJson,
      folderId: _taxonomyEdit.folderId,
      categoryId: _taxonomyEdit.categoryId,
      partId: _taxonomyEdit.partId,
      tagIds: _taxonomyEdit.tagIds,
      projectIds: _taxonomyEdit.projectIds,
      isFavorite: _isFavorite,
      isPinned: _isPinned,
    );

    await widget.referenceRepository.save(updated);

    if (!mounted) {
      return;
    }

    // true를 돌려주면 목록 화면이 "바뀐 게 있으니 다시 불러와야겠다"를 압니다.
    Navigator.of(context).pop(true);
  }

  /// 화면의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('레퍼런스 편집'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: (_isLoading || _isSaving) ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('저장'),
            ),
          ),
        ],
      ),
      // ListenableBuilder = _taxonomyEdit가 바뀌면 이 안을 다시 그려주는
      // 위젯입니다. home_screen.dart가 컨트롤러를 쓰는 것과 같은 방식입니다.
      body: ListenableBuilder(
        listenable: _taxonomyEdit,
        builder: (BuildContext context, Widget? _) {
          return _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildForm();
        },
      ),
    );
  }

  /// 편집 항목들을 세로로 늘어놓습니다.
  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        ReferenceDetailPreview(
          imagePath: _imagePath,
          isYoutube: widget.item.type == ReferenceType.youtube,
          onPlay: _playYoutube,
        ),
        const SizedBox(height: 24),

        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: '제목',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        Text('메모', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        RichMemoEditor(
          // widget.item.memo가 아니라 _memoJson을 넘깁니다. 이 편집기는 ListView
          // 안에 있어서, 포커스를 잃은 채로 화면 밖으로 스크롤되면 통째로 사라졌다
          // 다시 만들어집니다. 그때 원본(widget.item.memo)을 다시 넘기면 지금까지
          // 고친 내용이 사라진 것처럼 보입니다.
          //
          // RichMemoEditor는 다시 만들어질 때마다 그 순간의 initialMemo로
          // 새로 채워집니다(test/widgets/rich_memo_editor_test.dart의 "다시
          // 만들어지면 그 시점의 initialMemo로 새로 채워진다" 참고) — 그래서
          // 여기서 어떤 값을 넘기느냐가 전부입니다. onChanged로 _memoJson을
          // 최신으로 유지해두는 것만으로는 부족하고, 이 위젯을 담고 있는
          // ReferenceDetailScreen 자체가 다시 빌드돼야(예: 폴더를 고르거나
          // 즐겨찾기를 누르는 등 다른 setState) 그 최신 _memoJson이 이
          // RichMemoEditor 위젯에 실제로 실립니다 — 타이핑만으로는 이 화면이
          // 다시 빌드되지 않기 때문입니다(_save를 누르기 전까지는 setState를
          // 부르지 않는 설계, 위 "저장 시점" 설명 참고).
          initialMemo: _memoJson,
          onChanged: (String updated) => _memoJson = updated,
        ),
        const SizedBox(height: 24),

        ReferenceDetailTaxonomyFields(
          controller: _taxonomyEdit,
          repository: widget.taxonomyRepository,
        ),

        SwitchListTile(
          value: _isFavorite,
          onChanged: (bool value) => setState(() => _isFavorite = value),
          title: const Text('즐겨찾기'),
          secondary: const Icon(Icons.star_outline),
        ),
        SwitchListTile(
          value: _isPinned,
          onChanged: (bool value) => setState(() => _isPinned = value),
          title: const Text('맨 위에 고정'),
          subtitle: const Text('정렬 방식과 상관없이 목록 맨 앞에 옵니다'),
          secondary: const Icon(Icons.push_pin_outlined),
        ),
        const SizedBox(height: 24),

        // 맨 아래에 둡니다. 편집 항목들이 "이 레퍼런스 자체"에 대한 것이라면
        // 이건 "이 레퍼런스 주변"에 대한 것이라, 성격이 다른 참고 자료로
        // 취급해 가장 뒤에 배치했습니다.
        SimilarReferencesSection(
          items: _similarItems,
          imagePaths: _similarImagePaths,
          onTap: _openSimilar,
        ),
      ],
    );
  }

  /// 비슷한 레퍼런스를 눌렀을 때, 그 레퍼런스의 상세 화면을 새로 엽니다.
  ///
  /// 지금 화면을 대신하지 않고 **위에 쌓습니다**(push). 유튜브 재생 버튼과
  /// 같은 방식입니다 — "돌아가기"를 누르면 원래 보던 레퍼런스로 그대로
  /// 돌아와야 하고, 지금 화면에서 고치던 내용도 사라지면 안 됩니다.
  Future<void> _openSimilar(ReferenceItem similar) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => ReferenceDetailScreen(
          item: similar,
          referenceRepository: widget.referenceRepository,
          taxonomyRepository: widget.taxonomyRepository,
          imageStorage: widget.imageStorage,
        ),
      ),
    );
  }

  /// 유튜브 재생 화면을 엽니다.
  ///
  /// 편집 화면에서도 바로 볼 수 있어야 합니다. 안 그러면 "이게 무슨 영상이었지?"를
  /// 확인하려고 목록으로 나갔다 다시 들어와야 합니다.
  Future<void> _playYoutube() async {
    final String? videoId = widget.item.youtubeVideoId;
    if (videoId == null) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => YoutubePlayerScreen(
          videoId: videoId,
          // 저장된 제목이 아니라 지금 입력창에 있는 제목을 보여줍니다.
          // 제목을 고치는 중이라면 고친 쪽이 사용자가 기대하는 값입니다.
          title: _titleController.text.trim(),
        ),
      ),
    );
  }

}
