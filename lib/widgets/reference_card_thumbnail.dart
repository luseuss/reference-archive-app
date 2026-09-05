// 레퍼런스 카드의 그림 부분(썸네일 + 그 위에 얹는 것들)입니다.
//
// reference_card.dart에서 뺐습니다(CLAUDE.md "밀린 정리거리" 참고).
// 카드 한 장의 절반 가까이가 "그림을 어떻게 보여줄지"(자리표시자, 유튜브
// 재생 버튼, 호버 미리보기, 고르기 체크박스)였는데, 그 아래 글자 부분과는
// 성격이 다른 관심사라 나눌 수 있었습니다.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/enums.dart';
import '../models/reference_item.dart';

/// 카드의 그림 부분을 만듭니다.
///
/// 상황에 따라 그림 위에 두 가지가 얹힙니다.
///   - 유튜브면 재생 버튼 (누르면 편집 화면이 아니라 바로 재생)
///   - 고르기 모드면 체크박스
class ReferenceCardThumbnail extends StatelessWidget {
  const ReferenceCardThumbnail({
    super.key,
    required this.item,
    required this.imagePath,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onSelectToggle,
    required this.onPlay,
    this.isPreviewPlaying = false,
    this.previewUrl,
  });

  /// 보여줄 레퍼런스입니다.
  final ReferenceItem item;

  /// 이미지 파일의 전체 경로입니다. 아직 못 구했으면 null입니다.
  final String? imagePath;

  /// 지금 여러 장 고르는 중인지 여부입니다.
  final bool isSelectionMode;

  /// 이 카드가 지금 골라져 있는지 여부입니다.
  final bool isSelected;

  /// 체크박스를 눌렀을 때(또는 카드 본체를 눌렀을 때) 실행할 동작입니다.
  final VoidCallback onSelectToggle;

  /// 재생 버튼을 눌렀을 때 실행할 동작입니다. (유튜브 카드에만 보입니다)
  final VoidCallback onPlay;

  /// 지금 이 카드에서 미리보기 영상을 틀고 있는지 여부입니다.
  final bool isPreviewPlaying;

  /// 미리보기 영상을 띄울 주소입니다. 없으면 null입니다.
  final String? previewUrl;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isYoutube = item.type == ReferenceType.youtube;

    // 아무것도 얹을 게 없으면 그림만 돌려줍니다.
    if (!isSelectionMode && !isYoutube) {
      return _buildThumbnail(colors, isYoutube);
    }

