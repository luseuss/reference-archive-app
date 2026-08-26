// 앱 창에 "끌어다 놓은 것" 하나를 읽어서 이미지 데이터로 만들어주는 파일입니다.
//
// ── 왜 화면에서 떼어냈나 ──
// 원래 이 내용은 home_screen.dart 안에 있었습니다. 그런데 브라우저마다,
// 사이트마다 넘겨주는 것이 달라서 예외 처리가 계속 늘어났고, 화면 파일이
// 1000줄 가까이 되어 "목록 화면 코드"를 찾기가 어려워졌습니다.
//
// 여기 있는 내용은 화면과 아무 상관이 없습니다. "떨어진 것을 읽는 일"만 합니다.
// 그래서 따로 떼어냈습니다. 앞으로 **특정 사이트에서 끌어다 놓기가 안 될 때는
// 이 파일만 보면 됩니다.**
//
// 실제로 인터넷에서 내려받는 일은 여기서 하지 않고 image_source.dart에 맡깁니다.
// 이 파일은 "무엇이 왔는지 가려내는" 것까지만 합니다.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_native_extensions/raw_clipboard.dart' as raw;

import 'image_source.dart';

/// 끌어다 놓기로 받을 수 있는 이미지 형식들입니다.
///
/// 여기 없는 형식은 창에 놓아도 아예 들어오지 않습니다.
/// 브라우저가 이미지를 건네줄 때 쓰는 흔한 형식들을 담았습니다.
const List<FileFormat> droppableImageFormats = <FileFormat>[
  Formats.png,
  Formats.jpeg,
  Formats.gif,
  Formats.webp,
  Formats.bmp,
  Formats.tiff,
];

/// 창이 "받을 수 있다"고 알릴 형식 전부입니다.
///
/// 이미지 형식에 주소(uri)와 파일 경로(fileUri)를 더한 것입니다.
/// 여기 없는 형식은 커서에 금지 표시가 뜨고 아예 놓을 수 없습니다.
const List<DataFormat<Object>> dropRegionFormats = <DataFormat<Object>>[
  ...droppableImageFormats,
  Formats.uri,
  Formats.fileUri,
];

/// 끌어다 놓은 항목 하나를 읽어 이미지 데이터로 만들어주는 도구입니다.
class DroppedItemReader {
  DroppedItemReader(this.imageSource);

  /// 주소에서 이미지를 내려받는 도구입니다.
  ///
  /// 끌어다 놓은 것이 이미지가 아니라 **주소**인 경우가 가장 흔해서,
  /// 이 도구 없이는 대부분의 브라우저 드래그를 처리할 수 없습니다.
  final ImageSource imageSource;

  /// 떨어진 항목 하나를 읽어 이미지 데이터로 만듭니다.
  ///
  /// ── 브라우저에서 끌면 무엇이 오는가 ──
  /// 상황마다 다릅니다. 이미지 데이터가 그대로 오기도 하고, 주소만 오기도 합니다.
  /// 그래서 **줄 수 있는 형식을 물어보고** 처리 방법을 정합니다.
  ///
  ///   1. 이미지 형식(PNG/JPEG/...)을 줄 수 있으면 → 그대로 받습니다
  ///   2. HTML 조각을 줄 수 있으면 → 그 안의 진짜 이미지 주소를 찾습니다
  ///   3. 주소를 줄 수 있으면 → 내려받습니다
  ///   4. 그래도 없으면 → 사이트가 자기 방식으로 넣어둔 데이터를 뒤집니다
  ///
  /// **이 순서가 중요합니다.** 이유는 각 단계 주석에 적어뒀습니다.
  Future<ImageFetchResult> read(DataReader reader) async {
    // 1) 이미지 데이터를 직접 줄 수 있는지 먼저 봅니다.
    //    이미 갖고 있는 데이터를 쓰는 쪽이 빠르고 실패할 일도 없습니다.
    for (final FileFormat format in droppableImageFormats) {
      if (!reader.canProvide(format)) {
        continue;
      }

      final Uint8List? bytes = await _readFileBytes(reader, format);
      if (bytes != null && bytes.isNotEmpty) {
        return ImageFetchResult.success(bytes);
      }
    }

    // 2) 이미지를 못 주면 HTML 조각을 봅니다.
    //
    //    ── 주소보다 HTML을 먼저 보는 이유 (핀터레스트) ──
    //    이미지가 링크에 감싸여 있으면 브라우저가 주는 주소는 **이미지가 아니라
    //    링크가 가리키는 페이지 주소**입니다. 핀터레스트가 정확히 그렇습니다.
    //    그걸 내려받으면 HTML이 와서 "그림이 아니다"로 실패합니다.
    //
    //    반면 HTML 조각에는 <img src="진짜 이미지 주소">가 들어 있어서
    //    링크에 감싸여 있어도 실제 이미지를 찾을 수 있습니다.
    if (reader.canProvide(Formats.htmlText)) {
      final String? html = await _readValue<String>(reader, Formats.htmlText);

      String? imageUrl = html == null ? null : imageUrlFromHtml(html);

      // 못 찾았으면 글자가 깨져서 온 경우일 수 있습니다.
      // 되돌려서 한 번 더 찾아봅니다. (핀터레스트 피드가 이 경우입니다)
      if (imageUrl == null && html != null) {
        final String? repaired = repairMangledHtml(html);
        if (repaired != null) {
          imageUrl = imageUrlFromHtml(repaired);
        }
      }

      debugPrint('[드롭] HTML에서 찾은 주소: $imageUrl');

      if (imageUrl != null) {
        final ImageFetchResult result = await imageSource.fetchFromUrl(imageUrl);

        // 여기서 실패하면 아래 주소 방식으로 한 번 더 시도해봅니다.
        if (result.isSuccess) {
          return result;
        }
      }
    }

    // 3) 그래도 안 되면 주소를 그대로 받아봅니다.
    //    이미지를 직접 끈 경우(링크에 안 감싸인 경우)에는 이쪽이 맞습니다.
    if (reader.canProvide(Formats.uri)) {
      final NamedUri? named = await _readValue<NamedUri>(reader, Formats.uri);
      final String? url = named?.uri.toString();
      debugPrint('[드롭] 주소: $url');

      if (url != null && looksLikeUrl(url)) {
        return imageSource.fetchFromUrl(url);
      }
    }

    // 4) 표준 형식으로 아무것도 못 얻었으면, 사이트가 자기 방식으로 끼워 넣은
    //    데이터를 뒤져봅니다.
    //
    //    ── 왜 이게 필요한가 (핀터레스트 상세 페이지) ──
    //    핀터레스트 상세 페이지에서 끌면 표준 형식이 하나도 안 옵니다.
    //    HTML도, 주소도, 파일도 없습니다. 대신 자체 형식 안에
    //    이미지 주소를 넣어둡니다.
    //
    //      application/x-pinterest-closeup-image
    //      {"pinId":"...","previewImageUrl":"https://i.pinimg.com/736x/...jpg"}
    //
    //    이름은 사이트마다 다르므로 이름을 찾지 않고 주소처럼 생긴 글자를 찾습니다.
    final String? urlFromCustomData = await _findUrlInCustomData(reader);
    if (urlFromCustomData != null) {
      return imageSource.fetchFromUrl(urlFromCustomData);
    }

    // 여기까지 왔으면 어느 경로로도 못 얻은 것입니다.
    // 새로운 사이트가 안 될 때 원인을 짚을 수 있도록 무엇이 넘어왔는지 남깁니다.
    debugPrint('[드롭] 실패 — 넘어온 형식: ${reader.platformFormats}');

    return const ImageFetchResult.failure('이미지를 찾지 못했습니다. 이미지를 복사해서 붙여넣어 보세요.');
  }

