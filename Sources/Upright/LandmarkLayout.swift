import Foundation
import CoreGraphics

struct OverlayPoint {
    let name: String
    let x: Double
    let y: Double
}

enum LandmarkLayout {
    // Video uses resizeAspect, so account for letterboxing before placing points.
    static func imageRect(imageSize: CGSize, containerSize: CGSize) -> CGRect? {
        guard imageSize.width > 0, imageSize.height > 0,
              containerSize.width > 0, containerSize.height > 0 else { return nil }
        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (containerSize.width - size.width) / 2,
                      y: (containerSize.height - size.height) / 2,
                      width: size.width, height: size.height)
    }
}
