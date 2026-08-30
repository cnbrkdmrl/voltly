import SwiftUI

public extension View {
    @ViewBuilder
    func voltlyDecimalKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    func voltlyNumberKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.numberPad)
        #else
        self
        #endif
    }
}

public extension ToolbarItemPlacement {
    /// Uses top trailing placement on iOS and falls back to automatic on other platforms.
    static var voltlyPrimaryAction: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }
}
