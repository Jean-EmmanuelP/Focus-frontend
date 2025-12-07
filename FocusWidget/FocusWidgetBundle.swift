//
//  FocusWidgetBundle.swift
//  FocusWidget
//
//  Created by Jean-Emmanuel on 06/12/2025.
//

import WidgetKit
import SwiftUI

@main
struct FocusWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Main Focus Widget - shows stats, timer, and allows starting sessions
        FocusWidget()

        // Daily Rituals Widget - track habits
        RitualsWidget()

        // Today's Intentions Widget - morning check-in goals
        IntentionsWidget()

        // Live Activity for active focus sessions (Dynamic Island + Lock Screen)
        FocusSessionLiveActivity()
    }
}
