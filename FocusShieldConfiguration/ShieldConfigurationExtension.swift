//
//  ShieldConfigurationExtension.swift
//  FocusShieldConfiguration
//
//  Custom Shield Configuration for blocked apps during Focus sessions
//  Theme: "Salle du temps" - Sacred space for deep focus
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Custom Shield Configuration Extension
/// Displays personalized Volta-themed message when user tries to open a blocked app
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    // MARK: - Theme Colors
    private let backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1.0) // #050508
    private let primaryColor = UIColor(red: 0.35, green: 0.78, blue: 0.98, alpha: 1.0) // #5AC8FA sky blue
    private let subtitleColor = UIColor.white.withAlphaComponent(0.6)

    // MARK: - Motivational Messages
    private let appMessages = [
        "Tu es dans la salle du temps.\nChaque seconde compte.",
        "Ton futur toi te remercie.\nReste focus.",
        "La distraction peut attendre.\nPas tes rêves.",
        "Ce moment de focus\nte rapproche de tes objectifs.",
        "Tu as choisi d'être ici.\nHonore ce choix."
    ]

    private let webMessages = [
        "Internet peut attendre.\nTes objectifs, non.",
        "Ce site ne t'aidera pas\nà atteindre tes rêves.",
        "Chaque minute de focus\nest un pas vers ta meilleure version.",
        "Tu es plus fort que la tentation.\nContinue.",
        "La salle du temps est sacrée.\nProtège-la."
    ]

    private func randomAppMessage() -> String {
        appMessages.randomElement() ?? appMessages[0]
    }

    private func randomWebMessage() -> String {
        webMessages.randomElement() ?? webMessages[0]
    }

    // MARK: - Shield Configuration for Apps

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        return ShieldConfiguration(
            backgroundBlurStyle: .dark,
            backgroundColor: backgroundColor,
            icon: UIImage(systemName: "sparkles"),
            title: ShieldConfiguration.Label(
                text: "Mode Focus Actif",
                color: primaryColor
            ),
            subtitle: ShieldConfiguration.Label(
                text: randomAppMessage(),
                color: subtitleColor
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Retourner au Focus",
                color: UIColor.black
            ),
            primaryButtonBackgroundColor: primaryColor,
            secondaryButtonLabel: nil
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        return configuration(shielding: application)
    }

    // MARK: - Shield Configuration for Web Domains

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        return ShieldConfiguration(
            backgroundBlurStyle: .dark,
            backgroundColor: backgroundColor,
            icon: UIImage(systemName: "lock.shield"),
            title: ShieldConfiguration.Label(
                text: "Site Protégé",
                color: primaryColor
            ),
            subtitle: ShieldConfiguration.Label(
                text: randomWebMessage(),
                color: subtitleColor
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Retourner au Focus",
                color: UIColor.black
            ),
            primaryButtonBackgroundColor: primaryColor,
            secondaryButtonLabel: nil
        )
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        return configuration(shielding: webDomain)
    }
}
