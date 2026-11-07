import Foundation
import Testing
@testable import ReachKit

/// A small library: two albums by one artist, a compilation, a podcast,
/// a video, an untagged song and a playlist.
let sampleLibrary = MusicLibrary(
    songs: [
        MusicSong(id: "A2", title: "Freddie Freeloader", artist: "Miles Davis", album: "Kind of Blue", albumID: "KOB", number: 2),
        MusicSong(id: "A1", title: "So What", artist: "Miles Davis", album: "Kind of Blue", albumID: "KOB", number: 1),
        MusicSong(id: "A3", title: "Blue in Green", artist: "Miles Davis", album: "Kind of Blue", albumID: "KOB", number: 3),
        MusicSong(id: "B1", title: "Bitches Brew", artist: "Miles Davis", album: "Bitches Brew", albumID: "BB", number: 1),
        MusicSong(id: "C1", title: "Take Five", artist: "Dave Brubeck", album: "Jazz Hits", albumID: "JH", number: 1),
        MusicSong(id: "C2", title: "Round Midnight", artist: "Thelonious Monk", album: "Jazz Hits", albumID: "JH", number: 2),
        MusicSong(id: "P1", title: "Episode 12", artist: "Radio", album: "The Show", albumID: "SHOW", kind: .podcast),
        MusicSong(id: "V1", title: "Live at Montreux", artist: "Miles Davis", album: "Montreux", albumID: "MX", kind: .video),
        MusicSong(id: "U1", title: "Voice Memo", artist: "", album: ""),
    ],
    playlists: [MusicPlaylist(id: "L1", name: "Evening", songIDs: ["A3", "U1", "C1"]),
                MusicPlaylist(id: "L2", name: "Talk", songIDs: ["P1"])])

@Test("Podcasts, videos and untagged songs only come in when their settings are on")
func musicLibraryIncludes() {
    let plain = sampleLibrary.including(.init())
    #expect(Set(plain.songs.map(\.id)) == ["A1", "A2", "A3", "B1", "C1", "C2"])
    #expect(plain.playlists.map(\.name) == ["Evening"])
    #expect(plain.playlists[0].songIDs == ["A3", "C1"])
    let all = sampleLibrary.including(.init(podcasts: true, videos: true, untagged: true))
    #expect(all.songs.count == sampleLibrary.songs.count)
    #expect(all.playlists.count == 2)
}

@Test("Albums group by album, A to Z, songs in track order; a mixed album is Various Artists")
func musicLibraryAlbums() {
    let albums = sampleLibrary.including(.init()).albums
    #expect(albums.map(\.title) == ["Bitches Brew", "Jazz Hits", "Kind of Blue"])
    #expect(albums[2].songs.map(\.title) == ["So What", "Freddie Freeloader", "Blue in Green"])
    #expect(albums[1].artist == "Various Artists")
    #expect(albums[2].pathName == "Kind of Blue — Miles Davis")
}

@Test("Artists list their albums A to Z")
func musicLibraryArtists() {
    let artists = MusicCatalog(sampleLibrary.including(.init())).artists
    #expect(artists.map(\.name) == ["Miles Davis", "Various Artists"])
    #expect(artists[0].albums.map(\.title) == ["Bitches Brew", "Kind of Blue"])
    #expect(artists[0].songs.count == 4)
}

@Test("Random Album skips albums with fewer songs than the setting")
func musicRandomAlbum() {
    let library = MusicCatalog(sampleLibrary.including(.init()))
    var generator = SystemRandomNumberGenerator()
    for _ in 0..<50 {
        #expect(library.randomAlbum(minimumSongs: 2, using: &generator)?.songs.count ?? 0 >= 2)
        #expect(library.randomAlbum(minimumSongs: 3, using: &generator)?.title == "Kind of Blue")
    }
    #expect(library.randomAlbum(minimumSongs: 4, using: &generator) == nil)
}

@Test("Persistent IDs are 16 uppercase hex digits")
func musicPersistentID() {
    #expect(MusicLibrary.persistentID(0xABC) == "0000000000000ABC")
    #expect(MusicLibrary.persistentID(UInt64.max) == "FFFFFFFFFFFFFFFF")
}

