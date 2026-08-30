import SwiftUI

public struct MethodDistributionBar: View {
    private enum Layout {
        static let minSegmentWidth: CGFloat = 10
        static let barHeight: CGFloat = 14
    }

    private let shares: [MethodShare]

    public init(shares: [MethodShare]) {
        self.shares = shares
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    ForEach(orderedShares) { share in
                        Rectangle()
                            .fill(share.method.uiColor)
                            .frame(
                                width: segmentWidth(
                                    totalWidth: proxy.size.width,
                                    costShare: share.costShare
                                )
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: Layout.barHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            ForEach(orderedShares) { share in
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(share.method.uiColor)
                            .frame(width: 8, height: 8)
                        Text(share.method.titleTR)
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                    Text("Maliyet %\(Int(share.costShare.rounded())) • Enerji %\(Int(share.energyShare.rounded())) • Seans %\(Int(share.sessionShare.rounded()))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var orderedShares: [MethodShare] {
        shares.sorted { $0.method.rawValue < $1.method.rawValue }
    }

    private func segmentWidth(totalWidth: CGFloat, costShare: Double) -> CGFloat {
        let safeShare = max(0, min(100, costShare))
        let rawWidth = totalWidth * CGFloat(safeShare / 100)
        return max(Layout.minSegmentWidth, rawWidth)
    }
}

#if DEBUG
struct MethodDistributionBar_Previews: PreviewProvider {
    static var previews: some View {
        MethodDistributionBar(
            shares: [
                MethodShare(method: .home, costShare: 30, energyShare: 42, sessionShare: 35),
                MethodShare(method: .publicAC, costShare: 40, energyShare: 38, sessionShare: 41),
                MethodShare(method: .publicDC, costShare: 30, energyShare: 20, sessionShare: 24)
            ]
        )
        .padding()
    }
}
#endif
