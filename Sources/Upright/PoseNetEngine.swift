import AppKit
import CoreImage
import WebKit

// All engine state and WebKit calls are confined to the main thread.
final class PoseNetEngine: NSObject, WKScriptMessageHandler {
    enum State { case loading, ready, unavailable }
    var state: State = .loading
    var onState: ((State) -> Void)?
    var onResult: (([String: Any]) -> Void)?
    private var web: WKWebView!
    private var pendingID: Int?
    private var nextID = 0
    private let context = CIContext()

    func start() {
        let controller = WKUserContentController()
        controller.add(self, name: "pose")
        let config = WKWebViewConfiguration()
        config.userContentController = controller
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("model/index.html"), FileManager.default.fileExists(atPath: url.path) else {
            setState(.unavailable); return
        }
        web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        DispatchQueue.main.asyncAfter(deadline: .now() + 45) { [weak self] in
            guard let self, self.state == .loading else { return }
            self.setState(.unavailable)
        }
    }
    func submit(_ image: CIImage) {
        guard state == .ready, pendingID == nil else { return }
        guard let bytes = context.jpegRepresentation(of: image, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [:]) else { return }
        nextID += 1
        let id = nextID
        pendingID = id
        let encoded = bytes.base64EncodedString()
        web.evaluateJavaScript("window.analyzeFrame('\(encoded)', \(id)); void 0") { [weak self] _, error in
            if error != nil, self?.pendingID == id { self?.pendingID = nil; self?.setState(.unavailable) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self, self.pendingID == id else { return }
            self.pendingID = nil
            self.setState(.unavailable)
        }
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "ready":
            guard state == .loading else { return }
            setState(.ready)
        case "unavailable": setState(.unavailable)
        case "error":
            guard let id = body["id"] as? Int, pendingID == id else { return }
            pendingID = nil; setState(.unavailable)
        case "result":
            guard let id = body["id"] as? Int, pendingID == id, state == .ready else { return }
            pendingID = nil
            onResult?(body["points"] as? [String: Any] ?? [:])
        default: break
        }
    }
    private func setState(_ value: State) { state = value; onState?(value) }
}
