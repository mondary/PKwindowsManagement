import Foundation

/// Naming and retention policy for automatic settings backups.
///
/// A backup is written once per calendar day and overwritten during that day,
/// then only the last seven days are kept. Writing one timestamped file per
/// settings change used to fill a synced folder with hundreds of copies.
enum BackupRetention {
    static let fileNamePrefix = "PKwindowsManagement-backup-"
    static let fileNameExtension = "json"
    static let retentionDays = 7

    /// `PKwindowsManagement-backup-2026-11-12.json`
    static func fileName(for date: Date) -> String {
        "\(fileNamePrefix)\(dayFormatter().string(from: date)).\(fileNameExtension)"
    }

    /// Calendar day encoded in a backup file name, new (`yyyy-MM-dd`) or
    /// legacy (`yyyy-MM-dd_HH-mm-ss`) format. Returns nil for any other file.
    static func date(fromFileName name: String) -> Date? {
        guard name.hasPrefix(fileNamePrefix), name.hasSuffix(".\(fileNameExtension)") else { return nil }
        let start = name.index(name.startIndex, offsetBy: fileNamePrefix.count)
        let end = name.index(name.endIndex, offsetBy: -(fileNameExtension.count + 1))
        guard start < end else { return nil }
        let stamp = name[start..<end]
        guard stamp.count >= 10 else { return nil }
        return dayFormatter().date(from: String(stamp.prefix(10)))
    }

    /// Backup files older than the sliding window: the `retentionDays` calendar
    /// days ending today are kept, anything strictly older is returned for
    /// deletion. Unrelated files are never returned.
    static func expiredFileNames(in names: [String], today: Date) -> [String] {
        let calendar = gregorianCalendar()
        let startOfToday = calendar.startOfDay(for: today)
        guard let cutoff = calendar.date(
            byAdding: .day, value: -(retentionDays - 1), to: startOfToday
        ) else { return [] }
        return names.filter { name in
            guard let date = date(fromFileName: name) else { return false }
            return date < cutoff
        }
    }

    private static func gregorianCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    private static func dayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = gregorianCalendar()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
