// 목록에 보이는 레퍼런스 카드 한 장입니다.
//
// 화면(screens/) 파일이 너무 길어지지 않도록 카드 한 장의 생김새는 여기로 뺐습니다.
// 나중에 카드에 즐겨찾기 별표나 태그 표시를 붙일 때도 이 파일만 보면 됩니다.

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/enums.dart';
import '../models/reference_item.dart';
import '../theme/app_palette.dart';
import '../utils/date_format.dart';

/// 레퍼런스 한 건을 보여주는 카드입니다.
class ReferenceCard extends StatelessWidget {
  const ReferenceCard({
    super.key,
    required this.item,
    required this.imagePath,
    required this.onDelete,
    required this.onTap,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onSelectToggle,
    required this.onPlay,
    this.onHoverChanged,
    this.isPreviewPlaying = false,
    this.previewUrl,
    this.taxonomyNames = const <String, String>{},
  });

  /// 보여줄 레퍼런스
  final ReferenceItem item;

  /// 이미지 파일의 전체 경로입니다.
  ///
  /// 데이터베이스에는 파일 이름만 들어있어서, 화면에 띄우려면 실제 경로가 필요합니다.
  /// 경로를 아직 못 구했으면 null입니다.
  final String? imagePath;

  /// 삭제 버튼을 눌렀을 때 실행할 동작입니다.
  ///
  /// 카드가 직접 지우지 않고 "눌렸다"고 알리기만 합니다.
  /// 실제로 지우는 일은 화면(home_screen.dart)이 합니다.
  /// 카드는 생김새만 책임지게 두는 편이 나중에 고치기 쉽습니다.
  final VoidCallback onDelete;

  /// 카드를 눌렀을 때 실행할 동작입니다. (편집 화면 열기)
  ///
  /// 고르기 모드에서는 이걸 부르지 않고 [onSelectToggle]을 부릅니다.
  final VoidCallback onTap;

  /// 지금 여러 장 고르는 중인지 여부입니다.
  ///
  /// 켜져 있으면 카드에 체크박스가 생기고, 카드를 눌러도 편집 화면이 열리지 않습니다.
  /// 고르려고 누른 것인데 화면이 열려버리면 여러 장 고르기가 아예 불가능합니다.
  final bool isSelectionMode;

  /// 이 카드가 지금 골라져 있는지 여부입니다.
  final bool isSelected;

  /// 이 카드를 고르거나 고르기를 취소할 때 실행할 동작입니다.
  final VoidCallback onSelectToggle;

  /// 재생 버튼을 눌렀을 때 실행할 동작입니다. (유튜브 카드에만 보입니다)
  ///
  /// 카드 본체를 누르면 편집 화면, 재생 버튼을 누르면 재생 화면으로 갈라집니다.
  /// 삭제 버튼이 카드 안에 있으면서 자기 동작을 갖는 것과 같은 방식입니다.
  final VoidCallback onPlay;

  /// 마우스가 이 카드에 올라오거나 벗어났을 때 알려줍니다.
  ///
  /// null이면 호버를 아예 살피지 않습니다. 폰·태블릿에는 마우스가 없어서
  /// 화면 쪽에서 null을 넘깁니다.
  final ValueChanged<bool>? onHoverChanged;

  /// 지금 이 카드에서 미리보기 영상을 틀고 있는지 여부입니다.
  final bool isPreviewPlaying;

  /// 분류 항목 id를 이름으로 바꿔주는 표입니다. (id → 이름)
  ///
  /// 레퍼런스에는 폴더·카테고리·태그가 **id로만** 들어있습니다. 카드가 직접
  /// 데이터베이스를 뒤져 이름을 찾으면, 카드를 그릴 때마다 조회가 일어나
  /// 목록이 버벅입니다. 그래서 화면이 한 번 만들어 넘겨줍니다.
  final Map<String, String> taxonomyNames;

