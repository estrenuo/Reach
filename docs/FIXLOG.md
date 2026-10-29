# Fix log — Reach

## ← and → did nothing while browsing (S-008)

- Symptom: with `~/` in the search field, ← and → only moved the text cursor.
- Cause: real arrow key events carry `.numericPad` and `.function`. The check `flags.isEmpty` in `LauncherController.handle` never matched them. The self-test built key events without those flags, so it passed.
- Fix: drop `.numericPad`, `.function` and `.capsLock` before comparing modifiers, and give the self-test's arrow events the same flags as the keyboard.

Rule: build self-test key events with the flags the real keyboard sends, and compare only the modifiers people hold down.

## Move to Trash did nothing; typing in the action panel went nowhere (S-009)

- Symptom: after → the filter field stayed empty while typing "trash", and ↩ opened the file instead (Open is the first action). Back on the results, the first typed letter replaced the query.
- Cause: `@FocusState` set in `.onAppear` is lost, because the field is not in the window yet; the panel itself stayed first responder. Focusing a field later selects all of its text. The self-test set the filter on the model directly, so it never typed.
- Fix: set focus one run loop tick after appearing, then put the cursor after the text. The self-test now sends ←, letters and ↩ through `NSApp.sendEvent` and checks what the field received.

Rule: test typing with key events sent through `NSApp.sendEvent`, never by setting the model's text; set SwiftUI focus a tick after a view appears in a panel.

## Move to Trash failed for files on the Desktop (S-009)

- Symptom: Move to Trash on `~/Desktop/Schermafbeelding….png` showed "Unable to run “Move to Trash”…" and the file stayed.
- Cause: `trashItem` threw NSCocoaErrorDomain 513 (no permission). Not privacy permissions: Reach had Desktop access, and tccd logged nothing. The Desktop is a file provider domain (OneDrive: `com.apple.file-provider-domain-id`, `group:everyone deny delete`), which refuses a plain trash from other apps. The self-test used /tmp, which is not synced. The focus fix before this one was real, but not the whole story.
- Fix: on 513 `Trash.move` hands the file to a fallback, and Reach asks Finder to delete it (Apple Events, asked once). A refused Automation permission shows where to allow it. Actions log to `com.sanderrobijns.reach` / `actions`.
- Finding the log: in zsh, `log` is a builtin; use `/usr/bin/log show --last 10m --info --predicate 'subsystem == "com.sanderrobijns.reach"'`.

Rule: test file actions in a synced folder too, not only /tmp; before blaming privacy permissions, check tccd in the log and the folder's attributes (`ls -lOe@`); log every action with its error so a failure on the user's Mac can be read back.

## Quick Look stayed open after the launcher hid (S-012)

- Symptom: the self-test failed now and then on "hiding the launcher closes Quick Look", with the launcher hidden and the Quick Look panel still on screen. Other focus checks failed in the same runs.
- Cause: two at once. A tap on ⇧ followed at once by a hide (a click elsewhere) closes Quick Look during its opening animation. Quick Look ignores `orderOut` then, and `retryClose` stopped at once because the panel did not report visible yet. Separately, the runs that failed most had another app (Claude) come to the front: the launcher hides when it loses the keyboard, as it should, and every check after that fails.
- Fix: `retryClose` keeps trying for 0.6 s while the panel still reports hidden. A new check hides the launcher mid-animation; it failed on the old code and passes now. The self-test names every app that came to the front during a failed run.

Rule: when a close or hide can race an animation, retry until the window is really gone, and test the race on purpose; when a focus check fails, find out first whether another app took the keyboard.

## ⇧ closed the launcher instead of opening Quick Look (S-012)

- Symptom: on the real Mac a tap on ⇧ made the launcher disappear, with Quick Look left open or gone again. The self-test passed.
- Cause: Quick Look makes itself key when it opens. In real use another app is active and Reach is not, so at `resignKey` the key window is nil, not the Quick Look panel. The launcher read that as a click elsewhere and hid. The self-test called `handle` directly while Reach was the active app, where the key window is the Quick Look panel. The entry above blamed some of these failures on Claude coming to the front; most were this bug.
- Fix: `QuickLook.isTakingKeyboard` is true for one second after opening; a resign in that second takes the keyboard back. A new check puts Finder in front and taps ⇧ through `CGEvent`, the system's own path. It failed on the old code.

