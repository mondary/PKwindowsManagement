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

    struct BigYearEvent {
        let name: String
        let emphasized: Bool
        let startMonth: Int
        let startDay: Int
        let endMonth: Int
        let endDay: Int
        let startYear: Int?
        let endYear: Int?

        /// Une plage dont la fin précède le début traverse le nouvel an (ex : 28.12-03.01).
        func covers(month: Int, day: Int, year: Int) -> Bool {
            let ordinal = month * 100 + day
            let start = startMonth * 100 + startDay
            let end = endMonth * 100 + endDay
            if let pinnedYear = startYear ?? endYear {
                var endPinnedYear = endYear ?? pinnedYear
                if end < start, endYear == nil { endPinnedYear += 1 }
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = .current
                guard let candidate = calendar.date(from: DateComponents(year: year, month: month, day: day)),
                      let startDate = calendar.date(from: DateComponents(year: startYear ?? pinnedYear, month: startMonth, day: startDay)),
                      let endDate = calendar.date(from: DateComponents(year: endPinnedYear, month: endMonth, day: endDay)) else { return false }
                return (startDate...endDate).contains(candidate)
            }
            if start <= end { return (start...end).contains(ordinal) }
            return ordinal >= start || ordinal <= end
        }
    }

    /// Formats acceptés, un événement par ligne :
    /// `JJ.MM,Label` · `JJ.MM-JJ.MM,Label` · `JJ.MM.AAAA,Label` · `JJ.MM.AAAA-JJ.MM.AAAA,Label`
    /// (`JJMM` compact accepté aussi ; `!` devant le label le met en gras).
    static func events(from text: String) -> [BigYearEvent] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(separator: ",", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count == 2, !parts[1].isEmpty else { return nil }
            let dateTokens = parts[0].split(separator: "-").map(String.init)
            guard (1...2).contains(dateTokens.count),
                  let start = parseEventDate(dateTokens[0]) else { return nil }
            let end = dateTokens.count == 2 ? parseEventDate(dateTokens[1]) : start
            guard let end else { return nil }

            let emphasized = parts[1].hasPrefix("!")
            let name = (emphasized ? String(parts[1].dropFirst()) : parts[1])
                .trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return nil }
            return BigYearEvent(
                name: name, emphasized: emphasized,
                startMonth: start.month, startDay: start.day,
                endMonth: end.month, endDay: end.day,
                startYear: start.year, endYear: end.year
            )
        }
    }

    static func eventCoverage(from text: String, in year: Int) -> [String: [String]] {
        let parsed = events(from: text)
        guard !parsed.isEmpty else { return [:] }
        var result: [String: [String]] = [:]
        let calendar = self.calendar
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let end = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else { return [:] }
        var date = start
        while date < end {
            let components = calendar.dateComponents([.month, .day], from: date)
            for event in parsed where event.covers(month: components.month ?? 0, day: components.day ?? 0, year: year) {
                let label = event.emphasized ? "!\(event.name)" : event.name
                result[key(date), default: []].append(label)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return result
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
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = value.filter(\.isNumber)
        let day: Int
        let month: Int
        if digits.count == 4, let compactDay = Int(digits.prefix(2)), let compactMonth = Int(digits.suffix(2)) {
            day = compactDay
            month = compactMonth
        } else {
            let parts = value
                .replacingOccurrences(of: "/", with: ".")
                .replacingOccurrences(of: "-", with: ".")
                .split(separator: ".")
                .compactMap { Int($0) }
            guard parts.count == 2 else { return value }
            day = parts[0]
            month = parts[1]
        }
        guard (1...31).contains(day), (1...12).contains(month) else { return value }
        return String(format: "%02d-%02d", month, day)
    }

    private static func parseEventDate(_ raw: String) -> (day: Int, month: Int, year: Int?)? {
        let value = raw.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "/", with: ".")
        let digits = value.filter(\.isNumber)
        if !value.contains(".") {
            guard (4...8).contains(digits.count), digits.count % 2 == 0 else { return nil }
            let day = Int(digits.prefix(2)) ?? 0
            let month = Int(digits.dropFirst(2).prefix(2)) ?? 0
            let year = digits.count == 8 ? Int(digits.suffix(4)) : nil
            return valid(day: day, month: month, year: year)
        }
        let parts = value.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 2 || parts.count == 3 else { return nil }
        return valid(day: parts[0], month: parts[1], year: parts.count == 3 ? parts[2] : nil)
    }

    private static func valid(day: Int, month: Int, year: Int?) -> (day: Int, month: Int, year: Int?)? {
        guard (1...31).contains(day), (1...12).contains(month) else { return nil }
        return (day, month, year)
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
