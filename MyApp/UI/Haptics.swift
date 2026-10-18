import SwiftUI
#if os(iOS)
import UIKit
#endif

enum Haptics {
    #if os(iOS)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    #endif

    static func punch(_ setting: Vibration) {
        #if os(iOS)
        switch setting {
        case .off: break
        case .light: light.impactOccurred(intensity: 0.5)
        case .strong: medium.impactOccurred()
        }
        #endif
    }
}
