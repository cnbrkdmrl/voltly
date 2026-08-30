import SwiftUI

public struct OperatorsView: View {
    @StateObject private var viewModel: ChargingOperatorsViewModel

    public init(environment: AppEnvironment) {
        _viewModel = StateObject(
            wrappedValue: ChargingOperatorsViewModel(
                repository: environment.chargingOperatorRepository
            )
        )
    }

    public var body: some View {
        ChargingOperatorsScreen(viewModel: viewModel)
            .navigationTitle("Operatörler")
    }
}
