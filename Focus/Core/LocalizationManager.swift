import Foundation
import SwiftUI
import Combine

// MARK: - Supported Languages
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case french = "fr"
    case spanish = "es"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .french: return "Français"
        case .spanish: return "Español"
        }
    }

    var flag: String {
        switch self {
        case .system: return "🌐"
        case .english: return "🇬🇧"
        case .french: return "🇫🇷"
        case .spanish: return "🇪🇸"
        }
    }

    var localeIdentifier: String? {
        switch self {
        case .system: return nil
        case .english: return "en"
        case .french: return "fr"
        case .spanish: return "es"
        }
    }
}

// MARK: - Localization Manager
@MainActor
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    private let languageKey = "app_language"

    // Static translations dictionary as fallback
    private static let translations: [String: [String: String]] = [
        "en": LocalizationManager.englishTranslations,
        "fr": LocalizationManager.frenchTranslations,
        "es": LocalizationManager.spanishTranslations
    ]

    @Published var currentLanguage: AppLanguage {
        didSet {
            saveLanguage()
            updateBundle()
        }
    }

    @Published private(set) var bundle: Bundle = .main

    private init() {
        // Load saved language or default to system
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = .system
        }
        updateBundle()
    }

    private func saveLanguage() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
    }

    private func updateBundle() {
        if let localeIdentifier = currentLanguage.localeIdentifier,
           let path = Bundle.main.path(forResource: localeIdentifier, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.bundle = bundle
        } else {
            // Use device language for system setting
            self.bundle = .main
        }
    }

    func localizedString(_ key: String) -> String {
        // First try bundle localization
        let bundleValue = bundle.localizedString(forKey: key, value: "##NOT_FOUND##", table: nil)
        if bundleValue != "##NOT_FOUND##" && bundleValue != key {
            return bundleValue
        }

        // Fallback to hardcoded translations
        let langCode = effectiveLanguageCode
        if let translation = LocalizationManager.translations[langCode]?[key] {
            return translation
        }

        // Default to English if not found in current language
        if langCode != "en", let translation = LocalizationManager.translations["en"]?[key] {
            return translation
        }

        // Return key as last resort
        return key
    }

    var effectiveLanguageCode: String {
        if let localeId = currentLanguage.localeIdentifier {
            return localeId
        }
        // System language - detect device language
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        if preferredLanguage.starts(with: "fr") {
            return "fr"
        }
        if preferredLanguage.starts(with: "es") {
            return "es"
        }
        return "en"
    }
}

// MARK: - String Extension for Localization
extension String {
    var localized: String {
        return LocalizationManager.shared.localizedString(self)
    }

    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}

// MARK: - Localization Keys
enum L10n {
    // MARK: - Common
    static var done: String { "common.done".localized }
    static var cancel: String { "common.cancel".localized }
    static var save: String { "common.save".localized }
    static var delete: String { "common.delete".localized }
    static var edit: String { "common.edit".localized }
    static var error: String { "common.error".localized }
    static var retry: String { "common.retry".localized }
    static var loading: String { "common.loading".localized }
    static var ok: String { "common.ok".localized }
    static var yes: String { "common.yes".localized }
    static var no: String { "common.no".localized }

    // MARK: - Tabs
    static var tabDashboard: String { "tab.dashboard".localized }
    static var tabFire: String { "tab.fire".localized }
    static var tabQuests: String { "tab.quests".localized }
    static var tabCrew: String { "tab.crew".localized }

    // MARK: - Dashboard
    static var dashboardTitle: String { "dashboard.title".localized }
    static var dashboardGoodMorning: String { "dashboard.good_morning".localized }
    static var dashboardGoodAfternoon: String { "dashboard.good_afternoon".localized }
    static var dashboardGoodEvening: String { "dashboard.good_evening".localized }
    static var dashboardStartDay: String { "dashboard.start_day".localized }
    static var dashboardEndDay: String { "dashboard.end_day".localized }
    static var dashboardTodaysRoutines: String { "dashboard.todays_routines".localized }
    static var dashboardFocusTime: String { "dashboard.focus_time".localized }
    static var dashboardStreak: String { "dashboard.streak".localized }
    static var dashboardDayStreak: String { "dashboard.day_streak".localized }
    static var dashboardWeeklyProgress: String { "dashboard.weekly_progress".localized }

    // MARK: - Fire Mode
    static var fireTitle: String { "fire.title".localized }
    static var fireStartSession: String { "fire.start_session".localized }
    static var fireStopSession: String { "fire.stop_session".localized }
    static var fireMinutes: String { "fire.minutes".localized }
    static var fireSessionsToday: String { "fire.sessions_today".localized }
    static var fireSessionsThisWeek: String { "fire.sessions_this_week".localized }
    static var fireFocusTime: String { "fire.focus_time".localized }
    static var fireSelectQuest: String { "fire.select_quest".localized }
    static var fireNoQuest: String { "fire.no_quest".localized }
    static var fireDescription: String { "fire.description".localized }
    static var fireDescriptionPlaceholder: String { "fire.description_placeholder".localized }

    // MARK: - Quests
    static var questsTitle: String { "quests.title".localized }
    static var questsActive: String { "quests.active".localized }
    static var questsCompleted: String { "quests.completed".localized }
    static var questsAddQuest: String { "quests.add_quest".localized }
    static var questsProgress: String { "quests.progress".localized }
    static var questsNoQuests: String { "quests.no_quests".localized }

    // MARK: - Routines
    static var routinesTitle: String { "routines.title".localized }
    static var routinesDaily: String { "routines.daily".localized }
    static var routinesCompleted: String { "routines.completed".localized }
    static var routinesAddRoutine: String { "routines.add_routine".localized }
    static var routinesNoRoutines: String { "routines.no_routines".localized }

    // MARK: - Crew
    static var crewTitle: String { "crew.title".localized }
    static var crewLeaderboard: String { "crew.leaderboard".localized }
    static var crewMyCrew: String { "crew.my_crew".localized }
    static var crewRequests: String { "crew.requests".localized }
    static var crewAccount: String { "crew.account".localized }
    static var crewTopBuilders: String { "crew.top_builders".localized }
    static var crewThisWeek: String { "crew.this_week".localized }
    static var crewSearch: String { "crew.search".localized }
    static var crewSearchPlaceholder: String { "crew.search_placeholder".localized }
    static var crewPending: String { "crew.pending".localized }
    static var crewAccept: String { "crew.accept".localized }
    static var crewReject: String { "crew.reject".localized }
    static var crewRemove: String { "crew.remove".localized }
    static var crewNoMembers: String { "crew.no_members".localized }
    static var crewNoRequests: String { "crew.no_requests".localized }
    static var crewIncoming: String { "crew.incoming".localized }
    static var crewOutgoing: String { "crew.outgoing".localized }

    // MARK: - Profile / Account
    static var profileTitle: String { "profile.title".localized }
    static var profileMyStatistics: String { "profile.my_statistics".localized }
    static var profileDayVisibility: String { "profile.day_visibility".localized }
    static var profileVisibilityDescription: String { "profile.visibility_description".localized }
    static var profilePublic: String { "profile.public".localized }
    static var profilePublicDesc: String { "profile.public_desc".localized }
    static var profileCrewOnly: String { "profile.crew_only".localized }
    static var profileCrewOnlyDesc: String { "profile.crew_only_desc".localized }
    static var profilePrivate: String { "profile.private".localized }
    static var profilePrivateDesc: String { "profile.private_desc".localized }
    static var profileLanguage: String { "profile.language".localized }
    static var profileSignOut: String { "profile.sign_out".localized }
    static var profileSignOutConfirm: String { "profile.sign_out_confirm".localized }

    // MARK: - Statistics
    static var statsTitle: String { "stats.title".localized }
    static var statsWeek: String { "stats.week".localized }
    static var statsMonth: String { "stats.month".localized }
    static var statsFocusTime: String { "stats.focus_time".localized }
    static var statsAvgDaily: String { "stats.avg_daily".localized }
    static var statsRoutines: String { "stats.routines".localized }
    static var statsCompletion: String { "stats.completion".localized }
    static var statsCompleted: String { "stats.completed".localized }
    static var statsThisWeek: String { "stats.this_week".localized }
    static var statsThisMonth: String { "stats.this_month".localized }
    static var statsLast7Days: String { "stats.last_7_days".localized }
    static var statsLast30Days: String { "stats.last_30_days".localized }
    static var statsFocusSessions: String { "stats.focus_sessions".localized }
    static var statsDailyRoutines: String { "stats.daily_routines".localized }
    static var statsNoSessions: String { "stats.no_sessions".localized }
    static var statsNoRoutines: String { "stats.no_routines".localized }
    static var statsViewStats: String { "stats.view_stats".localized }

    // MARK: - Start The Day
    static var startDayTitle: String { "start_day.title".localized }
    static var startDayHowFeeling: String { "start_day.how_feeling".localized }
    static var startDaySleepQuality: String { "start_day.sleep_quality".localized }
    static var startDayIntentions: String { "start_day.intentions".localized }
    static var startDayAddIntention: String { "start_day.add_intention".localized }
    static var startDayLetsGo: String { "start_day.lets_go".localized }

    // MARK: - End of Day
    static var endDayTitle: String { "end_day.title".localized }
    static var endDayBiggestWin: String { "end_day.biggest_win".localized }
    static var endDayChallenges: String { "end_day.challenges".localized }
    static var endDayBestMoment: String { "end_day.best_moment".localized }
    static var endDayTomorrowGoal: String { "end_day.tomorrow_goal".localized }
    static var endDayComplete: String { "end_day.complete".localized }

