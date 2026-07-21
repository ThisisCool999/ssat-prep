import Foundation

public struct DayStats: Codable, Equatable {
    /// Total grades made that day (a lapsed card counts each time it resurfaces).
    public var reviews: Int = 0
    public var newIntroduced: Int = 0
    public var quizQuestions: Int = 0
    public var quizCorrect: Int = 0
    /// Distinct words touched in flashcards that day — the true "words reviewed"
    /// count, unaffected by struggling on one word across many cards.
    public var words: Set<String> = []
    /// The specific words first introduced (learned) today, so the daily
    /// new-word budget can be measured per deck scope rather than globally.
    public var newWords: Set<String> = []

    public var uniqueWordsReviewed: Int { words.count }
    /// Distinct new words learned today — deduped, so a word that recurs across
    /// its learning steps counts once (unlike the raw `newIntroduced` counter).
    public var uniqueNewWords: Int { newWords.count }

    public init() {}

    // Custom decode so progress files written before these sets existed still
    // load (a missing key would otherwise throw and discard the user's history).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reviews = try c.decodeIfPresent(Int.self, forKey: .reviews) ?? 0
        newIntroduced = try c.decodeIfPresent(Int.self, forKey: .newIntroduced) ?? 0
        quizQuestions = try c.decodeIfPresent(Int.self, forKey: .quizQuestions) ?? 0
        quizCorrect = try c.decodeIfPresent(Int.self, forKey: .quizCorrect) ?? 0
        words = try c.decodeIfPresent(Set<String>.self, forKey: .words) ?? []
        newWords = try c.decodeIfPresent(Set<String>.self, forKey: .newWords) ?? []
    }
}

public struct QuizResult: Codable, Equatable {
    public let date: Date
    public let kind: String
    public let total: Int
    public let correct: Int

    public init(date: Date, kind: String, total: Int, correct: Int) {
        self.date = date
        self.kind = kind
        self.total = total
        self.correct = correct
    }
}

/// Progress toward auto-unflagging one flagged word: two Good/Easy answers in a
/// row, then a further success on a strictly later calendar day.
struct FlagProgress: Codable {
    var streak: Int = 0
    var qualifiedDay: Date? = nil   // day the 2-in-a-row was first reached
}

private struct ProgressFile: Codable {
    var cards: [String: CardState] = [:]
    var days: [String: DayStats] = [:]
    var quizzes: [QuizResult] = []
    var passageAnswers: [String: [Int]] = [:]
    /// Words flagged for immediate study (e.g. missed in a Word Test) — pulled
    /// to the front of the next flashcard session, in insertion order.
    var priority: [String] = []
    /// Flagged words already drilled in the current pass through the flag list.
    /// Lets flashcard sessions resume with the words you haven't reached yet,
    /// instead of re-serving the same front words, without clearing the flag.
    var priorityDone: [String] = []
    /// Per-flagged-word progress toward the auto-unflag rule.
    var flagProgress: [String: FlagProgress] = [:]

    init() {}

    // Custom decode so files written before `priority` existed still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cards = try c.decodeIfPresent([String: CardState].self, forKey: .cards) ?? [:]
        days = try c.decodeIfPresent([String: DayStats].self, forKey: .days) ?? [:]
        quizzes = try c.decodeIfPresent([QuizResult].self, forKey: .quizzes) ?? []
        passageAnswers = try c.decodeIfPresent([String: [Int]].self, forKey: .passageAnswers) ?? [:]
        priority = try c.decodeIfPresent([String].self, forKey: .priority) ?? []
        priorityDone = try c.decodeIfPresent([String].self, forKey: .priorityDone) ?? []
        flagProgress = try c.decodeIfPresent([String: FlagProgress].self, forKey: .flagProgress) ?? [:]
    }
}

/// All mutable user state: one JSON file in Application Support.
public final class ProgressStore {
    private var file: ProgressFile
    private let url: URL
    private let calendar = Calendar.current

