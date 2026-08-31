// dHash(퍼셉추얼 해시) 계산이 맞는지 확인하는 테스트입니다.
// test/services/image_resize_test.dart와 같은 방식으로, 실제 사진 파일
// 없이 image 패키지로 즉석에서 테스트용 이미지를 만들어 씁니다.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:reference_archive_app/services/image_hash.dart';
import 'package:reference_archive_app/utils/similarity.dart';

void main() {
  /// 왼쪽 절반은 [leftGray], 오른쪽 절반은 [rightGray] 밝기로 채운
  /// 테스트용 이미지를 만듭니다. 그레이스케일이라 r=g=b로 채웁니다.
  Uint8List makeHalfSplitImage({
    required int leftGray,
    required int rightGray,
    int width = 100,
    int height = 80,
  }) {
    final img.Image image = img.Image(width: width, height: height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int gray = x < width ~/ 2 ? leftGray : rightGray;
        image.setPixelRgb(x, y, gray, gray, gray);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  test('64비트(글자 64개) 문자열을 돌려준다', () {
    final Uint8List bytes = makeHalfSplitImage(leftGray: 0, rightGray: 255);
    final String? hash = dHashFromBytes(bytes);
    expect(hash, isNotNull);
    expect(hash!.length, 64);
    expect(hash.split('').every((String c) => c == '0' || c == '1'), isTrue);
  });

  test('같은 이미지면 해밍 거리가 0이다', () {
    final Uint8List bytes = makeHalfSplitImage(leftGray: 30, rightGray: 200);
    final String? hashA = dHashFromBytes(bytes);
    final String? hashB = dHashFromBytes(bytes);
    expect(hammingDistance(hashA, hashB), 0);
  });

  test('밝기가 뚜렷하게 반대인 이미지는 해밍 거리가 크다', () {
    // 왼쪽이 어둡고 오른쪽이 밝은 이미지 vs 그 반대.
    // dHash는 "가로로 인접한 픽셀 중 어느 쪽이 더 밝은가"를 비트로 담으므로,
    // 밝기 순서가 뒤집히면 대부분의 비트가 뒤집힙니다.
    final Uint8List a = makeHalfSplitImage(leftGray: 0, rightGray: 255);
    final Uint8List b = makeHalfSplitImage(leftGray: 255, rightGray: 0);

    final String? hashA = dHashFromBytes(a);
    final String? hashB = dHashFromBytes(b);

    final int? distance = hammingDistance(hashA, hashB);
    expect(distance, isNotNull);
    // 왼쪽/오른쪽 단색 이미지는 한 행에 경계선이 하나뿐이라, 행마다 최대 1비트만
    // 다릅니다. 8행 중 절반 이상(>4)에서 경계 비트가 다르면 뚜렷하게 다르다고 봅니다.
    expect(distance!, greaterThan(4));
  });

  test('그림 파일이 아니면 null을 돌려준다', () {
    final Uint8List notAnImage = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
    expect(dHashFromBytes(notAnImage), isNull);
  });

  /// 사진처럼 픽셀마다 밝기가 조금씩 다른 그러데이션 이미지를 만듭니다.
  /// (단색 블록은 nearest/average 방식 차이가 안 드러나서 이 테스트에는
  /// 안 맞습니다 — 아래 테스트 설명 참고)
  img.Image makeGradientPhoto({int width = 400, int height = 300}) {
    final img.Image image = img.Image(width: width, height: height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int r = (x * 255 / width).round() % 256;
        final int g = (y * 255 / height).round() % 256;
        final int b = ((x + y) * 255 / (width + height)).round() % 256;
        image.setPixelRgb(x, y, r, g, b);
      }
    }
    return image;
  }

  test('같은 사진을 원본과 미리 축소한 사본, 두 해상도에서 찍어도 해시가 거의 같다', () {
    // 실제 상황을 흉내냅니다: reference_importer.dart는 원본 업로드 바이트를
    // 해시하고, phash_backfill.dart는 이미 1600px로 줄여 저장된 파일을
    // 나중에 다시 읽어 해시합니다 — 같은 사진인데 해상도가 다른 두 경로.
    // average(평균) 보간이 아니라 nearest(최근접)였다면 이 두 해시가
    // 서로 다르게 나올 수 있었습니다(Important 2 참고).
    final img.Image original = makeGradientPhoto(width: 400, height: 300);
    final img.Image alreadyResized = img.copyResize(
      original,
      width: 200,
      height: 150,
      interpolation: img.Interpolation.average,
    );

    final Uint8List originalBytes = Uint8List.fromList(img.encodePng(original));
    final Uint8List resizedBytes = Uint8List.fromList(img.encodePng(alreadyResized));

    final String? hashOriginal = dHashFromBytes(originalBytes);
    final String? hashResized = dHashFromBytes(resizedBytes);

    final int? distance = hammingDistance(hashOriginal, hashResized);
    expect(distance, isNotNull);
    expect(distance!, lessThanOrEqualTo(2));
  });
}
