import SwiftUI

struct BigYearRootView: View {
    let year: Int
    let onClose: () -> Void
    @State private var displayedYear: Int

    init(year: Int, onClose: @escaping () -> Void) {
        self.year = year
        self.onClose = onClose
        _displayedYear = State(initialValue: year)
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = BigYearLayout.compute(
                width: proxy.size.width,
                height: proxy.size.height,
                year: displayedYear
            )

            ZStack(alignment: .top) {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.985, green: 0.985, blue: 0.985))
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1)
                        }

                    BigYearGrid(
                        year: displayedYear,
                        layout: layout
                    )
                }
            }
        }
        .environment(\.locale, AppLocalization.locale)
    }

    private var header: some View {
        HStack {
            closeButton
            navButton("chevron.left") { displayedYear -= 1 }
            Spacer()
            Text("\(displayedYear)")
                .font(.system(size: 15, weight: .semibold, design: .default))
                .monospacedDigit()
                .foregroundStyle(.black.opacity(0.78))
            Spacer()
            navButton("chevron.right") { displayedYear += 1 }
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.black.opacity(0.72))
        .accessibilityLabel(localizedString("Close Big Year"))
    }

    private func navButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.black.opacity(0.72))
    }
}

private struct BigYearGrid: View {
    let year: Int
    let layout: BigYearLayout

    var body: some View {
        GeometryReader { proxy in
            let cell = layout.cellSize
            let gap: CGFloat = 1
            let totalWidth = CGFloat(layout.columns) * cell + CGFloat(layout.columns - 1) * gap
            let totalHeight = CGFloat(layout.rows) * cell + CGFloat(layout.rows - 1) * gap
            let originX = max(0, (proxy.size.width - totalWidth) / 2)
            let originY = max(0, (proxy.size.height - totalHeight) / 2)
            let days = BigYearCalendar.days(in: year)

            ZStack(alignment: .topLeading) {
                Color.clear

                ForEach(days.indices, id: \.self) { index in
                    let day = days[index]
                    let column = index / 7
                    let row = index % 7
                    let x = originX + CGFloat(column) * (cell + gap)
                    let y = originY + CGFloat(row) * (cell + gap)
                    BigYearDayCell(day: day, size: cell)
                        .frame(width: cell, height: cell)
                        .position(x: x + cell / 2, y: y + cell / 2)
                }

                monthLabels(in: days, layout: layout, originX: originX, originY: originY, cell: cell, gap: gap)
                weekdayLabels(originX: originX, originY: originY, cell: cell, gap: gap)
            }
        }
        .clipped()
    }

    private func weekdayLabels(originX: CGFloat, originY: CGFloat, cell: CGFloat, gap: CGFloat) -> some View {
        ForEach(BigYearCalendar.weekdaySymbols.indices, id: \.self) { row in
            Text(BigYearCalendar.weekdaySymbols[row])
                .font(.system(size: 8, weight: .semibold, design: .default))
                .foregroundStyle(.black.opacity(0.38))
                .position(
                    x: originX - 18,
                    y: originY + CGFloat(row) * (cell + gap) + cell / 2
                )
        }
    }

    private func monthLabels(
        in days: [BigYearDay],
        layout: BigYearLayout,
        originX: CGFloat,
        originY: CGFloat,
        cell: CGFloat,
        gap: CGFloat
    ) -> some View {
        ForEach(days.filter(\.isFirstOfMonth), id: \.date) { day in
            let index = BigYearCalendar.index(for: day.date, in: year)
            let column = index / 7
            let x = originX + CGFloat(column) * (cell + gap)
            let y = originY - 12
            Text(day.monthShort.uppercased())
                .font(.system(size: 8, weight: .semibold, design: .default))
                .foregroundStyle(.black.opacity(0.5))
                .position(x: x + 2, y: y)
        }
    }
}

private struct BigYearDayCell: View {
    let day: BigYearDay
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(background)
            Rectangle()
                .stroke(border, lineWidth: 0.5)

            Text(day.label)
                .font(.system(size: max(7, size * 0.28), weight: .semibold, design: .default))
                .monospacedDigit()
                .foregroundStyle(foreground)
                .padding(2)
        }
        .overlay(alignment: .bottomLeading) {
            if day.eventCount > 0 {
                HStack(spacing: 1) {
                    ForEach(0..<min(3, day.eventCount), id: \.self) { _ in
                        Capsule()
                            .fill(Color(red: 0.22, green: 0.42, blue: 0.88))
                            .frame(width: max(2, size * 0.12), height: 3)
                    }
                }
                .padding(2)
            }
        }
    }

    private var background: Color {
        if day.isToday { return .black }
        if day.isWeekend { return Color.white }
        return day.inYear ? Color.white : Color.white.opacity(0.72)
    }

    private var border: Color {
        if day.isToday { return .black }
        return Color.black.opacity(day.inYear ? 0.06 : 0.03)
    }

    private var foreground: Color {
        if day.isToday { return .white }
        return day.inYear ? .black.opacity(0.88) : .black.opacity(0.22)
    }
}

private struct BigYearLayout {
    let columns: Int
    let rows: Int
    let cellSize: CGFloat

    static func compute(width: CGFloat, height: CGFloat, year: Int) -> BigYearLayout {
        let days = BigYearCalendar.days(in: year).count
        let columns = max(1, Int(ceil(Double(days) / 7.0)))
        let rows = 7
        let gap: CGFloat = 1
        let usableWidth = max(1, width - 20)
        let usableHeight = max(1, height - 52)
        let cellByWidth = floor((usableWidth - CGFloat(columns - 1) * gap) / CGFloat(columns))
        let cellByHeight = floor((usableHeight - CGFloat(rows - 1) * gap) / CGFloat(rows))
        let cell = max(10, min(cellByWidth, cellByHeight))
        return BigYearLayout(columns: columns, rows: rows, cellSize: cell)
    }
}

private struct BigYearDay {
    let date: Date
    let label: String
    let monthShort: String
    let inYear: Bool
    let isToday: Bool
    let isWeekend: Bool
    let isFirstOfMonth: Bool
    let eventCount: Int
}

private enum BigYearCalendar {
    static var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = AppLocalization.locale
        c.timeZone = .current
        return c
    }

    static var weekdaySymbols: [String] {
        cal.veryShortWeekdaySymbols.map { $0.uppercased(with: AppLocalization.locale) }
    }

    static func days(in year: Int) -> [BigYearDay] {
        let start = cal.date(from: DateComponents(year: year, month: 1, day: 1))!
        let end = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1))!
        let today = Date()
        var result: [BigYearDay] = []
        var date = start
        while date < end {
            let month = cal.component(.month, from: date)
            result.append(
                BigYearDay(
                    date: date,
                    label: "\(cal.component(.day, from: date))",
                    monthShort: cal.shortMonthSymbols[month - 1],
                    inYear: true,
                    isToday: cal.isDate(date, inSameDayAs: today),
                    isWeekend: cal.isDateInWeekend(date),
                    isFirstOfMonth: cal.component(.day, from: date) == 1,
                    eventCount: 0
                )
            )
            date = cal.date(byAdding: .day, value: 1, to: date)!
        }
        return result
    }

    static func index(for date: Date, in year: Int) -> Int {
        let start = cal.date(from: DateComponents(year: year, month: 1, day: 1))!
        return cal.dateComponents([.day], from: start, to: date).day ?? 0
    }
}
