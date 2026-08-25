// 실제 데이터베이스 파일을 열고 닫는 곳입니다.
//
// tables.dart가 "어떤 표를 만들지" 정한다면, 이 파일은 "그 표들을 담은 데이터베이스를
// 실제로 어디에 만들지"를 정합니다.
//
// 이 파일을 고친 뒤에는 반드시 아래를 실행해야 반영됩니다.
//   dart run build_runner build

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

// 코드 생성기가 만들어주는 파일입니다. 빨간 줄이 떠도 build_runner를 돌리면 사라집니다.
part 'app_database.g.dart';

/// 앱의 데이터베이스입니다.
///
/// @DriftDatabase에 적은 표들이 이 데이터베이스에 들어갑니다.
/// 표를 새로 추가하면 여기 tables 목록에도 넣어야 합니다.
@DriftDatabase(
  tables: <Type>[References, TaxonomyItems, ReferenceTaxonomyLinks],
)
class AppDatabase extends _$AppDatabase {
  /// 실제 파일에 저장되는 데이터베이스를 엽니다. 앱에서 쓰는 방식입니다.
  AppDatabase() : super(_openConnection());

  /// 메모리 안에서만 도는 데이터베이스를 엽니다. **테스트 전용입니다.**
  ///
  /// 파일을 만들지 않기 때문에 테스트가 끝나면 흔적 없이 사라지고,
  /// 테스트끼리 서로의 데이터에 영향을 주지 않습니다.
  AppDatabase.forTesting(super.connection);

  /// 데이터베이스 구조의 버전입니다.
  ///
  /// 표를 추가하거나 칸을 바꿀 때마다 이 숫자를 1 올리고, 아래 migration에
  /// "그때 무엇을 해야 하는지"를 적어야 합니다. 안 그러면 **기존 사용자의 앱이
  /// 업데이트 후 켜지지 않습니다.** (새로 설치한 사람은 멀쩡해서 놓치기 쉬운 실수입니다.)
  @override
  int get schemaVersion => 1;

  /// 데이터베이스를 처음 만들 때, 그리고 구조가 바뀌었을 때 무엇을 할지 정합니다.
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      // 앱을 처음 설치했을 때: 정의된 표를 전부 만듭니다.
      onCreate: (Migrator m) async {
        await m.createAll();
      },

      // 앱을 업데이트해서 schemaVersion이 올라갔을 때 할 일을 여기에 적습니다.
      // 지금은 버전 1뿐이라 할 일이 없습니다.
      //
      // 예시 — 나중에 표를 하나 추가하며 버전을 2로 올린다면:
      //   if (from < 2) {
      //     await m.createTable(scenes);
      //   }
      onUpgrade: (Migrator m, int from, int to) async {},

      // 데이터베이스를 열 때마다 실행됩니다.
      beforeOpen: (OpeningDetails details) async {
        // 외래 키 검사를 켭니다. SQLite는 이걸 기본으로 꺼두기 때문에 직접 켜야 합니다.
        // 켜두면 "존재하지 않는 폴더에 들어있는 레퍼런스" 같은 깨진 데이터를 막아줍니다.
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}

/// 데이터베이스 파일을 어디에 만들지 정합니다.
///
/// 경로를 직접 적지 않습니다. 기기마다 앱 데이터 폴더 위치가 다르기 때문에
/// 절대경로를 코드에 적어두면 안 됩니다(설계 원칙 4-4).
///
/// ── databaseDirectory를 직접 지정한 이유 ──
/// 아무것도 지정하지 않으면 drift는 getApplicationDocumentsDirectory()를 씁니다.
/// 그런데 Windows에서 그곳은 **사용자의 "문서" 폴더**입니다. 그대로 두면
/// 사용자 문서 폴더 한가운데에 reference_archive.sqlite가 툭 생깁니다.
///
/// getApplicationSupportDirectory()는 앱 전용 폴더
/// (Windows에서는 %APPDATA%\com.luseuss\reference_archive_app)를 알려줍니다.
/// 사용자 눈에 띄지 않는 곳이고, 앱을 지울 때 함께 정리되는 자리입니다.
/// 이미지 파일도 같은 곳에 저장합니다(lib/services/local_image_storage.dart).
QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'reference_archive',
    native: DriftNativeOptions(
      databaseDirectory: getApplicationSupportDirectory,
    ),
  );
}
