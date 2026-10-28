# Fix log — Reach

## ← and → did nothing while browsing (S-008)

- Symptom: with `~/` in the search field, ← and → only moved the text cursor.
- Cause: real arrow key events carry `.numericPad` and `.function`. The check `flags.isEmpty` in `LauncherController.handle` never matched them. The self-test built key events without those flags, so it passed.
- Fix: drop `.numericPad`, `.function` and `.capsLock` before comparing modifiers, and give the self-test's arrow events the same flags as the keyboard.

Rule: build self-test key events with the flags the real keyboard sends, and compare only the modifiers people hold down.
