# Screen index — Alfred 5.8.1 (reference walk, 2026-10-28)

66 screenshots of the reference launcher. Two processes:

- **Launcher**: an agent app with no Dock icon. It has a floating search bar, an action panel, a clipboard/snippet viewer, Large Type and a status menu. Captured with `screencapture -R` on the window bounds (49–66) and on the menu region (48), because `window-shot.sh` does not see floating panels.
- **Preferences**: a normal window (1180×766 pt, later 1465×792 pt) with a fixed left icon rail. Captured per window (01–47).

The numbers follow capture order. The bar states (49–66) were captured after the preferences, so 49 comes after 48.

Notes from the walk:

- The user resized the Preferences window halfway (from 30 on). Nothing else changed.
- No settings were changed. Sheets were closed with Cancel. The theme list was **not** clicked, because clicking a theme makes it the active one.
- Not captured: dark mode (it would mean changing a system setting; see "Open" at the bottom), right-click menus on the workflow canvas (refused in background mode), and the preferences search results popover (does not render in the background).

---

## Shell (all Preferences pages)

Window chrome: a toolbar with a "Search Preferences" field at the top right (⌘F). A fixed purple icon rail on the left: General, Features, Workflows, Appearance, Remote, Advanced, then after a spacer Powerpack, Usage, Help, Update. The active item has a darker background. Each rail item is an icon with a small label below it.

The Features pages add a second column: a list of features, each row an icon, title and one-line subtitle. Each detail page has a header (large icon, title, one-line explanation, ?-help button top right). Many details have segmented tabs at the top.

---

## 01-general.png

Page: General. Reached from: rail > General (default page).
Layout: version label top left; one centred rounded card on a subtle patterned background.
Elements: Startup (checkbox launch at login + "Quit" button), Alfred hotkey recorder field (shows ⌥Space, modifier symbols greyed when inactive) + help button, location popup (country) + checkbox to use .com for searches, Permissions button that guides through macOS permissions.
Actions: record hotkey, toggle login item, quit launcher, request permissions.
Shortcuts seen: ⌥Space (show launcher).

## 02-features-default-results.png

Page: Features > Default Results. Reached from: rail > Features > first row.
Layout: grouped form rows.
Elements: Applications "Options…" button; Essentials checkboxes (Contacts, System Settings); Extras checkboxes (Folders, Documents, Text Files, Images, Archives, AppleScripts) + "Advanced…"; "search all file types" warning checkbox; Search Scope: checkboxes for the apps folder and home folders + an editable path list with +, −, Reset; Fallbacks popup ("only when no results") + "Setup fallback results" button.
Actions: choose what appears in default results, edit search scope, configure fallbacks.

## 03-features-file-search-search.png

Page: Features > File Search > Search tab. Tabs: Search / Navigation / Buffer / Advanced.
Elements: quick file search mode (prefix `'` or space); four keyword rows, each a checkbox + text field: open, find (reveal), in (content search), tags; "Don't show" type checkboxes (emails, contacts, bookmarks, history, music, images, calendar, source files, plist files, messages); default order popup; result limit popup (40).
Actions: enable/disable and rename keywords, exclude file types, sort order.

## 04-features-file-search-navigation.png

Page: File Search > Navigation.
Elements: fuzzy matching checkbox; ←/→ to move between folders; ↩ opens folders in Finder; "Previous path" hotkey recorder + keyword ("previous").
Actions: navigation behaviour settings.

## 05-features-file-search-buffer.png

Page: File Search > Buffer.
Elements: enable file buffer; legend of buffer keys (⌥↑ add/remove, ⌥↓ add and go to next, ⌥← remove last, ⌥→ act on all); clearing rules (after action, after 5 min idle); ⇧⌥ as alternative modifier.
Shortcuts seen: ⌥↑, ⌥↓, ⌥←, ⌥→.

## 06-features-file-search-advanced.png

Page: File Search > Advanced.
Elements: escape path on copy; run scripts instead of opening; generic icons on external drives; touch folders/aliases after opening; home-folder display popup + custom home folder path.

## 07-features-universal-actions-general.png

