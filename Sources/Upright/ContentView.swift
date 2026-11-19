import SwiftUI

struct ContentView: View {
    @StateObject private var monitor = Monitor()
    @State private var showLandmarks = true
    @State private var showDetails = false

    private var statusSymbol: String {
        if monitor.status == "Posture near baseline" || monitor.status == "Calibrated" { return "checkmark.circle.fill" }
        if monitor.status.hasPrefix("Posture changed") { return "exclamationmark.circle.fill" }
        if monitor.status.hasPrefix("Checking posture") { return "clock.fill" }
        return "viewfinder.circle.fill"
    }
    private var statusColor: Color {
        if monitor.status == "Posture near baseline" || monitor.status == "Calibrated" { return .green }
        if monitor.status.hasPrefix("Posture changed") { return .orange }
        return .accentColor
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                cameraCard
                statusCard
                calibrationCard
                diagnostics
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield")
                    Text("Camera frames are processed on this Mac.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 720)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 420, minHeight: 520)
        .onAppear { monitor.start() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "figure.seated.side")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Upright").font(.title2.bold())
                Text("Your posture, at a glance").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var cameraCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Camera", systemImage: "video")
                    .font(.headline)
                Spacer()
                Toggle("Landmarks", isOn: $showLandmarks)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("Show detected facial and shoulder landmarks")
            }
            CameraPreview(session: monitor.session)
                .overlay {
                    if showLandmarks {
                        LandmarkOverlay(points: monitor.landmarks, imageSize: monitor.landmarkImageSize)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .background(Color.black.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Live camera preview")
            Text("Keep your face and both shoulders in view.")
                .font(.callout).foregroundStyle(.secondary)
        }
        .padding(16)
        .cardSurface()
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: statusSymbol)
                .font(.system(size: 22))
                .foregroundStyle(statusColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text("POSTURE STATUS")
                    .font(.caption.weight(.semibold))
                    .tracking(0.7)
                    .foregroundStyle(.secondary)
                Text(monitor.status)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(monitor.isCalibrated ? "Tracking changes from your calibrated position." : "Calibrate below to start tracking posture changes.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var calibrationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your baseline").font(.headline)
            Text("Sit comfortably upright, look at your screen, then calibrate. Recalibrate if you move your laptop or change your seating position.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: monitor.calibrate) {
                Label(monitor.isCalibrated ? "Recalibrate posture" : "Calibrate posture", systemImage: "scope")
                    .frame(minHeight: 24)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var diagnostics: some View {
        DisclosureGroup("Tracking details", isExpanded: $showDetails) {
            VStack(alignment: .leading, spacing: 10) {
                detailRow("Detection", monitor.detectionStatus)
                detailRow("Head position", monitor.trackingStatus)
                detailRow("Eye spacing", monitor.eyeWidthStatus)
                detailRow("Model", monitor.modelStatus)
                detailRow("AirPods", monitor.motionStatus)
                Text("These experimental measurements indicate posture changes; they do not measure spine curvature.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 12)
        }
        .font(.callout)
        .padding(16)
        .cardSurface()
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.callout).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    func cardSurface() -> some View {
        background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.07)))
    }
}
