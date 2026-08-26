// 유튜브 재생기 페이지를 내 컴퓨터 안에서만 잠깐 띄워주는 아주 작은 서버입니다.
//
// ── 왜 이런 게 필요한가 (유튜브 오류 153) ──
// 유튜브 재생기(embed)는 **"어느 페이지에 끼워져 있는지"** 를 확인합니다.
// 그 정보가 없으면 이렇게 거부합니다.
//
//   오류 153 — 플레이어 구성 오류
//
// 처음에는 embed 주소를 웹뷰에 그대로 열었습니다. 그러면 페이지가 어디에도
// 속해 있지 않아서 거부당합니다.
//
// 두 번째로는 iframe이 든 HTML을 만들어 띄우면서 "이 페이지는 youtube.com에
// 있는 것으로 쳐달라"(baseUrl)고 알려봤습니다. **Windows에서는 이게 무시됩니다.**
// 플러그인 소스를 직접 확인한 결과, Windows 구현은 HTML만 받고 baseUrl은
// 아예 읽지 않습니다. (flutter_inappwebview_windows의 `loadData`)
//
// 그래서 **진짜 주소를 가진 페이지**를 만들기로 했습니다. 내 컴퓨터 안에만
// 열리는 작은 서버를 잠깐 띄우고, 웹뷰가 그 주소를 엽니다. 그러면 브라우저에서
// 웹사이트를 보는 것과 똑같은 상태가 되어 재생기가 정상 동작합니다.
//
// 기존 웹앱이 아무 문제 없던 이유도 같습니다. 거기는 애초에 진짜 웹페이지였습니다.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 재생기 페이지 하나를 내 컴퓨터 안에서만 띄워주는 임시 서버입니다.
///
/// 영상을 볼 때 켜고, 재생 화면을 닫을 때 끕니다. 계속 켜두지 않습니다.
class LocalPlayerServer {
  /// 지금 돌고 있는 서버입니다. 꺼져 있으면 null입니다.
  HttpServer? _server;

  /// 서버가 돌려줄 HTML입니다.
  String _html = '';

  /// 서버를 켜고, 웹뷰가 열어야 할 주소를 돌려줍니다.
  ///
  /// 켜지 못하면 null을 돌려줍니다. 그때는 부르는 쪽이
  /// "브라우저에서 열기"로 안내해야 합니다.
  Future<String?> start(String html) async {
    // 이전에 켜둔 것이 있으면 먼저 끕니다. 같은 화면에서 영상을 바꿔 틀 때
    // 서버가 쌓이면 안 됩니다.
    await stop();

    _html = html;

    try {
      // ── 두 가지를 일부러 이렇게 정했습니다 ──
      //
      // loopbackIPv4 = **내 컴퓨터 안에서만** 접속할 수 있는 주소입니다.
      //   같은 와이파이에 있는 다른 사람은 접근할 수 없습니다.
      //   여기에 그냥 열어두면 남이 들여다볼 수 있게 되므로 반드시 이래야 합니다.
      //
      // 포트 0 = **비어 있는 번호를 운영체제가 알아서 골라줍니다.**
      //   8080처럼 고정해두면 다른 프로그램이 이미 쓰고 있을 때 실패합니다.
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    } catch (error) {
      debugPrint('[재생기] 임시 서버를 켜지 못했습니다: $error');
      return null;
    }

    // 어떤 주소로 물어보든 재생기 페이지 하나만 돌려줍니다.
    // 파일을 여러 개 다룰 일이 없어서 경로를 따지지 않습니다.
    _server!.listen(
      (HttpRequest request) async {
        try {
          request.response.headers.contentType = ContentType.html;
          request.response.write(_html);
          await request.response.close();
        } catch (error) {
          debugPrint('[재생기] 페이지를 돌려주지 못했습니다: $error');
        }
      },
      onError: (Object error) {
        debugPrint('[재생기] 서버 오류: $error');
      },
    );

    final String url = 'http://127.0.0.1:${_server!.port}/';
    debugPrint('[재생기] 임시 서버 켜짐: $url');
    return url;
  }

  /// 서버를 끕니다. 이미 꺼져 있으면 아무 일도 하지 않습니다.
  ///
  /// 재생 화면을 닫을 때 반드시 불러야 합니다.
  /// 안 끄면 영상을 볼 때마다 서버가 하나씩 쌓입니다.
  Future<void> stop() async {
    final HttpServer? running = _server;
    if (running == null) {
      return;
    }

    _server = null;

    try {
      // force: true = 아직 처리 중인 요청이 있어도 바로 끕니다.
      // 화면을 닫는 중이라 기다릴 이유가 없습니다.
      await running.close(force: true);
    } catch (error) {
      debugPrint('[재생기] 임시 서버를 끄는 중 오류: $error');
    }
  }
}
