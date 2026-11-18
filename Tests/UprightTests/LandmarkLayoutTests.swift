import Foundation
@main struct LandmarkLayoutTests {
    static func main() {
        let rect = LandmarkLayout.imageRect(imageSize: CGSize(width: 640, height: 480), containerSize: CGSize(width: 400, height: 200))!
        precondition(abs(rect.width - 266.6666667) < 0.001)
        precondition(abs(rect.minX - 66.6666667) < 0.001 && rect.minY == 0)
        precondition(LandmarkLayout.imageRect(imageSize: .zero, containerSize: CGSize(width: 400, height: 200)) == nil)
        print("Landmark layout checks passed")
    }
}
