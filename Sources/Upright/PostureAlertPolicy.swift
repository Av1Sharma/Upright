import Foundation

/// Sends one alert per changed-posture episode. Only sustained, observed
/// recovery rearms alerts; tracking loss and detector changes do not.
struct PostureAlertPolicy {
    private var alerted = false
    private var recovery = PostureConfirmation()

    mutating func observeChanged(confirmed: Bool) -> Bool {
        recovery.reset()
        guard confirmed, !alerted else { return false }
        alerted = true
        return true
    }

    mutating func observeBaseline(at time: TimeInterval) {
        if recovery.observeChanged(at: time) >= recovery.required {
            alerted = false
        }
    }

    mutating func interruptRecovery() {
        recovery.reset()
    }

    mutating func reset() {
        alerted = false
        recovery.reset()
    }
}
