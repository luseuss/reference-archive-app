// 아카이브(데이터베이스 + 사진)를 zip 파일 하나로 백업하고, 그 zip을
// 다시 지금 아카이브에 합쳐 넣는(복원) 일을 맡습니다.
//
// ── 왜 여기 있나 ──
// repositories/는 표 하나하나를 다루지만, 백업은 데이터베이스
// 전체(모든 표)와 사진 폴더를 함께 다루는 일이라 어느 한 저장소에도
// 속하지 않습니다. services/에 두고 AppDatabase를 직접 받습니다.
//
// ── 백업 파일 형식 ──
// zip 하나 안에 다음 둘만 있습니다(앱 설정은 안 넣습니다 — 설정은
// 컴퓨터마다 따로 두는 게 자연스럽습니다).
//   reference_archive.sqlite   데이터베이스 전체
//   images/                    사진 폴더 그대로
//
// ── 데이터베이스를 어떻게 복사하나 (VACUUM INTO) ──
// 앱이 켜진 채로 sqlite 파일을 그냥 파일 복사하면, 쓰는 중인 내용이
// 걸려서 깨질 수 있습니다. sqlite의 `VACUUM INTO` 명령은 지금 켜져
// 있는 연결에서 바로 "항상 완전하고 일관된 복사본"을 새 파일로
// 만들어줍니다. drift의 customStatement()로 그 SQL을 직접 부릅니다.
//
// ── 복원은 "합치기"입니다 (통째로 바꾸기가 아닙니다) ──
// mergeBackupZipBytes()를 참고하세요.
//
// ── 파일 대화상자가 있는 부분과 없는 부분을 나눈 이유 ──
// writeBackupZip()/mergeBackupZipBytes()는 파일 대화상자 없이 경로/
// 바이트만 받아 일하므로, 화면 없이 유닛 테스트로 확인할 수 있습니다.
// createBackup()/restoreFromBackup()은 그 위에 file_picker 대화상자를
// 씌운 것으로, 진짜 운영체제 대화상자를 열려고 해서 테스트 환경에서는
// 못 씁니다(board_export_controller.dart의 저장 대화상자와 같은 사정).

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/app_database.dart';

/// 백업 zip 안에서 데이터베이스 파일에 쓰는 이름입니다.
///
/// **`local_image_storage.dart`의 이미지 폴더 이름, `app_database.dart`의
/// 실제 sqlite 파일 이름과는 별개입니다** — 이건 zip 안에서 쓰는 이름일
/// 뿐이라 굳이 똑같을 필요는 없지만, 헷갈리지 않게 같은 이름을 씁니다.
const String _sqliteEntryName = 'reference_archive.sqlite';

/// 백업 zip 안에서 사진 폴더가 들어갈 이름입니다.
///
/// **`local_image_storage.dart`의 `_imagesFolderName`과 반드시 같아야
/// 합니다** — 실제 사진 폴더를 zip에 넣을 때 폴더의 실제 이름을 그대로
/// 쓰기 때문에, 이 폴더가 여기서 이름이 바뀌면 이 상수도 같이 고쳐야
/// 합니다.
const String _imagesFolderName = 'images';

/// [ArchiveBackupService.createBackup] 결과입니다.
enum BackupOutcome {
  /// 백업 파일을 만들어 저장했습니다.
  saved,

  /// 사용자가 저장 대화상자를 취소했습니다. 실패가 아닙니다.
  cancelled,

  /// 저장하려다 오류가 났습니다.
  failed,
}

/// [ArchiveBackupService.restoreFromBackup] 결과입니다.
enum RestoreOutcome {
  /// 백업 내용을 지금 아카이브에 합쳤습니다.
  restored,

  /// 사용자가 파일 고르기 대화상자를 취소했습니다. 실패가 아닙니다.
  cancelled,

  /// 고른 파일이 이 앱이 만든 백업 zip이 아니거나, 안에 데이터베이스
  /// 파일이 없습니다.
  invalidFile,

