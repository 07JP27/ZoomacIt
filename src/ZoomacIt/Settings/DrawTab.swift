import SwiftUI

/// Draw settings tab: pen color, width, highlighter, text.
struct DrawTab: View {

    @AppStorage(Settings.Keys.defaultPenColor) private var penColorRaw: String = PenColor.red.rawValue
    @AppStorage(Settings.Keys.defaultPenWidth) private var penWidth: Double = 3.0
    @AppStorage(Settings.Keys.highlighterOpacity) private var highlighterOpacity: Double = 0.35
    @AppStorage(Settings.Keys.highlighterWidthMultiplier) private var highlighterMultiplier: Double = 4.0
    @AppStorage(Settings.Keys.defaultFontSize) private var fontSize: Double = 24.0
    @AppStorage(Settings.Keys.fontWeight) private var fontWeightRaw: String = FontWeightOption.medium.rawValue

    private var penColor: Binding<PenColor> {
        Binding(
            get: { PenColor(rawValue: penColorRaw) ?? .red },
            set: { penColorRaw = $0.rawValue }
        )
    }

    private var fontWeight: Binding<FontWeightOption> {
        Binding(
            get: { FontWeightOption(rawValue: fontWeightRaw) ?? .medium },
            set: { fontWeightRaw = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section("Pen") {
                Picker("Default Color", selection: penColor) {
                    ForEach(PenColor.allCases, id: \.self) { color in
                        HStack {
                            Circle()
                                .fill(Color(nsColor: color.nsColor))
                                .frame(width: 12, height: 12)
                            Text(color.rawValue.capitalized)
                        }
                        .tag(color)
                    }
                }

                HStack {
                    Text("Default Width")
                    Slider(value: $penWidth, in: 1...50, step: 1)
                    Text("\(Int(penWidth)) pt")
                        .frame(width: 40, alignment: .trailing)
                        .monospacedDigit()
                }
            }

            Section("Highlighter") {
                HStack {
                    Text("Opacity")
                    Slider(value: $highlighterOpacity, in: 0.05...1.0, step: 0.05)
                    Text(String(format: "%.0f%%", highlighterOpacity * 100))
                        .frame(width: 40, alignment: .trailing)
                        .monospacedDigit()
                }

                HStack {
                    Text("Width Multiplier")
                    Slider(value: $highlighterMultiplier, in: 1...10, step: 0.5)
                    Text(String(format: "%.1fx", highlighterMultiplier))
                        .frame(width: 40, alignment: .trailing)
                        .monospacedDigit()
                }
            }

            Section("Text") {
                HStack {
                    Text("Default Size")
                    Slider(value: $fontSize, in: 8...200, step: 1)
                    Text("\(Int(fontSize)) pt")
                        .frame(width: 50, alignment: .trailing)
                        .monospacedDigit()
                }

                Picker("Weight", selection: fontWeight) {
                    ForEach(FontWeightOption.allCases, id: \.self) { weight in
                        Text(weight.displayName).tag(weight)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