Page: Features > Universal Actions > General. Tabs: General / Actions.
Elements: which keys show the action panel (checkboxes →, fn, ctrl, ⇥); selection hotkey recorder (⌥⌘\) to act on the macOS selection; sort actions by last use.
Shortcuts seen: → / fn / ctrl / ⇥ (action panel), ⌥⌘\ (actions on selection).

## 08-features-universal-actions-actions.png

Page: Universal Actions > Actions.
Layout: left a scrolling checklist of built-in actions (checkbox, icon, name); right "Other actions" groups (workflow actions, web searches, workflow inputs), each with an explanation.
Elements: about 30 actions, among them Recent Documents, Show Package Contents, Open, Open with, Reveal in Finder, Get Info, Copy to, Move to, Delete, Copy/Move with Replace, Browse Folder, Open Terminal Here, Copy Path, Copy File, Add to Buffer, Open URL (in…), Copy/Paste as Plain Text, Save as Snippet, Open in Dictionary, Extract URLs, Show as Large Type.
Actions: enable/disable individual actions.

## 09-features-web-search-search.png

Page: Features > Web Search > Search tab. Tabs: Search / URLs-History.
Layout: filter field + "only show enabled" checkbox; table.
Elements: table columns: icon, keyword, lock (built-in), display text with `{query}` placeholder, custom flag, enabled checkbox. About 25 built-in engines. Footer "Add Custom Search" + −.
Actions: enable/disable engines, add/remove custom search.

## 10-features-web-search-urls-history.png

Page: Web Search > URLs/History.
Elements: recognise typed URLs + default scheme popup; treat `scheme:` without `//` as URL; store URL history; filter field; history table (URL | last accessed); auto-remove popup (1 month); Clear button.

## 11-features-web-bookmarks.png

Page: Features > Web Bookmarks.
Elements: sources (Safari, Chrome checkboxes); show bookmarks popup (in default results / keyword only); open-in popup (default browser / source browser).

## 12-features-clipboard-history.png

Page: Features > Clipboard History > History. Tabs: History / Merging / Advanced.
Elements: three small cards (plain text, images, file lists), each a checkbox + retention popup (24 hours / 7 days…); viewer hotkey recorder (⌥⌘C); viewer keyword ("clipboard"); clear keyword ("clear") + "Clear all history now"; snippets shown in the viewer; ignore items from other Apple devices.
Shortcuts seen: ⌥⌘C (clipboard viewer).

## 13-features-clipboard-merging.png

Page: Clipboard > Merging (disabled because history is off: shows the disabled state).
Elements: fast append (hold ⌘ + double C), write merged text back to the system clipboard, separator popup, sound on append.

## 14-features-clipboard-advanced.png

Page: Clipboard > Advanced.
Elements: diacritic-insensitive matching; auto-paste on ↩; move used item to top; convert images to PNG; max clip size popup; ignore-apps list (password managers, keychain) + / − / Reset; ignore concealed and auto-generated pasteboard types.

## 15-features-snippets-empty.png

Page: Features > Snippets. **Empty state** (no collections).
Layout: top settings row; right an "auto expansion" card; bottom split view: collections list | snippets table.
Elements: viewer hotkey (empty), keyword ("snip") + show keyword in result; matching popup (name or keyword) + word based; auto-expand checkbox + "Auto Expansion Options"; collection list with +, −, "Get Collections…"; snippet table (Name | Keyword | Snippet) with filter, +, −.
Actions: add collection, add snippet, import collections.

## 16-features-calculator.png

Page: Features > Calculator.
Elements: standard calculator checkbox; advanced calculator with prefix `=` and a list of functions; input decimal separator popup + ignore thousands separator; output separator popup + show thousands separator.

## 17-features-dictionary.png

Page: Features > Dictionary.
Elements: language popup + only words with a definition; "define" keyword; "spell" keyword; paste word on action.

## 18-features-contacts-contacts.png

Page: Features > Contacts > Contacts. Tabs: Contacts / Email / Advanced.
Elements: open contacts in the launcher's own contact viewer; custom actions table (Field | Action | Modifiers, empty) + / −; show notes field.

## 19-features-contacts-email.png

Page: Contacts > Email.
Elements: "email" keyword; open viewer when there are several addresses; compose via webmail; subject templates with `{filename}` and `{count}` placeholders.