  /// 합치다가 오류가 났습니다.
  failed,
}

/// 아카이브 백업을 만들고 복원하는 일을 맡습니다.
class ArchiveBackupService {
  ArchiveBackupService(this._database);

  /// 지금 켜져 있는 데이터베이스 연결입니다.
  final AppDatabase _database;

  /// 저장 대화상자를 열어 사용자가 고른 자리에 백업 zip을 만듭니다.
  Future<BackupOutcome> createBackup() async {
    final String? savePath = await FilePicker.saveFile(
      dialogTitle: '아카이브 백업 만들기',
      fileName: _defaultBackupFileName(),
      type: FileType.custom,
      allowedExtensions: <String>['zip'],
    );

    // 취소했으면(null) 조용히 아무 일도 안 합니다. 취소는 실패가 아닙니다.
    if (savePath == null) {
      return BackupOutcome.cancelled;
    }

    try {
      await writeBackupZip(savePath);
      return BackupOutcome.saved;
    } catch (error) {
      return BackupOutcome.failed;
    }
  }

  /// 오늘 날짜가 들어간 기본 백업 파일 이름을 만듭니다.
  /// 예: "레퍼런스아카이브-백업-2026-09-06.zip"
  String _defaultBackupFileName() {
    final DateTime now = DateTime.now();
    final String year = now.year.toString();
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');
    return '레퍼런스아카이브-백업-$year-$month-$day.zip';
  }

  /// 저장 대화상자를 열어, 사용자가 고른 자리에 **무드보드 하나만** 담은
  /// 공유 파일을 만듭니다.
  ///
  /// ── 이 공유 파일의 정체 ──
  /// 사실 그 무드보드 하나만 담은 아주 작은 **백업 zip**입니다
  /// ([writeBoardShareZip] 참고) — 그래서 받는 사람은 새로 배운
  /// "가져오기" 버튼이 아니라, 이미 있는 설정 화면의 "백업에서
  /// 가져오기"로 그대로 불러올 수 있습니다. 가져오기 쪽 코드를 새로
  /// 안 만든 이유입니다.
  Future<BackupOutcome> exportBoardShare(
    String boardId,
    String boardName,
  ) async {
    final String? savePath = await FilePicker.saveFile(
      dialogTitle: '무드보드 공유 파일 만들기',
      fileName: _defaultShareFileName(boardName),
      type: FileType.custom,
      allowedExtensions: <String>['zip'],
    );

    if (savePath == null) {
      return BackupOutcome.cancelled;
    }

    try {
      await writeBoardShareZip(boardId, savePath);
      return BackupOutcome.saved;
    } catch (error) {
      return BackupOutcome.failed;
    }
  }

  /// 오늘 날짜와 무드보드 이름이 들어간 공유 파일 이름을 만듭니다.
  /// 예: "겨울 무드-공유-2026-10-02.zip"
  String _defaultShareFileName(String boardName) {
    final DateTime now = DateTime.now();
    final String year = now.year.toString();
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');
    final String safeName = boardName.trim().isEmpty ? '무드보드' : boardName.trim();
    return '$safeName-공유-$year-$month-$day.zip';
  }

  /// 지금 데이터베이스 + 사진 폴더를 [zipPath]에 zip 파일로 만듭니다.
  ///
  /// 파일 대화상자를 안 거치는 핵심 로직입니다. 실제로 사용자에게 저장할
  /// 자리를 물어보는 일은 [createBackup]이 합니다.
  Future<void> writeBackupZip(String zipPath) async {
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'reference_archive_backup_',
    );

