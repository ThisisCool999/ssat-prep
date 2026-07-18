import Foundation

/// Anki-style SM-2 spaced repetition with in-session learning steps.
///
/// New cards pass through short learning steps (1 min, 10 min) inside a session
/// before graduating to day-scale review intervals. Review answers scale the
/// interval by the card's ease factor; lapses send the card back to relearning.

public enum Grade: Int, Codable, CaseIterable {
    case again = 0
    case hard = 1
    case good = 2
    case easy = 3
}

public enum CardPhase: String, Codable {
    case new
    case learning
    case review
    case relearning
}

public struct CardState: Codable, Equatable {
    public var phase: CardPhase
    public var ease: Double
    public var intervalDays: Double
    public var due: Date?
    public var reps: Int
    public var lapses: Int
    public var learningStep: Int
    /// Total times you answered "Again" on this word (any phase) — the misses
    /// that drive per-word accuracy.
    public var agains: Int

    public init() {
        phase = .new
        ease = 2.5
        intervalDays = 0
        due = nil
        reps = 0
        lapses = 0
        learningStep = 0
        agains = 0
    }

    // Custom decode so cards saved before `agains` existed still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        phase = try c.decodeIfPresent(CardPhase.self, forKey: .phase) ?? .new
        ease = try c.decodeIfPresent(Double.self, forKey: .ease) ?? 2.5
        intervalDays = try c.decodeIfPresent(Double.self, forKey: .intervalDays) ?? 0
        due = try c.decodeIfPresent(Date.self, forKey: .due)
        reps = try c.decodeIfPresent(Int.self, forKey: .reps) ?? 0
        lapses = try c.decodeIfPresent(Int.self, forKey: .lapses) ?? 0
        learningStep = try c.decodeIfPresent(Int.self, forKey: .learningStep) ?? 0
        agains = try c.decodeIfPresent(Int.self, forKey: .agains) ?? 0
    }

    public var isMastered: Bool { phase == .review && intervalDays >= 21 }

    /// Share of gradings on this word that were a pass (Hard/Good/Easy).
    /// nil until the word has been graded at least once.
    public var accuracy: Double? {
        reps > 0 ? Double(reps - agains) / Double(reps) : nil
    }

    /// Review cards are due any time on their due day (so a card that
    /// graduated at 9 PM is studyable the next morning); learning and
    /// relearning steps keep their exact timestamps.
    public func isDue(now: Date) -> Bool {
        guard let due else { return false }
        if phase == .review {
            return Calendar.current.startOfDay(for: due) <= now
        }
        return due <= now
    }
}

public enum SM2 {
    public static let learningSteps: [TimeInterval] = [60, 600]
    public static let relearningSteps: [TimeInterval] = [600]
    public static let graduatingIntervalDays: Double = 1
    public static let easyIntervalDays: Double = 4
    public static let maxIntervalDays: Double = 365
    public static let minEase: Double = 1.3

    public static func answer(_ state: CardState, grade: Grade, now: Date) -> CardState {
        var s = state
        s.reps += 1
        if grade == .again { s.agains += 1 }
        switch s.phase {
        case .new, .learning:
            s = answerLearning(s, grade: grade, now: now, steps: learningSteps, relapse: false)
        case .relearning:
            s = answerLearning(s, grade: grade, now: now, steps: relearningSteps, relapse: true)
        case .review:
            s = answerReview(s, grade: grade, now: now)
        }
        return s
    }

    private static func answerLearning(_ state: CardState, grade: Grade, now: Date,
                                       steps: [TimeInterval], relapse: Bool) -> CardState {
        var s = state
        s.phase = relapse ? .relearning : .learning
        switch grade {
        case .again:
            s.learningStep = 0
            s.due = now.addingTimeInterval(steps[0])
        case .hard:
            s.due = now.addingTimeInterval(steps[max(0, min(s.learningStep, steps.count - 1))])
        case .good:
            let next = s.learningStep + 1
            if next >= steps.count {
                s = graduate(s, now: now, interval: relapse ? max(1, s.intervalDays) : graduatingIntervalDays)
            } else {
                s.learningStep = next
                s.due = now.addingTimeInterval(steps[next])
            }
        case .easy:
            s = graduate(s, now: now, interval: relapse ? max(1, s.intervalDays) : easyIntervalDays)
        }
        return s
    }

    private static func graduate(_ state: CardState, now: Date, interval: Double) -> CardState {
        var s = state
        s.phase = .review
        s.learningStep = 0
        s.intervalDays = min(interval, maxIntervalDays)
        s.due = now.addingTimeInterval(s.intervalDays * 86400)
        return s
    }

    private static func answerReview(_ state: CardState, grade: Grade, now: Date) -> CardState {
        var s = state
        switch grade {
        case .again:
            s.lapses += 1
            s.ease = max(minEase, s.ease - 0.20)
            s.intervalDays = max(1, s.intervalDays * 0.5)
            s.phase = .relearning
            s.learningStep = 0
            s.due = now.addingTimeInterval(relearningSteps[0])
        case .hard:
            s.ease = max(minEase, s.ease - 0.15)
            s.intervalDays = min(maxIntervalDays, max(1, s.intervalDays * 1.2))
            s.due = now.addingTimeInterval(s.intervalDays * 86400)
        case .good:
            s.intervalDays = min(maxIntervalDays, max(1, s.intervalDays * s.ease))
            s.due = now.addingTimeInterval(s.intervalDays * 86400)
        case .easy:
            s.ease += 0.15
            s.intervalDays = min(maxIntervalDays, max(1, s.intervalDays * s.ease * 1.3))
            s.due = now.addingTimeInterval(s.intervalDays * 86400)
        }
        return s
    }

    /// Human preview of where each grade would send the card ("10m", "3d", "1.2mo").
    public static func intervalPreview(_ state: CardState, grade: Grade, now: Date) -> String {
        let next = answer(state, grade: grade, now: now)
        guard let due = next.due else { return "—" }
        let seconds = due.timeIntervalSince(now)
        if seconds < 3600 { return "\(max(1, Int(seconds / 60)))m" }
        if seconds < 86400 * 1.5 { return "1d" }
        let days = seconds / 86400
        if days < 30 { return "\(Int(days.rounded()))d" }
        let months = days / 30
        if months < 12 { return String(format: "%.1fmo", months) }
        return String(format: "%.1fy", days / 365)
    }
}
