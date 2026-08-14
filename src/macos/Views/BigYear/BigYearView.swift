import SwiftUI

enum BigYearColorRole: String, CaseIterable, Codable, Identifiable {
    case page
    case cell
    case weekend
    case empty
    case border
    case holiday
    case birthday
    case event
    case today
    case todayBorder
    case text
    case secondaryText
    case zoneA
    case zoneB
    case zoneC

    var id: String { rawValue }
    var title: String {
        switch self {
        case .page: "Fond"
        case .cell: "Case"
        case .weekend: "Week-end"
        case .empty: "Case vide"
        case .border: "Contour"
        case .holiday: "Jour férié"
        case .birthday: "Anniversaire"
        case .event: "Événement"
        case .today: "Aujourd'hui"
        case .todayBorder: "Aujourd'hui (bordure)"
        case .text: "Texte principal"
        case .secondaryText: "Texte secondaire"
        case .zoneA: "Vacances zone A"
        case .zoneB: "Vacances zone B"
        case .zoneC: "Vacances zone C"
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3:
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (255, 255, 255)
        }
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    var hex: String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.white
        return String(format: "#%02X%02X%02X",
                      Int((nsColor.redComponent * 255).rounded()),
                      Int((nsColor.greenComponent * 255).rounded()),
                      Int((nsColor.blueComponent * 255).rounded()))
    }
}

enum BigYearTheme: String, CaseIterable, Codable, Identifiable {
    case pastel
    case catppuccinLatte
    case catppuccinMocha
    case dracula
    case poster

    var id: String { rawValue }
    var title: String {
        switch self {
        case .pastel: "Pastel clair"
        case .catppuccinLatte: "Catppuccin Latte"
        case .catppuccinMocha: "Catppuccin Mocha"
        case .dracula: "Dracula"
        case .poster: "Poster bleu"
        }
    }
    var isDark: Bool { self == .catppuccinMocha || self == .dracula }

    var colors: BigYearColors {
        switch self {
        case .pastel:
            BigYearColors(
                page: .white, cell: .white,
                weekend: Color(red: 0.93, green: 0.97, blue: 1),
                empty: .white, border: Color(red: 0.95, green: 0.94, blue: 0.97),
                holiday: Color(red: 0.73, green: 0.91, blue: 0.82),
                birthday: Color(red: 0.95, green: 0.78, blue: 0.86),
                event: Color(red: 0.72, green: 0.90, blue: 0.89),
                today: Color(red: 1, green: 0.93, blue: 0.62),
                todayBorder: Color(red: 0.98, green: 0.58, blue: 0.34),
                text: Color.black.opacity(0.84), secondaryText: Color.black.opacity(0.62),
                zones: [Color(red: 0.76, green: 0.87, blue: 0.98), Color(red: 0.98, green: 0.83, blue: 0.69), Color(red: 0.86, green: 0.80, blue: 0.95)]
            )
        case .catppuccinLatte:
            BigYearColors(
                page: Color(red: 0.94, green: 0.95, blue: 0.97), cell: Color(red: 0.98, green: 0.98, blue: 0.99),
                weekend: Color(red: 0.90, green: 0.91, blue: 0.94),
                empty: Color(red: 0.94, green: 0.95, blue: 0.97), border: Color(red: 0.86, green: 0.87, blue: 0.91),
                holiday: Color(red: 0.65, green: 0.82, blue: 0.59), birthday: Color(red: 0.92, green: 0.70, blue: 0.78),
                event: Color(red: 0.55, green: 0.81, blue: 0.78),
                today: Color(red: 0.98, green: 0.89, blue: 0.62), todayBorder: Color(red: 0.88, green: 0.56, blue: 0.35),
                text: Color(red: 0.30, green: 0.31, blue: 0.41), secondaryText: Color(red: 0.42, green: 0.44, blue: 0.56),
                zones: [Color(red: 0.55, green: 0.70, blue: 0.91), Color(red: 0.94, green: 0.70, blue: 0.48), Color(red: 0.75, green: 0.65, blue: 0.89)]
            )
        case .catppuccinMocha:
            BigYearColors(
                page: Color(red: 0.12, green: 0.12, blue: 0.18), cell: Color(red: 0.12, green: 0.12, blue: 0.18),
                weekend: Color(red: 0.18, green: 0.19, blue: 0.27), empty: Color(red: 0.10, green: 0.10, blue: 0.15),
                border: Color(red: 0.24, green: 0.25, blue: 0.34), holiday: Color(red: 0.65, green: 0.89, blue: 0.63),
                birthday: Color(red: 0.96, green: 0.76, blue: 0.91),
                event: Color(red: 0.45, green: 0.80, blue: 0.76), today: Color(red: 0.39, green: 0.40, blue: 0.54),
                todayBorder: Color(red: 0.98, green: 0.70, blue: 0.53), text: Color(red: 0.80, green: 0.84, blue: 0.96),
                secondaryText: Color(red: 0.65, green: 0.68, blue: 0.78),
                zones: [Color(red: 0.54, green: 0.71, blue: 0.98), Color(red: 0.98, green: 0.70, blue: 0.53), Color(red: 0.80, green: 0.65, blue: 0.97)]
            )
        case .dracula:
            BigYearColors(
                page: Color(red: 0.16, green: 0.16, blue: 0.21), cell: Color(red: 0.16, green: 0.16, blue: 0.21),
                weekend: Color(red: 0.19, green: 0.20, blue: 0.27), empty: Color(red: 0.14, green: 0.14, blue: 0.19),
                border: Color(red: 0.27, green: 0.28, blue: 0.35), holiday: Color(red: 0.55, green: 0.89, blue: 0.62),
                birthday: Color(red: 0.95, green: 0.55, blue: 0.80),
                event: Color(red: 0.45, green: 0.88, blue: 0.86), today: Color(red: 0.29, green: 0.30, blue: 0.40),
                todayBorder: Color(red: 0.95, green: 0.77, blue: 0.48), text: Color(red: 0.97, green: 0.97, blue: 0.95),
                secondaryText: Color(red: 0.74, green: 0.76, blue: 0.83),
                zones: [Color(red: 0.55, green: 0.80, blue: 0.93), Color(red: 0.95, green: 0.65, blue: 0.45), Color(red: 0.74, green: 0.58, blue: 0.90)]
            )
        case .poster:
            BigYearColors(
                page: Color(red: 0.98, green: 0.99, blue: 1), cell: .white,
                weekend: Color(red: 0.91, green: 0.95, blue: 0.98), empty: Color(red: 0.95, green: 0.97, blue: 0.99),
                border: Color(red: 0.13, green: 0.49, blue: 0.72), holiday: Color(red: 1, green: 0.19, blue: 0.18),
                birthday: Color(red: 0.64, green: 0.25, blue: 0.78), event: Color(red: 1, green: 0.57, blue: 0.24),
                today: Color(red: 1, green: 0.92, blue: 0.35), todayBorder: Color(red: 0.13, green: 0.49, blue: 0.72),
                text: Color(red: 0.06, green: 0.18, blue: 0.25), secondaryText: Color(red: 0.13, green: 0.49, blue: 0.72),
                zones: [Color(red: 0.69, green: 0.94, blue: 0.22), Color(red: 1, green: 0.57, blue: 0.24), Color(red: 1, green: 0.92, blue: 0.35)]
            )
        }
    }
}

