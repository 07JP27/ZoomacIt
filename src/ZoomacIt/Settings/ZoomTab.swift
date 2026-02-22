import SwiftUI

/// Zoom settings tab: zoom level, animation.
struct ZoomTab: View {

    @AppStorage(Settings.Keys.defaultZoomLevel) private var zoomLevel: Double = 2.0
    @AppStorage(Settings.Keys.zoomAnimationEnabled) private var animationEnabled: Bool = true

    var body: some View {
        Form {
            Section("Zoom") {
                HStack {
                    Text("Default Level")
                    Slider(value: $zoomLevel, in: 1...8, step: 0.1)
                    Text(String(format: "%.1fx", zoomLevel))
                        .frame(width: 40, alignment: .trailing)
                        .monospacedDigit()
                }
                Toggle("Enable Animation", isOn: $animationEnabled)
            }
        }
        .formStyle(.grouped)
    }
}