## 20-features-contacts-advanced.png

Page: Contacts > Advanced.
Elements: last name first; show title; show job title; maps URL with `{query}`; Spotlight metadata toggle; custom URL handler with `{uid}`.

## 21-features-music-general.png

Page: Features > Music > General. Tabs: General / Keywords / Advanced.
Elements: mini player hotkey (⌃⌘↩) + keyword ("music"); random only larger albums; hide mini player after choosing; include playlists in search.

## 22-features-music-keywords.png

Page: Music > Keywords.
Elements: nine rows checkbox + keyword (play/pause, next, back, previous, random, volume max/mid, mute); show keywords in default results.

## 23-features-music-advanced.png

Page: Music > Advanced.
Elements: library XML path + Find (disabled); include untagged tracks, podcasts, videos; Reset library / Reset artwork; generated playlist name + suffix.

## 24-features-1password.png

Page: Features > 1Password.
Elements: info banner (integration moved to a workflow) + install button; deprecated bookmarks checkbox.

## 25-features-system.png

Page: Features > System.
Layout: two columns of keyword rows (checkbox + keyword + optional "Confirm").
Elements: screensaver, show/empty trash, log out, sleep, sleep displays, lock, restart, shut down; app commands hide, quit, force quit, quit all; volume up/down, mute; eject keyword + scope popup; eject all; exclude-volumes list + / − / Reset.

## 26-features-terminal.png

Page: Features > Terminal.
Elements: prefix popup (`>`); application popup (Terminal / custom script).

## 27-features-large-type.png

Page: Features > Large Type.
Elements: background fit popup + Font…; large live preview; auto-hide launcher when showing; show on mouse screen.

## 28-features-previews.png

Page: Features > Previews.
Elements: ⇧ = Quick Look; rich file previews; "no previews for" type list (empty) + / −; "no previews in" path list (empty) + / −.
Shortcuts seen: ⇧ / ⌘Y (Quick Look).

## 29-workflows-home.png

Page: Workflows, nothing selected. Reached from: rail > Workflows.
Layout: workflow list column (filter field, configure button, rows of icon + name + "by author"); bottom bar (Gallery, Help, +, −); dark canvas with five start cards (gallery, getting started, new workflow, from template, documentation); debugger status bar at the bottom.
Actions: filter, add, remove, open gallery, create.
Shortcuts seen: ⇧⌘F (filter workflows).

## 30-workflows-editor-canvas.png

Page: Workflows > a selected workflow (editor).
Layout: header (icon, name, "Configure Workflow…" button, subtitle + version); toolbar icons top right (variables/info, open folder, export, debugger, palette); node canvas; object palette on the right; hint bar "type / to search the palette".
Elements: coloured object cards by category (trigger, input, action, utility, output), each with an icon, type label and keyword/subtitle; coloured curved connection lines; small junction/modifier markers on the lines.
Actions: drag objects, connect, double-click to configure, toggle palette/debugger, export.

## 31-workflows-palette-inputs.png

Page: Workflow editor, palette with "Inputs" expanded.
Elements: collapsible categories (Getting Started, Prefabs, Favourites, Triggers, Inputs, Actions, Automations, User Interface, Utilities, Outputs). Each object row: icon + name + favourite star. All categories were expanded once (see the data model below).

## 32-workflows-object-config-sheet.png

Page: Script Filter configuration sheet (double-click an object).
Elements: keyword + "with space" + argument popup (required/optional/none); placeholder title, subtext, "please wait" subtext; icon drop well; language popup, input mode popup, run behaviour button, "launcher filters results" checkbox; script file path + Open File; monospaced script view; help, folder, Cancel, Save.

## 33-workflows-user-configuration.png

Page: Configure Workflow sheet (end-user setup).
Layout: left a form generated from the workflow's config definition; right the README rendered as rich text.
Elements: text fields with label + help text, required field marked with an inline error, checkbox groups, keyword fields; Reset to Defaults, Cancel, Save.

## 34-workflows-info-about.png

Page: Workflow info sheet > About tab. Tabs: About / Configuration Builder / Environment Variables.
Elements: large markdown editor (README); version field; help, Cancel, Save.

