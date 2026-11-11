import AppKit
import SwiftUI

struct ShortcutsSettingsPane: View {
    var model: AppModel

    private var lang: LanguageManager { model.lang }

    var body: some View {
        Form {
            Section {
                LabeledContent(lang.t("settings.shortcuts.approve")) {
                    ShortcutRecorder(
                        shortcut: Binding(
                            get: { model.approveShortcut },
                            set: { model.approveShortcut = $0 }
                        ),
                        lang: lang,
                        onRecordingChange: { model.setApproveShortcutSuspended($0) }
                    )
                }
                if model.approveShortcutRegistrationFailed {
                    Text(lang.t("settings.shortcuts.unavailable"))
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(lang.t("settings.tab.shortcuts"))
    }
}

/// Click to record, then press a key combination. Escape cancels.
struct ShortcutRecorder: View {
    @Binding var shortcut: HotKeyShortcut?
    let lang: LanguageManager
    var onRecordingChange: (Bool) -> Void = { _ in }

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button {
                isRecording ? stopRecording() : startRecording()
            } label: {
                Text(label)
                    .monospaced(shortcut != nil && !isRecording)
                    .frame(minWidth: 110)
            }
            .accessibilityLabel(lang.t("settings.shortcuts.approve"))

            if shortcut != nil, !isRecording {
                Button {
                    shortcut = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(lang.t("settings.shortcuts.clear"))
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private var label: String {
        if isRecording { return lang.t("settings.shortcuts.recording") }
        return shortcut?.displayString ?? lang.t("settings.shortcuts.record")
    }

    private func startRecording() {
        isRecording = true
        onRecordingChange(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape
                stopRecording()
                return nil
            }
            guard let recorded = HotKeyShortcut(event: event) else {
                NSSound.beep()
                return nil
            }
            shortcut = recorded
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if isRecording { onRecordingChange(false) }
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
