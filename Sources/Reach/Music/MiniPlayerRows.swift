import AppKit
import ReachKit

/// The mini player's rows (S-060), built from the query's path and the
/// library: the top list, albums, artists, playlists and songs. The list keeps
/// its own order (A to Z, or best match while typing), like browsing a folder.
@MainActor
final class MiniPlayerRows {
    /// More rows than this would make every keystroke slow; typing narrows them.
    static let limit = 300
    let path: MiniPlayerPath
    let library: MusicCatalog
    let settings: MusicSettings
    let artwork: (String) -> String?
    /// Where → goes from a row, by result id.
    private(set) var enters: [String: String] = [:]

    init(path: MiniPlayerPath, library: MusicCatalog, settings: MusicSettings, artwork: @escaping (String) -> String?) {
        self.path = path
        self.library = library
        self.settings = settings
        self.artwork = artwork
    }

    func rows() -> [LaunchResult] {
        switch MiniPlayerList.at(path.segments, in: library) {
        case .top: return filtered(top(), noun: "lists")
        case .albums(let albums): return filtered(albums.map(albumRow), noun: "albums")
        case .artists(let artists): return filtered(artists.map(artistRow), noun: "artists")
        case .playlists(let lists): return filtered(lists.map(playlistRow), noun: "playlists")
        case .songs(let songs, let album): return filtered(songs.map { songRow($0, album: album) }, noun: "songs")
        case .missing: return [Self.hint("Not in your music library any more")]
        }
    }

    private func top() -> [LaunchResult] {
        let albums = library.albums
        var rows = MiniPlayerList.Top.allCases.map { top -> LaunchResult in
            let count: String = switch top {
            case .albums: Self.count(albums.count, "album")
            case .artists: Self.count(library.artists.count, "artist")
            case .playlists: Self.count(library.playlists.count, "playlist")
            }
            let symbol = switch top {
            case .albums: "square.stack"
            case .artists: "music.mic"
            case .playlists: "music.note.list"
            }
            var row = LaunchResult(id: "mini:\(top.rawValue)", title: top.rawValue, subtitle: count, icon: .symbol(symbol), url: nil,
                                   kindLabel: "List")
            row.completes = path.entering(top.rawValue)
            enters[row.id] = row.completes
            return row
        }
        let minimum = settings.randomMinimum
        var random = LaunchResult(id: "mini:random", title: "Random Album",
                                  subtitle: "Play an album with at least \(Self.count(minimum, "song"))",
                                  icon: .symbol("shuffle"), url: nil, kindLabel: "Mini player")
        var generator = SystemRandomNumberGenerator()
        if let album = library.randomAlbum(minimumSongs: minimum, using: &generator) {
            random.music = .playSongs(album.songs.map(\.id))
        } else {
            random.subtitle = "No album has \(Self.count(minimum, "song")) or more"
        }
        rows.append(random)
        rows.append(LaunchResult(id: "mini:open", title: "Open Music", subtitle: "Open the Music app",
                                 icon: MusicSource.icon, url: URL(fileURLWithPath: MusicPlayer.app), kindLabel: "App"))
        return rows
    }

    private func albumRow(_ album: MusicAlbum) -> LaunchResult {
        var row = LaunchResult(id: "mini:album:\(album.id)", title: album.title,
                               subtitle: [album.artist, Self.count(album.songs.count, "song")].filter { !$0.isEmpty }.joined(separator: " · "),
                               icon: artwork(album.id).map(LaunchResult.Icon.image) ?? MusicSource.icon, url: nil, kindLabel: "Album")
        row.music = .playSongs(album.songs.map(\.id))
        enters[row.id] = path.entering(album.pathName)
        return row
    }

    private func artistRow(_ artist: MusicArtist) -> LaunchResult {
        var row = LaunchResult(id: "mini:artist:\(artist.name)", title: artist.name,
                               subtitle: Self.count(artist.albums.count, "album"),
                               icon: .symbol("music.mic"), url: nil, kindLabel: "Artist")
        row.music = .playSongs(artist.songs.map(\.id))
        enters[row.id] = path.entering(artist.name)
        return row
    }

    private func playlistRow(_ list: MusicPlaylist) -> LaunchResult {
        var row = LaunchResult(id: "mini:playlist:\(list.id)", title: list.name, subtitle: Self.count(list.songIDs.count, "song"),
                               icon: .symbol("music.note.list"), url: nil, kindLabel: "Playlist")
        row.music = .playPlaylist(list.id)
        enters[row.id] = path.entering(list.name)
        return row
    }

    private func songRow(_ song: MusicSong, album: MusicAlbum?) -> LaunchResult {
        let icon = song.albumID.isEmpty ? nil : artwork(song.albumID)
        var row = LaunchResult(id: "mini:song:\(song.id)", title: song.title,
                               subtitle: [song.artist, album == nil ? song.album : ""].filter { !$0.isEmpty }.joined(separator: " — "),
                               icon: icon.map(LaunchResult.Icon.image) ?? MusicSource.icon, url: nil, kindLabel: "Song")
        if album != nil, song.number > 0 { row.badge = "\(song.number)" }
        row.music = .playSong(song.id)
        return row
    }

    /// A to Z without text; with text, the rows that match, best first.
    private func filtered(_ rows: [LaunchResult], noun: String) -> [LaunchResult] {
        let text = path.filter.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            return rows.isEmpty ? [Self.hint("No \(noun) in your music library")] : Array(rows.prefix(Self.limit))
        }
        let matched = rows.enumerated().compactMap { offset, row -> (Int, Int, LaunchResult)? in
            let score = [Matcher.score(query: text, title: row.title), Matcher.score(query: text, title: row.subtitle).map { $0 / 2 }]
                .compactMap { $0 }.max()
            return score.map { (offset, $0, row) }
        }
        .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
        guard !matched.isEmpty else { return [Self.hint("No \(noun) match “\(text)”")] }
        return matched.prefix(Self.limit).map(\.2)
    }

    static func hint(_ title: String) -> LaunchResult {
        LaunchResult(id: "mini:hint", title: title, subtitle: "", icon: MusicSource.icon, url: nil)
    }

    static func count(_ number: Int, _ noun: String) -> String {
        "\(number) \(noun)\(number == 1 ? "" : "s")"
    }
}
