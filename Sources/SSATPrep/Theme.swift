import SwiftUI

/// True when the view's sidebar panel is the visible one. Panels stay alive
/// (and keep their state) while hidden, so anything global — keyboard
/// shortcuts, timers — must gate on this.
private struct PanelActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var panelActive: Bool {
        get { self[PanelActiveKey.self] }
        set { self[PanelActiveKey.self] = newValue }
    }
}

extension View {
    /// Registers a keyboard shortcut only while `active` — hidden keep-alive
    /// panels must not swallow keystrokes meant for the visible one.
    @ViewBuilder
    func keyboardShortcutIf(_ active: Bool, _ key: KeyEquivalent,
                            modifiers: EventModifiers = []) -> some View {
        if active {
            keyboardShortcut(key, modifiers: modifiers)
        } else {
            self
        }
    }
}

enum Theme {
    static let accent = Color(red: 0.18, green: 0.32, blue: 0.60)
    static let mastered = Color(red: 0.22, green: 0.55, blue: 0.35)
    static let learning = Color(red: 0.85, green: 0.58, blue: 0.16)
    static let wrong = Color(red: 0.75, green: 0.24, blue: 0.22)
    static let notebook = Color(red: 0.48, green: 0.32, blue: 0.66)
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator, lineWidth: 1))
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardBackground()) }
}

/// "A) answer" choice row used by every multiple-choice surface in the app.
struct ChoiceRow: View {
    let text: String
    let state: ChoiceState
    let action: () -> Void

    enum ChoiceState {
        case idle
        case correct
        case incorrect
        case dimmed
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                switch state {
                case .correct:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.mastered)
                case .incorrect:
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.wrong)
                case .idle, .dimmed:
                    EmptyView()
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(borderColor, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .opacity(state == .dimmed ? 0.55 : 1)
    }

    private var backgroundColor: Color {
        switch state {
        case .correct: return Theme.mastered.opacity(0.14)
        case .incorrect: return Theme.wrong.opacity(0.12)
        case .idle, .dimmed: return Color.primary.opacity(0.03)
        }
    }

    private var borderColor: Color {
        switch state {
        case .correct: return Theme.mastered.opacity(0.7)
        case .incorrect: return Theme.wrong.opacity(0.6)
        case .idle, .dimmed: return Color.primary.opacity(0.10)
        }
    }
}

/// Compact "on the real test" banner shown at the top of each training
/// section: exact format, timing, and scoring facts for the matching part of
/// the SSAT, so the reader always knows what a drill is preparing them for.
struct SectionBrief: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.callout)
                .frame(width: 26, height: 26)
                .background(Theme.accent.opacity(0.12), in: Circle())
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    var tint: Color = Theme.accent
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.callout).foregroundStyle(tint)
                Text(label).font(.callout).foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardStyle()
    }
}
