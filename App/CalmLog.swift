import Foundation
import BrainwaveKit
#if os(iOS)
import HealthKit
#endif

/// Saves finished calm sessions on this device, so the Mind tab can show the week and the streak.
enum CalmLogStore {
    private static let key = "calmSessions"

    static func load() -> [CalmSessionRecord] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([CalmSessionRecord].self, from: data)) ?? []
    }

    static func add(_ record: CalmSessionRecord) {
        var records = load()
        records.append(record)
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

#if os(iOS)
/// Writes a calm session to Apple Health as Mindful Minutes, if the user allows it.
enum HealthSync {
    static func saveMindfulSession(start: Date, end: Date) async {
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }
        let store = HKHealthStore()
        do {
            try await store.requestAuthorization(toShare: [type], read: [])
            let sample = HKCategorySample(type: type, value: HKCategoryValue.notApplicable.rawValue,
                                          start: start, end: end)
            try await store.save(sample)
        } catch {
            // The user said no, or Health is unavailable. The calm log still keeps the session.
        }
    }
}
#endif