    // MARK: - Time Formatting
    static var timeHours: String { "time.hours".localized }
    static var timeMinutes: String { "time.minutes".localized }
    static var timeH: String { "time.h".localized }
    static var timeM: String { "time.m".localized }
    static var timeDays: String { "time.days".localized }
    static var timeToday: String { "time.today".localized }
    static var timeYesterday: String { "time.yesterday".localized }

    // MARK: - Errors
    static var errorGeneric: String { "error.generic".localized }
    static var errorNetwork: String { "error.network".localized }
    static var errorLoadingData: String { "error.loading_data".localized }
    static var errorSaving: String { "error.saving".localized }
}

// MARK: - Hardcoded Translations Fallback
extension LocalizationManager {
    static let englishTranslations: [String: String] = [
        // Common
        "common.done": "Done",
        "common.cancel": "Cancel",
        "common.save": "Save",
        "common.delete": "Delete",
        "common.edit": "Edit",
        "common.error": "Error",
        "common.retry": "Retry",
        "common.loading": "Loading...",
        "common.ok": "OK",
        "common.yes": "Yes",
        "common.no": "No",
        "common.back": "Back",
        "common.continue": "Continue",
        "common.close": "Close",
        "common.add": "Add",
        "common.remove": "Remove",
        "common.none": "None",
        "common.show_less": "Show less",
        "common.see_all": "See all %d",
        "common.see_more": "See %d more",
        "common.manage": "Manage",
        "common.new": "New",

        // Welcome / Splash
        "welcome.title": "Welcome to Volta",
        "welcome.subtitle": "Your path to success starts here",
        "welcome.loading": "Preparing your experience...",

        // Auth / Sign In
        "auth.tagline": "Ship your side project",
        "auth.feature.focus": "Deep focus sessions",
        "auth.feature.quests": "Track quests and goals",
        "auth.feature.habits": "Level up with habits",
        "auth.feature.rituals": "Daily rituals",
        "auth.terms.agree": "By continuing, you agree to our",
        "auth.terms.tos": "Terms of Service",
        "auth.terms.and": "and",
        "auth.terms.privacy": "Privacy Policy",
        "auth.sign_in_apple": "Sign in with Apple",
        "auth.signing_in": "Signing in...",
        "auth.error_title": "Sign In Error",

        // Tabs
        "tab.dashboard": "Dashboard",
        "tab.fire": "Fire",
        "tab.quests": "Quests",
        "tab.crew": "Crew",

        // Dashboard
        "dashboard.title": "VOLTA",
        "dashboard.subtitle": "A new day to ship your project.",
        "dashboard.good_morning": "Good morning",
        "dashboard.good_afternoon": "Good afternoon",
        "dashboard.good_evening": "Good evening",
        "dashboard.start_day": "Start Your Day",
        "dashboard.end_day": "End Your Day",
        "dashboard.todays_routines": "Today's Routines",
        "dashboard.todays_intentions": "Today's Intentions",
        "dashboard.daily_habits": "Daily Habits",
        "dashboard.evening_reflection": "Evening Reflection",
        "dashboard.focus_time": "Focus Time",
        "dashboard.streak": "Streak",
        "dashboard.day_streak": "day streak",
        "dashboard.weekly_progress": "Weekly Progress",
        "dashboard.sessions_this_week": "Sessions This Week",
        "dashboard.loading": "Loading your dashboard...",
        "dashboard.focused_today": "Focused Today",
        "dashboard.swipe_hint": "Swipe left to edit or delete",
        "dashboard.motivational": "You're progressing. Even on tough days.",

        // Fire Mode
        "fire.title": "FIREMODE",
        "fire.subtitle": "Deep focus. Zero distraction.",
        "fire.start_session": "Start Focus Session",
        "fire.stop_session": "Stop Session",
        "fire.pause": "Pause",
        "fire.resume": "Resume",
        "fire.focus": "Focus",
        "fire.paused": "Paused",
        "fire.complete": "Complete!",
        "fire.great_work": "Great work! Session logged.",
        "fire.ready_to_focus": "Ready to focus?",
        "fire.ready_subtitle": "Start your first session and build momentum",
        "fire.duration": "Duration",
        "fire.minutes": "minutes",
        "fire.sessions_today": "Today's Sessions",
        "fire.sessions_this_week": "Sessions this week",
        "fire.focus_time": "Focus time",
        "fire.link_quest": "Link to Quest (optional)",
        "fire.select_quest": "Select a quest...",
        "fire.no_active_quests": "No active quests",
        "fire.no_quest": "No quest selected",
        "fire.description": "What will you work on?",
        "fire.description_placeholder": "Describe your focus area...",
        "fire.log_past_session": "Log Past Session",
        "fire.custom": "Custom",
        "fire.when": "When?",
        "fire.session_time": "Session time",
        "fire.what_worked_on": "What did you work on?",
        "fire.log_session": "Log Session",
        "fire.focus_session": "Focus session",
        "fire.manual": "Manual",
        "fire.start_firemode": "Start FireMode",
        "fire.launch_session": "Launch a focus session now",
        "fire.delete_session": "Delete Session?",
        "fire.delete_session_confirm": "This will permanently delete this focus session.",

        // Quests
        "quests.title": "QUESTS",
        "quests.subtitle": "Track your progress and build habits.",
        "quests.active": "Active",
        "quests.completed": "Completed",
        "quests.add_quest": "Add Quest",
        "quests.new_quest": "New Quest",
        "quests.progress": "Progress",
        "quests.no_quests": "No quests yet",
        "quests.quest_title": "Quest title",
        "quests.target": "Target (optional)",
        "quests.target_hint": "How many times do you want to achieve this?",
        "quests.current_progress": "Current Progress",
        "quests.progress_hint": "Use the slider on the quest card to update progress",
        "quests.mark_complete": "Mark as Complete",
        "quests.swipe_hint": "Swipe right to complete",
        "quests.areas": "Areas",
        "quests.quests": "Quests",
        "quests.no_areas": "No areas tracked yet",
        "quests.no_areas_hint": "Create quests to see your progress by area",
        "quests.no_quests_hint": "Create your first quest to start tracking progress",
        "quests.create_quest": "Create Quest",
        "quests.quest_placeholder": "e.g., Read 12 books, Run a marathon...",
        "quests.edit_quest": "Edit Quest",
        "quests.delete_quest": "Delete Quest",
        "quests.delete_confirm": "This action cannot be undone.",
        "quests.quest_details": "Quest Details",
        "quests.target_date": "Target Date",
        "quests.update_progress": "Update Progress",
        "quests.swipe_to_update": "Swipe to update progress",
        "quests.deadline": "Deadline",
        "quests.deadline_hint": "Set a target date for completing this quest (optional)",
        "quests.no_deadline": "No deadline",
        "quests.due_by": "Due by %@",

        // Routines / Rituals
        "routines.title": "Daily Rituals",
        "routines.subtitle": "Build daily habits that compound over time",
        "routines.daily": "Daily Routines",
        "routines.completed": "Completed",
        "routines.add_routine": "Add Ritual",
        "routines.new_ritual": "New Ritual",
        "routines.edit_ritual": "Edit Ritual",
        "routines.no_routines": "No rituals yet",
        "routines.no_routines_hint": "Create daily rituals to build consistency and track your progress",
        "routines.add_first": "Add Your First Ritual",
        "routines.total": "Total",
        "routines.done_today": "Done today",
        "routines.swipe_hint": "Swipe right to complete, left to edit/delete",
        "routines.delete_ritual": "Delete Ritual",
        "routines.delete_confirm": "Delete Ritual?",
        "routines.delete_message": "Are you sure you want to delete \"%@\"? This action cannot be undone.",
        "routines.choose_icon": "Choose an icon",
        "routines.ritual_name": "Ritual name",
        "routines.ritual_placeholder": "e.g., Morning workout, Read 30 min...",
        "routines.life_area": "Life area",
        "routines.no_areas": "No areas available",
        "routines.frequency": "Frequency",
        "routines.frequency.daily": "Daily",
        "routines.frequency.weekdays": "Weekdays",
        "routines.frequency.weekends": "Weekends",
        "routines.frequency.weekly": "Weekly",
        "routines.create": "Create Ritual",
        "routines.save_changes": "Save Changes",
        "routines.loading_areas": "Loading areas...",
        "routines.no_scheduled": "No rituals scheduled for today",
        "routines.scheduled_time": "Scheduled Time",
        "routines.scheduled_time_hint": "Set a specific time for this ritual (optional)",
        "routines.no_time": "No specific time",
        "routines.at_time": "at %@",

        // Crew
        "crew.title": "CREW",
        "crew.subtitle": "Build together. Grow together.",
        "crew.leaderboard": "Leaderboard",
        "crew.my_crew": "My Crew",
        "crew.requests": "Requests",
        "crew.account": "Account",
        "crew.top_builders": "Top Builders This Week",
        "crew.your_crew": "Your Crew",
        "crew.members": "members",
        "crew.this_week": "this week",
        "crew.search": "Search",
        "crew.search_placeholder": "Search users...",
        "crew.no_users_found": "No users found",
        "crew.pending": "Pending",
        "crew.respond": "Respond",
        "crew.accept": "Accept",
        "crew.reject": "Reject",
        "crew.in_crew": "In Crew",
        "crew.remove": "Remove",
        "crew.no_members": "No crew members yet",
        "crew.no_requests": "No pending requests",
        "crew.received_requests": "Received Requests",
        "crew.sent_requests": "Sent Requests",
        "crew.incoming": "Incoming",
        "crew.outgoing": "Outgoing",
        "crew.remove_confirm": "Are you sure you want to remove %@ from your crew?",
        "crew.search_hint": "Search for users and send them a crew request",
        "crew.start_session_hint": "Start a focus session to appear on the leaderboard",
        "crew.requests_hint": "When someone wants to join your crew, it will appear here",
        "crew.no_sent_requests": "No sent requests",
        "crew.search_to_send": "Search for users to send crew requests",
        "crew.crew_member": "Crew Member",
        "crew.day_not_visible": "Day Not Visible",
        "crew.day_private": "This user has their day set to private",
        "crew.no_activity": "No activity this day",
        "crew.intentions": "Intentions",
        "crew.focus_sessions": "Focus Sessions",
        "crew.sessions": "sessions",
        "crew.completed_routines": "Completed Routines",
        "crew.done": "done",
        "crew.focus_this_week": "focus this week",
        "crew.routines_done": "routines done",
        "crew.like": "Like",
        "crew.unlike": "Unlike",
        "crew.likes": "%d likes",
        "crew.1_like": "1 like",
        "crew.suggested": "Suggested for you",
        "crew.suggested_hint": "People you might want to add to your crew",

        // Profile / Account
        "profile.title": "Profile",
        "profile.level": "Level %d",
        "profile.my_statistics": "My Statistics",
        "profile.day_visibility": "Day Visibility",
        "profile.visibility_description": "Control who can see your daily activity",
        "profile.public": "Public",
        "profile.public_desc": "Anyone can see your day",
        "profile.crew_only": "Crew Only",
        "profile.crew_only_desc": "Only crew members can see",
        "profile.private": "Private",
        "profile.private_desc": "Nobody can see your day",
        "profile.language": "Language",
        "profile.sign_out": "Sign Out",
        "profile.sign_out_title": "Sign Out",
        "profile.sign_out_confirm": "Are you sure you want to sign out?",
        "profile.language_change_title": "Change Language",
        "profile.language_change_message": "The app needs to restart to apply the language change.",
        "profile.restart_app": "Restart",
        "profile.version": "Volta v1.0.0",
        "profile.guest_account": "Guest Account",

        // Statistics
        "stats.title": "Statistics",
        "stats.my_statistics": "My Statistics",
        "stats.member_stats": "%@'s Stats",
        "stats.week": "Week",
        "stats.month": "Month",
        "stats.focus_time": "Focus Time",
        "stats.avg_daily": "Avg. Daily",
        "stats.routines": "Routines",
        "stats.completion": "Completion",
        "stats.completed": "completed",
        "stats.rate": "rate",
        "stats.this_week": "this week",
        "stats.this_month": "this month",
        "stats.last_7_days": "Last 7 days",
        "stats.last_30_days": "Last 30 days",
        "stats.focus_sessions": "Focus Sessions",
        "stats.daily_routines": "Daily Routines",
        "stats.no_sessions": "No focus sessions yet",
        "stats.no_routines": "No routines completed yet",
        "stats.view_stats": "View Stats",
        "stats.failed_to_load": "Failed to load statistics",

        // Visibility
        "visibility.public": "Public",
        "visibility.crew": "Crew Only",
        "visibility.private": "Private",
        "visibility.public_desc": "Anyone can see your day",
        "visibility.crew_desc": "Only crew members can see",
        "visibility.private_desc": "Nobody can see your day",

        // Start The Day
        "start_day.title": "Start Your Day",
        "start_day.greeting_morning": "Good Morning!",
        "start_day.greeting_afternoon": "Good Afternoon!",
        "start_day.greeting_evening": "Good Evening!",
        "start_day.subtitle": "Take a moment to set the tone for a focused and productive day.",
        "start_day.how_feeling": "How are you feeling?",
        "start_day.feeling_hint": "Select the emotion that best describes your current state",
        "start_day.add_note": "Add a note (optional)",
        "start_day.note_placeholder": "What's on your mind this morning?",
        "start_day.sleep_quality": "How was your sleep?",
        "start_day.sleep_hint": "Rate your rest quality from 1 to 10",
        "start_day.poor": "Poor",
        "start_day.excellent": "Excellent",
        "start_day.sleep_notes": "Sleep notes (optional)",
        "start_day.sleep_placeholder": "Any thoughts about your sleep?",
        "start_day.intentions": "Today's Intentions",
        "start_day.intention_1": "Intention 1",
        "start_day.intention_2": "Intention 2",
        "start_day.intention_3": "Intention 3",
        "start_day.intention_placeholder": "What will you focus on?",
        "start_day.life_area": "Life area",
        "start_day.review": "Review Your Day",
        "start_day.confirm_subtitle": "Confirm your morning check-in",
        "start_day.not_set": "Not set",
        "start_day.feeling": "Feeling",
        "start_day.focus_areas": "Today's focus areas",
        "start_day.start_my_day": "Start My Day",
        "start_day.lets_go": "Let's Go",
        "start_day.youre_ready": "You're Ready!",
        "start_day.ready_subtitle": "Your intentions are set.\nTime to make it happen!",
        "start_day.sleep_1": "Very poor rest",
        "start_day.sleep_3": "Could be better",
        "start_day.sleep_5": "Decent sleep",
        "start_day.sleep_7": "Good rest",
        "start_day.sleep_10": "Excellent recovery!",
        "start_day.step_indicator": "Step %d of %d",
        "start_day.step.welcome": "Welcome",
        "start_day.step.welcome_subtitle": "Let's start your day right",
        "start_day.step.sleep_subtitle": "How was your rest?",
        "start_day.step.intention1_subtitle": "What's your first priority?",
        "start_day.step.intention2_subtitle": "What else matters today?",
        "start_day.step.intention3_subtitle": "One more thing to focus on",
        "start_day.intention_prompt_1": "What's the most important thing you want to accomplish today?",
        "start_day.intention_prompt_2": "What else would make today feel successful?",
        "start_day.intention_prompt_3": "One more intention to round out your day",
        "start_day.intention_example_1": "e.g., Finish the project proposal",
        "start_day.intention_example_2": "e.g., 30 minutes of exercise",
        "start_day.intention_example_3": "e.g., Call a friend",

        // End of Day
        "end_day.title": "Evening Review",
        "end_day.time_to_reflect": "Time to Reflect",
        "end_day.subtitle": "Take a few minutes to review your day and prepare for tomorrow.",
        "end_day.lets_reflect": "Let's Reflect",
        "end_day.daily_rituals": "Daily Rituals",
        "end_day.your_rituals": "Your Daily Rituals",
        "end_day.rituals_hint": "Check off what you completed today",
        "end_day.rituals": "Rituals",
        "end_day.rituals_progress": "%d of %d completed",
        "end_day.rituals_completed": "%d/%d completed",
        "end_day.ideas": "Ideas to get started:",
        "end_day.biggest_win": "Biggest Win",
        "end_day.biggest_win_question": "What was your biggest win today?",
        "end_day.biggest_win_hint": "Celebrate your accomplishments, no matter how small",
        "end_day.biggest_win_placeholder": "I'm proud of...",
        "end_day.challenges": "Challenges",
        "end_day.challenges_question": "What challenged you today?",
        "end_day.challenges_hint": "Identifying obstacles helps you overcome them",
        "end_day.challenges_placeholder": "I struggled with...",
        "end_day.best_moment": "Best Moment",
        "end_day.best_moment_question": "What was your best moment?",
        "end_day.best_moment_hint": "Find the bright spots in your day",
        "end_day.best_moment_placeholder": "I felt happy when...",
        "end_day.tomorrow": "Tomorrow",
        "end_day.tomorrow_question": "What's your #1 goal for tomorrow?",
        "end_day.tomorrow_hint": "Set yourself up for success",
        "end_day.tomorrow_placeholder": "Tomorrow I will...",
        "end_day.tomorrow_goal": "Goal for Tomorrow",
        "end_day.summary": "Summary",
        "end_day.your_day_review": "Your Day in Review",
        "end_day.summary_hint": "Here's a summary of your reflection",
        "end_day.no_reflections": "No reflections added",
        "end_day.no_reflections_hint": "You can still complete your review, or go back to add some thoughts.",
        "end_day.day_complete": "Day Complete!",
        "end_day.rest_well": "Rest well. Tomorrow is a new opportunity.",
        "end_day.rituals_done": "Rituals Done",
        "end_day.goal_set": "Goal Set",
        "end_day.complete_review": "Complete Review",
        "end_day.good_night": "Good Night",
        "end_day.step_indicator": "Step %d of %d",
        "end_day.example_task": "Completed a difficult task",
        "end_day.example_helped": "Helped someone",
        "end_day.example_learned": "Learned something new",
        "end_day.example_focused": "Stayed focused",
        "end_day.example_distractions": "Distractions",
        "end_day.example_conversation": "Difficult conversation",
        "end_day.example_time": "Time management",
        "end_day.example_energy": "Low energy",
        "end_day.example_good_conversation": "A good conversation",
        "end_day.example_achieving": "Achieving a goal",
        "end_day.example_peaceful": "A peaceful moment",
        "end_day.example_funny": "Something funny",
        "end_day.example_project": "Complete project X",
        "end_day.example_exercise": "Exercise",
        "end_day.example_talk": "Have a difficult conversation",
        "end_day.example_learn": "Learn something new",

        // Time Formatting
        "time.hours": "hours",
        "time.minutes": "minutes",
        "time.h": "h",
        "time.m": "m",
        "time.days": "days",
        "time.day": "day",
        "time.days_short": "d",
        "time.day_short": "d",
        "time.today": "Today",
        "time.yesterday": "Yesterday",
        "time.ago": "ago",
        "time.just_now": "Just now",
        "time.1_day_ago": "1 day ago",
        "time.days_ago": "%d days ago",
        "time.1_hour_ago": "1 hour ago",
        "time.hours_ago": "%d hours ago",
        "time.1_min_ago": "1 min ago",
        "time.mins_ago": "%d min ago",

        // Streak
        "streak.active": "Active Streak",
        "streak.day_count": "Day %d",
        "streak.free_for": "You've been on fire for:",
        "streak.motivational": "A new day to make progress",
        "streak.name": "Name",
        "streak.since": "Streak since",
        "streak.start_today": "Start a focus session to begin your streak!",
        "streak.today_done": "Done",
        "streak.today_pending": "Pending",

        // CTA (Call to Action)
        "cta.start_day.title": "Start your day right",
        "cta.start_day.subtitle": "Complete your morning check-in",
        "cta.start_day.button": "Start the Day",
        "cta.fire_mode.title": "Start a FireMode session",
        "cta.fire_mode.subtitle": "Launch your first focus session",
        "cta.fire_mode.button": "Enter FireMode",
        "cta.end_day.title": "Complete your End of Day review",
        "cta.end_day.subtitle": "Reflect and close your day",
        "cta.end_day.button": "End of Day Review",
        "cta.completed.title": "You're all set for today",
        "cta.completed.subtitle": "Great work. Rest and prepare for tomorrow.",
        "cta.completed.button": "View Progress",

        // Errors
        "error.generic": "Something went wrong",
        "error.network": "Network error. Please try again.",
        "error.loading_data": "Failed to load data",
        "error.saving": "Failed to save",
        "error.update_visibility": "Failed to update visibility",

        // Feelings
        "feeling.happy": "Happy",
        "feeling.calm": "Calm",
        "feeling.neutral": "Neutral",
        "feeling.sad": "Sad",
        "feeling.anxious": "Anxious",
        "feeling.frustrated": "Frustrated",
        "feeling.excited": "Excited",
        "feeling.tired": "Tired",

        // Areas
        "area.health": "Health",
        "area.learning": "Learning",
        "area.career": "Career",
        "area.relationships": "Relations",
        "area.creativity": "Creativity",
        "area.other": "Other",

        // Legal
        "legal.privacy.title": "Privacy Policy",
        "legal.privacy.content": "Volta only collects the information necessary to create and secure your account (name, email, password via Apple Sign In). No data is shared with third parties. You can delete your account at any time. Questions? support@volta.app"
    ]

