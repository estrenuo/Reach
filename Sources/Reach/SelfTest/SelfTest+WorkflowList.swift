import Foundation
import ReachKit

extension SelfTest {
    /// S-042: the example installs and answers its keyword, Turn Off silences
    /// it, and Remove moves the folder to a stand-in Trash.
    static func checkWorkflowList(model: AppModel) async {
        let lm = model.launcherModel
        let library = WorkflowLibrary.shared
        let trash = Shared<[URL]>([])
        let realTrash = library.trash
        library.trash = { url in
            trash.value.append(url)
            try FileManager.default.removeItem(at: url)
        }
        defer {
            library.trash = realTrash
            library.selection = nil
            library.filter = ""
        }

        let before = library.workflows.count
        library.addExample()
        guard let example = library.selected else {
            check("Add Example installs Hello World and selects it", false, library.failure ?? "")
            return
        }
        check("Add Example installs Hello World and selects it", example.name == "Hello World" && library.workflows.count == before + 1)
        let placed = WorkflowLayout.positions(example)
        check("the canvas places every object where uidata says", placed.count == example.objects.count
              && placed["HELLO"] == WorkflowPoint(x: 40, y: 80))
        library.filter = "hel"
        check("Filter Workflows finds it by name", library.shown.map(\.id) == [example.id])
        library.filter = "zzz"
        check("a filter that matches nothing shows no workflow", library.shown.isEmpty)
        library.filter = ""

        lm.query = "hello Ada"
        try? await Task.sleep(for: .milliseconds(1500))
        check("its keyword answers in the launcher", lm.results.contains { $0.title == "Hello, Ada" },
              lm.results.map(\.title).joined(separator: ", "))

        library.setEnabled(false, example)
        check("Turn Off is saved in its info.plist", Workflow(folder: example.folder)?.disabled == true)
        lm.query = "hello Bob"
        try? await Task.sleep(for: .milliseconds(300))
        check("a workflow that is off adds nothing to the launcher", !lm.results.contains { $0.workflow != nil || $0.kindLabel == "Hello World" })
        library.setEnabled(true, example)

        // S-043: a saved configuration value reaches the script as an environment variable.
        if let current = library.workflow(example.id) {
            check("Configure Workflow… lists its fields", current.settings.map(\.label) == ["Greeting", "Name"])
            check("an empty required field blocks Save",
                  WorkflowConfiguration.missing(current.settings, values: ["greeting": ""]).map(\.variable) == ["greeting"])
            library.saveConfiguration(["greeting": "Hoi", "shout": "1"], for: current)
            lm.query = "hello Ada"
            try? await Task.sleep(for: .milliseconds(1500))
            check("the script reads the saved values", lm.results.contains { $0.title == "Hoi, ADA" },
                  lm.results.map(\.title).joined(separator: ", "))
        }

        // S-046: Workflow Info… saves, and Export leaves secret values out.
        if let current = library.workflow(example.id) {
            var info = WorkflowInfo(current)
            info.version = "2.0"
            info.variables = [WorkflowVariable(name: "api_key", value: "secret", dontExport: true),
                              WorkflowVariable(name: "user", value: "ada")]
            library.saveInfo(info, for: current)
            let saved = library.workflow(example.id)
            check("Workflow Info… saves the version and variables", saved?.version == "2.0"
                  && saved?.variables["api_key"] == "secret" && saved?.variables["user"] == "ada")
            let out = FileManager.default.temporaryDirectory.appending(path: "Reach-selftest-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: out) }
            try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            let file = out.appending(path: "Hello World.alfredworkflow")
            if let saved { await library.export(saved, to: file) }
            let unzip = Process()
            unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            unzip.arguments = ["-x", "-k", file.path, out.appending(path: "x").path]
            try? unzip.run()
            unzip.waitUntilExit()
            let exported = Workflow(folder: out.appending(path: "x"))
            check("Export Workflow… blanks Don't Export values and keeps the rest",
                  exported?.variables["api_key"] == "" && exported?.variables["user"] == "ada"
                  && !FileManager.default.fileExists(atPath: out.appending(path: "x/prefs.plist").path),
                  "\(exported?.variables ?? [:]) \(library.failure ?? "")")
        }

        library.remove(library.workflow(example.id) ?? example)
        check("Remove moves the folder to the Trash", trash.value.map(\.lastPathComponent) == [example.id]
              && library.workflow(example.id) == nil && library.selection == nil)
        lm.query = ""
    }
}