    // Stack = 위젯을 겹쳐 쌓는 것입니다.
    return Stack(
      children: <Widget>[
        // ── 이 그림이 Stack의 크기를 정합니다 ──
        // Positioned.fill로 감싸면 안 됩니다. 그러면 크기를 정해주는 자식이
        // 하나도 없게 되어, 높이가 정해지지 않은 메이슨리 격자 안에서
        // "높이를 알 수 없다"는 오류가 납니다.
        // 아래 겹치는 것들만 Positioned.fill로 이 그림 크기에 맞춥니다.
        _buildThumbnail(colors, isYoutube),

        // 미리보기 영상은 썸네일을 덮습니다. 재생 버튼은 그 위에 그대로 남습니다.
        if (isPreviewPlaying && previewUrl != null)
          Positioned.fill(child: _buildPreviewPlayer(previewUrl!)),

        // 재생 버튼은 고르기 모드가 아닐 때만 보입니다.
        // 여러 장 고르는 중에 영상이 재생되기 시작하면 곤란합니다.
        if (isYoutube && !isSelectionMode) _buildPlayButton(),

        if (isSelectionMode)
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              // 밝은 사진 위에 흰 체크박스가 놓이면 안 보입니다.
              // 반투명 바탕을 깔아 어떤 그림 위에서도 보이게 합니다.
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              child: Checkbox(
                value: isSelected,

                // 체크박스를 눌렀을 때도 카드를 눌렀을 때와 똑같이 동작합니다.
                // 값 자체는 안 쓰지만 Checkbox가 넘겨주기 때문에 받아만 둡니다.
                onChanged: (bool? _) => onSelectToggle(),
              ),
            ),
          ),
      ],
    );
  }

  /// 눌러서 크게 보는 재생 버튼입니다.
  ///
  /// ── 미리보기 중에는 작아져서 구석으로 갑니다 ──
  /// 평소에는 "이건 영상이다"를 알리는 표시라 가운데 크게 있는 편이 좋습니다.
  /// 그런데 미리보기가 도는 동안에도 가운데 그대로 있으면 **영상 한가운데를
  /// 가려서** 정작 보려던 것을 못 보게 됩니다.
  ///
  /// 그렇다고 아예 숨기면 크게 보러 가는 길이 사라집니다. 그래서 작게 줄여
  /// 오른쪽 아래로 옮깁니다. 왼쪽 위는 체크박스 자리라 비워둡니다.
  Widget _buildPlayButton() {
    // 미리보기 중에는 작게, 평소에는 크게.
    final double iconSize = isPreviewPlaying ? 28 : 48;

    final Widget button = Material(
      // 투명한 Material 위에 InkWell을 두면 누를 때 물결이 나옵니다.
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPlay,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            Icons.play_circle_fill,
            size: iconSize,
            // 썸네일이 밝든 어둡든 보이도록 흰색에 그림자를 줍니다.
            color: Colors.white.withValues(alpha: 0.92),
            shadows: const <Shadow>[
              Shadow(color: Colors.black54, blurRadius: 10),
            ],
          ),
        ),
      ),
    );

    if (isPreviewPlaying) {
      return Positioned(right: 2, bottom: 2, child: button);
    }

    return Positioned.fill(child: Center(child: button));
  }

  /// 호버했을 때 썸네일 위에 겹치는 미리보기 영상입니다.
  ///
  /// ── IgnorePointer로 감싼 이유 ──
  /// 웹뷰는 그 위의 마우스 클릭을 자기가 가져갑니다. 그대로 두면 미리보기가
  /// 도는 동안 **카드를 눌러도 편집 화면이 안 열립니다.** 사용자 입장에서는
  /// 카드가 갑자기 먹통이 되는 셈입니다.
  ///
  /// IgnorePointer는 "이 안은 클릭 대상으로 치지 말라"는 뜻입니다. 덕분에
  /// 미리보기는 움직이는 썸네일처럼만 동작하고, 카드의 클릭·재생 버튼·길게 누르기는
  /// 평소와 똑같이 동작합니다. 마우스가 올라왔는지 살피는 일은 이 바깥의
  /// MouseRegion이 하므로 영향을 받지 않습니다.
  Widget _buildPreviewPlayer(String url) {
    // 웹뷰 부품이 준비되지 않은 환경(리눅스, 테스트 등)에서는 아무것도 안 얹습니다.
    // 확인 없이 만들면 목록 전체가 빨간 오류 화면이 됩니다.
    // 재생 화면(youtube_player_screen.dart)에서와 같은 이유입니다.
    if (InAppWebViewPlatform.instance == null) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: InAppWebView(
        // 카드마다 주소가 다르므로 key를 붙여, 다른 영상으로 바뀌었을 때
        // Flutter가 웹뷰를 새로 만들게 합니다.
        key: ValueKey<String>(url),
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          // 소리 없는 자동재생이라 사용자가 누르지 않아도 시작되어야 합니다.
          mediaPlaybackRequiresUserGesture: false,
          javaScriptEnabled: true,
          allowsInlineMediaPlayback: true,

          // 미리보기는 스크롤할 것이 없습니다. 꺼두면 목록을 스크롤할 때
          // 웹뷰가 대신 스크롤을 먹는 일이 없습니다.
          disableVerticalScroll: true,
          disableHorizontalScroll: true,
        ),
      ),
    );
  }

  /// 카드의 그림만 만듭니다.
  ///
  /// 유튜브도 이미지와 같은 길을 지납니다. 썸네일을 **내려받아 파일로 저장해두기**
  /// 때문입니다. 그래서 인터넷이 끊겨도 목록은 그대로 보입니다.
  ///
  /// ── 이미지와 유튜브의 비율이 다릅니다 ──
  /// 이미지는 **원본 비율 그대로** 둡니다. 레퍼런스를 모으는 앱에서 사진을
  /// 네모로 잘라버리면 구도가 사라집니다. 그래서 세로 사진은 길쭉하게,
  /// 가로 사진은 납작하게 그대로 보입니다. (기존 웹앱도 이렇게 했습니다)
  ///
  /// 유튜브는 어차피 전부 16:9라서 그 비율로 고정합니다. 고정해두면
  /// 썸네일이 아직 안 왔을 때도 카드 크기가 안 흔들립니다.
  Widget _buildThumbnail(ColorScheme colors, bool isYoutube) {
    // 경로를 아직 못 구했거나 파일 이름이 없으면 자리표시자를 보여줍니다.
    // 유튜브인데 썸네일을 못 받아온 경우도 여기로 옵니다.
    if (imagePath == null) {
      return AspectRatio(
        aspectRatio: isYoutube ? 16 / 9 : 4 / 3,
        child: _buildPlaceholder(
          colors,
          isYoutube ? Icons.smart_display_outlined : Icons.image_outlined,
        ),
      );
    }

    final Widget image = Image.file(
      File(imagePath!),

      // 카드 너비를 꽉 채우고 높이는 그림이 정합니다.
      width: double.infinity,
      fit: isYoutube ? BoxFit.cover : BoxFit.fitWidth,

      // ── 아직 안 읽힌 그림에 자리를 잡아주는 이유 ──
      // 그림은 파일을 읽어야 크기를 알 수 있습니다. 읽기 전에는 **높이가 0**이라
      // 카드가 납작하게 찌부러지고, 그 위에 얹은 체크박스와 재생 버튼이
      // 카드 밖으로 밀려나 **눌리지 않게 됩니다.** (테스트로 잡은 실제 문제입니다)
      //
      // 그래서 읽히기 전까지는 4:3 자리를 잡아두고, 다 읽히면 원본 비율로 바뀝니다.
      frameBuilder:
          (
            BuildContext context,
            Widget child,
            int? frame,
            bool wasSynchronouslyLoaded,
          ) {
            // 이미 준비됐으면 그림을 그대로 보여줍니다.
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }

            return AspectRatio(
              aspectRatio: isYoutube ? 16 / 9 : 4 / 3,
              child: _buildPlaceholder(colors, Icons.image_outlined),
            );
          },

      // 파일이 지워졌거나 깨졌을 때 앱이 죽지 않도록 대비합니다.
      // 이게 없으면 파일 하나가 잘못돼도 목록 전체가 빨간 오류 화면이 됩니다.
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        return AspectRatio(
          aspectRatio: isYoutube ? 16 / 9 : 4 / 3,
          child: _buildPlaceholder(colors, Icons.broken_image_outlined),
        );
      },
    );

    if (isYoutube) {
      return AspectRatio(aspectRatio: 16 / 9, child: image);
    }

    return image;
  }

  /// 그림을 못 보여줄 때 대신 띄우는 회색 상자입니다.
  Widget _buildPlaceholder(ColorScheme colors, IconData icon) {
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(icon, size: 40, color: colors.onSurfaceVariant),
      ),
    );
  }
}
