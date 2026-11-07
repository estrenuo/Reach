import Foundation

/// What a delete took out of info.plist (S-065), kept as values so ⌘Z can put
/// each piece back where it was, down to a line's place in its list.
/// Plist values are immutable property-list types, so passing them on is safe.
public struct DeletedObjects: @unchecked Sendable {
    /// The removed objects, with their index in `objects`, in ascending order.
    public var objects: [(index: Int, value: [String: Any])] = []
    /// The deleted objects' own `connections` lists.
    public var outgoing: [String: [Any]] = [:]
    /// Lines from other objects into a deleted one, with their index in that list, ascending per source.
    public var incoming: [(source: String, index: Int, value: Any)] = []
    /// The deleted objects' `uidata` entries.
    public var uidata: [String: Any] = [:]

    /// The uids of the removed objects, in the order they were in.
    public var uids: [String] { objects.compactMap { $0.value["uid"] as? String } }
}

extension WorkflowEdit {
    /// Removes objects `uids`, every connection to or from them, and their uidata.
    /// Nothing else in the plist changes; a list emptied of its lines stays, as Alfred leaves it.
    @discardableResult
    public static func delete(_ uids: Set<String>, in plist: inout [String: Any]) -> DeletedObjects {
        var removed = DeletedObjects()
        guard !uids.isEmpty else { return removed }

        if let objects = plist["objects"] as? [[String: Any]] {
            var kept: [[String: Any]] = []
            for (index, object) in objects.enumerated() {
                if let uid = object["uid"] as? String, uids.contains(uid) {
                    removed.objects.append((index, object))
                } else {
                    kept.append(object)
                }
            }
            if !removed.objects.isEmpty { plist["objects"] = kept }
        }

        if var connections = plist["connections"] as? [String: Any] {
            var changed = false
            for uid in uids {
                if let lines = connections.removeValue(forKey: uid) {
                    removed.outgoing[uid] = lines as? [Any] ?? []
                    changed = true
                }
            }
            for source in connections.keys.sorted() {
                guard let lines = connections[source] as? [Any] else { continue }
                var kept: [Any] = []
                for (index, line) in lines.enumerated() {
                    if let to = (line as? [String: Any])?["destinationuid"] as? String, uids.contains(to) {
                        removed.incoming.append((source, index, line))
                    } else {
                        kept.append(line)
                    }
                }
                if kept.count != lines.count {
                    connections[source] = kept
                    changed = true
                }
            }
            if changed { plist["connections"] = connections }
        }

        if var uidata = plist["uidata"] as? [String: Any] {
            for uid in uids {
                if let entry = uidata.removeValue(forKey: uid) { removed.uidata[uid] = entry }
            }
            if !removed.uidata.isEmpty { plist["uidata"] = uidata }
        }
        return removed
    }

    /// Puts back what `delete` removed, each piece at its old index (or at the
    /// end, when the list got shorter since).
    public static func restore(_ removed: DeletedObjects, in plist: inout [String: Any]) {
        if !removed.objects.isEmpty {
            var objects = plist["objects"] as? [[String: Any]] ?? []
            for (index, object) in removed.objects {
                objects.insert(object, at: min(index, objects.count))
            }
            plist["objects"] = objects
        }

        if !removed.outgoing.isEmpty || !removed.incoming.isEmpty {
            var connections = plist["connections"] as? [String: Any] ?? [:]
            for (uid, lines) in removed.outgoing { connections[uid] = lines }
            for (source, index, line) in removed.incoming {
                var lines = connections[source] as? [Any] ?? []
                lines.insert(line, at: min(index, lines.count))
                connections[source] = lines
            }
            plist["connections"] = connections
        }

        if !removed.uidata.isEmpty {
            var uidata = plist["uidata"] as? [String: Any] ?? [:]
            for (uid, entry) in removed.uidata { uidata[uid] = entry }
            plist["uidata"] = uidata
        }
    }

    /// Deletes objects `uids` from the workflow in `folder`, reading info.plist fresh.
    public static func delete(_ uids: Set<String>, folder: URL) throws -> DeletedObjects {
        var removed = DeletedObjects()
        try WorkflowFolder.update(folder) { removed = delete(uids, in: &$0) }
        return removed
    }

    /// Puts deleted objects back into the workflow in `folder`.
    public static func restore(_ removed: DeletedObjects, folder: URL) throws {
        try WorkflowFolder.update(folder) { restore(removed, in: &$0) }
    }

    /// The undo name for deleting `count` objects: "Delete Object", "Delete 2 Objects".
    public static func deleteName(_ count: Int) -> String {
        count == 1 ? "Delete Object" : "Delete \(count) Objects"
    }
}
