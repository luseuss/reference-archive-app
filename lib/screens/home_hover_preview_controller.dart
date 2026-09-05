// 목록 화면에서 유튜브 카드에 마우스를 올리면 미리보기를 켜주는 곳입니다.
//
// ── 왜 home_screen.dart에서 뺐나 ──
// home_selection_controller.dart를 뺀 것과 같은 이유입니다(CLAUDE.md
// "밀린 정리거리" 참고). "지금 무엇을 미리 보여주는 중인지" 상태와
// 그 상태를 다루는 동작(켜기·끄기·기다리기)이 함께 다녀야 해서 작은
// 클래스로 옮겼습니다.
//
// ── ChangeNotifier가 무엇인가 ──
// home_selection_controller.dart와 같은 방식입니다. 미리보기가 켜지거나
// 꺼지면 notifyListeners()가 불리고, 화면이 저절로 다시 그려집니다.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/reference_item.dart';
import '../services/local_player_server.dart';
import '../services/youtube_url.dart';

/// 마우스를 올린 뒤 미리보기를 시작하기까지 기다리는 시간입니다.
///
/// 짧으면 목록을 훑을 때 지나가는 영상이 줄줄이 켜지고, 길면 "왜 안 나오지?"
/// 하게 됩니다. 처음엔 0.4초로 뒀는데 써보니 답답해서 0.2초로 줄였습니다.
/// 너무 부산스럽거나 굼뜨면 이 값을 고치세요.
const Duration hoverPreviewDelay = Duration(milliseconds: 200);

