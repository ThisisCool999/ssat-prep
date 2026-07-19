import SwiftUI
import SSATCore

struct BrowseView: View {
    @EnvironmentObject private var state: AppState
    @State private var search = ""
    @State private var filter: Filter = .all
    @State private var selected: VocabWord?

    enum Filter: String, CaseIterable {
        case all = "All"
        case flagged = "Flagged"
        case learned = "Learned"
        case notebook = "Often tested"
        case supplement = "Added"
        case struggling = "Struggling"
        case mastered = "Mastered"
    }

    private var filtered: [VocabWord] {
        let base: [VocabWord]
        switch filter {
        case .all: base = state.content.words
        case .flagged:
            let f = Set(state.progress.priorityWords)
            base = state.content.words.filter { f.contains($0.word) }
        case .learned:
            // Any word you've started studying (past the "new" stage).
            base = state.content.words.filter { state.progress.card(for: $0.word).phase != .new }
        case .notebook: base = state.content.notebookWords
        case .supplement: base = state.content.supplementWords
        case .struggling:
            base = state.content.words.filter { state.progress.card(for: $0.word).lapses >= 2 }
        case .mastered:
            base = state.content.words.filter { state.progress.card(for: $0.word).isMastered }
        }
        let sorted = base.sorted { $0.word < $1.word }
        guard !search.isEmpty else { return sorted }
        let q = search.lowercased()
        return sorted.filter {
            $0.word.lowercased().contains(q)
                || $0.definition.lowercased().contains(q)
                || $0.synonyms.contains { s in s.lowercased().contains(q) }
        }
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                deepLinkHandler
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Word, meaning, synonym…", text: $search)
                            .textFieldStyle(.plain)
                        if !search.isEmpty {
                            Button {
                                search = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))

                    Picker("", selection: $filter) {
                        ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }
                .padding(10)

                List(filtered, id: \.self, selection: $selected) { word in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(word.word).font(.body.weight(.medium))
                            Text(word.definition)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if let acc = state.progress.card(for: word.word).accuracy {
                            Text("\(Int((acc * 100).rounded()))%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(accuracyColor(acc))
                        }
                        phaseDot(word)
                    }
                    .padding(.vertical, 2)
                    .tag(word)
                }
                .listStyle(.inset)

                Divider()
                Text("\(filtered.count) words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .frame(minWidth: 260, idealWidth: 340, maxWidth: 480)
            .background(Color(nsColor: .textBackgroundColor))

            detail
                .frame(minWidth: 340, maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Applies a filter requested from another screen (e.g. tapping the
    /// "Reviewed today" card jumps here with that filter preselected).
    private var deepLinkHandler: some View {
        Color.clear.frame(height: 0)
            .onChange(of: state.pendingWordFilter) { _, req in applyPending(req) }
            .onAppear { applyPending(state.pendingWordFilter) }
    }

    private func applyPending(_ req: String?) {
        guard let req, let f = Filter(rawValue: req) else { return }
        filter = f
        selected = nil
        state.pendingWordFilter = nil
    }

    private func accuracyColor(_ acc: Double) -> Color {
        if acc >= 0.85 { return Theme.mastered }
        if acc >= 0.6 { return Theme.learning }
        return Theme.wrong
    }

    private func phaseDot(_ word: VocabWord) -> some View {
        let card = state.progress.card(for: word.word)
        let (color, label): (Color, String) = {
            switch card.phase {
            case .new: return (.secondary.opacity(0.4), "new")
            case .learning, .relearning: return (Theme.learning, "learning")
            case .review: return card.isMastered ? (Theme.mastered, "mastered") : (Theme.accent, "young")
            }
        }()
        return Circle().fill(color).frame(width: 8, height: 8).help(label)
    }

    @ViewBuilder
    private var detail: some View {
        if let word = selected {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(word.word)
                            .font(.system(size: 34, weight: .semibold, design: .serif))
                        Text(word.pos)
                            .font(.callout.italic())
                            .foregroundStyle(.secondary)
                        Spacer()
                        if word.source == .notebook {
                            Label("Often tested", systemImage: "star.fill")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.notebook.opacity(0.14), in: Capsule())
                                .foregroundStyle(Theme.notebook)
                        }
                        Text(String(repeating: "◆", count: max(1, min(3, word.difficulty))))
                            .font(.caption)
                            .foregroundStyle(Theme.learning)
                            .help("Difficulty \(word.difficulty) of 3")
                    }

                    Text(word.definition).font(.title3)

                    if !word.synonyms.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(word.synonyms, id: \.self) { syn in
                                Text(syn)
                                    .font(.callout)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Theme.accent.opacity(0.10), in: Capsule())
                            }
                        }
                    }

                    if !word.mnemonic.isEmpty {
                        labeledBox("Mnemonic", word.mnemonic, tint: Theme.learning)
                    }
                    if !word.example.isEmpty {
                        Text(word.example).font(.callout.italic()).foregroundStyle(.secondary)
                    }
                    if !word.root.isEmpty {
                        Text(word.root).font(.caption).foregroundStyle(.tertiary)
                    }

                    Divider()

                    srsInfo(word)
                }
                .padding(24)
                .frame(maxWidth: 640, alignment: .leading)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "text.book.closed")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
                Text("Select a word")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func labeledBox(_ title: String, _ text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(tint).textCase(.uppercase)
            Text(text).font(.callout)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    private func srsInfo(_ word: VocabWord) -> some View {
        let card = state.progress.card(for: word.word)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Study record").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 4) {
                GridRow {
                    Text("Status").foregroundStyle(.secondary)
                    Text(statusLabel(card))
                }
                GridRow {
                    Text("Reviews").foregroundStyle(.secondary)
                    Text("\(card.reps)")
                }
                GridRow {
                    Text("Accuracy").foregroundStyle(.secondary)
                    if let acc = card.accuracy {
                        Text("\(Int((acc * 100).rounded()))%  ·  \(card.reps - card.agains)/\(card.reps) correct")
                            .foregroundStyle(accuracyColor(acc))
                    } else {
                        Text("—").foregroundStyle(.tertiary)
                    }
                }
                GridRow {
                    Text("Lapses").foregroundStyle(.secondary)
                    Text("\(card.lapses)")
                }
                if let due = card.due {
                    GridRow {
                        Text("Next review").foregroundStyle(.secondary)
                        Text(due, format: .dateTime.month().day().hour().minute())
                    }
                }
            }
            .font(.callout)
            HStack {
                let isFlagged = state.progress.priorityWords.contains(word.word)
                Button {
                    if isFlagged { state.progress.clearPriority(word.word) }
                    else { state.progress.flagPriority([word.word]) }
                    state.progress.save()
                    state.bump()
                } label: {
                    Label(isFlagged ? "Unflag" : "Flag for test",
                          systemImage: isFlagged ? "flag.slash" : "flag")
                }
                .controlSize(.small)
                Button("Reset this word") {
                    state.progress.resetCard(for: word.word)
                    state.progress.save()
                    state.bump()
                }
                .controlSize(.small)
            }
            .padding(.top, 4)
        }
    }

    private func statusLabel(_ card: CardState) -> String {
        switch card.phase {
        case .new: return "New — not studied yet"
        case .learning: return "Learning"
        case .relearning: return "Relearning after a lapse"
        case .review: return card.isMastered ? "Mastered (interval \(Int(card.intervalDays))d)" : "Young (interval \(Int(card.intervalDays))d)"
        }
    }
}