    try {
      // ── 1. 데이터베이스를 일관된 상태로 복사합니다 ──
      final String tempSqlitePath = p.join(tempDir.path, _sqliteEntryName);

      // 작은따옴표를 두 번 써서 이스케이프합니다(SQL 문자열 리터럴 규칙).
      // Windows 경로의 역슬래시는 SQL에서 특별한 뜻이 없어 그대로 써도
      // 안전합니다.
      final String escapedPath = tempSqlitePath.replaceAll("'", "''");
      await _database.customStatement("VACUUM INTO '$escapedPath'");

      // ── 2. zip으로 묶습니다 ──
      final ZipFileEncoder encoder = ZipFileEncoder();
      encoder.create(zipPath);

      await encoder.addFile(File(tempSqlitePath), _sqliteEntryName);

      final Directory imagesDir = await _imagesDirectory();
      if (await imagesDir.exists()) {
        // addDirectory는 폴더의 **실제 이름**을 zip 안 폴더 이름으로
        // 씁니다. images 폴더 이름이 바뀌면 이 파일 위쪽의
        // _imagesFolderName 상수도 같이 고쳐야 하는 이유입니다.
        await encoder.addDirectory(imagesDir);
      }

      await encoder.close();
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  /// [boardId] 판 하나만 담은 공유 zip을 [zipPath]에 만듭니다.
  ///
  /// 파일 대화상자를 안 거치는 핵심 로직입니다. 실제로 사용자에게 저장할
  /// 자리를 물어보는 일은 [exportBoardShare]가 합니다.
  ///
  /// ── 무엇을 담는가 ──
  /// 백업 전체([writeBackupZip])와 달리 이 판에 **필요한 행만** 골라
  /// 담습니다 — 다른 판이나 안 쓰는 레퍼런스까지 통째로 넘기면 받는
  /// 사람 입장에서 "내 아카이브와 상관없는 것들이 잔뜩 딸려왔다"가
  /// 됩니다.
  ///   1. 그 판(Boards) 자신
  ///   2. 그 판에 놓인, 지워지지 않은 카드들(BoardCards)
  ///   3. 카드가 가리키는 레퍼런스들(References) — 텍스트 카드는
  ///      가리키는 레퍼런스가 없으므로 자동으로 빠집니다.
  ///   4. 그 레퍼런스들의 태그·프로젝트 연결(ReferenceTaxonomyLinks)
  ///   5. 그 레퍼런스들의 폴더·카테고리·태그·프로젝트
  ///      (TaxonomyItems) — **폴더는 조상까지 전부** 따라갑니다.
  ///      안 그러면 하위 폴더만 오고 상위 폴더가 없어서 받는 쪽에서
  ///      폴더 구조가 끊겨 보입니다.
  ///   6. 그 레퍼런스들이 쓰는 사진 파일만(통째로 images 폴더가 아님)
  ///
  /// ── 받는 쪽은 똑같이 "백업에서 가져오기"를 씁니다 ──
  /// 위 다섯 표 모두 [writeBackupZip]과 **같은 파일 형식**(같은 파일
  /// 이름의 sqlite + 같은 이름의 images 폴더)으로 담기 때문에,
  /// [mergeBackupZipBytes]가 고치지 않아도 그대로 읽어 들입니다 —
  /// "안에 든 표가 전체냐 일부냐"는 합치는 쪽(모두 insertOrIgnore)
  /// 입장에서는 다를 게 없습니다.
  Future<void> writeBoardShareZip(String boardId, String zipPath) async {
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'reference_archive_board_share_',
    );
    AppDatabase? shareDb;

    try {
      // ── 1. 이 판에 필요한 행만 데이터베이스에서 골라 읽습니다 ──
      final BoardRow board = await (_database.select(
        _database.boards,
      )..where(($BoardsTable b) => b.id.equals(boardId))).getSingle();

      final List<BoardCardRow> cardRows =
          await (_database.select(_database.boardCards)..where(
                ($BoardCardsTable c) => c.boardId.equals(boardId) & c.deletedAt.isNull(),
              ))
              .get();

      final Set<String> referenceIds = cardRows
          .map((BoardCardRow card) => card.referenceId)
          .whereType<String>()
          .toSet();

      final List<ReferenceRow> referenceRows = referenceIds.isEmpty
          ? const <ReferenceRow>[]
          : await (_database.select(
              _database.references,
            )..where(($ReferencesTable r) => r.id.isIn(referenceIds))).get();

      final List<ReferenceTaxonomyLinkRow> linkRows = referenceIds.isEmpty
          ? const <ReferenceTaxonomyLinkRow>[]
          : await (_database.select(_database.referenceTaxonomyLinks)..where(
                  ($ReferenceTaxonomyLinksTable l) => l.referenceId.isIn(referenceIds),
                ))
                .get();

      // ── 2. 그 레퍼런스들이 쓰는 분류 항목을, 폴더는 조상까지 모읍니다 ──
      final Map<String, TaxonomyItemRow> taxonomyById =
          await _resolveTaxonomyClosure(<String>{
            for (final ReferenceRow r in referenceRows) ...<String>[
              if (r.folderId != null) r.folderId!,
              if (r.categoryId != null) r.categoryId!,
            ],
            for (final ReferenceTaxonomyLinkRow l in linkRows) l.taxonomyItemId,
            if (board.folderId != null) board.folderId!,
          });

      // ── 3. 위에서 고른 행들만 담은 작은 임시 데이터베이스를 만듭니다 ──
      // 진짜 운영 중인 데이터베이스가 아니라 이 공유 zip 하나만을 위한
      // 새 파일이라, writeBackupZip처럼 VACUUM INTO로 복사할 필요
      // 없이 처음부터 이 행들만 써 넣으면 됩니다.
      final String tempSqlitePath = p.join(tempDir.path, _sqliteEntryName);
      shareDb = AppDatabase.forTesting(NativeDatabase(File(tempSqlitePath)));

      await shareDb.batch((Batch batch) {
        batch.insertAll(
          shareDb!.taxonomyItems,
          taxonomyById.values.map(
            (TaxonomyItemRow row) => row.toCompanion(true),
          ),
        );
        batch.insertAll(
          shareDb.references,
          referenceRows.map((ReferenceRow row) => row.toCompanion(true)),
        );
        batch.insertAll(
          shareDb.referenceTaxonomyLinks,
          linkRows.map(
            (ReferenceTaxonomyLinkRow row) => row.toCompanion(true),
          ),
        );
        batch.insert(shareDb.boards, board.toCompanion(true));
        batch.insertAll(
          shareDb.boardCards,
          cardRows.map((BoardCardRow row) => row.toCompanion(true)),
        );
      });
      await shareDb.close();
      shareDb = null;

      // ── 4. zip으로 묶습니다 ──
      final ZipFileEncoder encoder = ZipFileEncoder();
      encoder.create(zipPath);
      await encoder.addFile(File(tempSqlitePath), _sqliteEntryName);

      // writeBackupZip과 달리 images 폴더를 통째로 담지 않고, 이
      // 판이 실제로 쓰는 사진 파일만 하나씩 골라 담습니다.
      final Directory imagesDir = await _imagesDirectory();
      for (final ReferenceRow reference in referenceRows) {
        final String? fileName = reference.fileName;
        if (fileName == null) {
          continue;
        }
        final File imageFile = File(p.join(imagesDir.path, fileName));
        if (await imageFile.exists()) {
          await encoder.addFile(imageFile, '$_imagesFolderName/$fileName');
        }
      }

      await encoder.close();
    } finally {
      await shareDb?.close();
      await tempDir.delete(recursive: true);
    }
  }

