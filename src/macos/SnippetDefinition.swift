import AppKit
import Foundation

enum SnippetKind: String, Codable, CaseIterable, Identifiable {
    case script
    case url

    var id: String { rawValue }

    var title: String {
        switch self {
        case .script: localizedString("Script")
        case .url: "URL"
        }
    }
}

enum SnippetBrowserTarget: String, Codable, CaseIterable, Identifiable {
    case defaultBrowser
    case safari
    case chrome
    case firefox
    case brave
    case edge
    case arc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defaultBrowser: localizedString("Default Browser")
        case .safari: "Safari"
        case .chrome: "Google Chrome"
        case .firefox: "Firefox"
        case .brave: "Brave"
        case .edge: "Microsoft Edge"
        case .arc: "Arc"
        }
    }

    var bundleIdentifier: String? {
        switch self {
        case .defaultBrowser: nil
        case .safari: "com.apple.Safari"
        case .chrome: "com.google.Chrome"
        case .firefox: "org.mozilla.firefox"
        case .brave: "com.brave.Browser"
        case .edge: "com.microsoft.edgemac"
        case .arc: "company.thebrowser.Browser"
        }
    }
}

struct SnippetDefinition: Codable, Identifiable, Equatable, Hashable {
    static let archiveID = "snippet.archive"
    static let archiveSymbolName = "tray.and.arrow.down"
    static let downloadsToDesktopID = "snippet.downloads-to-desktop"
    static let downloadsToDesktopSymbolName = "tray.and.arrow.up"
    private static let finderFolderIDs: Set<String> = [
        "snippet.applications",
        "snippet.home",
        "snippet.documents"
    ]

    let id: String
    var title: String
    var kind: SnippetKind
    var body: String
    var urlString: String
    var browserBundleID: String?
    var faviconData: Data?
    var isEnabled: Bool

    var launchpadSymbolName: String? {
        switch kind {
        case .script:
            if isFinderFolderShortcut { return "folder" }
            if id == Self.downloadsToDesktopID { return Self.downloadsToDesktopSymbolName }
            return id == Self.archiveID ? Self.archiveSymbolName : "terminal"
        case .url:
            return faviconData == nil ? "globe" : nil
        }
    }

    var settingsListSymbolName: String {
        switch kind {
        case .script:
            if isFinderFolderShortcut { return "folder" }
            if id == Self.downloadsToDesktopID { return Self.downloadsToDesktopSymbolName }
            return id == Self.archiveID ? Self.archiveSymbolName : "doc.plaintext"
        case .url:
            return "link"
        }
    }

    private var isFinderFolderShortcut: Bool {
        guard kind == .script else { return false }
        if Self.finderFolderIDs.contains(id) { return true }

        let normalizedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedBody.hasPrefix("open ") else { return false }
        return normalizedBody.contains("~")
            || normalizedBody.contains("$HOME")
            || normalizedBody.contains("/Applications")
            || normalizedBody.contains("/Documents")
    }

    init(id: String = UUID().uuidString, title: String, body: String) {
        self.id = id
        self.title = title
        self.kind = .script
        self.body = body
        self.urlString = ""
        self.browserBundleID = nil
        self.faviconData = nil
        self.isEnabled = true
    }

    init(id: String = UUID().uuidString, title: String, body: String, isEnabled: Bool) {
        self.id = id
        self.title = title
        self.kind = .script
        self.body = body
        self.urlString = ""
        self.browserBundleID = nil
        self.faviconData = nil
        self.isEnabled = isEnabled
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        urlString: String,
        browserBundleID: String? = nil,
        faviconData: Data? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.kind = .url
        self.body = ""
        self.urlString = urlString
        self.browserBundleID = browserBundleID
        self.faviconData = faviconData
        self.isEnabled = isEnabled
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case kind
        case body
        case urlString
        case browserBundleID
        case faviconData
        case isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        kind = try container.decodeIfPresent(SnippetKind.self, forKey: .kind) ?? .script
        body = try container.decode(String.self, forKey: .body)
        urlString = try container.decodeIfPresent(String.self, forKey: .urlString) ?? ""
        browserBundleID = try container.decodeIfPresent(String.self, forKey: .browserBundleID)
        faviconData = try container.decodeIfPresent(Data.self, forKey: .faviconData)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(kind, forKey: .kind)
        try container.encode(body, forKey: .body)
        try container.encode(urlString, forKey: .urlString)
        try container.encodeIfPresent(browserBundleID, forKey: .browserBundleID)
        try container.encodeIfPresent(faviconData, forKey: .faviconData)
        try container.encode(isEnabled, forKey: .isEnabled)
    }

    var summaryText: String {
        switch kind {
        case .script:
            return body.isEmpty ? localizedString("Empty script") : body
        case .url:
            if urlString.isEmpty { return localizedString("Empty URL") }
            if let browserBundleID {
                let browserName = SnippetBrowserTarget.allCases.first(where: { $0.bundleIdentifier == browserBundleID })?.title ?? browserBundleID
                return "\(urlString) • \(browserName)"
            }
            return urlString
        }
    }

    var searchText: String {
        [title, body, urlString, browserBundleID ?? ""].joined(separator: " ")
    }

    var faviconImage: NSImage? {
        guard let faviconData, let image = NSImage(data: faviconData) else { return nil }
        image.size = NSSize(width: 64, height: 64)
        return image
    }
}