  /// 사이트가 자체 형식으로 끼워 넣은 데이터에서 이미지 주소를 찾습니다.
  ///
  /// 표준 형식으로 아무것도 못 얻었을 때만 부릅니다.
  Future<String?> _findUrlInCustomData(DataReader reader) async {
    final raw.DataReaderItem? item = reader.rawReader;
    if (item == null) {
      return null;
    }

    try {
      final List<String> formats = await item.getAvailableFormats();

      for (final String format in formats) {
        // 그림 자체(비트맵)는 여기서 다루지 않습니다. 아주 크고,
        // 우리가 찾는 건 글자 속 주소입니다.
        if (format.contains('DragImageBits')) {
          continue;
        }

        final (Future<Object?>, raw.ReadProgress) request = item
            .getDataForFormat(format);
        final Object? data = await request.$1;

        String? text;
        if (data is String) {
          text = data;
        } else if (data is List<int> && data.length <= 100000) {
          // 0이 낀 채로 오는 경우가 있어서 그대로 읽으면 안 됩니다.
          // 자세한 이유는 textFromCustomData()의 설명을 보세요.
          text = textFromCustomData(data);
        }

        if (text == null) {
          continue;
        }

        final String? found = findImageUrlInText(text);
        if (found != null) {
          debugPrint('[드롭] 사이트 자체 데이터($format)에서 찾은 주소: $found');
          return found;
        }
      }
    } catch (error) {
      debugPrint('[드롭] 자체 데이터 살펴보기 실패: $error');
    }

    return null;
  }

  /// 값을 읽어 돌려줍니다. 못 읽으면 null입니다.
  ///
  /// getValue()도 결과를 콜백으로 주기 때문에 Completer로 감싸 Future로 바꿉니다.
  /// (getFile과 같은 이유입니다)
  Future<T?> _readValue<T extends Object>(
    DataReader reader,
    ValueFormat<T> format,
  ) {
    final Completer<T?> completer = Completer<T?>();

    reader.getValue<T>(
      format,
      (T? value) {
        if (!completer.isCompleted) {
          completer.complete(value);
        }
      },
      onError: (Object error) {
        debugPrint('떨어진 항목 값 읽기 실패: $error');
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    return completer.future;
  }

  /// 읽기 결과를 기다렸다가 바이트로 돌려줍니다.
  ///
  /// getFile()은 결과를 콜백으로 주기 때문에, await로 기다릴 수 있도록
  /// Completer로 감싸 Future로 바꿉니다.
  Future<Uint8List?> _readFileBytes(DataReader reader, FileFormat format) {
    final Completer<Uint8List?> completer = Completer<Uint8List?>();

    reader.getFile(
      format,
      (DataReaderFile file) async {
        final Uint8List bytes = await file.readAll();
        if (!completer.isCompleted) {
          completer.complete(bytes);
        }
      },
      onError: (Object error) {
        debugPrint('떨어진 항목 읽기 실패: $error');
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    return completer.future;
  }
}
