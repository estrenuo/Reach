import Foundation
import ReachKit

extension SelfTest {
    /// selftest.workflow, which checkWorkflows installs for every workflow
    /// check: one object of each kind the checks run, each with the keyword,
    /// hotkey or action that reaches it, and the lines between them.
    static func selfTestWorkflowPlist() -> [String: Any] {
        [
            "bundleid": "com.reach.selftest", "name": "Self Test", "createdby": "Reach",
            "objects": [
                ["uid": "SF", "type": ScriptFilter.type, "config": [
                    "keyword": "rtest", "withspace": true, "argumenttype": 0, "title": "Search Self Test",
                    "runningsubtext": "Looking…", "script": "echo", "type": 0, "scriptargtype": 1,
                ]],
                ["uid": "URL", "type": Workflow.openURL, "config": ["url": "https://example.com/{query}"]],
                ["uid": "COPY", "type": Workflow.copyToClipboard, "config": ["clipboardtext": "copied {query}"]],
                // S-047: a Keyword input whose keyword comes from a variable.
                ["uid": "KW", "type": KeywordInput.type, "config": [
                    "keyword": "{var:kw}", "withspace": true, "argumenttype": 0, "text": "Open {query}",
                ]],
                // S-047: keywords whose Return reaches an Automation Task, or an
                // External Trigger that shows the rkey keyword again.
                ["uid": "TASKKW", "type": KeywordInput.type, "config": ["keyword": "rtask", "argumenttype": 2, "text": "Task"]],
                ["uid": "TASK", "type": "alfred.workflow.automation.task", "config": [:]],
                ["uid": "BACKKW", "type": KeywordInput.type, "config": ["keyword": "rback", "argumenttype": 0, "text": "Back"]],
                ["uid": "IF", "type": Workflow.conditional, "config": ["conditions": [
                    ["uid": "ISWORLD", "inputstring": "", "matchmode": 0, "matchstring": "world"],
                ]]],
                ["uid": "CALL", "type": Workflow.callExternalTrigger, "config": [
                    "externaltriggerid": "again", "workflowbundleid": "self", "passinputasargument": true,
                ]],
                ["uid": "AGAIN", "type": Workflow.externalTrigger, "config": ["triggerid": "again"]],
                // S-048: Post Notification passes the text on to Copy to Clipboard.
                ["uid": "NOTEKW", "type": KeywordInput.type, "config": ["keyword": "rnote", "argumenttype": 0, "text": "Note"]],
                ["uid": "NOTE", "type": Workflow.notification, "config": ["title": "Done", "text": "{query}"]],
                ["uid": "SOUND", "type": Workflow.playSound, "config": ["soundname": "Blow", "systemsound": true]],
                ["uid": "DEBUG", "type": Workflow.debug, "config": ["argument": "debug {query}", "processoutputs": true]],
                ["uid": "TRASHKW", "type": KeywordInput.type, "config": ["keyword": "rtrash", "argumenttype": 0, "text": "Trash"]],
                ["uid": "TRASH", "type": Workflow.automationTask, "config": [
                    "taskuid": Workflow.trashTask, "tasksettings": ["target_path": "/tmp/{query}"],
                ]],
                // S-049: Hotkey triggers with each kind of argument.
                ["uid": "HKNONE", "type": WorkflowHotkey.type, "config": ["action": 0, "argument": 0]],
                ["uid": "HKSEL", "type": WorkflowHotkey.type, "config": ["action": 0, "argument": 1]],
                ["uid": "HKCLIP", "type": WorkflowHotkey.type, "config": ["action": 0, "argument": 2]],
                ["uid": "HKFIND", "type": WorkflowHotkey.type, "config": ["action": 0, "argument": 4]],
                // S-051: Split Arguments, as arguments, on a comma.
                ["uid": "SPLITKW", "type": KeywordInput.type, "config": ["keyword": "rsplit", "argumenttype": 0, "text": "Split"]],
                ["uid": "SPLIT", "type": Workflow.split, "config": ["delimiter": ",", "outputas": 1, "trimarguments": true]],
                // S-051: Replace with a regular expression and its groups.
                ["uid": "REPLKW", "type": KeywordInput.type, "config": ["keyword": "rrepl", "argumenttype": 0, "text": "Replace"]],
                ["uid": "REPL", "type": Workflow.replace, "config": [
                    "matchmode": 1, "matchstring": #".*github.com\/([^\/?]*\/[^\/?]*).*"#, "replacestring": "$1",
                ]],
                // S-052: JSON Config sets the argument and Copy to Clipboard's text.
                ["uid": "JSONKW", "type": KeywordInput.type, "config": ["keyword": "rjson", "argumenttype": 0, "text": "JSON"]],
                ["uid": "JSON", "type": Workflow.json, "config": [
                    "json": #"{"alfredworkflow": {"arg": "{query}!", "config": {"clipboardtext": "json {query}"}}}"#,
                ]],
                // S-052: Split on a comma, then Join Arguments with a plus.
                ["uid": "JOINKW", "type": KeywordInput.type, "config": ["keyword": "rjoin", "argumenttype": 0, "text": "Join"]],
                ["uid": "JOINSPLIT", "type": Workflow.split, "config": ["delimiter": ",", "outputas": 1, "trimarguments": true]],
                ["uid": "JOIN", "type": Workflow.joinArgs, "config": ["delimiter": "+"]],
                // S-053: Browse in Terminal with the argument as the path.
                ["uid": "TERMKW", "type": KeywordInput.type, "config": ["keyword": "rterm", "argumenttype": 0, "text": "Terminal"]],
                ["uid": "TERM", "type": Workflow.browseInTerminal, "config": ["path": ""]],
                // S-053: Dispatch Key Combo presses ⌘V, then Copy to Clipboard.
                ["uid": "KEYSKW", "type": KeywordInput.type, "config": ["keyword": "rkeys", "argumenttype": 0, "text": "Keys"]],
                ["uid": "KEYS", "type": Workflow.dispatchKeys, "config": [
                    "keychar": "v", "keycode": -1, "keymod": 1_048_576, "count": 1, "overridewithargument": false,
                ]],
                // S-053: a Grid View fed by a script file; a fake runner answers.
                ["uid": "GRIDKW", "type": KeywordInput.type, "config": ["keyword": "rgrid", "argumenttype": 0, "text": "Grid"]],
                ["uid": "GRID", "type": Workflow.grid, "config": ["inputtype": 1, "inputfile": "grid.sh", "filterable": true]],
                // S-054: the grid's ⇧ line shows Large Type.
                ["uid": "GRIDLARGE", "type": Workflow.largeType, "config": [:]],
                // S-054: the front browser tab's URL.
                ["uid": "TABKW", "type": KeywordInput.type, "config": ["keyword": "rtab", "argumenttype": 2, "text": "Tab"]],
                ["uid": "TAB", "type": Workflow.automationTask, "config": [
                    "taskuid": "com.alfredapp.automation.extras/web-browsers/frontmost-browser/frontmost.tabs.current",
                    "tasksettings": ["allow_empty": true],
                ]],
                // S-054: Action in Alfred opens the action panel for the text.
                ["uid": "ACTKW", "type": KeywordInput.type, "config": ["keyword": "ract", "argumenttype": 0, "text": "Actions"]],
                ["uid": "ACT", "type": Workflow.actionInAlfred, "config": ["jumpto": "_popUpItemAction:", "path": "", "type": 1]],
                // S-055: Delay, then Copy to Clipboard.
                ["uid": "WAITKW", "type": KeywordInput.type, "config": ["keyword": "rwait", "argumenttype": 0, "text": "Wait"]],
                ["uid": "WAIT", "type": Workflow.delay, "config": ["seconds": "0.2"]],
                ["uid": "ASKKW", "type": KeywordInput.type, "config": ["keyword": "rask", "argumenttype": 0, "text": "Ask"]],
                ["uid": "ASK", "type": Workflow.dialog, "config": ["title": "About {query}", "description": "Details", "button1": "Ok"]],
                ["uid": "BREWKW", "type": KeywordInput.type, "config": ["keyword": "rbrew", "argumenttype": 0, "text": "Brew"]],
                ["uid": "BREW", "type": Workflow.terminalCommand, "config": ["escaping": 0, "script": "brew install {query}"]],
                ["uid": "INFOKW", "type": KeywordInput.type, "config": ["keyword": "rinfo", "argumenttype": 0, "text": "Info"]],
                ["uid": "INFO", "type": Workflow.textView, "config": ["inputtype": 0, "outputmode": 0, "behaviour": 0, "fontmode": 0,
                                                                       "fontsizing": 4, "stackview": true, "footertext": "", "loadingtext": ""]],
                ["uid": "SHORTKW", "type": KeywordInput.type, "config": ["keyword": "rshort", "argumenttype": 0, "text": "Shortcut"]],
                ["uid": "SHORTJSON", "type": Workflow.json, "config": [
                    "json": #"{"alfredworkflow": {"arg": "{query}", "config": {"shortcut": "Echo", "inputmode": "0", "outputmode": 0}}}"#]],
                ["uid": "SHORT", "type": WorkflowShortcut.runType, "config": ["shortcut": "", "inputmode": -1, "outputmode": 0]],
                ["uid": "VIEWKW", "type": KeywordInput.type, "config": ["keyword": "rview", "argumenttype": 0, "text": "View"]],
                ["uid": "VIEW", "type": Workflow.automationTask, "config": ["taskuid": WorkflowShortcut.viewTask,
                                                                          "tasksettings": ["target_shortcut": "{query}"]]],
                ["uid": "SELKW", "type": KeywordInput.type, "config": ["keyword": "rsel", "argumenttype": 2, "text": "Selection"]],
                ["uid": "SEL", "type": Workflow.automationTask, "config": ["taskuid": FinderTask.selection, "tasksettings": [String: String]()]],
                ["uid": "WINKW", "type": KeywordInput.type, "config": ["keyword": "rwin", "argumenttype": 2, "text": "Window"]],
                ["uid": "WIN", "type": Workflow.automationTask, "config": ["taskuid": FinderTask.currentWindow, "tasksettings": [String: String]()]],
                // S-052: Universal Actions for text (not URLs) and for files.
                ["uid": "UATEXT", "type": WorkflowUniversalAction.type, "config": [
                    "name": "Self Test Text Universal", "acceptstext": true, "acceptsurls": false, "acceptsfiles": false,
                ]],
                ["uid": "UAFILES", "type": WorkflowUniversalAction.type, "config": [
                    "name": "Self Test Files Universal", "acceptsfiles": true, "acceptsmulti": 1,
                ]],
                // S-052: a Fallback Search.
                ["uid": "FALLBACK", "type": WorkflowFallback.type, "config": ["text": "Self Test fallback for '{query}'"]],
                // S-051: a File Filter for text files.
                ["uid": "FF", "type": FileFilter.type, "config": [
                    "keyword": "rfiles", "withspace": true, "argumenttype": 0, "title": "Find Self Test Files",
                    "types": ["public.plain-text"], "anchorfields": true, "limit": 0, "scopes": [String](),
                ]],
                // S-050: File Actions for text files (several) and for one image.
                ["uid": "FATEXT", "type": WorkflowFileAction.type, "config": [
                    "name": "Self Test Text Action", "acceptsmulti": 1, "filetypes": ["public.plain-text"],
                ]],
                ["uid": "FAPNG", "type": WorkflowFileAction.type, "config": [
                    "name": "Self Test Image Action", "acceptsmulti": 0, "filetypes": ["public.png"],
                ]],
            ],
            "variables": ["kw": "rkey"],
            "connections": [
                "SF": [
                    ["destinationuid": "URL", "modifiers": 0],
                    ["destinationuid": "COPY", "modifiers": WorkflowConnection.command, "modifiersubtext": "Copy"],
                ],
                "KW": [["destinationuid": "URL", "modifiers": 0]],
                "TASKKW": [["destinationuid": "TASK", "modifiers": 0]],
                "BACKKW": [["destinationuid": "IF", "modifiers": 0]],
                "IF": [["destinationuid": "CALL", "modifiers": 0, "sourceoutputuid": "ISWORLD"]],
                "AGAIN": [["destinationuid": "KW", "modifiers": 0]],
                "TRASHKW": [["destinationuid": "TRASH", "modifiers": 0]],
                "NOTEKW": [["destinationuid": "NOTE", "modifiers": 0]],
                "NOTE": [["destinationuid": "SOUND", "modifiers": 0]],
                "SOUND": [["destinationuid": "DEBUG", "modifiers": 0]],
                "DEBUG": [["destinationuid": "COPY", "modifiers": 0]],
                "HKNONE": [["destinationuid": "COPY", "modifiers": 0]],
                "HKSEL": [["destinationuid": "COPY", "modifiers": 0]],
                "HKCLIP": [["destinationuid": "COPY", "modifiers": 0]],
                "HKFIND": [["destinationuid": "COPY", "modifiers": 0]],
                "FATEXT": [["destinationuid": "COPY", "modifiers": 0]],
                "SPLITKW": [["destinationuid": "SPLIT", "modifiers": 0]],
                "SPLIT": [["destinationuid": "COPY", "modifiers": 0]],
                "REPLKW": [["destinationuid": "REPL", "modifiers": 0]],
                "REPL": [["destinationuid": "COPY", "modifiers": 0]],
                "FF": [["destinationuid": "COPY", "modifiers": 0]],
                "JSONKW": [["destinationuid": "JSON", "modifiers": 0]],
                "JSON": [["destinationuid": "COPY", "modifiers": 0]],
                "JOINKW": [["destinationuid": "JOINSPLIT", "modifiers": 0]],
                "JOINSPLIT": [["destinationuid": "JOIN", "modifiers": 0]],
                "JOIN": [["destinationuid": "COPY", "modifiers": 0]],
                "FALLBACK": [["destinationuid": "COPY", "modifiers": 0]],
                "UATEXT": [["destinationuid": "COPY", "modifiers": 0]],
                "TERMKW": [["destinationuid": "TERM", "modifiers": 0]],
                "KEYSKW": [["destinationuid": "KEYS", "modifiers": 0]],
                "TABKW": [["destinationuid": "TAB", "modifiers": 0]],
                "ACTKW": [["destinationuid": "ACT", "modifiers": 0]],
                "WAITKW": [["destinationuid": "WAIT", "modifiers": 0]],
                "WAIT": [["destinationuid": "COPY", "modifiers": 0]],
                "ASKKW": [["destinationuid": "ASK", "modifiers": 0]],
                "BREWKW": [["destinationuid": "BREW", "modifiers": 0]],
                "INFOKW": [["destinationuid": "INFO", "modifiers": 0]],
                "SHORTKW": [["destinationuid": "SHORTJSON", "modifiers": 0]],
                "SHORTJSON": [["destinationuid": "SHORT", "modifiers": 0]],
                "SHORT": [["destinationuid": "COPY", "modifiers": 0]],
                "VIEWKW": [["destinationuid": "VIEW", "modifiers": 0]],
                "SELKW": [["destinationuid": "SEL", "modifiers": 0]],
                "SEL": [["destinationuid": "COPY", "modifiers": 0]],
                "WINKW": [["destinationuid": "WIN", "modifiers": 0]],
                "WIN": [["destinationuid": "COPY", "modifiers": 0]],
                "TAB": [["destinationuid": "COPY", "modifiers": 0]],
                "GRIDKW": [["destinationuid": "GRID", "modifiers": 0]],
                "GRID": [["destinationuid": "COPY", "modifiers": 0], ["destinationuid": "GRIDLARGE", "modifiers": WorkflowConnection.shift]],
                "KEYS": [["destinationuid": "COPY", "modifiers": 0]],
                "UAFILES": [["destinationuid": "COPY", "modifiers": 0]],
                "FAPNG": [["destinationuid": "COPY", "modifiers": 0]],
            ],
        ]
    }
}
