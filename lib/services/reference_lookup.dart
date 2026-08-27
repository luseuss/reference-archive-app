// 레퍼런스 전부를 한 번에 읽어서 "번호로 바로 찾을 수 있는 표"로 만들어두는 도구입니다.
//
// ── 왜 필요한가 ──
// 무드보드 카드에는 레퍼런스의 **번호만** 들어있습니다. 제목과 그림을 보여주려면
// 그 번호로 레퍼런스를 찾아야 하는데, 카드를 그릴 때마다 데이터베이스에 물어보면
// 카드가 30장일 때 30번 오갑니다. 그러면 판이 눈에 띄게 버벅입니다.
//
// 그래서 화면을 열 때 **한 번에 다 읽어와** 표로 만들어두고, 찾는 일은 앱 안에서 끝냅니다.
//
// ── 그림 경로도 함께 구해둡니다 ──
// 데이터베이스에는 파일 이름만 들어있어서(설계 원칙 4-4), 화면에 띄우려면
// 실제 경로가 필요합니다. 그 경로를 묻는 일도 카드를 그리는 도중에 하면
// 스크롤할 때마다 멈칫거립니다.
//
// 무드보드 판(board_screen.dart)과 레퍼런스 고르는 창(pick_references_dialog.dart)이
// 똑같은 일을 하고 있어서 여기로 모았습니다.

import '../models/reference_item.dart';
import '../repositories/reference_repository.dart';
import 'image_storage.dart';

/// 레퍼런스를 번호로 바로 찾을 수 있게 정리해둔 것입니다.
class ReferenceLookup {
  const ReferenceLookup({
    required this.items,
    required this.itemsById,
    required this.imagePaths,
  });

  /// 아무것도 없는 상태입니다. 아직 읽어오기 전에 씁니다.
  ///
  /// null을 쓰지 않는 이유: 화면 곳곳에서 "아직 null인가?"를 확인해야 하고,
  /// 한 군데라도 빠뜨리면 앱이 죽습니다. 빈 표는 그냥 아무것도 못 찾을 뿐입니다.
  const ReferenceLookup.empty()
    : items = const <ReferenceItem>[],
      itemsById = const <String, ReferenceItem>{},
      imagePaths = const <String, String?>{};

  /// 레퍼런스 전부입니다. 저장소가 정해준 순서 그대로입니다.
  final List<ReferenceItem> items;

  /// 번호로 레퍼런스를 찾는 표입니다. (id → ReferenceItem)
  final Map<String, ReferenceItem> itemsById;

  /// 번호로 이미지 파일의 전체 경로를 찾는 표입니다. (id → 경로)
  ///
  /// 유튜브도 여기 들어옵니다. 썸네일을 내려받아 파일로 저장해두기 때문입니다.
  /// 파일 이름이 없는 레퍼런스는 아예 안 들어있습니다.
  final Map<String, String?> imagePaths;

  /// 레퍼런스를 전부 읽어서 표를 만들어 돌려줍니다.
  ///
  /// 시간이 걸리는 일이라 Future입니다. 부르는 쪽에서 await로 기다렸다가,
  /// **기다리는 사이에 화면이 사라지지 않았는지(mounted) 확인한 뒤** 쓰세요.
  static Future<ReferenceLookup> load({
    required ReferenceRepository repository,
    required ImageStorage imageStorage,
  }) async {
    final List<ReferenceItem> items = await repository.getAll();

    final Map<String, ReferenceItem> itemsById = <String, ReferenceItem>{};
    final Map<String, String?> imagePaths = <String, String?>{};

    for (final ReferenceItem item in items) {
      itemsById[item.id] = item;

      final String? fileName = item.fileName;
      if (fileName != null) {
        imagePaths[item.id] = await imageStorage.getFullPath(fileName);
      }
    }

    return ReferenceLookup(
      items: items,
      itemsById: itemsById,
      imagePaths: imagePaths,
    );
  }
}
