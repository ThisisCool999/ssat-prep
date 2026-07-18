import Foundation
import SwiftUI
import SSATCore

@MainActor
final class AppState: ObservableObject {
    let content = ContentStore.shared
    let progress = ProgressStore()

    /// Incremented whenever progress changes so summary views recompute.
    @Published private(set) var refreshTick = 0

    /// Set by a dashboard card to deep-link the Word List to a filter; the
    /// Word List reads and clears it when it appears.
    @Published var pendingWordFilter: String?

    func bump() { refreshTick += 1 }

    /// Flashcard deck scope: the whole deck, or only the "often tested" words
    /// drawn from the student's class list.
    enum DeckScope: String, CaseIterable, Identifiable {
        case all = "All words"
        case oftenTested = "Often tested"
        var id: String { rawValue }
    }

    func words(for scope: DeckScope) -> [VocabWord] {
        scope == .oftenTested ? content.notebookWords : content.words
    }

    var dueNow: Int { dueNow(scope: .all) }
    /// Cards due now in this scope. When `excludingFlagged` is set, flagged words
    /// are left out — the Flashcards start screen counts them separately (they jump
    /// to the front of the session), so excluding them keeps due + new + flagged from
    /// double-counting a word that is both flagged and due.
    func dueNow(scope: DeckScope, excludingFlagged: Bool = false) -> Int {
        let now = Date()
        guard excludingFlagged else {
            return progress.dueCount(words: words(for: scope), now: now)
        }
        let flagged = Set(progress.priorityWords)
        guard !flagged.isEmpty else {
            return progress.dueCount(words: words(for: scope), now: now)
        }
        return words(for: scope).filter {
            !flagged.contains($0.word) && progress.card(for: $0.word).isDue(now: now)
        }.count
    }

    /// Words still flagged that belong to this scope (the count that only drops
    /// when a flag is actually cleared).
    func priorityCount(scope: DeckScope) -> Int {
        let flagged = Set(progress.priorityWords)
        guard !flagged.isEmpty else { return 0 }
        return words(for: scope).reduce(0) { $0 + (flagged.contains($1.word) ? 1 : 0) }
    }

    /// Flagged words in this scope a new session will actually serve: the ones not
    /// yet drilled in the current pass (or the full set again once a pass finishes).
    func flaggedToDrill(scope: DeckScope) -> Int {
        let flagged = Set(progress.priorityWords)
        guard !flagged.isEmpty else { return 0 }
        let scopeFlagged = words(for: scope).filter { flagged.contains($0.word) }
        guard !scopeFlagged.isEmpty else { return 0 }
        let done = Set(progress.priorityDoneWords)
        let remaining = scopeFlagged.filter { !done.contains($0.word) }.count
        return remaining == 0 ? scopeFlagged.count : remaining
    }

    /// The flagged/marked words as full entries (missed in a test or marked by hand).
    var flaggedWords: [VocabWord] {
        let f = Set(progress.priorityWords)
        return content.words.filter { f.contains($0.word) }
    }

    /// Words first learned `daysAgo` days ago — e.g. daysAgo: 1 is yesterday.
    func newWords(daysAgo: Int) -> [VocabWord] {
        let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let set = progress.dayStats(for: day).newWords
        guard !set.isEmpty else { return [] }
        return content.words.filter { set.contains($0.word) }
    }

    var newRemainingToday: Int { newRemainingToday(scope: .all) }
    func newRemainingToday(scope: DeckScope, excludingFlagged: Bool = false) -> Int {
        let limit = UserDefaults.standard.object(forKey: "newPerDay") as? Int ?? 15
        let scopeWords = words(for: scope)
        // Budget is measured against new words already learned *within this scope*
        // today, so drilling often-tested words isn't blocked by unrelated new
        // words learned in the full deck (and vice versa).
        let introduced = progress.newWordsToday(in: Set(scopeWords.map { $0.word }), now: Date())
        // Flagged new-phase words are served from the priority queue, not the new
        // bucket, so the start screen excludes them here to avoid counting them
        // both as "new" and as "flagged" (mirrors StudySession's `fresh` filter).
        let flagged = excludingFlagged ? Set(progress.priorityWords) : []
        let unseen = scopeWords.filter {
            !flagged.contains($0.word) && progress.card(for: $0.word).phase == .new
        }.count
        return min(max(0, limit - introduced), unseen)
    }

    func makeSession(scope: DeckScope = .all) -> StudySession {
        let limit = UserDefaults.standard.object(forKey: "newPerDay") as? Int ?? 15
        return StudySession(words: words(for: scope), store: progress, newLimit: limit)
    }
}
