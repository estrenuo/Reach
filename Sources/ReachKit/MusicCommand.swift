import Foundation

/// A music command (S-059): a keyword that tells Music.app what to do, in
/// the order of Alfred's Music > Keywords page.
public enum MusicCommand: String, CaseIterable, Codable, Sendable {
    case playPause, next, back, previous, random, volumeMax, volumeMid, mute, volume

    public var title: String {
        switch self {
        case .playPause: "Play or Pause"
        case .next: "Next Track"
        case .back: "Back to Start"
        case .previous: "Previous Track"
        case .random: "Play a Random Song"
        case .volumeMax: "Maximum Volume"
        case .volumeMid: "Half Volume"
        case .mute: "Mute or Unmute"
        case .volume: "Set Volume"
        }
    }

    public var defaultKeyword: String {
        switch self {
        case .playPause: "play"
        case .next: "next"
        case .back: "back"
        case .previous: "previous"
        case .random: "random"
        case .volumeMax: "volmax"
        case .volumeMid: "volmid"
        case .mute: "mute"
        case .volume: "volume"
        }
    }

    public var symbol: String {
        switch self {
        case .playPause: "playpause"
        case .next: "forward.end"
        case .back: "backward.end"
        case .previous: "backward"
        case .random: "shuffle"
        case .volumeMax: "speaker.wave.3"
        case .volumeMid: "speaker.wave.1"
        case .mute: "speaker.slash"
        case .volume: "speaker.wave.2"
        }
    }

    /// The subtitle when no track is playing: what the command does.
    public var help: String {
        switch self {
        case .playPause: "Play or pause Music"
        case .next: "Skip to the next song"
        case .back: "Start the playing song again"
        case .previous: "Go to the song before"
        case .random: "Play a random song from your library"
        case .volumeMax: "Set Music's volume to 100"
        case .volumeMid: "Set Music's volume to 50"
        case .mute: "Mute or unmute Music"
        case .volume: "Type a volume from 0 to 100"
        }
    }

    /// The commands whose subtitle shows the playing track.
    public var showsTrack: Bool { [.playPause, .next, .back, .previous].contains(self) }

    /// `volume` takes a number after the keyword.
    public var takesVolume: Bool { self == .volume }
}

/// One row of Settings > Music > Keywords: a command, its keyword, on or off.
public struct MusicKeyword: Codable, Equatable, Sendable, Identifiable {
    public var command: MusicCommand
    public var keyword: String
    public var isOn: Bool

    public var id: MusicCommand { command }

    public init(command: MusicCommand, keyword: String? = nil, isOn: Bool = true) {
        self.command = command
        self.keyword = keyword ?? command.defaultKeyword
        self.isOn = isOn
    }

    public static var defaults: [MusicKeyword] { MusicCommand.allCases.map { MusicKeyword(command: $0) } }

    /// Saved keywords with any command missing from them added at its default,
    /// in the commands' order, so an old or hand-edited value never loses a row.
    public static func complete(_ saved: [MusicKeyword]) -> [MusicKeyword] {
        MusicCommand.allCases.map { command in saved.first { $0.command == command } ?? MusicKeyword(command: command) }
    }
}

/// What ↩ sends to Music.
public enum MusicRequest: Equatable, Sendable {
    case command(MusicCommand)
    case setVolume(Int)

    /// The AppleScript that does it. `tell application "Music"` starts Music when it is not running.
    public var script: String {
        let body: String = switch self {
        case .command(.playPause): "playpause"
        case .command(.next): "next track"
        case .command(.back): "back track"
        case .command(.previous): "previous track"
        case .command(.random): "play some track of library playlist 1"
        case .command(.volumeMax): "set sound volume to 100"
        case .command(.volumeMid): "set sound volume to 50"
        case .command(.mute): "set mute to not mute"
        case .command(.volume): "set sound volume to 50"
        case .setVolume(let level): "set sound volume to \(MusicKeywords.volumeRange.clamp(level))"
        }
        return "tell application \"Music\" to \(body)"
    }
}

