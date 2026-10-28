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
