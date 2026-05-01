//
//  HotReload.swift
//  Focus
//
//  InjectionIII hot reload support for SwiftUI views.
//  Saves → instant update on simulator/device, no rebuild needed.
//

import SwiftUI
import Combine

#if DEBUG

/// Observes InjectionIII notifications and triggers SwiftUI view re-renders.
class InjectionObserver: ObservableObject {
    @Published var injectionCount = 0
    private var cancellable: AnyCancellable?

    static let shared = InjectionObserver()

    init() {
        cancellable = NotificationCenter.default.publisher(for: Notification.Name("INJECTION_BUNDLE_NOTIFICATION"))
            .sink { [weak self] _ in
                self?.injectionCount += 1
            }
    }
}

extension View {
    /// Add `.enableHotReload()` to any view to make it refresh on code injection.
    func enableHotReload() -> some View {
        modifier(HotReloadModifier())
    }
}

struct HotReloadModifier: ViewModifier {
    @ObservedObject var observer = InjectionObserver.shared

    func body(content: Content) -> some View {
        content
            .id(observer.injectionCount)
    }
}

#else

extension View {
    func enableHotReload() -> some View { self }
}

#endif
