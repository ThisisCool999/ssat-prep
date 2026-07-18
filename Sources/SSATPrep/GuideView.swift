import SwiftUI
import SSATCore

/// Renders a list of GuideSections (used by both the Reading Guide and Test
/// Strategy pages): jump chips up top, then every section in one scroll.
struct GuideView: View {
    let sections: [GuideSection]
    let intro: String

    var body: some View {
        if sections.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
                Text("No guide content loaded.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        Text(intro)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 660, alignment: .leading)

                        chipRow(proxy: proxy)

                        ForEach(sections) { section in
                            sectionView(section)
                                .id(section.id)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 860, alignment: .leading)
                }
            }
        }
    }

    private func chipRow(proxy: ScrollViewProxy) -> some View {
        FlowChips(items: sections.map { ($0.id, $0.title, $0.icon) }) { id in
            withAnimation { proxy.scrollTo(id, anchor: .top) }
        }
    }

    private func sectionView(_ section: GuideSection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: validSymbol(section.icon))
                    .font(.title3)
                    .frame(width: 34, height: 34)
                    .background(Theme.accent.opacity(0.10), in: Circle())
                    .foregroundStyle(Theme.accent)
                Text(section.title)
                    .font(.title2.weight(.semibold))
            }

            ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                VStack(alignment: .leading, spacing: 6) {
                    if !block.heading.isEmpty {
                        Text(block.heading).font(.headline)
                    }
                    if !block.body.isEmpty {
                        Text(LocalizedStringKey(block.body))
                            .font(.callout)
                            .lineSpacing(3)
                    }
                    ForEach(block.bullets, id: \.self) { bullet in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•").foregroundStyle(Theme.accent)
                            Text(LocalizedStringKey(bullet))
                                .font(.callout)
                                .lineSpacing(2)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }
        }
    }

    private func validSymbol(_ name: String) -> String {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil ? name : "book"
    }
}

/// Wrapping row of tappable section chips.
struct FlowChips: View {
    let items: [(id: String, title: String, icon: String)]
    let onTap: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.id) { item in
                Button {
                    onTap(item.id)
                } label: {
                    Label(item.title, systemImage: validSymbol(item.icon))
                        .font(.callout)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.accent.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func validSymbol(_ name: String) -> String {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil ? name : "book"
    }
}
