import SwiftUI
import SSATCore

struct FlashcardsView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.panelActive) private var panelActive
    @AppStorage("newPerDay") private var newPerDay = 15
    @State private var scope: AppState.DeckScope = .all
    @State private var session: StudySession?
    @State private var flipped = false
    @State private var finishedSummary: (done: Int, again: Int)?

    private let dueRefresh = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let session, let word = session.current {
                cardScreen(session: session, word: word)
            } else if let summary = finishedSummary {
                endScreen(summary)
            } else {
                startScreen
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(dueRefresh) { _ in
            // Learning steps come due on a 1m/10m clock; refresh the idle
            // screens so due counts and disabled buttons track real time.
            if session == nil { state.bump() }
        }
    }

    private var scopeDue: Int { state.dueNow(scope: scope, excludingFlagged: true) }
    private var scopeNew: Int { state.newRemainingToday(scope: scope, excludingFlagged: true) }
    private var scopeFlaggedTotal: Int { state.priorityCount(scope: scope) }
    private var scopeFlaggedServed: Int { state.flaggedToDrill(scope: scope) }
    private var scopeTotal: Int { scopeDue + scopeNew + scopeFlaggedServed }

    // MARK: Start

    private var startScreen: some View {
        VStack(spacing: 18) {
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 42))
                .foregroundStyle(Theme.accent)
            Text("Flashcards")
                .font(.largeTitle.weight(.semibold))

            Picker("", selection: $scope) {
                ForEach(AppState.DeckScope.allCases) { s in
                    Text(s == .oftenTested ? "Often tested (\(state.content.notebookWords.count))" : "All words")
                        .tag(s)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 320)

            Text("\(scopeDue) cards due · \(scopeNew) new words available")
                .foregroundStyle(.secondary)
            if scopeFlaggedTotal > 0 {
                VStack(spacing: 3) {
                    Label(scopeFlaggedServed < scopeFlaggedTotal
                          ? "\(scopeFlaggedTotal) flagged · resuming with \(scopeFlaggedServed) not yet drilled this round"
                          : "\(scopeFlaggedTotal) flagged — up first",
                          systemImage: "flag.fill")
                        .font(.callout)
                        .foregroundStyle(Theme.wrong)
                    Text("A flag clears after 2 Goods in a row, then another success the next day.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if scope == .oftenTested {
                Label("Drilling only the words your class flags as most-tested.", systemImage: "star.fill")
                    .font(.callout)
                    .foregroundStyle(Theme.notebook)
            }
            HStack(spacing: 8) {
                Text("New words per day:")
                TextField("", value: $newPerDay, format: .number)
                    .frame(width: 56)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .onChange(of: newPerDay) { _, v in if v < 1 { newPerDay = 1 } }
                Stepper("", value: $newPerDay, in: 1...9999).labelsHidden()
            }
            .frame(width: 300)
            Button {
                let s = state.makeSession(scope: scope)
                if !s.isFinished {
                    session = s
                    flipped = false
                    finishedSummary = nil
                }
            } label: {
                Text(scopeTotal > 0 ? "Start studying" : "Nothing due — study ahead is off")
                    .font(.headline)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(scopeTotal == 0)

            Text("Grade honestly: **Again** if you blanked, **Good** if you recalled it with effort. The scheduler does the rest — words come back right before you'd forget them.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            SectionBrief(icon: "clock",
                         title: "Why this feeds the whole Verbal section",
                         detail: "Every synonym and analogy question is at heart a vocabulary question — this deck is the raw material for all 60, plus vocab-in-context in Reading.")
                .frame(maxWidth: 520)
        }
        .padding(40)
    }

    // MARK: Card

    private func cardScreen(session: StudySession, word: VocabWord) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(session.remaining) left")
                    .font(.callout.monospacedDigit())
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
                Button("Skip") {
                    session.postpone()
                    flipped = false
                    state.bump()
                }
                .controlSize(.small)
                Button("End session") {
                    finishedSummary = (session.completed, session.againCount)
                    self.session = nil
                    flipped = false
                    state.bump()
                }
                .controlSize(.small)
                .help("Stop here — everything you've answered is already saved")
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            VStack(spacing: 14) {
                Text(word.word)
                    .font(.system(size: 44, weight: .semibold, design: .serif))
                Text(word.pos)
                    .font(.callout.italic())
                    .foregroundStyle(.secondary)

                if flipped {
                    Divider().frame(width: 320)
                    backContent(word)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: 560)
            .padding(.vertical, 34)
            .padding(.horizontal, 30)
            .frame(minHeight: 300)
            .cardStyle()
            .padding(.horizontal, 40)
            .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { flipped.toggle() } }

            Spacer()

            controls(session: session)
                .padding(.bottom, 22)
        }
    }

    @ViewBuilder
    private func backContent(_ word: VocabWord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(word.definition)
                .font(.title3)
                .multilineTextAlignment(.leading)

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

            if !word.yourNote.isEmpty {
                noteBox(icon: "pencil.and.scribble", tint: Theme.notebook,
                        title: "Your note", text: word.yourNote)
            }
            if !word.mnemonic.isEmpty && word.mnemonic.lowercased() != word.yourNote.lowercased() {
                noteBox(icon: "brain", tint: Theme.learning,
                        title: "Memory hook", text: word.mnemonic)
            }
            if !word.example.isEmpty {
                Text(word.example)
                    .font(.callout.italic())
                    .foregroundStyle(.secondary)
            }
            if !word.root.isEmpty {
                Text(word.root)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func noteBox(icon: String, tint: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(tint)
                Text(text).font(.callout)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: Controls

    @ViewBuilder
    private func controls(session: StudySession) -> some View {
        if !flipped {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { flipped = true }
            } label: {
                Text("Show answer")
                    .font(.headline)
                    .frame(width: 220)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcutIf(panelActive, .space)
        } else {
            HStack(spacing: 10) {
                gradeButton(session: session, grade: .again, label: "Again", key: "1", tint: Theme.wrong)
                gradeButton(session: session, grade: .hard, label: "Hard", key: "2", tint: Theme.learning)
                gradeButton(session: session, grade: .good, label: "Good", key: "3", tint: Theme.accent)
                gradeButton(session: session, grade: .easy, label: "Easy", key: "4", tint: Theme.mastered)
            }
        }
    }

    private func gradeButton(session: StudySession, grade: Grade, label: String,
                             key: Character, tint: Color) -> some View {
        let preview: String = {
            guard let word = session.current else { return "—" }
            return SM2.intervalPreview(state.progress.card(for: word.word), grade: grade, now: Date())
        }()
        return Button {
            answer(session: session, grade: grade)
        } label: {
            VStack(spacing: 2) {
                Text(label).font(.headline)
                Text(preview).font(.caption).opacity(0.75)
            }
            .frame(width: 96)
            .padding(.vertical, 7)
            .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(tint.opacity(0.5), lineWidth: 1))
            .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
        .keyboardShortcutIf(panelActive, KeyEquivalent(key))
        .help("\(label) — press \(String(key))")
    }

    private func answer(session: StudySession, grade: Grade) {
        session.answer(grade)
        flipped = false
        state.bump()
        if session.isFinished {
            finishedSummary = (session.completed, session.againCount)
            self.session = nil
        }
    }

    // MARK: End

    private func endScreen(_ summary: (done: Int, again: Int)) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44))
                .foregroundStyle(Theme.mastered)
            Text("Session complete")
                .font(.largeTitle.weight(.semibold))
            Text("\(summary.done) answers · \(summary.again) lapses")
                .foregroundStyle(.secondary)
            HStack {
                Button("Study more") {
                    let s = state.makeSession(scope: scope)
                    if !s.isFinished {
                        session = s
                        flipped = false
                        finishedSummary = nil
                    }
                }
                .disabled(scopeTotal == 0)
                Button("Done") { finishedSummary = nil }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
    }
}