/// The playing song, for the subtitle of Next Track and the others.
public struct MusicTrack: Equatable, Sendable {
    public var name: String
    public var artist: String

    public init(name: String, artist: String) {
        self.name = name
        self.artist = artist
    }

    /// "Song — Artist", or the song alone.
    public var subtitle: String {
        artist.isEmpty ? name : "\(name) — \(artist)"
    }
}

public enum MusicKeywords {
    public static let volumeRange = 0...100

    /// What a query asks of one command.
    public enum Ask: Equatable, Sendable {
        /// The command itself; ↩ sends it.
        case run(MusicRequest)
        /// `volume` alone: a hint asking for a number.
        case needsVolume
        /// `volume 150`: a hint with the range.
        case badVolume
    }

    public struct Match: Equatable, Sendable {
        public let command: MusicCommand
        public let ask: Ask
        public let score: Int
    }

    /// The commands a query asks for, best first. The exact keyword (and
    /// `volume <n>`) always counts; with `defaultResults` on, part of a keyword
    /// or title does too, scored on the `Matcher` scale.
    public static func matches(_ query: String, in keywords: [MusicKeyword], defaultResults: Bool,
                               minimumScore: Int = SystemCommands.minimumScore) -> [Match] {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return [] }
        let lower = text.lowercased()
        return keywords.compactMap { setting -> Match? in
            let keyword = setting.keyword.trimmingCharacters(in: .whitespaces).lowercased()
            guard setting.isOn, !keyword.isEmpty else { return nil }
            if setting.command.takesVolume {
                if lower == keyword { return Match(command: .volume, ask: .needsVolume, score: 2000) }
                if lower.hasPrefix(keyword + " ") {
                    let rest = String(text.dropFirst(keyword.count + 1))
                    guard let level = volume(in: rest) else { return Match(command: .volume, ask: .badVolume, score: 2000) }
                    return Match(command: .volume, ask: .run(.setVolume(level)), score: 2000)
                }
            } else if lower == keyword {
                return Match(command: setting.command, ask: .run(.command(setting.command)), score: 2000)
            }
            guard defaultResults else { return nil }
            let score = [Matcher.score(query: text, title: keyword),
                         Matcher.score(query: text, title: setting.command.title)].compactMap { $0 }.max()
            guard let score, score >= minimumScore else { return nil }
            let ask: Ask = setting.command.takesVolume ? .needsVolume : .run(.command(setting.command))
            return Match(command: setting.command, ask: ask, score: score)
        }
        .sorted { $0.score > $1.score }
    }

    /// A whole number from 0 to 100, with or without a trailing %; nil otherwise.
    public static func volume(in text: String) -> Int? {
        var word = text.trimmingCharacters(in: .whitespaces)
        if word.hasSuffix("%") { word.removeLast() }
        guard let level = Int(word), volumeRange.contains(level) else { return nil }
        return level
    }

    /// Why `keyword` will not do for `command`, or nil when it will: two music
    /// commands, or a music command and another feature, cannot share a keyword.
    public static func problem(keyword: String, for command: MusicCommand, in keywords: [MusicKeyword],
                               taken: [String: String] = [:]) -> String? {
        let word = keyword.trimmingCharacters(in: .whitespaces).lowercased()
        if word.isEmpty { return "Type a keyword." }
        if word.contains(where: \.isWhitespace) { return "A keyword is one word, without spaces." }
        if let other = keywords.first(where: { $0.command != command && $0.keyword.lowercased() == word }) {
            return "“\(keyword)” is already the keyword for \(other.command.title)."
        }
        if let other = taken[word] { return "“\(keyword)” is already the keyword for \(other)." }
        return nil
    }
}

extension ClosedRange where Bound == Int {
    func clamp(_ value: Int) -> Int { Swift.min(Swift.max(value, lowerBound), upperBound) }
}
