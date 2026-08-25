// 이미지 크기 줄이기가 제대로 동작하는지 확인하는 테스트입니다.
//
// resizeImageBytes()는 파일이나 화면과 상관없이 "데이터를 넣으면 데이터가 나오는"
// 순수한 함수라서, 실제 사진 파일 없이도 테스트할 수 있습니다.
// 테스트 안에서 원하는 크기의 이미지를 즉석에서 만들어 넣습니다.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:reference_archive_app/services/image_resizer.dart';

void main() {
  /// 지정한 크기의 테스트용 PNG 이미지를 만들어 돌려줍니다.
  Uint8List makeTestPng(int width, int height) {
    final img.Image image = img.Image(width: width, height: height);
    // 전부 같은 색으로 채웁니다. 내용은 중요하지 않고 크기만 보면 됩니다.
    img.fill(image, color: img.ColorRgb8(120, 160, 140));
    return Uint8List.fromList(img.encodePng(image));
  }

  /// 결과 데이터를 다시 읽어서 크기를 확인합니다.
  img.Image decodeResult(Uint8List bytes) {
    final img.Image? decoded = img.decodeImage(bytes);
    expect(decoded, isNotNull, reason: '줄인 결과를 다시 읽을 수 없습니다');
    return decoded!;
  }

  test('가로가 긴 큰 이미지는 가로가 1600px로 줄어든다', () {
    // 3000 x 1500 → 긴 변이 가로
    final Uint8List? result = resizeImageBytes(makeTestPng(3000, 1500));

    expect(result, isNotNull);
    final img.Image resized = decodeResult(result!);

    expect(resized.width, maxImageLongEdge);
    // 비율(2:1)이 그대로 유지되어야 합니다.
    expect(resized.height, maxImageLongEdge ~/ 2);
  });

  test('세로가 긴 큰 이미지는 세로가 1600px로 줄어든다', () {
    // 1500 x 3000 → 긴 변이 세로
    final Uint8List? result = resizeImageBytes(makeTestPng(1500, 3000));

    expect(result, isNotNull);
    final img.Image resized = decodeResult(result!);

    expect(resized.height, maxImageLongEdge);
    expect(resized.width, maxImageLongEdge ~/ 2);
  });

  test('정사각형 큰 이미지는 양쪽 다 1600px가 된다', () {
    final Uint8List? result = resizeImageBytes(makeTestPng(2400, 2400));

    expect(result, isNotNull);
    final img.Image resized = decodeResult(result!);

    expect(resized.width, maxImageLongEdge);
    expect(resized.height, maxImageLongEdge);
  });

  test('1600px보다 작은 이미지는 억지로 키우지 않는다', () {
    // 작은 이미지를 늘리면 용량만 커지고 화질은 오히려 나빠집니다.
    final Uint8List? result = resizeImageBytes(makeTestPng(800, 600));

    expect(result, isNotNull);
    final img.Image resized = decodeResult(result!);

    expect(resized.width, 800);
    expect(resized.height, 600);
  });

  test('정확히 1600px인 이미지는 그대로 둔다', () {
    final Uint8List? result = resizeImageBytes(makeTestPng(1600, 1200));

    expect(result, isNotNull);
    final img.Image resized = decodeResult(result!);

    expect(resized.width, 1600);
    expect(resized.height, 1200);
  });

  test('PNG를 넣어도 결과는 JPEG가 된다', () {
    final Uint8List? result = resizeImageBytes(makeTestPng(2000, 1000));

    expect(result, isNotNull);

    // JPEG 파일은 항상 0xFF 0xD8 두 바이트로 시작합니다(파일 형식의 표식).
    expect(result![0], 0xFF);
    expect(result[1], 0xD8);
  });

  test('큰 이미지는 픽셀 수가 크게 줄어든다', () {
    // 여기서 "파일 용량이 줄어든다"고 확인하지 않는 이유:
    // 용량은 그림 내용에 따라 달라집니다. 이 테스트가 만드는 단색 이미지는
    // PNG로 압축하면 아주 작아져서(단색은 PNG가 유리), 오히려 JPEG로 바꾼 쪽이
    // 더 커집니다. 실제 사진은 반대지만, 테스트가 그림 내용에 좌우되면
    // 언제 실패할지 알 수 없는 불안정한 테스트가 됩니다.
    //
    // 우리가 실제로 약속하는 것은 "긴 변을 1600px로 맞춘다"이므로 그것만 확인합니다.
    final Uint8List? result = resizeImageBytes(makeTestPng(3200, 3200));

    expect(result, isNotNull);
    final img.Image resized = decodeResult(result!);

    final int originalPixels = 3200 * 3200;
    final int resizedPixels = resized.width * resized.height;

    // 긴 변이 절반으로 줄었으므로 픽셀 수는 1/4이 되어야 합니다.
    expect(resizedPixels, lessThan(originalPixels));
    expect(resizedPixels, originalPixels ~/ 4);
  });

  test('그림 파일이 아니면 null을 돌려준다', () {
    // 앱이 죽지 않고 조용히 실패해야 합니다.
    // 사용자가 실수로 텍스트 파일을 골랐을 때 앱이 꺼지면 곤란합니다.
    final Uint8List notAnImage = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);

    expect(resizeImageBytes(notAnImage), isNull);
  });
}
