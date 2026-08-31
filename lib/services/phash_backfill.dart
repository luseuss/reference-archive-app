// 이미 저장돼 있지만 아직 pHash가 없는 레퍼런스를 찾아 채우는 곳입니다.
//
// ── 언제 부르나 ──
// 앱을 켤 때 화면 뒤에서 한 번 조용히 돌립니다(screens/home_screen.dart의
// initState). 새로 추가하는 레퍼런스는 이미 들여오는 순간에 계산되므로
// (services/reference_importer.dart) 여기서 다시 볼 필요가 없습니다 —
// 이 함수는 "예전에 만들어져서 pHash가 비어있는" 것들만 대상으로 합니다.
//
// ── 실패해도 다시 시도합니다 ──
// 파일이 깨졌거나 없어서 계산에 실패한 레퍼런스는 pHash가 계속 null로
// 남고, 다음에 앱을 켤 때 또 시도합니다. 별도의 "포기" 표시를 두지
// 않습니다 — 그림 파일이 나중에 복구될 수도 있고, 매번 다시 시도해도
// 실패한 것들만 스치듯 다시 읽어보는 정도라 크게 부담스럽지 않습니다.

import 'dart:io';
import 'dart:typed_data';

import '../models/reference_item.dart';
import '../repositories/reference_repository.dart';
import 'image_hash.dart';
import 'image_storage.dart';

/// pHash가 없는 레퍼런스를 전부 찾아 계산해서 채웁니다.
Future<void> backfillMissingPHashes({
  required ReferenceRepository repository,
  required ImageStorage imageStorage,
}) async {
  final List<ReferenceItem> items = await repository.getAll();

  for (final ReferenceItem item in items) {
    if (item.pHash != null) {
      continue;
    }

    final String? fileName = item.fileName;
    if (fileName == null) {
      // 유튜브인데 썸네일을 못 받아온 경우 등, 사진 자체가 없습니다.
      continue;
    }

    try {
      final String path = await imageStorage.getFullPath(fileName);
      final List<int> bytes = await File(path).readAsBytes();
      final String? hash = dHashFromBytes(Uint8List.fromList(bytes));
      if (hash == null) {
        continue;
      }
      await repository.save(item.copyWith(pHash: hash));
    } catch (_) {
      // 파일이 없거나 읽는 중 문제가 생겨도 나머지 레퍼런스는 계속
      // 채워야 하므로 여기서 조용히 넘어갑니다.
      continue;
    }
  }
}
