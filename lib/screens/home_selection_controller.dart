// 목록 화면에서 "여러 장 고르기" 모드의 상태와 동작을 모은 곳입니다.
//
// ── 왜 home_screen.dart에서 뺐나 ──
// board_interaction_controller.dart를 뺀 것과 같은 이유입니다(CLAUDE.md
// "밀린 정리거리" 참고). "지금 고르는 중인지"·"무엇을 골랐는지" 상태와
// 그 상태를 다루는 동작(옮기기·태그 붙이기·지우기)이 함께 다녀야 하는데,
// 함수만 옮기면 상태는 home_screen.dart가 계속 들고 있어야 해서 오히려
// 읽기 어려워집니다. 그래서 상태까지 함께 옮길 작은 클래스를 만들었습니다.
//
// ── ChangeNotifier가 무엇인가 ──
// board_export_controller.dart와 같은 방식입니다. 선택이 바뀌면
// notifyListeners()가 불리고, 이 컨트롤러를 듣고 있는 화면이 저절로
// 다시 그려집니다.

import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/reference_item.dart';
import '../models/taxonomy_item.dart';
import '../repositories/reference_repository.dart';
import '../widgets/pick_taxonomy_dialog.dart';

/// 일괄 작업(폴더 이동/태그 추가/삭제) 하나가 끝난 뒤 화면이 알아야 할 것입니다.
///
/// "무엇을 보여줄지"는 화면(home_screen.dart) 책임으로 남겨둡니다.
/// 이 컨트롤러는 데이터를 실제로 고치는 일과 고르기 모드를 끝내는 일까지만
/// 하고, 화면에는 결과만 돌려줍니다.
class BulkActionOutcome {
  const BulkActionOutcome({this.message, this.shouldReload = false});

  /// 화면 아래에 띄울 안내입니다. null이면 아무것도 안 띄웁니다.
  ///
  /// (예: 대화상자를 그냥 닫아 취소한 경우)
  final String? message;

  /// 데이터가 실제로 바뀌어서 목록을 다시 불러와야 하는지 여부입니다.
  final bool shouldReload;
}

/// "여러 장 고르기" 모드의 상태와 동작을 담습니다.
class HomeSelectionController extends ChangeNotifier {
  /// 지금 여러 장을 고르는 중인지 여부입니다.
  ///
  /// ── 왜 "고른 게 하나라도 있으면 고르기 모드"로 하지 않았나 ──
  /// 그렇게 하면 마지막 한 장의 선택을 풀었을 때 체크박스와 작업 막대가
  /// 통째로 사라집니다. 사용자는 잘못 눌러서 모드가 꺼졌다고 느낍니다.
  /// 그래서 "고르기 모드"와 "무엇을 골랐는지"를 따로 둡니다.
  bool get isSelecting => _isSelecting;
  bool _isSelecting = false;

  /// 지금 골라둔 레퍼런스들의 id입니다.
  ///
  /// List가 아니라 Set인 이유: Set은 같은 값이 두 번 안 들어가고,
  /// "이게 들어있나?"를 확인하는 것이 목록이 길어져도 빠릅니다.
  /// 카드를 그릴 때마다 확인하는 값이라 이 차이가 실제로 체감됩니다.
  Set<String> get selectedIds => _selectedIds;
  final Set<String> _selectedIds = <String>{};

  /// 고르기 모드를 켜거나 끕니다.
  void toggleSelectionMode() {
    _isSelecting = !_isSelecting;

    // 모드를 끄면 골라둔 것도 함께 비웁니다.
    // 안 비우면 다음에 모드를 켤 때 예전 선택이 되살아나 놀라게 됩니다.
    if (!_isSelecting) {
      _selectedIds.clear();
    }

    notifyListeners();
  }

  /// 고르기 모드를 끝내고 골라둔 것을 모두 비웁니다.
  void exitSelectionMode() {
    _isSelecting = false;
    _selectedIds.clear();
    notifyListeners();
  }

  /// 카드 하나를 고르거나 고르기를 취소합니다.
  ///
  /// 고르기 모드가 꺼져 있을 때 불리면(카드를 길게 눌렀을 때) 모드를 켭니다.
  void toggleSelected(String id) {
    _isSelecting = true;

    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }

