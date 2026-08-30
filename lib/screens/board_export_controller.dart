// 무드보드 판 카드 전체를 사진으로 내보내는 상태와 동작을 모은 곳입니다.
//
// ── 왜 board_screen.dart에서 뺐나 ──
// board_interaction_controller.dart를 뺀 것과 같은 이유입니다. "지금
// 내보내는 중인지" 상태와 "찍고 저장하기" 동작이 함께 다녀야 하는데,
// 그냥 함수만 옮기면 그 상태를 board_screen.dart가 계속 들고 있어야 해서
// 오히려 읽기 어려워집니다. 그래서 상태까지 함께 옮길 작은 클래스를
// 만들었습니다.
//
// ── ChangeNotifier가 무엇인가 ──
// "값이 바뀌었다"고 화면에 알려주는 Flutter의 기본 장치입니다.
// board_interaction_controller.dart와 같은 방식입니다. 내보내는 중
// 상태가 바뀌면 notifyListeners()가 불리고, ListenableBuilder로 감싼
// 버튼이 저절로 다시 그려집니다(예: 내보내는 동안 버튼을 못 누르게).

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/board.dart';
import '../models/reference_item.dart';
import '../services/board_exporter.dart';

/// [BoardExportController.export]가 끝난 뒤 무슨 일이 있었는지입니다.
///
/// 화면 쪽은 이 값만 보고 스낵바에 어떤 문구를 띄울지 고르면 됩니다 —
/// "찍기·저장이 어떻게 이루어지는지"는 몰라도 됩니다.
enum BoardExportOutcome {
  /// 사진을 찍어서 파일로 저장했습니다.
  saved,

  /// 저장 대화상자에서 사용자가 취소했습니다. **실패가 아닙니다.**
  cancelled,

  /// 내보낼 카드가 하나도 없었습니다.
  noCards,
}

/// 무드보드 판을 사진으로 내보내는 상태와 동작을 담습니다.
class BoardExportController extends ChangeNotifier {
  /// 지금 이미지로 내보내는 중인지 여부입니다.
  ///
  /// 사진을 미리 읽고 찍는 데 잠깐 시간이 걸립니다. 그 사이 버튼을 다시
  /// 누르면 내보내기가 겹쳐 실행되므로, 끝날 때까지 버튼을 눌러도 반응하지
  /// 않게 막아둡니다.
  bool get isExporting => _isExporting;
  bool _isExporting = false;

  /// 판에 놓인 카드 전체를 사진(PNG)으로 찍어서 저장 대화상자로 저장합니다.
  ///
  /// **지금 화면에 보이는 부분이 아니라 카드 전체입니다.** 팀에 공유할
  /// 때 화면 밖에 있던 카드가 잘려나가면 안 되기 때문입니다.
  /// (services/board_exporter.dart 설명 참고)
  ///
  /// 이미 내보내는 중이면 조용히 아무 일도 안 합니다(null을 돌려줍니다).
  Future<BoardExportOutcome?> export({
    required BuildContext context,
    required String boardName,
    required List<BoardCard> cards,
    required Map<String, ReferenceItem> itemsById,
    required Map<String, String?> imagePaths,
  }) async {
    if (_isExporting) {
      return null;
    }

    _isExporting = true;
    notifyListeners();

    try {
      final Uint8List? bytes = await exportBoardImage(
        context: context,
        cards: cards,
        itemsById: itemsById,
        imagePaths: imagePaths,
      );

      if (bytes == null) {
        return BoardExportOutcome.noCards;
      }

      if (!context.mounted) {
        return null;
      }

      // 저장 대화상자를 엽니다. Windows에서는 사용자가 고른 자리에
      // file_picker가 bytes를 그대로 파일로 씁니다.
      final String? savedPath = await FilePicker.saveFile(
        dialogTitle: '무드보드 이미지 저장',
        fileName: '$boardName.png',
        type: FileType.custom,
        allowedExtensions: <String>['png'],
        bytes: bytes,
      );

      // 취소했으면(null) 조용히 아무 일도 안 합니다. 취소는 실패가
      // 아닙니다.
      return savedPath != null
          ? BoardExportOutcome.saved
          : BoardExportOutcome.cancelled;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }
}
