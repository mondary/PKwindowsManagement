import Foundation

/// Sections of the Launchpad library. Commands and snippets come first, then
/// applications grouped by a deterministic rule-based categorizer (offline,
/// instant, no dependency). An optional AI refinement pass may come later for
/// apps the rules cannot place.
enum LaunchpadGroup: String, CaseIterable, Identifiable {
    case actions
    case snippets
    case development
    case internet
    case creation
    case media
    case office
    case communication
    case games
    case utilities
    case system
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .actions: localizedString("Actions")
        case .snippets: localizedString("Snippets")
        case .development: localizedString("Development")
        case .internet: localizedString("Internet")
        case .creation: localizedString("Creation")
        case .media: localizedString("Media")
        case .office: localizedString("Office")
        case .communication: localizedString("Communication")
        case .games: localizedString("Games")
        case .utilities: localizedString("Utilities")
        case .system: localizedString("System")
        case .other: localizedString("Other")
        }
    }

    var icon: String {
        switch self {
        case .actions: "bolt"
        case .snippets: "link"
        case .development: "chevron.left.forwardslash.chevron.right"
        case .internet: "globe"
        case .creation: "paintpalette"
        case .media: "play.tv"
        case .office: "doc.text"
        case .communication: "message"
        case .games: "gamecontroller"
        case .utilities: "wrench.and.screwdriver"
        case .system: "gearshape.2"
        case .other: "square.grid.2x2"
        }
    }
}

enum AppCategorizer {
    /// Bundl IDs mapped by hand: checked before every other rule.
    private static let curated: [String: LaunchpadGroup] = [
        // Development
        "com.apple.dt.xcode": .development,
        "com.microsoft.vscode": .development,
        "com.microsoft.vscodeinsiders": .development,
        "com.sublimetext.4": .development,
        "com.sublimetext.3": .development,
        "com.googlecode.iterm2": .development,
        "com.apple.terminal": .development,
        "net.kovidgoyal.kitty": .development,
        "dev.warp.warp-stable": .development,
        "com.postmanlabs.mac": .development,
        "com.electron.postman": .development,
        "com.google.android.studio": .development,
        "com.todesktop.230313mzl4w4u92": .development,
        "com.exafunction.windsurf": .development,
        "com.github.atom": .development,
        "com.jetbrains.intellij": .development,
        "com.jetbrains.pycharm": .development,
        "com.jetbrains.webstorm": .development,
        "com.jetbrains.goland": .development,
        "com.jetbrains.clion": .development,
        "com.jetbrains.datagrip": .development,
        "com.jetbrains.rustrover": .development,
        "com.jetbrains.fleet": .development,
        // Internet
        "com.apple.safari": .internet,
        "org.mozilla.firefox": .internet,
        "com.google.chrome": .internet,
        "com.microsoft.edgemac": .internet,
        "com.brave.browser": .internet,
        "com.operasoftware.opera": .internet,
        "com.vivaldi.vivaldi": .internet,
        "org.chromium.chromium": .internet,
        "company.thebrowser.browser": .internet,
        // Creation
        "com.figma.desktop": .creation,
        "com.sketch.sketch": .creation,
        "com.pixelmator.pro": .creation,
        "com.pixelmator.studio": .creation,
        "com.blackmagicdesign.davinciresolve": .creation,
        "com.adobe.photoshop": .creation,
        "com.adobe.illustrator": .creation,
        "com.adobe.indesign": .creation,
        "com.adobe.premierepro": .creation,
        "com.adobe.aftereffects": .creation,
        "com.seriflabs.affinitydesigner": .creation,
        "com.seriflabs.affinityphoto": .creation,
        "com.seriflabs.affinitypublisher": .creation,
        "com.canva.canva-desktop": .creation,
        "org.blenderfoundation.blender": .creation,
        "com.apple.garageband": .creation,
        "com.apple.imovie": .creation,
        "com.apple.finalcut": .creation,
        // Media
        "com.apple.music": .media,
        "com.apple.itunes": .media,
        "com.apple.quicktimeplayer": .media,
        "com.apple.tv": .media,
        "com.apple.podcasts": .media,
        "com.apple.photos": .media,
        "com.spotify.client": .media,
        "org.videolan.vlc": .media,
        "com.colliderli.iina": .media,
        "com.coppertino.vox": .media,
        // Office
        "com.apple.iwork.pages": .office,
        "com.apple.iwork.numbers": .office,
        "com.apple.iwork.keynote": .office,
        "com.apple.notes": .office,
        "com.apple.reminders": .office,
        "com.apple.calendar": .office,
        "com.apple.freeform": .office,
        "md.obsidian": .office,
        "notion.id": .office,
        "com.microsoft.word": .office,
        "com.microsoft.excel": .office,
        "com.microsoft.powerpoint": .office,
        "com.microsoft.onenote.mac": .office,
        "org.libreoffice.script": .office,
        // Communication
        "com.apple.mail": .communication,
        "com.apple.mobilesms": .communication,
        "com.apple.ichat": .communication,
        "com.apple.facetime": .communication,
        "com.microsoft.teams": .communication,
        "com.microsoft.teams2": .communication,
        "com.tinyspeck.slackmacgap": .communication,
        "com.hnc.Discord": .communication,
        "net.whatsapp.whatsapp": .communication,
        "ru.keepcoder.telegram": .communication,
        "org.signal-desktop": .communication,
        "com.readdle.smartemail": .communication,
        "org.mozilla.thunderbird": .communication,
        "us.zoom.xos": .communication,
        // Games
        "com.valvesoftware.steam": .games,
        "com.epicgames.launcher": .games,
        "com.mojang.minecraft": .games,
        "com.riotgames.leagueoflegends": .games,
        "net.zigzag.zigzag": .games,
        // Utilities
        "com.apple.calculator": .utilities,
        "com.apple.activitymonitor": .utilities,
        "com.apple.diskutility": .utilities,
        "com.apple.preview": .utilities,
        "com.apple.screenshot": .utilities,
        "com.apple.archiveutility": .utilities,
        "com.tailscale.tailscale": .utilities,
        // System
        "com.apple.finder": .system,
        "com.apple.systempreferences": .system,
        "com.apple.preferences": .system
    ]

