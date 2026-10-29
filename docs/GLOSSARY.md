# Glossary — Reach

Every on-screen name has exactly one entry here. The "Not" column lists words to avoid.

| Term | Means | Not |
| --- | --- | --- |
| Launcher | The floating bar you summon with the hotkey: search field plus results | Alfred window, popup, spotlight, prompt |
| Search field | The text field at the top of the launcher | query box, input, prompt |
| Query | What you typed in the search field | search term, input |
| Result | One row under the search field that you can open | item (that is one thing in the buffer), hit, entry, match |
| Selected result | The highlighted result that Return opens | active, focused, current row |
| Open | Run the default action of a result: launch the app, open the file or URL | launch, execute, action (as a verb) |
| Hotkey | The global key combination that shows or hides the launcher | shortcut (reserved for in-app keys), trigger |
| Show / Hide | Bring the launcher up or put it away | toggle (only in the menu item "Show Launcher") |
| Keyword | A word at the start of the query that picks a feature: `open`, `find`, `wiki` | prefix (only for single characters), command |
| File search | Finding files and folders by name through a keyword | Spotlight search, finder |
| Web search | Searching a website with the query, from a URL template with `{query}` | custom search, engine |
| Custom search | A web search you add yourself in Settings > Web Search | user search, own engine |
| Built-in search | A web search that comes with Reach; you can switch it off, not change it | default search, preset |
| Typed URL | A web address typed in the search field, like example.com; Return opens it | link, address bar |
| URL history | The URLs you opened from Reach, found again by any part of them | browsing history, recent URLs |
| Fallback | A web search for what you typed, shown when the query has no results (or always, below them), in the order of the fallback list | default search, backup |
| Edit Fallbacks | The sheet that picks and orders the fallbacks | fallback editor, configure |
| Learning | The launcher remembering which result you opened for a query and ranking it first | knowledge, latching, AI |
| Settings | The app's settings window | Preferences |
| Menu bar icon | The app's icon in the macOS menu bar, with its menu | status item, tray icon |
| Browse | Walk folders inside the launcher with → and ← after typing `~/` or `/` | navigate, explore, drill down |
| Path | A query that starts with `~/` or `/`: a folder, plus an optional name to filter it | location, directory string |
| Preview | The right side of the launcher while browsing: large icon, Created and Modified dates | inspector, detail pane (Quick Look is the full-size preview, S-012) |
| Selection | The files selected in Finder, or the text selected in any app, at the moment you press the selection hotkey | highlight, current item |
| Selection hotkey | The global key combination (⌃⌥⌘\\) that opens the action panel for the selection | universal action hotkey |
| Large Type | Text shown in huge letters on a dark card over the screen; ⌘L shows the selected result, ⌘⌥L the typed text | big text, fullscreen text |
| Action panel | The list of actions for the selected result, opened with → | context menu, actions view |
| Action | One thing the action panel can do with a result: Reveal in Finder, Copy Path, Move to Trash | command, operation |
| Move to Trash | Put a file in the Trash, where it can be put back | Delete (that cannot be undone) |
| Calculation | A query the calculator answers: `2*21`, or with `=` in front for functions like `=sqrt(16)` | sum, formula, expression (in UI text) |
| Answer | The calculator's result row; ↩ copies it, ⌘↩ pastes it | result value, output |
| Paste | Put the answer in the app you were in, as ⌘V does | type, insert |
| Reach | The app itself | Alfred, the launcher (that is the panel) |
| Quick Look | The system's full-size preview of the selected result, opened by tapping ⇧ or ⌘Y | preview (that is the launcher's right side), peek |
| Buffer | Files, folders and apps collected with ⌥↑ to run one action on all of them with ⌥→ | basket, cart, selection (that is S-011), stack |
| Item | One file, folder or app in the buffer; "3 Items" in the panel header | entry, element |
| Skip | Leave a file type or folder out of Quick Look and Preview dates, in Settings > Previews | exclude, ignore, blacklist |
| Search scope | The folders Reach looks in for apps and files, in Settings > Search | search paths, locations, index |
| Default results | What a query without a keyword shows: apps, plus the file types ticked in Settings > Search | normal results, global search |
| Don't Show | File kinds that file search keywords leave out, like Mail messages or plist files | hide, filter, exclude (Skip is for Previews) |
| System command | A macOS command run by keyword: Sleep, Lock Screen, Restart, Eject | system action, power command |
| Confirm | A system command setting: Return first shows a row that asks, a second Return runs it | prompt, are you sure |
| Eject | Unmount a disk and make it safe to unplug | unmount, remove |
| Running app | An app with a Dock icon that is open now; Hide, Quit and Force Quit list them, last used first | open app, process |
| Force Quit | End an app at once; its unsaved changes are lost | kill, terminate |
| Shell command | A command typed after the prefix (`> ls -la`) that runs in a new terminal window | terminal command, script |
| Prefix | The character that turns a query into a shell command, `>` at first, in Settings > Terminal | trigger, keyword (a keyword is a word) |
| Terminal app | The app shell commands run in: Terminal, Ghostty or iTerm | shell, console |
| Define | Look up what a word means in the macOS dictionaries; Return opens Dictionary.app at the word | definition, look up, meaning |
| Spell | Suggest how to write a word; Return copies the spelling | spell check, correct |
| Contact | A person or company from Contacts.app, found by name or company | person, address book entry |
| Card | A contact's details in the launcher: addresses, numbers, websites, birthday | contact viewer, details view |
| Detail | One line of a card, like an email address or phone number | field, entry |
| Email a Contact | The `email` keyword: `email <name>` lists each address, Return starts the email | mail, compose |
| Clipboard history | What Reach keeps of what you copy, per kind, for the time you choose | clipboard manager, pasteboard |
| Clip | One kept copy: text, an image, or a file list | item, entry, clipping |
| Retention | How long clips of one kind are kept: 24 Hours, 7 Days, 1 Month or 3 Months | expiry, lifetime |
| Clipboard viewer | The launcher showing your clips to filter and paste, from ⌃⌥⌘C or the Clipboard History row | clipboard window, history panel |
| Ignore Apps | Apps whose copies are never kept; starts with the password managers and Keychain Access | excluded apps, blacklist |
| Max Clip Size | The longest copied text that is kept | clip limit, size cap |
| Append | Add the text just copied to the clip before it, with ⌘C pressed twice | merge, concatenate |
| Separator | What goes between appended texts: a space, a new line, a blank line or nothing | delimiter |
| Paste on Return | Return in the clipboard viewer also pastes the clip into the app in front | auto-paste |
| Spelling language | The language Spell suggests words in, Automatic at first | dictionary language, locale |
| Snippet | A saved text with a name, pasted from the launcher (S-030) | template, text block, clip (a clip is copied) |
| Collection | A named group of snippets in the sidebar; every snippet is in one | folder, group, category |
| All Snippets | The sidebar page with the snippets of every collection | library, everything |
| Snippet keyword | A short word, without spaces, that finds or expands a snippet | abbreviation, shortcut, trigger (Keyword alone is a launcher keyword) |
| Placeholder | `{date}`, `{time}` or `{clipboard}` in a snippet, filled in when it is pasted | variable, token, macro |
| Paste a Snippet | The `snip` keyword: `snip <name>` lists snippets, Return pastes one | insert, expand (Expand is for S-031) |
| Theme | How the launcher looks: a mode (follows the Mac, light, dark) and a surface (glass, clear glass, solid) | skin, style, look |
| Accent color | The color of the selected row and of buttons, picked apart from the theme | tint, highlight, theme color |
| Show on Desktop Picture | Draws the theme preview on the desktop picture instead of the plain background | wallpaper, background toggle |
| Expand | Replace a snippet keyword typed in any app with its snippet, as its last letter is typed | auto-expand, autocomplete, text replacement |
