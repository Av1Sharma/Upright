import Foundation
@main struct PostureConfirmationTests {
    static func main() {
        var tracker = PostureConfirmation()
        for time in 0...4 { _ = tracker.observeChanged(at: Double(time)) }
        precondition(tracker.evidence == 4, "Continuous evidence should confirm")
        tracker.reset()
        _ = tracker.observeChanged(at: 0)
        _ = tracker.observeChanged(at: 1)
        tracker.observeUnavailable(at: 1.5)
        _ = tracker.observeChanged(at: 2)
        precondition(tracker.evidence == 1, "A missing sample must not add time")
        _ = tracker.observeChanged(at: 3)
        precondition(tracker.evidence == 2, "Evidence should resume after a short gap")
        tracker.observeUnavailable(at: 6)
        precondition(tracker.evidence == 0, "A long interruption must reset evidence")
        _ = tracker.observeChanged(at: 10)
        tracker.observeNotChanged(at: 11)
        _ = tracker.observeChanged(at: 12.5)
        precondition(tracker.evidence == 0, "Normal posture beyond the grace period must reset")
        _ = tracker.observeChanged(at: 20)
        precondition(tracker.evidence == 0, "Long sampling gaps cannot count as evidence")
        print("Posture confirmation checks passed")
    }
}
