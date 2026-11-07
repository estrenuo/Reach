# Architecture review: after M7 (2026-11-07)

M7 added thumbnails (S-056), web bookmarks (S-057), contact field actions
(S-058), Music keywords (S-059) and the mini player (S-060), built in four
parallel sessions and merged on 2026-11-07. 3,427 lines in 41 source files;
292 unit tests; the build has no warnings.

Survey:

- Hot spots since 2026-11-06: `Snapshot.swift` (6 commits),
  `SettingsIndex.swift` (5), `SelfTest.swift` (5), `LauncherModel.swift` (4).
- Largest files:
  - `Snapshot.swift`, 675 lines: the only Swift file over 600.
  - `LauncherModel.swift`, 493 lines (680 at the last review, before the
    `+Actions` split).
  - `ActionPanel.swift`, 449 lines.
- The four merges conflicted only in one-line lists: `SettingsTab`,
  `LauncherModel.sources`, `SelfTest.groups`, the snapshot `states` line,
  `SettingsIndexTests` and `GLOSSARY.md`. Each took a minute to resolve.
- Music and the mini player went into `Sources/Reach/Music/` with their own
  `Snapshot+Music.swift` and `Snapshot+MiniPlayer.swift`. Bookmarks and
  contact actions put their settings pages in `UI/`.
- `Process()` lives in five app files, as before; no new ones.
- No duplicate `private struct`s. No new fix-log entries.

## Launcher snapshots by feature  [Done]

Files: Sources/Reach/Snapshot.swift (675 lines)
Signal: a Swift file over 600 lines; the most-edited file since the last review; a merge conflict in two of the four M7 merges.
Problem: the launcher captures are one `states` line of 33 names and one loop with 12 `if name == …` blocks. Four of the blocks repeat the same steps: write a sample workflow's `info.plist`, reload the library, set the query, capture, delete the folder, reload. A new launcher state edits the shared line and the shared loop, so parallel stories collide there. Music showed the other way: `captureMusic` in its own file, called once.
Proposal:

```swift
/// One launcher capture: its file name, what is typed, and what to set up first.
struct LauncherShot {
    var name: String
    var query: String = ""
    var prepare: @MainActor (AppModel) async -> Void = { _ in }
    var cleanUp: @MainActor (AppModel) -> Void = { _ in }
}
extension Snapshot {
    /// A sample workflow in the library for the length of `body`.
    static func withSampleWorkflow(_ name: String, _ plist: [String: Any], _ body: () async -> Void) async
    static func captureLauncher(_ shots: [LauncherShot], model: AppModel, dir: String) async
}
```

The plain states stay one list; the workflow captures move to
`Snapshot+Workflows.swift`, each a `LauncherShot` using `withSampleWorkflow`.
Benefits: a new launcher state is one entry in its feature's file; the loop has no `if name ==`; `Snapshot.swift` drops below 400 lines.
Proof of same behavior: the same 180 PNG names in `/tmp/Reach-shots` before and after, the layout JSONs PASS, and a look at the moved captures in light and dark.
Plan: 1) add `LauncherShot`, `captureLauncher` and `withSampleWorkflow`, run the plain states through them. 2) move the workflow captures to `Snapshot+Workflows.swift`. Two commits, snapshot code only.

Done: the launcher captures are one list of `LauncherShot`s run by `captureLauncher` (`Snapshot+Launcher.swift`), with no `if name ==`; the workflow shots and the Workflows window captures are in `Snapshot+Workflows.swift`, the sample clips and the clipboard viewer in `Snapshot+Clipboard.swift`. `Snapshot.swift` went from 675 to 395 lines. The same 180 PNG names before and after, every layout JSON and grid-lint PASS, and the moved captures look the same in light and dark (only the text cursor and the file dates differ).

## Read bookmark files off the main thread  [Worth exploring]

Files: Sources/Reach/Launcher/BookmarkSource.swift (215 lines)
Signal: slow work on the main thread.
Problem: the first query after a bookmark file changed reads and parses Safari's `Bookmarks.plist` and every Chrome profile on the main actor, inside `results(for:)`, between two keystrokes. A large Safari file can be several MB. `results(for:later:)` already lets a source answer later, and `MusicLibraryReader` reads off the main thread.
Proposal: when the files changed, start the read in a `Task.detached` that returns `[WebBookmark]`, return the old list (or `[]`) now, and send the matches through `later`. `WebBookmarks` in ReachKit already parses plain `Data`.
Benefits: typing never waits on disk; the source works like the mini player.
Proof of same behavior: the `bookmarks` self-test group (19 checks) and the 10 `WebBookmark` unit tests; a timing of the first query with a large fixture file before and after.
Plan: one commit. Do it first if the first `bm` query on the real Mac feels slow.

## Settings pages in their feature's folder  [Worth exploring]

Files: Sources/Reach/UI/ (23 files; 14 are settings pages)
Signal: a settings page that lives far from its feature.
Problem: `UI/` mixes the shared parts (`Grid`, `Theme`, `WindowBehavior`, `EditableList`) with feature pages such as `BookmarkSettingsView`, `ContactsSettingsView` and `DictionarySettingsView`, while `Music/`, `Clipboard/`, `Snippets/` and `Workflows/` keep their pages with the feature.
Proposal: move each page next to its source (`Launcher/` or a new feature folder); `UI/` keeps only shared parts.
Benefits: one folder per feature; a story touches fewer folders.
Proof of same behavior: a file move only; the build and `swift test` pass, git shows renames.
Plan: one commit of renames, no edits.

## Top recommendation

**Launcher snapshots by feature.** It is the only `Strong` card: the one file
over 600 lines, the most edited, and where parallel stories collide. It
touches no app behavior, and the snapshot names prove it.

## Considered, not recommended

- One registration per feature (a protocol that adds the settings tab, the
  source, the self-test group and the snapshots at once). The M7 merge
  conflicts were in one-line lists and took a minute each; a registry
  would hide the order of the sidebar and of the sources, which matters.
- Splitting `ActionPanel.swift` (449 lines). Below the 600-line signal and
  not a hot spot.
- `SettingsTab`'s three `switch`es (title, summary, page). Additive and
  checked by the compiler.
