import SwiftUI

/// Root settings view with tabs for each configuration category.
struct SettingsView: View {

    @State private var showResetAlert = false

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                GeneralTab()
                    .tabItem { Label("General", systemImage: "keyboard") }
                DrawTab()
                    .tabItem { Label("Draw", systemImage: "pencil.tip") }
                ZoomTab()
                    .tabItem { Label("Zoom", systemImage: "magnifyingglass") }
                BreakTimerTab()
                    .tabItem { Label("Break Timer", systemImage: "timer") }
            }
            .frame(minWidth: 480, minHeight: 320)

            Divider()

            HStack {
                Button("Reset to Defaults") {
                    showResetAlert = true
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .padding()
        .alert("Reset to Defaults", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                Settings.shared.resetToDefaults()
                HotkeyManager.shared.reregisterHotkeys()
            }
        } message: {
            Text("All settings will be restored to their default values. This cannot be undone.")
        }
        .onDisappear {
            BreakTimerWindowController.stopTestSound()
        }
    }
}
