// 휴지통(지운 레퍼런스를 되살리거나 영영 지우기)을 확인하는 테스트입니다.
//
// ── 여기서 특히 보는 것 ──
// **되살렸을 때 원래 상태가 그대로 돌아오는지**입니다. 폴더·태그 같은 분류는
// 레퍼런스를 지울 때 건드리지 않으므로 자동으로 따라와야 하고, 무드보드에
// 올려뒀던 카드도 그대로 살아나야 합니다.
//
// 반대로 **영영 지우면 찌꺼기가 남지 않아야** 합니다. 그 레퍼런스를 가리키던
// 무드보드 카드까지 함께 사라져야 합니다 — 주인 없는 배치 정보가 쌓이면
// 나중에 기기 간 동기화를 붙일 때 그 찌꺼기가 다른 기기로도 퍼집니다
// (local_board_repository.dart의 deleteBoard가 같은 이유로 그렇게 합니다).

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/board.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';
import 'package:reference_archive_app/repositories/local_board_repository.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/repositories/local_taxonomy_repository.dart';
import 'package:reference_archive_app/utils/id_generator.dart';

void main() {
  late AppDatabase db;
  late LocalReferenceRepository repository;
  late LocalTaxonomyRepository taxonomyRepository;
  late LocalBoardRepository boardRepository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalReferenceRepository(db);
    taxonomyRepository = LocalTaxonomyRepository(db);
    boardRepository = LocalBoardRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// 테스트용 이미지 레퍼런스를 하나 만들어 저장하고 돌려줍니다.
  Future<ReferenceItem> saveImage(String title) async {
    final DateTime now = DateTime.now().toUtc();
    final ReferenceItem item = ReferenceItem(
      id: newId(),
      type: ReferenceType.image,
      title: title,
      fileName: '${newId()}.jpg',
      createdAt: now,
      updatedAt: now,
    );
    await repository.save(item);
    return item;
  }

  group('휴지통 목록', () {
    test('지우기 전에는 휴지통이 비어 있다', () async {
      await saveImage('노을');

      expect(await repository.getDeleted(), isEmpty);
    });

    test('지운 것만 휴지통에 들어간다', () async {
      final ReferenceItem gone = await saveImage('노을');
      await saveImage('바다');

      await repository.delete(gone.id);

      final List<ReferenceItem> deleted = await repository.getDeleted();
      expect(deleted.length, 1);
      expect(deleted.single.title, '노을');

      // 목록 쪽에서는 사라져야 합니다.
      final List<ReferenceItem> alive = await repository.getAll();
      expect(alive.length, 1);
      expect(alive.single.title, '바다');
    });

    test('여러 장을 한꺼번에 지워도 전부 휴지통에 들어간다', () async {
      final ReferenceItem a = await saveImage('가');
      final ReferenceItem b = await saveImage('나');

      await repository.deleteMany(<String>[a.id, b.id]);

      expect((await repository.getDeleted()).length, 2);
      expect(await repository.getAll(), isEmpty);
    });
  });

  group('되살리기', () {
    test('되살리면 목록으로 돌아오고 휴지통에서는 빠진다', () async {
      final ReferenceItem item = await saveImage('노을');
      await repository.delete(item.id);

      await repository.restore(item.id);

      expect(await repository.getDeleted(), isEmpty);
      final List<ReferenceItem> alive = await repository.getAll();
      expect(alive.single.title, '노을');
    });

    test('되살리면 붙여뒀던 폴더·태그도 그대로 돌아온다', () async {
      // ── 이게 이 파일의 핵심입니다 ──
      // 되살렸는데 분류가 전부 풀려 있으면, 되살린 보람이 없습니다.
      final ReferenceItem item = await saveImage('노을');

      final DateTime now = DateTime.now().toUtc();
      final TaxonomyItem tag = TaxonomyItem(
        id: newId(),
        kind: TaxonomyKind.tag,
        name: '따뜻함',
        createdAt: now,
        updatedAt: now,
      );
      await taxonomyRepository.save(tag);
      await repository.setLinkedTaxonomyIds(
        item.id,
        TaxonomyKind.tag,
        <String>[tag.id],
      );

      await repository.delete(item.id);
      await repository.restore(item.id);

      final List<String> tagIds = await repository.getLinkedTaxonomyIds(
        item.id,
        TaxonomyKind.tag,
      );
      expect(tagIds, <String>[tag.id]);
    });

    test('되살리면 무드보드에 올려뒀던 카드도 그대로 있다', () async {
      final ReferenceItem item = await saveImage('노을');

      final DateTime now = DateTime.now().toUtc();
      await boardRepository.saveBoard(
        Board(id: 'board-1', name: '겨울 무드', createdAt: now, updatedAt: now),
      );
      await boardRepository.addCards(<BoardCard>[
        BoardCard(
          id: newId(),
          boardId: 'board-1',
          referenceId: item.id,
          x: 10,
          y: 20,
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      await repository.delete(item.id);
      await repository.restore(item.id);

      final List<BoardCard> cards = await boardRepository.getCards('board-1');
      expect(cards.length, 1);
      expect(cards.single.referenceId, item.id);
    });
  });

  group('영영 지우기', () {
    test('영영 지우면 휴지통에서도 사라진다', () async {
      final ReferenceItem item = await saveImage('노을');
      await repository.delete(item.id);

      await repository.purge(item.id);

      expect(await repository.getDeleted(), isEmpty);
      expect(await repository.getAll(), isEmpty);
    });

    test('영영 지우면 그 레퍼런스를 가리키던 무드보드 카드도 사라진다', () async {
      // 주인 없는 배치 정보가 남으면 나중에 동기화할 때 찌꺼기가 퍼집니다.
      final ReferenceItem item = await saveImage('노을');
      final ReferenceItem keep = await saveImage('바다');

      final DateTime now = DateTime.now().toUtc();
      await boardRepository.saveBoard(
        Board(id: 'board-1', name: '겨울 무드', createdAt: now, updatedAt: now),
      );
      await boardRepository.addCards(<BoardCard>[
        BoardCard(
          id: newId(),
          boardId: 'board-1',
          referenceId: item.id,
          x: 0,
          y: 0,
          createdAt: now,
          updatedAt: now,
        ),
        BoardCard(
          id: newId(),
          boardId: 'board-1',
          referenceId: keep.id,
          x: 100,
          y: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      await repository.delete(item.id);
      await repository.purge(item.id);

      // 지운 레퍼런스의 카드만 빠지고, 남은 레퍼런스의 카드는 그대로여야 합니다.
      final List<BoardCard> cards = await boardRepository.getCards('board-1');
      expect(cards.length, 1);
      expect(cards.single.referenceId, keep.id);
    });

    test('휴지통 비우기는 지운 것 전부를 없앤다', () async {
      final ReferenceItem a = await saveImage('가');
      final ReferenceItem b = await saveImage('나');
      await saveImage('다'); // 안 지운 것

      await repository.deleteMany(<String>[a.id, b.id]);
      await repository.purgeAll();

      expect(await repository.getDeleted(), isEmpty);

      // 안 지운 것은 그대로 남아야 합니다.
      final List<ReferenceItem> alive = await repository.getAll();
      expect(alive.single.title, '다');
    });
  });
}
