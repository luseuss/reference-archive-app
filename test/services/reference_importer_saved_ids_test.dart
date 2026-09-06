// ImportOutcome.savedIds(새로 만들어진 레퍼런스 번호들)가 제대로 채워지는지
// 확인하는 테스트입니다.
//
// ── 왜 필요한가 ──
// 무드보드 화면이 "탐색기·브라우저에서 파일을 판 위로 직접 끌어다 놓기"를
// 지원하려면, 들여오기가 끝난 뒤 **어느 레퍼런스가 새로 생겼는지**를 알아야
// 그 자리에 카드로 배치할 수 있습니다(board_screen.dart의
// `_onExternalFilesDropped`). 예전에는 성공/실패 개수만 돌려줘서 이 정보가
// 없었습니다.

import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/services/reference_importer.dart';

import '../fakes/fake_image_source.dart';
import '../fakes/fake_image_storage.dart';
import '../fakes/fake_youtube_info_source.dart';

void main() {
  late AppDatabase db;
  late LocalReferenceRepository repository;
  late FakeImageSource imageSource;
  late FakeImageStorage imageStorage;
  late FakeYoutubeInfoSource youtubeInfoSource;
  late ReferenceImporter importer;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalReferenceRepository(db);
    imageSource = FakeImageSource();
    imageStorage = FakeImageStorage();
    youtubeInfoSource = FakeYoutubeInfoSource();
    importer = ReferenceImporter(
      repository: repository,
      imageStorage: imageStorage,
      imageSource: imageSource,
      youtubeInfoSource: youtubeInfoSource,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('클립보드에서 붙여넣기에 성공하면 savedIds에 그 번호가 들어있다', () async {
    imageSource.hasClipboardImage = true;
    imageSource.bytes = Uint8List.fromList(<int>[1, 2, 3]);

    final ImportOutcome outcome = await importer.importFromClipboard(
      partId: defaultPartId,
    );

    final List<ReferenceItem> items = await repository.getAll();
    expect(outcome.savedIds, <String>[items.single.id]);
  });

  test('클립보드에 이미지가 없으면 savedIds가 비어있다', () async {
    final ImportOutcome outcome = await importer.importFromClipboard(
      partId: defaultPartId,
    );

    expect(outcome.savedIds, isEmpty);
    expect(outcome.failedCount, 1);
  });

  test('유튜브 영상을 들여오면 savedIds에 그 번호가 들어있다', () async {
    final ImportOutcome outcome = await importer.importYoutube(
      'dQw4w9WgXcQ',
      partId: defaultPartId,
    );

    final List<ReferenceItem> items = await repository.getAll();
    expect(outcome.savedIds, <String>[items.single.id]);
  });

  test('savedCount는 항상 savedIds의 개수와 같다', () async {
    imageSource.hasClipboardImage = true;

    final ImportOutcome outcome = await importer.importFromClipboard(
      partId: defaultPartId,
    );

    expect(outcome.savedCount, outcome.savedIds.length);
  });
}
