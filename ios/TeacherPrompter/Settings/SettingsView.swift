import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.loc) private var loc

    @AppStorage(SettingsKey.appearance) private var appearance: AppearanceMode = .system
    @AppStorage(SettingsKey.uiLanguage) private var uiLanguage: UILanguagePreference = .system
    @AppStorage(SettingsKey.fontSize) private var fontSize: Double = SettingsDefaults.fontSize
    @AppStorage(SettingsKey.previewNext) private var previewNext = true
    @AppStorage(SettingsKey.hideCompleted) private var hideCompleted = false
    @AppStorage(SettingsKey.strikeCompleted) private var strikeCompleted = true
    @AppStorage(SettingsKey.showPrevious) private var showPrevious = true
    @AppStorage(SettingsKey.focusMode) private var focusMode = false

    var body: some View {
        NavigationStack {
            Form {
                Section(loc(.appearance)) {
                    Picker(loc(.appearance), selection: $appearance) {
                        Text(loc(.system)).tag(AppearanceMode.system)
                        Text(loc(.light)).tag(AppearanceMode.light)
                        Text(loc(.dark)).tag(AppearanceMode.dark)
                    }
                    .pickerStyle(.segmented)

                    Picker(loc(.interfaceLanguage), selection: $uiLanguage) {
                        Text(loc(.systemLanguage)).tag(UILanguagePreference.system)
                        Text("Deutsch").tag(UILanguagePreference.de)
                        Text("English").tag(UILanguagePreference.en)
                    }
                }

                Section(loc(.lessonMode)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(loc(.fontSize(Int(fontSize))))
                        Slider(value: $fontSize, in: SettingsDefaults.fontRange, step: SettingsDefaults.fontStep)
                        Text(verbatim: "Die Zellmembran trennt …")
                            .font(.system(size: CGFloat(fontSize) * 0.6, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    Toggle(loc(.previewNext), isOn: $previewNext)
                    Toggle(loc(.showPrevious), isOn: $showPrevious)
                    Toggle(loc(.hideCompleted), isOn: $hideCompleted)
                    Toggle(loc(.strikeCompleted), isOn: $strikeCompleted)
                    Toggle(loc(.focusMode), isOn: $focusMode)
                }

                Section(loc(.about)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(loc(.ownershipTitle), systemImage: "lock.doc")
                            .font(.headline)
                        Text(loc(.ownershipText))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(loc(.settings))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc(.done)) { dismiss() }
                }
            }
        }
    }
}
