# Reach

A keyboard launcher for macOS, built in Swift and SwiftUI. Press a hotkey, type a few letters, and open an app, file, URL, calculation or snippet without touching the mouse.

> **Status: one-shot, as-is, unmaintained.** Reach was built once, as a showcase. There will be no further development, no bug fixes, no releases and no support. Issues and pull requests will not be answered. Use it at your own risk.

## Why this exists

Reach is a showcase for [bama](https://github.com/daveebbelaar/bama) (Build Any Mac App) by Dave Ebbelaar: a set of agent skills that take you from an existing app you like, through screenshots and user stories, to a native macOS app built one story per commit. The `docs/` folder holds that trail: the brief, the screen index of the reference walk, the user stories (S-001 to S-046) and the architecture reviews.

The reference app was [Alfred 5](https://www.alfredapp.com) with the Powerpack. Reach is a clone of its structure and behaviour, written from scratch. It contains no Alfred code, names, icons or artwork.

## Not a replacement for Alfred

Reach is **not** meant to take any income away from Alfred or its Powerpack licence. Alfred is a mature, maintained product, and Reach is an unmaintained experiment. If you like what you see here, [buy the Powerpack](https://www.alfredapp.com/shop/) and use the real thing.

## What it does

- **Launcher**: a floating panel on a global hotkey (default ⌃⌥Space) that finds apps, files and folders, and learns from what you pick.
- **Files**: browse folders inside the launcher, an action panel per result (Open With, Reveal in Finder, Copy Path, Move to Trash and more), Quick Look, a file buffer to act on several files at once, and keywords for file search, Finder reveal, content search and tags.
- **Selection hotkey** (⌃⌥⌘\\): act on the current Finder selection or selected text.
- **Built-in answers**: calculator, custom web searches with fallbacks, typed URLs with history, system commands, quitting apps, shell commands, dictionary, Large Type and contacts.
- **Clipboard and snippets**: clipboard history with a viewer, app exclusions, appending to the last clip, snippet collections and auto-expansion while typing.
- **Look and system**: built-in and custom themes, bar position and behaviour, searchable Settings, usage statistics, and settings sync through a folder such as iCloud Drive.
- **Workflows (light)**: runs script filters from Alfred-format workflow folders and `.alfredworkflow` files, with configuration, a read-only canvas and a debugger. There is no workflow editor.

`docs/STORIES.md` lists every story with its exact behaviour.

## Requirements

- macOS 26 or later
- Xcode 26 (Swift 6.2). There is no Xcode project: Reach is a Swift package built from the command line.

## Build and install

There are no prebuilt binaries. Build it yourself:

```sh
git clone https://github.com/estrenuo/Reach.git
cd Reach
./build.sh --open
```

`build.sh` builds a release binary, installs it to `~/Applications/Reach.app` and signs it with your Apple Development certificate if you have one, otherwise ad hoc. Build products go to `~/Library/Developer/Reach`, outside the repo.

Reach is an agent app: it has no Dock icon, only a menu bar icon. Depending on what you use, macOS asks for Accessibility (pasting, snippet expansion, selected text), Contacts, and Automation (Finder, System Events, your terminal app).

If you also run Alfred, Reach's default hotkeys avoid Alfred's. You can change them in Settings.

## Tests

```sh
swift test --scratch-path ~/Library/Developer/Reach/test-build   # unit tests for ReachKit
tools/selftest.sh                                                # in-app self-test on a throwaway store in /tmp
```

## Layout

- `Sources/Reach/` the app (SwiftUI, AppKit, SwiftData).
- `Sources/ReachKit/` pure logic without UI, with tests in `Tests/ReachKitTests/`.
- `docs/` the brief, stories, screen index and architecture reviews.
- `ARCHITECTURE.md` how the parts fit together. `CLAUDE.md` the rules the agent worked by.

## Trademarks

Alfred is a registered trademark of Running with Crayons Ltd. Reach is not affiliated with, endorsed by or connected to Running with Crayons or Alfred in any way.

## License

MIT, see [LICENSE](LICENSE). The software is provided as is, without warranty of any kind.
