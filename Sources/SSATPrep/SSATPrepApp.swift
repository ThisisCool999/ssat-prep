import SwiftUI
import SSATCore

@main
struct SSATPrepApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .frame(minWidth: 960, minHeight: 620)
                .background(WindowSizer())
        }
        .windowToolbarStyle(.unified)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1121, height: 711)

        Settings {
            SettingsView()
                .environmentObject(state)
        }
    }
}

/// Places the window at the exact frame from the user's reference screenshot on
/// every launch, so the app always opens at that size and position instead of
/// restoring whatever frame it last had. The values are fractions of the full
/// screen (measured from the screenshot), so they land correctly on any display.
private struct WindowSizer: NSViewRepresentable {
    // Measured from the reference screenshot (window box ÷ screen size).
    private static let fracLeft = 0.1211
    private static let fracWidth = 0.7624
    private static let fracTopInset = 0.1223   // gap above the window, from screen top
    private static let fracHeight = 0.7439

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window,
                  let screen = window.screen ?? NSScreen.main else { return }
            let f = screen.frame
            let w = f.width * Self.fracWidth
            let h = f.height * Self.fracHeight
            let x = f.minX + f.width * Self.fracLeft
            // AppKit y is measured from the bottom; the screenshot inset is from the top.
            let y = f.minY + f.height * (1 - Self.fracTopInset - Self.fracHeight)
            window.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true, animate: false)
            // Don't let macOS restore an old frame over ours on the next open.
            window.isRestorable = false
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @AppStorage("newPerDay") private var newPerDay = 15
    @AppStorage("testDateSet") private var testDateSet = false
    @AppStorage("testDate") private var testDateTimestamp = Date().timeIntervalSince1970
    @State private var confirmingReset = false

    var body: some View {
        Form {
            Section("Study") {
                HStack {
                    Text("New words per day")
                    Spacer()
                    TextField("", value: $newPerDay, format: .number)
                        .frame(width: 56)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .onChange(of: newPerDay) { _, v in if v < 1 { newPerDay = 1 } }
                    Stepper("", value: $newPerDay, in: 1...9999).labelsHidden()
                }
            }
            Section("Test date") {
                Toggle("I have a test date", isOn: $testDateSet)
                if testDateSet {
                    DatePicker("Test day", selection: Binding(
                        get: { Date(timeIntervalSince1970: testDateTimestamp) },
                        set: { testDateTimestamp = $0.timeIntervalSince1970 }
                    ), displayedComponents: .date)
                }
            }
            Section("Data") {
                Button("Reset all progress…", role: .destructive) { confirmingReset = true }
                    .confirmationDialog("Erase every card's history, streaks, and quiz results?",
                                        isPresented: $confirmingReset) {
                        Button("Erase everything", role: .destructive) {
                            state.progress.resetAll()
                            state.bump()
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}
