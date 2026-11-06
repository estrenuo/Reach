import Foundation
import Testing
@testable import ReachKit

private let standard = MusicKeyword.defaults

private func asks(_ query: String, in keywords: [MusicKeyword] = standard, defaultResults: Bool = false) -> [MusicKeywords.Ask] {
    MusicKeywords.matches(query, in: keywords, defaultResults: defaultResults).map(\.ask)
}

@Test("Each keyword maps to one Music command")
func musicKeywordsMapToCommands() {
    for command in MusicCommand.allCases where !command.takesVolume {
        #expect(asks(command.defaultKeyword) == [.run(.command(command))], "\(command)")
    }
    #expect(Set(MusicCommand.allCases.map(\.defaultKeyword)).count == MusicCommand.allCases.count)
    #expect(asks("NEXT") == [.run(.command(.next))])
    #expect(asks(" next ") == [.run(.command(.next))])
    #expect(asks("").isEmpty)
}

@Test("volume takes 0 to 100, with or without %")
func musicVolume() {
    #expect(asks("volume 50") == [.run(.setVolume(50))])
    #expect(asks("volume 0") == [.run(.setVolume(0))])
    #expect(asks("volume 100%") == [.run(.setVolume(100))])
    #expect(asks("volume  7 ") == [.run(.setVolume(7))])
    #expect(asks("volume") == [.needsVolume])
    #expect(asks("volume 101") == [.badVolume])
    #expect(asks("volume -1") == [.badVolume])
    #expect(asks("volume loud") == [.badVolume])
    #expect(asks("volume 5.5") == [.badVolume])
    #expect(MusicKeywords.volume(in: "42") == 42)
    #expect(MusicKeywords.volume(in: "") == nil)
}

@Test("A keyword turned off finds nothing; a renamed keyword finds its command")
func musicKeywordOffAndRenamed() {
    var keywords = standard
    keywords[1].isOn = false
    #expect(asks("next", in: keywords).isEmpty)
    keywords[1] = MusicKeyword(command: .next, keyword: "skip")
    #expect(asks("skip", in: keywords) == [.run(.command(.next))])
    #expect(asks("next", in: keywords).isEmpty)
    keywords[8] = MusicKeyword(command: .volume, keyword: "vol")
    #expect(asks("vol 30", in: keywords) == [.run(.setVolume(30))])
    #expect(asks("volume 30", in: keywords).isEmpty)
}

@Test("With Show in default results, part of a keyword or title finds the command")
func musicDefaultResults() {
    #expect(asks("nex").isEmpty)
    let found = MusicKeywords.matches("nex", in: standard, defaultResults: true)
    #expect(found.first?.command == .next)
    #expect(MusicKeywords.matches("random song", in: standard, defaultResults: true).first?.command == .random)
    #expect(MusicKeywords.matches("vol", in: standard, defaultResults: true).contains { $0.command == .volume && $0.ask == .needsVolume })
    #expect(MusicKeywords.matches("zzqxv", in: standard, defaultResults: true).isEmpty)
    // The exact keyword comes before a partial match of another command.
    #expect(MusicKeywords.matches("back", in: standard, defaultResults: true).first?.command == .back)
}

@Test("Each request becomes one AppleScript line for Music")
func musicScripts() {
    #expect(MusicRequest.command(.next).script == "tell application \"Music\" to next track")
    #expect(MusicRequest.command(.playPause).script == "tell application \"Music\" to playpause")
    #expect(MusicRequest.command(.mute).script == "tell application \"Music\" to set mute to not mute")
    #expect(MusicRequest.setVolume(30).script == "tell application \"Music\" to set sound volume to 30")
    #expect(MusicRequest.setVolume(300).script.hasSuffix("to 100"))
    let scripts = Set(MusicCommand.allCases.filter { !$0.takesVolume }.map { MusicRequest.command($0).script })
    #expect(scripts.count == MusicCommand.allCases.count - 1)
}

@Test("A keyword must be one word that nothing else uses")
func musicKeywordProblems() {
    #expect(MusicKeywords.problem(keyword: "skip", for: .next, in: standard) == nil)
    #expect(MusicKeywords.problem(keyword: "next", for: .next, in: standard) == nil)
    #expect(MusicKeywords.problem(keyword: "", for: .next, in: standard) == "Type a keyword.")
    #expect(MusicKeywords.problem(keyword: "go on", for: .next, in: standard) == "A keyword is one word, without spaces.")
    #expect(MusicKeywords.problem(keyword: "Play", for: .next, in: standard) == "“Play” is already the keyword for Play or Pause.")
    #expect(MusicKeywords.problem(keyword: "define", for: .next, in: standard, taken: ["define": "Define a Word"])
            == "“define” is already the keyword for Define a Word.")
}

@Test("Saved keywords get any missing command back, in order")
func musicKeywordsComplete() {
    let saved = [MusicKeyword(command: .mute, keyword: "shh", isOn: false)]
    let full = MusicKeyword.complete(saved)
    #expect(full.map(\.command) == MusicCommand.allCases)
    #expect(full.first { $0.command == .mute } == saved[0])
}

@Test("The track subtitle is song and artist")
func musicTrackSubtitle() {
    #expect(MusicTrack(name: "So What", artist: "Miles Davis").subtitle == "So What — Miles Davis")
    #expect(MusicTrack(name: "So What", artist: "").subtitle == "So What")
}
