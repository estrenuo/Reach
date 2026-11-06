import Foundation

/// What a song in the Music library is (S-060).
public enum MusicMediaKind: String, Sendable, Codable {
    case song, podcast, video
}

/// One song from the Music library, as plain values: the app reads it with
/// iTunesLibrary, the self-test and snapshots make their own.
public struct MusicSong: Equatable, Sendable, Identifiable {
    /// Music's persistent ID, 16 hex digits, as AppleScript knows it.
    public var id: String
    public var title: String
    public var artist: String
    public var album: String
    public var albumArtist: String
    /// Groups the songs of one album; empty for a song without an album.
    public var albumID: String
    public var disc: Int
    public var number: Int
    public var kind: MusicMediaKind

    public init(id: String, title: String, artist: String = "", album: String = "", albumArtist: String = "",
                albumID: String = "", disc: Int = 1, number: Int = 0, kind: MusicMediaKind = .song) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.albumID = albumID
        self.disc = disc
        self.number = number
        self.kind = kind
    }

    /// Without an album or an artist: Alfred calls these untagged.
    public var isUntagged: Bool { album.isEmpty || (artist.isEmpty && albumArtist.isEmpty) }
    /// The album artist, else the artist.
    public var albumArtistName: String { albumArtist.isEmpty ? artist : albumArtist }
}

public struct MusicPlaylist: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var songIDs: [String]

    public init(id: String, name: String, songIDs: [String]) {
        self.id = id
        self.name = name
        self.songIDs = songIDs
    }
}

public struct MusicAlbum: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var artist: String
    /// In disc and track order.
    public var songs: [MusicSong]

    /// The name in the mini player's path: "Kind of Blue — Miles Davis".
    public var pathName: String { artist.isEmpty ? title : "\(title) — \(artist)" }
}

public struct MusicArtist: Equatable, Sendable, Identifiable {
    public var name: String
    /// A to Z.
    public var albums: [MusicAlbum]

    public var id: String { name }
    /// Every song, album by album.
    public var songs: [MusicSong] { albums.flatMap(\.songs) }
}

/// The Music library as the mini player shows it (S-060).
public struct MusicLibrary: Equatable, Sendable {
    public var songs: [MusicSong]
    public var playlists: [MusicPlaylist]

    public init(songs: [MusicSong] = [], playlists: [MusicPlaylist] = []) {
        self.songs = songs
        self.playlists = playlists
    }

    /// Which songs count, from Settings > Music > General.
    public struct Include: Equatable, Sendable {
        public var podcasts = false
        public var videos = false
        public var untagged = false

        public init(podcasts: Bool = false, videos: Bool = false, untagged: Bool = false) {
            self.podcasts = podcasts
            self.videos = videos
            self.untagged = untagged
        }
    }

    /// The library with only the songs `include` lets in; playlists keep only
    /// those songs, and an empty playlist goes.
    public func including(_ include: Include) -> MusicLibrary {
        let kept = songs.filter { song in
            switch song.kind {
            case .podcast where !include.podcasts: return false
            case .video where !include.videos: return false
            default: return include.untagged || !song.isUntagged
            }
        }
        let ids = Set(kept.map(\.id))
        let lists = playlists.map { MusicPlaylist(id: $0.id, name: $0.name, songIDs: $0.songIDs.filter(ids.contains)) }
            .filter { !$0.songIDs.isEmpty }
        return MusicLibrary(songs: kept, playlists: lists)
    }

    /// Songs with an album, grouped, A to Z by title.
    public var albums: [MusicAlbum] {
        let grouped = Dictionary(grouping: songs.filter { !$0.album.isEmpty }) { $0.albumID.isEmpty ? "\($0.album)\t\($0.albumArtistName)" : $0.albumID }
        return grouped.map { id, songs in
            let ordered = songs.sorted { ($0.disc, $0.number, $0.title) < ($1.disc, $1.number, $1.title) }
            return MusicAlbum(id: id, title: ordered[0].album, artist: Self.artist(of: ordered), songs: ordered)
        }
        .sorted { Self.order($0.title, $0.artist, $1.title, $1.artist) }
    }

    /// Playlists A to Z.
    public var sortedPlaylists: [MusicPlaylist] {
        playlists.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// One artist for an album; "Various Artists" when its songs disagree and none sets an album artist.
    static func artist(of songs: [MusicSong]) -> String {
        let names = Set(songs.map(\.albumArtistName).filter { !$0.isEmpty })
        if names.count <= 1 { return names.first ?? "" }
        return "Various Artists"
    }

    static func order(_ title: String, _ artist: String, _ otherTitle: String, _ otherArtist: String) -> Bool {
        switch title.localizedStandardCompare(otherTitle) {
        case .orderedAscending: true
        case .orderedDescending: false
        case .orderedSame: artist.localizedStandardCompare(otherArtist) == .orderedAscending
        }
    }

    /// Music's persistent ID as AppleScript writes it: 16 uppercase hex digits.
    public static func persistentID(_ number: UInt64) -> String {
        let hex = String(number, radix: 16, uppercase: true)
        return String(repeating: "0", count: max(0, 16 - hex.count)) + hex
    }
}

/// The library sorted and grouped once for the mini player, so typing never
/// groups thousands of songs again. Built for one set of include settings.
public struct MusicCatalog: Equatable, Sendable {
    public let albums: [MusicAlbum]
    public let artists: [MusicArtist]
    public let playlists: [MusicPlaylist]
    private let songsByID: [String: MusicSong]

    public init(_ library: MusicLibrary) {
        albums = library.albums
        artists = Dictionary(grouping: albums.filter { !$0.artist.isEmpty }, by: \.artist)
            .map { MusicArtist(name: $0.key, albums: $0.value) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        playlists = library.sortedPlaylists
        songsByID = Dictionary(library.songs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public func songs(in playlist: MusicPlaylist) -> [MusicSong] {
        playlist.songIDs.compactMap { songsByID[$0] }
    }

    /// An album with at least `minimumSongs` songs, picked with `generator`; nil when none has that many.
    public func randomAlbum(minimumSongs: Int, using generator: inout some RandomNumberGenerator) -> MusicAlbum? {
        albums.filter { $0.songs.count >= minimumSongs }.randomElement(using: &generator)
    }
}