struct BigYearColors {
    let page: Color
    let cell: Color
    let weekend: Color
    let empty: Color
    let border: Color
    let holiday: Color
    let birthday: Color
    let event: Color
    let today: Color
    let todayBorder: Color
    let text: Color
    let secondaryText: Color
    let zones: [Color]

    var swatches: [Color] { [weekend, holiday, birthday, zones[2]] }

    func zone(_ zone: String) -> Color {
        zones[zone == "B" ? 1 : zone == "C" ? 2 : 0]
    }

    func color(_ role: BigYearColorRole) -> Color {
        switch role {
        case .page: page
        case .cell: cell
        case .weekend: weekend
        case .empty: empty
        case .border: border
        case .holiday: holiday
        case .birthday: birthday
        case .event: event
        case .today: today
        case .todayBorder: todayBorder
        case .text: text
        case .secondaryText: secondaryText
        case .zoneA: zones[0]
        case .zoneB: zones[1]
        case .zoneC: zones[2]
        }
    }

    func withColor(_ role: BigYearColorRole, _ color: Color) -> BigYearColors {
        switch role {
        case .page: return BigYearColors(page: color, cell: cell, weekend: weekend, empty: empty, border: border, holiday: holiday, birthday: birthday, event: event, today: today, todayBorder: todayBorder, text: text, secondaryText: secondaryText, zones: zones)
        case .cell: return BigYearColors(page: page, cell: color, weekend: weekend, empty: empty, border: border, holiday: holiday, birthday: birthday, event: event, today: today, todayBorder: todayBorder, text: text, secondaryText: secondaryText, zones: zones)
        case .weekend: return BigYearColors(page: page, cell: cell, weekend: color, empty: empty, border: border, holiday: holiday, birthday: birthday, event: event, today: today, todayBorder: todayBorder, text: text, secondaryText: secondaryText, zones: zones)
        case .empty: return BigYearColors(page: page, cell: cell, weekend: weekend, empty: color, border: border, holiday: holiday, birthday: birthday, event: event, today: today, todayBorder: todayBorder, text: text, secondaryText: secondaryText, zones: zones)
        case .border: return BigYearColors(page: page, cell: cell, weekend: weekend, empty: empty, border: color, holiday: holiday, birthday: birthday, event: event, today: today, todayBorder: todayBorder, text: text, secondaryText: secondaryText, zones: zones)
        case .holiday: return BigYearColors(page: page, cell: cell, weekend: weekend, empty: empty, border: border, holiday: color, birthday: birthday, event: event, today: today, todayBorder: todayBorder, text: text, secondaryText: secondaryText, zones: zones)
        case .birthday: return BigYearColors(page: page, cell: cell, weekend: weekend, empty: empty, border: border, holiday: holiday, birthday: color, event: event, today: today, todayBorder: todayBorder, text: text, secondaryText: secondaryText, zones: zones)
        case .event: return BigYearColors(page: page, cell: cell, weekend: weekend, empty: empty, border: border, holiday: holiday, birthday: birthday, event: color, today: today, todayBorder: todayBorder, text: text, secondaryText: secondaryText, zones: zones)
        case .today: return BigYearColors(page: page, cell: cell, weekend: weekend, empty: empty, border: border, holiday: holiday, birthday: birthday, event: event, today: color, todayBorder: todayBorder, text: text, secondaryText: secondaryText, zones: zones)
        case .todayBorder: return BigYearColors(page: page, cell: cell, weekend: weekend, empty: empty, border: border, holiday: holiday, birthday: birthday, event: event, today: today, todayBorder: color, text: text, secondaryText: secondaryText, zones: zones)
        case .text: return BigYearColors(page: page, cell: cell, weekend: weekend, empty: empty, border: border, holiday: holiday, birthday: birthday, event: event, today: today, todayBorder: todayBorder, text: color, secondaryText: secondaryText, zones: zones)
        case .secondaryText: return BigYearColors(page: page, cell: cell, weekend: weekend, empty: empty, border: border, holiday: holiday, birthday: birthday, event: event, today: today, todayBorder: todayBorder, text: text, secondaryText: color, zones: zones)
        case .zoneA:
            var zones = zones
            zones[0] = color
            return BigYearColors(page: page, cell: cell, weekend: weekend, empty: empty, border: border, holiday: holiday, birthday: birthday, event: event, today: today, todayBorder: todayBorder, text: text, secondaryText: secondaryText, zones: zones)
        case .zoneB:
            var zones = zones
            zones[1] = color
            return BigYearColors(page: page, cell: cell, weekend: weekend, empty: empty, border: border, holiday: holiday, birthday: birthday, event: event, today: today, todayBorder: todayBorder, text: text, secondaryText: secondaryText, zones: zones)
        case .zoneC:
            var zones = zones
            zones[2] = color
            return BigYearColors(page: page, cell: cell, weekend: weekend, empty: empty, border: border, holiday: holiday, birthday: birthday, event: event, today: today, todayBorder: todayBorder, text: text, secondaryText: secondaryText, zones: zones)
        }
    }

