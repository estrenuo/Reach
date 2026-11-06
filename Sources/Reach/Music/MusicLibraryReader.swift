import AppKit
import iTunesLibrary
import ReachKit

/// Reads the Music library for the mini player (S-060): once, the first time
/// the mini player opens, off the main thread, and again when Music says the
/// library changed. The self-test and snapshots swap `loader` and `artwork`
/// for a sample library, so a test run never reads the person's music.
final class MusicLibraryReader {
    enum State: Equatable {
        case notRead
        case reading
        case ready(MusicLibrary)
        /// macOS said no: Media & Apple Music is off for Reach.
        case denied
    }

    private(set) var state = State.notRead
    /// How many times the library was read; the self-test counts them.
    private(set) var reads = 0
    /// Reads the library and answers on the main thread. Nil means macOS said no.
    var loader: (@escaping @MainActor (MusicLibrary?) -> Void) -> Void = { MusicLibraryReader.readLive($0) }
    /// A picture file for an album's artwork, or nil while there is none (yet).
    var artwork: @MainActor (String) -> String? = { _ in nil }
    /// Called when a read finishes or artwork arrives, so the launcher can show it.
    var onChange: @MainActor () -> Void = {}
    private var observer: NSObjectProtocol?
    private var cached: (include: MusicLibrary.Include, catalog: MusicCatalog)?

    init() {
        artwork = { [weak self] id in LiveArtwork.shared.path(forAlbum: id) { self?.onChange() } }
    }

    /// The library sorted for the mini player with these include settings; nil until it is read.
    func catalog(_ include: MusicLibrary.Include) -> MusicCatalog? {
        guard let library = library() else { return nil }
        if let cached, cached.include == include { return cached.catalog }
        let catalog = MusicCatalog(library.including(include))
        cached = (include, catalog)
        return catalog
    }

    static let privacySettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Media")
    static let allowText = "Allow Reach to read your music library in System Settings > Privacy & Security > Media & Apple Music"

    /// The library, reading it first when it was never read.
    func library() -> MusicLibrary? {
        if state == .notRead { read() }
        if case .ready(let library) = state { return library }
        return nil
    }

    func read() {
        guard state != .reading else { return }
        let first = state == .notRead
        if first { state = .reading }
        reads += 1
        // A loader that answers at once (the self-test's) needs no second refresh.
        final class Call { var inline = true }
        let call = Call()
        loader { [weak self] library in
            guard let self else { return }
            state = library.map { .ready($0) } ?? .denied
            cached = nil
            if first { follow() }
            if !call.inline { onChange() }
        }
        call.inline = false
    }

    /// Music changed the library: read it again, when it was read before.
    func libraryChanged() {
        guard case .ready = state else { return }
        read()
    }

    /// Back to unread, with the live loader's results forgotten; for the self-test.
    func forget() {
        state = .notRead
        cached = nil
        reads = 0
    }

    private func follow() {
        guard observer == nil, loaderIsLive else { return }
        observer = DistributedNotificationCenter.default().addObserver(
            forName: .ITLibraryDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.libraryChanged() }
        }
    }

    /// Only the real library is followed; test runs post no notifications anyway.
    var loaderIsLive = true

    /// ITLibrary, off the main thread. It asks for Media & Apple Music the first time.
    nonisolated static func readLive(_ done: @escaping @MainActor (MusicLibrary?) -> Void) {
        Task.detached(priority: .userInitiated) {
            let read = LiveArtwork.load()
            await MainActor.run { done(read) }
        }
    }
}

/// Artwork from iTunesLibrary, written once per album to Reach's caches folder,
/// so the launcher shows it like any picture file.
nonisolated final class LiveArtwork: @unchecked Sendable {
    static let shared = LiveArtwork()
    private let lock = NSLock()
    /// The first song with artwork, per album, from the last read.
    private var items: [String: ITLibMediaItem] = [:]
    private var pending: Set<String> = []
    let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appending(path: "com.sanderrobijns.reach/Artwork", directoryHint: .isDirectory)

    /// Reads the library; nil when macOS said no.
    nonisolated static func load() -> MusicLibrary? {
        guard let library = try? ITLibrary(apiVersion: "1.0") else { return nil }
        var songs: [MusicSong] = []
        var artwork: [String: ITLibMediaItem] = [:]
        for item in library.allMediaItems {
            let kind: MusicMediaKind
            switch item.mediaKind {
            case .kindSong: kind = .song
            case .kindPodcast: kind = .podcast
            case .kindMovie, .kindTVShow, .kindMusicVideo, .kindHomeVideo: kind = .video
            default: continue
            }
            let id = MusicLibrary.persistentID(item.persistentID.uint64Value)
            let albumID = item.album.title == nil ? "" : MusicLibrary.persistentID(item.album.persistentID.uint64Value)
            songs.append(MusicSong(id: id, title: item.title, artist: item.artist?.name ?? "", album: item.album.title ?? "",
                                   albumArtist: item.album.albumArtist ?? "", albumID: albumID,
                                   disc: max(item.album.discNumber, 1), number: item.trackNumber, kind: kind))
            if !albumID.isEmpty, artwork[albumID] == nil, item.hasArtworkAvailable { artwork[albumID] = item }
        }
        let playlists = library.allPlaylists.compactMap { list -> MusicPlaylist? in
            guard list.isVisible, !list.isPrimary, list.distinguishedKind == .kindNone, list.kind != .folder else { return nil }
            return MusicPlaylist(id: MusicLibrary.persistentID(list.persistentID.uint64Value), name: list.name,
                                 songIDs: list.items.map { MusicLibrary.persistentID($0.persistentID.uint64Value) })
        }
        shared.lock.withLock { shared.items = artwork }
        return MusicLibrary(songs: songs, playlists: playlists)
    }

    /// The album's artwork file when it was written; else writes it in the
    /// background and calls `ready` on the main thread when it is there.
    func path(forAlbum id: String, ready: @escaping @MainActor () -> Void = {}) -> String? {
        let file = folder.appending(path: "\(id).png")
        if FileManager.default.fileExists(atPath: file.path) { return file.path }
        let item: ITLibMediaItem? = lock.withLock {
            guard !pending.contains(id) else { return nil }
            pending.insert(id)
            return items[id]
        }
        guard let item else { return nil }
        let folder = folder
        Task.detached(priority: .utility) {
            if let image = item.artwork?.image, let tiff = image.tiffRepresentation,
               let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try? png.write(to: file)
            }
            await MainActor.run { ready() }
        }
        return nil
    }
}
