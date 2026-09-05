// 레퍼런스 편집 화면에서 "분류 항목(파트·폴더·카테고리·태그·프로젝트)을
// 고르는 부분"의 상태와 동작을 모은 곳입니다.
//
// ── 왜 reference_detail_screen.dart에서 뺐나 ──
// home_selection_controller.dart를 뺀 것과 같은 이유입니다(CLAUDE.md
// "밀린 정리거리" 참고). "지금 무엇을 골랐는지" 상태 다섯 개(파트·폴더·
// 카테고리·태그·프로젝트)와, 그것들을 불러오고 바꾸는 동작이 함께 다녀야
// 하는데, 화면 하나에 다 있으면 "이 화면이 하는 일" 중 어디까지가 분류
// 항목 이야기인지 한눈에 안 들어옵니다.
//
// ── ChangeNotifier가 무엇인가 ──
// home_selection_controller.dart와 같은 방식입니다. 고른 것이 바뀌면
// notifyListeners()가 불리고, 화면이 저절로 다시 그려집니다.
//
// ── 이 컨트롤러가 안 하는 일 ──
// 이미지 경로를 불러오거나 "비슷한 레퍼런스"를 계산하는 일은 분류 항목과
// 상관없는 별개의 관심사라 그대로 화면(reference_detail_screen.dart)에
// 남겨뒀습니다.

import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/reference_item.dart';
import '../models/taxonomy_item.dart';
import '../repositories/taxonomy_repository.dart';

/// 레퍼런스 편집 화면의 분류 항목 선택 상태와 동작을 담습니다.
class ReferenceTaxonomyEditController extends ChangeNotifier {
  /// 이 컨트롤러가 이미 dispose됐는지 여부입니다.
  ///
  /// home_hover_preview_controller.dart의 `_disposed`와 같은 역할입니다.
  /// 데이터베이스를 읽는 사이에 화면이 닫혔으면 notifyListeners()를
  /// 부르면 안 되므로 여기서 막습니다.
  bool _disposed = false;

  /// 고를 수 있는 분류 항목 목록입니다. (종류별로 나눠 담습니다)
  Map<TaxonomyKind, List<TaxonomyItem>> get options => _options;
  final Map<TaxonomyKind, List<TaxonomyItem>> _options =
      <TaxonomyKind, List<TaxonomyItem>>{};

  String? get folderId => _folderId;
  String? _folderId;

  String? get categoryId => _categoryId;
  String? _categoryId;

  String? get partId => _partId;
  String? _partId;

  List<String> get tagIds => _tagIds;
  List<String> _tagIds = <String>[];

  List<String> get projectIds => _projectIds;
  List<String> _projectIds = <String>[];

  /// [item]에 저장돼 있던 값으로 고른 것들을 채웁니다.
  ///
  /// 편집 화면이 열릴 때 딱 한 번만 부릅니다. 여기서 새로 List를 만드는
  /// 이유는 item.tagIds를 그대로 들고 있으면, 사용자가 태그를 고를 때마다
  /// item(원본, 저장 전) 쪽 값까지 바뀐 것처럼 보일 수 있기 때문입니다.
  void initFrom(ReferenceItem item) {
    _folderId = item.folderId;
    _categoryId = item.categoryId;
    _partId = item.partId;
    _tagIds = List<String>.from(item.tagIds);
    _projectIds = List<String>.from(item.projectIds);
  }

  /// 분류 항목 전체 종류를 데이터베이스에서 불러옵니다.
  Future<void> load(TaxonomyRepository repository) async {
    final Map<TaxonomyKind, List<TaxonomyItem>> loaded =
        <TaxonomyKind, List<TaxonomyItem>>{};

    for (final TaxonomyKind kind in TaxonomyKind.values) {
      loaded[kind] = await repository.getAll(kind);
    }

    if (_disposed) {
      return;
    }

    _options
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  /// 한 종류의 분류 항목 목록만 다시 불러옵니다.
  ///
  /// + 버튼으로 새 항목을 만든 직후에 부릅니다.
  /// 전체를 다시 불러올 필요는 없어서 바뀐 종류만 갱신합니다.
  Future<void> reloadFor(TaxonomyRepository repository, TaxonomyKind kind) async {
    final List<TaxonomyItem> loaded = await repository.getAll(kind);

    if (_disposed) {
      return;
    }

    _options[kind] = loaded;
    notifyListeners();
  }

  /// 폴더를 고릅니다. null이면 "없음"입니다.
  void setFolder(String? id) {
    _folderId = id;
    notifyListeners();
  }

  /// 카테고리를 고릅니다. null이면 "없음"입니다.
  void setCategory(String? id) {
    _categoryId = id;
    notifyListeners();
  }

  /// 파트를 고릅니다. null이면 "없음"입니다.
  void setPart(String? id) {
    _partId = id;
    notifyListeners();
  }

  /// 태그 목록을 통째로 바꿉니다.
  void setTags(List<String> ids) {
    _tagIds = ids;
    notifyListeners();
  }

  /// 프로젝트 목록을 통째로 바꿉니다.
  void setProjects(List<String> ids) {
    _projectIds = ids;
    notifyListeners();
  }

  /// [kind] 종류의 분류 항목을 새로 만든 직후 부릅니다.
  ///
  /// 목록을 다시 불러오고, 방금 만든 항목을 바로 골라줍니다. 또 고르게
  /// 하면 번거롭습니다. 파트·폴더·카테고리는 하나만 고르는 값이라 그냥
  /// 바꿔치기하고, 태그·프로젝트는 여러 개를 고르는 값이라 목록 맨 뒤에
  /// 더합니다.
  Future<void> handleCreated(
    TaxonomyRepository repository,
    TaxonomyKind kind,
    TaxonomyItem created,
  ) async {
    await reloadFor(repository, kind);

    if (_disposed) {
      return;
    }

    switch (kind) {
      case TaxonomyKind.part:
        _partId = created.id;
        break;
      case TaxonomyKind.folder:
        _folderId = created.id;
        break;
      case TaxonomyKind.category:
        _categoryId = created.id;
        break;
      case TaxonomyKind.tag:
        _tagIds = <String>[..._tagIds, created.id];
        break;
      case TaxonomyKind.project:
        _projectIds = <String>[..._projectIds, created.id];
        break;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
