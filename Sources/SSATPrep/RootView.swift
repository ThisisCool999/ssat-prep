import SwiftUI
import SSATCore

enum Destination: String, Hashable, CaseIterable {
    case today
    case flashcards
    case quiz
    case analogies
    case wordTest
    case timedSections
    case wordList
    case readingGuide
    case passages
    case books
    case math
    case strategy
    case progress

    var label: String {
        switch self {
        case .today: return "Today"
        case .flashcards: return "Flashcards"
        case .quiz: return "Synonym Quiz"
        case .analogies: return "Analogies"
        case .wordTest: return "Word Test"
        case .timedSections: return "Timed Sections"
        case .wordList: return "Word List"
        case .readingGuide: return "Reading Guide"
        case .passages: return "Practice Passages"
        case .books: return "Book Overviews"
        case .math: return "Math Review"
        case .strategy: return "Test Strategy"
        case .progress: return "Progress"
        }
    }

    var icon: String {
        switch self {
        case .today: return "sun.max"
        case .flashcards: return "rectangle.on.rectangle.angled"
        case .quiz: return "checklist"
        case .analogies: return "arrow.triangle.branch"
        case .wordTest: return "checklist.checked"
        case .timedSections: return "timer"
        case .wordList: return "text.book.closed"
        case .readingGuide: return "book"
        case .passages: return "doc.text"
        case .books: return "books.vertical"
        case .math: return "function"
        case .strategy: return "map"
        case .progress: return "chart.bar.xaxis"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var state: AppState
    @State private var selection: Destination = .today

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Study") {
                    sidebarRow(.today)
                    sidebarRow(.flashcards)
                    sidebarRow(.quiz)
                    sidebarRow(.analogies)
                    sidebarRow(.wordTest)
                    sidebarRow(.timedSections)
                }
                Section("Learn") {
                    sidebarRow(.wordList)
                    sidebarRow(.readingGuide)
                    sidebarRow(.passages)
                    sidebarRow(.books)
                    sidebarRow(.math)
                }
                Section {
                    sidebarRow(.strategy)
                    sidebarRow(.progress)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 210)
        } detail: {
            // Every panel stays mounted so its in-progress state (a running
            // deck, a half-finished quiz, scroll positions) survives sidebar
            // navigation; only the selected one is visible and interactive.
            // Each panel is laid *inside* a flexible Color.clear via .overlay:
            // Color.clear reports no intrinsic size, so a hidden List/HSplitView
            // can't inflate the shared canvas past the window — while the detail
            // area keeps its normal safe-area inset (no GeometryReader hijacking
            // the coordinate space, which had shoved content under the sidebar).
            ZStack {
                ForEach(Destination.allCases, id: \.self) { d in
                    Color.clear
                        .overlay(detailView(d))
                        .opacity(selection == d ? 1 : 0)
                        .allowsHitTesting(selection == d)
                        .accessibilityHidden(selection != d)
                        .environment(\.panelActive, selection == d)
                }
            }
            .navigationTitle(selection.label)
        }
        .tint(Theme.accent)
        .onChange(of: selection) { _, _ in
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }

    private func sidebarRow(_ d: Destination) -> some View {
        Label(d.label, systemImage: d.icon).tag(d)
    }

    @ViewBuilder
    private func detailView(_ d: Destination) -> some View {
        switch d {
        case .today: DashboardView(navigate: { selection = $0 })
        case .flashcards: FlashcardsView()
        case .quiz: QuizView()
        case .analogies: AnalogiesView()
        case .wordTest: WordTestView()
        case .timedSections: TimedSectionView()
        case .wordList: BrowseView()
        case .readingGuide: GuideView(sections: state.content.readingGuide,
                                      intro: "Forty questions in forty minutes, and every point comes from the passage in front of you. Here is the whole playbook.")
        case .passages: PassagesView()
        case .books: BooksView()
        case .math: MathView()
        case .strategy: GuideView(sections: state.content.overview,
                                  intro: "Know the test before you fight it: format, scoring, and the game plan for each section.")
        case .progress: StatsView()
        }
    }
}
