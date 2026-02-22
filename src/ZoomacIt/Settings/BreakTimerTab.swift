import Combine
import SwiftUI

/// Break Timer settings tab.
struct BreakTimerTab: View {

    @AppStorage(Settings.Keys.breakTimerDefaultDuration) private var duration: Int = 600
    @AppStorage(Settings.Keys.breakTimerColor) private var colorRaw: String = PenColor.red.rawValue
    @AppStorage(Settings.Keys.breakTimerOpacity) private var opacity: Double = 1.0
    @AppStorage(Settings.Keys.breakTimerBackground) private var backgroundRaw: String = BreakTimerBackground.black.rawValue
    @AppStorage(Settings.Keys.breakTimerShowElapsed) private var showElapsed: Bool = true
    @AppStorage(Settings.Keys.breakTimerPlaySound) private var playSound: Bool = false
    @AppStorage(Settings.Keys.breakTimerSoundFile) private var soundFilePath: String = ""
    @AppStorage(Settings.Keys.breakTimerBackgroundFadeDarkness) private var fadeDarkness: Double = 0.6

    /// Tracks whether a test sound is currently playing.
    @State private var isTestPlaying = false
    /// Timer to poll playback state so button updates when sound finishes naturally.
    @State private var pollTimer: Timer?

    private var timerColor: Binding<PenColor> {
        Binding(
            get: { PenColor(rawValue: colorRaw) ?? .red },
            set: { colorRaw = $0.rawValue }
        )
    }

    private var background: Binding<BreakTimerBackground> {
        Binding(
            get: { BreakTimerBackground(rawValue: backgroundRaw) ?? .black },
            set: { backgroundRaw = $0.rawValue }
        )
    }

    /// Duration in minutes for the stepper.
    private var durationMinutes: Binding<Int> {
        Binding(
            get: { duration / 60 },
            set: { duration = $0 * 60 }
        )
    }

    var body: some View {
        Form {
            Section("Timer") {
                Stepper("Default Duration: \(duration / 60) min", value: durationMinutes, in: 1...120)
            }

            Section("Appearance") {
                Picker("Timer Color", selection: timerColor) {
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
                    Text("Opacity")
                    Slider(value: $opacity, in: 0.1...1.0, step: 0.1)
                    Text(String(format: "%.0f%%", opacity * 100))
                        .frame(width: 40, alignment: .trailing)
                        .monospacedDigit()
                }

                Picker("Background", selection: background) {
                    Text("Black").tag(BreakTimerBackground.black)
                    Text("Faded Desktop").tag(BreakTimerBackground.fadedDesktop)
                }

                if BreakTimerBackground(rawValue: backgroundRaw) == .fadedDesktop {
                    HStack {
                        Text("Fade Darkness")
                        Slider(value: $fadeDarkness, in: 0.1...1.0, step: 0.05)
                        Text(String(format: "%.0f%%", fadeDarkness * 100))
                            .frame(width: 40, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
            }

            Section("Options") {
                Toggle("Show Elapsed Time After Expiration", isOn: $showElapsed)
                Toggle("Play Sound on Expiration", isOn: $playSound)

                if playSound {
                    HStack {
                        Text("Sound File")
                        Spacer()
                        if soundFilePath.isEmpty {
                            Text("System Default")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(URL(fileURLWithPath: soundFilePath).lastPathComponent)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Button("Choose…") {
                            chooseSoundFile()
                        }
                        if !soundFilePath.isEmpty {
                            Button("Clear") {
                                soundFilePath = ""
                            }
                        }
                        Button {
                            if isTestPlaying {
                                BreakTimerWindowController.stopTestSound()
                                isTestPlaying = false
                                stopPollTimer()
                            } else {
                                let fileURL: URL? = soundFilePath.isEmpty ? nil : URL(fileURLWithPath: soundFilePath)
                                BreakTimerWindowController.playTestSound(fileURL: fileURL)
                                isTestPlaying = true
                                startPollTimer()
                            }
                        } label: {
                            Image(systemName: isTestPlaying ? "stop.fill" : "play.fill")
                        }
                        .help(isTestPlaying ? "Stop Sound" : "Test Sound")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onDisappear {
            BreakTimerWindowController.stopTestSound()
            isTestPlaying = false
            stopPollTimer()
        }
    }

    private func chooseSoundFile() {
        let panel = NSOpenPanel()
        panel.title = "Choose Sound File"
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            soundFilePath = url.path
        }
    }

    /// Start polling to detect when test sound finishes naturally.
    private func startPollTimer() {
        stopPollTimer()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if !BreakTimerWindowController.isTestSoundPlaying {
                isTestPlaying = false
                stopPollTimer()
            }
        }
    }

    /// Stop the playback poll timer.
    private func stopPollTimer() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