    static let frenchTranslations: [String: String] = [
        // Common
        "common.done": "Terminé",
        "common.cancel": "Annuler",
        "common.save": "Enregistrer",
        "common.delete": "Supprimer",
        "common.edit": "Modifier",
        "common.error": "Erreur",
        "common.retry": "Réessayer",
        "common.loading": "Chargement...",
        "common.ok": "OK",
        "common.yes": "Oui",
        "common.no": "Non",
        "common.back": "Retour",
        "common.continue": "Continuer",
        "common.close": "Fermer",
        "common.add": "Ajouter",
        "common.remove": "Retirer",
        "common.none": "Aucun",
        "common.show_less": "Voir moins",
        "common.see_all": "Voir tout (%d)",
        "common.see_more": "Voir %d de plus",
        "common.manage": "Gérer",
        "common.new": "Nouveau",

        // Welcome / Splash
        "welcome.title": "Bienvenue sur Volta",
        "welcome.subtitle": "Ton chemin vers le succès commence ici",
        "welcome.loading": "Préparation de ton expérience...",

        // Auth / Sign In
        "auth.tagline": "Lance ton side project",
        "auth.feature.focus": "Sessions de focus intense",
        "auth.feature.quests": "Suis tes quêtes et objectifs",
        "auth.feature.habits": "Progresse avec tes habitudes",
        "auth.feature.rituals": "Rituels quotidiens",
        "auth.terms.agree": "En continuant, tu acceptes nos",
        "auth.terms.tos": "Conditions d'utilisation",
        "auth.terms.and": "et",
        "auth.terms.privacy": "Politique de confidentialité",
        "auth.sign_in_apple": "Se connecter avec Apple",
        "auth.signing_in": "Connexion en cours...",
        "auth.error_title": "Erreur de connexion",

        // Tabs
        "tab.dashboard": "Tableau de bord",
        "tab.fire": "Fire",
        "tab.quests": "Quêtes",
        "tab.crew": "Équipe",

        // Dashboard
        "dashboard.title": "VOLTA",
        "dashboard.subtitle": "Un nouveau jour pour avancer sur ton projet.",
        "dashboard.good_morning": "Bonjour",
        "dashboard.good_afternoon": "Bon après-midi",
        "dashboard.good_evening": "Bonsoir",
        "dashboard.start_day": "Commence ta journée",
        "dashboard.end_day": "Termine ta journée",
        "dashboard.todays_routines": "Routines du jour",
        "dashboard.todays_intentions": "Intentions du jour",
        "dashboard.daily_habits": "Habitudes quotidiennes",
        "dashboard.evening_reflection": "Réflexion du soir",
        "dashboard.focus_time": "Temps de focus",
        "dashboard.streak": "Série",
        "dashboard.day_streak": "jours de suite",
        "dashboard.weekly_progress": "Progression hebdo",
        "dashboard.sessions_this_week": "Sessions cette semaine",
        "dashboard.loading": "Chargement du tableau de bord...",
        "dashboard.focused_today": "Focus aujourd'hui",
        "dashboard.swipe_hint": "Glisse à gauche pour modifier ou supprimer",
        "dashboard.motivational": "Tu progresses. Même les jours difficiles.",

        // Fire Mode
        "fire.title": "FIREMODE",
        "fire.subtitle": "Focus intense. Zéro distraction.",
        "fire.start_session": "Démarrer une session",
        "fire.stop_session": "Arrêter",
        "fire.pause": "Pause",
        "fire.resume": "Reprendre",
        "fire.focus": "Focus",
        "fire.paused": "En pause",
        "fire.complete": "Terminé !",
        "fire.great_work": "Bravo ! Session enregistrée.",
        "fire.ready_to_focus": "Prêt à te concentrer ?",
        "fire.ready_subtitle": "Lance ta première session et prends de l'élan",
        "fire.duration": "Durée",
        "fire.minutes": "minutes",
        "fire.sessions_today": "Sessions du jour",
        "fire.sessions_this_week": "Sessions cette semaine",
        "fire.focus_time": "Temps de focus",
        "fire.link_quest": "Lier à une quête (optionnel)",
        "fire.select_quest": "Sélectionne une quête...",
        "fire.no_active_quests": "Aucune quête active",
        "fire.no_quest": "Aucune quête sélectionnée",
        "fire.description": "Sur quoi vas-tu travailler ?",
        "fire.description_placeholder": "Décris ton domaine de focus...",
        "fire.log_past_session": "Ajouter une session passée",
        "fire.when": "Quand ?",
        "fire.session_time": "Durée de la session",
        "fire.what_worked_on": "Sur quoi as-tu travaillé ?",
        "fire.log_session": "Enregistrer",
        "fire.focus_session": "Session focus",
        "fire.manual": "Manuel",
        "fire.start_firemode": "Lancer FireMode",
        "fire.launch_session": "Lance une session de focus maintenant",
        "fire.delete_session": "Supprimer la session ?",
        "fire.delete_session_confirm": "Cette action supprimera définitivement cette session.",

        // Quests
        "quests.title": "QUÊTES",
        "quests.subtitle": "Suis ta progression et construis des habitudes.",
        "quests.active": "Actives",
        "quests.completed": "Terminées",
        "quests.add_quest": "Ajouter une quête",
        "quests.new_quest": "Nouvelle quête",
        "quests.progress": "Progression",
        "quests.no_quests": "Pas encore de quêtes",
        "quests.quest_title": "Titre de la quête",
        "quests.target": "Objectif (optionnel)",
        "quests.target_hint": "Combien de fois veux-tu accomplir cela ?",
        "quests.current_progress": "Progression actuelle",
        "quests.progress_hint": "Utilise le curseur sur la carte pour mettre à jour",
        "quests.mark_complete": "Marquer comme terminée",
        "quests.swipe_hint": "Glisse à droite pour terminer",
        "quests.areas": "Domaines",
        "quests.quests": "Quêtes",
        "quests.no_areas": "Aucun domaine suivi",
        "quests.no_areas_hint": "Crée des quêtes pour voir ta progression par domaine",
        "quests.no_quests_hint": "Crée ta première quête pour commencer",
        "quests.create_quest": "Créer une quête",
        "quests.quest_placeholder": "ex. Lire 12 livres, Courir un marathon...",
        "quests.edit_quest": "Modifier la quête",
        "quests.delete_quest": "Supprimer la quête",
        "quests.delete_confirm": "Cette action est irréversible.",
        "quests.quest_details": "Détails de la quête",
        "quests.target_date": "Date cible",
        "quests.update_progress": "Mettre à jour",
        "quests.swipe_to_update": "Glisse pour mettre à jour",
        "quests.deadline": "Échéance",
        "quests.deadline_hint": "Définis une date cible pour accomplir cette quête (optionnel)",
        "quests.no_deadline": "Pas d'échéance",
        "quests.due_by": "Pour le %@",

        // Routines / Rituals
        "routines.title": "Rituels quotidiens",
        "routines.subtitle": "Construis des habitudes qui s'accumulent",
        "routines.daily": "Routines quotidiennes",
        "routines.completed": "Complétées",
        "routines.add_routine": "Ajouter un rituel",
        "routines.new_ritual": "Nouveau rituel",
        "routines.edit_ritual": "Modifier le rituel",
        "routines.no_routines": "Pas encore de rituels",
        "routines.no_routines_hint": "Crée des rituels quotidiens pour construire ta régularité",
        "routines.add_first": "Ajoute ton premier rituel",
        "routines.total": "Total",
        "routines.done_today": "Faits aujourd'hui",
        "routines.swipe_hint": "Glisse à droite pour compléter, à gauche pour modifier",
        "routines.delete_ritual": "Supprimer le rituel",
        "routines.delete_confirm": "Supprimer le rituel ?",
        "routines.delete_message": "Es-tu sûr de vouloir supprimer \"%@\" ? Cette action est irréversible.",
        "routines.choose_icon": "Choisis une icône",
        "routines.ritual_name": "Nom du rituel",
        "routines.ritual_placeholder": "ex. Sport matinal, Lire 30 min...",
        "routines.life_area": "Domaine de vie",
        "routines.no_areas": "Aucun domaine disponible",
        "routines.frequency": "Fréquence",
        "routines.frequency.daily": "Quotidien",
        "routines.frequency.weekdays": "Semaine",
        "routines.frequency.weekends": "Week-end",
        "routines.frequency.weekly": "Hebdomadaire",
        "routines.create": "Créer le rituel",
        "routines.save_changes": "Enregistrer",
        "routines.loading_areas": "Chargement des domaines...",
        "routines.no_scheduled": "Aucun rituel prévu aujourd'hui",
        "routines.scheduled_time": "Heure prévue",
        "routines.scheduled_time_hint": "Définis une heure spécifique pour ce rituel (optionnel)",
        "routines.no_time": "Pas d'heure spécifique",
        "routines.at_time": "à %@",

        // Crew
        "crew.title": "ÉQUIPE",
        "crew.subtitle": "Construis ensemble. Progresse ensemble.",
        "crew.leaderboard": "Classement",
        "crew.my_crew": "Mon équipe",
        "crew.requests": "Demandes",
        "crew.account": "Compte",
        "crew.top_builders": "Top Builders cette semaine",
        "crew.your_crew": "Ton équipe",
        "crew.members": "membres",
        "crew.this_week": "cette semaine",
        "crew.search": "Rechercher",
        "crew.search_placeholder": "Rechercher des utilisateurs...",
        "crew.no_users_found": "Aucun utilisateur trouvé",
        "crew.pending": "En attente",
        "crew.respond": "Répondre",
        "crew.accept": "Accepter",
        "crew.reject": "Refuser",
        "crew.in_crew": "Dans l'équipe",
        "crew.remove": "Retirer",
        "crew.no_members": "Pas encore de membres",
        "crew.no_requests": "Aucune demande en attente",
        "crew.received_requests": "Demandes reçues",
        "crew.sent_requests": "Demandes envoyées",
        "crew.incoming": "Reçues",
        "crew.outgoing": "Envoyées",
        "crew.remove_confirm": "Es-tu sûr de vouloir retirer %@ de ton équipe ?",
        "crew.search_hint": "Recherche des utilisateurs pour leur envoyer une demande",
        "crew.start_session_hint": "Lance une session de focus pour apparaître dans le classement",
        "crew.requests_hint": "Quand quelqu'un veut rejoindre ton équipe, ça apparaîtra ici",
        "crew.no_sent_requests": "Aucune demande envoyée",
        "crew.search_to_send": "Recherche des utilisateurs pour envoyer des demandes",
        "crew.crew_member": "Membre de l'équipe",
        "crew.day_not_visible": "Journée non visible",
        "crew.day_private": "Cet utilisateur a mis sa journée en privé",
        "crew.no_activity": "Aucune activité ce jour",
        "crew.intentions": "Intentions",
        "crew.focus_sessions": "Sessions focus",
        "crew.sessions": "sessions",
        "crew.completed_routines": "Routines complétées",
        "crew.done": "faits",
        "crew.focus_this_week": "focus cette semaine",
        "crew.routines_done": "routines faites",
        "crew.like": "J'aime",
        "crew.unlike": "Je n'aime plus",
        "crew.likes": "%d j'aime",
        "crew.1_like": "1 j'aime",
        "crew.suggested": "Suggestions pour toi",
        "crew.suggested_hint": "Des personnes que tu pourrais ajouter à ton équipe",

        // Profile / Account
        "profile.title": "Profil",
        "profile.level": "Niveau %d",
        "profile.my_statistics": "Mes statistiques",
        "profile.day_visibility": "Visibilité de la journée",
        "profile.visibility_description": "Contrôle qui peut voir ton activité",
        "profile.public": "Public",
        "profile.public_desc": "Tout le monde peut voir ta journée",
        "profile.crew_only": "Équipe uniquement",
        "profile.crew_only_desc": "Seuls les membres de ton équipe peuvent voir",
        "profile.private": "Privé",
        "profile.private_desc": "Personne ne peut voir ta journée",
        "profile.language": "Langue",
        "profile.sign_out": "Se déconnecter",
        "profile.sign_out_title": "Se déconnecter",
        "profile.sign_out_confirm": "Es-tu sûr de vouloir te déconnecter ?",
        "profile.language_change_title": "Changer de langue",
        "profile.language_change_message": "L'application doit redémarrer pour appliquer le changement de langue.",
        "profile.restart_app": "Redémarrer",
        "profile.version": "Volta v1.0.0",
        "profile.guest_account": "Compte invité",

        // Statistics
        "stats.title": "Statistiques",
        "stats.my_statistics": "Mes statistiques",
        "stats.member_stats": "Stats de %@",
        "stats.week": "Semaine",
        "stats.month": "Mois",
        "stats.focus_time": "Temps de focus",
        "stats.avg_daily": "Moy. quotidienne",
        "stats.routines": "Routines",
        "stats.completion": "Complétion",
        "stats.completed": "complétées",
        "stats.rate": "taux",
        "stats.this_week": "cette semaine",
        "stats.this_month": "ce mois",
        "stats.last_7_days": "7 derniers jours",
        "stats.last_30_days": "30 derniers jours",
        "stats.focus_sessions": "Sessions focus",
        "stats.daily_routines": "Routines quotidiennes",
        "stats.no_sessions": "Pas encore de sessions focus",
        "stats.no_routines": "Pas encore de routines complétées",
        "stats.view_stats": "Voir les stats",
        "stats.failed_to_load": "Échec du chargement des statistiques",

        // Visibility
        "visibility.public": "Public",
        "visibility.crew": "Équipage seulement",
        "visibility.private": "Privé",
        "visibility.public_desc": "Tout le monde peut voir ta journée",
        "visibility.crew_desc": "Seul ton équipage peut voir",
        "visibility.private_desc": "Personne ne peut voir ta journée",

        // Start The Day
        "start_day.title": "Commence ta journée",
        "start_day.greeting_morning": "Bonjour !",
        "start_day.greeting_afternoon": "Bon après-midi !",
        "start_day.greeting_evening": "Bonsoir !",
        "start_day.subtitle": "Prends un moment pour te mettre dans le bon état d'esprit.",
        "start_day.how_feeling": "Comment te sens-tu ?",
        "start_day.feeling_hint": "Sélectionne l'émotion qui décrit le mieux ton état actuel",
        "start_day.add_note": "Ajoute une note (optionnel)",
        "start_day.note_placeholder": "Qu'as-tu en tête ce matin ?",
        "start_day.sleep_quality": "Comment as-tu dormi ?",
        "start_day.sleep_hint": "Note la qualité de ton repos de 1 à 10",
        "start_day.poor": "Mal",
        "start_day.excellent": "Excellent",
        "start_day.sleep_notes": "Notes sur le sommeil (optionnel)",
        "start_day.sleep_placeholder": "Des remarques sur ton sommeil ?",
        "start_day.intentions": "Intentions du jour",
        "start_day.intention_1": "Intention 1",
        "start_day.intention_2": "Intention 2",
        "start_day.intention_3": "Intention 3",
        "start_day.intention_placeholder": "Sur quoi vas-tu te concentrer ?",
        "start_day.life_area": "Domaine de vie",
        "start_day.review": "Récapitulatif",
        "start_day.confirm_subtitle": "Confirme ton check-in matinal",
        "start_day.not_set": "Non défini",
        "start_day.feeling": "Humeur",
        "start_day.focus_areas": "Objectifs du jour",
        "start_day.start_my_day": "Commencer ma journée",
        "start_day.lets_go": "C'est parti !",
        "start_day.youre_ready": "Tu es prêt !",
        "start_day.ready_subtitle": "Tes intentions sont définies.\nÀ toi de jouer !",
        "start_day.sleep_1": "Très mauvais repos",
        "start_day.sleep_3": "Pourrait être mieux",
        "start_day.sleep_5": "Sommeil correct",
        "start_day.sleep_7": "Bon repos",
        "start_day.sleep_10": "Excellente récupération !",
        "start_day.step_indicator": "Étape %d sur %d",
        "start_day.step.welcome": "Bienvenue",
        "start_day.step.welcome_subtitle": "Commençons bien ta journée",
        "start_day.step.sleep_subtitle": "Comment était ton repos ?",
        "start_day.step.intention1_subtitle": "Quelle est ta priorité ?",
        "start_day.step.intention2_subtitle": "Quoi d'autre compte aujourd'hui ?",
        "start_day.step.intention3_subtitle": "Une dernière chose à garder en tête",
        "start_day.intention_prompt_1": "Quelle est la chose la plus importante que tu veux accomplir aujourd'hui ?",
        "start_day.intention_prompt_2": "Quoi d'autre rendrait cette journée réussie ?",
        "start_day.intention_prompt_3": "Une dernière intention pour compléter ta journée",
        "start_day.intention_example_1": "ex. Terminer la proposition de projet",
        "start_day.intention_example_2": "ex. 30 minutes d'exercice",
        "start_day.intention_example_3": "ex. Appeler un ami",

        // End of Day
        "end_day.title": "Bilan du soir",
        "end_day.time_to_reflect": "Temps de réflexion",
        "end_day.subtitle": "Prends quelques minutes pour faire le bilan et préparer demain.",
        "end_day.lets_reflect": "Réfléchissons",
        "end_day.daily_rituals": "Rituels quotidiens",
        "end_day.your_rituals": "Tes rituels du jour",
        "end_day.rituals_hint": "Coche ce que tu as accompli aujourd'hui",
        "end_day.rituals": "Rituels",
        "end_day.rituals_progress": "%d sur %d complétés",
        "end_day.rituals_completed": "%d/%d complétés",
        "end_day.ideas": "Idées pour commencer :",
        "end_day.biggest_win": "Plus grande victoire",
        "end_day.biggest_win_question": "Quelle a été ta plus grande victoire aujourd'hui ?",
        "end_day.biggest_win_hint": "Célèbre tes accomplissements, même les plus petits",
        "end_day.biggest_win_placeholder": "Je suis fier de...",
        "end_day.challenges": "Défis rencontrés",
        "end_day.challenges_question": "Qu'est-ce qui t'a mis au défi aujourd'hui ?",
        "end_day.challenges_hint": "Identifier les obstacles aide à les surmonter",
        "end_day.challenges_placeholder": "J'ai eu du mal avec...",
        "end_day.best_moment": "Meilleur moment",
        "end_day.best_moment_question": "Quel a été ton meilleur moment ?",
        "end_day.best_moment_hint": "Trouve les points positifs de ta journée",
        "end_day.best_moment_placeholder": "J'étais content quand...",
        "end_day.tomorrow": "Demain",
        "end_day.tomorrow_question": "Quel est ton objectif n°1 pour demain ?",
        "end_day.tomorrow_hint": "Prépare-toi à réussir",
        "end_day.tomorrow_placeholder": "Demain je vais...",
        "end_day.tomorrow_goal": "Objectif pour demain",
        "end_day.summary": "Résumé",
        "end_day.your_day_review": "Bilan de ta journée",
        "end_day.summary_hint": "Voici un résumé de ta réflexion",
        "end_day.no_reflections": "Aucune réflexion ajoutée",
        "end_day.no_reflections_hint": "Tu peux quand même terminer, ou revenir ajouter des pensées.",
        "end_day.day_complete": "Journée terminée !",
        "end_day.rest_well": "Repose-toi bien. Demain est une nouvelle opportunité.",
        "end_day.rituals_done": "Rituels faits",
        "end_day.goal_set": "Objectif défini",
        "end_day.complete_review": "Terminer le bilan",
        "end_day.good_night": "Bonne nuit",
        "end_day.step_indicator": "Étape %d sur %d",
        "end_day.example_task": "Terminé une tâche difficile",
        "end_day.example_helped": "Aidé quelqu'un",
        "end_day.example_learned": "Appris quelque chose",
        "end_day.example_focused": "Resté concentré",
        "end_day.example_distractions": "Distractions",
        "end_day.example_conversation": "Conversation difficile",
        "end_day.example_time": "Gestion du temps",
        "end_day.example_energy": "Peu d'énergie",
        "end_day.example_good_conversation": "Une bonne conversation",
        "end_day.example_achieving": "Atteindre un objectif",
        "end_day.example_peaceful": "Un moment de calme",
        "end_day.example_funny": "Quelque chose de drôle",
        "end_day.example_project": "Terminer le projet X",
        "end_day.example_exercise": "Faire du sport",
        "end_day.example_talk": "Avoir une conversation difficile",
        "end_day.example_learn": "Apprendre quelque chose",

        // Time Formatting
        "time.hours": "heures",
        "time.minutes": "minutes",
        "time.h": "h",
        "time.m": "m",
        "time.days": "jours",
        "time.day": "jour",
        "time.days_short": "j",
        "time.day_short": "j",
        "time.today": "Aujourd'hui",
        "time.yesterday": "Hier",
        "time.ago": "il y a",
        "time.just_now": "À l'instant",
        "time.1_day_ago": "Il y a 1 jour",
        "time.days_ago": "Il y a %d jours",
        "time.1_hour_ago": "Il y a 1 heure",
        "time.hours_ago": "Il y a %d heures",
        "time.1_min_ago": "Il y a 1 min",
        "time.mins_ago": "Il y a %d min",

        // Streak
        "streak.active": "Série active",
        "streak.day_count": "Jour %d",
        "streak.free_for": "Tu es en feu depuis :",
        "streak.motivational": "Un nouveau jour pour progresser",
        "streak.name": "Nom",
        "streak.since": "Depuis le",
        "streak.start_today": "Lance une session focus pour démarrer ta série !",
        "streak.today_done": "Fait",
        "streak.today_pending": "En attente",

        // CTA (Call to Action)
        "cta.start_day.title": "Bien démarrer ta journée",
        "cta.start_day.subtitle": "Complète ton check-in du matin",
        "cta.start_day.button": "Démarrer la journée",
        "cta.fire_mode.title": "Lance une session FireMode",
        "cta.fire_mode.subtitle": "Démarre ta première session focus",
        "cta.fire_mode.button": "Entrer en FireMode",
        "cta.end_day.title": "Fais ta revue de fin de journée",
        "cta.end_day.subtitle": "Réfléchis et clôture ta journée",
        "cta.end_day.button": "Revue de fin de journée",
        "cta.completed.title": "Tu as tout fait pour aujourd'hui",
        "cta.completed.subtitle": "Bravo. Repose-toi et prépare-toi pour demain.",
        "cta.completed.button": "Voir la progression",

        // Errors
        "error.generic": "Une erreur s'est produite",
        "error.network": "Erreur réseau. Réessaie.",
        "error.loading_data": "Échec du chargement des données",
        "error.saving": "Échec de l'enregistrement",
        "error.update_visibility": "Échec de la mise à jour de la visibilité",

        // Feelings
        "feeling.happy": "Content",
        "feeling.calm": "Calme",
        "feeling.neutral": "Neutre",
        "feeling.sad": "Triste",
        "feeling.anxious": "Anxieux",
        "feeling.frustrated": "Frustré",
        "feeling.excited": "Excité",
        "feeling.tired": "Fatigué",

        // Areas
        "area.health": "Santé",
        "area.learning": "Apprentissage",
        "area.career": "Carrière",
        "area.relationships": "Relations",
        "area.creativity": "Créativité",
        "area.other": "Autre",

        // Legal
        "legal.privacy.title": "Confidentialité",
        "legal.privacy.content": "Volta collecte uniquement les informations nécessaires pour créer et sécuriser votre compte (nom, email, mot de passe via Apple Sign In). Aucune donnée n'est partagée avec des tiers. Vous pouvez supprimer votre compte à tout moment. Questions ? support@volta.app"
    ]

