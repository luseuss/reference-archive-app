// 레퍼런스를 앱에 들여오는 일을 모아둔 파일입니다.
//
// 들어오는 길이 넷입니다. **어느 길로 들어오든 저장하는 방식은 하나**여야
// 똑같이 리사이즈되고 똑같이 기록됩니다.
//
//   1. 파일 고르기 창
//   2. 창에 끌어다 놓기
//   3. 붙여넣기 (Ctrl+V)
//   4. 유튜브 주소
//
// ── 왜 화면에서 떼어냈나 ──
// 원래 이 내용은 home_screen.dart 안에 있었습니다. 그런데 화면 파일이 1400줄이
// 넘어가면서 "목록 화면 코드"를 찾기가 어려워졌습니다. 여기 있는 것들은
// **화면과 아무 상관이 없습니다** — 어디에 어떻게 그릴지 모르고, 그냥 들여와
// 저장하고 결과만 알려줍니다.
//
// 화면은 결과를 받아 안내를 띄우고 목록을 새로 고치는 일만 합니다.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../models/enums.dart';
import '../models/reference_item.dart';
import '../repositories/reference_repository.dart';
import '../utils/id_generator.dart';
import 'dropped_item_reader.dart';
import 'image_source.dart';
import 'image_storage.dart';
import 'youtube_info_source.dart';
import 'youtube_url.dart';

/// 들여오기를 한 번 하고 난 결과입니다.
///
/// 화면은 이걸 받아서 안내 문구를 띄웁니다. 몇 개 성공했고 몇 개 실패했는지,
/// 실패했다면 무엇이 문제였는지가 들어 있습니다.
class ImportOutcome {
  const ImportOutcome({
    this.savedCount = 0,
    this.failedCount = 0,
    this.errorMessage,
    this.successMessage,
  });

  /// 아무것도 하지 않고 끝난 경우입니다. (사용자가 파일 고르기를 취소한 경우 등)
  const ImportOutcome.nothingToDo()
    : savedCount = 0,
      failedCount = 0,
      errorMessage = null,
      successMessage = null;

  /// 저장에 성공한 개수입니다.
  final int savedCount;

  /// 실패한 개수입니다.
  final int failedCount;

  /// 실패한 이유입니다. 성공했으면 null입니다.
  ///
  /// 이 글자는 그대로 사용자에게 보여줍니다. 그래서 "그 사이트가 막고 있습니다"처럼
  /// 다음에 뭘 하면 되는지 알 수 있는 문장이 들어갑니다.
  final String? errorMessage;

  /// 성공했을 때 보여줄 문구입니다. 없으면 화면이 "N장 추가했습니다"로 만듭니다.
  ///
  /// 유튜브는 "1장 추가했습니다"가 어색해서 따로 문구를 넘깁니다.
  final String? successMessage;

  /// 사용자에게 알릴 것이 아무것도 없는 경우인지 여부입니다.
  bool get isNothingToDo => savedCount == 0 && failedCount == 0;
}

/// 레퍼런스를 들여와 저장하는 도구입니다.
class ReferenceImporter {
  ReferenceImporter({
    required this.repository,
    required this.imageStorage,
    required this.imageSource,
    required this.youtubeInfoSource,
  });

  /// 레퍼런스를 저장하는 통로입니다.
  final ReferenceRepository repository;

  /// 이미지 파일을 저장하는 도구입니다.
  final ImageStorage imageStorage;

  /// 주소나 클립보드에서 이미지를 가져오는 도구입니다.
  final ImageSource imageSource;

  /// 유튜브에서 제목과 썸네일을 가져오는 도구입니다.
  final YoutubeInfoSource youtubeInfoSource;

  /// 끌어다 놓은 것을 읽어주는 도구입니다.
  late final DroppedItemReader _droppedItemReader = DroppedItemReader(
    imageSource,
  );

