# Architecture — Reach

A keyboard launcher: an agent app (no Dock icon) with a floating launcher panel, a menu bar icon and a Settings window. See `docs/BRIEF.md` for what it does and `CLAUDE.md` for how to build and check it.

## Targets

| Target | Holds | Depends on |
| --- | --- | --- |
| `ReachKit` | Pure logic, no AppKit or SwiftUI: `Matcher` (text scores), `QueryKind` (keywords), `Ranking` (text score plus Learning), `WebSearchURL`, `KeyCombo`, `SnippetName` | Foundation |
| `Reach` | The app: panel, views, system hooks, SwiftData | ReachKit |
| `ReachKitTests` | Unit tests for ReachKit | ReachKit |

Settings go through `Store.settings`: `UserDefaults.standard` for real use, and for test, snapshot and seed runs (`APP_STORE` set) a suite that starts empty at every launch, so those runs never read or write the real settings. AppKit's own window frames still land in `.standard`.

Logic that can be tested without the app goes in ReachKit. The app target holds the self-test (`SelfTest/`, one file per milestone section) and snapshot mode (`Snapshot.swift`); both refuse to run without `APP_STORE` in /tmp.

## The launcher

```text
HotkeyCenter (Carbon) ─┐
Menu bar "Show Launcher" ┼─> LauncherController ──> LauncherPanel (NSPanel, non-activating)
                         │        │ keys (↑ ↓ ← → Tab ↩ Esc ⌘1–9 ⌘,)        └─ LauncherView (SwiftUI)
                         │        v
                         └──> LauncherModel ── query ──> [ResultSource] ──> merge ──> results
                                   │                       apps, files        hints, Ranking + Learning,
                                   └─ opener (NSWorkspace; a recorder in the self-test)   fallbacks
```

- `LauncherController` (in `LauncherPanel.swift`) shows, hides, sizes and places the panel, and turns key events into model calls. The panel never activates Reach, so the previous app keeps focus.
- `LauncherModel` owns the query, the results and the selection. It knows no source by name.
- The action panel (`ActionPanel`, `ActionPanelView`) takes over the launcher for one file, folder or app when → is pressed with the cursor at the end of the query. `FileAction` in ReachKit lists the actions and filters them; `ActionRunner` runs them on the system, and the self-test swaps in a recorder through `LauncherModel.perform`. Move to Trash goes through `Trash.move` (`FileManager.trashItem`), never a delete. Actions switched off in Settings > Actions (`ActionSettings`, saved in UserDefaults outside test runs) never reach the panel.
- Quick Look (`QuickLook`, S-012) shows the system preview panel for the action panel's file, else the selected result. A tap on ⇧ (`ShiftTap` in ReachKit tells it from ⇧ held for a capital), ⌘Y or the Quick Look action opens it; Esc closes it before anything else. The launcher keeps the keyboard: Quick Look makes itself key on opening, and `LauncherController` takes it back when it lost the keyboard within a second of Quick Look opening or closing (`KeyboardHandover` in ReachKit, unit-tested; `QuickLook.keepsLauncherKey` feeds it the clock), since with another app in front the key window reads nil. `PreviewSettings` (Settings > Previews) turns it off and skips file types and folders. Logs go to `quicklook`, without paths.
- The buffer (S-013) is a `FileBuffer` in ReachKit, held by `LauncherModel` across hides: ⌥↑ and ⌥↓ add, ⌥← and ⌥⌫ take out (and pass to the text field when it is empty), ⌥→ opens `ActionPanel(items:)`. `ActionRunner.run(_:on:)` takes every item; `FileAction.available(many:)` leaves out the actions for one item. An action on the buffer empties it, and `didShow` empties it after 5 minutes unused (`LauncherModel.now`, moved forward by the self-test). The selection hotkey with several Finder files opens the same panel.
- The selection hotkey (⌃⌥⌘\, a second Carbon hotkey, id 3) reads the macOS selection through `SelectionReader` (Finder's selection by Apple Events, other apps' selected text by Accessibility, ⌘C as the fallback) and opens the action panel on it. Selected text gets `TextAction`s and one web search per fallback engine; `LargeType` shows text on a dark card. The self-test swaps the reader through `LauncherModel.readSelection`.
- When the launcher rewrites the query itself (→, ←, Tab, Browse in Launcher) it bumps `queryRewrites`, and the view puts the text cursor at the end.

## Seam: ResultSource

`Launcher/ResultSource.swift`. Every kind of result is a source:

```swift
protocol ResultSource: AnyObject {
    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]?
    func cancel()
}
```

- Fast sources return results at once. Slow ones (Spotlight) return nil and call `later`; the model keeps the previous results on screen until every source has answered.
- The model merges the answers: non-openable hints first, then a calculation's answer (a result with `answer` instead of a URL: ↩ copies it through `copier`, ⌘↩ also pastes through `paster`), then openable results ranked by `Ranking.order` with Learning (9 in all), then `Fallbacks`: the web searches in `WebSearchSettings.fallbackIDs`, in that order, split with the results by `FallbackList.split` (only when nothing openable came back, or always below the results within the 9).
- Adapters: `TypedURLSource` (a pinned row for a URL typed in the search field, read by `TypedURL` in ReachKit), `URLHistory` (opened URLs as `URLVisit` rows in the database, ranked with the apps; `URLRetention` decides when they go), `WebSearchSource` (keyword searches from `WebSearchSettings`; `WebSearches.matches` in ReachKit decides, and gets the query as typed, since a trailing space ends a keyword), `CalculatorSource` (the answer row for `2*21` or `=sqrt(16)`, from `Calculator` in ReachKit), `AppIndex` (apps at the top level of the search scope's folders), `FileSearch` (Spotlight: `open`/`find` by name, `in` by contents, `tags` by Finder tag, and the Default Results types for a query without a keyword), `PathBrowser` (folder listings for `~/` and `/`), and `FakeSource` in the self-test.
- Search settings (`SearchSettings`, S-014): the keywords, Don't Show, Default Results and the scope. `QueryKind(query, keywords:)` in ReachKit reads the keyword with the current words, and `SpotlightPredicate` builds the query string, so both are unit-tested without Spotlight.
- Browsing (`QueryKind.path`) is the one exception to the merge: the folder listing keeps its own order (A to Z, or best match), has no cap of 9 and no fallbacks, and the launcher switches to `BrowseView` (list, Preview, footer). → / Tab enter a folder and ← goes up, through `LauncherModel.enter`, `complete` and `back`.

**To add a kind of result** (system command, dictionary): write one class that conforms to `ResultSource`, add it to `LauncherModel.sources` in `init`, and add a self-test check. If it needs a keyword, add a case to `QueryKind` in ReachKit with a unit test.

## Data

- SwiftData store at `~/Library/Application Support/Reach/Reach.store`: `Snippet`, `LearningEntry`. New fields need a default value so existing stores keep loading.
- Settings (hotkey, open at login, accent) live in `UserDefaults` or with the system (`SMAppService`), not in the store.
- Results are built per query and never stored.

## Decisions

- Global hotkey through Carbon `RegisterEventHotKey`: no permission needed.
- File search uses Spotlight word starts (`"name*"cdw`), not substring matching: a leading wildcard skips the index and missed the 200 ms target.
- Learning: 150 points a pick, at most five picks, halved every 30 days; capped below the exact-title score so typing a full name always wins.
