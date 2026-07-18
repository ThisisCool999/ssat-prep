import SwiftUI
import SSATCore

struct StatsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                deckBar

                HStack(spacing: 12) {
                    StatCard(value: "\(state.progress.streak(asOf: Date()))", label: "Day streak",
                             icon: "flame", tint: .orange)
                    StatCard(value: "\(totalReviews)", label: "Total reviews", icon: "arrow.counterclockwise")
                    StatCard(value: quizAccuracy, label: "Quiz accuracy (last 10)", icon: "target",
                             tint: Theme.mastered)
                    StatCard(value: "\(strugglingCount)", label: "Struggling words", icon: "exclamationmark.triangle",
                             tint: Theme.wrong)
                }

                activityCard

                recentQuizzes
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private var counts: (new: Int, learning: Int, young: Int, mastered: Int) {
        state.progress.phaseCounts(words: state.content.words)
    }

    private var deckBar: some View {
        let c = counts
        let total = max(1, c.new + c.learning + c.young + c.mastered)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Deck status — \(total) words")
                .font(.headline)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    segment(width: geo.size.width, count: c.mastered, total: total, color: Theme.mastered)
                    segment(width: geo.size.width, count: c.young, total: total, color: Theme.accent)
                    segment(width: geo.size.width, count: c.learning, total: total, color: Theme.learning)
                    segment(width: geo.size.width, count: c.new, total: total, color: Color.secondary.opacity(0.25))
                }
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .frame(height: 14)
            HStack(spacing: 16) {
                legend("Mastered \(c.mastered)", Theme.mastered)
                legend("Young \(c.young)", Theme.accent)
                legend("Learning \(c.learning)", Theme.learning)
                legend("Unseen \(c.new)", Color.secondary.opacity(0.4))
            }
            .font(.callout)
        }
        .padding(16)
        .cardStyle()
    }

    private func segment(width: CGFloat, count: Int, total: Int, color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: max(0, width * CGFloat(count) / CGFloat(total)))
    }

    private func legend(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).foregroundStyle(.secondary)
        }
    }

    private var totalReviews: Int {
        (0..<365).reduce(0) { acc, offset in
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { return acc }
            return acc + state.progress.dayStats(for: day).reviews
        }
    }

    private var strugglingCount: Int {
        state.content.words.filter { state.progress.card(for: $0.word).lapses >= 2 }.count
    }

    private var quizAccuracy: String {
        let recent = state.progress.quizzes.suffix(10)
        let total = recent.reduce(0) { $0 + $1.total }
        guard total > 0 else { return "—" }
        let correct = recent.reduce(0) { $0 + $1.correct }
        return "\(Int((Double(correct) / Double(total) * 100).rounded()))%"
    }

    private var activityCard: some View {
        let days = (0..<14).reversed().map { offset -> (String, DayStats) in
            let day = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let label = offset == 0 ? "today" : day.formatted(.dateTime.day())
            return (label, state.progress.dayStats(for: day))
        }
        let maxReviews = max(days.map { $0.1.reviews }.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Reviews — last 14 days")
                .font(.headline)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 4) {
                        Text(day.1.reviews > 0 ? "\(day.1.reviews)" : " ")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(day.1.reviews > 0 ? Theme.accent.opacity(0.7) : Color.secondary.opacity(0.15))
                            .frame(height: max(4, CGFloat(day.1.reviews) / CGFloat(maxReviews) * 70))
                        Text(day.0)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var recentQuizzes: some View {
        let quizzes = state.progress.quizzes.suffix(8).reversed()
        return VStack(alignment: .leading, spacing: 10) {
            Text("Recent quizzes")
                .font(.headline)
            if quizzes.isEmpty {
                Text("No quizzes yet — run a synonym quiz or analogy drill.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                    ForEach(Array(quizzes.enumerated()), id: \.offset) { _, quiz in
                        GridRow {
                            Text(quiz.date, format: .dateTime.month().day().hour().minute())
                                .foregroundStyle(.secondary)
                            Text(quiz.kind == "synonym" ? "Synonym quiz" : "Analogy drill")
                            Text("\(quiz.correct)/\(quiz.total)")
                                .monospacedDigit()
                                .foregroundStyle(quiz.correct * 5 >= quiz.total * 4 ? Theme.mastered : Color.primary)
                        }
                        .font(.callout)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
