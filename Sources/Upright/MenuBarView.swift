import SwiftUI

struct MenuBarView: View {
    @ObservedObject var monitor: Monitor
    let openDetails: () -> Void
    let quit: () -> Void
    @State private var feedback: String?
    @State private var feedbackID = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Upright", systemImage: "figure.seated.side")
                    .font(.headline)
                Spacer()
                Text("ON THIS MAC")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            CameraPreview(session: monitor.session)
                .overlay {
                    LandmarkOverlay(points: monitor.landmarks, imageSize: monitor.landmarkImageSize)
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel("Live camera preview")

            VStack(alignment: .leading, spacing: 3) {
                Text(feedback ?? monitor.status)
                    .font(.callout.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Keep your face and shoulders in view.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button {
                let succeeded = monitor.calibrate()
                feedback = succeeded ? "Baseline saved" : monitor.status
                let id = UUID()
                feedbackID = id
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if feedbackID == id { feedback = nil }
                }
            } label: {
                Text(monitor.isCalibrated ? "Recalibrate posture" : "Calibrate posture")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .help("Save the current position as your baseline")

            Divider()
            HStack {
                Button("Open detailed view", action: openDetails)
                Spacer()
                Button("Quit Upright", action: quit)
                    .help("Quit Upright and stop monitoring")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(16)
        .frame(width: 360)
    }
}
