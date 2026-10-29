import Foundation

/// The folder another Mac reads Reach's setup from (S-039), such as one in
/// iCloud Drive. Everything lives under `<folder>/Reach/`: the settings
/// (themes included) in a property list, the snippets as JSON, and the
/// workflows in their own folder.
public struct SyncFolder: Equatable, Sendable {
    public static let directoryName = "Reach"

    public let folder: URL

    public init(folder: URL) { self.folder = folder }

    public var root: URL { folder.appending(path: Self.directoryName, directoryHint: .isDirectory) }
    public var preferences: URL { root.appending(path: "Preferences.plist") }
    public var snippets: URL { root.appending(path: "Snippets.json") }
    public var workflows: URL { root.appending(path: "Workflows", directoryHint: .isDirectory) }

    /// When another Mac (or this one) last wrote the folder; nil when it holds no setup yet.
    public var modified: Date? {
        [preferences, snippets]
            .compactMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
            .max()
    }

    /// Writes the setup, each file in one step so another Mac never reads half of it.
    public func write(preferences values: [String: Any], snippets library: SnippetLibrary) throws {
        try FileManager.default.createDirectory(at: workflows, withIntermediateDirectories: true)
        let plist = try PropertyListSerialization.data(fromPropertyList: Self.synced(values), format: .xml, options: 0)
        try plist.write(to: preferences, options: .atomic)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(library).write(to: snippets, options: .atomic)
    }

    /// The settings in the folder, or empty when there are none.
    public func readPreferences() -> [String: Any] {
        guard let data = try? Data(contentsOf: preferences),
              let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return [:] }
        return Self.synced(values)
    }

    /// The snippets in the folder, or nil when there are none.
    public func readSnippets() -> SnippetLibrary? {
        guard let data = try? Data(contentsOf: snippets) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SnippetLibrary.self, from: data)
    }

    /// Settings that belong to this Mac stay out: the sync folder itself,
    /// window places, and what the system keeps in the app's defaults.
    public static func syncs(key: String) -> Bool {
        let local = ["sync.", "usage.", "NS", "Apple", "com.apple.", "AK", "WebKit", "MSApp"]
        return !local.contains { key.hasPrefix($0) }
    }

    public static func synced(_ values: [String: Any]) -> [String: Any] {
        values.filter { syncs(key: $0.key) }
    }

    /// What to do when the app starts or the folder is set.
    public enum Step: Equatable, Sendable {
        /// The folder is newer than what this Mac last wrote or read: use it.
        case read
        /// This Mac's setup goes to the folder.
        case write
    }

    /// `lastSynced` is the folder's time when this Mac last wrote or read it.
    public static func step(folderModified: Date?, lastSynced: Date?) -> Step {
        guard let folderModified else { return .write }
        guard let lastSynced else { return .read }
        return folderModified > lastSynced.addingTimeInterval(1) ? .read : .write
    }
}

/// The snippets and their collections, as they go to the sync folder.
public struct SnippetLibrary: Codable, Equatable, Sendable {
    public struct Collection: Codable, Equatable, Sendable {
        public var id: UUID
        public var name: String
        public var createdAt: Date

        public init(id: UUID, name: String, createdAt: Date) {
            self.id = id
            self.name = name
            self.createdAt = createdAt
        }
    }

    public struct Snippet: Codable, Equatable, Sendable {
        public var id: UUID
        public var name: String
        public var keyword: String
        public var text: String
        public var createdAt: Date
        public var collection: UUID?

        public init(id: UUID, name: String, keyword: String, text: String, createdAt: Date, collection: UUID?) {
            self.id = id
            self.name = name
            self.keyword = keyword
            self.text = text
            self.createdAt = createdAt
            self.collection = collection
        }
    }

    public var collections: [Collection]
    public var snippets: [Snippet]

    public init(collections: [Collection] = [], snippets: [Snippet] = []) {
        self.collections = collections
        self.snippets = snippets
    }

    /// What reading `incoming` changes here: by id, new ones are added,
    /// known ones updated, and ones the folder no longer has removed.
    public struct Changes: Equatable, Sendable {
        public var insert: [UUID] = []
        public var update: [UUID] = []
        public var delete: [UUID] = []
    }

    public static func changes(from local: [UUID], to incoming: [UUID]) -> Changes {
        let localSet = Set(local)
        let incomingSet = Set(incoming)
        return Changes(insert: incoming.filter { !localSet.contains($0) },
                       update: incoming.filter { localSet.contains($0) },
                       delete: local.filter { !incomingSet.contains($0) })
    }
}
