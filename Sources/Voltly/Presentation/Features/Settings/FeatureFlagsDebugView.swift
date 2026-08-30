import SwiftUI

@MainActor
public final class FeatureFlagsDebugViewModel: ObservableObject {
    @Published public private(set) var states: [AppFeatureState] = []

    private let store: any FeatureFlagStore
    private let checker: any FeatureAccessChecking

    public init(
        store: any FeatureFlagStore,
        checker: any FeatureAccessChecking
    ) {
        self.store = store
        self.checker = checker
        refresh()
    }

    public func isEnabled(_ feature: AppFeature) -> Bool {
        states.first(where: { $0.feature == feature })?.isEnabled
            ?? checker.isEnabled(feature)
    }

    public func sourceText(for feature: AppFeature) -> String {
        let source = states.first(where: { $0.feature == feature })?.source
            ?? checker.source(for: feature)
        switch source {
        case .stored:
            return "Manuel"
        case .defaultValue:
            return "Varsayılan"
        }
    }

    public func setFeature(
        _ feature: AppFeature,
        enabled: Bool
    ) {
        store.setValue(enabled, for: feature)
        refresh()
    }

    public func resetToDefaults() {
        store.resetToDefaults()
        refresh()
    }

    public func refresh() {
        states = checker
            .allFeatureStates()
            .sorted { $0.feature.debugTitle < $1.feature.debugTitle }
    }
}

public struct FeatureFlagsDebugView: View {
    @StateObject private var viewModel: FeatureFlagsDebugViewModel

    public init(viewModel: FeatureFlagsDebugViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        List {
            Section("Feature Flags") {
                ForEach(AppFeature.allCases) { feature in
                    Toggle(
                        isOn: Binding(
                            get: { viewModel.isEnabled(feature) },
                            set: { viewModel.setFeature(feature, enabled: $0) }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(feature.debugTitle)
                                .font(.subheadline.weight(.semibold))
                            Text(feature.debugDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Kaynak: \(viewModel.sourceText(for: feature))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button("Varsayılanlara dön") {
                    viewModel.resetToDefaults()
                }
                .foregroundStyle(.red)
            } footer: {
                Text("Bu ekran sadece debug derlemelerinde görünür.")
            }
        }
        .navigationTitle("Feature Flags")
        .onAppear {
            viewModel.refresh()
        }
    }
}

#if DEBUG
struct FeatureFlagsDebugView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            FeatureFlagsDebugView(
                viewModel: FeatureFlagsDebugViewModel(
                    store: UserDefaultsFeatureFlagStore(defaults: .standard),
                    checker: FeatureAccessChecker(
                        store: UserDefaultsFeatureFlagStore(defaults: .standard)
                    )
                )
            )
        }
    }
}
#endif
