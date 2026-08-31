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

import 'dart:io';

import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/reference_item.dart';
import '../models/taxonomy_item.dart';
import '../repositories/reference_repository.dart';
import '../repositories/taxonomy_repository.dart';
import '../services/image_storage.dart';
import '../utils/rich_text_memo.dart';
import '../widgets/rich_memo_editor.dart';
import '../widgets/taxonomy_multi_field.dart';
import '../widgets/taxonomy_single_field.dart';
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

  /// 화면에서 고치는 중인 값들입니다.
  /// 저장을 누르기 전까지는 데이터베이스에 반영되지 않습니다.
  String? _folderId;
  String? _categoryId;
  String? _partId;
  List<String> _tagIds = <String>[];
  List<String> _projectIds = <String>[];
  bool _isFavorite = false;
  bool _isPinned = false;

  /// 고를 수 있는 분류 항목 목록입니다. (종류별로 나눠 담습니다)
  final Map<TaxonomyKind, List<TaxonomyItem>> _taxonomyOptions =
      <TaxonomyKind, List<TaxonomyItem>>{};

  /// 이미지 파일의 전체 경로입니다.
  String? _imagePath;

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
    _folderId = widget.item.folderId;
    _categoryId = widget.item.categoryId;
    _partId = widget.item.partId;
    _tagIds = List<String>.from(widget.item.tagIds);
    _projectIds = List<String>.from(widget.item.projectIds);
    _isFavorite = widget.item.isFavorite;
    _isPinned = widget.item.isPinned;

    _loadOptions();
  }

  /// 화면이 사라질 때 입력창 도구들을 정리합니다.
  /// 안 하면 화면을 닫아도 메모리에 남습니다.
  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  /// 고를 수 있는 분류 항목들과 이미지 경로를 불러옵니다.
  Future<void> _loadOptions() async {
    final Map<TaxonomyKind, List<TaxonomyItem>> loaded =
        <TaxonomyKind, List<TaxonomyItem>>{};

    for (final TaxonomyKind kind in TaxonomyKind.values) {
      loaded[kind] = await widget.taxonomyRepository.getAll(kind);
    }

    String? path;
    final String? fileName = widget.item.fileName;
    if (fileName != null) {
      path = await widget.imageStorage.getFullPath(fileName);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _taxonomyOptions
        ..clear()
        ..addAll(loaded);
      _imagePath = path;
      _isLoading = false;
    });
  }

  /// 한 종류의 분류 항목 목록만 다시 불러옵니다.
  ///
  /// + 버튼으로 새 항목을 만든 직후에 부릅니다.
  /// 전체를 다시 불러올 필요는 없어서 바뀐 종류만 갱신합니다.
  Future<void> _reloadOptionsFor(TaxonomyKind kind) async {
    final List<TaxonomyItem> loaded = await widget.taxonomyRepository.getAll(kind);

    if (!mounted) {
      return;
    }

    setState(() {
      _taxonomyOptions[kind] = loaded;
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
      folderId: _folderId,
      categoryId: _categoryId,
      partId: _partId,
      tagIds: _tagIds,
      projectIds: _projectIds,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(),
    );
  }

  /// 편집 항목들을 세로로 늘어놓습니다.
  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _buildPreview(),
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

        // 파트를 맨 위에 둡니다. 폴더·카테고리보다 큰 갈래라서
        // 위에서 아래로 좁혀지는 순서가 자연스럽습니다.
        TaxonomySingleField(
          kind: TaxonomyKind.part,
          options: _taxonomyOptions[TaxonomyKind.part] ?? <TaxonomyItem>[],
          selectedId: _partId,
          repository: widget.taxonomyRepository,
          onChanged: (String? id) => setState(() => _partId = id),
          onCreated: (TaxonomyItem created) async {
            await _reloadOptionsFor(TaxonomyKind.part);
            if (mounted) {
              setState(() => _partId = created.id);
            }
          },
        ),
        const SizedBox(height: 16),

        TaxonomySingleField(
          kind: TaxonomyKind.folder,
          options: _taxonomyOptions[TaxonomyKind.folder] ?? <TaxonomyItem>[],
          selectedId: _folderId,
          repository: widget.taxonomyRepository,
          onChanged: (String? id) => setState(() => _folderId = id),
          onCreated: (TaxonomyItem created) async {
            await _reloadOptionsFor(TaxonomyKind.folder);
            // 방금 만든 것을 바로 골라줍니다. 또 고르게 하면 번거롭습니다.
            if (mounted) {
              setState(() => _folderId = created.id);
            }
          },
        ),
        const SizedBox(height: 16),

        TaxonomySingleField(
          kind: TaxonomyKind.category,
          options: _taxonomyOptions[TaxonomyKind.category] ?? <TaxonomyItem>[],
          selectedId: _categoryId,
          repository: widget.taxonomyRepository,
          onChanged: (String? id) => setState(() => _categoryId = id),
          onCreated: (TaxonomyItem created) async {
            await _reloadOptionsFor(TaxonomyKind.category);
            if (mounted) {
              setState(() => _categoryId = created.id);
            }
          },
        ),
        const SizedBox(height: 24),

        TaxonomyMultiField(
          kind: TaxonomyKind.tag,
          options: _taxonomyOptions[TaxonomyKind.tag] ?? <TaxonomyItem>[],
          selectedIds: _tagIds,
          repository: widget.taxonomyRepository,
          onChanged: (List<String> ids) => setState(() => _tagIds = ids),
          onCreated: (TaxonomyItem created) async {
            await _reloadOptionsFor(TaxonomyKind.tag);
            if (mounted) {
              setState(() => _tagIds = <String>[..._tagIds, created.id]);
            }
          },
        ),
        const SizedBox(height: 24),

        TaxonomyMultiField(
          kind: TaxonomyKind.project,
          options: _taxonomyOptions[TaxonomyKind.project] ?? <TaxonomyItem>[],
          selectedIds: _projectIds,
          repository: widget.taxonomyRepository,
          onChanged: (List<String> ids) => setState(() => _projectIds = ids),
          onCreated: (TaxonomyItem created) async {
            await _reloadOptionsFor(TaxonomyKind.project);
            if (mounted) {
              setState(() => _projectIds = <String>[..._projectIds, created.id]);
            }
          },
        ),
        const SizedBox(height: 24),

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
      ],
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

  /// 화면 위쪽의 미리보기입니다. 유튜브면 그 위에 재생 버튼이 얹힙니다.
  Widget _buildPreview() {
    final ColorScheme colors = Theme.of(context).colorScheme;

    final bool isYoutube = widget.item.type == ReferenceType.youtube;

    Widget content;
    if (_imagePath == null) {
      // 이미지는 파일이 아직 없는 경우이고,
      // 유튜브는 썸네일을 못 받아온 경우입니다. (인터넷이 없었거나 비공개 영상)
      content = Icon(
        isYoutube ? Icons.play_circle_outline : Icons.image_outlined,
        size: 48,
        color: colors.onSurfaceVariant,
      );
    } else {
      content = Image.file(
        File(_imagePath!),
        fit: BoxFit.contain,
        // 파일이 지워졌거나 깨졌을 때 화면 전체가 오류로 덮이지 않게 합니다.
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          return Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: colors.onSurfaceVariant,
          );
        },
      );
    }

    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: isYoutube
          // 유튜브는 미리보기 위에 재생 버튼을 겹쳐서, 눌러 바로 볼 수 있게 합니다.
          ? Stack(
              children: <Widget>[
                Positioned.fill(child: Center(child: content)),
                Positioned.fill(
                  child: Material(
                    // 투명한 Material 위에 InkWell을 두면 누를 때 물결이 나옵니다.
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _playYoutube,
                      child: Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          size: 72,
                          // 썸네일이 밝든 어둡든 보이도록 흰색에 그림자를 줍니다.
                          color: Colors.white.withValues(alpha: 0.92),
                          shadows: const <Shadow>[
                            Shadow(color: Colors.black54, blurRadius: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Center(child: content),
    );
  }
}
