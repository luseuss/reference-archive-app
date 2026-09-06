// 설정 화면의 "데이터 관리" 구역(백업 만들기/불러오기) 상태를 담습니다.
//
// board_export_controller.dart와 같은 ChangeNotifier 패턴입니다 —
// "지금 하는 중인지" 상태만 여기서 갖고, 실제 파일 작업은
// services/archive_backup_service.dart가 합니다.

import 'package:flutter/foundation.dart';

import '../services/archive_backup_service.dart';

/// 백업 만들기/불러오기의 상태를 담습니다.
class BackupController extends ChangeNotifier {
  BackupController(this._service);

  final ArchiveBackupService _service;

  /// 지금 백업을 만들거나 불러오는 중인지 여부입니다.
  /// 켜져 있는 동안 버튼을 다시 못 누르게 막는 데 씁니다.
  bool get isWorking => _isWorking;
  bool _isWorking = false;

  /// 백업을 만듭니다.
  Future<BackupOutcome> createBackup() async {
    if (_isWorking) {
      return BackupOutcome.cancelled;
    }

    _isWorking = true;
    notifyListeners();

    try {
      return await _service.createBackup();
    } finally {
      _isWorking = false;
      notifyListeners();
    }
  }

  /// 백업 파일을 골라 지금 아카이브에 합칩니다.
  Future<RestoreOutcome> restoreFromBackup() async {
    if (_isWorking) {
      return RestoreOutcome.cancelled;
    }

    _isWorking = true;
    notifyListeners();

    try {
      return await _service.restoreFromBackup();
    } finally {
      _isWorking = false;
      notifyListeners();
    }
  }
}
