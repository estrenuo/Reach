import Foundation

/// Where the mini player is (S-060), read from the query: the keyword, the
/// lists entered so far, and the text typed to filter the current list.
/// "music Albums › Kind of Blue — Miles Davis › so" is the songs of that album, filtered by "so".
public struct MiniPlayerPath: Equatable, Sendable {
    public static let separator = " › "
    public var keyword: String
    public var segments: [String]
    public var filter: String

    public init(keyword: String, segments: [String] = [], filter: String = "") {
        self.keyword = keyword
        self.segments = segments
        self.filter = filter
    }

    /// Nil unless the query is the keyword alone or the keyword and a space.
    public static func parse(_ query: String, keyword: String) -> MiniPlayerPath? {
        let word = keyword.trimmingCharacters(in: .whitespaces)
        guard !word.isEmpty else { return nil }
        let lower = query.lowercased()
        let start = word.lowercased() + " "
        if !lower.hasPrefix(start), lower.trimmingCharacters(in: .whitespaces) == word.lowercased() {
            return MiniPlayerPath(keyword: query.trimmingCharacters(in: .whitespaces))
        }
        guard lower.hasPrefix(start) else { return nil }
        let rest = String(query.dropFirst(word.count + 1))
        var parts = rest.components(separatedBy: separator)
        let filter = parts.removeLast()
        return MiniPlayerPath(keyword: String(query.prefix(word.count)), segments: parts, filter: filter)
    }

    /// The query for this path.
    public var query: String {
        keyword + " " + segments.map { $0 + Self.separator }.joined() + filter
    }

    /// The query inside `name`, with nothing typed.
    public func entering(_ name: String) -> String {
        MiniPlayerPath(keyword: keyword, segments: segments + [name]).query
    }

    /// ←: clears the typed text, else goes up one list. Nil at the top with nothing typed.
    public func back() -> String? {
        if !filter.isEmpty { return MiniPlayerPath(keyword: keyword, segments: segments).query }
        guard !segments.isEmpty else { return nil }
        return MiniPlayerPath(keyword: keyword, segments: Array(segments.dropLast())).query
    }
}

/// The mini player's lists.
public enum MiniPlayerList: Equatable, Sendable {
    public enum Top: String, CaseIterable, Sendable {
        case albums = "Albums", artists = "Artists", playlists = "Playlists"
    }

    case top
    case albums([MusicAlbum])
    case artists([MusicArtist])
    case playlists([MusicPlaylist])
    case songs([MusicSong], album: MusicAlbum?)
    /// A path that names nothing in the library (an album that went away).
    case missing

    /// The list a path's segments lead to.
    public static func at(_ segments: [String], in library: MusicCatalog) -> MiniPlayerList {
        guard let first = segments.first else { return .top }
        guard let top = Top.allCases.first(where: { $0.rawValue.lowercased() == first.lowercased() }) else { return .missing }
        let rest = Array(segments.dropFirst())
        switch top {
        case .albums:
            return albums(library.albums, rest)
        case .artists:
            let artists = library.artists
            guard let name = rest.first else { return .artists(artists) }
            guard let artist = artists.first(where: { $0.name == name }) else { return .missing }
            return albums(artist.albums, Array(rest.dropFirst()))
        case .playlists:
            let lists = library.playlists
            guard let name = rest.first else { return .playlists(lists) }
            guard rest.count == 1, let list = lists.first(where: { $0.name == name }) else { return .missing }
            return .songs(library.songs(in: list), album: nil)
        }
    }

    private static func albums(_ albums: [MusicAlbum], _ rest: [String]) -> MiniPlayerList {
        guard let name = rest.first else { return .albums(albums) }
        guard rest.count == 1, let album = albums.first(where: { $0.pathName == name }) else { return .missing }
        return .songs(album.songs, album: album)
    }
}
