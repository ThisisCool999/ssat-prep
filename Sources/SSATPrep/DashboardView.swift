import SwiftUI
import SSATCore

struct DashboardView: View {
    @EnvironmentObject private var state: AppState
    @AppStorage("testDateSet") private var testDateSet = false
    @AppStorage("testDate") private var testDateTimestamp = Date().timeIntervalSince1970
    let navigate: (Destination) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                HStack(spacing: 12) {
                    Button { openWordList("Learned") } label: {
                        StatCard(value: "\(newWordsToday)", label: "New words today", icon: "graduationcap",
                                 tint: newWordsToday > 0 ? Theme.mastered : Theme.accent)
                    }
                    .buttonStyle(.plain)
                    StatCard(value: "\(state.dueNow)", label: "Cards due", icon: "clock",
                             tint: state.dueNow > 0 ? Theme.learning : Theme.mastered)
                    StatCard(value: "\(state.newRemainingToday)", label: "New words left", icon: "sparkles")
                    Button { openWordList("Mastered") } label: {
                        StatCard(value: "\(state.progress.streak(asOf: Date()))", label: "Day streak", icon: "flame",
                                 tint: .orange, subtitle: "\(masteredCount) words mastered")
                    }
                    .buttonStyle(.plain)
                }

                actionRow

                forecastCard

                sourcesCard
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("English skills · SSAT & SAT prep")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .textCase(.uppercase)
            Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.callout)
                .foregroundStyle(.secondary)
            if testDateSet {
                let days = Calendar.current.dateComponents(
                    [.day],
                    from: Calendar.current.startOfDay(for: Date()),
                    to: Calendar.current.startOfDay(for: Date(timeIntervalSince1970: testDateTimestamp))
                ).day ?? 0
                Text(days >= 0 ? "\(days) days until test day" : "Test day has passed — set a new date in Settings")
                    .font(.title2.weight(.semibold))
            } else {
                Text("Keep the reviews moving.")
                    .font(.title2.weight(.semibold))
            }
        }
    }

    private var masteredCount: Int {
        state.progress.phaseCounts(words: state.content.words).mastered
    }

    /// New words introduced today — the distinct words first started today
    /// (deduped, so the same word recurring through its learning steps counts
    /// once).
    private var newWordsToday: Int {
        state.progress.dayStats(for: Date()).uniqueNewWords
    }

    private func openWordList(_ filter: String) {
        state.pendingWordFilter = filter
        navigate(.wordList)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            actionButton("Start Flashcards", subtitle: dueSubtitle, icon: "rectangle.on.rectangle.angled",
                         prominent: true) { navigate(.flashcards) }
            actionButton("Synonym Quiz", subtitle: "SSAT-style, five choices", icon: "checklist") { navigate(.quiz) }
            actionButton("Analogy Drill", subtitle: "Bridges + practice", icon: "arrow.triangle.branch") { navigate(.analogies) }
        }
    }

    private var dueSubtitle: String {
        let due = state.dueNow
        let new = state.newRemainingToday
        if due == 0 && new == 0 { return "All caught up" }
        return "\(due) due · \(new) new"
    }

    private func actionButton(_ title: String, subtitle: String, icon: String,
                              prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).opacity(0.8)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(prominent ? Theme.accent : Color.primary.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(prominent ? AnyShapeStyle(.clear) : AnyShapeStyle(.separator), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var forecastCard: some View {
        let counts = state.progress.forecast(words: state.content.words, now: Date(), days: 14)
        let maxCount = max(counts.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Review forecast — next 14 days")
                .font(.headline)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(counts.enumerated()), id: \.offset) { i, c in
                    VStack(spacing: 4) {
                        Text(c > 0 ? "\(c)" : " ")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(i == 0 ? Theme.learning : Theme.accent.opacity(0.55))
                            .frame(height: max(4, CGFloat(c) / CGFloat(maxCount) * 70))
                        Text(dayLabel(offset: i))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private func dayLabel(offset: Int) -> String {
        if offset == 0 { return "today" }
        let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return date.formatted(.dateTime.day())
    }

    private var sourcesCard: some View {
        let notebook = state.content.notebookWords.count
        let supplement = state.content.supplementWords.count
        return HStack(spacing: 14) {
            Image(systemName: "book.and.wrench")
                .font(.title2)
                .foregroundStyle(Theme.notebook)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(notebook + supplement) words in your deck")
                    .font(.headline)
                Text("\(notebook) often-tested words from your class (your own mnemonics included) · \(supplement) more hard SSAT words on top")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Browse") { navigate(.wordList) }
        }
        .padding(16)
        .cardStyle()
    }
}
