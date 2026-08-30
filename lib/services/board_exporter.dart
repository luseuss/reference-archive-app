// 무드보드에 놓인 카드 전체를 사진(PNG) 한 장으로 떠내는 기능입니다.
//
// ── 왜 필요한가 ──
// 팀에 공유하려면 지금 화면에 보이는 부분이 아니라 **판에 놓인 카드
// 전체**가 한 장에 들어가야 합니다(CLAUDE.md 4단계 7번). 그런데 화면에는
// 지금 보이는 부분만 그려져 있어서, 화면을 그대로 찍으면 잘려나갑니다.
//
// 그래서 화면 밖(사용자 눈에 안 보이는 아주 먼 곳)에 카드 전체를 다시
// 한 번 늘어놓고, 그것을 통째로 사진으로 떠냅니다. Flutter의
// RepaintBoundary가 "이 안에 그려진 것을 통째로 이미지로 달라"는 기능을
// 이미 갖고 있어서, 그 위에 카드들을 얹기만 하면 됩니다.
//
// ── 이 파일은 화면(위젯)을 직접 만들어야 해서 순수 함수가 아닙니다 ──
// board_layout.dart 같은 계산 파일과 달리, 실제로 Flutter가 그림을
// 그려봐야 하는 일이라 화면 없이 테스트할 수 없습니다. 그래서 이 기능은
// 앱을 켜서 눈으로 확인합니다(update.md 참고).

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/board.dart';
import '../models/reference_item.dart';
import '../theme/app_palette.dart';
import '../utils/board_card_actions.dart' show BoardResizeCorner;
import '../widgets/board_card_view.dart';

/// 사진으로 찍을 때 화면 배율입니다.
///
/// 2배로 찍으면 고해상도 화면(레티나 등)에서 봐도 흐리지 않습니다.
/// 기존 웹앱도 내보내기에서 배율을 키워 찍었습니다.
const double boardExportPixelRatio = 2;

