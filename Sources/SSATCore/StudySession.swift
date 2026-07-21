import Foundation

/// Builds and runs one flashcard session: due learning/review cards first,
/// then up to the daily allowance of new cards. Cards answered "again"/"hard"
/// during learning come back within the same session once their short
/// learning step elapses (or immediately if nothing else is waiting).
public final class StudySession {
    /// Flagged words served per session. A big flag backlog used to interleave
    /// wholesale into one enormous queue (hours per cycle); batches keep sessions
    /// tight while the drilled-pass tracking still covers the backlog over time.
    public static let flaggedPerSession = 20

    public private(set) var queue: [VocabWord]
    public private(set) var completed: Int = 0
    public private(set) var againCount: Int = 0
    private let store: ProgressStore

    public init(words: [VocabWord], store: ProgressStore, newLimit: Int, now: Date = Date()) {
        self.store = store

        // Words flagged for immediate study (e.g. missed in a Word Test) jump to
        // the front, regardless of their schedule, and are excluded from the
        // normal buckets below so they aren't queued twice. To let sessions resume
        // instead of re-serving the same front words, only flags not yet drilled in
        // the current pass are queued; once every flag is drilled the pass resets.
        let prioritySet = Set(store.priorityWords)
        let flaggedInScope = words.filter { prioritySet.contains($0.word) }
        let doneSet = Set(store.priorityDoneWords)
        var priorityQueue = flaggedInScope.filter { !doneSet.contains($0.word) }
        if priorityQueue.isEmpty && !flaggedInScope.isEmpty {
            store.resetPriorityPass()
            priorityQueue = flaggedInScope
        }
        // Shuffle so a session isn't always the earliest word in list order,
        // then take one batch — the rest of the pass continues next session.
        priorityQueue.shuffle()
        priorityQueue = Array(priorityQueue.prefix(Self.flaggedPerSession))

        var learning: [(VocabWord, Date)] = []
        var review: [(VocabWord, Date)] = []
        var fresh: [VocabWord] = []
        for w in words where !prioritySet.contains(w.word) {
            let c = store.card(for: w.word)
            switch c.phase {
            case .new:
                fresh.append(w)
            case .learning, .relearning:
                // Learn-ahead: also pick up step cards due soon, so a word left
                // mid-step by the last session is never stranded and skipped.
                if let due = c.due,
                   c.isDue(now: now.addingTimeInterval(SM2.learnAheadSeconds)) {
                    learning.append((w, due))
                }
            case .review:
                if let due = c.due, c.isDue(now: now) { review.append((w, due)) }
            }
        }
        // Budget against distinct new words already learned today *within this
        // word set* (deduped) — matching the count shown on the start screen,
        // and immune to a word recurring across its learning steps.
        let scopeKeys = Set(words.map { $0.word })
        let introduced = store.dayStats(for: now).newWords.intersection(scopeKeys).count
        let newAllowance = max(0, newLimit - introduced)
        let newWords = Array(fresh.shuffled().prefix(newAllowance))

        let dueLearning: [VocabWord] = learning.sorted { $0.1 < $1.1 }.map { $0.0 }
        let dueReview: [VocabWord] = review.sorted { $0.1 < $1.1 }.map { $0.0 }
        let dueCards = dueLearning + dueReview

        // Round-robin the three streams instead of stacking all flagged first and
        // new words last. Otherwise a big flag backlog strands the new words at the
        // end where a short session never reaches them — so you'd only ever re-see
        // old words. Interleaving gives flagged, due, and new airtime every session.
        queue = Self.interleave([priorityQueue, dueCards, newWords])
    }

    /// Merge streams round-robin: one from each in turn, skipping exhausted ones,
    /// so every stream is represented from the very start of the queue.
    private static func interleave(_ streams: [[VocabWord]]) -> [VocabWord] {
        let maxLen = streams.map(\.count).max() ?? 0
        var out: [VocabWord] = []
        out.reserveCapacity(streams.reduce(0) { $0 + $1.count })
        for i in 0..<maxLen {
            for stream in streams where i < stream.count {
                out.append(stream[i])
            }
        }
        return out
    }

    /// Learning-step cards graded this session, waiting for their step to elapse
    /// before they are served again.
    private var waiting: [(word: VocabWord, due: Date)] = []

    public var current: VocabWord? { queue.first }
    public var remaining: Int { queue.count + waiting.count }
    public var isFinished: Bool { queue.isEmpty }
    /// Cards still in a learning step too far away to serve now — they return in
    /// a later session (shown on the end screen so the user knows to come back).
    public var pendingLaterCount: Int { waiting.count }

    /// Applies the grade, persists, and parks the card until its learning step
    /// elapses. Steps are honored in-session: a "10 min" card comes back after
    /// 10 minutes, not whenever the queue happens to cycle — otherwise three
    /// quick Goods minutes apart could graduate a word to day-scale review on
    /// nothing but short-term memory.
    public func answer(_ grade: Grade, now: Date = Date()) {
        guard let word = queue.first else { return }
        queue.removeFirst()

        let before = store.card(for: word.word)
        let after = SM2.answer(before, grade: grade, now: now)
        store.setCard(after, for: word.word)
        store.recordReview(word: word.word, on: now, wasNew: before.phase == .new)
        store.markPriorityDrilled(word.word)
        store.advanceFlagMastery(word: word.word,
                                 success: grade == .good || grade == .easy, on: now)
        store.save()

        completed += 1
        if grade == .again { againCount += 1 }

        if after.phase == .learning || after.phase == .relearning, let due = after.due {
            waiting.append((word, due))
        }
        promote(now: now)
    }

    /// Move waiting cards whose step has elapsed back into the queue; when the
    /// queue runs dry, serve cards due within the learn-ahead window early so
    /// the session doesn't end with a card 3 minutes from ready.
    private func promote(now: Date) {
        waiting.sort { $0.due < $1.due }
        // Elapsed step cards cut to the FRONT: their recall is time-critical.
        // Appended to the back of a long queue, a "10 minute" word would really
        // return after 10 minutes plus every other card in line.
        var ready: [VocabWord] = []
        while let first = waiting.first, first.due <= now {
            ready.append(waiting.removeFirst().word)
        }
        queue.insert(contentsOf: ready, at: 0)
        while queue.isEmpty, let first = waiting.first,
              first.due <= now.addingTimeInterval(SM2.learnAheadSeconds) {
            queue.append(waiting.removeFirst().word)
        }
    }

    /// Skip the current card to the back of the queue without grading it.
    public func postpone() {
        guard !queue.isEmpty else { return }
        queue.append(queue.removeFirst())
    }
}