    func applying(overrides: [String: String]) -> BigYearColors {
        overrides.reduce(self) { colors, entry in
            guard let role = BigYearColorRole(rawValue: entry.key) else { return colors }
            return colors.withColor(role, Color(hex: entry.value))
        }
    }
}

struct BigYearRootView: View {
    let year: Int
    @ObservedObject var settings: AppSettings
    let onClose: () -> Void
    @State private var displayedYear: Int
    @State private var vacations: [String: Set<String>] = [:]
    @State private var systemEvents: [String: [String]] = [:]
    @State private var optionsVisible = false
    @State private var selectedDate: Date?

    init(year: Int, settings: AppSettings, onClose: @escaping () -> Void) {
        self.year = year
        self.settings = settings
        self.onClose = onClose
        _displayedYear = State(initialValue: year)
    }

    var body: some View {
        GeometryReader { proxy in
            let headerHeight: CGFloat = 52
            ZStack(alignment: .leading) {
                VStack(spacing: 0) {
                    header
                        .frame(height: headerHeight)
                        .background(colors.weekend)
                    BigYearGrid(
                        year: displayedYear,
                        size: CGSize(width: proxy.size.width, height: max(1, proxy.size.height - headerHeight)),
                        holidays: BigYearData.frenchHolidays(in: displayedYear),
                        vacations: vacations,
                        birthdays: BigYearData.birthdays(from: settings.bigYearBirthdays),
                        events: allEvents,
                        selectedZone: settings.bigYearSchoolZone,
                        colors: colors,
                        posterMode: settings.bigYearTheme == .poster,
                        emphasizeBirthdays: settings.bigYearEmphasizeBirthdays,
                        emphasizeMonthNames: settings.bigYearEmphasizeMonthNames,
                        onSelectDate: { selectedDate = $0 }
                    )
                }
                if optionsVisible {
                    colors.zone("C").opacity(0.22)
                        .ignoresSafeArea()
                        .onTapGesture { optionsVisible = false }
                    optionsPanel
                        .frame(width: min(360, proxy.size.width * 0.34))
                        .transition(.move(edge: .leading))
                }
                if let selectedDate {
                    colors.text.opacity(0.18)
                        .ignoresSafeArea()
                        .onTapGesture { self.selectedDate = nil }
                    BigYearEventEditor(
                        date: selectedDate,
                        colors: colors,
                        onAdd: appendEvent,
                        onCancel: { self.selectedDate = nil }
                    )
                    .frame(width: min(430, proxy.size.width - 40))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(colors.page)
        }
        .task(id: displayedYear) {
            vacations = [:]
            vacations = await BigYearData.schoolVacations(in: displayedYear)
        }
        .task(id: "\(displayedYear)-\(settings.bigYearSystemCalendarEnabled)") {
            systemEvents = settings.bigYearSystemCalendarEnabled
                ? await SystemCalendarService.allDayEvents(in: displayedYear)
                : [:]
        }
        .environment(\.locale, Locale(identifier: "fr_FR"))
        .environment(\.colorScheme, settings.bigYearTheme.isDark ? .dark : .light)
        .onExitCommand(perform: onClose)
    }

    private var colors: BigYearColors { settings.bigYearColors }
    private var allEvents: [String: [String]] {
        systemEvents.merging(BigYearData.eventCoverage(from: settings.bigYearEvents, in: displayedYear)) { $0 + $1 }
    }

    private func appendEvent(_ line: String) {
        settings.bigYearEvents += settings.bigYearEvents.isEmpty ? line : "\n\(line)"
        selectedDate = nil
    }

    private var header: some View {
        ZStack {
            HStack {
                Button { withAnimation(.easeOut(duration: 0.18)) { optionsVisible = true } } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel("Options Big Year")
                .keyboardShortcut("e", modifiers: .command)
                Spacer()
                Button(action: onClose) {
                    Label("Quitter", systemImage: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .frame(height: 30)
                }
            }
            HStack(spacing: 10) {
                Button { displayedYear -= 1 } label: {
                    Image(systemName: "chevron.left").frame(width: 24, height: 24)
                }
                Text("\(displayedYear)")
                    .font(.system(size: 17, weight: .semibold))
                    .monospacedDigit()
                    .frame(minWidth: 58)
                Button { displayedYear += 1 } label: {
                    Image(systemName: "chevron.right").frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(colors.weekend, in: Capsule())
        }
        .padding(.horizontal, 14)
        .buttonStyle(.plain)
        .foregroundStyle(colors.text)
        .background(colors.weekend)
    }

    private var optionsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Options").font(.title3.weight(.semibold))
                Spacer()
                Button { withAnimation(.easeOut(duration: 0.18)) { optionsVisible = false } } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Thème").font(.headline)
                        VStack(spacing: 6) {
                            ForEach(BigYearTheme.allCases) { theme in
                                themeRow(theme)
                            }
                        }
                    }
                    BigYearAppearanceSection(settings: settings, colors: colors)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Vacances scolaires").font(.headline)
                        Picker("Zone", selection: $settings.bigYearSchoolZone) {
                            Text("Zone A").tag("A")
                            Text("Zone B").tag("B")
                            Text("Zone C").tag("C")
                        }
                        .pickerStyle(.segmented)
                        Text("Seule la zone sélectionnée est affichée dans la grille.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Anniversaires").font(.headline)
                        Text("Un anniversaire par ligne au format JJ.MM,Prénom ou JJMM,Prénom. Préfixe le prénom par ! pour le mettre en gras.")
                            .font(.caption).foregroundStyle(.secondary)
                        BirthdayEditor(text: $settings.bigYearBirthdays, onEscape: onClose)
                            .frame(minHeight: 150)
                        Text("11.02,!Clément\n0112,Marie")
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Événements").font(.headline)
                        Text("Un événement par ligne : JJ.MM ou JJ.MM-JJ.MM pour une plage, .AAAA pour une année précise. Préfixe le titre par ! pour le mettre en gras.")
                            .font(.caption).foregroundStyle(.secondary)
                        BirthdayEditor(text: $settings.bigYearEvents, onEscape: onClose)
                            .frame(minHeight: 110)
                        Text("08.02-15.02.2026,Ski\n03.11,Déplacement Paris\n28.12-03.01,!Fêtes")
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Calendriers macOS / Google", isOn: $settings.bigYearSystemCalendarEnabled)
                        Text("Lit les événements journée entière des comptes configurés dans Calendrier macOS.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Légende").font(.headline)
                        legend("Week-end", colors.weekend)
                        legend("Jour férié", colors.holiday)
                        legend("Anniversaire", colors.birthday)
                        legend("Événement", colors.event)
                        legend("Vacances zone \(settings.bigYearSchoolZone)", colors.zone(settings.bigYearSchoolZone))
                    }
                }
                .padding(18)
            }
            Spacer(minLength: 0)
            Divider()
            Text("Échap ferme Big Year")
                .font(.caption).foregroundStyle(.secondary).padding(18)
        }
        .frame(maxHeight: .infinity)
        .background(colors.page)
        .foregroundStyle(colors.text)
        .shadow(color: .black.opacity(0.18), radius: 18, x: 5)
        .onExitCommand(perform: onClose)
    }

    private func legend(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 24, height: 10)
            Text(title).font(.caption)
        }
    }

    private func themeRow(_ theme: BigYearTheme) -> some View {
        Button { settings.bigYearTheme = theme } label: {
            HStack(spacing: 10) {
                Text(theme.title)
                    .font(.system(size: 13, weight: settings.bigYearTheme == theme ? .semibold : .regular))
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 4) {
                    ForEach(Array(theme.colors.swatches.enumerated()), id: \.offset) { _, color in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color)
                            .frame(width: 14, height: 14)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.primary.opacity(0.12)))
                    }
                }
                Image(systemName: settings.bigYearTheme == theme ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(settings.bigYearTheme == theme ? Color.accentColor : Color.secondary.opacity(0.45))
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(settings.bigYearTheme == theme ? colors.weekend : colors.cell, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(colors.border))
        }
        .buttonStyle(.plain)
    }
}

