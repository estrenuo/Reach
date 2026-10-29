import SwiftUI

/// The buffer at the right end of the search field (S-013): up to five
/// small icons, overlapping like a fanned stack, then "+N" and the count.
struct BufferView: View {
    let items: [URL]

    static let shown = 5
    static let iconSize: CGFloat = 24
    /// How much each icon covers the one before it.
    static let overlap: CGFloat = -Space.sm

    private var names: [String] { items.map { FileManager.default.displayName(atPath: $0.path) } }

    var body: some View {
        HStack(spacing: Space.xs) {
            HStack(spacing: Self.overlap) {
                ForEach(Array(items.prefix(Self.shown).enumerated()), id: \.element) { index, url in
                    IconCache.image(for: .file(url.path))
                        .resizable()
                        .frame(width: Self.iconSize, height: Self.iconSize)
                        // The newest on top, as it was added last.
                        .zIndex(Double(index))
                        .help(names[index])
                }
            }
            Text(items.count > Self.shown ? "+\(items.count - Self.shown)" : "\(items.count)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .help("\(items.count) \(items.count == 1 ? "item" : "items") in the buffer. "
              + "⌥→ for actions, ⌥← to take out the last, ⌥⌫ to empty.")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Buffer, \(items.count) \(items.count == 1 ? "item" : "items"): \(names.joined(separator: ", "))")
        .transition(.opacity)
    }
}