    static let spanishTranslations: [String: String] = [
        // Common
        "common.done": "Hecho",
        "common.cancel": "Cancelar",
        "common.save": "Guardar",
        "common.delete": "Eliminar",
        "common.edit": "Editar",
        "common.error": "Error",
        "common.retry": "Reintentar",
        "common.loading": "Cargando...",
        "common.ok": "OK",
        "common.yes": "Sí",
        "common.no": "No",
        "common.back": "Atrás",
        "common.continue": "Continuar",
        "common.close": "Cerrar",
        "common.add": "Añadir",
        "common.remove": "Eliminar",
        "common.none": "Ninguno",
        "common.show_less": "Ver menos",
        "common.see_all": "Ver todos %d",
        "common.see_more": "Ver %d más",
        "common.manage": "Gestionar",
        "common.new": "Nuevo",

        // Welcome / Splash
        "welcome.title": "Bienvenido a Volta",
        "welcome.subtitle": "Tu camino hacia el éxito comienza aquí",
        "welcome.loading": "Preparando tu experiencia...",

        // Auth / Sign In
        "auth.tagline": "Enfócate. Construye. Progresa.",
        "auth.feature.focus": "Sesiones de enfoque profundo",
        "auth.feature.quests": "Sigue tus metas y objetivos",
        "auth.feature.habits": "Sube de nivel con hábitos",
        "auth.feature.rituals": "Rituales diarios",
        "auth.terms.agree": "Al continuar, aceptas nuestros",
        "auth.terms.tos": "Términos de Servicio",
        "auth.terms.and": "y",
        "auth.terms.privacy": "Política de Privacidad",
        "auth.sign_in_apple": "Iniciar sesión con Apple",
        "auth.signing_in": "Iniciando sesión...",
        "auth.error_title": "Error de inicio de sesión",

        // Tabs
        "tab.dashboard": "Inicio",
        "tab.fire": "Enfoque",
        "tab.quests": "Metas",
        "tab.crew": "Equipo",

        // Dashboard
        "dashboard.title": "VOLTA",
        "dashboard.subtitle": "Un nuevo día para avanzar en tu proyecto.",
        "dashboard.good_morning": "Buenos días",
        "dashboard.good_afternoon": "Buenas tardes",
        "dashboard.good_evening": "Buenas noches",
        "dashboard.start_day": "Comienza tu Día",
        "dashboard.end_day": "Termina tu Día",
        "dashboard.todays_routines": "Rutinas de Hoy",
        "dashboard.todays_intentions": "Intenciones del Día",
        "dashboard.daily_habits": "Hábitos Diarios",
        "dashboard.evening_reflection": "Reflexión Nocturna",
        "dashboard.focus_time": "Tiempo de Enfoque",
        "dashboard.streak": "Racha",
        "dashboard.day_streak": "días de racha",
        "dashboard.weekly_progress": "Progreso Semanal",
        "dashboard.sessions_this_week": "Sesiones de la Semana",
        "dashboard.loading": "Cargando tu dashboard...",
        "dashboard.focused_today": "Enfocado Hoy",
        "dashboard.swipe_hint": "Desliza a la izquierda para editar o eliminar",
        "dashboard.motivational": "Estás progresando. Incluso en los días difíciles.",

        // Fire Mode
        "fire.title": "FIREMODE",
        "fire.subtitle": "Enfoque profundo. Cero distracciones.",
        "fire.start_session": "Iniciar Sesión de Enfoque",
        "fire.stop_session": "Detener Sesión",
        "fire.pause": "Pausar",
        "fire.resume": "Reanudar",
        "fire.focus": "Enfoque",
        "fire.paused": "Pausado",
        "fire.complete": "¡Completado!",
        "fire.great_work": "¡Buen trabajo! Sesión registrada.",
        "fire.ready_to_focus": "¿Listo para enfocarte?",
        "fire.ready_subtitle": "Inicia tu primera sesión y genera impulso",
        "fire.duration": "Duración",
        "fire.minutes": "minutos",
        "fire.sessions_today": "Sesiones de Hoy",
        "fire.sessions_this_week": "Sesiones esta semana",
        "fire.focus_time": "Tiempo de enfoque",
        "fire.link_quest": "Vincular a Meta (opcional)",
        "fire.select_quest": "Selecciona una meta...",
        "fire.no_active_quests": "Sin metas activas",
        "fire.no_quest": "Sin meta seleccionada",
        "fire.description": "¿En qué trabajarás?",
        "fire.description_placeholder": "Describe tu área de enfoque...",
        "fire.log_past_session": "Registrar Sesión Pasada",
        "fire.when": "¿Cuándo?",
        "fire.session_time": "Tiempo de sesión",
        "fire.what_worked_on": "¿En qué trabajaste?",
        "fire.log_session": "Registrar Sesión",
        "fire.focus_session": "Sesión de enfoque",
        "fire.manual": "Manual",
        "fire.start_firemode": "Iniciar FireMode",
        "fire.launch_session": "Lanza una sesión de enfoque ahora",
        "fire.delete_session": "¿Eliminar Sesión?",
        "fire.delete_session_confirm": "Esto eliminará permanentemente esta sesión de enfoque.",

        // Quests
        "quests.title": "METAS",
        "quests.subtitle": "Sigue tu progreso y construye hábitos.",
        "quests.active": "Activas",
        "quests.completed": "Completadas",
        "quests.add_quest": "Añadir Meta",
        "quests.new_quest": "Nueva Meta",
        "quests.progress": "Progreso",
        "quests.no_quests": "Sin metas aún",
        "quests.quest_title": "Título de la meta",
        "quests.target": "Objetivo (opcional)",
        "quests.target_hint": "¿Cuántas veces quieres lograr esto?",
        "quests.current_progress": "Progreso Actual",
        "quests.progress_hint": "Usa el deslizador en la tarjeta para actualizar el progreso",
        "quests.mark_complete": "Marcar como Completada",
        "quests.swipe_hint": "Desliza a la derecha para completar",
        "quests.areas": "Áreas",
        "quests.quests": "Metas",
        "quests.no_areas": "Sin áreas registradas aún",
        "quests.no_areas_hint": "Crea metas para ver tu progreso por área",
        "quests.no_quests_hint": "Crea tu primera meta para comenzar a seguir tu progreso",
        "quests.create_quest": "Crear Meta",
        "quests.quest_placeholder": "ej., Leer 12 libros, Correr un maratón...",
        "quests.edit_quest": "Editar Meta",
        "quests.delete_quest": "Eliminar Meta",
        "quests.delete_confirm": "Esta acción no se puede deshacer.",
        "quests.quest_details": "Detalles de la Meta",
        "quests.target_date": "Fecha Objetivo",
        "quests.update_progress": "Actualizar Progreso",
        "quests.swipe_to_update": "Desliza para actualizar progreso",

        // Routines / Rituals
        "routines.title": "Rituales Diarios",
        "routines.subtitle": "Construye hábitos diarios que se acumulan con el tiempo",
        "routines.daily": "Rutinas Diarias",
        "routines.completed": "Completado",
        "routines.add_routine": "Añadir Ritual",
        "routines.new_ritual": "Nuevo Ritual",
        "routines.edit_ritual": "Editar Ritual",
        "routines.no_routines": "Sin rituales aún",
        "routines.no_routines_hint": "Crea rituales diarios para construir consistencia",
        "routines.add_first": "Añade Tu Primer Ritual",
        "routines.total": "Total",
        "routines.done_today": "Hecho hoy",
        "routines.swipe_hint": "Desliza a la derecha para completar, izquierda para editar/eliminar",
        "routines.delete_ritual": "Eliminar Ritual",
        "routines.delete_confirm": "¿Eliminar Ritual?",
        "routines.delete_message": "¿Seguro que quieres eliminar \"%@\"? Esta acción no se puede deshacer.",
        "routines.choose_icon": "Elige un icono",
        "routines.ritual_name": "Nombre del ritual",
        "routines.ritual_placeholder": "ej., Ejercicio matutino, Leer 30 min...",
        "routines.life_area": "Área de vida",
        "routines.no_areas": "Sin áreas disponibles",
        "routines.frequency": "Frecuencia",
        "routines.frequency.daily": "Diario",
        "routines.frequency.weekdays": "Días laborables",
        "routines.frequency.weekends": "Fines de semana",
        "routines.frequency.weekly": "Semanal",
        "routines.create": "Crear Ritual",
        "routines.save_changes": "Guardar Cambios",
        "routines.loading_areas": "Cargando áreas...",
        "routines.no_scheduled": "Sin rituales programados para hoy",

        // Crew
        "crew.title": "EQUIPO",
        "crew.subtitle": "Construye juntos. Crece juntos.",
        "crew.leaderboard": "Clasificación",
        "crew.my_crew": "Mi Equipo",
        "crew.requests": "Solicitudes",
        "crew.account": "Cuenta",
        "crew.top_builders": "Top Constructores Esta Semana",
        "crew.your_crew": "Tu Equipo",
        "crew.members": "miembros",
        "crew.this_week": "esta semana",
        "crew.search": "Buscar",
        "crew.search_placeholder": "Buscar usuarios...",
        "crew.no_users_found": "No se encontraron usuarios",
        "crew.pending": "Pendiente",
        "crew.respond": "Responder",
        "crew.accept": "Aceptar",
        "crew.reject": "Rechazar",
        "crew.in_crew": "En Equipo",
        "crew.remove": "Eliminar",
        "crew.no_members": "Sin miembros aún",
        "crew.no_requests": "Sin solicitudes pendientes",
        "crew.received_requests": "Solicitudes Recibidas",
        "crew.sent_requests": "Solicitudes Enviadas",
        "crew.incoming": "Entrantes",
        "crew.outgoing": "Salientes",
        "crew.remove_confirm": "¿Seguro que quieres eliminar a %@ de tu equipo?",
        "crew.search_hint": "Busca usuarios y envíales una solicitud de equipo",
        "crew.start_session_hint": "Inicia una sesión de enfoque para aparecer en la clasificación",
        "crew.requests_hint": "Cuando alguien quiera unirse a tu equipo, aparecerá aquí",
        "crew.no_sent_requests": "Sin solicitudes enviadas",
        "crew.search_to_send": "Busca usuarios para enviar solicitudes de equipo",
        "crew.crew_member": "Miembro del Equipo",
        "crew.day_not_visible": "Día No Visible",
        "crew.day_private": "Este usuario tiene su día configurado como privado",
        "crew.no_activity": "Sin actividad este día",
        "crew.intentions": "Intenciones",
        "crew.focus_sessions": "Sesiones de Enfoque",
        "crew.sessions": "sesiones",
        "crew.completed_routines": "Rutinas Completadas",
        "crew.done": "hecho",
        "crew.focus_this_week": "enfoque esta semana",
        "crew.routines_done": "rutinas hechas",

        // Profile / Account
        "profile.title": "Perfil",
        "profile.level": "Nivel %d",
        "profile.my_statistics": "Mis Estadísticas",
        "profile.day_visibility": "Visibilidad del Día",
        "profile.visibility_description": "Controla quién puede ver tu actividad diaria",
        "profile.public": "Público",
        "profile.public_desc": "Cualquiera puede ver tu día",
        "profile.crew_only": "Solo Equipo",
        "profile.crew_only_desc": "Solo los miembros del equipo pueden ver",
        "profile.private": "Privado",
        "profile.private_desc": "Nadie puede ver tu día",
        "profile.language": "Idioma",
        "profile.sign_out": "Cerrar Sesión",
        "profile.sign_out_title": "Cerrar Sesión",
        "profile.sign_out_confirm": "¿Seguro que quieres cerrar sesión?",
        "profile.language_change_title": "Cambiar Idioma",
        "profile.language_change_message": "La aplicación necesita reiniciarse para aplicar el cambio de idioma.",
        "profile.restart_app": "Reiniciar",
        "profile.version": "Volta v1.0.0",
        "profile.guest_account": "Cuenta de Invitado",

        // Statistics
        "stats.title": "Estadísticas",
        "stats.my_statistics": "Mis Estadísticas",
        "stats.member_stats": "Estadísticas de %@",
        "stats.week": "Semana",
        "stats.month": "Mes",
        "stats.focus_time": "Tiempo de Enfoque",
        "stats.avg_daily": "Promedio Diario",
        "stats.routines": "Rutinas",
        "stats.completion": "Completado",
        "stats.completed": "completado",
        "stats.rate": "tasa",
        "stats.this_week": "esta semana",
        "stats.this_month": "este mes",
        "stats.last_7_days": "Últimos 7 días",
        "stats.last_30_days": "Últimos 30 días",
        "stats.focus_sessions": "Sesiones de Enfoque",
        "stats.daily_routines": "Rutinas Diarias",
        "stats.no_sessions": "Sin sesiones de enfoque aún",
        "stats.no_routines": "Sin rutinas completadas aún",
        "stats.view_stats": "Ver Estadísticas",
        "stats.failed_to_load": "Error al cargar estadísticas",

        // Start The Day
        "start_day.title": "Comienza tu Día",
        "start_day.greeting_morning": "¡Buenos Días!",
        "start_day.greeting_afternoon": "¡Buenas Tardes!",
        "start_day.greeting_evening": "¡Buenas Noches!",
        "start_day.subtitle": "Tómate un momento para establecer el tono de un día enfocado y productivo.",
        "start_day.how_feeling": "¿Cómo te sientes?",
        "start_day.feeling_hint": "Selecciona la emoción que mejor describe tu estado actual",
        "start_day.add_note": "Añadir nota (opcional)",
        "start_day.note_placeholder": "¿Qué tienes en mente esta mañana?",
        "start_day.sleep_quality": "¿Cómo dormiste?",
        "start_day.sleep_hint": "Califica la calidad de tu descanso del 1 al 10",
        "start_day.poor": "Mal",
        "start_day.excellent": "Excelente",
        "start_day.sleep_notes": "Notas sobre el sueño (opcional)",
        "start_day.sleep_placeholder": "¿Algún pensamiento sobre tu sueño?",
        "start_day.intentions": "Intenciones del Día",
        "start_day.intention_1": "Intención 1",
        "start_day.intention_2": "Intención 2",
        "start_day.intention_3": "Intención 3",
        "start_day.intention_placeholder": "¿En qué te enfocarás?",
        "start_day.life_area": "Área de vida",
        "start_day.review": "Revisa tu Día",
        "start_day.confirm_subtitle": "Confirma tu check-in matutino",
        "start_day.not_set": "No establecido",
        "start_day.feeling": "Estado de ánimo",
        "start_day.focus_areas": "Áreas de enfoque de hoy",
        "start_day.start_my_day": "Comenzar Mi Día",
        "start_day.lets_go": "¡Vamos!",
        "start_day.youre_ready": "¡Estás Listo!",
        "start_day.ready_subtitle": "Tus intenciones están establecidas.\n¡Es hora de hacerlo realidad!",
        "start_day.sleep_1": "Muy mal descanso",
        "start_day.sleep_3": "Podría ser mejor",
        "start_day.sleep_5": "Sueño decente",
        "start_day.sleep_7": "Buen descanso",
        "start_day.sleep_10": "¡Excelente recuperación!",
        "start_day.step_indicator": "Paso %d de %d",
        "start_day.step.welcome": "Bienvenida",
        "start_day.step.welcome_subtitle": "Comencemos bien tu día",
        "start_day.step.sleep_subtitle": "¿Cómo fue tu descanso?",
        "start_day.step.intention1_subtitle": "¿Cuál es tu primera prioridad?",
        "start_day.step.intention2_subtitle": "¿Qué más importa hoy?",
        "start_day.step.intention3_subtitle": "Una cosa más en qué enfocarte",
        "start_day.intention_prompt_1": "¿Qué es lo más importante que quieres lograr hoy?",
        "start_day.intention_prompt_2": "¿Qué más haría que hoy se sienta exitoso?",
        "start_day.intention_prompt_3": "Una intención más para completar tu día",
        "start_day.intention_example_1": "ej., Terminar la propuesta del proyecto",
        "start_day.intention_example_2": "ej., 30 minutos de ejercicio",
        "start_day.intention_example_3": "ej., Llamar a un amigo",

        // End of Day
        "end_day.title": "Revisión Nocturna",
        "end_day.time_to_reflect": "Hora de Reflexionar",
        "end_day.subtitle": "Tómate unos minutos para revisar tu día y prepararte para mañana.",
        "end_day.lets_reflect": "Reflexionemos",
        "end_day.daily_rituals": "Rituales Diarios",
        "end_day.your_rituals": "Tus Rituales Diarios",
        "end_day.rituals_hint": "Marca lo que completaste hoy",
        "end_day.rituals": "Rituales",
        "end_day.rituals_progress": "%d de %d completados",
        "end_day.rituals_completed": "%d/%d completados",
        "end_day.ideas": "Ideas para comenzar:",
        "end_day.biggest_win": "Mayor Logro",
        "end_day.biggest_win_question": "¿Cuál fue tu mayor logro hoy?",
        "end_day.biggest_win_hint": "Celebra tus logros, sin importar lo pequeños que sean",
        "end_day.biggest_win_placeholder": "Estoy orgulloso de...",
        "end_day.challenges": "Desafíos",
        "end_day.challenges_question": "¿Qué te desafió hoy?",
        "end_day.challenges_hint": "Identificar obstáculos te ayuda a superarlos",
        "end_day.challenges_placeholder": "Tuve dificultades con...",
        "end_day.best_moment": "Mejor Momento",
        "end_day.best_moment_question": "¿Cuál fue tu mejor momento?",
        "end_day.best_moment_hint": "Encuentra los puntos brillantes de tu día",
        "end_day.best_moment_placeholder": "Me sentí feliz cuando...",
        "end_day.tomorrow": "Mañana",
        "end_day.tomorrow_question": "¿Cuál es tu meta #1 para mañana?",
        "end_day.tomorrow_hint": "Prepárate para el éxito",
        "end_day.tomorrow_placeholder": "Mañana voy a...",
        "end_day.tomorrow_goal": "Meta para Mañana",
        "end_day.summary": "Resumen",
        "end_day.your_day_review": "Tu Día en Revisión",
        "end_day.summary_hint": "Aquí hay un resumen de tu reflexión",
        "end_day.no_reflections": "Sin reflexiones añadidas",
        "end_day.no_reflections_hint": "Aún puedes completar tu revisión, o volver atrás para añadir algunos pensamientos.",
        "end_day.day_complete": "¡Día Completado!",
        "end_day.rest_well": "Descansa bien. Mañana es una nueva oportunidad.",
        "end_day.rituals_done": "Rituales Hechos",
        "end_day.goal_set": "Meta Establecida",
        "end_day.complete_review": "Completar Revisión",
        "end_day.good_night": "Buenas Noches",
        "end_day.step_indicator": "Paso %d de %d",

        // Time Formatting
        "time.hours": "horas",
        "time.minutes": "minutos",
        "time.h": "h",
        "time.m": "m",
        "time.days": "días",
        "time.day": "día",
        "time.today": "Hoy",
        "time.yesterday": "Ayer",
        "time.ago": "hace",
        "time.just_now": "Justo ahora",
        "time.1_day_ago": "hace 1 día",
        "time.days_ago": "hace %d días",
        "time.1_hour_ago": "hace 1 hora",
        "time.hours_ago": "hace %d horas",
        "time.1_min_ago": "hace 1 min",
        "time.mins_ago": "hace %d min",

        // Streak
        "streak.active": "Racha Activa",
        "streak.day_count": "Día %d",
        "streak.free_for": "Has estado en fuego por:",
        "streak.motivational": "Un nuevo día para progresar",
        "streak.name": "Nombre",
        "streak.since": "Racha desde",
        "streak.start_today": "¡Inicia una sesión de enfoque para comenzar tu racha!",
        "streak.today_done": "Hecho",
        "streak.today_pending": "Pendiente",

        // CTA (Call to Action)
        "cta.start_day.title": "Comienza bien tu día",
        "cta.start_day.subtitle": "Completa tu check-in matutino",
        "cta.start_day.button": "Comenzar el Día",
        "cta.fire_mode.title": "Inicia una sesión FireMode",
        "cta.fire_mode.subtitle": "Lanza tu primera sesión de enfoque",
        "cta.fire_mode.button": "Entrar en FireMode",
        "cta.end_day.title": "Completa tu revisión de fin de día",
        "cta.end_day.subtitle": "Reflexiona y cierra tu día",
        "cta.end_day.button": "Revisión de Fin de Día",
        "cta.completed.title": "Ya estás listo para hoy",
        "cta.completed.subtitle": "Buen trabajo. Descansa y prepárate para mañana.",
        "cta.completed.button": "Ver Progreso",

        // Errors
        "error.generic": "Algo salió mal",
        "error.network": "Error de red. Por favor intenta de nuevo.",
        "error.loading_data": "Error al cargar datos",
        "error.saving": "Error al guardar",
        "error.update_visibility": "Error al actualizar visibilidad",

        // Feelings
        "feeling.happy": "Feliz",
        "feeling.calm": "Tranquilo",
        "feeling.neutral": "Neutral",
        "feeling.sad": "Triste",
        "feeling.anxious": "Ansioso",
        "feeling.frustrated": "Frustrado",
        "feeling.excited": "Emocionado",
        "feeling.tired": "Cansado",

        // Areas
        "area.health": "Salud",
        "area.learning": "Aprendizaje",
        "area.career": "Carrera",
        "area.relationships": "Relaciones",
        "area.creativity": "Creatividad",
        "area.other": "Otro",

        // Legal
        "legal.privacy.title": "Política de Privacidad",
        "legal.privacy.content": "Volta solo recopila la información necesaria para crear y proteger tu cuenta (nombre, correo, contraseña mediante Apple Sign In). No se comparten datos con terceros. Puedes eliminar tu cuenta en cualquier momento. ¿Preguntas? support@volta.app"
    ]
}
