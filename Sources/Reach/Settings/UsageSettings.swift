import AppKit
import Charts
import ReachKit
import SwiftUI

/// Settings > Usage (S-040): a summary line and the last 28 days, stacked by kind of use.
struct UsageSettings: View {
    private var usage = UsageStore.shared
    @State private var copied = false

    var body: some View {
        let days = usage.log.chart(ending: usage.now())
        Section {
            LabeledContent {
                Button(copied ? "Copied" : "Copy Stats") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(usage.statsText(), forType: .string)
                    copied = true
                }
                .disabled(usage.log.since == nil)
            } label: {
                Text("Usage")
                Text(usage.summary())
            }
        }

        Section("Last 28 Days") {
            Chart {
                ForEach(days) { day in
                    ForEach(UsageKind.allCases) { kind in
                        AreaMark(x: .value("Day", day.date, unit: .day),
                                 y: .value("Uses", day.counts[kind] ?? 0),
                                 stacking: .standard)
                            .foregroundStyle(by: .value("Kind", kind.title))
                            .interpolationMethod(.monotone)
                    }
                }
            }
            .chartForegroundStyleScale(domain: UsageKind.allCases.map(\.title))
            .chartLegend(position: .bottom, alignment: .leading)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 240)
            .padding(.vertical, Space.sm)
            .accessibilityLabel("Uses per day for the last 28 days, by kind")
        }
    }
}
