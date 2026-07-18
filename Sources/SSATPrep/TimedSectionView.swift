import SwiftUI
import SSATCore

/// Full 40-minute reading-section simulation built from the user's class
/// practice sets: countdown (pausable), passage-by-passage navigation, an
/// answer strip, real SSAT scoring (+1 / −¼ / 0), then a review mode.
struct TimedSectionView: View {
    @EnvironmentObject private var state: AppState
    @State private var session: SectionSession?

    var body: some View {
        Group {
            if let session {
                if session.finished {
                    SectionResults(session: session,
                                   onReview: { session.reviewing = true },
                                   onExit: { self.session = nil })
                } else {
                    SectionRunner(session: session, onExit: { self.session = nil })
                }
            } else {
                picker
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var picker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if state.content.practiceSections.isEmpty {
                    Text("No practice sections loaded.")
                        .foregroundStyle(.secondary)
                }

                ForEach(state.content.practiceSections) { section in
                    Button {
                        session = SectionSession(section: section, progress: state.progress)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "timer")
                                .font(.title2)
                                .frame(width: 40, height: 40)
                                .background(Theme.accent.opacity(0.10), in: Circle())
                                .foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(section.name).font(.headline)
                                Text("\(section.passages.count) passages · \(section.questionCount) questions · \(section.minutes) minutes\(lastScoreSuffix(section))")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }

    private func lastScoreSuffix(_ section: PracticeSection) -> String {
        let key = "timed:" + section.name
        let saved = state.progress.passageAnswers(for: key)
        guard saved.count == section.questionCount + 1 else { return "" }
        return String(format: " · last raw score %.2f", Double(saved[0]) / 100)
    }
}

/// One run through a section. Class (not struct) so mutations inside the
/// runner update live views via ObservableObject.
final class SectionSession: ObservableObject, Identifiable {
    let section: PracticeSection
    let progress: ProgressStore
    @Published var answers: [Int?]
    @Published var passageIndex = 0
    @Published var secondsLeft: Int
    @Published var paused = false
    @Published var finished = false
    @Published var reviewing = false

    init(section: PracticeSection, progress: ProgressStore) {
        self.section = section
        self.progress = progress
        answers = Array(repeating: nil, count: section.questionCount)
        secondsLeft = section.minutes * 60
    }

    /// Global question index of the first question of a passage.
    func base(_ passageIdx: Int) -> Int {
        section.passages.prefix(passageIdx).reduce(0) { $0 + $1.questions.count }
    }

    var allQuestions: [(passage: Passage, question: PassageQuestion)] {
        section.passages.flatMap { p in p.questions.map { (p, $0) } }
    }

    var rightCount: Int {
        zip(answers, allQuestions).filter { $0 == $1.question.answerIndex }.count
    }
    var wrongCount: Int {
        zip(answers, allQuestions).filter { $0 != nil && $0 != $1.question.answerIndex }.count
    }
    var blankCount: Int { answers.filter { $0 == nil }.count }
    var rawScore: Double { Double(rightCount) - Double(wrongCount) * 0.25 }

    func tick() {
        guard !paused, !finished else { return }
        secondsLeft -= 1
        if secondsLeft <= 0 { finish() }
    }

    func finish() {
        guard !finished else { return }
        finished = true
        progress.recordQuiz(QuizResult(date: Date(), kind: "section",
                                       total: answers.count, correct: rightCount))
        // First slot stores rawScore ×100 so the picker can show it; the rest
        // are the answers (−1 = blank).
        var saved = [Int(rawScore * 100)]
        saved += answers.map { $0 ?? -1 }
        progress.setPassageAnswers(saved, for: "timed:" + section.name)
        progress.save()
    }
}

private struct SectionRunner: View {
    @ObservedObject var session: SectionSession
    @EnvironmentObject private var state: AppState
    let onExit: () -> Void
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HSplitView {
                passagePane
                questionPane
            }
            Divider()
            answerStrip
        }
        .onReceive(clock) { _ in
            session.tick()
            if session.finished { state.bump() }
        }
    }

    private var passage: Passage { session.section.passages[session.passageIndex] }

    private var toolbar: some View {
        HStack(spacing: 14) {
            Button {
                onExit()
            } label: {
                Label("Quit", systemImage: "xmark")
            }
            .help("Abandon the section — nothing is recorded")

            Spacer()

            Button(session.paused ? "Resume" : "Pause") { session.paused.toggle() }
                .controlSize(.small)

            Text(timeString)
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(session.secondsLeft <= 300 ? Theme.wrong : Color.primary)
                .frame(width: 76, alignment: .trailing)

            Button("Finish section") {
                session.finish()
                state.bump()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    private var timeString: String {
        String(format: "%d:%02d", session.secondsLeft / 60, session.secondsLeft % 60)
    }

    private var passagePane: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    session.passageIndex -= 1
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(session.passageIndex == 0)
                Spacer()
                Text("Passage \(session.passageIndex + 1) of \(session.section.passages.count)")
                    .font(.callout.weight(.semibold))
                Spacer()
                Button {
                    session.passageIndex += 1
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(session.passageIndex == session.section.passages.count - 1)
            }
            .padding(10)
            ScrollView {
                Text(passage.text)
                    .font(.system(size: 15, design: .serif))
                    .lineSpacing(6)
                    .textSelection(.enabled)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(session.passageIndex)
            }
            .background(.background.secondary)
        }
        .frame(minWidth: 340, idealWidth: 430)
        .opacity(session.paused ? 0.06 : 1)
        .overlay {
            if session.paused {
                VStack(spacing: 8) {
                    Image(systemName: "pause.circle").font(.system(size: 40))
                    Text("Paused — the clock is stopped").font(.headline)
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private var questionPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(passage.questions.enumerated()), id: \.offset) { qi, q in
                    let global = session.base(session.passageIndex) + qi
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(global + 1).")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(Theme.accent)
                            Text(q.prompt).font(.body.weight(.medium))
                        }
                        VStack(spacing: 5) {
                            ForEach(Array(q.choices.enumerated()), id: \.offset) { ci, choice in
                                ChoiceRow(text: choice,
                                          state: session.answers[global] == ci ? .correct : .idle) {
                                    // Test conditions: choices stay changeable
                                    // and unmarked until the section ends.
                                    session.answers[global] = session.answers[global] == ci ? nil : ci
                                }
                            }
                        }
                    }
                    .padding(12)
                    .cardStyle()
                }
            }
            .padding(16)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .frame(minWidth: 380)
        .opacity(session.paused ? 0.06 : 1)
        .allowsHitTesting(!session.paused)
    }

    private var answerStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(0..<session.answers.count, id: \.self) { i in
                    let answered = session.answers[i] != nil
                    Button {
                        jump(to: i)
                    } label: {
                        Text("\(i + 1)")
                            .font(.caption.monospacedDigit())
                            .frame(width: 26, height: 22)
                            .background(answered ? Theme.accent.opacity(0.85) : Color.primary.opacity(0.06),
                                        in: RoundedRectangle(cornerRadius: 5))
                            .foregroundStyle(answered ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                Text("\(session.blankCount) blank")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
        }
    }

    private func jump(to global: Int) {
        var base = 0
        for (pi, p) in session.section.passages.enumerated() {
            if global < base + p.questions.count {
                session.passageIndex = pi
                return
            }
            base += p.questions.count
        }
    }
}

private struct SectionResults: View {
    @ObservedObject var session: SectionSession
    let onReview: () -> Void
    let onExit: () -> Void

    var body: some View {
        if session.reviewing {
            SectionReview(session: session, onExit: onExit)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.accent)
                Text(String(format: "Raw score  %.2f", session.rawScore))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("\(session.rightCount) right · \(session.wrongCount) wrong (−\(String(format: "%.2f", Double(session.wrongCount) * 0.25))) · \(session.blankCount) blank")
                    .foregroundStyle(.secondary)
                Text(verdict)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
                HStack {
                    Button("Review answers") { onReview() }
                        .buttonStyle(.borderedProminent)
                    Button("Done") { onExit() }
                }
            }
            .padding(40)
        }
    }