/// 판에 놓인 카드 전체를 PNG 사진 한 장으로 떠서 바이트로 돌려줍니다.
///
/// 카드가 하나도 없으면 null을 돌려줍니다.
///
/// [context]는 화면 밖에 잠깐 끼워 넣을 자리(Overlay)를 찾는 데만 씁니다.
/// 실제로 사용자 눈에는 아무것도 보이지 않습니다 — 화면에서 아주 멀리
/// 떨어진 곳에 그렸다가, 다 찍으면 바로 치웁니다.
Future<Uint8List?> exportBoardImage({
  required BuildContext context,
  required List<BoardCard> cards,
  required Map<String, ReferenceItem> itemsById,
  required Map<String, String?> imagePaths,
}) async {
  if (cards.isEmpty) {
    return null;
  }

  // ── 1. 사진 파일들을 미리 읽어둡니다 ──
  // 안 그러면 아직 안 읽힌 사진이 하얗게 빈 채로 찍힙니다.
  for (final BoardCard card in cards) {
    final String? path = imagePaths[card.referenceId];
    if (path != null) {
      await precacheImage(FileImage(File(path)), context);
    }
  }

  if (!context.mounted) {
    return null;
  }

  // ── 2. 카드마다 실제로 그려질 높이를 미리 구합니다 ──
  // 사용자가 크기를 조절한 카드는 card.height에 정확한 값이 있습니다.
  // 아직 조절 안 한 카드는 그림의 원본 비율대로 높이가 정해지므로, 사진
  // 파일을 직접 읽어서 가로세로 비율을 구합니다. (board_layout.dart의
  // boardCardHeight와 같은 규칙이지만, 화면에 그려보지 않고도 미리 알아야
  // 해서 여기서는 파일을 직접 읽습니다)
  final Map<String, double> heights = <String, double>{};
  for (final BoardCard card in cards) {
    final double? explicit = card.height;
    if (explicit != null) {
      heights[card.id] = explicit;
      continue;
    }

    final String? path = imagePaths[card.referenceId];
    final Size? naturalSize = path == null ? null : await _decodeImageSize(path);

    heights[card.id] = naturalSize == null
        ? card.width * 3 / 4 // 사진이 없으면 자리표시자와 같은 4:3 비율
        : card.width * naturalSize.height / naturalSize.width;
  }

  if (!context.mounted) {
    return null;
  }

  // ── 3. 카드 전체가 차지하는 범위를 구합니다 ──
  Rect bounds = Rect.fromLTWH(
    cards.first.x,
    cards.first.y,
    cards.first.width,
    heights[cards.first.id]!,
  );
  for (final BoardCard card in cards.skip(1)) {
    bounds = bounds.expandToInclude(
      Rect.fromLTWH(card.x, card.y, card.width, heights[card.id]!),
    );
  }

  // ── 4. 화면 밖에 카드를 전부 늘어놓고 찍습니다 ──
  final GlobalKey boundaryKey = GlobalKey();
  final AppPalette palette = AppPalette.of(context);
  final OverlayState overlay = Overlay.of(context, rootOverlay: true);

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext context) {
      return Positioned(
        // 화면에서 아주 멀리 떨어진 곳에 그립니다. 사용자 눈에는 안
        // 보이지만 Flutter는 여전히 이 위젯을 그리고(그래야 사진을 뜰 수
        // 있습니다), 실수로라도 클릭이 닿지 않도록 IgnorePointer로
        // 감쌉니다.
        left: -bounds.width - 100000,
        top: -bounds.height - 100000,
        child: IgnorePointer(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: bounds.width,
              height: bounds.height,
              child: ColoredBox(
                color: palette.background,
                child: Stack(
                  children: <Widget>[
                    for (final BoardCard card in cards)
                      _buildExportCard(card, bounds, heights, itemsById, imagePaths),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);

  try {
    // 다 그려질 때까지 두 번 기다립니다. 한 번은 위젯이 자리 잡는
    // 차례이고, 한 번은 (미리 읽어둔) 사진이 실제로 그려지는 차례입니다.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

    final RenderRepaintBoundary boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

    final ui.Image image = await boundary.toImage(
      pixelRatio: boardExportPixelRatio,
    );
    try {
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    // 찍었든 실패했든, 화면 밖에 끼워둔 것은 반드시 치웁니다.
    entry.remove();
  }
}

/// 카드 한 장을 화면 밖 상자 안의 제자리에 놓습니다.
///
/// 실제 화면과 같은 `BoardCardView`를 그대로 재사용합니다. 마우스를
/// 올린 상태가 아니라서(=isActive, isSelected 둘 다 거짓) 제목 띠·손잡이·
/// 내리기 버튼 없이 **그림만** 나옵니다 — 사진첩처럼 깔끔한 모습이 되도록
/// 일부러 고른 방식입니다. 눌러도 아무 일이 안 일어나게 콜백은 전부
/// 빈 함수로 둡니다(어차피 화면 밖이라 손이 안 닿습니다).
Widget _buildExportCard(
  BoardCard card,
  Rect bounds,
  Map<String, double> heights,
  Map<String, ReferenceItem> itemsById,
  Map<String, String?> imagePaths,
) {
  final ReferenceItem? item = itemsById[card.referenceId];

  // 짝이 되는 레퍼런스를 못 찾으면 화면에서와 마찬가지로 그리지 않습니다.
  if (item == null) {
    return const SizedBox.shrink();
  }

  return Positioned(
    left: card.x - bounds.left,
    top: card.y - bounds.top,
    width: card.width,
    height: heights[card.id],
    child: BoardCardView(
      item: item,
      imagePath: imagePaths[card.referenceId],
      onRemove: () {},
      onMeasured: (Size size) {},
      onResizeStart: (Size currentSize, BoardResizeCorner corner) {},
      onResizeUpdate: (Offset delta) {},
      onResizeEnd: () {},
    ),
  );
}

/// 사진 파일의 원본 가로·세로 픽셀 크기를 읽어옵니다. 못 읽으면 null입니다.
Future<Size?> _decodeImageSize(String path) async {
  try {
    final Uint8List bytes = await File(path).readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final Size size = Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
    frame.image.dispose();
    codec.dispose();
    return size;
  } catch (_) {
    // 파일이 깨졌거나 사진이 아니면 null을 돌려줍니다. 부르는 쪽이
    // 4:3 자리표시자 비율로 대신합니다.
    return null;
  }
}
