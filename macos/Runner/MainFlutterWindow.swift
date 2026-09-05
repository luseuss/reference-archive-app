import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // 팝업으로 뜨는 두 번째 창에도 이 창과 똑같이 플러그인이 등록되게
    // 합니다. 안 하면 팝업 창에서는 무드보드가 아예 안 열립니다.
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
    }

    super.awakeFromNib()
  }
}
