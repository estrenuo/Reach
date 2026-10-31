# Stories — Reach

Source: [BRIEF.md](BRIEF.md) and [screens/INDEX.md](screens/INDEX.md) (66 screens of the reference app, 2026-10-28). Names follow `docs/GLOSSARY.md` (started with the M1 UX notes).

Status legend: `todo`, `doing`, `done`, `dropped`.

---

## M1 Core loop: summon, type, open

Done when I can press a hotkey, type a few letters, open an app or file, and the app remembers my choices after a restart.

### S-001 Summon the launcher with a global hotkey
As the user, I press the launcher hotkey (default ⌃⌥Space) anywhere and an empty launcher bar appears centred on the screen with the cursor in the search field; pressing it again or Esc hides it.
Screens: 49-alfred-bar-empty.png
Acceptance:
- [snap] Empty state: one rounded bar with a large search field and the app mark at the right, nothing else.
- [self] Hotkey toggles the bar from any app; Esc and clicking outside hide it and give focus back to the previous app.
- [manual] The bar appears within 100 ms of the key press.
UX:
- Flow: hotkey (default ⌃⌥Space), or menu bar icon > Show Launcher → search field has focus, previous query cleared → Esc, the hotkey again, or a click outside hides it and the previous app gets focus back
- Surface: panel (non-activating floating panel; people type and watch results, then return to their work)
- States: empty = search field only, no hint text in the results area; there is no loading state (the bar shows before any search runs)
- Words: search field placeholder "Search"; no title bar
- Access: VoiceOver reads "Launcher, search field"; Reduce Motion uses a fade instead of a scale-in
Status: done

### S-002 See ranked app results while typing
As the user, I type part of an app name and see up to 9 matching apps, the best match selected.
Screens: 50-alfred-bar-results.png
Depends: S-001
Acceptance:
- [snap] Rows show icon, title and a shortcut column (↩ on the selected row, ⌘2–⌘9 on the others); the selected row is filled with the accent colour; the subtitle shows only on the selected row.
- [unit] Matching covers word starts and initials ("vsc" → Visual Studio Code) and the apps folders of the search scope.
- [unit] Results update on every keystroke within 50 ms for 500 indexed apps.
UX:
- Flow: type in the search field → results appear under it, first result selected → keep typing to narrow → Backspace widens, Esc clears the query (a second Esc hides the launcher)
- Surface: inline list in the launcher panel
- States: no results → fallbacks (S-006); too much → 9 visible rows, then scroll with a thin indicator; long titles truncate in the middle with the full title in the tooltip
- Words: subtitle of an app result is its path; shortcut column "↩" on the selected result, "⌘2"…"⌘9" on the others
- Access: the selection is shown by fill and by the ↩ glyph (not by colour alone); VoiceOver reads "title, subtitle, result 1 of 9"
Status: done

### S-003 Open a result with Return or ⌘number
As the user, I press ↩ to open the selected result, ↑/↓ to move the selection, or ⌘2–⌘9 to open a row directly.
Screens: 50-alfred-bar-results.png
Depends: S-002
Acceptance:
- [self] ↩ opens the selected item and hides the bar; ⌘n opens row n.
- [self] ↑ on the first row and ↓ on the last row do nothing (no wrap).
UX:
- Flow: ↑/↓ or the mouse hover moves the selection → ↩, a click, or ⌘n opens → the launcher hides and the app or file comes to the front
- Surface: inline (acts on the selected result)
- States: done = the launcher hides at once; error "Unable to open “Name”. It may have been moved or deleted." inline as the selected result's subtitle, launcher stays open
- Words: no buttons; tooltip on a result shows its full path
- Access: keyboard-only flow complete; VoiceOver action "Open"
Status: done

### S-004 Results learn from what I pick
As the user, when I type the same letters again, the item I chose last time comes first.
Screens: 50-alfred-bar-results.png
Depends: S-003
Acceptance:
- [unit] Query → chosen item is stored with a count and last-used date; it ranks above a better text match after two picks.
- [unit] The knowledge survives an app restart.
UX:
- Flow: no UI of its own; ranking changes after each open; way back is Settings > Advanced > Clear Learning (S-038)
- Surface: none (behaviour)
- States: first run = plain text-match order
- Words: the feature is called "Learning" everywhere
- Access: n/a
Status: done

### S-005 Find files by name with a keyword
As the user, I type `open <name>` (or `'` / space prefix) and see matching files and folders, most recently used first.
Screens: 55-alfred-file-search-find.png, 56-alfred-quick-file-search.png
Depends: S-002
Acceptance:
- [snap] File rows show the file icon and name; the selected row shows the path as subtitle.
- [unit] Search uses Spotlight metadata and returns within 200 ms.
- [self] ↩ opens the file in its default app.
UX:
- Flow: type `open ` or `'` → results switch to files and folders → ↩ opens; Backspace over the keyword returns to normal results
- Surface: inline list in the launcher panel
- States: keyword typed with no name yet → one hint result "Type a file name"; no matches → "No files match “query”" as a non-openable result plus the fallbacks; slow Spotlight (> 0.5 s) → keep the previous results until new ones arrive
- Words: keyword names "open" and `'`; hint result "Type a file name"
- Access: the file kind is in the VoiceOver label ("PDF document, report.pdf, in Documents")
Status: done

### S-006 Search the web when nothing matches
As the user, when my query has no results I see "Search Google / Amazon / Wikipedia for '…'" and ↩ opens the browser.
Screens: 54-alfred-fallbacks.png, 59-alfred-web-search-keyword.png
Depends: S-002
Acceptance:
- [snap] Three fallback rows with engine icon and quoted query.
- [unit] The query is URL-encoded into the engine's URL template.
UX:
- Flow: query with no results → fallbacks appear as results → ↩ or ⌘n opens the default browser
- Surface: inline (results)
- States: shown only when nothing else matches
- Words: "Search Google for “query”" (curly quotes, engine name first)
- Access: the engine icon has a text alternative ("Google")
Status: done

### S-007 Change the launcher hotkey in Settings
As the user, I open Settings from the menu bar icon, record a new hotkey on the General page, and it works immediately.
Screens: 01-general.png, 48-menubar-status-menu.png
Depends: S-001
Acceptance:
- [snap] General page: launch-at-login checkbox, hotkey recorder field, permissions button.
- [snap] Menu bar icon menu: Toggle, version (disabled), Settings… ⌘,, Quit.
- [self] The new hotkey is stored and the old one stops working; launch at login registers a login item.
UX:
- Flow: menu bar icon > Settings… or ⌘, while the launcher is open → Settings opens on General → click the hotkey field, press the keys → saved at once; Esc while recording keeps the old hotkey
- Surface: new window (Settings, people come back to it) with the hotkey as an inline recorder field
- States: recording = field shows "Press a key combination"; conflict = inline error "This key combination is used by another app. Choose a different one." under the field
- Words: menu "Show Launcher", "Settings…", "Quit"; labels "Launcher hotkey", "Open at login"; button "Grant Permissions…"
- Access: the recorder field reads "Launcher hotkey, Control Option Space"; the whole page works with Tab
Status: done

---

## M2 Files and actions

### S-008 Browse folders inside the launcher
As the user, I type `~/` or `/` and walk the file system with →/← or Tab, seeing a preview of the selected item.
Screens: 57-alfred-file-navigation.png, 04-features-file-search-navigation.png
Depends: S-005
Acceptance:
- [snap] Path in the field, listing on the left, large icon and created/modified dates on the right.
- [self] ↩ on a folder opens it in Finder; → enters it; ← goes to the parent.
UX:
- Flow: type `~/` or `/` -> the folder's contents, folders and files mixed, A to Z -> type to filter -> → or Tab enters the selected folder (Tab on a file completes its name) -> ← drops the typed name, then goes up one folder -> ↩ opens the file, or the folder in Finder -> Esc clears the query, then hides
- Surface: inline in the launcher (changes what is on screen): the result list on the left, the Preview on the right, the selected name in a footer
- States: empty folder "“Developer” is empty"; no match "Nothing in “Developer” matches “xyz”"; missing "No folder at “~/nope”"; long names truncate in the middle with the full name as a tooltip; hidden files only when the typed name starts with "."
- Words: Preview labels "Created" and "Modified"; folder row tooltip "Press → to browse this folder, ↩ to open it in Finder"
- Access: keyboard only; VoiceOver reads "Folder, Developer, result 1 of 14"; the Preview is one element "Created 16 Jan 2020, Modified today"; no web fallbacks while browsing
Status: done

