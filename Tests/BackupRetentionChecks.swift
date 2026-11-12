import Foundation

@main
enum BackupRetentionChecks {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 10))!

        // One file per calendar day, named after that day.
        assert(BackupRetention.fileName(for: today) == "PKwindowsManagement-backup-2026-11-12.json")
        let firstOfMonth = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        assert(BackupRetention.fileName(for: firstOfMonth) == "PKwindowsManagement-backup-2026-01-05.json")

        // New and legacy names resolve to the same day; unrelated files are ignored.
        let parsed = BackupRetention.date(fromFileName: "PKwindowsManagement-backup-2026-11-05.json")
        let legacy = BackupRetention.date(fromFileName: "PKwindowsManagement-backup-2026-11-05_08-44-00.json")
        assert(parsed != nil)
        assert(legacy == parsed)
        assert(BackupRetention.date(fromFileName: "notes.json") == nil)
        assert(BackupRetention.date(fromFileName: "PKwindowsManagement-backup.json") == nil)
        assert(BackupRetention.date(fromFileName: "PKwindowsManagement-backup-2026-11.json") == nil)

        // Sliding window: today plus the six previous days are kept.
        let names = [
            "PKwindowsManagement-backup-2026-11-12.json",
            "PKwindowsManagement-backup-2026-11-12_09-30-00.json",
            "PKwindowsManagement-backup-2026-11-07.json",
            "PKwindowsManagement-backup-2026-11-06.json",
            "PKwindowsManagement-backup-2026-11-05.json",
            "PKwindowsManagement-backup-2026-10-31_08-44-00.json",
            "notes.json",
            "PKwindowsManagement-backup.json"
        ]
        let expired = Set(BackupRetention.expiredFileNames(in: names, today: today))
        assert(expired == [
            "PKwindowsManagement-backup-2026-11-05.json",
            "PKwindowsManagement-backup-2026-10-31_08-44-00.json"
        ])

        // Exactly seven daily files survive the sweep.
        let week = (5...12).map { "PKwindowsManagement-backup-2026-11-\(String(format: "%02d", $0)).json" }
        let kept = week.filter { !BackupRetention.expiredFileNames(in: [ $0 ], today: today).contains($0) }
        assert(kept.count == 7)
        assert(kept.first == "PKwindowsManagement-backup-2026-11-06.json")
        assert(kept.last == "PKwindowsManagement-backup-2026-11-12.json")

        print("Backup retention checks passed: daily file, legacy names and seven-day window")
    }
}
