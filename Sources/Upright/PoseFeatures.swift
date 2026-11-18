import Foundation

struct PosePoint {
    let x: Double
    let y: Double
    let confidence: Double

    init?(_ value: Any?) {
        guard let value = value as? [String: Any],
              let x = value["x"] as? Double, let y = value["y"] as? Double,
              let confidence = value["confidence"] as? Double,
              x.isFinite, y.isFinite, confidence.isFinite else { return nil }
        self.x = x; self.y = y; self.confidence = confidence
    }
}

struct PoseFeatures {
    let headHeight: Double
    let eyeToShoulderWidth: Double?

    init?(points: [String: Any], confidence: Double = 0.3) {
        guard let nose = PosePoint(points["nose"]),
              let left = PosePoint(points["leftShoulder"]),
              let right = PosePoint(points["rightShoulder"]),
              nose.confidence >= confidence, left.confidence >= confidence,
              right.confidence >= confidence else { return nil }
        let shoulderWidth = hypot(left.x - right.x, left.y - right.y)
        guard shoulderWidth > 10 else { return nil }
        headHeight = ((left.y + right.y) / 2 - nose.y) / shoulderWidth
        if let leftEye = PosePoint(points["leftEye"]), let rightEye = PosePoint(points["rightEye"]),
           leftEye.confidence >= confidence, rightEye.confidence >= confidence {
            let eyeWidth = hypot(leftEye.x - rightEye.x, leftEye.y - rightEye.y)
            eyeToShoulderWidth = eyeWidth > 0 ? eyeWidth / shoulderWidth : nil
        } else {
            eyeToShoulderWidth = nil
        }
    }
}
