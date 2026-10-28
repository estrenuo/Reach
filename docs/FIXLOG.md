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
