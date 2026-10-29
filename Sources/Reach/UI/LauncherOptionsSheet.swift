import ReachKit
import SwiftUI

/// Launcher Options (S-034), a sheet from Settings > Appearance: how the bar
/// looks on the left, where it shows on the right.
struct LauncherOptionsSheet: View {
    @Bindable private var options = LauncherOptionsStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                Form { looks }.formStyle(.grouped)
                Form { position }.formStyle(.grouped)
            }
            .scrollDisabled(true)
            Divider()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(Space.lg)
        }
        .frame(width: 760)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var looks: some View {
        Section("Results") {
            Picker("Visible results", selection: $options.visibleResults) {
                ForEach(Array(LauncherOptions.visibleResults), id: \.self) { Text("\($0)").tag($0) }
            }
            Picker(selection: $options.subtext) {
                Text("Always").tag(LauncherOptions.Subtext.always)
                Text("Selected Row Only").tag(LauncherOptions.Subtext.selected)
                Text("Never").tag(LauncherOptions.Subtext.never)
            } label: {
                Text("Show subtext")
                Text("The second line of a row: a path, a URL, or what Return does.")
            }
            Toggle(isOn: $options.hidesShortcuts) {
                Text("Hide result shortcuts")
                Text("⌘1 to ⌘9 and ↩ on the right of each row. The keys still work.")
            }
        }
        Section("Menu Bar") {
            Toggle(isOn: $options.showsMenuBarIcon) {
                Text("Show menu bar icon")
                Text("Without it, type “settings” in the launcher, press ⌘, there, or open Reach again to reach Settings.")
            }
        }
    }

    @ViewBuilder
    private var position: some View {
        Section("Position") {
            ScreenSketch(choice: options.screen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.xs)
            Picker(selection: $options.screen) {
                Text("Mouse Screen").tag(LauncherOptions.Screen.mouse)
                Text("Main Screen").tag(LauncherOptions.Screen.main)
                Text("Active Screen").tag(LauncherOptions.Screen.activeWindow)
            } label: {
                Text("Show on")
                Text(options.screen.help)
            }
        }
    }
}

extension LauncherOptions.Screen {
    var help: String {
        switch self {
        case .mouse: "The screen the pointer is on."
        case .main: "The screen with the menu bar."
        case .activeWindow: "The screen with the window you are working in, else the mouse screen."
        }
    }
}

/// Two screens, a window on the left one and the pointer on the right one,
/// with the bar drawn on the screen the choice picks.
private struct ScreenSketch: View {
    let choice: LauncherOptions.Screen

    private var picked: Int { choice == .mouse ? 1 : 0 }

    var body: some View {
        HStack(alignment: .bottom, spacing: Space.sm) {
            screen(0, width: 132, height: 84)
            screen(1, width: 172, height: 108)
        }
        .animation(.easeOut(duration: Motion.appear), value: choice)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(picked == 0 ? "The launcher shows on the left screen" : "The launcher shows on the right screen")
    }

    private func screen(_ index: Int, width: CGFloat, height: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        return ZStack(alignment: .top) {
            shape.fill(.background.secondary)
            if index == 0 {
                // The menu bar, and the active window.
                Rectangle().fill(.tertiary).frame(height: 4)
                RoundedRectangle(cornerRadius: 2).strokeBorder(.secondary, lineWidth: 1)
                    .frame(width: 64, height: 40)
                    .offset(x: -24, y: 28)
            } else {
                Image(systemName: "cursorarrow")
                    .font(.system(size: 12))
                    .offset(x: 48, y: 64)
            }
            if picked == index {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Palette.accent)
                    .frame(width: width * 0.5, height: 12)
                    .offset(y: height * 0.2)
                    .transition(.opacity)
            }
        }
        .frame(width: width, height: height)
        .overlay(shape.strokeBorder(picked == index ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(.separator),
                                    lineWidth: picked == index ? 2 : 1))
    }
}
