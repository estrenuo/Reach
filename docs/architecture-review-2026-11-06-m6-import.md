# Architecture review: after the imported workflows (2026-11-06)

Since the M6 review (2026-10-30), S-047 to S-055 taught Reach to run
Sander's imported Alfred workflows: Keyword inputs, notifications, hotkeys,
File Actions, Split/Replace/JSON/Join, Grid View, key presses, the current
tab, Delay, Dialog, Terminal Command, Text View, Shortcuts and Finder tasks.
Every story is done; the build has no warnings.

Survey:

- Hot spots since 2026-10-30: `SelfTest+Workflows.swift` (27 commits),
  `ReachKit/WorkflowStep.swift` (22), `LauncherModel+Workflows.swift` (17),
  `LauncherModel.swift` (12).
- Largest files:
  - `SelfTest+Workflows.swift`, 791 lines. `checkWorkflows` alone is 355 lines.
  - `LauncherModel.swift`, 680 lines (629 at the M6 review).
  - `Snapshot.swift`, 610 lines.
  - `ReachKit/WorkflowStep.swift`, 405 lines. Its `follow` function is one `switch` of 199 lines.
- Each new object type touches the same three places: a `case` in
  `follow`, a `case` in `WorkflowStep` when it needs the app, and a
  `case` in `LauncherModel.runSteps`. That is the expected shape for an
  interpreter; the cost is inside `follow`.
- 61 calls to `steps(after:)` in 18 workflow test files pin the
  interpreter's behaviour.
- `Process()` lives in five app files; workflow steps all go through
  `ScriptRunner`, as the M6 review wanted. `WorkflowLibrary` still waits
  for `ditto` itself.
- No `private struct` duplicates. One workflow entry in the fix log (S-041).

## A workflow run's state as one value  [Strong]

Files: Sources/ReachKit/WorkflowStep.swift (405 lines)
Signal: the file every workflow story edited (22 commits in a week); one function of 199 lines.
Problem: the state a run carries (argument, variables, environment, config, depth) is passed as separate arguments. `follow` calls `next(after:argument:variables:environment:depth:)` 14 times, spelling out all of it, and the cases that change one value (Argument and Variables, Split, JSON) must repeat the others. Adding `config` for JSON Config (S-052) edited every call.
Proposal:

```swift
/// Where a workflow run is: what the next object gets.
struct WorkflowFlow {
    var argument: String
    var variables: [String: String]
    var environment: [String: String]
    var config: [String: PlistValue] = [:]
    var depth = 0
    func with(argument: String) -> Self
    func setting(_ values: [String: String]) -> Self   // into variables and environment
}
private func next(after uid: String, output: String? = nil, _ flow: WorkflowFlow) -> [WorkflowStep]
```

Then group the cases by kind in their own files, each a function
`(WorkflowObject, WorkflowFlow) -> [WorkflowStep]?`: actions (open,
reveal, copy, Large Type, Terminal), utilities (Argument, Conditional,
Split, Replace, Join, JSON, Junction, Delay), automation tasks (Trash,
Current Tab, Finder, Shortcuts) and outputs (notification, sound, debug,
Text View, dialog). `follow` asks each group in turn.
Benefits: locality, since a new object type is one case in one file of about 100 lines; each case reads as what it changes; `follow` drops below 30 lines.
Proof of same behavior: the 18 workflow unit-test files and the self-test's workflow group, unchanged and green before and after.
Plan: 1) add `WorkflowFlow` and move `follow` and `next` onto it, nothing else. 2) move the cases into four files by kind. Two commits, ReachKit only.

## The workflow self-test by story  [Worth exploring]

Files: Sources/Reach/SelfTest/SelfTest+Workflows.swift (791 lines)
Signal: a Swift file over 600 lines; the most-edited file since the M6 review.
Problem: `checkWorkflows` is 355 lines covering S-041 to S-055 in one function, so a failure line has to be searched for, and each story adds to the same function.
Proposal: split it by story group into files such as `SelfTest+WorkflowRuns.swift` (S-041, S-047) and `SelfTest+WorkflowObjects.swift` (S-051 to S-055), each a `static func` in the `workflows` group of `SelfTest.groups`.
Benefits: a failure names its file; `tools/selftest.sh workflows` stays the same.
Proof of same behavior: the same number of checks and the same PASS lines, compared before and after.
Plan: one commit. Do it at the next workflow story, or when the file passes 1,000 lines.

## LauncherModel by feature  [Worth exploring]

Unchanged from the M5 and M6 reviews: split the action panel and buffer into `LauncherModel+Actions.swift` when the file passes 800 lines. It is 680.

## One way to run a process  [Worth exploring]

Unchanged from the M6 review: `WorkflowLibrary` install and export can use `ScriptRunner`. Do it when they become async for another reason, or someone reports a hang.

## Top recommendation

**A workflow run's state as one value.** It is the only `Strong` card: the
interpreter is where the next workflow story will go, and the unit tests
already pin its behaviour, so the refactor is safe and has no UI part.

## Considered, not recommended

- One type per object kind behind a protocol. About thirty small types for what are now short cases; the grouped functions give the same locality with less interface.
- Moving the `WorkflowStep` cases that resume a run (`.wait`, `.currentTab`, `.run`) onto `WorkflowFlow`. That changes the app side as well; worth it only once another resuming step appears.
- Splitting `Snapshot.swift`. As before: one short, independent capture per story.