### S-009 Show the action panel for a result
As the user, I press → on a file or app and choose an action (Open with, Reveal in Finder, Copy path, Get Info, Move to Trash…).
Screens: 51-alfred-action-panel.png, 07-features-universal-actions-general.png
Depends: S-005
Acceptance:
- [snap] Header with icon, name and path; filter field; action list with ⌘n; preview and metadata on the right; footer with the action's description.
- [self] Typing filters the actions; Esc returns to the results.
- [unit] Trash goes through `FileManager.trashItem`, never a hard delete.
UX:
- Flow: → on a file, folder or app (text cursor at the end of the query; while browsing, → on a folder still enters it) -> the action panel, filter field focused -> type to filter -> ↑ ↓, ↩ or ⌘1–9 runs the action -> the launcher hides (Browse in Launcher shows the folder; Open With… lists apps) -> Esc clears the filter, then goes back to the results with the query kept; ← on an empty filter goes back too
- Surface: inline in the launcher (the panel swaps its content, no second window)
- Actions: Open; Open With…; Reveal in Finder; Browse in Launcher; Get Info; Copy Path; Copy File; Open in Terminal; Move to Trash. Folders skip Open With…; Open in Terminal uses the folder itself, or a file's folder
- States: no action matches "No actions match “xyz”"; Open With… with no other apps "No other apps open this file"; a failed action shows "Unable to run “Move to Trash” on “notes.txt”." in the footer and the panel stays
- Words: footer descriptions in sentence case, like "Show it selected in a Finder window" and "Move it to the Trash. You can put it back from the Trash."; filter placeholder "Filter actions"
- Access: keyboard only; VoiceOver reads the header "Actions for Safari, /Applications/Safari.app", each row "Action, Reveal in Finder, 3 of 9"; Move to Trash needs no confirmation because it can be undone from the Trash; when a synced folder (OneDrive, iCloud Drive) refuses a plain trash, Finder moves it, after asking once for Automation permission
Status: done

### S-010 Choose which actions appear
As the user, I switch individual actions on or off in Settings > Features > Actions.
Screens: 08-features-universal-actions-actions.png
Depends: S-009
Acceptance:
- [snap] A checklist with icon and name per action.
- [unit] A disabled action never shows in the panel.
UX:
- Flow: Settings (⌘, or the menu bar icon) > Actions tab -> uncheck an action -> it leaves the action panel at once, also while filtering -> check it to bring it back
- Surface: a Settings tab (one topic, a grouped Form), the native form of the reference's "Features > Actions" page
- States: everything on by default; with every action off, → shows the hint "All actions are off. Turn them on in Settings > Actions."
- Words: tab "Actions"; section "Action Panel"; one checkbox per action with its icon and name; footer "Actions you turn off no longer show in the action panel. Open With… shows only for files and apps."
- Access: each checkbox reads its action's name; the settings are saved for the next launch, and test runs never change them
Status: done

### S-011 Act on the current macOS selection
As the user, I select files in Finder or text in any app and press ⌥⌘\ to open the action panel for it.
Screens: 07-features-universal-actions-general.png
Depends: S-009
Acceptance:
- [self] A Finder selection gives file actions; selected text gives text actions (Large Type, web search, copy as plain text).
- [manual] Works in Finder, Safari and TextEdit.
UX:
- Flow: select files in Finder or text in any app -> the selection hotkey -> the launcher opens straight on the action panel for it -> type to filter, ↩ or ⌘1–9 runs -> the launcher hides; Esc clears the filter, then hides the launcher (there are no results behind it)
- Hotkey: ⌃⌥⌘\ while Alfred still owns ⌥⌘\ (the same rule as ⌃⌥Space); shown in Settings > Actions
- Surface: the action panel of S-009, with the selection as its header
- Files: the first selected file gets the file actions; the header says "and 2 more" for the rest (acting on all of them is S-013)
- Text actions: Show in Large Type; Copy as Plain Text; one "Search Google for “…”" row per fallback engine
- States: nothing selected: the launcher with "Select files in Finder or text in any app, then press ⌃⌥⌘\"; no Accessibility permission: the row "Allow Reach to read selected text" that opens System Settings > Privacy & Security > Accessibility; Large Type: a dark rounded card over the screen, closed by Esc or a click
- Words: header for text "Selected text in Safari", Preview shows the text itself
- Access: text actions read like file actions; Large Type is one element "Large Type, <text>"
Status: done