struct BigYearAppearanceSection: View {
    @ObservedObject var settings: AppSettings
    let colors: BigYearColors

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Apparence").font(.headline)
            Toggle("Anniversaires en gras", isOn: $settings.bigYearEmphasizeBirthdays)
            Toggle("Noms des mois en gras", isOn: $settings.bigYearEmphasizeMonthNames)
            Text("Avec « ! » un élément reste toujours en gras, en plus du réglage ci-dessus.")
                .font(.caption).foregroundStyle(.secondary)
            VStack(spacing: 8) {
                ForEach(BigYearColorRole.allCases) { role in
                    colorRow(role)
                }
            }
            Button("Réinitialiser les couleurs") {
                settings.bigYearColorOverrides = [:]
            }
            .font(.caption)
        }
    }

    private func colorRow(_ role: BigYearColorRole) -> some View {
        HStack(spacing: 8) {
            Text(role.title)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            ColorPicker("", selection: binding(for: role), supportsOpacity: false)
                .labelsHidden()
        }
    }

    private func binding(for role: BigYearColorRole) -> Binding<Color> {
        Binding(
            get: {
                if let hex = settings.bigYearColorOverrides[role.rawValue] {
                    return Color(hex: hex)
                }
                return colors.color(role)
            },
            set: { settings.bigYearColorOverrides[role.rawValue] = $0.hex }
        )
    }
}

