import Foundation
import Testing
@testable import ReachKit

private var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

private func day(_ value: Int) -> Date { Date(timeIntervalSince1970: TimeInterval(value) * 86_400 + 3_600) }

@Test func countsAreStoredPerDayAndKind() throws {
    var log = UsageLog()
    log.record(.launcher, at: day(10), calendar: utc)
    log.record(.launcher, at: day(10).addingTimeInterval(7_200), calendar: utc)
    log.record(.clipboard, at: day(10), calendar: utc)
    log.record(.launcher, at: day(11), calendar: utc)
    #expect(log.count(.launcher, on: day(10), calendar: utc) == 2)
    #expect(log.count(.clipboard, on: day(10), calendar: utc) == 1)
    #expect(log.count(.launcher, on: day(11), calendar: utc) == 1)
    #expect(log.count(.expansion, on: day(11), calendar: utc) == 0)
    #expect(log.total == 4)

    // It survives a save and a load.
    let saved = try JSONEncoder().encode(log)
    #expect(try JSONDecoder().decode(UsageLog.self, from: saved) == log)
}

@Test func theChartHas28DaysOldestFirstWithQuietDays() {
    var log = UsageLog()
    log.record(.snippets, at: day(100), calendar: utc)
    log.record(.actions, at: day(80), calendar: utc)
    let chart = log.chart(ending: day(100), calendar: utc)
    #expect(chart.count == 28)
    #expect(chart.first?.date == utc.startOfDay(for: day(73)))
    #expect(chart.last?.counts == [.snippets: 1])
    #expect(chart.map(\.total).reduce(0, +) == 2)
}

@Test func theAverageCountsEveryDaySinceTheFirstUse() {
    var log = UsageLog()
    #expect(log.averagePerDay(at: day(5), calendar: utc) == 0)
    for _ in 0..<10 { log.record(.launcher, at: day(1), calendar: utc) }
    #expect(log.averagePerDay(at: day(1), calendar: utc) == 10)
    #expect(log.averagePerDay(at: day(5), calendar: utc) == 2)
}

@Test func oldDaysAreDropped() {
    var log = UsageLog()
    for index in 0...(UsageLog.keptDays) { log.record(.launcher, at: day(index), calendar: utc) }
    #expect(log.days.count == UsageLog.keptDays)
    #expect(log.count(.launcher, on: day(0), calendar: utc) == 0)
}