    private var verdict: String {
        let n = session.answers.count
        let pct = Double(session.rightCount) / Double(max(1, n))
        if pct >= 0.85 { return "Strong section. Review the misses — at this level each one is a specific trap worth naming." }
        if pct >= 0.65 { return "Solid. Check whether the misses cluster by question type or by passage genre — that's your next drill." }
        return "Rough one — that happens. Review every miss with the evidence test: find the exact line that proves the right answer."
    }
}

private struct SectionReview: View {
    @ObservedObject var session: SectionSession
    let onExit: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button {
                        onExit()
                    } label: {
                        Label("Done", systemImage: "chevron.left")
                    }
                    Spacer()
                    Text(String(format: "Raw score %.2f", session.rawScore))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(session.section.passages.enumerated()), id: \.offset) { pi, passage in
                    Text("Passage \(pi + 1)")
                        .font(.title3.weight(.semibold))
                    Text(passage.text)
                        .font(.system(size: 14, design: .serif))
                        .lineSpacing(5)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 9))

                    ForEach(Array(passage.questions.enumerated()), id: \.offset) { qi, q in
                        let global = session.base(pi) + qi
                        let user = session.answers[global]
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: user == q.answerIndex ? "checkmark.circle.fill"
                                        : user == nil ? "minus.circle" : "xmark.circle.fill")
                                    .foregroundStyle(user == q.answerIndex ? Theme.mastered
                                        : user == nil ? Color.secondary : Theme.wrong)
                                Text("\(global + 1). \(q.prompt)").font(.body.weight(.medium))
                            }
                            ForEach(Array(q.choices.enumerated()), id: \.offset) { ci, choice in
                                HStack(spacing: 6) {
                                    Text(choice)
                                        .font(.callout)
                                        .foregroundStyle(ci == q.answerIndex ? Theme.mastered
                                            : ci == user ? Theme.wrong : Color.secondary)
                                    if ci == user && ci != q.answerIndex {
                                        Text("your answer").font(.caption).foregroundStyle(Theme.wrong)
                                    }
                                }
                            }
                            if !q.explanation.isEmpty {
                                Text(q.explanation)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .padding(9)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
                            }
                        }
                        .padding(12)
                        .cardStyle()
                    }
                }
            }
            .padding(22)
            .frame(maxWidth: 700, alignment: .leading)
        }
    }
}