  /// [seedIds]에서 시작해, 그 안에 든 폴더의 **조상 폴더까지** 전부
  /// 찾아 돌려줍니다.
  ///
  /// 카테고리·태그·프로젝트는 `parentId`가 늘 비어 있어서 한 번만
  /// 읽히고 끝나지만, 폴더는 상위 폴더를 가리킬 수 있어서(폴더 중첩)
  /// 그 사슬을 끝까지 따라가야 합니다 — 안 그러면 공유받은 쪽에
  /// 하위 폴더만 오고 그 위 폴더가 없어서 구조가 끊겨 보입니다.
  Future<Map<String, TaxonomyItemRow>> _resolveTaxonomyClosure(
    Set<String> seedIds,
  ) async {
    final Map<String, TaxonomyItemRow> resolved = <String, TaxonomyItemRow>{};
    Set<String> toResolve = seedIds;

    while (toResolve.isNotEmpty) {
      final List<String> batch = toResolve
          .where((String id) => !resolved.containsKey(id))
          .toList();
      if (batch.isEmpty) {
        break;
      }

      final List<TaxonomyItemRow> rows = await (_database.select(
        _database.taxonomyItems,
      )..where(($TaxonomyItemsTable t) => t.id.isIn(batch))).get();

      final Set<String> nextRound = <String>{};
      for (final TaxonomyItemRow row in rows) {
        resolved[row.id] = row;
        final String? parentId = row.parentId;
        if (parentId != null && !resolved.containsKey(parentId)) {
          nextRound.add(parentId);
        }
      }
      toResolve = nextRound;
    }

    return resolved;
  }