## 35-workflows-info-configuration-builder.png

Page: Workflow info > Configuration Builder.
Elements: a stack of collapsible item cards (type such as Text Field; `{var:name}` token, copy, move up/down, remove). Each card: variable, label, description | default, trim, placeholder, required. Footer: Collapse All, Expand All, Preview, +.

## 36-workflows-info-environment-variables.png

Page: Workflow info > Environment Variables. **Empty state.**
Elements: table Name | Value | Don't Export; + / −; explanation of `{var:name}`.

## 37-workflows-debugger.png

Page: Workflow editor with debugger open.
Elements: bottom panel; toolbar (status "running · name", log level popup, scope popup, "selected objects only", Copy, Clear); timestamped log lines.

## 38-appearance-themes.png

Page: Appearance. Reached from: rail > Appearance.
Layout: theme list (thumbnail, name, author line) | large preview area showing a **live mock of the launcher**.
Elements: about 10 built-in light/dark themes; footer Options, Help, +, −; preview: search field with a query, hat icon, results (icon, title, subtitle, ↩ / ⌘2…⌘6 shortcut column), selected row highlighted; background toggle button top right.

## 39-appearance-options.png

Page: Appearance > Options sheet.
Elements: hide hat, hide result shortcuts, hide menu bar icon, result subtext popup; number of visible results (9) + scroll indicator popup; auto-highlight top result; focusing mode popup; screen thumbnail with window position, save position when dragging, show-on popup (default / mouse / active screen); native dark rendering; Close.

## 40-appearance-preview-on-wallpaper.png

Page: Appearance with the preview background switched to the desktop picture.
Elements: same mock, now translucent over the wallpaper.

## 41-remote-home.png

Page: Remote, nothing selected.
Layout: page list (icon, name, subtitle) | empty illustration | right column with server toggle and status, paired devices list, "Add iOS Remote", app promo.

## 42-remote-page-system-commands.png

Page: Remote > System Commands page.
Elements: 4×4 grid of round icon buttons with labels; empty dashed slot; hint "drop files, apps or URLs; hover and + for more".

## 43-advanced.png

Page: Advanced.
Layout: two columns of form rows.
Elements: clear cache, rebuild metadata; store typed query + restore last query within 5 min; keyword latching + Clear Knowledge; notification options; proxy for scripts; selection hotkey clipboard behaviour; force keyboard popup; action modifier (⌘ + number); ctrl↩ / ⌥↩ / ⌘↩ fallback popups; sync folder + Set folder / Reveal.
Shortcuts seen: ⌃↑ / ⌃↓ (query history), ⌘1–9 (pick result).

## 44-powerpack.png

Page: Powerpack (license state). Illustration + licence card; Copy License, Deactivate.

## 45-usage.png

Page: Usage.
Elements: summary line (since date, total uses, average per day) + Copy Stats; stacked area chart over 28 days with legend per type (general, expansion, clipboard, navigation, action, music, remote, hotkeys).

## 46-help.png

Page: Help.
Elements: banner pointing to the search field; four large round icons linking to docs, troubleshooting, bug report, forum; Diagnostics… button.

## 47-update.png

Page: Update.
Elements: current version bar + check button; scrolling changelog (version, build/date, bullets); auto-check checkbox + channel popup.

## 48-menubar-status-menu.png

Page: menu bar extra (captured outside the window).
Elements: hat icon; menu: Toggle, version (disabled), Preferences… ⌘,, Check for Updates…, Quit.

## 49-alfred-bar-empty.png

Page: launcher bar, empty. Reached from: hotkey ⌥Space.
Layout: single row: large search field + hat icon at the right. Rounded window, 718 pt wide.

## 50-alfred-bar-results.png

Page: launcher with results ("co").
Elements: up to 9 rows: icon, title (subtitle only on the selected row, per setting), shortcut column (↩ on the selected row, ⌘2…⌘9 on the others); selected row filled with the accent colour.
Actions: ↑/↓ select, ↩ open, ⌘n open nth, → action panel, ⇧ Quick Look, ⌘L Large Type.

## 51-alfred-action-panel.png

Page: action panel (→ on a result).
Layout: header (item icon, name, path); filter field; left a list of actions with ⌘n; right a large preview + metadata (version, created, modified); footer with a description of the selected action.

