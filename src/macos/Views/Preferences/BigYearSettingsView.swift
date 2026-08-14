import SwiftUI

struct BigYearSettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var vacations: [String: Set<String>] = [:]

    private var year: Int { Calendar.current.component(.year, from: Date()) }

    var body: some View {
        GeometryReader { _ in
            VStack(alignment: .leading, spacing: 18) {
                Text("Big Year")
                    .font(.title3.weight(.semibold))

                HStack(alignment: .top, spacing: 18) {
                    themeSection
                        .frame(maxWidth: 320)
                    calendarSection
                        .frame(maxWidth: .infinity)
                }

                preview
                    .frame(maxHeight: .infinity)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .task {
            vacations = await BigYearData.schoolVacations(in: year)
        }
    }

    private var preview: some View {
        let colors = settings.bigYearTheme.colors
        return VStack(spacing: 0) {
            ZStack {
                HStack {
                    Image(systemName: "line.3.horizontal")
                    Spacer()
                    Image(systemName: "xmark")
                }
                Text("\(year)")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .foregroundStyle(colors.text)
            .background(colors.page)

            GeometryReader { proxy in
                BigYearGrid(
                    year: year,
                    size: proxy.size,
                    holidays: BigYearData.frenchHolidays(in: year),
                    vacations: vacations,
                    birthdays: BigYearData.birthdays(from: settings.bigYearBirthdays),
                    selectedZone: settings.bigYearSchoolZone,
                    colors: colors
                )
            }
        }
        .frame(minHeight: 220, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(colors.border))
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Thème").font(.subheadline.weight(.medium))
            ForEach(BigYearTheme.allCases) { theme in
                Button { settings.bigYearTheme = theme } label: {
                    HStack(spacing: 8) {
                        Text(theme.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(Array(theme.colors.swatches.enumerated()), id: \.offset) { _, color in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(color)
                                .frame(width: 13, height: 13)
                                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.primary.opacity(0.12)))
                        }
                        Image(systemName: settings.bigYearTheme == theme ? "checkmark.circle.fill" : "circle")
                    }
                    .font(.system(size: 12, weight: settings.bigYearTheme == theme ? .semibold : .regular))
                    .foregroundStyle(theme.colors.text)
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(theme.colors.page, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(theme.colors.border))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Vacances scolaires").font(.subheadline.weight(.medium))
            Picker("Zone", selection: $settings.bigYearSchoolZone) {
                Text("Zone A").tag("A")
                Text("Zone B").tag("B")
                Text("Zone C").tag("C")
            }
            .pickerStyle(.segmented)

            Text("Anniversaires").font(.subheadline.weight(.medium))
            BirthdayEditor(text: $settings.bigYearBirthdays)
                .frame(minHeight: 220)
            Text("Un par ligne : 11.02,!Clément ou 0112,Marie")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}
