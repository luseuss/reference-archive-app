// 휴지통(지운 레퍼런스)의 상태와 동작을 모은 곳입니다.
//
// ── 왜 컨트롤러가 따로 있나 ──
// home_selection_controller.dart와 같은 이유입니다. "휴지통에 지금 무엇이
// 들어있나" 상태와 그것을 다루는 동작(되살리기·영영 지우기·비우기)이 함께
// 다녀야 하는데, 함수만 화면에 두면 상태는 화면이 계속 들고 있어야 해서
// 오히려 읽기 어려워집니다.
//
// ── 여기서 저장소와 사진 파일을 함께 다루는 이유 ──
// 이 프로젝트는 **저장소(repositories/)는 데이터베이스만, 사진 파일은
// services/** 가 다루도록 나눠져 있습니다. "영영 지우기"는 그 둘을 다
// 해야 하는 일이라, 둘을 아는 자리가 필요합니다. 새 레퍼런스를 들여올 때
// reference_importer.dart가 같은 방식으로 둘을 조합합니다.
//
// ── ChangeNotifier가 무엇인가 ──
// "값이 바뀌었다"고 화면에 알려주는 Flutter의 기본 장치입니다.
// board_export_controller.dart와 같은 방식입니다.

import 'package:flutter/foundation.dart';

import '../models/reference_item.dart';
import '../repositories/reference_repository.dart';
import '../services/image_storage.dart';

/// 휴지통의 상태와 동작을 담습니다.
class TrashController extends ChangeNotifier {
  TrashController({required this.repository, required this.imageStorage});

  /// 레퍼런스를 읽고 쓰는 통로입니다.
  final ReferenceRepository repository;

  /// 사진 파일을 지울 때 씁니다. 영영 지울 때만 필요합니다.
  final ImageStorage imageStorage;

  /// 지금 휴지통에 들어있는 것들입니다. 최근에 지운 순서입니다.
  List<ReferenceItem> get items => _items;
  List<ReferenceItem> _items = <ReferenceItem>[];

  /// 레퍼런스 번호 → 그 사진 파일의 전체 경로입니다.
  ///
  /// 데이터베이스에는 파일 이름만 있어서(설계 원칙 4-4) 화면에 띄우려면
  /// 실제 경로가 필요합니다. 화면이 카드마다 따로 물어보면 그릴 때마다
  /// 기다리게 되므로, 목록을 읽을 때 한 번에 구해둡니다
  /// (services/reference_lookup.dart와 같은 방식입니다).
  Map<String, String?> get imagePaths => _imagePaths;
  Map<String, String?> _imagePaths = <String, String?>{};

  /// 아직 목록을 읽어오는 중인지 여부입니다.
  bool get isLoading => _isLoading;
  bool _isLoading = true;

  /// 휴지통이 비어 있는지 여부입니다. 안내 문구를 띄울지 정하는 데 씁니다.
  bool get isEmpty => _items.isEmpty;

  /// 휴지통 목록을 읽어옵니다. 화면을 열 때와 무언가 바뀔 때마다 부릅니다.
  Future<void> load() async {
    final List<ReferenceItem> items = await repository.getDeleted();

    final Map<String, String?> paths = <String, String?>{};
    for (final ReferenceItem item in items) {
      final String? fileName = item.fileName;
      if (fileName != null) {
        paths[item.id] = await imageStorage.getFullPath(fileName);
      }
    }

    _items = items;
    _imagePaths = paths;
    _isLoading = false;
    notifyListeners();
  }

  /// 지운 레퍼런스 하나를 되살립니다.
  ///
  /// 사진 파일은 애초에 안 지워져 있으므로 여기서 할 일이 없습니다.
  /// 폴더·태그와 무드보드 카드도 저절로 따라옵니다(저장소 restore 설명 참고).
  Future<void> restore(ReferenceItem item) async {
    await repository.restore(item.id);
    await load();
  }

  /// 레퍼런스 하나를 영영 지웁니다. 되돌릴 수 없습니다.
  ///
  /// **사진 파일을 데이터베이스보다 먼저 지웁니다.** 순서를 뒤집으면,
  /// 데이터베이스에서 지운 뒤 파일 지우기가 실패했을 때 **어느 파일이
  /// 버려진 것인지 알 방법이 사라집니다**(그 파일을 가리키던 줄이 이미
  /// 없으니까요). 지금 순서라면 실패해도 휴지통에 그대로 남아서 다시
  /// 시도할 수 있습니다.
  Future<void> purge(ReferenceItem item) async {
    await _deleteImageFile(item);
    await repository.purge(item.id);
    await load();
  }

  /// 휴지통을 통째로 비웁니다. 되돌릴 수 없습니다.
  Future<void> purgeAll() async {
    for (final ReferenceItem item in _items) {
      await _deleteImageFile(item);
    }

    await repository.purgeAll();
    await load();
  }

  /// 레퍼런스에 딸린 사진 파일을 지웁니다. 파일이 없으면 아무 일도 안 합니다.
  ///
  /// 유튜브 레퍼런스도 썸네일을 파일로 저장해두므로 똑같이 지웁니다.
  Future<void> _deleteImageFile(ReferenceItem item) async {
    final String? fileName = item.fileName;
    if (fileName == null || fileName.isEmpty) {
      return;
    }

    try {
      await imageStorage.deleteImageFile(fileName);
    } catch (error) {
      // 파일이 이미 없거나 못 지워도 데이터베이스 쪽은 계속 정리합니다.
      // 여기서 멈춰버리면 휴지통을 영영 비울 수 없게 됩니다.
      debugPrint('[휴지통] 사진 파일을 지우지 못했습니다: $error');
    }
  }
}
