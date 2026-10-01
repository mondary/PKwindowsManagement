// Appended to a temporary copy of AppLauncherService.swift, never compiled alone.
extension AppLauncherService {
    static func seedStoreCaptureCatalog() throws {
        let paths = [
            "/System/Applications/Calendar.app",
            "/System/Applications/Notes.app",
            "/System/Applications/Reminders.app",
            "/System/Applications/Mail.app",
            "/System/Applications/Messages.app",
            "/System/Applications/Maps.app",
            "/System/Applications/Photos.app",
            "/System/Applications/Music.app",
            "/System/Applications/Podcasts.app",
            "/System/Applications/Books.app",
            "/System/Applications/Preview.app",
            "/System/Applications/Calculator.app",
            "/System/Applications/Clock.app",
            "/System/Applications/Weather.app",
            "/System/Applications/FaceTime.app",
            "/System/Applications/Contacts.app",
            "/System/Applications/TextEdit.app",
            "/System/Applications/Utilities/Terminal.app",
            "/System/Applications/Utilities/Activity Monitor.app"
        ]
        cachedInstalledApps = try paths.map { path in
            let url = URL(fileURLWithPath: path)
            guard let bundle = Bundle(url: url),
                  let id = bundle.bundleIdentifier, id.hasPrefix("com.apple.") else {
                throw NSError(domain: "StoreCapture", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Missing allowlisted Apple app: \(path)"])
            }
            return InstalledApp(url: url, displayName: url.deletingPathExtension().lastPathComponent,
                                bundleID: id, icon: NSWorkspace.shared.icon(forFile: path))
        }
        cachedInstalledAppsTimestamp = Date()
        precondition(cachedInstalledApps?.count == paths.count)
    }
}
