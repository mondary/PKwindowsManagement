import SwiftUI

private enum BigYearPalette {
    static let page = Color.white
    static let cell = Color.white
    static let weekend = Color(red: 0.93, green: 0.97, blue: 1.00)
    static let empty = Color.white
    static let border = Color(red: 0.95, green: 0.94, blue: 0.97)
    static let holiday = Color(red: 0.73, green: 0.91, blue: 0.82)
    static let birthday = Color(red: 0.95, green: 0.78, blue: 0.86)
    static let today = Color(red: 1.00, green: 0.93, blue: 0.62)
    static let todayBorder = Color(red: 0.98, green: 0.58, blue: 0.34)

    static func zone(_ zone: String) -> Color {
        switch zone {
        case "B": Color(red: 0.98, green: 0.83, blue: 0.69)
        case "C": Color(red: 0.86, green: 0.80, blue: 0.95)
        default: Color(red: 0.76, green: 0.87, blue: 0.98)
        }
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
                    header.frame(height: headerHeight)
                    BigYearGrid(
                        year: displayedYear,
                        size: CGSize(width: proxy.size.width, height: max(1, proxy.size.height - headerHeight)),
                        holidays: BigYearData.frenchHolidays(in: displayedYear),
                        vacations: vacations,
                        birthdays: BigYearData.birthdays(from: settings.bigYearBirthdays),
                        selectedZone: settings.bigYearSchoolZone
                    )
                }
                if optionsVisible {
                    Color(red: 0.84, green: 0.80, blue: 0.92).opacity(0.22)
                        .ignoresSafeArea()
                        .onTapGesture { optionsVisible = false }
                    optionsPanel
                        .frame(width: min(360, proxy.size.width * 0.34))
                        .transition(.move(edge: .leading))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .task(id: displayedYear) {
            vacations = [:]
            vacations = await BigYearData.schoolVacations(in: displayedYear)
        }
        .environment(\.locale, Locale(identifier: "fr_FR"))
        .environment(\.colorScheme, .light)
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
            .background(BigYearPalette.weekend, in: Capsule())
        }
        .padding(.horizontal, 14)
        .buttonStyle(.plain)
        .foregroundStyle(Color.black.opacity(0.84))
        .background(BigYearPalette.page)
        .overlay(alignment: .bottom) { BigYearPalette.border.frame(height: 1) }
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
                        Text("Un anniversaire par ligne au format MM-JJ,Prénom. Les lignes vides sont ignorées.")
                            .font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: $settings.bigYearBirthdays)
                            .font(.system(.body, design: .monospaced))
                            .disableAutocorrection(true)
                            .frame(minHeight: 150)
                            .padding(6)
                            .background(Color(red: 0.96, green: 0.96, blue: 0.96), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(BigYearPalette.border))
                        Text("11-02,Clément\n03-18,Marie")
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Légende").font(.headline)
                        legend("Week-end", BigYearPalette.weekend)
                        legend("Jour férié", BigYearPalette.holiday)
                        legend("Anniversaire", BigYearPalette.birthday)
                        legend("Vacances zone \(settings.bigYearSchoolZone)", BigYearPalette.zone(settings.bigYearSchoolZone))
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
        .background(Color.white)
        .foregroundStyle(Color.black.opacity(0.86))
        .shadow(color: .black.opacity(0.18), radius: 18, x: 5)
    }

    private func legend(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 24, height: 10)
            Text(title).font(.caption)
        }
    }
}