## 52-alfred-calculator.png

Page: launcher, standard calculator ("2*21").
Elements: one result with a calculator icon and the answer. Finding: an expression with functions without `=` falls through to the fallbacks.

## 53-alfred-calculator-advanced.png

Page: launcher, advanced calculator ("=…sqrt…").
Elements: one result with the answer.

## 54-alfred-fallbacks.png

Page: launcher, no matches.
Elements: three web-search fallback rows ("Search <engine> for '<query>'").

## 55-alfred-file-search-find.png

Page: launcher, `find <name>`.
Elements: file rows (document icon + file name), up to 9.

## 56-alfred-quick-file-search.png

Page: launcher, `' <name>` (quick file search).
Elements: files and folders mixed, most recent first.

## 57-alfred-file-navigation.png

Page: launcher, path navigation (`~/`).
Layout: field shows the full path; folder listing left; preview + created/modified right; footer with the selected item name and small icons at the bottom right.

## 58-alfred-terminal-prefix.png

Page: launcher, `> command`.
Elements: one row "run command in Terminal".

## 59-alfred-web-search-keyword.png

Page: launcher, `google …` with that keyword disabled.
Elements: falls back to the fallback rows.

## 60-alfred-dictionary.png

Page: launcher, `define <word>`.
Elements: one row with a dictionary icon and the word.

## 61-alfred-clipboard-keyword.png

Page: launcher, `clipboard`.
Elements: feature rows (clipboard history, show viewer).

## 62-alfred-snippets-keyword.png

Page: launcher, `snip`.
Elements: an app match + "find your snippets".

## 63-alfred-system-command.png

Page: launcher, `sleep`.
Elements: apps and system commands mixed in one ranked list.

## 64-alfred-workflow-script-filter.png

Page: launcher, `gh` (a workflow keyword whose workflow is not configured).
Elements: plain app matches only. The workflow does not show up until its required config is filled in.

## 65-alfred-clipboard-viewer.png

Page: clipboard / snippet viewer (⌥⌘C), **empty state** (history off).
Layout: filter field; left list ("All Snippets"); right a detail area with a hint; footer hint "type to filter".

## 66-alfred-large-type.png

Page: Large Type (⌘L on a query), cropped.
Elements: dark rounded card, huge white text, centred on screen; Escape closes it.

---

## Navigation map

| From | Item | Leads to |
| --- | --- | --- |
| Hotkey ⌥Space | — | Launcher bar (49) → results (50) |
| Launcher | → / ⇥ / fn / ctrl on a result | Action panel (51) |
| Launcher | `~/` or `/` | File navigation (57) |
| Launcher | `'` or space, `find`, `open`, `in`, `tags` | File search (55, 56) |
| Launcher | `=` / plain expression | Calculator (52, 53) |
| Launcher | `>` | Terminal command (58) |
| Launcher | `define`, `spell` | Dictionary (60) |
| Launcher | no matches | Fallbacks (54) |
| Launcher | ⌘L | Large Type (66) |
| Hotkey ⌥⌘C / keyword `clipboard` | — | Clipboard/snippet viewer (65) |
| Menu bar hat | Preferences… | Preferences window (01) |
| Rail | General | 01 |
| Rail | Features | 02 + feature list: File Search 03–06, Universal Actions 07–08, Web Search 09–10, Web Bookmarks 11, Clipboard 12–14, Snippets 15, Calculator 16, Dictionary 17, Contacts 18–20, Music 21–23, 1Password 24, System 25, Terminal 26, Large Type 27, Previews 28 |
| Rail | Workflows | 29 → select workflow 30 → palette 31, double-click object 32, Configure Workflow 33, info icon 34–36, bug icon 37 |
| Rail | Appearance | 38 → Options 39, background toggle 40 |
| Rail | Remote | 41 → page 42 |
| Rail | Advanced | 43 |
| Rail | Powerpack / Usage / Help / Update | 44 / 45 / 46 / 47 |

## Command map

