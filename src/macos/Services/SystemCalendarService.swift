import EventKit
import Foundation

@MainActor
enum SystemCalendarService {
    private static let store = EKEventStore()

    static func allDayEvents(in year: Int) async -> [String: [String]] {
        guard await requestAccess() else { return [:] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let end = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else { return [:] }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        var result: [String: [String]] = [:]
        for event in store.events(matching: predicate) where event.isAllDay {
            var date = max(calendar.startOfDay(for: event.startDate), start)
            let endExclusive = min(calendar.startOfDay(for: event.endDate), end)
            while date < endExclusive {
                let label = "📅 \(event.title ?? "Événement")"
                if !result[BigYearData.key(date), default: []].contains(label) {
                    result[BigYearData.key(date), default: []].append(label)
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
                date = next
            }
        }
        return result
    }

    private static func requestAccess() async -> Bool {
        if #available(macOS 14.0, *) {
            return (try? await store.requestFullAccessToEvents()) == true
        }
        return await withCheckedContinuation { continuation in
            store.requestAccess(to: .event) { granted, _ in continuation.resume(returning: granted) }
        }
    }
}
