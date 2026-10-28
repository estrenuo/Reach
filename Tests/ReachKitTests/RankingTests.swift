import Foundation
import Testing
@testable import ReachKit

@Test("Without Learning, the text score decides")
func plainOrder() {
    let order = Ranking.order([(id: "Visual Studio Code", score: 682), (id: "Console", score: 898)], learned: [:])
    #expect(order == ["Console", "Visual Studio Code"])
}

@Test("After two picks a result ranks above a better text match (S-004)")
func learnedOrder() {
    let now = Date.now
    let learned = ["Visual Studio Code": LearnedPick(count: 2, lastUsed: now)]
    // "co": Console starts with the query, Visual Studio Code only has a word that does.
    let order = Ranking.order([(id: "Console", score: 898), (id: "Visual Studio Code", score: 682)],
                              learned: learned, now: now)
    #expect(order.first == "Visual Studio Code")
}

@Test("A never-picked result gets no boost")
func noBoost() {
    #expect(Ranking.learningBoost(nil, now: .now) == 0)
}

@Test("The boost halves every 30 days and stops growing after five picks")
func decay() {
    let now = Date.now
    let fresh = Ranking.learningBoost(LearnedPick(count: 2, lastUsed: now), now: now)
    let month = Ranking.learningBoost(LearnedPick(count: 2, lastUsed: now.addingTimeInterval(-30 * 86_400)), now: now)
    #expect(fresh == 300)
    #expect(month == 150)
    #expect(Ranking.learningBoost(LearnedPick(count: 50, lastUsed: now), now: now) == 750)
}

@Test("An exact title still beats a heavily learned weak match")
func exactWins() {
    let now = Date.now
    let learned = ["Facetime Recorder": LearnedPick(count: 50, lastUsed: now)]
    let order = Ranking.order([(id: "Facetime Recorder", score: 200), (id: "Code", score: 1000)],
                              learned: learned, now: now)
    #expect(order.first == "Code")
}
