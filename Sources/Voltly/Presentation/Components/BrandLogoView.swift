import SwiftUI

public struct BrandLogoView: View {
    private let size: CGFloat
    private let cornerRadius: CGFloat

    public init(size: CGFloat = 28, cornerRadius: CGFloat = 8) {
        self.size = size
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        Image("BrandLogo")
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

#if DEBUG
struct BrandLogoView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            BrandLogoView()
            BrandLogoView(size: 72, cornerRadius: 18)
        }
        .padding()
        .background(AppTheme.surface)
    }
}
#endif
