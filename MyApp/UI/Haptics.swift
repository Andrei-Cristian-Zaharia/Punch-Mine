import SwiftUI
#if os(iOS)
import UIKit
#endif

enum Haptics {
    #if os(iOS)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notification = UINotificationFeedbackGenerator()
    #endif

    enum Strength { case medium, heavy }

    /// A bigger bump for explosions, Titan Punches and the Heart. Light vibration softens it.
    static func impact(_ strength: Strength, _ setting: Vibration) {
        #if os(iOS)
        guard setting != .off else { return }
        let scale: CGFloat = setting == .light ? 0.6 : 1
        switch strength {
        case .medium: medium.impactOccurred(intensity: 0.8 * scale)
        case .heavy: heavy.impactOccurred(intensity: scale)
        }
        #endif
    }

    static func success(_ setting: Vibration) {
        #if os(iOS)
        if setting != .off { notification.notificationOccurred(.success) }
        #endif
    }

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
