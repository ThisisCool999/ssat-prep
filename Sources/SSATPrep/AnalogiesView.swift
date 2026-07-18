import SwiftUI
import SSATCore

struct AnalogiesView: View {
    @EnvironmentObject private var state: AppState
    @State private var tab: Tab = .learn

    enum Tab: String, CaseIterable {
        case learn = "Bridges & Method"
        case practice = "Practice"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 340)
            .padding(.vertical, 12)

            Divider()

            switch tab {
            case .learn: BridgeGuide(module: state.content.analogies)
            case .practice: AnalogyPractice(questions: state.content.analogies.practice)
            }
        }
    }
}

private struct BridgeGuide: View {
    let module: AnalogyModule

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionBrief(icon: "clock",
                             title: "On the real test",
                             detail: "Analogies are questions 31–60 of the Verbal section (60 questions, 30 minutes total — about 25 seconds each). Stem pair, five choice pairs, −¼ per wrong answer.")
                    .frame(maxWidth: 640)
                Text("Every SSAT analogy hides one of about a dozen relationships. Name the bridge with a precise sentence, then test that sentence on the choices.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 640, alignment: .leading)

                ForEach(Array(module.howTo.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(i + 1)")
                            .font(.headline.monospacedDigit())
                            .frame(width: 26, height: 26)
                            .background(Theme.accent.opacity(0.12), in: Circle())
                            .foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.heading).font(.headline)
                            Text(step.body).font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: 640, alignment: .leading)
                }

                Text("The bridge catalog")
                    .font(.title3.weight(.semibold))
                    .padding(.top, 6)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 290), spacing: 12)],
                          alignment: .leading, spacing: 12) {
                    ForEach(module.bridges) { bridge in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(bridge.name).font(.headline)
                            Text(bridge.pattern)
                                .font(.callout.italic())
                                .foregroundStyle(Theme.accent)
                            Text(bridge.example).font(.callout)
                            Text(bridge.tip)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
                        .cardStyle()
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 960, alignment: .leading)
        }
    }
}

private struct AnalogyPractice: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.panelActive) private var panelActive
    let questions: [AnalogyQuestion]
    @State private var order: [Int] = []
    @State private var index = 0
    @State private var picked: Int?
    @State private var correctCount = 0
    @State private var finished = false
    @State private var count = 20

    private let countChoices = [10, 20, 30, 50, 0]   // 0 = the whole bank

    private var sampleSize: Int { count == 0 ? questions.count : min(count, questions.count) }

    /// Draw a fresh random subset of the bank so each drill is different.
    private func begin() {
        order = Array(Array(0..<questions.count).shuffled().prefix(sampleSize))
        index = 0
        picked = nil
        correctCount = 0
        finished = false
    }

    var body: some View {
        Group {
            if questions.isEmpty {
                Text("No practice questions loaded.")
                    .foregroundStyle(.secondary)
            } else if finished {
                results
            } else if order.isEmpty {
                startScreen
            } else {
                questionScreen
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var startScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent)
            Text("\(questions.count) analogies in the bank")
                .font(.title3.weight(.semibold))
            Text("Every drill pulls a fresh random set, so you rarely repeat questions. Each stem is built on a word you're studying.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 470)

            VStack(alignment: .leading, spacing: 6) {
                Text("How many questions").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Picker("", selection: $count) {
                    ForEach(countChoices, id: \.self) { n in
                        Text(n == 0 ? "All (\(questions.count))" : "\(n)").tag(n)
                    }
                }
                .pickerStyle(.segmented)
            }
            .frame(width: 430)

            Text("Make your bridge sentence *before* looking at the choices.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Start \(sampleSize) questions") { begin() }
                .buttonStyle(.borderedProminent)
                .disabled(questions.isEmpty)
        }
        .padding(40)
    }

    private var questionScreen: some View {
        let q = questions[order[index]]
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(index + 1) of \(order.count)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button("Quit drill") {
                    order = []
                    picked = nil
                    finished = false
                }
                .controlSize(.small)
                .help("Abandon this drill — nothing is recorded")
                Spacer()
                Text("\(correctCount) correct")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(Theme.mastered)
            }
            .padding(.horizontal, 30)
            .padding(.top, 16)

            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                Text(q.stem)
                    .font(.system(size: 24, weight: .medium, design: .serif))
                VStack(spacing: 8) {
                    ForEach(Array(q.choices.enumerated()), id: \.offset) { i, choice in
                        ChoiceRow(text: choice, state: choiceState(i, q: q)) {
                            guard picked == nil else { return }
                            picked = i
                            if i == q.answerIndex { correctCount += 1 }
                        }
                    }
                }
                if let picked {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(picked == q.answerIndex ? "Correct" : "Answer: \(q.choices[q.answerIndex])")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(picked == q.answerIndex ? Theme.mastered : Theme.wrong)
                            Text("· bridge: \(q.bridge)")
                                .font(.callout)
                                .foregroundStyle(Theme.accent)
                        }
                        Text(q.explanation).font(.callout).foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))

                    Button(index + 1 < order.count ? "Next" : "Finish") {
                        self.picked = nil
                        if index + 1 < order.count {
                            index += 1
                        } else {
                            state.progress.recordQuiz(QuizResult(date: Date(), kind: "analogy",
                                                                 total: order.count, correct: correctCount))
                            state.progress.save()
                            state.bump()
                            finished = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcutIf(panelActive, .return)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: 620)
            .padding(28)
            .cardStyle()
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity)

            Spacer()
        }
    }

    private func choiceState(_ i: Int, q: AnalogyQuestion) -> ChoiceRow.ChoiceState {
        guard let picked else { return .idle }
        if i == q.answerIndex { return .correct }
        if i == picked { return .incorrect }
        return .dimmed
    }

    private var results: some View {
        VStack(spacing: 14) {
            Text("\(correctCount) / \(order.count)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text(correctCount * 4 >= order.count * 3 ? "Strong. Bridges are clicking." : "Review the bridge catalog, then run it again.")
                .foregroundStyle(.secondary)
            HStack {
                Button("New set") { begin() }
                Button("Done") {
                    order = []
                    finished = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
    }
}
