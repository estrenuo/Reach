# Architecture review — end of M6 (2026-10-30)

M6 (S-041 to S-046) added workflows: script filters in the launcher, the
Workflows window, Configure Workflow…, the canvas, the debugger, and
Workflow Info… with export. All M6 stories are done.

Survey:

- Hot spots (3 days): `STORIES.md`, `ARCHITECTURE.md`, `Snapshot.swift`, `SelfTest.swift`, `LauncherModel.swift`.
- Largest files:
  - `LauncherModel.swift`, 629 lines. It grew 18 lines in M6; workflow results and actions went into `LauncherModel+Workflows.swift` (85 lines) and `WorkflowSource`, as the M5 review planned.
  - `Snapshot.swift`, 431 lines.
  - `ActionPanel.swift`, 362 lines.
  - `ScriptFilter.swift`, 345 lines (ReachKit, pure parsing).
  - Every file in `Workflows/` is under 300 lines.
- Workflow logic sits in ReachKit with unit tests: `Workflow`, `ScriptFilterOutput`, `WorkflowStep`, `WorkflowConfiguration`, `WorkflowFolder`, `WorkflowLayout`, `WorkflowLog`, `WorkflowInfo`, `WorkflowExport` (186 tests). The app types wire them to views, the launcher and files.
- Seams with two adapters: `WorkflowSource.run` (the self-test's fake runner), `WorkflowLibrary.trash`.
- No `private struct` duplicates. `docs/FIXLOG.md` has one M6 entry (S-041); no area has 3.

## One way to run a process  [Worth exploring]

Files: Sources/Reach/Workflows/ScriptRunner.swift, WorkflowLibrary.swift (unzip, zip), Launcher/ShellSource.swift, Launcher/SystemCommands.swift
Signal: the same kind of code in four places.
Problem: four places build a `Process`, set its arguments and wait. Only `ScriptRunner` reads stdout and stderr off the main thread with a timeout. `WorkflowLibrary` waits for `ditto` on the main thread, which is fine for a small workflow folder but would hang the window on a large one.
Proposal: `WorkflowLibrary` install and export call `ScriptRunner.run(ScriptCommand(executable:arguments:))` and await it.
Benefits: one place for timeouts and stderr; export failures could show ditto's message.
Proof of same behavior: the S-042 and S-046 self-test checks (install the example, export and unpack).
Plan: one commit. Do it when export or install becomes async for another reason, or a user reports a hang.

## LauncherModel by feature  [Worth exploring]

Unchanged from the M5 review: split the action panel and buffer into `LauncherModel+Actions.swift` when the file passes 800 lines. It is 629.

## Top recommendation

None is `Strong`. M6 went in the shape the M5 review proposed: workflows are one `ResultSource`, their logic is in ReachKit, and `LauncherModel` barely grew. I change nothing in this check-in.

## Considered, not recommended

- A protocol for `WorkflowLibrary`. It has one adapter; the self-test drives the shared instance on a /tmp store.
- Splitting `Snapshot.swift`. It grows by one capture per story; each capture is a few lines and independent.
- Moving `ScriptFilter.swift` parsing into smaller files. It is one format, read top to bottom, and fully unit tested.
