import Foundation
import SwiftUI
import Combine

// MARK: - Supported Languages
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case french = "fr"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .french: return "Français"
        }
    }

    var flag: String {
        switch self {
        case .system: return "🌐"
        case .english: return "🇬🇧"
        case .french: return "🇫🇷"
        }
    }

    var localeIdentifier: String? {
        switch self {
        case .system: return nil
        case .english: return "en"
        case .french: return "fr"
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
        "fr": LocalizationManager.frenchTranslations
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

    private var effectiveLanguageCode: String {
        if let localeId = currentLanguage.localeIdentifier {
            return localeId
        }
        // System language - detect device language
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        if preferredLanguage.starts(with: "fr") {
            return "fr"
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
        "area.other": "Other"
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
        "area.other": "Autre"
    ]
}