private struct BigYearEventEditor: View {
    let date: Date
    let colors: BigYearColors
    let onAdd: (String) -> Void
    let onCancel: () -> Void
    @State private var title = ""
    @State private var endDate: Date
    @State private var isRange = false
    @State private var repeatsYearly = false
    @State private var important = false
    @FocusState private var titleFocused: Bool

    init(date: Date, colors: BigYearColors, onAdd: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.date = date
        self.colors = colors
        self.onAdd = onAdd
        self.onCancel = onCancel
        _endDate = State(initialValue: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Nouvel événement").font(.title3.weight(.bold))
                Spacer()
                Button(action: onCancel) { Image(systemName: "xmark") }.buttonStyle(.plain)
            }
            TextField("Titre", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($titleFocused)
                .onSubmit(save)
            HStack {
                Text(BigYearData.fullDate(date)).font(.subheadline.weight(.medium))
                Spacer()
                Toggle("Plage", isOn: $isRange).toggleStyle(.switch)
            }
            if isRange {
                DatePicker("Jusqu’au", selection: $endDate, in: date..., displayedComponents: .date)
            }
            Toggle("Répéter chaque année", isOn: $repeatsYearly)
            Toggle("Important", isOn: $important)
            HStack {
                Spacer()
                Button("Annuler", action: onCancel)
                Button("Ajouter", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .foregroundStyle(colors.text)
        .background(colors.page, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(colors.border))
        .shadow(color: .black.opacity(0.25), radius: 24)
        .onAppear { titleFocused = true }
        .onExitCommand(perform: onCancel)
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = repeatsYearly ? "dd.MM" : "dd.MM.yyyy"
        var dates = formatter.string(from: date)
        if isRange { dates += "-\(formatter.string(from: endDate))" }
        onAdd("\(dates),\(important ? "!" : "")\(cleanTitle)")
    }
}

struct BigYearGrid: View {
    let year: Int
    let size: CGSize
    let holidays: [String: String]
    let vacations: [String: Set<String>]
    let birthdays: [String: [String]]
    let events: [String: [String]]
    let selectedZone: String
    let colors: BigYearColors
    var posterMode = false
    var emphasizeBirthdays = true
    var emphasizeMonthNames = true
    var onSelectDate: (Date) -> Void = { _ in }

    var body: some View {
        if posterMode {
            BigYearPosterGrid(
                year: year, size: size, holidays: holidays, vacations: vacations,
                birthdays: birthdays, events: events, selectedZone: selectedZone,
                colors: colors, emphasizeBirthdays: emphasizeBirthdays,
                emphasizeMonthNames: emphasizeMonthNames, onSelectDate: onSelectDate
            )
        } else {
            mosaic
        }
    }

    private var mosaic: some View {
        let days = yearDays
        let layout = BigYearGridLayout.compute(dayCount: days.count, size: size)
        let totalCells = layout.rows * layout.columns

        return ZStack(alignment: .topLeading) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(layout.cellWidth), spacing: 1), count: layout.columns),
                alignment: .leading,
                spacing: 1
            ) {
                ForEach(0..<totalCells, id: \.self) { index in
                    if index < days.count {
                        let date = days[index]
                        BigYearDayCell(
                            date: date,
                            size: min(layout.cellWidth, layout.cellHeight),
                            holiday: holidays[BigYearData.key(date)],
                            isOnVacation: (vacations[BigYearData.key(date)] ?? []).contains(selectedZone),
                            birthdays: birthdays[BigYearData.monthDayKey(date)] ?? [],
                            events: events[BigYearData.key(date)] ?? [],
                            colors: colors,
                            emphasizeMonthNames: emphasizeMonthNames
                        )
                        .frame(width: layout.cellWidth, height: layout.cellHeight)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelectDate(date) }
                    } else {
                        colors.empty.frame(width: layout.cellWidth, height: layout.cellHeight)
                    }
                }
            }
            eventOverlay(days: days, layout: layout)
        }
        .padding(1)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(colors.border)
        .clipped()
    }

    private func eventOverlay(days: [Date], layout: BigYearGridLayout) -> some View {        let segments = BigYearEventSegment.make(
            days: days,
            columns: layout.columns,
            holidays: holidays,
            vacations: vacations,
            birthdays: birthdays,
            customEvents: events,
            selectedZone: selectedZone,
            colors: colors
        )
        return ZStack(alignment: .topLeading) {
            ForEach(segments) { segment in
                Text(segment.title)
                    .font(.system(size: min(10, max(7, min(layout.cellWidth, layout.cellHeight) * 0.12)), weight: (segment.emphasized || (segment.isBirthday && emphasizeBirthdays)) ? .bold : .medium))
                    .foregroundStyle(Color(red: 0.18, green: 0.17, blue: 0.22).opacity(0.88))
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .frame(width: segment.width(cell: layout.cellWidth), height: 14, alignment: .leading)
                    .background(segment.color, in: RoundedRectangle(cornerRadius: 3))
                    .offset(
                        x: CGFloat(segment.startColumn) * (layout.cellWidth + 1) + 3,
                        y: CGFloat(segment.row) * (layout.cellHeight + 1) + 22 + CGFloat(segment.lane) * 16
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private var yearDays: [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "fr_FR")
        calendar.timeZone = .current
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let end = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else { return [] }
        var result: [Date] = []
        var date = start
        while date < end {
            result.append(date)
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return result
    }
}

private struct BigYearPosterGrid: View {
    let year: Int
    let size: CGSize
    let holidays: [String: String]
    let vacations: [String: Set<String>]
    let birthdays: [String: [String]]
    let events: [String: [String]]
    let selectedZone: String
    let colors: BigYearColors
    let emphasizeBirthdays: Bool
    let emphasizeMonthNames: Bool
    let onSelectDate: (Date) -> Void

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "fr_FR")
        calendar.timeZone = .current
        return calendar
    }

    var body: some View {
        let monthWidth = min(80, max(48, size.width * 0.06))
        let cellWidth = (size.width - monthWidth - 32) / 31
        let rowHeight = (size.height - 13) / 12
        VStack(spacing: 1) {
            ForEach(1...12, id: \.self) { month in
                monthRow(month: month, monthWidth: monthWidth, cellWidth: cellWidth, rowHeight: rowHeight)
            }
        }
        .padding(1)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(colors.border)
        .clipped()
    }

    private func monthRow(month: Int, monthWidth: CGFloat, cellWidth: CGFloat, rowHeight: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 1) {
                Text(calendar.shortMonthSymbols[month - 1].uppercased())
                    .font(.system(size: min(22, rowHeight * 0.48), weight: emphasizeMonthNames ? .black : .bold, design: .rounded))
                    .foregroundStyle(colors.border)
                    .frame(width: monthWidth, height: rowHeight, alignment: .trailing)
                    .padding(.trailing, 5)
                    .background(colors.page)
                ForEach(1...31, id: \.self) { day in
                    if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
                       calendar.component(.month, from: date) == month {
                        let key = BigYearData.key(date)
                        PosterDayCell(
                            date: date,
                            holiday: holidays[key],
                            isOnVacation: (vacations[key] ?? []).contains(selectedZone),
                            birthdays: birthdays[BigYearData.monthDayKey(date)] ?? [],
                            events: events[key] ?? [],
                            colors: colors,
                            emphasizeBirthdays: emphasizeBirthdays
                        )
                        .frame(width: cellWidth, height: rowHeight)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelectDate(date) }
                    } else {
                        colors.empty.frame(width: cellWidth, height: rowHeight)
                    }
                }
            }
            ForEach(eventRuns(month: month)) { run in
                Text(run.title)
                    .font(.system(size: min(12, rowHeight * 0.24), weight: run.emphasized ? .black : .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 4)
                    .frame(width: CGFloat(run.length) * (cellWidth + 1) - 2, height: rowHeight * 0.58, alignment: .center)
                    .offset(x: monthWidth + 1 + CGFloat(run.startDay - 1) * (cellWidth + 1), y: rowHeight * 0.30)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: rowHeight)
    }

    private func eventRuns(month: Int) -> [PosterEventRun] {
        var result: [PosterEventRun] = []
        var seen: Set<String> = []
        for day in 1...31 {
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
                  calendar.component(.month, from: date) == month else { continue }
            for name in events[BigYearData.key(date)] ?? [] where !seen.contains(name) {
                var length = 1
                while day + length <= 31,
                      let next = calendar.date(from: DateComponents(year: year, month: month, day: day + length)),
                      (events[BigYearData.key(next)] ?? []).contains(name) {
                    length += 1
                }
                seen.insert(name)
                let emphasized = name.hasPrefix("!")
                let title = emphasized ? String(name.dropFirst()).trimmingCharacters(in: .whitespaces) : name
                result.append(PosterEventRun(title: title, startDay: day, length: length, emphasized: emphasized))
            }
        }
        return result
    }
}

