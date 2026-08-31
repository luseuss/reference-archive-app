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
  //
  // interpolation을 average(평균)로 지정하는 이유: 이 앱은 같은 사진을
  // 서로 다른 해상도에서 두 번 해시합니다 — 들여오는 순간에는 원본
  // 업로드 바이트를(reference_importer.dart), 나중에 되채울 때는 이미
  // 1600px로 줄여 저장된 파일을(phash_backfill.dart) 읽습니다. 기본값인
  // nearest(최근접) 방식은 픽셀을 그냥 콕콕 집어서 줄이기 때문에, 원본
  // 해상도가 다르면 같은 사진이라도 골라내는 픽셀이 달라져 해시가 달라질
  // 수 있습니다. average는 영역 전체를 평균 내므로 해상도가 달라도
  // "시각적으로 같은 사진"이면 같은 결과가 나옵니다.
  final img.Image resized = img.copyResize(
    decoded,
    width: dHashWidth,
    height: dHashHeight,
    interpolation: img.Interpolation.average,
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
