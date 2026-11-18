import Foundation

/// Accumulates only observed, consecutive intervals of changed posture.
/// Short uncertain/normal interruptions do not erase earlier evidence, but
/// never contribute time toward confirmation.
struct PostureConfirmation {
    private(set) var evidence: TimeInterval = 0
    private var lastChanged: TimeInterval?
    private var lastSampleWasChanged = false
    let required: TimeInterval = 10
    let interruptionGrace: TimeInterval = 2
    let maxSampleGap: TimeInterval = 5

    mutating func observeChanged(at time: TimeInterval) -> TimeInterval {
        if let last = lastChanged {
            let gap = time - last
            if gap < 0 || gap > maxSampleGap || (!lastSampleWasChanged && gap > interruptionGrace) {
                reset()
            } else if lastSampleWasChanged {
                evidence += gap
            }
        }
        lastChanged = time
        lastSampleWasChanged = true
        return min(evidence, required)
    }

    mutating func observeNotChanged(at time: TimeInterval) {
        if let last = lastChanged, time < last || time - last > interruptionGrace { reset() }
        lastSampleWasChanged = false
    }

    mutating func observeUnavailable(at time: TimeInterval) {
        observeNotChanged(at: time)
    }

    mutating func reset() {
        evidence = 0
        lastChanged = nil
        lastSampleWasChanged = false
    }
}
