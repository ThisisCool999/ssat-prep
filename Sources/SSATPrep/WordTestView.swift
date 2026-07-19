import SwiftUI
import SSATCore

/// A straight run through every word (or every often-tested word): see each
/// one, mark whether you know it, and at the end get the full list of misses.
/// Unlike Flashcards this ignores spaced-repetition scheduling — it's an audit
/// of what you actually know right now.
struct WordTestView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.panelActive) private var panelActive

    @State private var scope: TestScope = .all
    @State private var sectionSize = 0          // 0 = no split (all at once)
    @State private var sectionIndex = 0
    @State private var flagMissed = true
    @State private var queue: [VocabWord] = []
    @State private var index = 0
    @State private var revealed = false
    @State private var missed: [VocabWord] = []
    @State private var correct = 0
    @State private var finished = false

    enum TestScope: String, CaseIterable, Identifiable {
        case all = "All words"
        case oftenTested = "Often tested"
        case flagged = "Flagged"
        case yesterday = "Yesterday's new"
        var id: String { rawValue }
    }

    private static let sizeChoices = [0, 30, 50, 80, 100]

    private func scopeWords(_ s: TestScope) -> [VocabWord] {
        switch s {
        case .all: return state.content.words
        case .oftenTested: return state.content.notebookWords
        case .flagged: return state.flaggedWords
        case .yesterday: return state.newWords(daysAgo: 1)
        }
    }

    /// Scope words in a stable order, so "sections" are consistent between runs.
    private var pool: [VocabWord] { scopeWords(scope).sorted { $0.word < $1.word } }

    private var sectionCount: Int {
        guard sectionSize > 0 else { return 1 }
        return max(1, Int(ceil(Double(pool.count) / Double(sectionSize))))
    }

    private var currentSection: [VocabWord] {
        guard sectionSize > 0 else { return pool }
        let start = min(sectionIndex, sectionCount - 1) * sectionSize
        guard start < pool.count else { return [] }
        return Array(pool[start..<min(start + sectionSize, pool.count)])
    }

    var body: some View {
        Group {
            if finished {
                results
            } else if let word = queue.indices.contains(index) ? queue[index] : nil {
                testScreen(word)
            } else {
                startScreen
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Start

    private var startScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist.checked")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent)
            Text("Word Test")
                .font(.largeTitle.weight(.semibold))
            Text("Go through words one by one and mark whether you know each. At the end you get the full list you missed.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 480)

            VStack(alignment: .leading, spacing: 12) {
                labeledRow("Which words") {
                    Picker("", selection: $scope) {
                        ForEach(TestScope.allCases) { s in Text(s.rawValue).tag(s) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: scope) { _, _ in sectionIndex = 0 }
                }
                Text(scopeBlurb)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                labeledRow("Section size") {
                    Picker("", selection: $sectionSize) {
                        ForEach(Self.sizeChoices, id: \.self) { n in
                            Text(n == 0 ? "All at once" : "\(n)").tag(n)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: sectionSize) { _, _ in sectionIndex = 0 }
                }

                if sectionSize > 0 && sectionCount > 1 {
                    labeledRow("Section") {
                        HStack {
                            Stepper("Section \(sectionIndex + 1) of \(sectionCount)",
                                    value: $sectionIndex, in: 0...(sectionCount - 1))
                            Spacer()
                            Text(sectionRangeLabel).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Toggle(isOn: $flagMissed) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Flag the words I miss").font(.callout)
                        Text("Missed words jump to the front of Flashcards. Flags clear only by mastering the word (2 Goods in a row, then a success the next day) or unflagging by hand.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 460)
            .padding(14)
            .cardStyle()

            Button {
                start(with: currentSection.shuffled())
            } label: {
                Text(pool.isEmpty ? "No words in this set" : "Start test — \(currentSection.count) words")
                    .font(.headline)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(currentSection.isEmpty)

            Text("Press **space** to reveal the meaning, **1** for missed, **2** for got it.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(30)
    }

    private func labeledRow<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private var scopeBlurb: String {
        switch scope {
        case .all: return "\(state.content.words.count) words — your whole deck."
        case .oftenTested: return "\(state.content.notebookWords.count) words your class flags as most-tested."
        case .flagged:
            let n = state.flaggedWords.count
            return n == 0 ? "Nothing flagged yet — miss words here or tap “Flag for test” in the Word List."
                          : "\(n) words you missed last round or flagged by hand."
        case .yesterday:
            let n = state.newWords(daysAgo: 1).count
            return n == 0 ? "No new words were learned yesterday to check."
                          : "\(n) words you first learned yesterday — see what stuck."
        }
    }

    private var sectionRangeLabel: String {
        let s = currentSection
        guard let first = s.first?.word, let last = s.last?.word else { return "" }
        return "\(first)…\(last)"
    }

    private func start(with words: [VocabWord]) {
        queue = words.shuffled()
        index = 0
        revealed = false
        missed = []
        correct = 0
        finished = queue.isEmpty
    }

    // MARK: Test

    private func testScreen(_ word: VocabWord) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(index + 1) of \(queue.count)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                if word.source == .notebook {
                    Label("Often tested", systemImage: "star.fill")
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.notebook.opacity(0.14), in: Capsule())
                        .foregroundStyle(Theme.notebook)
                }
                Spacer()
                Text("\(correct) known · \(missed.count) missed")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button("End test") { finish() }
                    .controlSize(.small)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            ProgressView(value: Double(index), total: Double(max(1, queue.count)))
                .padding(.horizontal, 24)
                .padding(.top, 6)

            Spacer()

            VStack(spacing: 14) {
                Text(word.word)
                    .font(.system(size: 44, weight: .semibold, design: .serif))
                Text(word.pos).font(.callout.italic()).foregroundStyle(.secondary)

                if revealed {
                    Divider().frame(width: 320)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(word.definition).font(.title3)
                        if !word.synonyms.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(word.synonyms, id: \.self) { s in
                                    Text(s).font(.callout)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(Theme.accent.opacity(0.10), in: Capsule())
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: 560)
            .padding(.vertical, 34).padding(.horizontal, 30)
            .frame(minHeight: 280)
            .cardStyle()
            .padding(.horizontal, 40)
            .onTapGesture { withAnimation(.easeInOut(duration: 0.12)) { revealed = true } }

            Spacer()

            HStack(spacing: 12) {
                if !revealed {
                    Button {
                        withAnimation { revealed = true }
                    } label: { Text("Show meaning").frame(width: 150).padding(.vertical, 6) }
                    .buttonStyle(.bordered)
                    .keyboardShortcutIf(panelActive, .space)
                }
                Button { grade(known: false, word: word) } label: {
                    Text("Missed").font(.headline).frame(width: 120).padding(.vertical, 7)
                        .background(Theme.wrong.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.wrong.opacity(0.5)))
                        .foregroundStyle(Theme.wrong)
                }
                .buttonStyle(.plain)
                .keyboardShortcutIf(panelActive, KeyEquivalent("1"))
                Button { grade(known: true, word: word) } label: {
                    Text("Got it").font(.headline).frame(width: 120).padding(.vertical, 7)
                        .background(Theme.mastered.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.mastered.opacity(0.5)))
                        .foregroundStyle(Theme.mastered)
                }
                .buttonStyle(.plain)
                .keyboardShortcutIf(panelActive, KeyEquivalent("2"))
            }
            .padding(.bottom, 24)
        }
    }

    private func grade(known: Bool, word: VocabWord) {
        if known { correct += 1 } else { missed.append(word) }
        revealed = false
        if index + 1 < queue.count {
            index += 1
        } else {
            finish()
        }
    }

    private func finish() {
        let answered = correct + missed.count
        if answered > 0 {
            state.progress.recordQuiz(QuizResult(date: Date(), kind: "wordtest",
                                                 total: answered, correct: correct))
            // Missed words jump to the front of the next flashcard session. A flag
            // only clears by mastering the word in Flashcards or unflagging by hand,
            // so a correct answer here doesn't remove one.
            if flagMissed {
                state.progress.flagPriority(uniqueMissed.map { $0.word })
            }
            state.progress.save()
            state.bump()
        }
        finished = true
    }

    // MARK: Results

    private var results: some View {
        let answered = correct + missed.count
        return ScrollView {
            VStack(spacing: 16) {
                Image(systemName: missed.isEmpty ? "checkmark.seal.fill" : "list.bullet.rectangle")
                    .font(.system(size: 44))
                    .foregroundStyle(missed.isEmpty ? Theme.mastered : Theme.accent)
                Text(answered > 0 ? "\(correct) / \(answered)" : "No words tested")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                if answered > 0 {
                    Text("\(Int((Double(correct) / Double(answered) * 100).rounded()))% known")
                        .foregroundStyle(.secondary)
                }

                if missed.isEmpty && answered > 0 {
                    Text("Every word landed. Nothing missed.")
                        .foregroundStyle(.secondary)
                } else if !missed.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Words you missed (\(missed.count)) — study these:")
                            .font(.headline)
                        ForEach(uniqueMissed) { w in
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(w.word).font(.callout.weight(.semibold))
                                    if w.source == .notebook {
                                        Image(systemName: "star.fill").font(.caption2).foregroundStyle(Theme.notebook)
                                    }
                                }
                                Text(w.definition).font(.callout).foregroundStyle(.secondary)
                                if !w.synonyms.isEmpty {
                                    Text(w.synonyms.joined(separator: ", "))
                                        .font(.caption).foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 3)
                            Divider()
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: 560, alignment: .leading)
                    .cardStyle()
                }

                HStack {
                    if !missed.isEmpty {
                        Button("Retest missed (\(uniqueMissed.count))") {
                            start(with: uniqueMissed)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button("Done") {
                        queue = []
                        finished = false
                        missed = []
                        correct = 0
                        index = 0
                    }
                }
            }
            .padding(40)
            .frame(maxWidth: 640)
        }
    }

    private var uniqueMissed: [VocabWord] {
        var seen = Set<String>()
        return missed.filter { seen.insert($0.word).inserted }
    }
}
