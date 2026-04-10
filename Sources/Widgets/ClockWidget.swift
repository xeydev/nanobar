import SwiftUI
import Monitors

public struct ClockView: View {
    @EnvironmentObject private var state: BarState
    let config: [String: String]

    public init(config: [String: String]) { self.config = config }

    private var color: Color {
        Theme.color(hex: config["color"]) ?? Theme.calendarColor
    }

    @ViewBuilder
    public var body: some View {
        if !state.clockText.isEmpty {
            HStack(spacing: Theme.iconLabelSpacing) {
                Image(systemName: "calendar")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(color)
                Text(state.clockText)
                    .font(.system(size: Theme.labelSize, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.labelColor)
                    .lineLimit(1)
                    .stableMinWidth()
            }
            .glassPill()
        }
    }
}
