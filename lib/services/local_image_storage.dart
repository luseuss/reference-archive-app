// ImageStorage 약속을 "이 기기의 파일 시스템"으로 실제로 지키는 구현입니다.
//
// 파일을 직접 다루는 코드는 이 파일 안에만 있습니다.
// 나중에 이미지를 클라우드에 올리게 되면 이 파일과 짝이 되는
// cloud_image_storage.dart를 새로 만들어 갈아끼우면 됩니다.
//
// ── 왜 절대경로를 데이터베이스에 저장하지 않나 ──
// 앱 데이터 폴더 위치는 기기마다 다릅니다. Windows와 안드로이드가 다르고,
// 같은 Windows에서도 사용자 이름이 다르면 경로가 달라집니다.
// 그래서 데이터베이스에는 파일 이름만 넣고, 실제 경로는 앱이 실행될 때 조합합니다.
// (CLAUDE.md 설계 원칙 4-4)

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/id_generator.dart';
import 'image_resizer.dart';
import 'image_storage.dart';

/// 이미지를 이 기기의 앱 데이터 폴더에 저장하는 구현체입니다.
class LocalImageStorage implements ImageStorage {
  /// 이미지들을 모아둘 폴더 이름입니다. 앱 데이터 폴더 안에 만들어집니다.
  static const String _imagesFolderName = 'images';

  /// 이미지 폴더의 실제 경로를 구합니다. 폴더가 없으면 만들어줍니다.
  ///
  /// getApplicationSupportDirectory()가 기기별 앱 전용 폴더를 알려줍니다.
  /// Windows에서는 문서 폴더 아래, 안드로이드에서는 앱 전용 저장소 아래입니다.
  Future<Directory> _getImagesDirectory() async {
    final Directory appDir = await getApplicationSupportDirectory();
    final Directory imagesDir = Directory(p.join(appDir.path, _imagesFolderName));

    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  /// 파일 이름만 알 때 그 파일의 전체 경로를 만들어 돌려줍니다.
  @override
  Future<String> getFullPath(String fileName) async {
    final Directory imagesDir = await _getImagesDirectory();
    return p.join(imagesDir.path, fileName);
  }

  /// 원본 이미지 데이터를 받아서 크기를 줄인 뒤 저장하고, 저장된 파일 이름을 돌려줍니다.
  @override
  Future<String?> saveImage(Uint8List originalBytes) async {
    // 크기를 줄이는 작업은 무거워서, 그냥 하면 그동안 화면이 얼어붙습니다.
    // compute()는 이 일을 별도의 작업 공간(isolate)에서 처리해줍니다.
    // 덕분에 큰 사진을 넣어도 화면이 멈추지 않습니다.
    final Uint8List? resizedBytes = await compute(resizeImageBytes, originalBytes);

    if (resizedBytes == null) {
      return null;
    }

    final String fileName = '${newId()}.jpg';
    final Directory imagesDir = await _getImagesDirectory();
    final File file = File(p.join(imagesDir.path, fileName));

    await file.writeAsBytes(resizedBytes);
    return fileName;
  }

  /// 저장된 이미지 파일을 실제로 지웁니다.
  @override
  Future<void> deleteImageFile(String fileName) async {
    final String fullPath = await getFullPath(fileName);
    final File file = File(fullPath);

    if (await file.exists()) {
      await file.delete();
    }
  }
}
