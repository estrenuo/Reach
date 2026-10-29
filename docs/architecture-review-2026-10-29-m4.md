# Architecture review, end of M4 (2026-10-29)

M4 added the clipboard history, the viewer, merging, snippet collections,
`snip` and expansion while typing. 12,200 lines of Swift; no file passes
600 lines. The hot spots are `LauncherModel` (24 commits in 30 days),
`Snapshot.swift` (23) and the self-test (18).

## One way to borrow the clipboard  [Strong]

Files: Launcher/Selection.swift (`copiedText`), Snippets/SnippetSource.swift (`pasteSnippet`, `SnippetClipboard`), Launcher/CalculatorSource.swift (`Paster`), Clipboard/ClipboardHistory.swift (`skipCurrent`)
Signal: the same kind of bug twice (FIXLOG S-026 and S-030, both about what the pasteboard holds), and two drifted copies of "save the clipboard, use it, put it back".
Problem: the selection hotkey presses ⌘C and puts the old clipboard back with its own copy of the save and restore code. It has none of the S-030 fixes:
- It puts a copied password back, so the password manager no longer clears it.
- Its ⌘C copy is not transient, so Clipboard History keeps the selected text as a clip.
- History then keeps the restored clipboard as one more new copy.
- Its ⌘C is not marked with `Paster.marker`, so the ⌘C-twice watcher can count it as a press.

`Paster`, which every paste goes through, sits in `CalculatorSource.swift`.
Proposal: one module in `Clipboard/ClipboardLoan.swift`, used by both:

```swift
/// The clipboard as it was, kept while Reach uses it for a moment.
struct ClipboardLoan {
    /// Copies every item now, unless the clipboard holds a private copy.
    init(_ board: NSPasteboard)
    var isPrivate: Bool
    /// Puts it back unless something else was copied since `count`, and tells
    /// the history the restored clipboard is not a new copy.
    func giveBack(to board: NSPasteboard, ifStillAt count: Int, history: ClipboardHistory?)
}
```

`Paster` moves next to it, and every key it presses carries the marker.
Benefits: the nspasteboard.org rule lives in one place (the S-030 FIXLOG rule). The selection hotkey gets the fixes for free. `pasteSnippet` loses 30 lines.
Proof of same behavior: the S-030 self-test checks stay as they are. New self-test checks run the selection path on a private pasteboard, with the same checks: a private copy is not put back, the history does not grow.
Plan: (1) `ClipboardLoan` and `Paster` in their own file, used by `pasteSnippet`; (2) `Selection.copiedText` on the loan, with the new checks and a FIXLOG entry, since it is a bug fix.

## Snapshot mode takes the launcher's own sources  [Strong]

Files: Snapshot.swift (293 lines)
Signal: a bug in S-030 (the `snip` snapshot showed no snippets) because Snapshot mode keeps a list of sources by hand.
Problem: that list has drifted. It lacks the Clipboard History row, and it puts web searches before typed URLs, unlike the app. Every new source has to be added twice.
Proposal: swap only what must be fake: `sources.map { $0 === files ? samples : $0 }`.
Benefits: snapshots show what the app shows. A new source needs no snapshot change.
Proof of same behavior: the launcher snapshots, compared image by image. Only `clipboard` rows and order may differ, and where they do, that is the drift being fixed.
Plan: one commit, plus removing the note about it from ARCHITECTURE.md.

## A key monitor that follows a setting  [Worth exploring]

Files: Clipboard/DoubleCopyWatcher.swift, Snippets/SnippetExpander.swift
Signal: the same pattern twice: `withObservationTracking` on a setting, then installing or removing a global `NSEvent` monitor, nil in test runs.
Problem: each one writes its own follow, install and remove code. A third watcher would copy it again.
Proposal: `GlobalMonitor(mask:, isOn: () -> Bool, handle:)`, which follows `isOn` and installs only outside test runs.
Benefits: about 20 lines fewer each, and one place that guarantees no real key monitor in tests.
Proof of same behavior: the S-028 and S-031 self-test checks.
Plan: one commit. Better done when a third watcher appears.

## LauncherModel growth  [Speculative]

Files: Launcher/LauncherModel.swift (552 lines, 24 commits in 30 days)
Signal: over the 400-line threshold for a type, though the clipboard and snippet parts already live in extension files.
Proposal: move Large Type and the confirm flow for system commands into extension files, as the clipboard did. Wait until a story touches them.

## Top recommendation

**One way to borrow the clipboard.** It is Strong. It fixes four real faults in the selection hotkey by sharing what S-030 already tests, and it puts the FIXLOG rule in one place. "Snapshot mode takes the launcher's own sources" is a small Strong second, one commit.

## Considered, not recommended

- A protocol around `NSPasteboard`: `NSPasteboard.withUniqueName()` is already a working test adapter.
- Splitting `ClipboardHistory` (302 lines): one job (watch, keep, purge, put back) with tests at its interface.
- Caching snippet keywords with a store notification instead of the one-second refresh: the fetch is cheap, and a notification is one more thing to keep in sync.

## Also found

- "Ask before deleting snippets" in Settings > General does nothing. Deleting a collection always asks, and deleting a snippet can be undone. Remove it, or make it decide whether deleting a collection asks.

## Outcome

Done on 2026-10-29, as the user chose (the clipboard loan, the snapshot sources, the dead toggle):

- `ClipboardLoan` and `Paster` in `Clipboard/ClipboardLoan.swift`, used by snippet pasting (24c2697). The self-test passed 348 of 348 before and after, with the S-030 and S-031 checks unchanged.
- The selection hotkey reads through the loan (c40c87a), a bug fix with a FIXLOG entry and 4 new self-test checks (352 of 352).
- Snapshot mode takes the launcher's own sources (20a29ac). The layout files are the same as before, and the typed URL state looks the same.
- "Ask before deleting snippets" is gone from Settings > General, and the Accessibility row says what it is for today.

Left for later: "A key monitor that follows a setting" (when a third watcher comes), "LauncherModel growth".
