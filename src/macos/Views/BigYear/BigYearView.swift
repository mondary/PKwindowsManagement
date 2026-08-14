import SwiftUI

enum BigYearTheme: String, CaseIterable, Codable, Identifiable {
    case pastel
    case catppuccinLatte
    case catppuccinMocha
    case dracula

    var id: String { rawValue }
    var title: String {
        switch self {
        case .pastel: "Pastel clair"
        case .catppuccinLatte: "Catppuccin Latte"
        case .catppuccinMocha: "Catppuccin Mocha"
        case .dracula: "Dracula"
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
                today: Color(red: 0.98, green: 0.89, blue: 0.62), todayBorder: Color(red: 0.88, green: 0.56, blue: 0.35),
                text: Color(red: 0.30, green: 0.31, blue: 0.41), secondaryText: Color(red: 0.42, green: 0.44, blue: 0.56),
                zones: [Color(red: 0.55, green: 0.70, blue: 0.91), Color(red: 0.94, green: 0.70, blue: 0.48), Color(red: 0.75, green: 0.65, blue: 0.89)]
            )
        case .catppuccinMocha:
            BigYearColors(
                page: Color(red: 0.12, green: 0.12, blue: 0.18), cell: Color(red: 0.12, green: 0.12, blue: 0.18),
                weekend: Color(red: 0.18, green: 0.19, blue: 0.27), empty: Color(red: 0.10, green: 0.10, blue: 0.15),
                border: Color(red: 0.24, green: 0.25, blue: 0.34), holiday: Color(red: 0.65, green: 0.89, blue: 0.63),
                birthday: Color(red: 0.96, green: 0.76, blue: 0.91), today: Color(red: 0.39, green: 0.40, blue: 0.54),
                todayBorder: Color(red: 0.98, green: 0.70, blue: 0.53), text: Color(red: 0.80, green: 0.84, blue: 0.96),
                secondaryText: Color(red: 0.65, green: 0.68, blue: 0.78),
                zones: [Color(red: 0.54, green: 0.71, blue: 0.98), Color(red: 0.98, green: 0.70, blue: 0.53), Color(red: 0.80, green: 0.65, blue: 0.97)]
            )
        case .dracula:
            BigYearColors(
                page: Color(red: 0.16, green: 0.16, blue: 0.21), cell: Color(red: 0.16, green: 0.16, blue: 0.21),
                weekend: Color(red: 0.19, green: 0.20, blue: 0.27), empty: Color(red: 0.14, green: 0.14, blue: 0.19),
                border: Color(red: 0.27, green: 0.28, blue: 0.35), holiday: Color(red: 0.55, green: 0.89, blue: 0.62),
                birthday: Color(red: 0.95, green: 0.55, blue: 0.80), today: Color(red: 0.29, green: 0.30, blue: 0.40),
                todayBorder: Color(red: 0.95, green: 0.77, blue: 0.48), text: Color(red: 0.97, green: 0.97, blue: 0.95),
                secondaryText: Color(red: 0.74, green: 0.76, blue: 0.83),
                zones: [Color(red: 0.55, green: 0.80, blue: 0.93), Color(red: 0.95, green: 0.65, blue: 0.45), Color(red: 0.74, green: 0.58, blue: 0.90)]
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
    let today: Color
    let todayBorder: Color
    let text: Color
    let secondaryText: Color
    let zones: [Color]

    var swatches: [Color] { [weekend, holiday, birthday, zones[2]] }

    func zone(_ zone: String) -> Color {
        zones[zone == "B" ? 1 : zone == "C" ? 2 : 0]
    }
}

struct BigYearRootView: View {
    let year: Int
    @ObservedObject var settings: AppSettings
    let onClose: () -> Void
    @State private var displayedYear: Int
    @State private var vacations: [String: Set<String>] = [:]
    @State private var optionsVisible = false

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
                        selectedZone: settings.bigYearSchoolZone,
                        colors: colors
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
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(colors.page)
        }
        .task(id: displayedYear) {
            vacations = [:]
            vacations = await BigYearData.schoolVacations(in: displayedYear)
        }
        .environment(\.locale, Locale(identifier: "fr_FR"))
        .environment(\.colorScheme, settings.bigYearTheme.isDark ? .dark : .light)
    }

    private var colors: BigYearColors { settings.bigYearTheme.colors }

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
                        BirthdayEditor(text: $settings.bigYearBirthdays, autoFocus: true)
                            .frame(minHeight: 150)
                        Text("11.02,!Clément\n0112,Marie")
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Légende").font(.headline)
                        legend("Week-end", colors.weekend)
                        legend("Jour férié", colors.holiday)
                        legend("Anniversaire", colors.birthday)
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

struct BigYearGrid: View {
    let year: Int
    let size: CGSize
    let holidays: [String: String]
    let vacations: [String: Set<String>]
    let birthdays: [String: [String]]
    let selectedZone: String
    let colors: BigYearColors