  /// 파일 고르기 창을 띄워 이미지를 들여옵니다.
  Future<ImportOutcome> importFromFilePicker({required String partId}) async {
    // 여러 장을 한 번에 고를 수 있습니다. 사용자가 취소하면 null이 돌아옵니다.
    //
    // withData: true를 주면 파일 내용을 메모리에 함께 담아줍니다.
    // 안드로이드에서는 다른 앱이 넘겨준 파일에 실제 경로가 없을 수 있어서,
    // 경로 대신 내용을 직접 받는 편이 안전합니다.
    final FilePickerResult? picked = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
      dialogTitle: '레퍼런스로 추가할 이미지 고르기',
    );

    if (picked == null || picked.files.isEmpty) {
      return const ImportOutcome.nothingToDo();
    }

    int savedCount = 0;
    int failedCount = 0;

    for (final PlatformFile file in picked.files) {
      final bool ok = await _saveOneFile(file, partId);
      if (ok) {
        savedCount++;
      } else {
        failedCount++;
      }
    }

    return ImportOutcome(savedCount: savedCount, failedCount: failedCount);
  }

  /// 창에 끌어다 놓은 것들을 들여옵니다.
  ///
  /// ── 브라우저에서 끌면 무엇이 오는가 ──
  /// 상황마다 다릅니다. 무엇이 오는지 가려내는 일은 DroppedItemReader가 합니다.
  /// 여기서는 그 결과를 저장하는 일만 합니다.
  Future<ImportOutcome> importFromDrop(
    PerformDropEvent event, {
    required String partId,
  }) async {
    int savedCount = 0;
    int failedCount = 0;
    String? lastError;

    for (final DropItem item in event.session.items) {
      final DataReader? reader = item.dataReader;
      if (reader == null) {
        failedCount++;
        continue;
      }

      // 유튜브 링크를 끌어온 것인지 **먼저** 봅니다.
      // 그냥 읽으면 이미지인 줄 알고 내려받다가 실패합니다.
      // (자세한 이유는 DroppedItemReader.youtubeVideoIdOf() 설명 참고)
      final String? videoId = await _droppedItemReader.youtubeVideoIdOf(reader);
      if (videoId != null) {
        final bool savedVideo = await saveYoutube(videoId, partId: partId);
        if (savedVideo) {
          savedCount++;
        } else {
          failedCount++;
          lastError = '유튜브 영상을 추가하지 못했습니다.';
        }
        continue;
      }

      final ImageFetchResult fetched = await _droppedItemReader.read(reader);

      if (!fetched.isSuccess) {
        failedCount++;
        lastError = fetched.errorMessage;
        continue;
      }

      final bool ok = await _saveImageBytes(
        fetched.bytes!,
        partId: partId,
        title: fetched.suggestedTitle,
      );
      if (ok) {
        savedCount++;
      } else {
        failedCount++;
        // 가져오기는 됐는데 그림이 아닌 경우입니다.
        // (예: 이미지가 아니라 웹페이지 주소를 받아온 경우)
        // "그림 파일이 맞는지 확인하세요"보다 다음에 뭘 하면 되는지 알려줍니다.
        lastError =
            '가져온 것이 이미지가 아닙니다. '
            '이미지를 우클릭해 "이미지 복사" 후 붙여넣어 보세요.';
      }
    }

    return ImportOutcome(
      savedCount: savedCount,
      failedCount: failedCount,
      errorMessage: lastError,
    );
  }

  /// 클립보드에 있는 것을 들여옵니다. (Ctrl+V)
  ///
  /// 세 가지를 순서대로 시도합니다.
  ///   1. 클립보드에 **이미지**가 있으면 그걸 씁니다. (브라우저에서 "이미지 복사")
  ///   2. 글자가 **유튜브 주소**면 영상으로 저장합니다.
  ///   3. 글자가 **이미지 주소**면 내려받습니다. (브라우저에서 "이미지 주소 복사")
  ///
  /// 사용자는 둘 중 무엇을 복사했는지 신경 쓰지 않아도 되게 하려는 것입니다.
  Future<ImportOutcome> importFromClipboard({required String partId}) async {
    ImageFetchResult fetched = await imageSource.fetchFromClipboard();

    // 주소를 실제로 받아보려 시도했는지 기록합니다.
    //
    // 이걸 구분하는 이유: 주소를 받아보다 실패한 경우에는 그쪽에서 온 구체적인
    // 이유("그 사이트가 막고 있습니다" 등)를 그대로 보여줘야 합니다.
    // 그걸 "클립보드에 이미지가 없습니다"로 덮어쓰면, 사용자는 클립보드를
    // 다시 복사하러 가는 엉뚱한 행동을 하게 됩니다.
    bool triedUrl = false;

    if (!fetched.isSuccess) {
      final String? text = await imageSource.readClipboardText();

      // 유튜브 주소면 이미지로 내려받으려 하지 말고 영상으로 저장합니다.
      // 유튜브 페이지를 내려받아 봐야 HTML이라 "그림이 아니다"로 실패합니다.
      final String? videoId = text == null ? null : youtubeVideoIdFrom(text);
      if (videoId != null) {
        return importYoutube(videoId, partId: partId);
      }

      if (text != null && looksLikeUrl(text)) {
        triedUrl = true;
        fetched = await imageSource.fetchFromUrl(text.trim());
      }
    }

    if (!fetched.isSuccess) {
      return ImportOutcome(
        failedCount: 1,
        errorMessage: triedUrl
            // 주소를 받아보다 실패 → 그쪽 이유를 그대로 전합니다.
            ? fetched.errorMessage
            // 클립보드에 쓸 만한 게 아예 없음 → 무엇을 하면 되는지 알려줍니다.
            : '클립보드에 이미지가 없습니다. 브라우저에서 이미지를 우클릭해 '
                  '"이미지 복사" 또는 "이미지 주소 복사"를 해보세요.',
      );
    }

    final bool ok = await _saveImageBytes(
      fetched.bytes!,
      partId: partId,
      title: fetched.suggestedTitle,
    );

    return ImportOutcome(
      savedCount: ok ? 1 : 0,
      failedCount: ok ? 0 : 1,
      errorMessage: ok ? null : '이미지를 저장하지 못했습니다.',
    );
  }

  /// 영상 번호로 유튜브 레퍼런스를 들여옵니다.
  Future<ImportOutcome> importYoutube(
    String videoId, {
    required String partId,
  }) async {
    final bool ok = await saveYoutube(videoId, partId: partId);

    return ImportOutcome(
      savedCount: ok ? 1 : 0,
      failedCount: ok ? 0 : 1,
      errorMessage: ok ? null : '유튜브 영상을 추가하지 못했습니다.',
      successMessage: '유튜브 영상을 추가했습니다.',
    );
  }

  /// 클립보드에 유튜브 주소가 들어있으면 그걸 돌려줍니다. 없으면 null입니다.
  ///
  /// 주소 입력 대화상자를 띄울 때 미리 채워주는 데 씁니다.
  /// 방금 복사해온 것을 또 붙여넣게 하는 것은 번거롭기만 합니다.
  Future<String?> youtubeUrlInClipboard() async {
    final String? text = await imageSource.readClipboardText();

    if (text != null && isYoutubeVideoUrl(text)) {
      return text.trim();
    }
    return null;
  }

  /// 유튜브 영상 하나를 레퍼런스로 저장합니다.
  ///
  /// ── 썸네일을 왜 내려받아 저장하나 ──
  /// 화면에 띄울 때마다 img.youtube.com에서 가져오게 할 수도 있습니다.
  /// 하지만 그러면 **인터넷이 없을 때 목록이 텅 빈 회색 칸으로 보입니다.**
  /// 이 앱은 "내 컴퓨터에 모아두는" 것이 핵심이라, 이미지와 똑같이 파일로
  /// 저장해둡니다. 그러면 비행기 안에서도 목록은 그대로 보입니다.
  ///
  /// 제목이나 썸네일을 못 가져와도 **저장은 합니다.** 영상 번호만 있으면
  /// 나중에 재생할 수 있고, 제목은 편집 화면에서 직접 적을 수 있습니다.
  ///
  /// 성공하면 true, 실패하면 false를 돌려줍니다.
  Future<bool> saveYoutube(String videoId, {required String partId}) async {
    try {
      final YoutubeVideoInfo info = await youtubeInfoSource.fetch(videoId);

      // 썸네일은 있으면 저장하고, 없으면 없는 대로 넘어갑니다.
      String? savedFileName;
      final Uint8List? thumbnail = info.thumbnailBytes;
      if (thumbnail != null) {
        savedFileName = await imageStorage.saveImage(thumbnail);
      }

      final DateTime now = DateTime.now().toUtc();
      await repository.save(
        ReferenceItem(
          id: newId(),
          type: ReferenceType.youtube,
          title: info.title,
          fileName: savedFileName,
          partId: partId,
          youtubeVideoId: videoId,
          createdAt: now,
          updatedAt: now,
        ),
      );
      return true;
    } catch (error) {
      debugPrint('유튜브 저장 실패: $error');
      return false;
    }
  }

  // ── 아래는 이 파일 안에서만 쓰는 도우미들입니다 ──

  /// 고른 파일 하나를 줄여서 저장하고 레퍼런스로 등록합니다.
  Future<bool> _saveOneFile(PlatformFile file, String partId) async {
    final String originalName = file.name;
    try {
      // withData: true로 골랐으므로 bytes에 내용이 들어있습니다.
      // 혹시 없으면(플랫폼 사정) 경로로 읽어봅니다.
      Uint8List? bytes = file.bytes;

      if (bytes == null) {
        final String? path = file.path;
        if (path == null) {
          return false;
        }
        bytes = await File(path).readAsBytes();
      }

      return await _saveImageBytes(
        bytes,
        partId: partId,
        title: _stripExtension(originalName),
      );
    } catch (error) {
      // 파일 하나가 실패해도 나머지는 계속 처리되도록 여기서 잡습니다.
      // 사진 10장 중 1장이 깨졌다고 9장까지 못 넣으면 곤란합니다.
      debugPrint('이미지 저장 실패 ($originalName): $error');
      return false;
    }
  }

  /// 이미지 데이터를 줄여서 저장하고 레퍼런스로 등록합니다.
  ///
  /// **파일 고르기·끌어다 놓기·붙여넣기가 전부 이 함수로 모입니다.**
  /// 가져오는 경로는 셋이지만 저장하는 방식은 하나여야, 어느 쪽으로 넣든
  /// 똑같이 리사이즈되고 똑같이 기록됩니다.
  Future<bool> _saveImageBytes(
    Uint8List bytes, {
    required String partId,
    String? title,
  }) async {
    try {
      final String? savedFileName = await imageStorage.saveImage(bytes);

      // 그림 파일이 아니거나 깨진 파일이면 null이 돌아옵니다.
      if (savedFileName == null) {
        return false;
      }

      final DateTime now = DateTime.now().toUtc();
      await repository.save(
        ReferenceItem(
          id: newId(),
          type: ReferenceType.image,
          // 제목을 못 뽑아낸 경우(클립보드 등)에는 빈 제목으로 둡니다.
          // 목록에서는 "(제목 없음)"으로 보이고 편집 화면에서 고칠 수 있습니다.
          title: title ?? '',
          fileName: savedFileName,
          partId: partId,
          createdAt: now,
          updatedAt: now,
        ),
      );
      return true;
    } catch (error) {
      debugPrint('이미지 저장 실패: $error');
      return false;
    }
  }

  /// 파일 이름에서 확장자를 떼어냅니다. ("노을.jpg" → "노을")
  String _stripExtension(String fileName) {
    final int dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0) {
      return fileName;
    }
    return fileName.substring(0, dotIndex);
  }
}
