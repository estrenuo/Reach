import ReachKit
import SwiftUI

/// Settings > Advanced (S-038): clear what Learning remembers, the typed-query
/// history, and the web search each of ⌃↩, ⌥↩ and ⌘↩ runs.
struct AdvancedSettings: View {
    @Environment(AppModel.self) private var model
    @Bindable private var options = AdvancedOptions.shared
    @State private var learned = 0
    @State private var confirmingClear = false

    var body: some View {
        Section("Learning") {
            LabeledContent {
                Button("Clear Learning…") { confirmingClear = true }
                    .disabled(learned == 0)
            } label: {
                Text("Learning")
                Text(learned == 0 ? "Nothing learned yet." : "Remembers \(learned) results you picked, to rank them first next time.")
            }
        }
        .confirmationDialog("Clear what Reach learned?", isPresented: $confirmingClear) {
            Button("Clear Learning", role: .destructive) {
                Learning(container: model.container).clear()
                learned = 0
            }
        } message: {
            Text("Results go back to plain text-match order. Your apps, files and snippets stay.")
        }
        .onAppear { learned = Learning(container: model.container).count }

        Section("Query History") {
            Toggle(isOn: $options.remembersQueries) {
                Text("Remember typed queries")
                Text("Press ⌃↑ and ⌃↓ in the launcher to bring back what you typed before.")
            }
            Toggle(isOn: $options.restoresLastQuery) {
                Text("Restore the last query")
                Text("Within 5 minutes, the launcher opens with the last query selected.")
            }
            .disabled(!options.remembersQueries)
        }

        Section {
            ForEach(ReturnModifier.allCases) { modifier in
                Picker(modifier.symbol, selection: binding(for: modifier)) {
                    Text("Nothing").tag(String?.none)
                    Divider()
                    ForEach(WebSearchSettings.shared.searches.filter(\.takesQuery)) { search in
                        Text(search.title(for: "")).tag(String?.some(search.id))
                    }
                }
            }
        } header: {
            Text("Alternative Actions")
        } footer: {
            Text("Hold a key with Return to search the web for what you typed, whatever result is selected. ⌘↩ on a calculation still pastes the answer.")
                .foregroundStyle(.secondary)
        }
    }

    private func binding(for modifier: ReturnModifier) -> Binding<String?> {
        Binding(get: { options.alternatives[modifier.rawValue] },
                set: { options.alternatives[modifier.rawValue] = $0 })
    }
}
