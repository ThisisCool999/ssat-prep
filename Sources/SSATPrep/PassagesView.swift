import SwiftUI
import SSATCore

struct PassagesView: View {
    @EnvironmentObject private var state: AppState
    @State private var selected: Passage?

    var body: some View {
        if let passage = selected {
            PassageRunner(passage: passage, onExit: { selected = nil })
                .id(passage.id)
        } else {
            picker
        }
    }

    private struct BookGroup: Identifiable {
        let id: String
        let passages: [Passage]
    }

    /// Book title + part number parsed from a retelling's attribution, or nil for
    /// the standalone passages.
    private func bookInfo(_ p: Passage) -> (book: String, part: Int)? {
        let attr = p.attribution
        let prefix = "Retelling of "
        guard attr.hasPrefix(prefix), let byRange = attr.range(of: " by ") else { return nil }
        let start = attr.index(attr.startIndex, offsetBy: prefix.count)
        let book = String(attr[start..<byRange.lowerBound])
        var part = 0
        if let pr = attr.range(of: "Part ") {
            part = Int(attr[pr.upperBound...].prefix { $0.isNumber }) ?? 0
        }
        return (book, part)
    }

    private var bookGroups: [BookGroup] {
        var map: [String: [(Int, Passage)]] = [:]
        for p in state.content.passages {
            if let info = bookInfo(p) { map[info.book, default: []].append((info.part, p)) }
        }
        return map.keys.sorted().map { book in
            BookGroup(id: book, passages: map[book]!.sorted { $0.0 < $1.0 }.map(\.1))
        }
    }

    private var otherPassages: [Passage] {
        state.content.passages.filter { bookInfo($0) == nil }
    }

    private var picker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionBrief(icon: "clock",
                             title: "On the real test",
                             detail: "Reading is 40 questions in 40 minutes across 7–8 passages (~250–400 words each) — roughly 5 minutes per passage including its questions. −¼ per wrong answer, so skip a passage rather than rush all of them.")