  /// 미리보기 영상을 띄울 주소입니다. 없으면 null입니다.
  ///
  /// 카드가 주소를 직접 만들지 않습니다. 어느 카드에서 틀지 정하는 일은
  /// 화면(home_screen.dart)이 하고, 카드는 받은 것을 보여주기만 합니다.
  final String? previewUrl;

  /// 카드의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    // 마우스를 올렸는지는 카드마다 따로 기억합니다. 화면 전체가 기억하면
    // 카드 하나에 마우스가 스칠 때마다 목록 전체를 다시 그리게 됩니다.
    return _HoverLift(
      onHoverChanged: onHoverChanged,
      builder: (BuildContext context, bool isHovered) {
        return _buildCard(context, isHovered);
      },
    );
  }

  /// 카드 본체를 만듭니다.
  ///
  /// ── Card 위젯을 안 쓰고 직접 그리는 이유 ──
  /// 기존 웹앱의 카드는 **얇은 테두리 + 두 겹 그림자**입니다. Flutter의 Card는
  /// elevation 하나로 그림자를 만들기 때문에 이 모양이 안 나옵니다.
  /// 그래서 Container에 테두리와 그림자를 직접 그립니다.
  Widget _buildCard(BuildContext context, bool isHovered) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppPalette palette = AppPalette.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,

      // 마우스를 올리면 살짝 떠오릅니다. 기존 웹앱의 translateY(-2px)와 같습니다.
      transform: Matrix4.translationValues(0, isHovered ? -2 : 0, 0),

      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(appCornerRadius),

        // 골라둔 카드는 강조색 테두리로 한눈에 구분되게 합니다.
        // 체크박스만으로는 카드가 많을 때 어느 걸 골랐는지 알아보기 어렵습니다.
        border: Border.all(
          color: isSelected ? colors.primary : palette.border,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isHovered ? palette.cardShadowHovered : palette.cardShadow,
      ),

      // 그림이 둥근 모서리 밖으로 삐져나오지 않게 잘라냅니다.
      clipBehavior: Clip.antiAlias,

      // InkWell로 감싸면 누를 수 있게 되고, 누를 때 물결 효과도 함께 나옵니다.
      // 삭제 버튼은 이 안에 있지만 자기 동작이 따로 있어서 카드 열기와 섞이지 않습니다.
      child: InkWell(
        // 고르기 모드에서는 누르는 것이 "고르기"가 됩니다.
        onTap: isSelectionMode ? onSelectToggle : onTap,

        // 길게 누르면 고르기 모드로 들어갑니다.
        // 폰에는 우클릭이 없어서, 길게 누르기가 "여러 개 고르기"의 표준 방법입니다.
        onLongPress: onSelectToggle,

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          // ── 카드 높이는 내용이 정합니다 ──
          // 예전에는 카드 높이를 격자가 정해주고 그림을 Expanded로 늘렸습니다.
          // 지금은 반대입니다. **그림이 원본 비율대로 높이를 정하고**, 카드가
          // 거기에 맞춰집니다. 그래서 세로 사진은 길쭉한 카드가 됩니다.
          mainAxisSize: MainAxisSize.min,

          children: <Widget>[
            _buildThumbnailArea(colors),

            _buildBody(palette),
          ],
        ),
      ),
    );
  }

  /// 카드의 그림 아래쪽, 글자로 된 부분을 통째로 만듭니다.
  ///
  /// 위에서부터 제목 → 폴더 → 카테고리 → 태그 → 메모 → 날짜·삭제 순입니다.
  /// **없는 항목은 아예 자리를 차지하지 않습니다.** 폴더도 태그도 메모도 없는
  /// 레퍼런스가 흔한데, 빈 줄이 남으면 카드마다 높이가 들쭉날쭉해집니다.
  Widget _buildBody(AppPalette palette) {
    return Padding(
      // 기존 웹앱의 `.card-body { padding: 13px 14px 14px; }` 와 같습니다.
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildTitleRow(palette),

          // 폴더는 옅게, 카테고리는 강조색으로 보여줍니다.
          // 기존 웹앱이 그렇게 구분해뒀습니다 — 카테고리가 더 중요한 분류입니다.
          if (_nameOf(item.folderId) != null)
            _bodyGap(
              Text(
                '📁 ${_nameOf(item.folderId)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: palette.textDim,
                ),
              ),
            ),

          if (_nameOf(item.categoryId) != null)
            _bodyGap(
              Text(
                '🏷 ${_nameOf(item.categoryId)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: palette.accent,
                ),
              ),
            ),

          if (_tagNames().isNotEmpty) _bodyGap(_buildTags(palette)),

          if (item.memo != null && item.memo!.trim().isNotEmpty)
            _bodyGap(
              Text(
                item.memo!.trim(),
                // 메모가 길어도 카드가 한없이 길어지지 않게 세 줄로 자릅니다.
                // 전체는 편집 화면에서 봅니다.
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: palette.textDim,
                ),
              ),
            ),

          _buildFoot(palette),
        ],
      ),
    );
  }

  /// 본문 항목 사이의 간격을 붙여줍니다. (웹앱의 `gap: 7px`)
  ///
  /// 항목마다 `SizedBox(height: 7)`를 손으로 넣으면, 항목이 없을 때 빈칸만
  /// 남거나 반대로 붙어버리는 실수를 하게 됩니다. 여기서 한 번에 처리합니다.
  Widget _bodyGap(Widget child) {
    return Padding(padding: const EdgeInsets.only(top: 7), child: child);
  }

  /// 제목 줄입니다. 고정·즐겨찾기 표시가 있으면 앞에 붙습니다.
  Widget _buildTitleRow(AppPalette palette) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 고정·즐겨찾기 표시는 켜져 있을 때만 보입니다.
        if (item.isPinned)
          Padding(
            padding: const EdgeInsets.only(right: 4, top: 2),
            child: Icon(Icons.push_pin, size: 14, color: palette.accent),
          ),
        if (item.isFavorite)
          Padding(
            padding: const EdgeInsets.only(right: 4, top: 2),
            child: Icon(Icons.star, size: 14, color: palette.accent),
          ),
        Expanded(
          child: Text(
            item.title.isEmpty ? '(제목 없음)' : item.title,

            // 제목이 길면 카드를 밀어내지 않고 두 줄까지만 보여줍니다.
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: palette.text,
            ),
          ),
        ),
      ],
    );
  }

  /// 태그들을 작은 알약 모양으로 늘어놓습니다.
  Widget _buildTags(AppPalette palette) {
    // Wrap = 한 줄에 다 못 들어가면 다음 줄로 넘겨주는 배치입니다.
    // Row로 하면 태그가 많을 때 화면 밖으로 넘쳐 오류가 납니다.
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: <Widget>[
        for (final String name in _tagNames())
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: palette.tagBackground,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '#$name',
              style: TextStyle(fontSize: 11, color: palette.textDim),
            ),
          ),
      ],
    );
  }

  /// 카드 맨 아래 줄입니다. 왼쪽에 날짜, 오른쪽에 삭제입니다.
  Widget _buildFoot(AppPalette palette) {
    return Container(
      margin: const EdgeInsets.only(top: 11),
      padding: const EdgeInsets.only(top: 8),

      // 위쪽에 실선 하나로 본문과 나눕니다. (웹앱의 `.card-foot` 테두리)
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            formatCardDate(item.createdAt),
            style: TextStyle(fontSize: 11, color: palette.textDim),
          ),

          // 고르기 모드에서는 낱장 삭제 버튼을 숨깁니다.
          // 여러 장을 고르는 중에 실수로 한 장만 지우면 당황스럽고,
          // 지우는 방법은 아래 작업 막대에 이미 있습니다.
          if (!isSelectionMode)
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  '삭제',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: palette.textDim,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 분류 항목 id를 이름으로 바꿉니다. 없으면 null입니다.
  ///
  /// 레퍼런스에는 id만 들어있어서 그대로 보여줄 수 없습니다.
  /// 이름 목록은 화면에서 만들어 넘겨줍니다.
  String? _nameOf(String? taxonomyItemId) {
    if (taxonomyItemId == null) {
      return null;
    }
    return taxonomyNames[taxonomyItemId];
  }

  /// 이 레퍼런스에 붙은 태그 이름들을 돌려줍니다.
  ///
  /// 이름을 못 찾은 것은 건너뜁니다. 분류를 지운 직후처럼 잠깐 어긋날 수
  /// 있는데, 그때 빈 알약이 뜨는 것보다 안 보이는 편이 낫습니다.
  List<String> _tagNames() {
    final List<String> names = <String>[];

    for (final String tagId in item.tagIds) {
      final String? name = taxonomyNames[tagId];
      if (name != null) {
        names.add(name);
      }
    }

    return names;
  }

  /// 카드의 그림 부분을 만듭니다.
  ///
  /// 상황에 따라 그림 위에 두 가지가 얹힙니다.
  ///   - 유튜브면 재생 버튼 (누르면 편집 화면이 아니라 바로 재생)
  ///   - 고르기 모드면 체크박스
  Widget _buildThumbnailArea(ColorScheme colors) {
    final bool isYoutube = item.type == ReferenceType.youtube;

    // 아무것도 얹을 게 없으면 그림만 돌려줍니다.
    if (!isSelectionMode && !isYoutube) {
      return _buildThumbnail(colors);
    }

    // Stack = 위젯을 겹쳐 쌓는 것입니다.
    return Stack(
      children: <Widget>[
        // ── 이 그림이 Stack의 크기를 정합니다 ──
        // Positioned.fill로 감싸면 안 됩니다. 그러면 크기를 정해주는 자식이
        // 하나도 없게 되어, 높이가 정해지지 않은 메이슨리 격자 안에서
        // "높이를 알 수 없다"는 오류가 납니다.
        // 아래 겹치는 것들만 Positioned.fill로 이 그림 크기에 맞춥니다.
        _buildThumbnail(colors),

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
  Widget _buildThumbnail(ColorScheme colors) {
    final bool isYoutube = item.type == ReferenceType.youtube;

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

/// 마우스를 올렸는지 기억했다가 알려주는 작은 도우미 위젯입니다.
///
/// ── 왜 따로 만들었나 ──
/// 카드는 "마우스를 올리면 살짝 떠오르는" 것 말고는 상태가 없습니다.
/// 그것 하나 때문에 카드 전체를 StatefulWidget으로 바꾸면 코드가 길어집니다.
/// 그래서 **호버를 기억하는 일만 하는** 작은 위젯을 따로 두고,
/// 카드는 지금 올라와 있는지(`isHovered`)만 받아서 그리기만 합니다.
class _HoverLift extends StatefulWidget {
  const _HoverLift({required this.builder, this.onHoverChanged});

  /// 지금 마우스가 올라와 있는지를 받아 화면을 만들어주는 함수입니다.
  final Widget Function(BuildContext context, bool isHovered) builder;

  /// 바깥에도 호버를 알려야 할 때 씁니다. (유튜브 미리보기)
  ///
  /// null이면 알리지 않고, 떠오르는 효과만 냅니다.
  final ValueChanged<bool>? onHoverChanged;

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  /// 지금 마우스가 이 위에 올라와 있는지 여부입니다.
  bool _isHovered = false;

  /// 마우스가 들어오거나 나갔을 때 기억해두고 바깥에도 알립니다.
  void _setHovered(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
    widget.onHoverChanged?.call(isHovered);
  }

  @override
  Widget build(BuildContext context) {
    // MouseRegion = 마우스가 이 영역에 들어오고 나가는 것을 알려주는 위젯입니다.
    // 손가락 터치로는 아무 일도 일어나지 않아서, 폰에서는 저절로 조용합니다.
    return MouseRegion(
      onEnter: (PointerEnterEvent event) => _setHovered(true),
      onExit: (PointerExitEvent event) => _setHovered(false),
      child: widget.builder(context, _isHovered),
    );
  }
}