/// 이 기기에서 호버 미리보기를 쓸 수 있는지 여부입니다.
///
/// 폰·태블릿에는 마우스가 없어서 "올려두기"라는 동작 자체가 없습니다.
/// 억지로 흉내내지 않고 데스크톱에서만 켭니다. (CLAUDE.md 플랫폼 차이표)
bool get supportsHoverPreview {
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

/// 유튜브 카드 호버 미리보기의 상태와 동작을 담습니다.
class HomeHoverPreviewController extends ChangeNotifier {
  /// 미리보기 페이지를 띄워주는 임시 서버입니다.
  ///
  /// 재생 화면이 쓰는 것과 같은 도구입니다. 유튜브 재생기는 진짜 주소를 가진
  /// 페이지 안에 있어야 하기 때문입니다. (local_player_server.dart 참고)
  final LocalPlayerServer _server = LocalPlayerServer();

  /// 마우스를 올린 뒤 미리보기를 시작하기까지 기다리는 타이머입니다.
  Timer? _hoverTimer;

  /// 미리보기를 시작하려고 마음먹은 카드의 id입니다.
  ///
  /// ── 왜 따로 기억하나 ──
  /// 미리보기를 켜려면 임시 서버를 띄워야 하고, 그동안 사용자는 이미 마우스를
  /// 다른 데로 옮겼을 수 있습니다. 그때 그대로 진행하면 **마우스가 없는 카드에서
  /// 영상이 재생됩니다.** 서버가 준비된 뒤 이 값을 다시 확인해서 막습니다.
  String? _pendingPreviewId;

  /// 이 컨트롤러가 이미 dispose됐는지 여부입니다.
  ///
  /// StatefulWidget의 `mounted`와 같은 역할입니다. 서버를 켜는 사이에
  /// 화면이 닫혔으면 notifyListeners()를 부르면 안 되므로 여기서 막습니다.
  bool _disposed = false;

  /// 지금 미리보기 영상을 틀고 있는 카드의 id입니다. 없으면 null입니다.
  ///
  /// **한 번에 하나만 틀 수 있게** 이렇게 하나만 기억합니다.
  /// 카드마다 웹뷰를 두면 목록에 영상이 서른 개일 때 감당이 안 됩니다.
  /// 마우스는 한 곳에만 있으므로 이걸로 충분합니다.
  String? get previewingItemId => _previewingItemId;
  String? _previewingItemId;

  /// 미리보기 영상을 띄울 주소입니다.
  String? get previewUrl => _previewUrl;
  String? _previewUrl;

  /// 마우스가 카드에 올라오거나 벗어났을 때 실행됩니다.
  ///
  /// ── 왜 바로 틀지 않고 기다리나 ──
  /// 목록을 훑을 때 마우스는 카드 여러 장을 스쳐 지나갑니다. 올라오자마자 틀면
  /// 지나가는 길에 있던 영상이 줄줄이 켜졌다 꺼지면서 화면이 정신없어지고,
  /// 볼 생각도 없던 영상을 계속 받아오게 됩니다.
  ///
  /// 그래서 잠깐 머물렀을 때만 켭니다. "보려고 멈춘 것"과 "지나가는 것"의 차이입니다.
  ///
  /// [isSelecting]이 true면(여러 장 고르는 중) 틀지 않습니다. 여러 장 고르는 데
  /// 집중하는 상황이고, 지나갈 때마다 영상이 켜지면 방해만 됩니다.
  void onCardHoverChanged(
    ReferenceItem item,
    bool isHovering, {
    required bool isSelecting,
  }) {
    // 지나가던 타이머는 언제나 취소합니다.
    _hoverTimer?.cancel();

    if (!isHovering) {
      _pendingPreviewId = null;

      // 다른 카드에서 이미 틀고 있는 중이라면 건드리지 않습니다.
      // 카드 A를 벗어나는 알림이 카드 B에 들어온 뒤에 올 수도 있습니다.
      if (_previewingItemId == item.id) {
        stopPreview();
      }
      return;
    }

    if (isSelecting) {
      return;
    }

    _pendingPreviewId = item.id;
    _hoverTimer = Timer(hoverPreviewDelay, () => _startPreview(item));
  }

  /// 카드 위에서 미리보기 영상을 켭니다.
  Future<void> _startPreview(ReferenceItem item) async {
    final String? videoId = item.youtubeVideoId;
    if (videoId == null) {
      return;
    }

    // 소리는 끕니다. 목록을 훑을 때마다 소리가 나면 쓸 수 없는 기능이 됩니다.
    final String? url = await _server.start(
      youtubePlayerHtml(videoId, muted: true),
    );

    if (_disposed || url == null) {
      return;
    }

    // 서버를 켜는 사이에 마우스가 다른 데로 갔으면 그만둡니다.
    // 이걸 안 보면 마우스가 없는 카드에서 영상이 재생됩니다.
    if (_pendingPreviewId != item.id) {
      await _server.stop();
      return;
    }

    _previewingItemId = item.id;
    _previewUrl = url;
    notifyListeners();
  }

  /// 미리보기 영상을 끕니다.
  ///
  /// 기다리고 있던 타이머도 함께 취소합니다 — 이 함수를 부르는 곳들
  /// (고르기 모드 진입, 유튜브 재생 화면 열기 등)은 전부 "미리보기와
  /// 관련된 모든 것을 멈춰라"는 뜻으로 부르기 때문입니다.
  void stopPreview() {
    _hoverTimer?.cancel();
    _pendingPreviewId = null;

    if (_previewingItemId == null) {
      return;
    }

    _previewingItemId = null;
    _previewUrl = null;
    notifyListeners();

    // 서버는 끄는 데 시간이 걸리므로 기다리지 않습니다.
    // 화면은 이미 미리보기를 치웠고, 서버는 뒤에서 정리되면 됩니다.
    _server.stop();
  }

  /// 화면이 사라질 때 만들어둔 것들을 정리합니다.
  ///
  /// 타이머를 안 끄면 화면을 닫은 뒤에 타이머가 깨어나서
  /// 이미 없어진 컨트롤러를 고치려다 오류를 냅니다.
  @override
  void dispose() {
    _disposed = true;
    _hoverTimer?.cancel();
    _server.stop();
    super.dispose();
  }
}
