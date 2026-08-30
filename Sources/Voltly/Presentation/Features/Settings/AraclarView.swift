import SwiftUI

public struct AraclarView: View {
    @StateObject private var viewModel: VehicleSetupViewModel

    public init(environment: AppEnvironment) {
        _viewModel = StateObject(wrappedValue: VehicleSetupViewModel(environment: environment))
    }

    public var body: some View {
        VehicleSetupScreen(viewModel: viewModel)
            .navigationTitle("Araçlar")
    }
}
