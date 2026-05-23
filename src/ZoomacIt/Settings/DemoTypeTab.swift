import SwiftUI

/// DemoType settings tab: text, typing speed, hotkey.
struct DemoTypeTab: View {

    @AppStorage(Settings.Keys.demoTypeText) private var text: String = ""
    @AppStorage(Settings.Keys.demoTypeSpeed) private var speed: Double = 15.0

    var body: some View {
        Form {
            Section("Text") {
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
            }

            Section("Typing Speed") {
                HStack {
                    Text("Characters/sec")
                    Slider(value: $speed, in: 5...60, step: 1)
                    Text(String(format: "%.0f", speed))
                        .frame(width: 30, alignment: .trailing)
                        .monospacedDigit()
                }
            }
        }
        .formStyle(.grouped)
    }
}
