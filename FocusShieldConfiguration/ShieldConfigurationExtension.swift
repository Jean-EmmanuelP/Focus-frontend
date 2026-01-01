//
//  ShieldConfigurationExtension.swift
//  FocusShieldConfiguration
//
//  Custom Shield Configuration for blocked apps during Focus sessions
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Custom Shield Configuration Extension
/// Displays personalized message when user tries to open a blocked app
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    // MARK: - Shield Configuration

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        return ShieldConfiguration(
            backgroundBlurStyle: .dark,
            backgroundColor: UIColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1.0), // #050508 - deep black
            icon: UIImage(systemName: "flame.fill"),
            title: ShieldConfiguration.Label(
                text: "Tu es en mode Focus 🔥",
                color: UIColor(red: 0.35, green: 0.78, blue: 0.98, alpha: 1.0) // #5AC8FA - sky blue
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Cette app est bloquée pendant ta session.\nReste concentré, tu peux le faire !",
                color: UIColor.white.withAlphaComponent(0.7)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Retour au Focus",
                color: UIColor.white
            ),
            primaryButtonBackgroundColor: UIColor(red: 0.35, green: 0.78, blue: 0.98, alpha: 1.0), // #5AC8FA
            secondaryButtonLabel: nil
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        return configuration(shielding: application)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        return ShieldConfiguration(
            backgroundBlurStyle: .dark,
            backgroundColor: UIColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1.0),
            icon: UIImage(systemName: "globe"),
            title: ShieldConfiguration.Label(
                text: "Site bloqué 🔒",
                color: UIColor(red: 0.35, green: 0.78, blue: 0.98, alpha: 1.0)
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Ce site est bloqué pendant ta session Focus.\nConcentre-toi sur ce qui compte vraiment.",
                color: UIColor.white.withAlphaComponent(0.7)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Retour au Focus",
                color: UIColor.white
            ),
            primaryButtonBackgroundColor: UIColor(red: 0.35, green: 0.78, blue: 0.98, alpha: 1.0),
            secondaryButtonLabel: nil
        )
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        return configuration(shielding: webDomain)
    }
}
