import SwiftUI

public struct EstimationBadge: View {
    private let isEstimated: Bool

    public init(isEstimated: Bool) {
        self.isEstimated = isEstimated
    }

    public var body: some View {
        if isEstimated {
            Text("~ \(L10n.estimated)")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.2))
                .clipShape(Capsule())
        }
    }
}
