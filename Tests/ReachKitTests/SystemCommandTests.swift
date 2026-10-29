import Foundation
import Testing
@testable import ReachKit

private let standard = SystemCommandSetting.standard

@Test("A keyword or a title finds the command; sleep finds Sleep and Sleep Displays")
func systemCommandMatch() {
    let sleep = SystemCommands.matches("sleep", in: standard).map(\.setting.command)
    #expect(sleep.prefix(2) == [.sleep, .sleepDisplays])
    #expect(SystemCommands.matches("lock", in: standard).first?.setting.command == .lock)
    #expect(SystemCommands.matches("lock scr", in: standard).first?.setting.command == .lock)
    #expect(SystemCommands.matches("shut", in: standard).first?.setting.command == .shutDown)
    #expect(SystemCommands.matches("", in: standard).isEmpty)
    #expect(SystemCommands.matches("zzqxv", in: standard).isEmpty)
}

@Test("Letters inside a word do not offer a command")
func systemCommandLooseMatch() {
    #expect(!SystemCommands.matches("tart", in: standard).contains { $0.setting.command == .restart })
}

@Test("A command that is off, or has no keyword, matches nothing")
func systemCommandOff() {
    var settings = standard
    settings[settings.firstIndex { $0.command == .restart }!].isOn = false
    #expect(!SystemCommands.matches("restart", in: settings).contains { $0.setting.command == .restart })
    settings[settings.firstIndex { $0.command == .lock }!].keyword = "zz"
    #expect(SystemCommands.matches("zz", in: settings).first?.setting.command == .lock)
}

@Test("eject and words pick the disk")
func systemCommandEjectWords() {
    let match = SystemCommands.matches("eject Backup Disk", in: standard).first
    #expect(match?.setting.command == .eject && match?.target == "Backup Disk" && match?.score == 2000)
    #expect(SystemCommands.matches("eject", in: standard).first { $0.setting.command == .eject }?.target == nil)
}

@Test("The commands that cannot be undone ask first; only Alfred's set can ask")
func systemCommandConfirm() {
    #expect(Set(standard.filter(\.confirms).map(\.command)) == [.emptyTrash, .logOut, .restart, .shutDown, .forceQuit, .quitAll])
    #expect(!SystemCommandSetting(command: .volumeUp, confirms: true).confirms)
    #expect(SystemCommand.restart.question() == "Restart your Mac?")
    #expect(SystemCommand.restart.confirmHelp == "↩ restarts, esc cancels")
}

@Test("Commands and apps are mixed in one ranked list")
func systemCommandsRankWithApps() {
    let apps = ["Sleep Timer", "Safari"].compactMap { title in
        Matcher.score(query: "sleep", title: title).map { (id: "app:\(title)", score: $0) }
    }
    let commands = SystemCommands.matches("sleep", in: standard).map { (id: "system:\($0.setting.command.rawValue)", score: $0.score) }
    let order = Ranking.order(apps + commands, learned: [:])
    #expect(order == ["system:sleep", "app:Sleep Timer", "system:sleepDisplays"])
    let learned = Ranking.order(apps + commands, learned: ["system:sleepDisplays": LearnedPick(count: 5, lastUsed: .now)])
    #expect(learned.first == "system:sleepDisplays")
}

@Test("A keyword must be one free word")
func systemCommandProblems() {
    #expect(SystemCommands.problem(keyword: "nap", for: .sleep, in: standard) == nil)
    #expect(SystemCommands.problem(keyword: "sleep", for: .sleep, in: standard) == nil)
    #expect(SystemCommands.problem(keyword: " ", for: .sleep, in: standard) == "Type a keyword.")
    #expect(SystemCommands.problem(keyword: "go to", for: .sleep, in: standard) == "A keyword is one word, without spaces.")
    #expect(SystemCommands.problem(keyword: "Lock", for: .sleep, in: standard) == "“Lock” is already the keyword for Lock Screen.")
    #expect(SystemCommands.problem(keyword: "in", for: .sleep, in: standard, taken: ["in": "Search inside files"])
            == "“in” is already the keyword for Search inside files.")
}

@Test("Only running apps are offered after quit, hide and forcequit")
func systemCommandRunningApps() {
    let running = ["Safari", "Mail", "Music"]
    for keyword in ["quit", "hide", "forcequit"] {
        let match = SystemCommands.matches("\(keyword) sa", in: standard).first
        #expect(match?.setting.command.takesTarget == true && match?.target == "sa")
        #expect(SystemCommands.pick(match?.target ?? "", from: running, name: { $0 }).map(\.item) == ["Safari"])
    }
    #expect(SystemCommands.pick("", from: running, name: { $0 }).map(\.item) == running)
    #expect(SystemCommands.pick("Xcode", from: running, name: { $0 }).isEmpty)
    #expect(SystemCommands.pick("m", from: running, name: { $0 }).map(\.item) == ["Mail", "Music"])
}

@Test("Force Quit names the app when it asks; Quit All asks first")
func systemCommandAppQuestions() {
    #expect(SystemCommand.forceQuit.question("Safari") == "Force “Safari” to quit?")
    #expect(SystemCommand.quitAll.question() == "Quit every app but Finder?")
    #expect(SystemCommand.quitAll.confirmHelp == "↩ quits them, esc cancels")
    #expect(!SystemCommand.quitAll.takesTarget && SystemCommand.quit.takesTarget)
}
