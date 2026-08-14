import SwiftUI

struct BigYearSettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var vacations: [String: Set<String>] = [:]
    @State private var systemEvents: [String: [String]] = [:]

    private var year: Int { Calendar.current.component(.year, from: Date()) }

    var body: some View {
        GeometryReader { _ in
            VStack(alignment: .leading, spacing: 18) {
                Text("Big Year")
                    .font(.title3.weight(.semibold))

                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 18) {
                        themeSection
                            .frame(maxWidth: 320)
                        appearanceSection
                            .frame(maxWidth: 320)
                    }
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
        .task(id: settings.bigYearSystemCalendarEnabled) {
            systemEvents = settings.bigYearSystemCalendarEnabled
                ? await SystemCalendarService.allDayEvents(in: year)
                : [:]
        }
    }

    private var preview: some View {
        let colors = settings.bigYearColors
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
                    events: systemEvents.merging(BigYearData.eventCoverage(from: settings.bigYearEvents, in: year)) { $0 + $1 },
                    selectedZone: settings.bigYearSchoolZone,
                    colors: colors,
                    posterMode: settings.bigYearTheme == .poster,
                    emphasizeBirthdays: settings.bigYearEmphasizeBirthdays,
                    emphasizeMonthNames: settings.bigYearEmphasizeMonthNames
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

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Apparence").font(.subheadline.weight(.medium))
            BigYearAppearanceSection(settings: settings, colors: settings.bigYearColors)
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

            Toggle("Calendriers macOS / Google", isOn: $settings.bigYearSystemCalendarEnabled)
            Text("Importe les événements journée entière des comptes configurés dans Calendrier macOS.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Anniversaires").font(.subheadline.weight(.medium))
            BirthdayEditor(text: $settings.bigYearBirthdays)
                .frame(minHeight: 140)
            Text("Un par ligne : 11.02,!Clément ou 0112,Marie")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            Text("Événements").font(.subheadline.weight(.medium))
            BirthdayEditor(text: $settings.bigYearEvents)
                .frame(minHeight: 140)
            Text("Jour ou plage : 08.02-15.02.2026,Ski · 03.11,Déplacement · ! pour gras")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}