    notifyListeners();
  }

  /// 지금 보이는 것을 전부 고릅니다. 이미 전부 골랐으면 전부 풉니다.
  void toggleSelectAll(List<ReferenceItem> items) {
    final bool allSelected = _selectedIds.length == items.length;

    _selectedIds.clear();

    if (!allSelected) {
      for (final ReferenceItem item in items) {
        _selectedIds.add(item.id);
      }
    }

    notifyListeners();
  }

  /// 화면에 안 보이게 된 것을 골라둔 목록에서도 뺍니다.
  ///
  /// 예를 들어 세 장을 골라둔 채 검색어를 바꾸면 그중 두 장이 목록에서
  /// 사라질 수 있습니다. 그대로 두면 "1장 골랐다"고 보이는데 실제로는
  /// 3장이 지워지는, 사용자가 예상할 수 없는 일이 벌어집니다.
  void pruneSelection(List<ReferenceItem> visibleItems) {
    final int before = _selectedIds.length;

    _selectedIds.removeWhere((String id) {
      return !visibleItems.any((ReferenceItem item) => item.id == id);
    });

    if (_selectedIds.length != before) {
      notifyListeners();
    }
  }

  /// 골라둔 것들을 한 폴더로 옮깁니다.
  Future<BulkActionOutcome> moveToFolder({
    required BuildContext context,
    required ReferenceRepository repository,
    required List<TaxonomyItem> folders,
  }) async {
    // 폴더가 하나도 없으면 고를 것이 없습니다.
    // "폴더 없음"만 덩그러니 뜨는 대화상자보다, 무엇을 하면 되는지 알려줍니다.
    if (folders.isEmpty) {
      return const BulkActionOutcome(
        message: '먼저 오른쪽 위 "분류 관리"에서 폴더를 만들어주세요.',
      );
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
      return const BulkActionOutcome();
    }

    // picked.item이 null이면 "폴더에서 빼기"입니다. 취소와는 다릅니다.
    await repository.moveManyToFolder(_selectedIds.toList(), picked.item?.id);

    final String where = picked.item == null
        ? '폴더에서 빼냈습니다'
        : '"${picked.item!.name}"으로 옮겼습니다';

    exitSelectionMode();
    return BulkActionOutcome(message: '$count장을 $where.', shouldReload: true);
  }

  /// 골라둔 것들에 태그를 붙입니다.
  Future<BulkActionOutcome> addTag({
    required BuildContext context,
    required ReferenceRepository repository,
    required List<TaxonomyItem> tags,
  }) async {
    if (tags.isEmpty) {
      return const BulkActionOutcome(
        message: '먼저 오른쪽 위 "분류 관리"에서 태그를 만들어주세요.',
      );
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
      return const BulkActionOutcome();
    }

    await repository.addTaxonomyItemToMany(_selectedIds.toList(), picked.item!.id);

    exitSelectionMode();
    return BulkActionOutcome(
      message: '$count장에 "${picked.item!.name}" 태그를 붙였습니다.',
      shouldReload: true,
    );
  }

  /// 골라둔 것들을 한꺼번에 지웁니다.
  Future<BulkActionOutcome> delete({
    required BuildContext context,
    required ReferenceRepository repository,
  }) async {
    final int count = _selectedIds.length;

    final bool confirmed = await _confirmBulkDelete(context, count);
    if (!confirmed) {
      return const BulkActionOutcome();
    }

    await repository.deleteMany(_selectedIds.toList());

    exitSelectionMode();
    return BulkActionOutcome(message: '$count장을 지웠습니다.', shouldReload: true);
  }

  /// 여러 장을 정말 지울지 확인받습니다.
  ///
  /// 낱장 삭제에는 확인이 없지만 여기에는 둡니다. 한 장을 잘못 지우는 것과
  /// 50장을 잘못 지우는 것은 되돌리는 수고가 완전히 다르기 때문입니다.
  Future<bool> _confirmBulkDelete(BuildContext context, int count) async {
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
}