    var body: some View {
        let days = yearDays
        let layout = BigYearGridLayout.compute(dayCount: days.count, size: size)
        let totalCells = layout.rows * layout.columns

        ZStack(alignment: .topLeading) {
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
                            colors: colors
                        )
                        .frame(width: layout.cellWidth, height: layout.cellHeight)
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

    private func eventOverlay(days: [Date], layout: BigYearGridLayout) -> some View {
        let segments = BigYearEventSegment.make(
            days: days,
            columns: layout.columns,
            holidays: holidays,
            vacations: vacations,
            birthdays: birthdays,
            selectedZone: selectedZone,
            colors: colors
        )
        return ZStack(alignment: .topLeading) {
            ForEach(segments) { segment in
                Text(segment.title)
                    .font(.system(size: min(10, max(7, min(layout.cellWidth, layout.cellHeight) * 0.12)), weight: segment.emphasized ? .bold : .medium))
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

    func width(cell: CGFloat) -> CGFloat { max(8, CGFloat(endColumn - startColumn) * (cell + 1) - 5) }

    static func make(
        days: [Date], columns: Int, holidays: [String: String], vacations: [String: Set<String>],
        birthdays: [String: [String]], selectedZone: String, colors: BigYearColors
    ) -> [BigYearEventSegment] {
        var events: [(id: String, title: String, color: Color, start: Int, end: Int, emphasized: Bool)] = []
        for (index, date) in days.enumerated() {
            let key = BigYearData.key(date)
            if let holiday = holidays[key] { events.append(("holiday-\(key)", holiday, colors.holiday, index, index + 1, false)) }
            for (birthdayIndex, name) in (birthdays[BigYearData.monthDayKey(date)] ?? []).enumerated() {
                let emphasized = name.hasPrefix("!")
                let displayName = emphasized ? String(name.dropFirst()).trimmingCharacters(in: .whitespaces) : name
                events.append(("birthday-\(key)-\(birthdayIndex)", "🎂 \(displayName)", colors.birthday, index, index + 1, emphasized))
            }
        }
        var start: Int?
        for index in 0...days.count {
            let active = index < days.count && (vacations[BigYearData.key(days[index])] ?? []).contains(selectedZone)
            if active, start == nil { start = index }
            if !active, let rangeStart = start {
                events.append(("vacation-\(selectedZone)-\(rangeStart)", "Vacances zone \(selectedZone)", colors.zone(selectedZone), rangeStart, index, false))
                start = nil
            }
        }

        var raw: [(id: String, title: String, color: Color, row: Int, start: Int, end: Int, emphasized: Bool)] = []
        for event in events {
            var cursor = event.start
            while cursor < event.end {
                let row = cursor / columns
                let rowEnd = min(event.end, (row + 1) * columns)
                raw.append((event.id + "-\(row)", event.title, event.color, row, cursor % columns, rowEnd - row * columns, event.emphasized))
                cursor = rowEnd
            }
        }
        var laneEnds: [Int: [Int]] = [:]
        return raw.sorted { ($0.row, $0.start, -$0.end) < ($1.row, $1.start, -$1.end) }.map { segment in
            var ends = laneEnds[segment.row] ?? []
            let lane = ends.firstIndex(where: { $0 <= segment.start }) ?? ends.count
            if lane == ends.count { ends.append(segment.end) } else { ends[lane] = segment.end }
            laneEnds[segment.row] = ends
            return BigYearEventSegment(id: segment.id, title: segment.title, color: segment.color, row: segment.row, startColumn: segment.start, endColumn: segment.end, lane: lane, emphasized: segment.emphasized)
        }
    }
}

private struct BigYearDayCell: View {
    let date: Date
    let size: CGFloat
    let holiday: String?
    let isOnVacation: Bool
    let birthdays: [String]
    let colors: BigYearColors

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
                    .font(.system(size: min(9, size * 0.12), weight: .semibold))
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
        if hasImportantBirthday { return colors.birthday.opacity(0.32) }
        return isWeekend ? colors.weekend : colors.cell
    }
    private var helpText: String {
        var parts = [BigYearData.fullDate(date)]
        if let holiday { parts.append(holiday) }
        if isOnVacation { parts.append("Vacances zone sélectionnée") }
        if !birthdays.isEmpty {
            parts.append("🎂 Anniversaire : " + birthdays.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "! ")) }.joined(separator: ", "))
        }
        return parts.joined(separator: "\n")
    }
}