Rule: test system hooks with another app in front and real events posted through the system, since that is how people use a launcher; never accept "another app took focus" as the explanation before a test with no one at the Mac has ruled out a bug.

## The launcher hid just after Quick Look closed (S-012)

- Symptom: after a second ⇧ or Esc closed Quick Look, the launcher sometimes disappeared too. One run in four, in the self-test.
- Cause: AppKit hands the key window on again when Quick Look goes, so the launcher resigns a second time, about 0.4 s after the close. The grace from the fix above covered only the opening.
- Fix: `QuickLook.isMovingKeyboard` is true for a second after Quick Look opens or closes. Found by reading the `quicklook` log of a failed run: "close", then "launcher lost the keyboard".

Rule: a window that makes itself key also moves the keyboard when it leaves; cover both ends, and run a focus test five times before calling it stable.

## More retries kept Quick Look open (S-013, reverted)

- Symptom: one self-test run in three failed on "hiding it mid-animation closes Quick Look too". Retrying `orderOut` for 2 s instead of 0.6 s, or calling `close()` instead, made it fail in every run, and the log said "Quick Look stayed open after closing for 2 s".
- Cause: unknown in full. Calling `orderOut` or `close()` on the Quick Look panel again and again while it animates keeps it on screen; it goes once the calls stop.
- Fix: none; the three retries over 0.6 s stay. Tried with the code from the commit before, which passed three runs in a row on the same Mac.

Rule: when a change to timing code makes a flaky test fail every time, test the old code again on the same Mac before trying a third idea, and revert.

## File search showed .pyc caches and ~/Library files (end of M2)

- Symptom: `open brief` listed `session-start-briefing.cpython-310.pyc` from a `__pycache__` folder; 20 of 56 matches for "brief" in the home folder sat in ~/Library.
- Cause: compiled code has its own type (`public.python-bytecode`) that no Don't Show kind covered, and the search scope included all of ~/Library.
- Fix: a Don't Show kind "Compiled code", on at first, and `ScopeFilter` leaves ~/Library out of file search except iCloud Drive (`Mobile Documents`) and `CloudStorage`, as Alfred does. Spotlight cannot filter on the path, so `FileSearch` skips those results and keeps reading until it has nine.

Rule: check a new search against your own home folder, not only the test files; the noise lives in caches.

## Reentrant NSTableView warning in the snapshot run (end of M2)

- Symptom: full snapshot runs logged "Application performed a reentrant operation in its NSTableView delegate". Short runs of one page did not.
- Cause: switching the sidebar from Starred (3 snippets) to All (8): the one snippet `List` grew its table while the sidebar's selection and the title changed in the same update. Clicking the sidebar does the same.
- Found by: line-buffering snapshot mode's stdout (the warning goes to stderr unbuffered, so it had landed at the top of the log), then PROBE lines around each step: the warning sat between "sidebar all" and "sidebar done", 4 runs of 4. A first guess, seed data from the window's `.task`, was tried, did not help, and was reverted.
- Fix: `.id(model.sidebar)` on the snippet list, so each page gets a list of its own instead of a table that reshapes. 0 warnings in 4 runs.

Rule: before reading order into a log, make stdout line-buffered; and give a list that shows a different set per sidebar page an `.id` for the page.

## Settings and window snapshots fell back after the settings store (end of M2)

- Symptom: with `.defaultAppStorage(Store.settings)` on the Window and Settings scenes, every capture of those windows fell back to the blank-glass copy (12 of 12). The commit before gave 0 of 12.
- Cause: not found in full; the modifier on the scene root changed something screencapture relies on. Bisected by building the commit before and running the same short snapshot run.
- Fix: the store goes on the one property that needs it, `@AppStorage("confirmDelete", store: Store.settings)`, not on the scenes.

Rule: hand a store to the property that uses it, not to a whole scene; and when snapshots change after a refactor, build the commit before and run the same pages.
