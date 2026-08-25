// 이미지 크기를 줄이는 계산만 담당하는 파일입니다.
//
// 여기에는 파일이나 화면과 관련된 코드가 하나도 없습니다.
// "데이터를 넣으면 데이터가 나오는" 순수한 계산만 들어있어서,
// 실제 사진 파일 없이도 테스트할 수 있습니다.
//
// 파일에 저장하는 일은 image_storage.dart 쪽이 담당합니다.
// 계산과 저장을 나눠두면 각각을 따로 고치고 따로 테스트할 수 있습니다.

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 줄인 뒤 이미지의 긴 변 최대 길이(픽셀)입니다.
///
/// 요즘 사진기나 폰으로 찍은 사진은 한 장에 5~10MB씩 합니다. 레퍼런스를 수백 장
/// 모으면 금방 수 GB가 됩니다. 화면에서 보는 용도라면 1600px이면 충분해서,
/// 기존 웹앱과 똑같은 기준으로 줄입니다.
///
/// 원본이 이보다 작으면 억지로 키우지 않고 그대로 둡니다.
/// 작은 이미지를 늘리면 용량만 커지고 화질은 오히려 나빠지기 때문입니다.
const int maxImageLongEdge = 1600;

/// JPEG로 저장할 때의 품질입니다. 0~100이고 높을수록 깨끗하지만 용량이 큽니다.
/// 85는 눈으로 차이를 알기 어려우면서 용량이 크게 줄어드는 지점입니다.
const int jpegQuality = 85;

/// 이미지 데이터를 받아서 크기를 줄이고 JPEG로 바꿔 돌려줍니다.
///
/// **이 함수는 클래스 안이 아니라 밖에 있어야 합니다.** compute()로 별도 작업
/// 공간에서 실행하려면 최상위 함수여야 한다는 규칙이 있기 때문입니다.
///
/// 그림 파일이 아니거나 깨진 파일이면 null을 돌려줍니다.
Uint8List? resizeImageBytes(Uint8List originalBytes) {
  final img.Image? decoded = _tryDecode(originalBytes);

  if (decoded == null) {
    return null;
  }

  final img.Image resized = _resizeToFit(decoded);

  // JPEG로 통일해 저장합니다. PNG는 사진에서 용량이 훨씬 크고,
  // 형식이 여러 개면 나중에 다루기도 번거롭습니다.
  return Uint8List.fromList(img.encodeJpg(resized, quality: jpegQuality));
}

/// 이미지 데이터를 읽어봅니다. 읽지 못하면 null을 돌려줍니다.
///
/// try/catch로 감싼 이유:
/// decodeImage()는 "못 읽으면 null을 준다"고 되어 있지만, 실제로는 그림이 아닌
/// 데이터를 넣으면 **오류를 내며 터집니다.** (내부적으로 여러 형식을 하나씩
/// 시험해보는데, 그 과정에서 데이터 범위를 벗어나 읽는 경우가 있습니다.)
///
/// 사용자가 실수로 그림이 아닌 파일을 골랐을 때 앱이 꺼지면 안 되므로
/// 여기서 확실히 막습니다.
img.Image? _tryDecode(Uint8List bytes) {
  try {
    return img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
}

/// 이미지의 긴 변이 maxImageLongEdge를 넘으면 비율을 유지한 채 줄입니다.
///
/// 원본이 이미 작으면 그대로 돌려줍니다(억지로 키우지 않음).
img.Image _resizeToFit(img.Image source) {
  final int longEdge = source.width > source.height ? source.width : source.height;

  if (longEdge <= maxImageLongEdge) {
    return source;
  }

  // 가로가 더 길면 width를 기준으로, 세로가 더 길면 height를 기준으로 줄입니다.
  // 한쪽만 지정하면 나머지 한쪽은 비율에 맞춰 자동으로 계산됩니다.
  if (source.width >= source.height) {
    return img.copyResize(source, width: maxImageLongEdge);
  } else {
    return img.copyResize(source, height: maxImageLongEdge);
  }
}
