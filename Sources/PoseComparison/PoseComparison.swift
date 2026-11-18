import AppKit
import AVFoundation
import CoreImage
import Vision
import WebKit

final class ComparisonController: NSViewController, AVCaptureVideoDataOutputSampleBufferDelegate, WKScriptMessageHandler {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "comparison.camera")
    private let context = CIContext()
    private var captureRequested = false
    private var web: WKWebView!
    override func loadView() {
        let controller = WKUserContentController()
        controller.add(self, name: "comparison")
        let config = WKWebViewConfiguration()
        config.userContentController = controller
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: 1100, height: 760), configuration: config)
        view = web
        guard let html = Bundle.main.resourceURL?.appendingPathComponent("comparison/index.html") else { return }
        web.loadFileURL(html, allowingReadAccessTo: html.deletingLastPathComponent())
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else { self.showError("Camera access denied. Enable it in System Settings."); return }
            self.queue.async { self.startCamera() }
        }
    }
    private func startCamera() {
        guard let camera = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else { showError("Camera unavailable."); return }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { showError("Cannot start camera output."); return }
        session.addOutput(output)
        session.startRunning()
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.body as? String == "capture" else { return }
        queue.async {
            guard self.session.isRunning else { self.showError("Camera is not running."); return }
            self.captureRequested = true
        }
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard captureRequested else { return }
        captureRequested = false
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { showError("Camera returned no image."); return }
        do {
            let request = VNDetectHumanBodyPoseRequest()
            try VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up, options: [:]).perform([request])
            let points = try request.results?.first?.recognizedPoints(.all) ?? [:]
            var vision: [String: [String: Double]] = [:]
            for (name, joint) in [("leftShoulder", VNHumanBodyPoseObservation.JointName.leftShoulder), ("rightShoulder", .rightShoulder)] {
                if let point = points[joint], point.confidence > 0 {
                    vision[name] = ["x": Double(point.location.x), "y": Double(1 - point.location.y), "confidence": Double(point.confidence)]
                }
            }
            let image = CIImage(cvPixelBuffer: buffer)
            guard let data = context.jpegRepresentation(of: image, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [:]) else { showError("Could not prepare camera frame."); return }
            let payload: [String: Any] = ["image": data.base64EncodedString(), "vision": vision]
            let json = try JSONSerialization.data(withJSONObject: payload)
            guard let text = String(data: json, encoding: .utf8) else { showError("Could not prepare comparison."); return }
            DispatchQueue.main.async { self.web.evaluateJavaScript("window.compareFrame(\(text))") { _, error in if let error { self.showError(error.localizedDescription) } } }
        } catch { showError("Vision failed: \(error.localizedDescription)") }
    }
    private func showError(_ message: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: [message]), let json = String(data: data, encoding: .utf8) else { return }
        DispatchQueue.main.async { self.web?.evaluateJavaScript("window.comparisonError(\(json)[0])", completionHandler: nil) }
    }
}
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 800), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Shoulder Comparison"
        window.contentViewController = ComparisonController()
        window.setContentSize(NSSize(width: 1100, height: 760))
        window.minSize = NSSize(width: 640, height: 480)
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