  /// 파일 고르기 대화상자를 열어, 사용자가 고른 백업 zip을 지금
  /// 아카이브에 합칩니다.
  Future<RestoreOutcome> restoreFromBackup() async {
    final FilePickerResult? picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['zip'],
      withData: true,
      dialogTitle: '백업 파일 고르기',
    );

    if (picked == null || picked.files.isEmpty) {
      return RestoreOutcome.cancelled;
    }

    final Uint8List? bytes = picked.files.single.bytes;
    if (bytes == null) {
      return RestoreOutcome.failed;
    }

    try {
      await mergeBackupZipBytes(bytes);
      return RestoreOutcome.restored;
    } on FormatException {
      // 백업 zip 안에 데이터베이스 파일이 없거나(위 mergeBackupZipBytes가
      // 직접 던짐), zip 형식 자체가 아닌 파일을 골랐을 때(ZipDecoder가
      // 던지는 ArchiveException도 FormatException의 하위 타입입니다)
      // 여기로 옵니다.
      return RestoreOutcome.invalidFile;
    } catch (error) {
      return RestoreOutcome.failed;
    }
  }

  /// [zipBytes](백업 zip 파일 내용)를 지금 데이터베이스·사진 폴더에
  /// **합칩니다.** 통째로 바꿔치기가 아닙니다 — 지금 있는 것은 그대로
  /// 두고, 백업에만 있는 것만 추가합니다.
  ///
  /// 합치기가 안전한 이유: 이 프로젝트의 모든 항목은 UUID를 씁니다
  /// (CLAUDE.md 설계 원칙 1). 서로 다른 컴퓨터에서 만든 두 항목의
  /// id가 우연히 겹칠 확률은 사실상 0이라, "id가 없으면 추가"만으로
  /// 충돌 없이 합쳐집니다. 다만 **이름이 같은 항목을 하나로 합쳐주지는
  /// 않습니다** — 서로 다른 컴퓨터에서 각자 만든 "인물" 폴더가 있다면
  /// 합친 뒤 폴더가 두 개로 보입니다. 이번 범위에서는 그대로 둡니다.
  ///
  /// 파일 대화상자를 안 거치는 핵심 로직입니다. 실제로 사용자에게 백업
  /// 파일을 고르게 하는 일은 [restoreFromBackup]이 합니다.
  Future<void> mergeBackupZipBytes(Uint8List zipBytes) async {
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'reference_archive_restore_',
    );

    try {
      final Archive archive = ZipDecoder().decodeBytes(zipBytes);
      await extractArchiveToDisk(archive, tempDir.path);

      final File backupSqlite = File(p.join(tempDir.path, _sqliteEntryName));
      if (!await backupSqlite.exists()) {
        throw const FormatException('백업 zip 안에 데이터베이스 파일이 없습니다.');
      }

      await _mergeDatabaseFrom(backupSqlite);
      await _mergeImagesFrom(
        Directory(p.join(tempDir.path, _imagesFolderName)),
      );
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  /// 백업 데이터베이스 파일을 열어 표마다 "id가 없으면 추가"로 지금
  /// 데이터베이스에 합칩니다.
  ///
  /// 백업 파일을 [AppDatabase]로 열면(NativeDatabase(File(...))),
  /// 이 앱이 이미 갖고 있는 마이그레이션이 자동으로 실행됩니다 — 옛날
  /// 버전으로 만든 백업이어도 최신 구조로 올라온 뒤에 읽힙니다.
  Future<void> _mergeDatabaseFrom(File backupSqliteFile) async {
    final AppDatabase backupDb = AppDatabase.forTesting(
      NativeDatabase(backupSqliteFile),
    );

    try {
      // 부모 표를 먼저 읽어서, 넣는 순서도 부모가 먼저 되게 합니다.
      final List<TaxonomyItemRow> taxonomyRows = await backupDb
          .select(backupDb.taxonomyItems)
          .get();
      final List<ReferenceRow> referenceRows = await backupDb
          .select(backupDb.references)
          .get();
      final List<ReferenceTaxonomyLinkRow> linkRows = await backupDb
          .select(backupDb.referenceTaxonomyLinks)
          .get();
      final List<BoardRow> boardRows = await backupDb
          .select(backupDb.boards)
          .get();
      final List<BoardCardRow> cardRows = await backupDb
          .select(backupDb.boardCards)
          .get();

      // db.batch()는 그 자체로 하나의 트랜잭션입니다. 다섯 표 전부를
      // 한 번에 묶어서, 중간에 실패해도 절반만 합쳐지는 일이 없게 합니다.
      await _database.batch((Batch batch) {
        batch.insertAll(
          _database.taxonomyItems,
          taxonomyRows.map((TaxonomyItemRow row) => row.toCompanion(true)),
          mode: InsertMode.insertOrIgnore,
        );
        batch.insertAll(
          _database.references,
          referenceRows.map((ReferenceRow row) => row.toCompanion(true)),
          mode: InsertMode.insertOrIgnore,
        );
        batch.insertAll(
          _database.referenceTaxonomyLinks,
          linkRows.map(
            (ReferenceTaxonomyLinkRow row) => row.toCompanion(true),
          ),
          mode: InsertMode.insertOrIgnore,
        );
        batch.insertAll(
          _database.boards,
          boardRows.map((BoardRow row) => row.toCompanion(true)),
          mode: InsertMode.insertOrIgnore,
        );
        batch.insertAll(
          _database.boardCards,
          cardRows.map((BoardCardRow row) => row.toCompanion(true)),
          mode: InsertMode.insertOrIgnore,
        );
      });
    } finally {
      await backupDb.close();
    }
  }

  /// 백업의 사진 폴더에서, 지금 사진 폴더에 없는 파일만 복사합니다.
  ///
  /// 파일 이름도 UUID 기반이라(설계 원칙 4) 이름이 겹칠 일이 사실상
  /// 없습니다 — 그래도 이미 있으면 덮어쓰지 않고 건너뜁니다.
  Future<void> _mergeImagesFrom(Directory backupImagesDir) async {
    if (!await backupImagesDir.exists()) {
      return;
    }

    final Directory imagesDir = await _imagesDirectory();
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    await for (final FileSystemEntity entity in backupImagesDir.list()) {
      if (entity is! File) {
        continue;
      }

      final String fileName = p.basename(entity.path);
      final File destination = File(p.join(imagesDir.path, fileName));

      if (!await destination.exists()) {
        await entity.copy(destination.path);
      }
    }
  }

  /// 사진이 저장된 폴더를 찾습니다.
  ///
  /// local_image_storage.dart의 _getImagesDirectory()와 같은 위치를
  /// 가리키지만, 이 서비스는 ImageStorage(약속)가 아니라 실제 파일
  /// 시스템을 직접 다뤄야 하는 일이라(폴더 전체를 zip에 넣고, zip에서
  /// 풀어야 함) 독립적으로 구합니다.
  Future<Directory> _imagesDirectory() async {
    final Directory appDir = await getApplicationSupportDirectory();
    return Directory(p.join(appDir.path, _imagesFolderName));
  }
}
