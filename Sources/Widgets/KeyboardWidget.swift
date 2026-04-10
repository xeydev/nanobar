import SwiftUI
import Monitors

public struct KeyboardView: View {
    @EnvironmentObject private var state: BarState
    let config: [String: String]
    @State private var wiggle = false

    public init(config: [String: String]) { self.config = config }

    private var layout: String { state.keyboardLayout }

    private var color: Color {
        Theme.color(hex: config["color"]) ?? Theme.keyboardColor
    }

    public var body: some View {
        HStack(spacing: Theme.iconLabelSpacing) {
            Image(systemName: "keyboard.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 13)
                .foregroundStyle(color)
                .symbolEffect(.bounce, options: .nonRepeating, value: wiggle)
            Text(layout)
                .font(.system(size: Theme.labelSize, weight: .semibold))
                .foregroundStyle(Theme.labelColor)
                .lineLimit(1)
                .stableMinWidth()
        }
        .glassPill()
        .onChange(of: layout) { wiggle.toggle() }
    }
}
