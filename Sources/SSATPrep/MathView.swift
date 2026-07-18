import SwiftUI
import SSATCore

struct MathView: View {
    @EnvironmentObject private var state: AppState
    @State private var selectedTopic: MathTopic?

    var body: some View {
        if state.content.mathStrands.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
                Text("No math content loaded.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HSplitView {
                List(selection: $selectedTopic) {
                    ForEach(state.content.mathStrands) { strand in
                        Section {
                            ForEach(strand.topics) { topic in
                                Text(topic.title)
                                    .padding(.vertical, 2)
                                    .tag(topic)
                            }
                        } header: {
                            Text(strand.strand)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
                .listStyle(.inset)
                .background(Color(nsColor: .textBackgroundColor))
                .frame(minWidth: 230, idealWidth: 280, maxWidth: 340)

                Group {
                    if let topic = selectedTopic {
                        TopicDetail(topic: topic)
                            .id(topic.id)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "function")
                                .font(.system(size: 36))
                                .foregroundStyle(.tertiary)
                            SectionBrief(icon: "clock",
                                         title: "On the real test",
                                         detail: "Math is TWO scored sections — Quantitative 1 and Quantitative 2 — each 25 questions in 30 minutes (about 70 seconds per question). No calculator, choices A–E, −¼ per wrong answer. These 50 topics cover everything the two sections test.")
                                .frame(maxWidth: 460)
                            Text("Pick a topic to see the facts, formulas, worked examples, and traps.")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(minWidth: 400, maxWidth: .infinity)
            }
        }
    }
}

private struct TopicDetail: View {
    let topic: MathTopic
    @State private var revealedSolutions: Set<Int> = []
    @State private var pickedChoices: [Int: Int] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(topic.title)
                    .font(.title.weight(.semibold))

                if !topic.keyPoints.isEmpty {
                    box(title: "Know cold", icon: "bolt") {
                        ForEach(topic.keyPoints, id: \.self) { point in
                            bullet(point)
                        }
                    }
                }

                if !topic.formulas.isEmpty {
                    box(title: "Formulas", icon: "x.squareroot") {
                        ForEach(topic.formulas, id: \.self) { formula in
                            Text(formula)
                                .font(.system(size: 14, design: .monospaced))
                                .padding(.vertical, 1)
                        }
                    }
                }

                if !topic.examples.isEmpty {
                    box(title: "Worked examples", icon: "pencil.line") {
                        ForEach(Array(topic.examples.enumerated()), id: \.offset) { _, ex in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(ex.problem).font(.callout.weight(.medium))
                                Text(ex.solution)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(2)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }

                if !topic.traps.isEmpty {
                    box(title: "Traps", icon: "exclamationmark.triangle", tint: Theme.wrong) {
                        ForEach(topic.traps, id: \.self) { trap in
                            bullet(trap, tint: Theme.wrong)
                        }
                    }
                }

                if !topic.practice.isEmpty {
                    Text("Practice")
                        .font(.title3.weight(.semibold))
                    ForEach(Array(topic.practice.enumerated()), id: \.offset) { pi, prob in
                        practiceCard(pi: pi, prob: prob)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }

    private func bullet(_ text: String, tint: Color = Theme.accent) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•").foregroundStyle(tint)
            Text(text).font(.callout).lineSpacing(2)
        }
        .padding(.vertical, 1)
    }

    private func box<Content: View>(title: String, icon: String, tint: Color = Theme.accent,
                                    @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(tint)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func practiceCard(pi: Int, prob: PracticeProblem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(pi + 1).")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.accent)
                Text(prob.problem).font(.callout.weight(.medium))
            }
            if !prob.choices.isEmpty {
                VStack(spacing: 6) {
                    ForEach(Array(prob.choices.enumerated()), id: \.offset) { ci, choice in
                        ChoiceRow(text: choice, state: practiceChoiceState(pi: pi, ci: ci, prob: prob)) {
                            guard pickedChoices[pi] == nil else { return }
                            pickedChoices[pi] = ci
                            revealedSolutions.insert(pi)
                        }
                    }
                }
            } else {
                Button(revealedSolutions.contains(pi) ? "Solution:" : "Show solution") {
                    revealedSolutions.insert(pi)
                }
                .controlSize(.small)
            }
            if revealedSolutions.contains(pi) {
                Text(prob.solution)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .cardStyle()
    }

    private func practiceChoiceState(pi: Int, ci: Int, prob: PracticeProblem) -> ChoiceRow.ChoiceState {
        guard let picked = pickedChoices[pi] else { return .idle }
        guard let answer = prob.answerIndex else { return picked == ci ? .incorrect : .dimmed }
        if ci == answer { return .correct }
        if ci == picked { return .incorrect }
        return .dimmed
    }
}
