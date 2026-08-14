import Foundation

enum BigYearData {
    private static var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "fr_FR")
        calendar.firstWeekday = 2
        calendar.timeZone = .current
        return calendar
    }()

    static func birthdays(from text: String) -> [String: [String]] {
        if let data = text.data(using: .utf8),
           let rows = try? JSONDecoder().decode([Birthday].self, from: data) {
            return Dictionary(grouping: rows, by: { normalizedDay($0.date) })
                .mapValues { $0.map(\.name) }
        }

        let rows = text.split(whereSeparator: \.isNewline).compactMap { line -> Birthday? in
            let parts = line.split(separator: ",", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count == 2, !parts[1].isEmpty else { return nil }
            return Birthday(date: parts[0], name: parts[1])
        }
        return Dictionary(grouping: rows, by: { normalizedDay($0.date) })
            .mapValues { $0.map(\.name) }
    }

    static func frenchHolidays(in year: Int) -> [String: String] {
        let easter = easterSunday(year)
        let fixed: [(Int, Int, String)] = [
            (1, 1, "Jour de l’an"), (5, 1, "Fête du Travail"), (5, 8, "Victoire 1945"),
            (7, 14, "Fête nationale"), (8, 15, "Assomption"), (11, 1, "Toussaint"),
            (11, 11, "Armistice"), (12, 25, "Noël")
        ]
        var result = Dictionary(uniqueKeysWithValues: fixed.compactMap { month, day, name in
            calendar.date(from: DateComponents(year: year, month: month, day: day)).map { (key($0), name) }
        })
        for (offset, name) in [(1, "Lundi de Pâques"), (39, "Ascension"), (50, "Lundi de Pentecôte")] {
            if let date = calendar.date(byAdding: .day, value: offset, to: easter) { result[key(date)] = name }
        }
        return result
    }

    static func schoolVacations(in year: Int) async -> [String: Set<String>] {
        let academies = [("A", "Lyon"), ("B", "Lille"), ("C", "Paris")]
        var result: [String: Set<String>] = [:]
        for schoolYear in ["\(year - 1)-\(year)", "\(year)-\(year + 1)"] {
            for (zone, academy) in academies {
                guard let records = await vacationRecords(schoolYear: schoolYear, academy: academy) else { continue }
                for record in records {
                    guard let start = ISO8601DateFormatter().date(from: record.startDate),
                          let end = ISO8601DateFormatter().date(from: record.endDate) else { continue }
                    var date = calendar.startOfDay(for: start)
                    var endExclusive = calendar.startOfDay(for: end)
                    if record.description.localizedCaseInsensitiveContains("Vacances d'Été") {
                        let startYear = calendar.component(.year, from: date)
                        endExclusive = calendar.date(from: DateComponents(year: startYear, month: 9, day: 1)) ?? endExclusive
                    } else if endExclusive <= date {
                        endExclusive = calendar.date(byAdding: .day, value: 1, to: date) ?? endExclusive
                    }
                    while date < endExclusive {
                        if calendar.component(.year, from: date) == year { result[key(date), default: []].insert(zone) }
                        guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
                        date = next
                    }
                }
            }
        }
        return result
    }

    static func key(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func monthDayKey(_ date: Date) -> String {
        let parts = calendar.dateComponents([.month, .day], from: date)
        return String(format: "%02d-%02d", parts.month ?? 0, parts.day ?? 0)
    }

    static func fullDate(_ date: Date) -> String {
        fullDateFormatter.string(from: date)
    }

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .full
        return formatter
    }()

    private static func normalizedDay(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/", with: "-")
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count >= 2 else { return value }
        let month = parts.count == 2 ? parts[0] : parts[parts.count - 2]
        let day = parts.last ?? 0
        return String(format: "%02d-%02d", month, day)
    }

    private static func easterSunday(_ year: Int) -> Date {
        let a = year % 19, b = year / 100, c = year % 100, d = b / 4, e = b % 4
        let f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30, i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7, m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private static func vacationRecords(schoolYear: String, academy: String) async -> [VacationRecord]? {
        var components = URLComponents(string: "https://data.education.gouv.fr/api/explore/v2.1/catalog/datasets/fr-en-calendrier-scolaire/records")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "refine", value: "annee_scolaire:\"\(schoolYear)\""),
            URLQueryItem(name: "refine", value: "location:\"\(academy)\"")
        ]
        guard let url = components.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(VacationResponse.self, from: data) else { return nil }
        return response.results
    }
}

private struct Birthday: Codable {
    let date: String
    let name: String
}

private struct VacationResponse: Decodable {
    let results: [VacationRecord]
}

private struct VacationRecord: Decodable {
    let description: String
    let startDate: String
    let endDate: String

    enum CodingKeys: String, CodingKey {
        case description
        case startDate = "start_date"
        case endDate = "end_date"
    }
}
