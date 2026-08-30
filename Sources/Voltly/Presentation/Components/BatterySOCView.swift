import SwiftUI

public struct BatterySOCView: View {
    private let startSOC: Double
    private let endSOC: Double

    @State private var animatedSOC: Double

    public init(startSOC: Double, endSOC: Double) {
        self.startSOC = max(0, min(100, startSOC))
        self.endSOC = max(0, min(100, endSOC))
        _animatedSOC = State(initialValue: max(0, min(100, endSOC)))
    }

    private var fillColor: Color {
        switch animatedSOC {
        case ..<30: return AppTheme.publicDCColor
        case ..<70: return AppTheme.publicACColor
        default: return AppTheme.homeColor
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let width = max(0, proxy.size.width - 16)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 2)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(fillColor.gradient)
                        .frame(width: width * (animatedSOC / 100))
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: animatedSOC)
                        .padding(2)

                    Rectangle()
                        .fill(AppTheme.overlaySurface)
                        .frame(width: 2)
                        .offset(x: width * (startSOC / 100))
                        .padding(.vertical, 4)
                }
                .padding(.trailing, 12)
                .overlay(alignment: .trailing) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 8, height: 18)
                }
            }
            .frame(height: 40)

            HStack(spacing: 8) {
                Text("Şarj Yüzdesi \(Int(startSOC))% -> \(Int(endSOC))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if endSOC > startSOC {
                    Label("+\(Int(endSOC - startSOC))%", systemImage: "bolt.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(fillColor)
                }
            }
        }
        .onAppear {
            animatedSOC = endSOC
        }
        .onChange(of: endSOC) { _, newValue in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                animatedSOC = max(0, min(100, newValue))
            }
        }
    }
}
