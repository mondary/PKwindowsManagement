import Foundation

let text = "28.12.2026-03.01.2027,Fêtes\n08.02-15.02,Ski"
let events2026 = BigYearData.eventCoverage(from: text, in: 2026)
let events2027 = BigYearData.eventCoverage(from: text, in: 2027)

precondition(events2026["2026-12-28"] == ["Fêtes"])
precondition(events2027["2027-01-03"] == ["Fêtes"])
precondition(events2026["2026-01-03"] == nil)
precondition(events2026["2026-02-10"] == ["Ski"])
precondition(events2027["2027-02-10"] == ["Ski"])