**Launcher (seen)**: ⌥Space toggle · ↑/↓ select · ↩ open · ⌘1–9 open nth result · → (also ⇥, fn, ctrl, configurable) action panel · ⇧ or ⌘Y Quick Look · ⌘L Large Type · Esc close/back · ⌃↑/⌃↓ query history · ⌥↑/⌥↓/⌥←/⌥→ file buffer · ⌥⌘\ actions on macOS selection · ⌥⌘C clipboard viewer · ⌃⌘↩ music mini player · ctrl↩ / ⌥↩ / ⌘↩ alternative actions (web search / Finder search / reveal).

**Status menu**: Toggle · Preferences… ⌘, · Check for Updates… · Quit.

**Preferences menu bar**:

| Menu | Items |
| --- | --- |
| App | Services · Hide ⌘H · Hide Others · Show All · Quit · Quit and Close All Windows |
| File | Close ⌘W · Close All ⌥⌘W |
| Edit | Undo ⌘Z · Redo ⇧⌘Z · Cut ⌘X · Copy ⌘C · Paste ⌘V · Delete · Select All ⌘A · Writing Tools · AutoFill · Dictation · Emoji & Symbols ⌃⌘E |
| Format | Font ▸ · Text ▸ |
| Search | Search Preferences ⌘F · Filter Workflows ⇧⌘F |
| View | Zoom In ⌘+ · Zoom Out ⌘− · Actual Size ⌘0 · Enter Full Screen ⌃⌘F |
| Window | Minimize ⌘M · Minimize All ⌥⌘M · Zoom · Zoom All · Fill ⌃⌥… · Center · Move & Resize ▸ · Full Screen Tile ▸ · Bring All to Front · Arrange in Front · window list |
| Help | Send feedback · Support site |

(Shortcuts read through the accessibility attributes AXMenuItemCmdChar/Modifiers. The Window > Fill/Center modifiers are system-defined.)

## Data model guess

- **Result**: kind (app, file, folder, contact, web search, system command, calculator, dictionary, workflow item, clipboard item, snippet), title, subtitle, icon, argument, `uid` (for learning), valid flag, modifier subtitles/args (⌘ ⌥ ⌃ ⇧ fn), quick look URL.
- **Usage/knowledge**: query → chosen uid, count, last used (drives ranking, "latching"); typed-query history.
- **SearchScope**: paths[], include apps folder, include home folders; type filters (extras, don't show).
- **Keyword feature setting**: feature, keyword, enabled, confirm flag (system commands).
- **WebSearch**: keyword, display text, URL template with `{query}`, icon, built-in flag, enabled. **URLHistoryEntry**: url, last accessed.
- **Fallback**: ordered list of web searches/workflows used when there are no results.
- **ClipboardItem**: type (text, image, file list), content, source app, date; retention per type; ignored apps; max size.
- **SnippetCollection**: name, icon, prefix/suffix, auto-expand. **Snippet**: name, keyword, text (with placeholders), collection.
- **FileBuffer**: ordered file list (transient).
- **UniversalAction**: id, name, icon, enabled, applies-to types (file, text, URL).
- **Theme**: name, author, colours (window, search field, text, selection, subtext, shortcut), fonts, sizes, radius, blur, hat visibility.
- **AppearanceOptions**: visible results, subtext mode, scroll indicator, focus mode, screen, saved position.
- **Hotkey**: key + modifiers (launcher, clipboard viewer, selection, previous path, mini player, snippets viewer).
- **Workflow**: uid, name, author, version, icon, description, README, enabled, category, objects[], connections[], user config items[], environment variables[] (name, value, don't export).
- **WorkflowObject**: type (trigger/input/action/automation/UI/utility/output and subtype), config dict, position, colour. **Connection**: from, to, modifier, conditions.
- **UserConfigItem**: type (text field, checkbox, popup, file…), variable, label, description, default, placeholder, required, trim.
- **RemotePage**: name, icon, grid of buttons (action, label, icon); **PairedDevice**.
- **UsageStat**: date, counts per category.
- **Preferences**: launch at login, location, sync folder, notification options, proxy, action modifier, alternative-action mapping.

## Open

- **Dark mode**: not captured. Changing the system appearance is a system setting I do not change. Set macOS to Dark yourself and I will capture 01, 30, 38 and 50 again as `67-…` to `70-…`.