    /// Bundle ID prefixes checked after exact matches.
    private static let prefixes: [(String, LaunchpadGroup)] = [
        ("com.jetbrains.", .development),
        ("com.microsoft.vscode", .development),
        ("com.adobe.", .creation),
        ("com.seriflabs.", .creation),
        ("org.mozilla.", .internet),
        ("com.apple.", .system)
    ]

    /// Name keywords (FR + EN), checked after bundle IDs.
    private static let keywords: [(String, LaunchpadGroup)] = [
        ("code", .development), ("xcode", .development), ("visual studio", .development),
        ("android studio", .development), ("terminal", .development), ("iterm", .development),
        ("git", .development), ("docker", .development), ("intellij", .development),
        ("pycharm", .development), ("webstorm", .development), ("goland", .development),
        ("datagrip", .development), ("rustrover", .development), ("sublim", .development),
        ("postman", .development), ("neovim", .development), ("emacs", .development),
        ("éditeur", .development), ("editeur", .development), ("développe", .development),
        ("developpe", .development), ("compiler", .development),

        ("navigateur", .internet), ("browser", .internet), ("firefox", .internet),
        ("chrome", .internet), ("brave", .internet), ("vivaldi", .internet),

        ("figma", .creation), ("sketch", .creation), ("photoshop", .creation),
        ("illustrator", .creation), ("indesign", .creation), ("premiere", .creation),
        ("after effects", .creation), ("davinci", .creation), ("resolve", .creation),
        ("affinity", .creation), ("canva", .creation), ("blender", .creation),
        ("pixelmator", .creation), ("dessin", .creation), ("design", .creation),
        ("création", .creation), ("creation", .creation), ("3d", .creation),

        ("spotify", .media), ("vlc", .media), ("iina", .media), ("quicktime", .media),
        ("musique", .media), ("music", .media), ("lecteur", .media), ("player", .media),
        ("vidéo", .media), ("video", .media), ("podcast", .media), ("radio", .media),
        ("audio", .media), ("photo", .media), ("tv", .media), ("netflix", .media),

        ("note", .office), ("notes", .office), ("texte", .office), ("text", .office),
        ("word", .office), ("excel", .office), ("powerpoint", .office), ("keynote", .office),
        ("pages", .office), ("numbers", .office), ("obsidian", .office), ("notion", .office),
        ("libreoffice", .office), ("agenda", .office), ("calendar", .office),
        ("calendrier", .office), ("tâche", .office), ("tache", .office), ("task", .office),
        ("todo", .office), ("office", .office), ("bureautique", .office), ("rappel", .office),

        ("mail", .communication), ("courriel", .communication), ("email", .communication),
        ("message", .communication), ("slack", .communication), ("discord", .communication),
        ("whatsapp", .communication), ("telegram", .communication), ("signal", .communication),
        ("teams", .communication), ("zoom", .communication), ("skype", .communication),
        ("facetime", .communication), ("chat", .communication), ("messenger", .communication),

        ("jeu", .games), ("game", .games), ("steam", .games), ("minecraft", .games),
        ("battlenet", .games), ("battle.net", .games), ("epic games", .games),

        ("calculatrice", .utilities), ("calculator", .utilities), ("archive", .utilities),
        ("compress", .utilities), ("décompres", .utilities), ("capture", .utilities),
        ("screenshot", .utilities), ("nettoy", .utilities), ("cleaner", .utilities),
        ("moniteur", .utilities), ("monitor", .utilities), ("presse-papiers", .utilities),
        ("clipboard", .utilities), ("vpn", .utilities), ("horloge", .utilities),
        ("clock", .utilities), ("minuteur", .utilities), ("timer", .utilities),
        ("convertisseur", .utilities), ("converter", .utilities), ("couleur", .utilities),
        ("color", .utilities), ("mot de passe", .utilities), ("password", .utilities),

        ("réglage", .system), ("reglage", .system), ("settings", .system),
        ("finder", .system), ("time machine", .system), ("système", .system),
        ("systeme", .system)
    ]

    static func group(for app: LaunchableApp) -> LaunchpadGroup {
        if app.commandSymbolName != nil { return .actions }
        if app.snippet != nil { return .snippets }

        let bundle = app.bundleID.lowercased()
        if let match = curated[bundle] { return match }

        let name = app.name.lowercased()
        for (keyword, group) in keywords
        where name.contains(keyword) {
            return group
        }

        for (prefix, group) in prefixes
        where bundle.hasPrefix(prefix) {
            return group
        }

        return .other
    }

    /// Groups a flat app list into ordered non-empty sections.
    static func grouped(_ apps: [LaunchableApp]) -> [(group: LaunchpadGroup, apps: [LaunchableApp])] {
        let byGroup = Dictionary(grouping: apps, by: group(for:))
        return LaunchpadGroup.allCases.compactMap { group in
            guard let members = byGroup[group], !members.isEmpty else { return nil }
            return (group, members)
        }
    }
}
