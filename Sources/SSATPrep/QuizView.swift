import SwiftUI
import SSATCore

struct QuizView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.panelActive) private var panelActive
    @State private var questions: [SynonymQuestion] = []
    @State private var index = 0
    @State private var picked: Int?
    @State private var correctCount = 0
    @State private var missed: [VocabWord] = []
    @State private var showResults = false
    @State private var length = 10
    @State private var mode: Mode = .normal

    enum Mode: String, CaseIterable, Identifiable {
        case normal = "Normal"
        case practiceTest = "Practice test"
        var id: String { rawValue }
    }

    var body: some View {
        Group {
            if showResults {
                results
            } else if questions.isEmpty {
                startScreen
            } else {
                questionScreen
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var startScreen: some View {
        VStack(spacing: 18) {
            Image(systemName: "checklist")
                .font(.system(size: 42))
                .foregroundStyle(Theme.accent)
            Text("Synonym Quiz")
                .font(.largeTitle.weight(.semibold))
            SectionBrief(icon: "clock",
                         title: "On the real test",
                         detail: "Synonyms are questions 1–30 of the Verbal section: 60 questions in 30 minutes, so about 25 seconds each. A word in capitals, five choices, closest meaning wins. +1 right, −¼ wrong, 0 blank.")
                .frame(maxWidth: 520)
            Text("Misses get pushed back into your review queue.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Picker("", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 320)
            Text(mode == .practiceTest
                 ? "Drills the often-tested words from your class list — the ones you miss come up again and again."
                 : "Draws from your whole deck, each word once.")
                .font(.callout)
                .foregroundStyle(mode == .practiceTest ? Theme.notebook : .secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)

            Picker("Length", selection: $length) {
                Text("10 questions").tag(10)
                Text("20 questions").tag(20)
                Text("30 questions — full section length").tag(30)
            }
            .pickerStyle(.radioGroup)
            Button {
                start()
            } label: {
                Text("Start quiz")
                    .font(.headline)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }

    private func start() {
        var rng = SystemRandomNumberGenerator()
        switch mode {
        case .normal:
            questions = QuizEngine.makeQuestions(from: state.content.words, count: length, using: &rng)
        case .practiceTest:
            // Draw targets only from often-tested words, sampled *with* weighted
            // replacement so the ones you struggle with recur through the set.
            let often = state.content.notebookWords.filter { !$0.synonyms.isEmpty }
            let targets = weightedTargets(from: often, count: length, using: &rng)
            questions = QuizEngine.makeQuestions(targets: targets,
                                                 distractorPool: state.content.words, using: &rng)
        }
        index = 0
        picked = nil
        correctCount = 0
        missed = []
        showResults = false
    }

    /// Samples `count` target words (with replacement) from the often-tested
    /// pool, weighting the ones you struggle with so they recur — without
    /// placing the same word back-to-back.
    private func weightedTargets(from pool: [VocabWord], count: Int,
                                 using rng: inout some RandomNumberGenerator) -> [VocabWord] {
        guard !pool.isEmpty else { return [] }
        let weighted: [(word: VocabWord, weight: Double)] = pool.map { w in
            let c = state.progress.card(for: w.word)
            var wt = 1.0
            wt += Double(c.lapses) * 2
            if let acc = c.accuracy, acc < 0.8 { wt += 2 }
            if c.phase == .new || c.phase == .learning || c.phase == .relearning { wt += 1 }
            return (w, wt)
        }
        let total = weighted.reduce(0) { $0 + $1.weight }
        var result: [VocabWord] = []
        var last: String?
        var guardCount = 0
        while result.count < count && guardCount < count * 30 {
            guardCount += 1
            var r = Double.random(in: 0..<total, using: &rng)
            var pick = weighted[0].word
            for entry in weighted {
                if r < entry.weight { pick = entry.word; break }
                r -= entry.weight
            }
            if pick.word == last && pool.count > 1 { continue }
            result.append(pick)
            last = pick.word
        }
        return result
    }

    private var uniqueMissed: [VocabWord] {
        var seen = Set<String>()
        return missed.filter { seen.insert($0.word).inserted }
    }

    private var questionScreen: some View {
        let q = questions[index]
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Question \(index + 1) of \(questions.count)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button("Quit quiz") {
                    questions = []
                    picked = nil
                    showResults = false
                }
                .controlSize(.small)
                .help("Abandon this quiz — nothing is recorded")
                Spacer()
                Text("\(correctCount) correct")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(Theme.mastered)
            }
            .padding(.horizontal, 30)
            .padding(.top, 16)

            ProgressView(value: Double(index), total: Double(questions.count))
                .padding(.horizontal, 30)
                .padding(.top, 6)

            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                Text(q.word.word.uppercased())
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                    .frame(maxWidth: .infinity, alignment: .center)

                VStack(spacing: 8) {
                    ForEach(Array(q.choices.enumerated()), id: \.offset) { i, choice in
                        ChoiceRow(text: "\(letter(i)) \(choice)", state: choiceState(i, q: q)) {
                            guard picked == nil else { return }
                            picked = i
                            if i == q.answerIndex {
                                correctCount += 1
                            } else {
                                missed.append(q.word)
                            }
                        }
                    }
                }

                if let picked {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(picked == q.answerIndex ? "Correct." : "Not quite — the answer is \(letter(q.answerIndex)) \(q.choices[q.answerIndex]).")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(picked == q.answerIndex ? Theme.mastered : Theme.wrong)
                        Text("\(q.word.word) (\(q.word.pos)): \(q.word.definition)")
                            .font(.callout)
                        if !q.word.mnemonic.isEmpty {
                            Text(q.word.mnemonic)
                                .font(.callout.italic())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))

                    Button(index + 1 < questions.count ? "Next" : "See results") {
                        advance()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcutIf(panelActive, .return)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: 620)
            .padding(30)
            .cardStyle()
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity)

            Spacer()
        }
    }

    private func letter(_ i: Int) -> String {
        ["A)", "B)", "C)", "D)", "E)"][i]
    }

    private func choiceState(_ i: Int, q: SynonymQuestion) -> ChoiceRow.ChoiceState {
        guard let picked else { return .idle }
        if i == q.answerIndex { return .correct }
        if i == picked { return .incorrect }
        return .dimmed
    }

    private func advance() {
        picked = nil
        if index + 1 < questions.count {
            index += 1
        } else {
            state.progress.recordQuiz(QuizResult(date: Date(), kind: "synonym",
                                                 total: questions.count, correct: correctCount))
            for word in missed {
                var card = state.progress.card(for: word.word)
                if card.phase != .new {
                    card.due = Date()
                    state.progress.setCard(card, for: word.word)
                }
            }
            state.progress.save()
            state.bump()
            showResults = true
        }
    }

    private var results: some View {
        VStack(spacing: 16) {
            Image(systemName: correctCount * 5 >= questions.count * 4 ? "star.circle" : "flag.checkered")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            Text("\(correctCount) / \(questions.count)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
            if missed.isEmpty {
                Text("Perfect set. These words are landing.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Missed words — now due for review:")
                        .font(.headline)
                    // Dedupe: practice-test mode can miss the same word twice.
                    ForEach(uniqueMissed) { w in
                        HStack(alignment: .firstTextBaseline) {
                            Text(w.word).font(.callout.weight(.semibold))
                            Text(w.definition).font(.callout).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: 480, alignment: .leading)
                .cardStyle()
            }
            HStack {
                Button("Another round") { start() }
                Button("Done") { questions = []; showResults = false }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
    }
}
