// 호버 미리보기가 **어느 기기에서 켜지는지**를 확인하는 테스트입니다.
//
// ── 이 테스트가 확인하지 못하는 것 ──
// 미리보기 영상이 실제로 재생되는지는 여기서 알 수 없습니다.
// 테스트 환경에서는 웹뷰 부품이 안 켜지기 때문입니다(재생 화면과 같은 사정).
// 그건 `flutter run -d windows`로 직접 봐야 합니다.
//
// 대신 여기서는 자동으로 확인할 수 있는 것을 확실히 잡아둡니다.
//   - 폰에서는 호버를 아예 살피지 않는지 (마우스가 없는 기기)
//   - 마우스를 올려도 **바로** 켜지지는 않는지 (스쳐 지나가는 것과 구분)
//   - 이미지 카드는 미리보기 대상이 아닌지

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/screens/home_screen.dart';

void main() {
  group('어느 기기에서 켜지는가', () {
    tearDown(() {
      // 바꿔둔 값을 원래대로 돌려놓습니다.
      // 안 그러면 뒤에 실행되는 다른 테스트까지 영향을 받습니다.
      debugDefaultTargetPlatformOverride = null;
    });

    test('데스크톱에서는 켜진다', () {
      for (final TargetPlatform platform in <TargetPlatform>[
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(supportsHoverPreview, isTrue, reason: '$platform');
      }
    });

    test('폰·태블릿에서는 꺼진다', () {
      // 폰에는 마우스가 없어서 "올려두기"라는 동작 자체가 없습니다.
      // 억지로 흉내내지 않는다는 것이 이 프로젝트의 방침입니다.
      for (final TargetPlatform platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.iOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(supportsHoverPreview, isFalse, reason: '$platform');
      }
    });
  });

  group('미리보기를 시작하기까지 기다리는 시간', () {
    test('바로 켜지지 않는다', () {
      // 0이면 목록을 훑을 때 지나가는 길의 영상이 줄줄이 켜졌다 꺼집니다.
      expect(hoverPreviewDelay, greaterThan(Duration.zero));
    });

    test('답답할 만큼 길지도 않다', () {
      // 1초를 넘으면 "왜 안 나오지?" 하게 됩니다.
      expect(hoverPreviewDelay, lessThanOrEqualTo(const Duration(seconds: 1)));
    });
  });
}