private struct BigYearGrid: View {
    let year: Int
    let size: CGSize
    let holidays: [String: String]
    let vacations: [String: Set<String>]
    let birthdays: [String: [String]]
    let selectedZone: String

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
                            birthdays: birthdays[BigYearData.monthDayKey(date)] ?? []
                        )
                        .frame(width: layout.cellWidth, height: layout.cellHeight)
                    } else {
                        BigYearPalette.empty.frame(width: layout.cellWidth, height: layout.cellHeight)
                    }
                }
            }
            eventOverlay(days: days, layout: layout)
        }
        .padding(1)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(BigYearPalette.border)
        .clipped()
    }

    private func eventOverlay(days: [Date], layout: BigYearGridLayout) -> some View {
        let segments = BigYearEventSegment.make(
            days: days,
            columns: layout.columns,
            holidays: holidays,
            vacations: vacations,
            birthdays: birthdays,
            selectedZone: selectedZone
        )
        return ZStack(alignment: .topLeading) {
            ForEach(segments) { segment in
                Text(segment.title)
                    .font(.system(size: min(9, max(7, min(layout.cellWidth, layout.cellHeight) * 0.11)), weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.68))
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

    func width(cell: CGFloat) -> CGFloat { max(8, CGFloat(endColumn - startColumn) * (cell + 1) - 5) }

    static func make(
        days: [Date], columns: Int, holidays: [String: String], vacations: [String: Set<String>],
        birthdays: [String: [String]], selectedZone: String
    ) -> [BigYearEventSegment] {
        var events: [(id: String, title: String, color: Color, start: Int, end: Int)] = []
        for (index, date) in days.enumerated() {
            let key = BigYearData.key(date)
            if let holiday = holidays[key] { events.append(("holiday-\(key)", holiday, BigYearPalette.holiday, index, index + 1)) }
            for (birthdayIndex, name) in (birthdays[BigYearData.monthDayKey(date)] ?? []).enumerated() {
                events.append(("birthday-\(key)-\(birthdayIndex)", "🎂 \(name)", BigYearPalette.birthday, index, index + 1))
            }
        }
        var start: Int?
        for index in 0...days.count {
            let active = index < days.count && (vacations[BigYearData.key(days[index])] ?? []).contains(selectedZone)
            if active, start == nil { start = index }
            if !active, let rangeStart = start {
                events.append(("vacation-\(selectedZone)-\(rangeStart)", "Vacances zone \(selectedZone)", BigYearPalette.zone(selectedZone), rangeStart, index))
                start = nil
            }
        }

        var raw: [(id: String, title: String, color: Color, row: Int, start: Int, end: Int)] = []
        for event in events {
            var cursor = event.start
            while cursor < event.end {
                let row = cursor / columns
                let rowEnd = min(event.end, (row + 1) * columns)
                raw.append((event.id + "-\(row)", event.title, event.color, row, cursor % columns, rowEnd - row * columns))
                cursor = rowEnd
            }
        }
        var laneEnds: [Int: [Int]] = [:]
        return raw.sorted { ($0.row, $0.start, -$0.end) < ($1.row, $1.start, -$1.end) }.map { segment in
            var ends = laneEnds[segment.row] ?? []
            let lane = ends.firstIndex(where: { $0 <= segment.start }) ?? ends.count
            if lane == ends.count { ends.append(segment.end) } else { ends[lane] = segment.end }
            laneEnds[segment.row] = ends
            return BigYearEventSegment(id: segment.id, title: segment.title, color: segment.color, row: segment.row, startColumn: segment.start, endColumn: segment.end, lane: lane)
        }
    }
}

private struct BigYearDayCell: View {
    let date: Date
    let size: CGFloat
    let holiday: String?
    let isOnVacation: Bool
    let birthdays: [String]

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(isToday ? BigYearPalette.today : (isWeekend ? BigYearPalette.weekend : BigYearPalette.cell))
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
                .foregroundStyle(isToday ? Color.black.opacity(0.9) : Color.black.opacity(0.62))
                .lineLimit(1)
                .padding(.horizontal, isToday ? 6 : 4)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .topTrailing)
            if isToday {
                Text("AUJOURD’HUI")
                    .font(.system(size: max(6, size * 0.09), weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.72))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.72), in: Capsule())
                    .padding(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .overlay { if isToday { Rectangle().stroke(BigYearPalette.todayBorder, lineWidth: 3) } }
        .overlay(alignment: .leading) { if isFirstOfMonth { Rectangle().fill(BigYearPalette.border).frame(width: 2) } }
        .help(helpText)
    }

    private var isToday: Bool { calendar.isDateInToday(date) }
    private var isWeekend: Bool { calendar.isDateInWeekend(date) }
    private var isFirstOfMonth: Bool { calendar.component(.day, from: date) == 1 }
    private var monthName: String { calendar.monthSymbols[calendar.component(.month, from: date) - 1] }
    private var dayLabel: String {
        let weekday = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
            .replacingOccurrences(of: ".", with: "")
            .uppercased()
        return "\(weekday) \(calendar.component(.day, from: date))"
    }
    private var helpText: String {
        var parts = [BigYearData.fullDate(date)]
        if let holiday { parts.append(holiday) }
        if isOnVacation { parts.append("Vacances zone sélectionnée") }
        if !birthdays.isEmpty { parts.append("🎂 Anniversaire : " + birthdays.joined(separator: ", ")) }
        return parts.joined(separator: "\n")
    }
}
