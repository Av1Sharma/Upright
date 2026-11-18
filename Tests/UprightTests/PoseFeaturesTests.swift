import Foundation

@main struct PoseFeaturesTests {
    static func point(_ x: Double, _ y: Double, _ confidence: Double = 0.9) -> [String: Double] {
        ["x": x, "y": y, "confidence": confidence]
    }
    static func main() {
        let base: [String: Any] = ["nose": point(50, 30), "leftEye": point(40, 20), "rightEye": point(60, 20), "leftShoulder": point(0, 80), "rightShoulder": point(100, 80)]
        guard let features = PoseFeatures(points: base), let ratio = features.eyeToShoulderWidth else { fatalError("Expected valid features") }
        precondition(abs(features.headHeight - 0.5) < 0.0001 && abs(ratio - 0.2) < 0.0001)
        var lowConfidence = base
        lowConfidence["leftEye"] = point(40, 20, 0.1)
        precondition(PoseFeatures(points: lowConfidence)?.eyeToShoulderWidth == nil)
        var narrow = base
        narrow["rightShoulder"] = point(1, 80)
        precondition(PoseFeatures(points: narrow) == nil)
        print("Pose feature checks passed")
    }
}
