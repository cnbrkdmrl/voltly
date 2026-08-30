import SwiftUI

public extension ChargeMethod {
    var uiColor: Color {
        switch self {
        case .home: return AppTheme.homeColor
        case .publicAC: return AppTheme.publicACColor
        case .publicDC: return AppTheme.publicDCColor
        }
    }

    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .publicAC: return "bolt"
        case .publicDC: return "bolt.fill"
        }
    }
}
