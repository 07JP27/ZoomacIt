import SwiftUI

/// Root settings view with tabs for each configuration category.
struct SettingsView: View {

    @State private var showResetAlert = false

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                GeneralTab()
                    .tabItem { Text("General") }
                DrawTab()
                    .tabItem { Text("Draw") }
                ZoomTab()
                    .tabItem { Text("Zoom") }
                BreakTimerTab()
                    .tabItem { Text("Break Timer") }
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
