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
