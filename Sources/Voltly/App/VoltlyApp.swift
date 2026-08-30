import SwiftUI

public struct VoltlyAppContainerView: View {
    @StateObject private var launchCoordinator = LaunchCoordinator()

    public init() {}

    public var body: some View {
        Group {
            switch launchCoordinator.state {
            case .checking(let message):
                LaunchLoadingStateView(
                    title: "Uygulama hazırlanıyor",
                    message: message
                )
            case .migrating(let message):
                LaunchLoadingStateView(
                    title: "Uygulama hazırlanıyor",
                    message: message
                )
            case .ready(let environment):
                LaunchRootView(environment: environment)
            case .failed(let failure):
                LaunchFailedStateView(
                    failure: failure,
                    onRetry: { launchCoordinator.retry() },
                    onShowSupportLog: { launchCoordinator.presentSupportLogIfAvailable() }
                )
            }
        }
        .task {
            launchCoordinator.startIfNeeded()
        }
        .sheet(item: $launchCoordinator.supportLogSheet) { logSheet in
            NavigationStack {
                ScrollView {
                    Text(logSheet.logText)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                .navigationTitle(logSheet.title)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
            }
        }
    }
}

private struct LaunchLoadingStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }
}

private struct LaunchFailedStateView: View {
    let failure: LaunchFailureState
    let onRetry: () -> Void
    let onShowSupportLog: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.orange)
            Text(failure.title)
                .font(.headline)
            Text(failure.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Button("Yeniden dene", action: onRetry)
                .buttonStyle(.borderedProminent)
            Button("Destek / log göster", action: onShowSupportLog)
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, 20)
    }
}
