import AppKit
import AVFoundation
import CoreMotion
import Vision

final class Monitor: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var status = "Starting camera…"
    @Published var motionStatus = "AirPods unavailable"
    @Published var detectionStatus = "Waiting for camera frames…"
    let session = AVCaptureSession()
    private let motion = CMHeadphoneMotionManager()
    private let queue = DispatchQueue(label: "upright.camera")
    private let landmarkConfidence: Float = 0.2
    private enum CameraMode: String { case body = "Body landmarks", face = "Face position (limited)" }
    private var baseline: Double?
    private var baselineMode: CameraMode?
    private var latestMode: CameraMode?
    private var latest: Double?
    private var badSince: Date?
    private var reference: CMAttitude?
    private var tilt = 0.0
    private var motionTime = Date.distantPast
    private var lastFrame = Date.distantPast

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { self.configure() } else { DispatchQueue.main.async { self.status = "Camera permission denied" } }
            }
        default: status = "Enable camera access in System Settings"
        }
        guard motion.isDeviceMotionAvailable else { return }
        motion.startDeviceMotionUpdates(to: OperationQueue.main) { [weak self] data, _ in
            guard let self, let data else { return }
            if let ref = self.reference, let current = data.attitude.copy() as? CMAttitude {
                current.multiply(byInverseOf: ref)
                self.tilt = abs(current.pitch)
            }
            self.motionTime = Date()
            self.motionStatus = "AirPods motion connected"
        }
    }
    private func configure() {
        queue.async {
            guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device), self.session.canAddInput(input) else {
                DispatchQueue.main.async { self.status = "Camera unavailable" }; return
            }
            self.session.addInput(input)
            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: self.queue)
            guard self.session.canAddOutput(output) else { DispatchQueue.main.async { self.status = "Camera output unavailable" }; return }
            self.session.addOutput(output)
            self.session.startRunning()
            DispatchQueue.main.async { self.status = "Sit comfortably upright and calibrate" }
        }
    }
    func calibrate() {
        guard let latest else { status = "Waiting for a usable body pose"; return }
        baseline = latest
        baselineMode = latestMode
        reference = motion.deviceMotion?.attitude.copy() as? CMAttitude
        tilt = 0; badSince = nil
        status = "Calibrated"
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard Date().timeIntervalSince(lastFrame) > 0.5, let image = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastFrame = Date()
        let request = VNDetectHumanBodyPoseRequest()
        let faceRequest = VNDetectFaceRectanglesRequest()
        do {
            try VNImageRequestHandler(cvPixelBuffer: image, orientation: .up, options: [:]).perform([request, faceRequest])
            let faceCount = faceRequest.results?.count ?? 0
            let frameSize = "\(CVPixelBufferGetWidth(image))×\(CVPixelBufferGetHeight(image))"
            guard let pose = request.results?.first else {
                if let face = faceRequest.results?.first {
                    let value = Double(face.boundingBox.midY)
                    DispatchQueue.main.async {
                        self.detectionStatus = "Frame \(frameSize) · Face detected · Body pose unavailable; using face position"
                        self.update(value, mode: .face)
                    }
                } else {
                    missing("Frame \(frameSize) · No face or body pose detected")
                }
                return
            }
            let points = try pose.recognizedPoints(.all)
            let required: [(String, VNHumanBodyPoseObservation.JointName)] = [("Nose", .nose), ("Left shoulder", .leftShoulder), ("Right shoulder", .rightShoulder)]
            let detail = "Frame \(frameSize) · Faces: \(faceCount) · " + required.map { name, joint in "\(name): \((points[joint]?.confidence ?? 0) > self.landmarkConfidence ? "detected" : "not detected")" }.joined(separator: " · ")
            DispatchQueue.main.async { self.detectionStatus = detail }
            guard let nose = points[.nose], let left = points[.leftShoulder], let right = points[.rightShoulder], nose.confidence > landmarkConfidence, left.confidence > landmarkConfidence, right.confidence > landmarkConfidence else { missing(detail); return }
            let width = hypot(left.location.x - right.location.x, left.location.y - right.location.y)
            guard width > 0.05 else { missing("Shoulders appear too close together. Move closer to the camera."); return }
            let feature = (nose.location.y - (left.location.y + right.location.y) / 2) / width
            DispatchQueue.main.async { self.update(feature, mode: .body) }
        } catch { missing("Vision error: \(error.localizedDescription)") }
    }
    private func missing(_ detail: String) { DispatchQueue.main.async { self.latest = nil; self.badSince = nil; self.detectionStatus = detail; self.status = "Face and shoulders must be visible" } }
    private func update(_ value: Double, mode: CameraMode) {
        latest = value
        latestMode = mode
        guard let baseline else { status = "Sit comfortably upright and calibrate"; return }
        guard baselineMode == mode else {
            badSince = nil
            status = "Detection method changed — recalibrate"
            return
        }
        let cameraChange = value < baseline - (mode == .face ? 0.06 : 0.12)
        let motionFresh = Date().timeIntervalSince(motionTime) < 3 && reference != nil
        if !motionFresh { motionStatus = "AirPods unavailable or not calibrated" }
        let changed = cameraChange || (motionFresh && tilt > 0.30)
        if changed {
            if badSince == nil { badSince = Date() }
            status = Date().timeIntervalSince(badSince!) > 10 ? "Posture changed — check your position" : "Checking posture…"
        } else { badSince = nil; status = "Posture near baseline" }
    }
}

import SwiftUI
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspect
        view.layer = layer
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {}
}

struct ContentView: View {
    @StateObject private var monitor = Monitor()
    var body: some View {
        VStack(spacing: 16) {
            Text("Upright").font(.largeTitle)
            CameraPreview(session: monitor.session).frame(height: 260)
            Text(monitor.status).font(.headline)
            Text(monitor.detectionStatus).font(.caption).multilineTextAlignment(.center)
            Text(monitor.motionStatus).foregroundStyle(.secondary)
            Button("Calibrate upright posture") { monitor.calibrate() }
            Text("Keep your face and shoulders in view. Face-only mode tracks vertical head movement; it cannot measure spine posture.").font(.caption).multilineTextAlignment(.center)
        }.padding(30).frame(minWidth: 400, minHeight: 220).onAppear { monitor.start() }
    }
}
@main struct UprightApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}
