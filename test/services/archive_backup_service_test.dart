// 아카이브 백업/복원의 핵심 로직(zip 만들기·합치기)을 확인하는
// 테스트입니다. 파일 대화상자는 안 거칩니다 — createBackup()/
// restoreFromBackup()처럼 대화상자를 여는 부분은 위젯 테스트로 못
// 잡는 부류라(이 프로젝트의 다른 파일 저장 기능들과 같은 사정),
// writeBackupZip()/mergeBackupZipBytes()만 직접 부릅니다.
//
// 데이터베이스는 진짜 파일로 엽니다(NativeDatabase(File(...))).
// VACUUM INTO는 실제 파일 시스템에 파일을 쓰는 명령이라, 메모리
// 데이터베이스만으로는 이 기능의 핵심을 확인했다고 보기 어렵습니다.

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/board.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';
import 'package:reference_archive_app/repositories/local_board_repository.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/repositories/local_taxonomy_repository.dart';
import 'package:reference_archive_app/services/archive_backup_service.dart';
import 'package:reference_archive_app/utils/id_generator.dart';

import '../fakes/fake_path_provider.dart';

void main() {
  // 플러그인(path_provider)을 흉내내려면 테스트 환경이 먼저 준비되어야 합니다.
  TestWidgetsFlutterBinding.ensureInitialized();

  // 이 파일은 일부러 AppDatabase를 여러 번 만듭니다(백업 쪽 데이터베이스를
  // "다른 컴퓨터"인 것처럼 흉내내려고, 서로 다른 파일을 각각 엽니다).
  // drift는 기본적으로 이런 경우 "혹시 실수 아니냐"는 경고를 출력하는데,
  // 여기서는 의도한 것이므로 꺼둡니다.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory tempDir;
  late AppDatabase db;
  late LocalReferenceRepository repository;
  late ArchiveBackupService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_test_');

    // writeBackupZip()이 사진 폴더를 찾을 때 getApplicationSupportDirectory()를
    // 부릅니다. 진짜 앱 데이터 폴더를 건드리지 않도록 임시 폴더로 돌립니다.
    PathProviderPlatform.instance = FakePathProvider(tempDir.path);

    db = AppDatabase.forTesting(
      NativeDatabase(File('${tempDir.path}/live.sqlite')),
    );
    repository = LocalReferenceRepository(db);
    service = ArchiveBackupService(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// 테스트용 이미지 레퍼런스를 하나 만들어 저장하고 돌려줍니다.
  Future<ReferenceItem> saveImage(String title) async {
    final DateTime now = DateTime.now().toUtc();
    final ReferenceItem item = ReferenceItem(
      id: newId(),
      type: ReferenceType.image,
      title: title,
      fileName: '$title.jpg',
      createdAt: now,
      updatedAt: now,
    );
    await repository.save(item);
    return item;
  }

  test('백업 zip 안에 데이터베이스 파일이 들어있다', () async {
    await saveImage('노을');

    final String zipPath = '${tempDir.path}/backup.zip';
    await service.writeBackupZip(zipPath);

    expect(await File(zipPath).exists(), isTrue);

    final Archive archive = ZipDecoder().decodeBytes(
      await File(zipPath).readAsBytes(),
    );
    final ArchiveFile? sqliteEntry = archive.findFile(
      'reference_archive.sqlite',
    );
    expect(sqliteEntry, isNotNull);
  });

  test('백업한 데이터베이스를 열어보면 저장해둔 레퍼런스가 그대로 있다', () async {
    await saveImage('노을');

    final String zipPath = '${tempDir.path}/backup.zip';
    await service.writeBackupZip(zipPath);

    final Directory extractDir = Directory('${tempDir.path}/extracted');
    final Archive archive = ZipDecoder().decodeBytes(
      await File(zipPath).readAsBytes(),
    );
    await extractArchiveToDisk(archive, extractDir.path);

    final AppDatabase reopened = AppDatabase.forTesting(
      NativeDatabase(File('${extractDir.path}/reference_archive.sqlite')),
    );
    final List<ReferenceItem> items = await LocalReferenceRepository(
      reopened,
    ).getAll();
    await reopened.close();

    expect(items.single.title, '노을');
  });

  group('복원(합치기)', () {
    /// 두 번째(백업 쪽) 데이터베이스를 만들어 돌려줍니다. 실제 백업처럼
    /// **지금 켜진 것과는 완전히 다른 파일**입니다.
    Future<AppDatabase> makeBackupDb() async {
      return AppDatabase.forTesting(
        NativeDatabase(File('${tempDir.path}/backup_source.sqlite')),
      );
    }

    test('백업에 있고 지금 없는 레퍼런스는 추가된다', () async {
      await saveImage('내 것');

      final AppDatabase backupDb = await makeBackupDb();
      final DateTime now = DateTime.now().toUtc();
      await LocalReferenceRepository(backupDb).save(
        ReferenceItem(
          id: newId(),
          type: ReferenceType.image,
          title: '백업에서 온 것',
          fileName: 'backup.jpg',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final String backupZipPath = '${tempDir.path}/other.zip';
      await ArchiveBackupService(backupDb).writeBackupZip(backupZipPath);
      await backupDb.close();

      await service.mergeBackupZipBytes(
        await File(backupZipPath).readAsBytes(),
      );

      final List<String> titles =
          (await repository.getAll())
              .map((ReferenceItem item) => item.title)
              .toList()
            ..sort();
      expect(titles, <String>['내 것', '백업에서 온 것']);
    });

    test('같은 id가 이미 있으면 두 번 늘어나지 않는다 (합치기를 두 번 해도 안전함)', () async {
      await saveImage('내 것');

      final String zipPath = '${tempDir.path}/self_backup.zip';
      await service.writeBackupZip(zipPath);

      // 자기 자신의 백업을 자기 자신에 두 번 합쳐봅니다.
      await service.mergeBackupZipBytes(await File(zipPath).readAsBytes());
      await service.mergeBackupZipBytes(await File(zipPath).readAsBytes());

      expect((await repository.getAll()).length, 1);
    });

    test('백업의 폴더·태그도 함께 합쳐진다', () async {
      final AppDatabase backupDb = await makeBackupDb();
      final LocalTaxonomyRepository backupTaxonomy = LocalTaxonomyRepository(
        backupDb,
      );
      final DateTime now = DateTime.now().toUtc();
      await backupTaxonomy.save(
        TaxonomyItem(
          id: newId(),
          kind: TaxonomyKind.folder,
          name: '백업 폴더',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final String backupZipPath = '${tempDir.path}/other.zip';
      await ArchiveBackupService(backupDb).writeBackupZip(backupZipPath);
      await backupDb.close();

      await service.mergeBackupZipBytes(
        await File(backupZipPath).readAsBytes(),
      );

      final LocalTaxonomyRepository liveTaxonomy = LocalTaxonomyRepository(
        db,
      );
      final List<TaxonomyItem> folders = await liveTaxonomy.getAll(
        TaxonomyKind.folder,
      );
      expect(folders.map((TaxonomyItem f) => f.name), contains('백업 폴더'));
    });

    test('백업의 무드보드 판과 카드도 함께 합쳐진다', () async {
      final AppDatabase backupDb = await makeBackupDb();
      final LocalBoardRepository backupBoards = LocalBoardRepository(
        backupDb,
      );
      final LocalReferenceRepository backupReferences =
          LocalReferenceRepository(backupDb);

      final DateTime now = DateTime.now().toUtc();
      final ReferenceItem backupRef = ReferenceItem(
        id: newId(),
        type: ReferenceType.image,
        title: '백업 레퍼런스',
        fileName: 'x.jpg',
        createdAt: now,
        updatedAt: now,
      );
      await backupReferences.save(backupRef);
      await backupBoards.saveBoard(
        Board(id: 'board-1', name: '백업 무드보드', createdAt: now, updatedAt: now),
      );
      await backupBoards.addCards(<BoardCard>[
        BoardCard(
          id: newId(),
          boardId: 'board-1',
          referenceId: backupRef.id,
          x: 0,
          y: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      final String backupZipPath = '${tempDir.path}/other.zip';
      await ArchiveBackupService(backupDb).writeBackupZip(backupZipPath);
      await backupDb.close();

      await service.mergeBackupZipBytes(
        await File(backupZipPath).readAsBytes(),
      );

      final LocalBoardRepository liveBoards = LocalBoardRepository(db);
      final List<BoardCard> cards = await liveBoards.getCards('board-1');
      expect(cards.single.referenceId, backupRef.id);
    });

    test('백업의 사진 파일도 실제 사진 폴더로 복사된다', () async {
      final AppDatabase backupDb = await makeBackupDb();

      // 백업 쪽 images 폴더에 진짜 파일을 하나 만들어둡니다. writeBackupZip이
      // getApplicationSupportDirectory()로 찾은 폴더에서 읽으므로, 지금
      // 가짜 경로(FakePathProvider)가 가리키는 폴더에 직접 만듭니다.
      //
      // 주의: 백업 쪽과 지금 쪽이 **같은 가짜 경로**를 씁니다(파일
      // 시스템은 하나뿐이므로). 실제로는 서로 다른 컴퓨터의 서로 다른
      // 폴더지만, 이 테스트에서는 "백업에만 있던 파일이 살아있는 쪽에도
      // 생기는지"를 확인하는 것이 핵심이라 문제되지 않습니다.
      final Directory imagesDir = Directory('${tempDir.path}/images');
      await imagesDir.create(recursive: true);
      final File backupOnlyImage = File('${imagesDir.path}/backup-only.jpg');
      await backupOnlyImage.writeAsBytes(<int>[1, 2, 3]);

      final String backupZipPath = '${tempDir.path}/other.zip';
      await ArchiveBackupService(backupDb).writeBackupZip(backupZipPath);
      await backupDb.close();

      // 합치기 전에 images 폴더를 비웁니다 — 방금 만든 backup-only.jpg가
      // "이미 살아있는 쪽에 있던 것"이 아니라 "백업에서 온 것"임을
      // 분명히 하려는 것입니다.
      await backupOnlyImage.delete();

      await service.mergeBackupZipBytes(
        await File(backupZipPath).readAsBytes(),
      );

      expect(await backupOnlyImage.exists(), isTrue);
    });
  });
}
