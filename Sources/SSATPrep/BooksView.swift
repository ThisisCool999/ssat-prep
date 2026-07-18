import SwiftUI
import SSATCore

/// Overview of the books the reading passages are drawn from — so the student
/// walks into a passage already knowing the author, era, what its prose will
/// feel like, and (via the expandable synopsis) the whole story start to end.
struct BooksView: View {
    @EnvironmentObject private var state: AppState
    @State private var expanded: Set<String> = []

    private var books: [SourceBook] {
        state.content.books.sorted { $0.year < $1.year }
    }

    var body: some View {
        if books.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
                Text("No book overviews loaded.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("The reading section leans on classic literature. These are the books behind the passages — skim them so an unfamiliar excerpt already has a shape when you meet it on the test.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 720, alignment: .leading)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 14)],
                              alignment: .leading, spacing: 14) {
                        ForEach(books) { book in
                            card(book)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 940, alignment: .leading)
            }
        }
    }

    private func card(_ book: SourceBook) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: genreIcon(book.genre))
                    .foregroundStyle(Theme.accent)
                Text(book.title)
                    .font(.headline)
                Spacer()
                Text(String(repeating: "◆", count: max(1, min(3, book.difficulty))))
                    .font(.caption2)
                    .foregroundStyle(Theme.learning)
                    .help("Prose difficulty \(book.difficulty) of 3")
            }
            Text("\(book.author) · \(String(book.year)) · \(book.genre)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(book.overview)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            if !book.ssatNote.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                    Text(book.ssatNote)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }

            if !book.synopsis.isEmpty {
                Divider().padding(.vertical, 2)
                let isOpen = expanded.contains(book.id)
                Button {
                    if isOpen { expanded.remove(book.id) } else { expanded.insert(book.id) }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                        Text(isOpen ? "The whole story" : "The whole story (spoilers)")
                            .font(.callout.weight(.medium))
                        Spacer()
                    }
                    .foregroundStyle(Theme.accent)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isOpen {
                    Text(book.synopsis)
                        .font(.callout)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .transition(.opacity)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .cardStyle()
        .animation(.easeInOut(duration: 0.15), value: expanded)
    }

    private func genreIcon(_ genre: String) -> String {
        let g = genre.lowercased()
        if g.contains("gothic") || g.contains("horror") { return "moon.stars" }
        if g.contains("detective") || g.contains("mystery") { return "magnifyingglass" }
        if g.contains("adventure") { return "pawprint" }
        if g.contains("memoir") || g.contains("essay") || g.contains("reminis") { return "leaf" }
        if g.contains("poem") || g.contains("poetry") { return "text.quote" }
        if g.contains("coming") { return "figure.walk" }
        return "book.closed"
    }
}
