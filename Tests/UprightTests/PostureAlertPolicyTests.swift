import Foundation

@main struct PostureAlertPolicyTests {
    static func main() {
        var confirmation = PostureConfirmation()
        var alerts = PostureAlertPolicy()
        var count = 0
        for time in 0...20 {
            let progress = confirmation.observeChanged(at: Double(time))
            if alerts.observeChanged(confirmed: progress >= confirmation.required) {
                precondition(time == 4, "Alert only after four seconds of evidence")
                count += 1
            }
        }
        precondition(count == 1, "Sustained changed posture must not spam notifications")

        for time in 21...23 { alerts.observeBaseline(at: Double(time)) }
        precondition(!alerts.observeChanged(confirmed: true), "Brief recovery must not rearm alerts")
        alerts.observeBaseline(at: 24)
        alerts.interruptRecovery()
        for time in 25...28 { alerts.observeBaseline(at: Double(time)) }
        precondition(!alerts.observeChanged(confirmed: true), "Tracking loss must break recovery evidence")

        alerts.observeBaseline(at: 30)
        alerts.observeBaseline(at: 40)
        precondition(!alerts.observeChanged(confirmed: true), "A sampling gap must not count as recovery")
        alerts.interruptRecovery()
        precondition(!alerts.observeChanged(confirmed: true), "Detector changes must not rearm alerts")

        for time in 41...45 { alerts.observeBaseline(at: Double(time)) }
        precondition(!alerts.observeChanged(confirmed: false), "A new change still needs confirmation")
        precondition(alerts.observeChanged(confirmed: true), "Sustained recovery must allow a new alert")
        precondition(!alerts.observeChanged(confirmed: true), "The new episode must also alert only once")
        alerts.reset()
        precondition(!alerts.observeChanged(confirmed: false), "Calibration must not itself alert")
        precondition(alerts.observeChanged(confirmed: true), "Calibration must allow a future confirmed alert")
        print("Posture alert policy checks passed")
    }
}