    public init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SSATPrep", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("progress.json")
        if let data = try? Data(contentsOf: url) {
            do {
                file = try JSONDecoder().decode(ProgressFile.self, from: data)
            } catch {
                // Never let a later save() clobber a file we couldn't read —
                // move it aside so the history stays recoverable.
                let backup = dir.appendingPathComponent(
                    "progress-corrupt-\(Int(Date().timeIntervalSince1970)).json")
                try? FileManager.default.moveItem(at: url, to: backup)
                FileHandle.standardError.write(Data(
                    "SSATPrep: progress.json failed to decode (\(error)); moved to \(backup.lastPathComponent)\n".utf8))
                file = ProgressFile()
            }
        } else {
            file = ProgressFile()
        }
    }

    public func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            let data = try encoder.encode(file)
            try data.write(to: url, options: .atomic)
        } catch {
            FileHandle.standardError.write(Data(
                "SSATPrep: failed to save progress: \(error)\n".utf8))
        }
    }

    // MARK: Cards

    public func card(for word: String) -> CardState {
        file.cards[word] ?? CardState()
    }

    public func setCard(_ state: CardState, for word: String) {
        file.cards[word] = state
    }

    public func resetCard(for word: String) {
        file.cards.removeValue(forKey: word)
    }

    // MARK: Priority (front-of-queue study)

    public var priorityWords: [String] { file.priority }

    /// Flag words to study first in the next flashcard session (dedup, keep order).
    public func flagPriority(_ words: [String]) {
        let existing = Set(file.priority)
        for w in words where !existing.contains(w) { file.priority.append(w) }
    }

    public func clearPriority(_ word: String) {
        file.priority.removeAll { $0 == word }
        file.priorityDone.removeAll { $0 == word }
        file.flagProgress[word] = nil
    }

    public var priorityDoneWords: [String] { file.priorityDone }

    /// Mark a flagged word as drilled in the current pass, so sessions resume with
    /// the words you haven't reached yet. Idempotent; a no-op for unflagged words.
    public func markPriorityDrilled(_ word: String) {
        guard file.priority.contains(word), !file.priorityDone.contains(word) else { return }
        file.priorityDone.append(word)
    }

    /// Start a fresh pass through the flag list (called once every flag is drilled).
    public func resetPriorityPass() {
        file.priorityDone.removeAll()
    }

    /// Advance a flagged word toward auto-unflagging on a flashcard answer. A flag
    /// clears only after two Good/Easy answers in a row and then a further success
    /// on a strictly later calendar day. `success` means Good or Easy; anything
    /// else breaks the streak. Returns true if this answer cleared the flag.
    @discardableResult
    public func advanceFlagMastery(word: String, success: Bool, on date: Date) -> Bool {
        guard file.priority.contains(word) else { return false }
        guard success else {
            file.flagProgress[word] = FlagProgress()
            return false
        }
        let today = calendar.startOfDay(for: date)
        var fp = file.flagProgress[word] ?? FlagProgress()
        if fp.streak >= 2, let day = fp.qualifiedDay, today > calendar.startOfDay(for: day) {
            clearPriority(word)
            return true
        }
        fp.streak += 1
        if fp.streak >= 2 && fp.qualifiedDay == nil {
            fp.qualifiedDay = today
        }
        file.flagProgress[word] = fp
        return false
    }

    public func resetAll() {
        file = ProgressFile()
        save()
    }

    // MARK: Day log

    private func dayKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public func dayStats(for date: Date) -> DayStats {
        file.days[dayKey(date)] ?? DayStats()
    }

    public func recordReview(word: String, on date: Date, wasNew: Bool) {
        var d = file.days[dayKey(date)] ?? DayStats()
        d.reviews += 1
        d.words.insert(word)
        if wasNew {
            d.newIntroduced += 1
            d.newWords.insert(word)
        }
        file.days[dayKey(date)] = d
    }

    /// New words introduced today whose headword is in `scopeWords`.
    public func newWordsToday(in scopeWords: Set<String>, now: Date) -> Int {
        dayStats(for: now).newWords.intersection(scopeWords).count
    }

    public func recordQuiz(_ result: QuizResult) {
        file.quizzes.append(result)
        var d = file.days[dayKey(result.date)] ?? DayStats()
        d.quizQuestions += result.total
        d.quizCorrect += result.correct
        file.days[dayKey(result.date)] = d
    }

    public var quizzes: [QuizResult] { file.quizzes }

    // MARK: Passages

    public func passageAnswers(for title: String) -> [Int] {
        file.passageAnswers[title] ?? []
    }

    public func setPassageAnswers(_ answers: [Int], for title: String) {
        file.passageAnswers[title] = answers
    }

    // MARK: Derived stats

    /// Consecutive days ending today (or yesterday, if today has no activity yet)
    /// with at least one review or quiz question.
    public func streak(asOf date: Date) -> Int {
        var count = 0
        var day = date
        let todayActive = isActive(on: day)
        if !todayActive {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        while isActive(on: day) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    private func isActive(on date: Date) -> Bool {
        let d = file.days[dayKey(date)] ?? DayStats()
        return d.reviews > 0 || d.quizQuestions > 0
    }

    /// Matches what a session will serve: due now, or a learning-step card due
    /// within the learn-ahead window (so the start screen never claims "nothing
    /// due" for a word a session would in fact pick up).
    private func servableNow(_ c: CardState, now: Date) -> Bool {
        if c.isDue(now: now) { return true }
        if c.phase == .learning || c.phase == .relearning {
            return c.isDue(now: now.addingTimeInterval(SM2.learnAheadSeconds))
        }
        return false
    }

    public func dueCount(words: [VocabWord], now: Date) -> Int {
        words.filter { servableNow(card(for: $0.word), now: now) }.count
    }

    /// Review-due counts for the next `days` days starting at `now` (index 0 = today).
    /// Today's bucket is exactly the cards due *now* (so it matches `dueCount`);
    /// a learning card scheduled for later today isn't actionable yet and is not
    /// counted until its step elapses. Future buckets group by calendar day.
    public func forecast(words: [VocabWord], now: Date, days: Int) -> [Int] {
        var counts = [Int](repeating: 0, count: days)
        let startOfToday = calendar.startOfDay(for: now)
        for w in words {
            let c = card(for: w.word)
            guard let due = c.due else { continue }
            let day = calendar.startOfDay(for: due)
            let offset = calendar.dateComponents([.day], from: startOfToday, to: day).day ?? 0
            if offset <= 0 {
                if servableNow(c, now: now) { counts[0] += 1 }
            } else if offset < days {
                counts[offset] += 1
            }
        }
        return counts
    }

    public func phaseCounts(words: [VocabWord]) -> (new: Int, learning: Int, young: Int, mastered: Int) {
        var new = 0, learning = 0, young = 0, mastered = 0
        for w in words {
            let c = card(for: w.word)
            switch c.phase {
            case .new: new += 1
            case .learning, .relearning: learning += 1
            case .review: c.isMastered ? (mastered += 1) : (young += 1)
            }
        }
        return (new, learning, young, mastered)
    }
}