### S-012 Quick Look the selected result
As the user, I press ⇧ (or ⌘Y) to preview the selected file.
Screens: 28-features-previews.png
Depends: S-005
Acceptance:
- [self] A Quick Look panel opens and closes on a second ⇧ or Esc.
- [snap] Settings > Previews: Quick Look toggle and two exclusion lists (empty state).
UX:
- Flow: select a result -> tap ⇧ or press ⌘Y -> the Quick Look panel opens beside the launcher, which keeps focus -> ↑/↓ change the result and Quick Look follows -> ⇧, ⌘Y or Esc closes it (Esc closes only Quick Look) -> hiding the launcher closes it too
- Tap: ⇧ pressed and let go quickly with no other key in between, so typing capitals never opens Quick Look
- Surface: the system Quick Look panel (a tool kept open beside the work); Settings > Previews tab (a place people come back to)
- States: a result without a file (web search, hint) or a skipped type or folder: ⇧ does nothing; empty lists show "No file types" and "No folders"; long paths truncate in the middle with the full path as a tooltip
- Words: tab "Previews"; checkbox "Tap ⇧ to Quick Look the selected result" with "Or press ⌘Y. Press it again or Esc to close Quick Look."; lists "Skip These File Types" and "Skip These Folders", footers "Files of these types get no Quick Look and show no dates in the Preview. Drop a file here or click + to choose one." and "Nothing inside these folders gets Quick Look or Preview dates. Useful for slow network drives."; buttons + "Add a file type to skip" / "Add a folder to skip", − "Stop skipping the selected item"
- Access: keyboard only in the launcher; VoiceOver reads the lists as "Skip These File Types, empty"; + and − carry labels
- Action panel: ⇧ and ⌘Y preview the panel's file too, and "Quick Look" is the second action ("Preview it without opening it. Tap ⇧ or press ⌘Y."); it shows only when Quick Look can preview the file, and ↩ on it keeps the launcher open. Esc closes Quick Look before the panel. Selected text has no file, so neither applies there
- Not now: rich thumbnails in the Preview (the reference's second checkbox) need a slow thumbnail source and move to Later
Status: done

### S-013 Collect files in a buffer and act on all of them
As the user, I press ⌥↑ on several files and then ⌥→ to run one action on all of them.
Screens: 05-features-file-search-buffer.png
Depends: S-009
Acceptance:
- [snap] Buffered items show small icons in the bar.
- [unit] ⌥↑ toggles, ⌥← removes the last item; the buffer clears after an action.
UX:
- Flow: select a file, folder or app -> ⌥↑ adds it, or takes it out again; ⌥↓ adds it and selects the next result -> search again, the buffer stays -> ⌥→ opens the action panel for every item -> an action runs on all of them, then the buffer is empty. Way back: ⌥← takes out the last item, ⌥⌫ empties the buffer, Esc in the panel goes back to the results with the buffer kept
- Keys: ⌥← and ⌥⌫ work on the buffer only when it has items; with an empty buffer they move and delete by word, as in any text field. ⌥↑ on a result without a file (web search, hint) does nothing
- Surface: small icons at the right end of the search field (inline; the launcher keeps its height), with a count; the action panel as for one file
- States: empty buffer shows nothing; up to 5 icons, then "+N"; each icon's tooltip is the file's name, the group's is "3 items in the buffer. ⌥→ for actions, ⌥← to take out the last, ⌥⌫ to empty."; the panel header says "3 Items" with the names as its detail, and its Preview lists the names
- Actions on several items: Open, Open With… (apps that open every one, only when no item is a folder), Reveal in Finder, Get Info, Copy Path (one path per line), Copy File, Move to Trash. Browse in Launcher, Open in Terminal and Quick Look are for one item and do not show
- Clearing: after an action on the buffer, and when the buffer is unused for 5 minutes (checked when the launcher shows). Hiding and showing the launcher keeps it. The selection hotkey with several Finder files opens the same panel for all of them
- Words: "Buffer"; "3 Items"; footer as for the action
- Access: keyboard only; VoiceOver reads the icons as "Buffer, 3 items: q3.pdf, q2.pdf, photo.png"
- Not now: settings for the buffer (on/off, when to clear), ⌥-click to take out one item
Status: done

### S-014 Set file-search keywords, scope and exclusions
As the user, I rename or disable the `open`/`find`/`in`/`tags` keywords, edit the search scope and hide file types.
Screens: 02-features-default-results.png, 03-features-file-search-search.png, 06-features-file-search-advanced.png
Depends: S-005
Acceptance:
- [snap] Default Results page with the scope path list (+, −, Reset) and the type checkboxes.
- [snap] File Search page with the keyword rows and the "Don't show" checkboxes.
- [unit] `find` reveals in Finder, `in` searches file contents, `tags` searches Finder tags.
UX:
- Flow: Settings > Search -> Keywords: a checkbox and a text field per keyword (open, find, in, tags); Return or leaving the field saves, Esc puts the saved word back -> Don't Show: checkboxes -> Default Results: checkboxes -> Search Scope: a folder list with +, − and Reset; drop folders from Finder. In the launcher: `find rep` -> files, ↩ reveals the selected one in Finder; `in rabbit hat` -> files whose contents have every word; `tags work` -> files tagged with every word. A keyword that is off makes the query a normal search.
- Surface: one Settings tab "Search" between General and Actions (grouped form sections, changes values inline)
- States: keyword with no text yet -> hint "Type a file name", "Type words from inside a file", "Type a tag"; invalid keyword -> inline red text under the field ("Type a keyword.", "A keyword is one word, without spaces.", "“find” is already the keyword for Reveal in Finder.") and the saved word stays; scope with one folder left -> − is off; no default types -> apps only, as now
- Words: tab "Search"; sections "Keywords", "Don't Show", "Default Results", "Search Scope"; keyword labels "Open files", "Reveal in Finder", "Search inside files", "Search file tags"; Reset tooltip "Put back the standard folders"; footers say what each section does
- Access: every checkbox and field has the label text; the keyword field's VoiceOver label is "Keyword for Open files"; the scope list reads like the Previews lists
Status: done

---

## M3 Built-in answers

### S-015 Calculate in the bar
As the user, I type `2*21` and see the answer; with `=` I can use functions like `sqrt`. ↩ copies the answer.
Screens: 52-alfred-calculator.png, 53-alfred-calculator-advanced.png, 16-features-calculator.png
Depends: S-002
Acceptance:
- [unit] Standard mode handles + − × ÷ ^ % and brackets; `=` mode adds functions; decimal separator follows the locale setting.
- [snap] One result row with a calculator icon and the answer.
UX:
- Flow: type `2*21` -> the answer is the first result, selected, above apps and files -> ↩ copies it and hides the launcher; ⌘↩ copies it, hides, and pastes it into the app you were in. `=` before the query adds functions (`=sqrt(16)`) and the constants `pi` and `e`. Esc clears the query as always.
- Surface: one result row at the top of the list (inline answer to the query)
- States: `=` alone -> hint "Type a calculation"; a number alone (`2048`), an unfinished sum (`2*`) or `1/0` -> no answer row, the usual results and fallbacks; no Accessibility permission -> ⌘↩ still copies
- Words: the row's title is the answer with thousands grouped (1.234.567,5), the copy has no grouping (1234567,5); subtitle "↩ copies the answer, ⌘↩ pastes it"; VoiceOver kind "Calculation"
- Numbers: the macOS decimal separator, and a point always works too; no Settings tab yet
- Access: ↩ and ⌘↩ from the keyboard; the row reads "Calculation, 42"
Status: done

### S-016 Use and add custom web searches
As the user, I type `wiki alfred` to search a site, and add my own search with a URL template containing `{query}`.
Screens: 09-features-web-search-search.png
Depends: S-006
Acceptance:
- [snap] Table: keyword, title, enabled, built-in lock; filter field; "Add Custom Search".
- [unit] A disabled keyword falls through to the fallbacks (as in 59).
UX:
- Flow: type `wiki alfred` -> "Search Wikipedia for “alfred”" is the first result -> ↩ opens it in the browser. Part of a keyword (`wik`) offers "Search Wikipedia for “…”" among the apps; ↩ completes it to `wiki `. The keyword and a space alone open the site's front page. A search without {query} ("Open Gmail") opens on its keyword. Settings > Web Search -> Add Custom Search… -> sheet with Title, Keyword, URL -> Add (Return) or Cancel (Esc) -> the row appears, selected; double-click or Edit… changes it, − or Remove takes it out.
- Surface: a Settings tab "Web Search" between Search and Actions (a list of settings); the add and edit form is a sheet (one short task)
- States: no custom searches -> "No custom searches"; filter with no match -> "No searches match “x”"; Add with a problem -> red text under the fields ("Type a title.", "Type a keyword.", "A keyword is one word, without spaces.", "“in” is already the keyword for Search inside files.", "Type a URL that starts with https://."); a search that is off -> its keyword is an ordinary query
- Words: tab "Web Search"; sections "Custom Searches" and "Built-in Searches"; "Add Custom Search…", "Edit Custom Search", "Only show enabled searches"; lock tooltip "Built in: you can switch it off, not change it"; completion subtitle "Press ↩ to type the words to search for"
- Built-ins: Alfred's list with SF Symbols; on at first: Apple Maps, translate, wiki, amazon, imdb, linkedin, youtube, wolfram. The fallbacks (Google, Amazon, Wikipedia) come from the same list, on or off.
- Access: every checkbox reads the search's title and keyword; the sheet works from the keyboard
Status: done

### S-017 Open typed URLs and keep a URL history
As the user, I type `example.com` and ↩ opens it; URLs I opened before come back as results.
Screens: 10-features-web-search-urls-history.png
Depends: S-006
Acceptance:
- [unit] Bare domains get the default scheme; history entries expire after the chosen period.
- [snap] History table with URL and last accessed, plus Clear.
UX:
- Flow: type `example.com` -> "https://example.com" is the first result, selected -> ↩ opens it and the URL history remembers it -> later, typing any part (`exam`, `docs`) finds it among the apps, ranked with Learning. Settings > Web Search -> URLs -> filter, select a URL and − or Remove, or Clear… -> "Clear URL History?" with Clear and Cancel.
- Surface: a segmented "Searches | URLs" switch at the top of the Web Search tab (one page per topic, no extra tab); Clear… is a confirmation dialog (destroys data that cannot come back)
- States: no history -> "No URLs yet"; filter with no match -> "No URLs match “x”"; Recognize URLs off -> a domain is an ordinary query; history off -> nothing new is remembered, history rows are hidden; a URL not opened within the period goes at launch, on the next opened URL, or when the period changes
- Words: "Recognize URLs", "Scheme for a domain typed without one" (https, http), "Treat URL schemes without // as URLs", "Remember URLs you open from Reach", "Remove a URL when not used for" (1 Week, 1 Month, 3 Months, 1 Year, Never), "Clear…"; typed row subtitle "Open this URL"; history row shows the URL without https://, the full URL under it
- What counts: a scheme with //, `localhost:port`, an IPv4 address, or a domain ending in a common top-level domain; endings that are also file extensions (md, sh, py, rs, zip, mov) need https:// typed
- Access: VoiceOver kinds "URL" and "URL from your history"; − and Clear… have tooltips
Status: done

### S-018 Choose and order fallback searches
As the user, I pick which searches appear when nothing matches, and in which order.
Screens: 02-features-default-results.png
Depends: S-016
Acceptance:
- [snap] Fallbacks sheet with a reorderable list.
- [unit] The setting "only when there are no results" is respected.
UX:
- Flow: Settings > Search > Fallbacks -> Show fallbacks picker (Only when there are no results, Always, below the results) -> "Edit Fallbacks…" -> sheet: drag, Move Up/Down, + adds any web search that takes words, − removes, Reset -> Done; the launcher and the selected-text actions follow the list
- Surface: section under Search Scope (changes values on screen); sheet "Edit Fallbacks" (one short task: a reorderable list)
- States: empty list "No fallbacks: a query without results shows nothing."; Always shares the nine rows, results first; a removed custom search drops out
- Words: "Show fallbacks", "Web searches" with "Google, Amazon, Wikipedia" under it, "Edit Fallbacks…", "Reset" with tooltip "Put back Google, Amazon and Wikipedia"
- Access: Return closes the sheet (Done); the chevron buttons and context menu move rows without dragging
- Snapshots: settings-search-end-<mode>.png, settings-fallbacks-<mode>.png
Status: done

### S-019 Run system commands by keyword
As the user, I type `sleep`, `lock`, `emptytrash`, `restart` or `eject` and run it; dangerous ones ask for confirmation.
Screens: 63-alfred-system-command.png, 25-features-system.png
Depends: S-002
Acceptance:
- [snap] System page: rows with checkbox, keyword field and Confirm checkbox.
- [self] Confirm-flagged commands show a confirmation row before running.
- [unit] Commands and apps are mixed in one ranked list.
UX:
- Flow: type a keyword or part of a title (`sleep`, `shut`) -> the command ranks among the apps -> ↩ runs it and the launcher hides; with Confirm on, ↩ shows one row "Restart your Mac?" -> ↩ runs, Esc or typing goes back to the results
- Surface: rows in the launcher (one more kind of result); the confirmation replaces the results in place (keeps the keyboard flow, no alert); Settings > System tab (a place people come back to)
- States: `eject` lists each disk, `eject us` picks one; "No disks to eject" when there are none, Eject All then hides; a failed command shows "Unable to run “Toggle Mute”." under its row
- Words: Alfred's set; titles "Lock Screen", "Shut Down", "Toggle Mute"; sections Commands, Sound, Disks; "Confirm"; questions like "Empty the Trash?" with "↩ empties it, esc cancels"
- Defaults: every command on; Empty Trash, Log Out, Restart and Shut Down ask first
- Access: the Confirm checkbox reads "Confirm Restart"; keyword fields read "Keyword for Restart"; a keyword already in use shows why under the field
- Snapshots: launcher-system-<mode>.png, launcher-confirm-<mode>.png, settings-system-<mode>.png
- Later: Alfred's Eject scope picker and exclude list
Status: done

### S-020 Quit, hide or force-quit apps by keyword
As the user, I type `quit Safari` and the running app quits.
Screens: 25-features-system.png
Depends: S-019
Acceptance:
- [unit] Only running apps are offered after `quit`/`hide`/`forcequit`.
- [self] `quitall` asks for confirmation.
UX:
- Flow: `quit` lists the running apps, last used first -> `quit saf` narrows -> ↩ quits "Quit Safari"; `qui` offers "Quit…" and ↩ completes to `quit `; `forcequit safari` asks "Force “Safari” to quit?"; `quitall` asks "Quit every app but Finder?" -> ↩ quits them, Esc keeps them
- Surface: rows in the launcher with the app's icon; the confirmation row from S-019; Settings > System > Apps (Hide, Quit, Force Quit, Quit All)
- States: "No apps are running"; "No running app matches “xcode”"; an app that refuses to quit shows "Unable to run “Quit Finder”." under its row
- Words: "Quit Safari", "Hide Mail", "Force Quit…", "Press ↩ to pick a running app"
- Defaults: Force Quit and Quit All ask first; Quit All leaves Finder and Reach running; apps with unsaved work still ask for themselves
- Snapshots: launcher-quit-<mode>.png (sample apps, not the ones running), settings-system-<mode>.png
Status: done

### S-021 Run a shell command
As the user, I type `> ls -la` and ↩ runs it in my terminal app.
Screens: 58-alfred-terminal-prefix.png, 26-features-terminal.png
Depends: S-002
Acceptance:
- [snap] One row "Run command in Terminal".
- [self] The prefix and target terminal (Terminal or Ghostty) are configurable.
UX:
- Flow: `> ls -la` -> one row "Run command in Terminal" -> ↩ opens a new window in the terminal app and runs it -> the launcher hides; Esc or deleting the prefix goes back to a normal search
- Surface: one row in the launcher (no fallbacks, no other results); Settings > Terminal with Prefix and Application menus, as on Alfred's Terminal page
- States: the prefix alone shows "Type a shell command"; a terminal that does not open shows "Unable to open Terminal." under the row; apps that are not installed are left out of the menu, and the footer says they show up once installed
- Words: "Run command in Terminal", "Opens a new window and runs it", "Prefix", "Application", "Shell Commands"
- Defaults: prefix `>` (menu of > $ ! ; #, none can start a word); Terminal; Ghostty and iTerm when installed. The shell stays open after the command. Commands are not learned and not logged: they can hold paths and passwords
- Snapshots: launcher-shell-<mode>.png, settings-terminal-<mode>.png
Status: done

### S-022 Look up a word
As the user, I type `define <word>` and see the definition; `spell <word>` suggests spellings.
Screens: 60-alfred-dictionary.png, 17-features-dictionary.png
Depends: S-002
Acceptance:
- [unit] Definitions come from the macOS dictionary service.
- [self] ↩ opens Dictionary.app at the word.
UX:
- Flow: `define seren` -> the word and related words that have a definition, the first sense as the subtitle -> ↩ opens Dictionary.app at the word; `spell recieve` -> spellings -> ↩ copies one, ⌘↩ pastes it; `defi` offers "Define a Word…" and ↩ completes to `define `
- Surface: rows in the launcher above the other results; Settings > Dictionary (new tab after Terminal) with Spelling language and the two keywords, each with a checkbox
- States: the keyword alone shows "Type a word to define" / "Type a word to spell"; "No definition for “xqz”"; "No spellings for “xqz”"; a keyword that is taken shows why under its field
- Words: "Define a Word", "Spell a Word", "Spelling language", "Automatic", "↩ copies it, ⌘↩ pastes it", "Press ↩ to type a word"
- Defaults: `define` and `spell`, both on; Automatic follows macOS. Definitions come from the dictionaries ticked in Dictionary.app. Settings is 640 wide so nine tabs fit
- Snapshots: launcher-define-<mode>.png, launcher-spell-<mode>.png (sample words, the same on every Mac), settings-dictionary-<mode>.png
Status: done

### S-023 Show text in Large Type
As the user, I press ⌘L to show the query or the selected result in huge letters over the screen.
Screens: 66-alfred-large-type.png, 27-features-large-type.png
Depends: S-002
Acceptance:
- [snap] Dark rounded card, white text scaled to fit, centred on the screen with the mouse.
- [self] Esc or a click closes it.
UX:
- Flow: ⌘L shows the selected result (an answer or spelling, a shell command, a URL, else its title); ⌘⌥L shows the typed text -> the launcher hides -> Esc, a click, or another app closes the card
- Surface: a borderless card over the screen with the mouse, sized to the text (no window, no focus kept)
- States: a hint, fallback, or web search shows the query; an empty query shows nothing; short text gets letters up to 200 pt on a small card, long text shrinks to 64 pt and then wraps, within 90% of the screen
- Words: "Large Type", the action panel's "Show in Large Type"
- Access: Esc closes; VoiceOver reads "Large Type, <text>"
Status: done

### S-024 Find and email contacts
As the user, I type a name and see the contact; `email <name>` starts a mail to them.
Screens: 18-features-contacts-contacts.png, 19-features-contacts-email.png, 20-features-contacts-advanced.png
Depends: S-002
Acceptance:
- [snap] A contact card view in the bar (name, fields; ↩ copies a field).
- [unit] Name order and title follow the Advanced settings.
UX:
- Flow: type a name -> the contact row (name, company) -> ↩ or → shows its card in the launcher -> ↩ on a detail emails, opens the website, shows the address in Maps, or copies it; ⌘C copies any detail; ⌘O opens Contacts.app -> Esc goes back to the results. `email <name>` -> one row per address -> ↩ starts the email; `email <address>` emails it.
- Surface: the action panel, as a card (one input people repeat while they watch the result); settings in their own Settings > Contacts tab
- States: no access "Allow Reach to see your contacts" (after `email`, with a link to System Settings); keyword alone "Type a name to email"; no address "No contact named “x” has an email address"; part of the keyword offers "Email a Contact…"; a filter with no match "No details match “x”"
- Words: "Contact", "Card", "Filter details", "Open in Contacts", "Email a Contact", "Search contacts", "Show last name first", "Show title", "Show job title"
- Access: keyboard only; VoiceOver reads "Card for <name>", each detail with its kind and label, "Contact, <name>" on the preview
- Not now: Alfred's custom field actions, Gmail compose, file attachment subject lines, a Maps URL setting, the notes field (it needs a special entitlement from Apple)
Status: done

---

## M4 Clipboard and snippets

### S-025 Keep a clipboard history
As the user, I switch on history per type (text, images, file lists) with a retention period, and copied items are stored.
Screens: 12-features-clipboard-history.png
Acceptance:
- [unit] Items older than the retention are purged on launch and hourly.
- [unit] Items from ignored apps and concealed/auto-generated pasteboard types are never stored.
- [snap] Clipboard settings page with the three type cards.
UX:
- Flow: Settings > Clipboard -> tick Keep Plain Text, Keep Images or Keep File Lists -> pick how long (24 Hours, 7 Days, 1 Month, 3 Months) -> from then on each copy is kept; copying the same again moves it to the top; expired clips go at launch and every hour
- Surface: its own Settings tab with one card per kind (changes values in place); Settings is 720 wide so eleven tabs fit
- States: everything off at first, the menus disabled while their kind is off; Access says whether macOS allows, asks or denies reading the clipboard, with "Open System Settings…" unless it allows
- Words: "Clipboard", "Keep Plain Text", "Keep Images", "Keep File Lists", "Clip", footer "Reach keeps what you copy for the time you choose, then forgets it."
- Access: checkboxes and menus by keyboard; VoiceOver reads "Keep Images for, 24 Hours"
- Privacy: only the pasteboard's types are looked at until a kind is on and the copy is kept; private and machine-made types (nspasteboard.org) and password managers are skipped; the log names kinds and counts, never content
Status: done

### S-026 Browse and paste from the clipboard viewer
As the user, I press ⌥⌘C, filter my history and ↩ pastes the item into the front app.
Screens: 65-alfred-clipboard-viewer.png, 61-alfred-clipboard-keyword.png
Depends: S-025
Acceptance:
- [snap] Empty state: "All Snippets" row, a hint on the right, a footer hint.
- [snap] Filled state: list left, full preview right.
- [self] Auto-paste on ↩ when enabled; the used item moves to the top.
UX:
- Flow: ⌃⌥⌘C anywhere (⌥⌘C stays Alfred's for now), or type "clipboard" and ↩ on Clipboard History -> the launcher shows the viewer, newest clip selected -> type to filter by the whole text or the app -> ↩ pastes the clip into the app in front and it moves to the top; ⌘C only copies; ⌘1–9 pick a row; Esc clears the filter, then hides (or goes back to the results, from the row); ⌃⌥⌘C again hides
- Surface: the launcher panel in its browse layout, list left and preview right (a panel people type into and watch)
- States: empty "All Snippets" with "View all snippets and collections" on the right and "Type to filter clipboard and snippets" in the footer; history off adds "Turn On Clipboard History…" (opens Settings > Clipboard); a filter without clips "No clips match “x”"; filled rows show the first line, the time and, when selected, "From TextEdit"; the footer says when and from which app
- Words: "Clipboard History", "All Snippets", "Filter clipboard", "Paste on Return", "Show the clipboard viewer"
- Access: keyboard only; VoiceOver reads "Text, 12:14, Meeting notes, From Notes, result 2 of 5" and the preview text
- Snippets: ↩ on All Snippets opens the snippets window until S-029 adds collections
Status: done

### S-027 Exclude apps and limit clip size
As the user, I add apps whose copies are never stored and set a maximum clip size.
Screens: 14-features-clipboard-advanced.png
Depends: S-025
Acceptance:
- [unit] Default exclusions include password managers and Keychain.
- [snap] Ignore-apps list with +, −, Reset.
UX:
- Flow: Settings > Clipboard > Advanced -> + chooses an app in /Applications, or drop an app on the list -> its copies are no longer kept; select a row and − to keep its copies again; Reset brings back the password managers and Keychain Access only; Max Clip Size menu: 64k characters, 256k characters (standard), 1M characters, No Limit
- Surface: a second page in the Clipboard tab (History | Advanced, segmented like Web Search); S-028 adds Merging
- States: the list starts with nine password managers and Keychain Access, by name; an app that is not installed shows its name and "Not installed"; an empty list says "No apps"
- Words: "Advanced", "Paste on Return" (moved here), "Max Clip Size", "Ignore Apps", "No Limit", tooltips "Add an app whose copies are never kept", "Keep copies from the selected app again"
- Access: + and − are labelled; the list reads "Ignore Apps"
- Scope: the limit counts text only; images and file lists keep their own retention
Status: done

### S-028 Append to the last clip
As the user, I hold ⌘ and press C twice to append the selection to the last clipboard item.
Screens: 13-features-clipboard-merging.png
Depends: S-025
Acceptance:
- [unit] The separator setting is used; a sound plays when enabled.
- [snap] Merging tab, disabled while history is off.
UX:
- Flow: Settings > Clipboard > Merging -> turn on "Append with ⌘C twice" -> in any app select text, hold ⌘ and press C twice within half a second -> the text is added to the text clip before it, its own clip goes, the merged text is on the clipboard, Purr plays; ⌘V pastes it. Undo: the viewer still has the earlier clip under its merged text; turn the setting off to stop
- Surface: the Merging page between History and Advanced (changes values in place)
- States: the page is disabled while Keep Plain Text is off, with "Turn on Keep Plain Text on the History page to append to the last clip."; the three options are disabled while Append is off; Access says whether Reach may see ⌘C, with "Open System Settings…"
- Words: "Merging", "Append with ⌘C twice", "Put the merged text on the clipboard", "Separator" (Separate with a Space, a New Line, a Blank Line, No Separator), "Play a sound when appending"
- Defaults: Append off; Put on the Clipboard on (Alfred has it off); Space; sound on
- Privacy: a global key monitor runs only while Append is on; it looks at ⌘C and ⌘ only, never other keys, and takes no key away from the app; copies from ignored apps are never appended
Status: done

### S-029 Create a snippet collection and snippets
As the user, I create a collection and add snippets with a name, keyword and text.
Screens: 15-features-snippets-empty.png
Acceptance:
- [snap] Empty state with "+" in both panes.
- [snap] Filled state: collections left, Name | Keyword | Snippet table right.
- [unit] Snippets persist and can be searched by name or keyword.
UX:
- Flow: All Snippets in the clipboard viewer, or the Reach window -> sidebar + names a new collection in a sheet (Return creates, Esc cancels) -> table + or ⌘N adds "New Snippet" to the selected collection and selects it -> the editor on the right edits Name, Keyword, Collection and the text; changes save as you type; ⌘Z undoes
- Surface: sidebar page per collection plus All Snippets (a place people come back to); editor as an inspector column (details of the selection); confirmation dialog only for deleting a collection with snippets
- States: no collections "No Collections"; an empty collection "No Snippets" with "Add Snippet"; nothing selected "No Snippet Selected"; a keyword another snippet has shows an orange warning with an icon; long names truncate
- Words: "All Snippets", "Collections", "New Collection", "Rename Collection", "Rename…", "Delete…", "Add Snippet", "Name | Keyword | Snippet", "Delete “Work” and its 5 snippets?" with "You can undo this with ⌘Z."
- Access: + and − are labelled with tooltips; the table reads its columns; the whole flow works from the keyboard
- Scope: Starred is gone; a keyword has no spaces; snippets without a collection move into "Snippets" at launch
Status: done

### S-030 Paste a snippet from the launcher
As the user, I type `snip <name>` and ↩ pastes the snippet.
Screens: 62-alfred-snippets-keyword.png
Depends: S-029
Acceptance:
- [self] The snippet text is pasted into the front app; `{date}` and `{clipboard}` placeholders are filled in.
UX:
- Flow: type `snip` (or `sni`, ↩ on "Paste a Snippet…") -> every snippet by name; `snip <name or keyword>` finds one, a full keyword first -> ↩ pastes it into the app in front -> the clipboard from before comes back; in the clipboard viewer, typing also finds snippets below the clips, ↩ pastes
- Surface: rows in the launcher (results people pick from), like `email`
- States: no snippets "No Snippets" with "Add snippets in the Reach window"; no match "No snippet matches “x”"; a row shows the first line and the snippet keyword
- Words: "Paste a Snippet…", "Press ↩ to type a name", footer "Snippet in Work"; placeholders `{date}` (29 Oct 2026), `{time}` (14:05), `{clipboard}`
- Access: VoiceOver reads "Snippet" before the name; ⌘1–9 pick a row
- Scope: the pasted text is marked transient, so Clipboard History never keeps it; a copy made right after the paste is not overwritten
Status: done

### S-031 Expand snippets automatically while typing
As the user, I type a snippet keyword in any app and it is replaced by the snippet.
Screens: 15-features-snippets-empty.png
Depends: S-029
Acceptance:
- [self] Expansion works in TextEdit and Safari; it is off by default and needs Accessibility permission.
- [manual] No expansion in password fields.
UX:
- Flow: Settings > Snippets > Expand keywords while typing (off at first) -> allow Accessibility if asked -> type a keyword at the start of a word in any app -> as its last letter lands, the keyword is deleted and the snippet pasted -> the clipboard from before comes back
- Surface: a Settings tab of its own, "Snippets" (rare setting, with room for more snippet options)
- States: without Accessibility the Access row says where to allow it, with "Open System Settings…"; in the editor, a keyword another keyword starts with warns "“zad” expands first while typing, so this keyword never does."
- Words: "Expansion", "Expand keywords while typing", footer "Never in password fields or in Reach. Pick keywords you do not type by accident, like “;sig”."
- Access: the toggle reads its title and description; the warnings carry an icon, not only orange
- Scope: case counts; a click, an arrow key, a shortcut or another app starts over; secure input (Terminal, password prompts) and AXSecureTextField fields never expand; no Ignore Apps list yet
Status: done

---

## M5 Look and system

### S-032 Pick a theme
As the user, I choose a light or dark theme from a list and see it live on a mock launcher.
Screens: 38-appearance-themes.png, 40-appearance-preview-on-wallpaper.png
Depends: S-002
Acceptance:
- [snap] Theme list with thumbnails; preview mock with a query and result rows.
- [self] The background toggle shows the preview over the desktop picture.
- [unit] The chosen theme applies to the real bar immediately.
UX:
- Flow: Settings > Appearance -> click a theme -> the preview and the real bar change at once -> Show on Desktop Picture puts the preview on the desktop picture or the plain background
- Surface: inline on the Appearance tab (changes one value on screen): preview on top, the six themes below, the accent color last
- States: no desktop picture readable -> the plain background; a saved theme that is gone -> Reach
- Words: themes "Reach", "Reach Light", "Reach Dark", "Clear", "Solid Light", "Solid Dark", each with a line like "Glass, follows the Mac"; section "Theme"; toggle "Show on Desktop Picture"; tooltip "Use the Reach Dark theme for the launcher"
- Access: each thumbnail is a button with its name and summary and the selected trait; the preview reads "Preview of the Reach theme"; the selection shows as a ring and the trait, not only color
- Scope: a theme is a mode (follows the Mac, light, dark) and a surface (glass, clear glass, solid); the accent color stays apart and goes with every theme; snapshots and the self-test draw a sample picture, never the real desktop picture
Status: done

### S-033 Make my own theme
As the user, I duplicate a theme and change its colours, font and corner radius.
Screens: 38-appearance-themes.png
Depends: S-032
Acceptance:
- [self] Clicking a part of the preview opens the colour/font editor for that part; built-in themes are read-only.
UX:
- Flow: Settings > Appearance -> Duplicate Theme (or Duplicate in a thumbnail's context menu) -> the copy is picked -> click the background, the search field or the results in the preview -> a popover with that part's settings -> each change shows in the preview and the bar at once -> click outside to close
- Surface: popover from the preview (a few related choices tied to one control); Rename Theme is an alert with a field
- States: a built-in theme's popover says "Reach Light is built in" with "Duplicate to Edit"; an unset color says "Uses the system color" or "Uses the accent color"; sizes stay in range; a deleted picked theme leaves Reach picked, ⌘Z brings it back
- Words: "Duplicate Theme", "Duplicate", "Rename…", "Delete", "Undo Delete Theme", "Duplicate to Edit"; popover sections "Background" (Appearance, Surface, Tint, Corners), "Search Field" (Font, Size, Text color), "Results" (Selection color, Font, Size, Text color); copies are named "<name> Copy"; footer "Click a part of the preview to change it."
- Access: each part is a button "Change the search field" with a tooltip; hover outlines it with a dashed accent line; the selection text turns black or white by contrast
- Scope: one font for the whole bar; no import or export of themes yet; the self-test checks the store and the bar, not the click itself (snapshots show both popovers)
Status: done

### S-034 Tune the bar's behaviour and position
As the user, I set the number of visible results, subtext mode, hidden shortcuts, and which screen the bar shows on.
Screens: 39-appearance-options.png
Depends: S-032
Acceptance:
- [snap] Options sheet with both columns.
- [unit] Visible results 3–9; "show on" default/mouse/active screen.
UX:
- Flow: Settings > Appearance -> Launcher Options… -> a sheet: Results on the left, Position on the right -> each change applies to the next query or show -> Done or Escape closes it
- Surface: sheet (a few related settings people set once, tied to one button), two columns like the reference
- States: Visible results is a menu of 3 to 9, so no wrong value can be typed; Active Screen without a window in front uses the mouse screen; the sketch draws the bar on the screen the choice picks
- Words: "Launcher Options…", sections "Results" and "Position"; "Visible results"; "Show subtext" with "Always", "Selected Row Only", "Never"; "Hide result shortcuts" ("The keys still work."); "Show on" with "Mouse Screen", "Main Screen", "Active Screen"
- Access: every control has a label and a description; the sketch reads "The launcher shows on the left screen"; Done is the default button
- Scope: "default screen" became Mouse Screen, how Reach always worked; no saved drag position yet; always-on subtext leaves the short browse rows alone
Status: done

### S-035 Hide the menu bar icon
As the user, I hide the menu bar icon and still reach Settings by typing `settings` in the bar.
Screens: 39-appearance-options.png, 48-menubar-status-menu.png
Depends: S-007
Acceptance:
- [unit] The hidden state persists; the keyword always works.
UX:
- Flow: Settings > Appearance -> Launcher Options… -> "Show menu bar icon" off -> the icon goes at once; Settings stays reachable by typing `settings` (or `pref`, `reach`) in the bar, ⌘, in the bar, or opening Reach again from Finder or Spotlight
- Surface: a toggle in its own "Menu Bar" section of the Launcher Options sheet; a pinned "Reach Settings" row in the launcher
- Words: "Show menu bar icon" ("Without it, type “settings” in the launcher, press ⌘, there, or open Reach again to reach Settings."); row "Reach Settings", "Open Settings (⌘,)"
Status: done

### S-036 Search Settings
As the user, I press ⌘F in Settings, type a word and jump to the page with that setting.
Screens: 46-help.png
Depends: S-007
Acceptance:
- [snap] A results list under the search field.
- [unit] Every settings label is indexed.
UX:
- Flow: ⌘F (or click the field) -> type -> the sidebar lists matching settings -> click one, or Return for the first -> its page shows on the right
- Surface: the system search field at the top of the Settings sidebar; results replace the pages while it has text
- States: empty field shows the pages; no match shows "No Results for …"; clearing the field brings the pages back
- Words: "Search Settings"; each result shows the label, with "Page › Section" under it
- Access: Edit > Search Settings ⌘F, only while Settings is in front; a page's name and summary words also match
Status: done

### S-037 Navigate Settings with the rail and menu bar
As the user, I move between Settings pages with the left icon rail and the menu bar.
Screens: 01-general.png, 02-features-default-results.png
Depends: S-007
Acceptance:
- [snap] Icon rail with labels; Features shows a second column with icon, title and subtitle per feature.
- [self] Menu bar: Close ⌘W, Search ⌘F, Filter Workflows ⇧⌘F, standard Edit/View/Window menus.
UX:
- Flow: ⌘, -> Settings opens on the last page -> click a page in the sidebar -> the page shows on the right with its name as the window title
- Surface: the Settings window becomes a sidebar window, like System Settings: General and Appearance at the top, the features under a "Features" heading with a summary line each (the reference's second column folded into the sidebar, the native way)
- States: a fixed window of 900 × 632 that can grow; a page taller than the window scrolls with a system scroll bar
- Words: page names as before; summaries like "Apps, files and fallbacks", "History and merging"
- Access: each sidebar row is a label with its summary as help
- Scope: Search ⌘F comes with S-036, Filter Workflows ⇧⌘F with S-042
Status: done

### S-038 Advanced: clear knowledge, query history, alternative actions
As the user, I clear what the app learned (Learning), restore my last query with ⌃↑, and choose what ctrl↩ / ⌥↩ / ⌘↩ do.
Screens: 43-advanced.png
Depends: S-004
Acceptance:
- [unit] Clear Learning empties the ranking store.
- [self] ⌃↑/⌃↓ walk the typed-query history; the last query returns within 5 minutes when enabled.
- [unit] Modifier+↩ runs the mapped fallback action.
UX:
- Flow: Settings > Advanced → Clear Learning… → confirmation "Clear what Reach learned?" → Clear Learning. In the launcher: ⌃↑ / ⌃↓ put earlier queries in the field; ⌃↩ / ⌥↩ / ⌘↩ run the web search chosen per key with the typed text
- Surface: a Settings tab (one grouped Form); a confirmation dialog for the clear, since it cannot be undone
- States: Clear Learning… is disabled with "Nothing learned yet."; an unmapped key keeps what Return did before; Restore is off unless the history is on
- Words: "Learning", "Query History", "Remember typed queries", "Restore the last query", "Alternative Actions", "Nothing"
- Access: each key picker is labeled with its key symbol; the toggles have a description line
- Note: the Learning store lives in the app, so its clear is checked in the self-test, not a unit test
Status: done

### S-039 Sync settings through a folder
As the user, I point Settings to an iCloud Drive folder so another Mac uses the same setup.
Screens: 43-advanced.png
Acceptance:
- [unit] All settings, snippets, themes and workflows live under that folder; the window has Set folder and Reveal buttons.
UX:
- Flow: Settings > Advanced > Sync → Set Folder… → choose a folder (iCloud Drive) → an empty folder gets this Mac's setup; a folder with a setup is read, and an alert offers "Restart Now" so every setting is read again. Reveal shows `<folder>/Reach` in Finder; Stop Syncing keeps the files
- Surface: a section in the Advanced tab; the system open panel picks the folder
- States: not set = "Not syncing. Settings, snippets, themes and workflows stay on this Mac."; set = the path, Reveal and Stop Syncing; a write failure shows under the folder
- Words: "Sync", "Sync folder", "Set Folder…", "Reveal", "Stop Syncing", "Restart Now", "Later"
- Note: settings and themes go to `Reach/Preferences.plist`, snippets to `Reach/Snippets.json`, workflows to `Reach/Workflows/`. At launch a folder newer than this Mac's last sync is read first; changes are written 2 s later. The folder setting itself and window places stay per Mac
Status: done

### S-040 See how much I use the launcher
As the user, I open Usage and see a 28-day stacked chart by kind of use.
Screens: 45-usage.png
Depends: S-003
Acceptance:
- [snap] Summary line and stacked area chart with a legend.
- [unit] Counts are stored per day and category.
UX:
- Flow: Settings > Usage → the summary and the chart; Copy Stats puts the summary and 28 tab-separated day lines on the clipboard
- Surface: a Settings page under Advanced (one grouped Form)
- States: nothing counted = "Nothing counted yet. Each result, action, clip and snippet you use counts." with Copy Stats disabled; quiet days show as zero
- Words: "Usage", "Copy Stats", "Last 28 Days"; kinds Launcher, Actions, Clipboard, Snippets, Expansion
- Access: the chart reads "Uses per day for the last 28 days, by kind"; the legend names each color
- Note: counts stay on this Mac (`usage.` keys are not synced), and days older than 400 are dropped
Status: done

---

## M6 Workflows (light)

A personal version of the workflow system: script-backed keywords, not the full node editor.

### S-041 Run a script filter from a keyword
As the user, I install a workflow folder whose keyword runs a script that returns results as JSON, and I can pick one.
Screens: 64-alfred-workflow-script-filter.png, 32-workflows-object-config-sheet.png
Depends: S-002
Acceptance:
- [unit] Accepts the Script Filter JSON format (items with title, subtitle, arg, icon, valid, mods).
- [self] The placeholder title and "please wait" text show while the script runs.
UX:
- Flow: copy a workflow folder (Alfred's `info.plist` format) into the Workflows folder → type its keyword → part of the keyword offers the workflow and ↩ completes it → type text after the keyword → the placeholder row with its running subtext (else "Please wait…") → the script's rows replace it → ↩ runs the objects connected to the filter (Open URL, Open File, Reveal, Run Script, Copy to Clipboard, Large Type); ⌃↩ ⌥↩ ⌘↩ use the row's `mods` or the matching connection line
- Surface: rows in the launcher, pinned above ranked results, with the workflow's name as kind label and its icon.png
- States: keyword typed without required text = the placeholder row, not openable; script running = placeholder + "Please wait…"; script fails or prints no JSON = the placeholder with the first error line and a warning symbol; a row with `valid: false` and `autocomplete` completes the query
- Words: "Please wait…", "Nothing in <workflow> uses this result.", "This workflow is no longer installed.", "Reach does not run this script language."
- Note: scripts run off the main thread with Alfred's `alfred_*` environment variables, and a new query stops the old script. Languages: bash, zsh, ruby, perl, python3, osascript (AppleScript, JavaScript) and an external file. Filters that let Alfred filter run once per launcher opening and Reach filters their rows. The Workflows folder is in Application Support/Reach, or in the sync folder (S-039)
Status: done

### S-042 List, filter, enable and remove workflows
As the user, I see my workflows in Settings, filter them, switch one off or remove it.
Screens: 29-workflows-home.png
Depends: S-041
Acceptance:
- [snap] List with icon, name and author; filter field; +, −; empty canvas with start cards when nothing is selected.
- [unit] Removing moves the workflow folder to the Trash.
UX:
- Flow: Window > Workflows (⇧⌘K), the menu bar icon's "Workflows…", or Settings > Workflows > "Open Workflows…" → the Workflows window: workflows by name on the left, the selected one on the right → + (Install Workflow… ⌘O) takes a workflow folder or an .alfredworkflow file → the switch, the context menu or Workflow > Turn Off Workflow (⇧⌘D) switches one off → − or Remove Workflow… (⌘⌫) asks, then moves the folder to the Trash
- Surface: its own window (a sidebar list with a filter field and +/− below, a detail pane), not a Settings tab, since S-044 puts a canvas there; Settings > Workflows has the count and the folder
- States: no workflows = "No Workflows" in the list and three start cards (Install Workflow…, Add Example, Open Workflows Folder); nothing selected = the start cards; a filter that finds nothing = the system search empty state; switched off = the row dimmed with "Off", and its keywords answer nothing
- Words: "Install Workflow…", "Add Example", "Filter Workflows", "Turn Off Workflow", "Move “<name>” to the Trash?", "Its keywords stop working. You can put it back from the Trash."
- Note: switching off writes `disabled` into info.plist, as Alfred does. Add Example installs "Hello World" (keyword `hello`, a bash script filter, ↩ copies and ⌘↩ searches the web)
Status: done

### S-043 Fill in a workflow's settings
As the user, I open "Configure Workflow…" and fill in the fields the workflow asks for, next to its README.
Screens: 33-workflows-user-configuration.png, 35-workflows-info-configuration-builder.png
Depends: S-042
Acceptance:
- [snap] Generated form left, rendered README right; required fields show an inline error.
- [unit] Values are passed to scripts as environment variables.
UX:
- Flow: select a workflow → "Configure Workflow…" in its header, its context menu, or Workflow > Configure Workflow… (⌘E) → a sheet: the fields on the left, the README on the right → fill in → Save; Reset to Defaults puts every field back
- Surface: a sheet on the Workflows window; the button and menu item show only for a workflow with fields
- States: a required field that is empty = a red "<Label> is required." under it and Save disabled; no README = "No README"; field kinds: text field, text area, checkbox, pop-up button, file picker (Choose…)
- Words: "Configure “<name>”", "Scripts get each value as an environment variable.", "Reset to Defaults", "Cancel", "Save"
- Note: fields come from Alfred's `userconfigurationconfig`; values live in the folder's prefs.plist, as Alfred keeps them, and only values that differ from the default are written. A value wins over a workflow variable of the same name
Status: done

### S-044 See a workflow's objects and connections read-only
As the user, I select a workflow and see its objects and connections on a canvas.
Screens: 30-workflows-editor-canvas.png, 31-workflows-palette-inputs.png
Depends: S-042
Acceptance:
- [snap] Coloured object cards per category and curved connection lines.
UX:
- Flow: select a workflow in the Workflows window → its canvas fills the detail pane below the header → scroll to see more; hover a card for its full text
- Surface: the detail pane of the Workflows window; read only, nothing to drag or connect (the full editor is under Later)
- States: no objects = "No Objects"; a card is colored by category (trigger red, input purple, action blue, utility gray, output green) with its kind ("Script Filter") and what it does (keyword, URL, text, first script line); a line with a key held shows ⌃ ⌥ ⇧ ⌘ halfway along
- Words: "No Objects", "This workflow has nothing on its canvas."
- Note: cards sit where Alfred's uidata puts them; objects without a position go in columns by how many lines lead to them
Status: done

### S-045 Debug a workflow
As the user, I open the debugger and see a timestamped log of each run.
Screens: 37-workflows-debugger.png
Depends: S-041
Acceptance:
- [snap] Bottom panel with log level, Copy and Clear.
- [unit] Script stderr ends up in the log.
UX:
- Flow: select a workflow → Debugger in its header (⌥⌘D, Workflow > Show Debugger) → a panel opens under the canvas → type the keyword in the launcher → each run shows, newest at the bottom
- Surface: a panel at the bottom of the detail pane, not a window, so the canvas stays in view
- States: nothing run yet = "No Runs Yet"; a run line in the primary color, what the script printed in gray, errors and exit codes in red; Errors Only hides the rest
- Words: "All Information", "Errors Only", "Copy", "Clear", "Script Filter ran with “hello Ada”", "Run Script ended with exit code 127."
- Note: the log keeps the last 500 lines while Reach runs; it is not saved
Status: done

### S-046 Edit a workflow's README, version and variables
As the user, I edit the About text and version and add environment variables to a workflow.
Screens: 34-workflows-info-about.png, 36-workflows-info-environment-variables.png
Depends: S-042
Acceptance:
- [snap] Three-tab sheet; variables table empty state with +.
- [unit] "Don't export" variables are stripped on export.
UX:
- Flow: select a workflow → Info… in its header (⌘I, Workflow > Workflow Info…) → a sheet with About, README and Variables → Save; Workflow > Export Workflow… (⇧⌘E) saves an .alfredworkflow file to share
- Surface: a sheet over the Workflows window, tabs as a segmented control so their names fit
- States: no variables = "No Variables" with Add Variable; a bad or doubled name shows in red and disables Save
- Words: "About", "README", "Variables", "Name", "Value", "Don't Export", "Export Workflow…"
- Note: Export blanks the value of every Don't Export variable and leaves out what Configure Workflow… saved (prefs.plist)
Status: done

### S-047 Run a workflow from a Keyword input
As the user, I type the keyword of an imported Alfred workflow that starts with a Keyword input (not a Script Filter), and ↩ runs what is connected to it.
Screens: 64-alfred-workflow-script-filter.png
Depends: S-041
Acceptance:
- [unit] A Keyword input (`alfred.workflow.input.keyword`) is read with its keyword, space, argument, title and subtext, and matches like a Script Filter.
- [unit] A keyword written as `{var:name}` is filled from the workflow's variables and its configuration; one that stays empty adds no keyword.
- [unit] The typed text goes on to the connected objects, per modifier line.
- [self] Part of the keyword completes it; with the text typed, one row shows its title with `{query}` filled in; ↩ opens the connected URL.
- [unit] Scripts of type 11 (Alfred's default `/bin/zsh --no-rcs`) run.
- [unit] ↩ follows a Conditional (modes 0–4 from Alfred's help; 5 "is true" and 6 "is false" read from workflows that use them; other modes never match) down the line of the first matching condition, else the else line.
- [unit] Arg and Vars passes its variables on, also after a Run Script; Hide Alfred does nothing; Call External Trigger in the same workflow follows its External Trigger, and one that reaches a script filter or keyword shows the launcher with that keyword typed.
- [unit] The Automation Task "Move to Trash" (`path.trash`) trashes its filled-in `target_path` (the text when empty) and goes on with the objects after it; other Automation Tasks do not run.
- [self] ↩ that reaches the Trash task moves the filled-in path to the Trash.
- [self] ↩ through a Conditional and an External Trigger shows the keyword again with the text; ↩ that reaches an object Reach does not run says "Reach does not run <kind> yet." under the row and in the debugger.
UX:
- Flow: type the keyword → ↩ completes it → type the text → one row, the Keyword input's title with the text → ↩ (or ⌃↩ ⌥↩ ⌘↩ for a modifier line) runs the connected objects
- States: argument required and no text = placeholder row, not openable; argument none = the row runs on the keyword alone
- Note: the cause of "imported workflows do nothing": Reach only read Script Filters, and most Alfred workflows start with a Keyword input. Configurable keywords (`{var:keyword}`) never matched either. Hotkeys, List Filters, File Filters, Automation Tasks other than Move to Trash, Post Notification and triggers in another workflow still do nothing; Return on them now says so. Alfred's Purge Disk Images runs end to end: dmgeject detaches the image and trashes it, dmgtrash trashes the file, and both show their list again until the last one is gone.
Status: done

---

### S-048 Notifications, sounds and debug lines from a workflow
As the user, ↩ on an imported Alfred workflow that posts a notification, plays a sound or writes a debug line does that too, and goes on, so the workflows that only stopped there run.
Depends: S-047
Acceptance:
- [unit] Post Notification (`alfred.workflow.output.notification`) fills `title` and `text` with `{query}` and `{var:…}` (the workflow's name when the title is empty), uses only the file name or drops its extension when set, shows nothing without text when "only show if query populated" is on, and passes the argument on.
- [unit] Play Sound (`alfred.workflow.output.playsound`) plays the system sound `soundname`, or the file of that name in the workflow's folder when `systemsound` is off, and passes the argument on.
- [unit] Debug (`alfred.workflow.utility.debug`) writes its `argument` to the workflow debugger, with `{query}`, `{var:…}` and `{variables}` filled in, clears this workflow's lines first when set, and passes the argument on unless "process outputs" is off.
- [self] ↩ through Post Notification, Play Sound and Debug shows the text, plays the sound, logs the line and passes it on; the self-test records the notification and sound instead of posting or playing.
UX:
- macOS asks once whether Reach may post notifications. When that is off, the debugger says so; the rest of the workflow still runs.
Status: done

### S-049 Hotkeys from a workflow
As the user, a key combination I give an imported Alfred workflow's Hotkey trigger runs what is connected to it from any app, with the text Alfred would pass, so the workflows I start by hotkey work.
Depends: S-047
Acceptance:
- [unit] A Hotkey trigger (`alfred.workflow.trigger.hotkey`) is read with its argument (0 none, 1 the macOS selection, 2 the clipboard, 3 a fixed text), its "Show Alfred" action, its related apps and their mode, and Alfred's `hotkey` and `hotmod` when the info.plist has them.
- [unit] The argument is what Alfred would pass; any other kind, like 4 (the Find pasteboard), passes nothing and says which kind.
- [unit] A combination that is Reach's launcher, selection or clipboard hotkey, or that another hotkey took first, is skipped with the reason.
- [self] Workflow > Workflow Hotkeys… (⌥⌘K) sets a combination per trigger; it is registered at once, again on every read of the library, and taken off by Turn Off. A skipped one says why in the sheet and in the debugger.
- [self] An injected press runs the connected objects with no text, the selection or the clipboard; an argument Reach does not pass runs without it and is logged.
UX:
- Alfred leaves hotkeys out of an exported workflow, so the triggers start empty; the sheet says so. A combination another app owns stays off with that reason.
Status: done

---

## Later

- Full visual node editor: drag objects from the palette, connect, utilities (conditional, junction, transform) (30, 31).
- Music mini player and music keywords (21-features-music-general.png, 22-features-music-keywords.png, 23-features-music-advanced.png).
- Web bookmarks from Safari and Chrome (11-features-web-bookmarks.png).
- Custom actions on contact fields (18).
- Rich file thumbnails in the Preview instead of the file icon (28).

## Dropped

- 24-features-1password.png: third-party password manager integration (vendor integration).
- 41-remote-home.png, 42-remote-page-system-commands.png: iOS remote and its server (needs a second device and app).
- 44-powerpack.png: licence and upgrade page (vendor).
- 46-help.png: links to the vendor's docs, forum and bug tracker. Only the search-Settings entry point lives on in S-036.
- 47-update.png: changelog and update channel (handled by the build, not the app).

## Screen coverage

Each screen 01–66 is linked above, listed under Later or Dropped: 01 S-007/S-037 · 02 S-014/S-018/S-037 · 03 S-014 · 04 S-008 · 05 S-013 · 06 S-014 · 07 S-009/S-011 · 08 S-010 · 09 S-016 · 10 S-017 · 11 Later · 12 S-025 · 13 S-028 · 14 S-027 · 15 S-029/S-031 · 16 S-015 · 17 S-022 · 18 S-024 · 19 S-024 · 20 S-024 · 21–23 Later · 24 Dropped · 25 S-019/S-020 · 26 S-021 · 27 S-023 · 28 S-012 · 29 S-042 · 30 S-044 · 31 S-044 · 32 S-041 · 33 S-043 · 34 S-046 · 35 S-043 · 36 S-046 · 37 S-045 · 38 S-032/S-033 · 39 S-034/S-035 · 40 S-032 · 41–42 Dropped · 43 S-038/S-039 · 44 Dropped · 45 S-040 · 46 S-036 (rest Dropped) · 47 Dropped · 48 S-007/S-035 · 49 S-001 · 50 S-002/S-003/S-004 · 51 S-009 · 52 S-015 · 53 S-015 · 54 S-006 · 55 S-005 · 56 S-005 · 57 S-008 · 58 S-021 · 59 S-006/S-016 · 60 S-022 · 61 S-026 · 62 S-030 · 63 S-019 · 64 S-041 · 65 S-026 · 66 S-023.
