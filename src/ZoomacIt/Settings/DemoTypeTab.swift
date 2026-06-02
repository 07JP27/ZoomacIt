import SwiftUI

/// DemoType-specific settings: script file, speed, user-driven mode.
struct DemoTypeTab: View {

    @AppStorage(Settings.Keys.demoTypeFilePath) private var filePath: String = ""
    @AppStorage(Settings.Keys.demoTypeSpeed) private var speed: Double = 55.0
    @AppStorage(Settings.Keys.demoTypeUserDriven) private var userDriven: Bool = false

    var body: some View {
        Form {
            Section("Script Source") {
                HStack {
                    TextField("File path", text: $filePath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse…") { browseFile() }
                }
                Text("Leave empty to use clipboard ([start] prefix) or input dialog.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Typing") {
                HStack {
                    Text("Speed")
                    Slider(value: $speed, in: 10...100, step: 5)
                    Text("\(Int(speed)) ms")
                        .monospacedDigit()
                        .frame(width: 50)
                }
                Toggle("User-driven mode", isOn: $userDriven)
                Text("In user-driven mode, each keypress injects characters from the script instead of auto-typing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func browseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            filePath = url.path
        }
    }
}
