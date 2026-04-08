import SwiftUI

public struct ClockView: View {
    let text: String

    public init(text: String) { self.text = text }

    @ViewBuilder
    public var body: some View {
        if !text.isEmpty {
            HStack(spacing: Theme.iconLabelSpacing) {
                Image(systemName: "calendar")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(Theme.calendarColor)
                Text(text)
                    .font(.system(size: Theme.labelSize, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.labelColor)
                    .stableMinWidth()
            }
            .glassPill()
        }
    }
}
