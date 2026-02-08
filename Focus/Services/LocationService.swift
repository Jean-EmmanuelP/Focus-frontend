//
//  LocationService.swift
//  Focus
//
//  Location service for tracking user location and providing context to AI
//

import Foundation
import CoreLocation
import Combine

// MARK: - Location Data

struct UserLocationData: Codable {
    let latitude: Double
    let longitude: Double
    let city: String?
    let country: String?
    let neighborhood: String?
    let timezone: String?
    let updatedAt: Date
}

// MARK: - Location Service

@MainActor
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    @Published var currentLocation: CLLocation?
    @Published var currentCity: String?
    @Published var currentCountry: String?
    @Published var currentNeighborhood: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isUpdating = false
    @Published var error: String?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    // Throttle updates
    private var lastUpdateTime: Date?
    private let minUpdateInterval: TimeInterval = 300 // 5 minutes minimum between updates

    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 500 // Update when moved 500m
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Public Methods

    /// Request location permission
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Start monitoring location
    func startUpdating() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }

        isUpdating = true
        locationManager.startUpdatingLocation()
    }

    /// Stop monitoring location
    func stopUpdating() {
        isUpdating = false
        locationManager.stopUpdatingLocation()
    }

    /// Get current location once
    func getCurrentLocation() async throws -> UserLocationData {
        // Request single location update
        locationManager.requestLocation()

        // Wait for location with timeout
        return try await withCheckedThrowingContinuation { continuation in
            var cancelled = false

            // Timeout after 10 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                if !cancelled {
                    cancelled = true
                    continuation.resume(throwing: LocationError.timeout)
                }
            }

            // Subscribe to location updates
            let cancellable = $currentLocation
                .compactMap { $0 }
                .first()
                .sink { [weak self] location in
                    guard !cancelled else { return }
                    cancelled = true

                    Task { @MainActor [weak self] in
                        let data = await self?.buildLocationData(from: location)
                        if let data = data {
                            continuation.resume(returning: data)
                        } else {
                            continuation.resume(throwing: LocationError.geocodingFailed)
                        }
                    }
                }

            // Keep reference to avoid deallocation
            _ = cancellable
        }
    }

    /// Save location to backend
    func saveLocationToBackend() async throws {
        guard let location = currentLocation else {
            throw LocationError.noLocation
        }

        let locationData = await buildLocationData(from: location)

        struct LocationUpdate: Encodable {
            let latitude: Double
            let longitude: Double
            let city: String?
            let country: String?
            let neighborhood: String?
            let timezone: String?
        }

        let update = LocationUpdate(
            latitude: locationData.latitude,
            longitude: locationData.longitude,
            city: locationData.city,
            country: locationData.country,
            neighborhood: locationData.neighborhood,
            timezone: locationData.timezone
        )

        try await APIClient.shared.request(
            endpoint: .updateLocation,
            method: .post,
            body: update
        )
    }

    // MARK: - Private Methods

    private func buildLocationData(from location: CLLocation) async -> UserLocationData {
        // Reverse geocode to get city/country
        var city: String?
        var country: String?
        var neighborhood: String?

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                city = placemark.locality
                country = placemark.country
                neighborhood = placemark.subLocality ?? placemark.administrativeArea
            }
        } catch {
            print("[LocationService] Geocoding failed: \(error)")
        }

        // Update published properties
        self.currentCity = city
        self.currentCountry = country
        self.currentNeighborhood = neighborhood

        return UserLocationData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            city: city,
            country: country,
            neighborhood: neighborhood,
            timezone: TimeZone.current.identifier,
            updatedAt: Date()
        )
    }

    /// Check if enough time has passed for an update
    private func shouldUpdate() -> Bool {
        guard let lastUpdate = lastUpdateTime else { return true }
        return Date().timeIntervalSince(lastUpdate) >= minUpdateInterval
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            self.currentLocation = location
            self.lastUpdateTime = Date()

            // Geocode in background
            _ = await self.buildLocationData(from: location)

            // Auto-save to backend (throttled)
            if self.shouldUpdate() {
                try? await self.saveLocationToBackend()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.error = error.localizedDescription
            print("[LocationService] Error: \(error.localizedDescription)")
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus

            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.startUpdating()
            case .denied, .restricted:
                self.error = "Accès à la localisation refusé"
            default:
                break
            }
        }
    }
}

// MARK: - Location Errors

enum LocationError: LocalizedError {
    case noLocation
    case timeout
    case geocodingFailed
    case permissionDenied
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .noLocation:
            return "Aucune localisation disponible"
        case .timeout:
            return "Délai d'attente dépassé"
        case .geocodingFailed:
            return "Impossible de déterminer la ville"
        case .permissionDenied:
            return "Accès à la localisation refusé"
        case .serverError(let message):
            return "Erreur serveur: \(message)"
        }
    }
}
