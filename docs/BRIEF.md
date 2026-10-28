# Reach

A keyboard launcher for one Mac user: press a hotkey, type a few letters, and open an app, file, URL, calculation or snippet without touching the mouse.

Bundle id: `com.sanderrobijns.reach`. Reference walk: [screens/INDEX.md](screens/INDEX.md) (Alfred 5.8.1, 66 screens).

## Replaces
Alfred 5 with Powerpack. The two run side by side until M1–M4 are done; after that Reach takes over the ⌥Space hotkey and Alfred is switched off by hand.

## Main jobs
1. **Open things**: apps, files and folders by name, with results that learn from what I pick (S-001–S-005).
2. **Answer and act inline**: calculator, web search with fallbacks, system commands, shell commands, dictionary, and actions on a result or the macOS selection (S-006, S-008–S-024).
3. **Paste from memory**: clipboard history and snippets, in the launcher and through auto-expansion (S-025–S-031).

## Data
- **LearningEntry**: query, result id, count, last used.
- **WebSearch**: keyword, title, URL template with `{query}`, icon, built-in flag, enabled, fallback order.
- **ClipboardItem**: kind (text, image, file list), content, source app, date.
- **Snippet** in a **SnippetCollection**: name, keyword, text; collection name, auto-expand flag.

Settings (hotkeys, scope, keywords, options) live in `UserDefaults`, not in the data model. Search results are built on the fly and never stored.

## Shape
An agent app (no Dock icon) with three surfaces:
- the **launcher**: a floating, non-activating panel;
- a **menu bar icon** with a small menu;
- a **Settings** window with a sidebar (General, Features, Appearance, Advanced; Features has a second list column).

macOS 26 or later. Local data, works offline, no accounts.

## System hooks
- Global hotkey. The default is ⌃⌥Space while Alfred still has ⌥Space (decided by the agent, changeable in Settings).
- Menu bar icon; open at login; Spotlight metadata for file search; Quick Look; Accessibility for pasting and snippet expansion; the pasteboard.
- Later: a CLI or URL scheme for scripts.

## Reference
Alfred 5.8.1. Structure and behaviour only: no names, icons, text or the hat.

## Look
Native macOS 26: a Liquid Glass panel like Spotlight, the system accent colour, SF Symbols. Themes (S-032–S-034) come later on top of that native default.

## Not in version one
- Workflows and the node editor (M6, Later).
- Music mini player, web bookmarks, contacts custom actions.
- iOS remote, licensing, update channel, settings sync across Macs (later: iCloud Drive folder, S-039).
