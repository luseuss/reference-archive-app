// 이미 만들어둔 분류 항목 중에서 하나를 고르는 작은 대화상자입니다.
//
// 여러 장을 골라 "폴더 이동"이나 "태그 추가"를 할 때 "어느 폴더로?", "어느 태그를?"을
// 물어보는 데 씁니다. 폴더든 태그든 하는 일은 "목록에서 하나 고르기"로 같아서
// 하나로 만들어 돌려씁니다.
//
// 새로 만드는 대화상자는 create_taxonomy_dialog.dart에 따로 있습니다.
// 여기서는 **고르기만** 합니다.

import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/taxonomy_item.dart';

/// 분류 항목을 고른 결과입니다.
///
/// ── 왜 그냥 TaxonomyItem?을 돌려주지 않는가 ──
/// 폴더 고르기에는 "폴더 없음"이라는 선택지가 있습니다. 그런데 대화상자를
/// 그냥 닫은 것(취소)도 null입니다. 둘 다 null로 돌려주면 화면 코드가
/// **"취소했다"와 "폴더에서 빼달라고 했다"를 구분할 수 없습니다.**
///
/// 그래서 취소는 결과 자체를 null로, "없음"을 고른 것은 이 클래스의
/// [item]이 null인 것으로 구분합니다.
class PickedTaxonomy {
  const PickedTaxonomy(this.item);

  /// 고른 항목입니다. "없음"을 골랐으면 null입니다.
  final TaxonomyItem? item;
}

/// 분류 항목 하나를 고르는 대화상자를 띄웁니다.
///
/// 고르면 [PickedTaxonomy]를, 취소하면 null을 돌려줍니다.
/// [allowNone]을 켜면 "폴더 없음" 같은 선택지가 맨 위에 함께 나옵니다.
Future<PickedTaxonomy?> showPickTaxonomyDialog({
  required BuildContext context,
  required TaxonomyKind kind,
  required List<TaxonomyItem> items,
  required String title,
  bool allowNone = false,
}) {
  return showDialog<PickedTaxonomy>(
    context: context,
    builder: (BuildContext context) {
      return _PickTaxonomyDialog(
        kind: kind,
        items: items,
        title: title,
        allowNone: allowNone,
      );
    },
  );
}

/// 목록에서 분류 항목 하나를 고르는 대화상자입니다.
///
/// 고르는 즉시 닫히기 때문에 따로 상태를 들고 있을 필요가 없습니다.
/// 그래서 StatefulWidget이 아니라 StatelessWidget입니다.
class _PickTaxonomyDialog extends StatelessWidget {
  const _PickTaxonomyDialog({
    required this.kind,
    required this.items,
    required this.title,
    required this.allowNone,
  });

  /// 고르는 대상이 폴더인지 태그인지 등을 나타냅니다. 안내 문구에 씁니다.
  final TaxonomyKind kind;

  /// 고를 수 있는 항목들입니다.
  final List<TaxonomyItem> items;

  /// 대화상자 제목입니다. ("3장을 옮길 폴더" 처럼 개수를 넣어 부릅니다)
  final String title;

  /// "없음" 선택지를 함께 보여줄지 여부입니다.
  final bool allowNone;

  /// 대화상자의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),

      // contentPadding을 줄인 이유: 목록 항목은 자기 여백을 이미 갖고 있어서
      // 기본 여백을 그대로 두면 좌우가 지나치게 넓어 보입니다.
      contentPadding: const EdgeInsets.only(top: 12, bottom: 8),

      content: SizedBox(
        // 너비를 정해주지 않으면 항목 이름 길이에 따라 대화상자 폭이 들쭉날쭉합니다.
        width: 320,
        child: _buildOptionList(context),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
      ],
    );
  }

  /// 고를 수 있는 항목들을 세로 목록으로 만듭니다.
  Widget _buildOptionList(BuildContext context) {
    final List<Widget> options = <Widget>[];

    if (allowNone) {
      options.add(
        ListTile(
          leading: const Icon(Icons.folder_off_outlined),
          title: Text('${kind.displayName} 없음'),
          onTap: () {
            // item이 null인 결과 = "없음으로 만들어달라"는 뜻입니다.
            Navigator.of(context).pop(const PickedTaxonomy(null));
          },
        ),
      );
      options.add(const Divider(height: 1));
    }

    for (final TaxonomyItem item in items) {
      options.add(
        ListTile(
          leading: const Icon(Icons.label_outline),
          title: Text(item.name),
          onTap: () {
            Navigator.of(context).pop(PickedTaxonomy(item));
          },
        ),
      );
    }

    // shrinkWrap: true = "목록 높이를 내용에 맞게 줄여라".
    // 안 주면 목록이 무한한 높이를 차지하려 해서 대화상자 안에서 오류가 납니다.
    return ListView(shrinkWrap: true, children: options);
  }
}
