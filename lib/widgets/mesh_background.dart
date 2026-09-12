// 화면 뒤에 흐릿하게 번지는 "색 안개"를 그리는 위젯입니다. (에메랄드 글래스 디자인)
//
// 지금은 메인 화면(home_screen.dart)에만 씁니다. 사이드바·머리줄·카드
// 아래쪽 글자 부분이 반투명한 것은 이 안개가 뒤에 있어야 뜻이 있습니다 —
// 안개 없이 반투명 패널만 있으면 그냥 흐릿한 회색으로 보일 뿐입니다.
//
// ── 왜 블러를 한 번만 먹이나 ──
// 사이드바·카드마다 각자 BackdropFilter로 뒤를 흐리게 하면, 그 개수만큼
// 블러 연산이 반복돼 카드가 많아질수록 느려집니다. 대신 이 위젯이 안개
// 자체를 미리 한 번 흐릿하게 그려두면, 그 위에 얹는 반투명 패널들은
// 그냥 알파색만 칠해도 "뿌옇게 비치는" 느낌이 그대로 납니다 — 안개
// 자체에 또렷한 경계가 없어서, 위에 블러를 또 먹일 필요가 없습니다.
// (app_palette.dart 위쪽 설명 참고)

import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// 배경에 색 안개를 깔고, 그 위에 [child]를 그리는 위젯입니다.
class MeshBackground extends StatelessWidget {
  const MeshBackground({super.key, required this.child});

  /// 안개 위에 그릴 실제 화면 내용입니다.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // 맨 아래 바탕색. 안개가 옅은 라이트 모드에서도 빈 곳이 하얗게
        // 비지 않게 깔아둡니다.
        ColoredBox(color: palette.background),

        // 안개 자체입니다. ImageFiltered로 이 레이어 전체를 한 번에
        // 흐릿하게 만듭니다 — 안개 뭉치 몇 개만 그리면 되는 가벼운
        // 레이어라 한 번에 블러를 먹여도 비용이 크지 않습니다.
        Positioned.fill(
          child: IgnorePointer(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
              child: _MeshBlobs(colors: palette.meshColors),
            ),
          ),
        ),

        child,
      ],
    );
  }
}

/// 색 안개를 이루는 뭉친 원들입니다. 화면 네 귀퉁이 근처에 하나씩 둬서
/// 특정 방향으로 쏠리지 않게 합니다.
class _MeshBlobs extends StatelessWidget {
  const _MeshBlobs({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    // 안개 색이 넷보다 적게 와도(테스트 등) 죽지 않게 순환해서 씁니다.
    Color colorAt(int index) => colors[index % colors.length];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;

        return Stack(
          children: <Widget>[
            _blob(colorAt(0), left: w * 0.02, top: h * -0.08, size: w * 0.5),
            _blob(colorAt(1), left: w * 0.55, top: h * 0.02, size: w * 0.5),
            _blob(colorAt(2), left: w * 0.3, top: h * 0.62, size: w * 0.55),
            _blob(colorAt(3), left: w * -0.12, top: h * 0.55, size: w * 0.4),
          ],
        );
      },
    );
  }

  /// 안개 뭉치 하나입니다. 가운데가 진하고 가장자리로 갈수록 완전히
  /// 투명해지는 원이라, 여러 개를 겹쳐도 각지지 않고 자연스럽게 섞입니다.
  Widget _blob(Color color, {required double left, required double top, required double size}) {
    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
