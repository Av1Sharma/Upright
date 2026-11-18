import AppKit
import AVFoundation
import CoreMotion
import CoreImage
import Vision

final class Monitor: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var status = "Starting camera…"
    @Published var motionStatus = "AirPods unavailable"
    @Published var detectionStatus = "Waiting for camera frames…"
    @Published var modelStatus = "Loading PoseNet…"
    @Published var trackingStatus = "Waiting for first estimate"
    @Published var eyeWidthStatus = "Eye / shoulder width: unavailable"
    let session = AVCaptureSession()
    private let motion = CMHeadphoneMotionManager()
    private let poseNet = PoseNetEngine()
    private let queue = DispatchQueue(label: "upright.camera")
    private let landmarkConfidence: Float = 0.2
    private enum CameraMode: String { case body = "Vision body landmarks", poseNet = "PoseNet body landmarks", face = "Face position (limited)" }
    private var baseline: Double?
    private var baselineMode: CameraMode?
    private var latestMode: CameraMode?
    private var latest: Double?
    private var latestEyeRatio: Double?
    private var baselineEyeRatio: Double?
    private var latestTime = Date.distantPast
    private var badSince: Date?
    private var reference: CMAttitude?
    private var tilt = 0.0
    private var motionTime = Date.distantPast
    private var lastFrame = Date.distantPast
    private var estimateCount = 0
    private var watchdog: Timer?
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        watchdog = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.checkEstimateFreshness()
        }
        poseNet.onState = { [weak self] state in
            guard let self else { return }
            self.latest = nil
            self.latestEyeRatio = nil
            self.baselineEyeRatio = nil
            self.badSince = nil
            switch state {
            case .loading: self.modelStatus = "Loading PoseNet…"
            case .ready: self.modelStatus = "PoseNet ready"
            case .unavailable: self.modelStatus = "PoseNet unavailable; using Apple Vision"
            }
        }
        poseNet.onResult = { [weak self] points in self?.handlePoseNet(points) }
        poseNet.start()
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
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: self.queue)
            guard self.session.canAddOutput(output) else { DispatchQueue.main.async { self.status = "Camera output unavailable" }; return }
            self.session.addOutput(output)
            self.session.startRunning()
            DispatchQueue.main.async { self.status = "Sit comfortably upright and calibrate" }
        }
    }
    func calibrate() {
        guard let latest, Date().timeIntervalSince(latestTime) < 5 else { status = "Waiting for a usable body pose"; return }
        baseline = latest
        baselineMode = latestMode
        baselineEyeRatio = latestMode == .poseNet ? latestEyeRatio : nil
        reference = motion.deviceMotion?.attitude.copy() as? CMAttitude
        tilt = 0; badSince = nil
        status = "Calibrated"
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard Date().timeIntervalSince(lastFrame) > 0.5, let image = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastFrame = Date()
        let frame = CIImage(cvPixelBuffer: image)
        let usePoseNet = DispatchQueue.main.sync { self.poseNet.state == .ready }
        if usePoseNet {
            DispatchQueue.main.async { self.poseNet.submit(frame) }
            return
        }
        let request = VNDetectHumanBodyPoseRequest()
        let faceRequest = VNDetectFaceRectanglesRequest()
        // Vision remains available while PoseNet loads or when model loading fails.
        // Ignore its results once PoseNet is ready so measurements never mix.
        do {
            try VNImageRequestHandler(cvPixelBuffer: image, orientation: .up, options: [:]).perform([request, faceRequest])
            let faceCount = faceRequest.results?.count ?? 0
            let frameSize = "\(CVPixelBufferGetWidth(image))×\(CVPixelBufferGetHeight(image))"
            guard let pose = request.results?.first else {
                if let face = faceRequest.results?.first {
                    let value = Double(face.boundingBox.midY)
                    DispatchQueue.main.async {
                        guard self.poseNet.state != .ready else { return }
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
            DispatchQueue.main.async { if self.poseNet.state != .ready { self.detectionStatus = detail } }
            guard let nose = points[.nose], let left = points[.leftShoulder], let right = points[.rightShoulder], nose.confidence > landmarkConfidence, left.confidence > landmarkConfidence, right.confidence > landmarkConfidence else { missing(detail); return }
            let width = hypot(left.location.x - right.location.x, left.location.y - right.location.y)
            guard width > 0.05 else { missing("Shoulders appear too close together. Move closer to the camera."); return }
            let feature = (nose.location.y - (left.location.y + right.location.y) / 2) / width
            DispatchQueue.main.async { if self.poseNet.state != .ready { self.update(feature, mode: .body) } }
        } catch { missing("Vision error: \(error.localizedDescription)") }
    }
    private func handlePoseNet(_ points: [String: Any]) {
        guard let features = PoseFeatures(points: points) else {
            latest = nil; latestEyeRatio = nil; badSince = nil
            eyeWidthStatus = "Eye / shoulder width: unavailable"
            detectionStatus = "PoseNet: face or shoulders not reliably visible"
            status = "Waiting for a usable body pose"
            return
        }
        latestEyeRatio = features.eyeToShoulderWidth
        if let ratio = features.eyeToShoulderWidth {
            let change = baselineMode == .poseNet ? baselineEyeRatio.map { String(format: "%+.3f", ratio - $0) } : nil
            eyeWidthStatus = String(format: "Eye / shoulder width: %.3f · change %@", ratio, change ?? "—")
        } else {
            eyeWidthStatus = "Eye / shoulder width: eyes not reliably visible"
        }
        let left = PosePoint(points["leftShoulder"])!
        let right = PosePoint(points["rightShoulder"])!
        detectionStatus = String(format: "PoseNet · shoulders %.0f%% / %.0f%%", left.confidence * 100, right.confidence * 100)
        update(features.headHeight, mode: .poseNet)
    }
    private func missing(_ detail: String) { DispatchQueue.main.async { guard self.poseNet.state != .ready else { return }; self.latest = nil; self.badSince = nil; self.detectionStatus = detail; self.status = "Face and shoulders must be visible" } }
    private func checkEstimateFreshness() {
        guard latest != nil, Date().timeIntervalSince(latestTime) >= 5 else { return }
        latest = nil
        latestEyeRatio = nil
        eyeWidthStatus = "Eye / shoulder width: unavailable"
        badSince = nil
        trackingStatus = "Waiting for a fresh pose estimate"
        status = "Waiting for camera updates"
    }
    private func update(_ value: Double, mode: CameraMode) {
        estimateCount += 1
        let delta = baseline.map { String(format: "%+.3f", value - $0) } ?? "—"
        trackingStatus = String(format: "Estimate %d · pose %.3f · change %@", estimateCount, value, delta)
        latest = value
        latestTime = Date()
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
            Text(monitor.trackingStatus).font(.caption).monospacedDigit()
            Text(monitor.eyeWidthStatus).font(.caption).monospacedDigit()
            Text(monitor.modelStatus).foregroundStyle(.secondary)
            Text(monitor.motionStatus).foregroundStyle(.secondary)
            Button("Calibrate upright posture") { monitor.calibrate() }
            Text("Keep your face and shoulders in view. Face-only mode tracks vertical head movement; it cannot measure spine posture.").font(.caption).multilineTextAlignment(.center)
        }.padding(30).frame(minWidth: 400, minHeight: 220).onAppear { monitor.start() }
    }
}
@main struct UprightApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}