@Test("The query holds the mini player's path and the typed filter")
func miniPlayerPathParse() {
    #expect(MiniPlayerPath.parse("music", keyword: "music") == MiniPlayerPath(keyword: "music"))
    #expect(MiniPlayerPath.parse("Music", keyword: "music")?.segments == [])
    #expect(MiniPlayerPath.parse("music ", keyword: "music") == MiniPlayerPath(keyword: "music"))
    #expect(MiniPlayerPath.parse("music alb", keyword: "music") == MiniPlayerPath(keyword: "music", filter: "alb"))
    #expect(MiniPlayerPath.parse("music Albums › kind", keyword: "music")
            == MiniPlayerPath(keyword: "music", segments: ["Albums"], filter: "kind"))
    #expect(MiniPlayerPath.parse("music Albums › Kind of Blue — Miles Davis › ", keyword: "music")?.segments
            == ["Albums", "Kind of Blue — Miles Davis"])
    #expect(MiniPlayerPath.parse("musical", keyword: "music") == nil)
    #expect(MiniPlayerPath.parse("mus", keyword: "music") == nil)
    #expect(MiniPlayerPath.parse("music", keyword: "") == nil)
}

@Test("→ goes into a list, ← clears the text and then goes back")
func miniPlayerPathMoves() {
    let top = MiniPlayerPath(keyword: "music")
    #expect(top.entering("Albums") == "music Albums › ")
    let inside = MiniPlayerPath.parse("music Albums › kin", keyword: "music")!
    #expect(inside.back() == "music Albums › ")
    #expect(MiniPlayerPath.parse("music Albums › ", keyword: "music")!.back() == "music ")
    #expect(top.back() == nil)
    #expect(MiniPlayerPath.parse("music x", keyword: "music")!.back() == "music ")
}

@Test("A path leads to its list, or to missing when the library lost it")
func miniPlayerLists() {
    let library = MusicCatalog(sampleLibrary.including(.init()))
    #expect(MiniPlayerList.at([], in: library) == .top)
    guard case .albums(let albums) = MiniPlayerList.at(["Albums"], in: library) else { Issue.record("albums"); return }
    #expect(albums.count == 3)
    guard case .songs(let songs, let album) = MiniPlayerList.at(["Albums", "Kind of Blue — Miles Davis"], in: library) else {
        Issue.record("album"); return
    }
    #expect(songs.map(\.id) == ["A1", "A2", "A3"] && album?.id == "KOB")
    guard case .albums(let his) = MiniPlayerList.at(["Artists", "Miles Davis"], in: library) else { Issue.record("artist"); return }
    #expect(his.map(\.title) == ["Bitches Brew", "Kind of Blue"])
    guard case .songs(let evening, nil) = MiniPlayerList.at(["Playlists", "Evening"], in: library) else { Issue.record("list"); return }
    #expect(evening.map(\.id) == ["A3", "C1"])
    #expect(MiniPlayerList.at(["Albums", "Gone"], in: library) == .missing)
    #expect(MiniPlayerList.at(["Songs"], in: library) == .missing)
}

@Test("Playing a song, a playlist or a set of songs is one AppleScript each")
func miniPlayerScripts() {
    #expect(MusicRequest.playSong("00000000000000A1").script
            == "tell application \"Music\" to play (some track of library playlist 1 whose persistent ID is \"00000000000000A1\")")
    #expect(MusicRequest.playPlaylist("00000000000000E1").script == "tell application \"Music\" to play (some playlist whose persistent ID is \"00000000000000E1\")")
    let many = MusicRequest.playSongs(["A1", "A2"]).script
    #expect(many.contains("user playlist \"Reach Mini Player\""))
    #expect(many.contains("{\"A1\", \"A2\"}"))
    #expect(many.contains("play dest"))
    // Only hex digits reach the script.
    #expect(MusicRequest.playSong("A1\" & quit & \"").script.contains("\"A1\""))
}
