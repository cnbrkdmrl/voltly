import SwiftUI

public struct ChargeMapAnnotationView: View {
    private let pin: ChargeMapPin
    private let isSelected: Bool

    public init(pin: ChargeMapPin, isSelected: Bool) {
        self.pin = pin
        self.isSelected = isSelected
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(pin.chargeMethod.uiColor)
                .frame(width: isSelected ? 34 : 28, height: isSelected ? 34 : 28)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)

            Image(systemName: pin.chargeMethod.iconName)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
        }
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isSelected)
    }
}

#if DEBUG
struct ChargeMapAnnotationView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.08).ignoresSafeArea()
            ChargeMapAnnotationView(
                pin: ChargeMapPin(
                    id: UUID(),
                    sessionID: UUID(),
                    coordinate: .init(latitude: 41.01, longitude: 28.97),
                    stationDisplayName: "Lumicle • Gönen",
                    chargeMethod: .publicDC,
                    energyKWh: 12.3,
                    totalPrice: 141,
                    currencyCode: "TRY",
                    tlPerKWh: 11.4,
                    isApproximateLocation: false
                ),
                isSelected: true
            )
        }
    }
}
#endif