private struct PosterEventRun: Identifiable {
    let title: String
    let startDay: Int
    let length: Int
    let emphasized: Bool
    var id: String { "\(title)-\(startDay)" }
}

private struct PosterDayCell: View {
    let date: Date
    let holiday: String?
    let isOnVacation: Bool
    let birthdays: [String]
    let events: [String]
    let colors: BigYearColors
    var emphasizeBirthdays = true

    private var calendar: Calendar { Calendar(identifier: .gregorian) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(background)
            Text(label)
                .font(.system(size: 6, weight: .bold, design: .rounded))
                .foregroundStyle(colors.secondaryText)
                .padding(2)
            if events.isEmpty, let note {
                Text(note)
                    .font(.system(size: 8, weight: emphasizeBirthdays ? .bold : .regular, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)
                    .padding(3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .overlay { if calendar.isDateInToday(date) { Rectangle().stroke(colors.todayBorder, lineWidth: 3) } }
        .help(BigYearData.fullDate(date))
    }

    private var label: String {
        let weekday = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
            .replacingOccurrences(of: ".", with: "").uppercased()
        return "\(calendar.component(.day, from: date))  \(weekday)"
    }
    private var note: String? {
        if let birthday = birthdays.first { return "🎂 \(birthday.trimmingCharacters(in: CharacterSet(charactersIn: "! ")))" }
        return holiday
    }
    private var background: Color {
        if calendar.isDateInToday(date) { return colors.today }
        if !events.isEmpty { return colors.event }
        if !birthdays.isEmpty { return colors.birthday }
        if holiday != nil { return colors.holiday }
        if isOnVacation { return colors.zone("A") }
        return calendar.isDateInWeekend(date) ? colors.weekend : colors.cell
    }
}

private struct BigYearGridLayout {
    let columns: Int
    let rows: Int
    let cellWidth: CGFloat
    let cellHeight: CGFloat

    static func compute(dayCount: Int, size: CGSize) -> BigYearGridLayout {
        var best = BigYearGridLayout(columns: 1, rows: dayCount, cellWidth: 1, cellHeight: 1)
        var bestDifference = CGFloat.greatestFiniteMagnitude
        for columns in 1...dayCount {
            let rows = Int(ceil(Double(dayCount) / Double(columns)))
            let width = (size.width - CGFloat(columns - 1) - 2) / CGFloat(columns)
            let height = (size.height - CGFloat(rows - 1) - 2) / CGFloat(rows)
            guard width > 0, height > 0 else { continue }
            let difference = abs(width - height)
            if difference < bestDifference {
                bestDifference = difference
                best = BigYearGridLayout(columns: columns, rows: rows, cellWidth: width, cellHeight: height)
            }
        }
        return best
    }
}

private struct BigYearEventSegment: Identifiable {
    let id: String
    let title: String
    let color: Color
    let row: Int
    let startColumn: Int
    let endColumn: Int
    let lane: Int
    let emphasized: Bool
    let isBirthday: Bool

    func width(cell: CGFloat) -> CGFloat { max(8, CGFloat(endColumn - startColumn) * (cell + 1) - 5) }

    static func make(
        days: [Date], columns: Int, holidays: [String: String], vacations: [String: Set<String>],
        birthdays: [String: [String]], customEvents: [String: [String]], selectedZone: String, colors: BigYearColors
    ) -> [BigYearEventSegment] {
        var events: [(id: String, title: String, color: Color, start: Int, end: Int, emphasized: Bool, isBirthday: Bool)] = []
        for (index, date) in days.enumerated() {
            let key = BigYearData.key(date)
            if let holiday = holidays[key] { events.append(("holiday-\(key)", holiday, colors.holiday, index, index + 1, false, false)) }
            for (birthdayIndex, name) in (birthdays[BigYearData.monthDayKey(date)] ?? []).enumerated() {
                let emphasized = name.hasPrefix("!")
                let displayName = emphasized ? String(name.dropFirst()).trimmingCharacters(in: .whitespaces) : name
                events.append(("birthday-\(key)-\(birthdayIndex)", "🎂 \(displayName)", colors.birthday, index, index + 1, emphasized, true))
            }
        }
        for (name, indices) in groupCustomEvents(coverage: customEvents, days: days) {
            let emphasized = name.hasPrefix("!")
            let title = emphasized ? String(name.dropFirst()).trimmingCharacters(in: .whitespaces) : name
            for (runStart, runEnd) in indices {
                events.append(("userevent-\(name)-\(runStart)", title, colors.event, runStart, runEnd + 1, emphasized, false))
            }
        }
        var start: Int?
        for index in 0...days.count {
            let active = index < days.count && (vacations[BigYearData.key(days[index])] ?? []).contains(selectedZone)
            if active, start == nil { start = index }
            if !active, let rangeStart = start {
                events.append(("vacation-\(selectedZone)-\(rangeStart)", "Vacances zone \(selectedZone)", colors.zone(selectedZone), rangeStart, index, false, false))
                start = nil
            }
        }

        var raw: [(id: String, title: String, color: Color, row: Int, start: Int, end: Int, emphasized: Bool, isBirthday: Bool)] = []
        for event in events {
            var cursor = event.start
            while cursor < event.end {
                let row = cursor / columns
                let rowEnd = min(event.end, (row + 1) * columns)
                raw.append((event.id + "-\(row)", event.title, event.color, row, cursor % columns, rowEnd - row * columns, event.emphasized, event.isBirthday))
                cursor = rowEnd
            }
        }
        var laneEnds: [Int: [Int]] = [:]
        return raw.sorted { ($0.row, $0.start, -$0.end) < ($1.row, $1.start, -$1.end) }.map { segment in
            var ends = laneEnds[segment.row] ?? []
            let lane = ends.firstIndex(where: { $0 <= segment.start }) ?? ends.count
            if lane == ends.count { ends.append(segment.end) } else { ends[lane] = segment.end }
            laneEnds[segment.row] = ends
            return BigYearEventSegment(id: segment.id, title: segment.title, color: segment.color, row: segment.row, startColumn: segment.start, endColumn: segment.end, lane: lane, emphasized: segment.emphasized, isBirthday: segment.isBirthday)
        }
    }

    /// Regroupe les jours consécutifs de chaque événement personnalisé en plages (début, fin).
    private static func groupCustomEvents(
        coverage: [String: [String]], days: [Date]
    ) -> [String: [(Int, Int)]] {
        var indicesByName: [String: [Int]] = [:]
        for (index, date) in days.enumerated() {
            for name in coverage[BigYearData.key(date)] ?? [] {
                indicesByName[name, default: []].append(index)
            }
        }
        var result: [String: [(Int, Int)]] = [:]
        for (name, indices) in indicesByName {
            var runs: [(Int, Int)] = []
            var runStart = indices.first ?? 0
            var previous = runStart
            for index in indices.dropFirst() {
                if index == previous + 1 { previous = index; continue }
                runs.append((runStart, previous))
                runStart = index
                previous = index
            }
            if !indices.isEmpty { runs.append((runStart, previous)) }
            result[name] = runs
        }
        return result
    }
}

private struct BigYearDayCell: View {
    let date: Date
    let size: CGFloat
    let holiday: String?
    let isOnVacation: Bool
    let birthdays: [String]
    let events: [String]
    let colors: BigYearColors
    var emphasizeMonthNames = true

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(cellBackground)
            if isFirstOfMonth, size > 42 {
                Text(monthName.uppercased())
                    .font(.system(size: min(9, size * 0.12), weight: emphasizeMonthNames ? .bold : .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .padding(.horizontal, 5)
                    .frame(maxWidth: size * 0.58)
                    .frame(height: 16)
                    .background(Color.black.opacity(0.9))
            }
            Text(dayLabel)
                .font(.system(size: min(11, max(7, size * 0.14)), weight: isToday ? .bold : .regular))
                .foregroundStyle(isToday ? colors.text : colors.secondaryText)
                .lineLimit(1)
                .padding(.horizontal, isToday ? 6 : 4)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .topTrailing)
            if isToday {
                Text("AUJOURD’HUI")
                    .font(.system(size: max(6, size * 0.09), weight: .bold))
                    .foregroundStyle(colors.text.opacity(0.82))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(colors.page.opacity(0.78), in: Capsule())
                    .padding(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .overlay { if isToday { Rectangle().stroke(colors.todayBorder, lineWidth: 3) } }
        .overlay(alignment: .leading) { if isFirstOfMonth { Rectangle().fill(colors.border).frame(width: 2) } }
        .help(helpText)
    }

    private var isToday: Bool { calendar.isDateInToday(date) }
    private var isWeekend: Bool { calendar.isDateInWeekend(date) }
    private var hasImportantBirthday: Bool { birthdays.contains(where: { $0.hasPrefix("!") }) }
    private var hasEvent: Bool { !events.isEmpty }
    private var isFirstOfMonth: Bool { calendar.component(.day, from: date) == 1 }
    private var monthName: String { calendar.monthSymbols[calendar.component(.month, from: date) - 1] }
    private var dayLabel: String {
        let weekday = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
            .replacingOccurrences(of: ".", with: "")
            .uppercased()
        return "\(weekday) \(calendar.component(.day, from: date))"
    }
    private var cellBackground: Color {
        if isToday { return colors.today }
        if hasEvent { return colors.event.opacity(0.32) }
        if hasImportantBirthday { return colors.birthday.opacity(0.32) }
        return isWeekend ? colors.weekend : colors.cell
    }
    private var helpText: String {
        var parts = [BigYearData.fullDate(date)]
        if let holiday { parts.append(holiday) }
        if isOnVacation { parts.append("Vacances zone sélectionnée") }
        if !events.isEmpty {
            parts.append("Événement : " + events.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "! ")) }.joined(separator: ", "))
        }
        if !birthdays.isEmpty {
            parts.append("🎂 Anniversaire : " + birthdays.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "! ")) }.joined(separator: ", "))
        }
        return parts.joined(separator: "\n")
    }
}
