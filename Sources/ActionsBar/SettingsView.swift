import SwiftUI

struct SettingsView: View {
    @Environment(RunStore.self) private var store
    @Bindable var settings: AppSettings
    let onClose: () -> Void

    @State private var tokenInput = ""
    @State private var hasManualToken = Keychain.read() != nil
    @State private var pinnedText = ""
    @State private var launchAtLogin = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                group("Authentification") {
                    LabeledContent("Source", value: store.tokenSource.label)
                        .font(.callout)
                    HStack {
                        SecureField(hasManualToken ? "Token enregistré" : "Token personnel (optionnel)", text: $tokenInput)
                            .textFieldStyle(.roundedBorder)
                        Button("Enregistrer") {
                            Keychain.save(tokenInput.trimmingCharacters(in: .whitespacesAndNewlines))
                            tokenInput = ""
                            hasManualToken = true
                            store.reload()
                        }
                        .disabled(tokenInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if hasManualToken {
                        Button("Supprimer le token et utiliser gh") {
                            Keychain.delete()
                            hasManualToken = false
                            store.reload()
                        }
                        .controlSize(.small)
                    }
                    Text("Par défaut, le token de `gh auth token` est utilisé. Un token manuel nécessite les scopes `repo` (et `read:org` pour les organisations).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                group("Dépôts suivis") {
                    Toggle("Suivre automatiquement mes dépôts récents", isOn: $settings.autoDiscover)
                    if settings.autoDiscover {
                        Stepper("Les \(settings.autoDiscoverCount) derniers poussés",
                                value: $settings.autoDiscoverCount, in: 1...50)
                    }
                    Text("Dépôts supplémentaires (owner/nom, un par ligne)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $pinnedText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 70)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(.quaternary))
                }

                group("Rafraîchissement") {
                    Picker("Pendant un run", selection: $settings.activeInterval) {
                        ForEach([3, 5, 10, 15, 30], id: \.self) { Text("\($0) s").tag($0) }
                    }
                    Picker("Au repos", selection: $settings.idleInterval) {
                        ForEach([15, 30, 60, 120, 300], id: \.self) { Text("\($0) s").tag($0) }
                    }
                }

                group("Général") {
                    Toggle("Notifier à la fin d'un workflow", isOn: $settings.notificationsEnabled)
                        .disabled(!Notifier.isAvailable)
                    Toggle("Afficher le nom du workflow dans la barre", isOn: $settings.showNameInMenuBar)
                    Toggle("Lancer au démarrage", isOn: $launchAtLogin)
                        .disabled(!Notifier.isAvailable)
                        .onChange(of: launchAtLogin) { _, newValue in settings.launchAtLogin = newValue }
                }

                HStack {
                    Spacer()
                    Button("Appliquer") {
                        apply()
                        onClose()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(12)
        }
        .frame(maxHeight: 520)
        .onAppear {
            pinnedText = settings.pinnedRepos.joined(separator: "\n")
            launchAtLogin = settings.launchAtLogin
        }
    }

    private func apply() {
        settings.pinnedRepos = pinnedText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.split(separator: "/").count == 2 }
        store.reload()
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }
}