                Text("Work a book straight through its four parts to lock in the plot, or drill the standalone passages below. Every passage opens with a note on what's happening and explains each answer.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if !bookGroups.isEmpty {
                    Text("The books — read each in four parts")
                        .font(.title3.weight(.semibold))
                        .padding(.top, 4)
                    ForEach(bookGroups) { group in
                        DisclosureGroup {
                            VStack(spacing: 10) {
                                ForEach(group.passages) { passageRow($0) }
                            }
                            .padding(.top, 8)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "books.vertical")
                                    .font(.title3)
                                    .frame(width: 34, height: 34)
                                    .background(Theme.notebook.opacity(0.12), in: Circle())
                                    .foregroundStyle(Theme.notebook)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(group.id).font(.headline)
                                    Text("\(group.passages.count) parts · \(bookProgress(group))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(14)
                        .cardStyle()
                    }
                }

                if !otherPassages.isEmpty {
                    Text("Standalone passages")
                        .font(.title3.weight(.semibold))
                        .padding(.top, 10)
                    ForEach(otherPassages) { passageRow($0) }
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }

    private func bookProgress(_ group: BookGroup) -> String {
        let done = group.passages.filter { p in
            let a = state.progress.passageAnswers(for: p.title)
            return a.count == p.questions.count && !a.isEmpty
        }.count
        return done == 0 ? "not started" : "\(done)/\(group.passages.count) done"
    }

    private func passageRow(_ passage: Passage) -> some View {
        Button {
            selected = passage
        } label: {
            HStack(spacing: 14) {
                Image(systemName: genreIcon(passage.genre))
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(Theme.accent.opacity(0.10), in: Circle())
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(passage.title).font(.headline)
                    Text("\(passage.genre.capitalized) · \(passage.questions.count) questions\(scoreSuffix(passage))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    if !passage.attribution.isEmpty {
                        Text(passage.attribution)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
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

    private func scoreSuffix(_ passage: Passage) -> String {
        let answers = state.progress.passageAnswers(for: passage.title)
        guard answers.count == passage.questions.count, !answers.isEmpty else { return "" }
        let correct = zip(answers, passage.questions).filter { $0 == $1.answerIndex }.count
        return " · last score \(correct)/\(passage.questions.count)"
    }

    private func genreIcon(_ genre: String) -> String {
        switch genre.lowercased() {
        case "fiction": return "theatermasks"
        case "science": return "atom"
        case "humanities": return "building.columns"
        case "poetry": return "text.quote"
        case "essay": return "text.alignleft"
        case "memoir": return "leaf"
        default: return "doc.text"
        }
    }
}

private struct PassageRunner: View {
    @EnvironmentObject private var state: AppState
    let passage: Passage
    let onExit: () -> Void
    @State private var answers: [Int?]

    init(passage: Passage, onExit: @escaping () -> Void) {
        self.passage = passage
        self.onExit = onExit
        _answers = State(initialValue: Array(repeating: nil, count: passage.questions.count))
    }

    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(passage.title)
                        .font(.title2.weight(.semibold))
                    if !passage.attribution.isEmpty {
                        Text(passage.attribution)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    if !passage.context.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(Theme.accent)
                            Text(passage.context)
                                .font(.callout.italic())
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                    }
                    Text(passage.text)
                        .font(.system(size: 15, design: .serif))
                        .lineSpacing(passage.genre.lowercased() == "poetry" ? 4 : 6)
                        .textSelection(.enabled)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 360, idealWidth: 440)
            .background(.background.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Button {
                            onExit()
                        } label: {
                            Label("All passages", systemImage: "chevron.left")
                        }
                        Spacer()
                        Text(scoreLine)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    ForEach(Array(passage.questions.enumerated()), id: \.offset) { qi, q in
                        questionCard(qi: qi, q: q)
                    }
                }
                .padding(22)
                .frame(maxWidth: 560, alignment: .leading)
            }
            .frame(minWidth: 400)
        }
    }

    private var scoreLine: String {
        let done = answers.compactMap { $0 }.count
        guard done > 0 else { return "\(passage.questions.count) questions" }
        let correct = zip(answers, passage.questions).filter { $0 == $1.answerIndex }.count
        return "\(correct) correct of \(done) answered"
    }

    private func questionCard(qi: Int, q: PassageQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(qi + 1).")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.accent)
                Text(q.prompt).font(.body.weight(.medium))
            }
            VStack(spacing: 6) {
                ForEach(Array(q.choices.enumerated()), id: \.offset) { ci, choice in
                    ChoiceRow(text: choice, state: choiceState(qi: qi, ci: ci, q: q)) {
                        guard answers[qi] == nil else { return }
                        answers[qi] = ci
                        persist()
                    }
                }
            }
            if let picked = answers[qi] {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(picked == q.answerIndex ? "Correct" : "Answer: \(letter(q.answerIndex))")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(picked == q.answerIndex ? Theme.mastered : Theme.wrong)
                        if !q.type.isEmpty {
                            Text("· \(q.type)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.accent.opacity(0.10), in: Capsule())
                        }
                    }
                    Text(q.explanation).font(.callout).foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .cardStyle()
    }

    private func letter(_ i: Int) -> String {
        ["A", "B", "C", "D", "E"][min(max(i, 0), 4)]
    }

    private func choiceState(qi: Int, ci: Int, q: PassageQuestion) -> ChoiceRow.ChoiceState {
        guard let picked = answers[qi] else { return .idle }
        if ci == q.answerIndex { return .correct }
        if ci == picked { return .incorrect }
        return .dimmed
    }

    private func persist() {
        guard answers.allSatisfy({ $0 != nil }) else { return }
        state.progress.setPassageAnswers(answers.compactMap { $0 }, for: passage.title)
        state.progress.save()
        state.bump()
    }
}
