// 이미지의 퍼셉추얼 해시(dHash)를 계산하는 곳입니다.
//
// ── dHash가 무엇인가 ──
// 이미지를 아주 작게(9x8) 축소한 뒤, 가로로 인접한 픽셀끼리 밝기를
// 비교해서 64비트(0/1 64개) "지문"을 만듭니다. 픽셀이 완전히 같지 않아도
// 시각적으로 비슷한 이미지끼리는 비슷한 비트 패턴이 나옵니다. 두 해시가
// 몇 비트 다른지(해밍 거리)로 "얼마나 비슷한가"를 잽니다.
// (해밍 거리 계산과 이걸 유사도 점수에 반영하는 곳은 utils/similarity.dart)
//
// ── 왜 CORS 걱정이 없나 ──
// 기존 웹앱은 브라우저 <canvas>로 이 계산을 했어서 외부 이미지가 CORS에
// 막히면 계산이 실패했습니다. 이 앱은 이미지가 전부 로컬 파일이라 그런
// 걱정이 없습니다. 대신 파일이 깨졌을 가능성은 여전히 있어서 실패하면
// null을 돌려줍니다.

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 해시를 만들 때 축소하는 가로/세로 크기입니다.
/// 가로가 세로보다 1 더 큰 이유: 가로로 인접한 픽셀을 비교해서 비트를
/// 만들기 때문에, 8칸을 비교하려면 9개의 픽셀이 필요합니다.
const int dHashWidth = 9;
const int dHashHeight = 8;

/// 이미지 데이터에서 dHash(64비트 문자열)를 계산합니다.
/// 그림 파일이 아니거나 깨진 파일이면 null을 돌려줍니다.
String? dHashFromBytes(Uint8List bytes) {
  final img.Image? decoded = _tryDecode(bytes);
  if (decoded == null) {
    return null;
  }

  // 가로세로 비율은 무시하고 강제로 9x8에 맞춥니다. 해시를 만드는 데는
  // 원본 비율이 중요하지 않고, 비교하는 두 이미지가 항상 같은 방식으로
  // 눌려야 공정하게 비교할 수 있습니다.
  final img.Image resized = img.copyResize(
    decoded,
    width: dHashWidth,
    height: dHashHeight,
  );

  final StringBuffer bits = StringBuffer();
  for (int y = 0; y < dHashHeight; y++) {
    for (int x = 0; x < dHashWidth - 1; x++) {
      final double left = _luminance(resized.getPixel(x, y));
      final double right = _luminance(resized.getPixel(x + 1, y));
      bits.write(left > right ? '1' : '0');
    }
  }
  return bits.toString();
}

/// 픽셀 하나의 밝기를 구합니다. 사람 눈이 초록에 더 민감하다는 것을
/// 반영한 가중치입니다(기존 웹앱과 동일한 값).
double _luminance(img.Pixel pixel) {
  return 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
}

/// 이미지 데이터를 읽어봅니다. 읽지 못하면 null을 돌려줍니다.
/// (image_resizer.dart의 _tryDecode와 같은 이유로 try/catch로 감쌉니다 —
/// decodeImage는 그림이 아닌 데이터를 넣으면 오류를 내며 터질 수 있습니다)
img.Image? _tryDecode(Uint8List bytes) {
  try {
    return img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
}
