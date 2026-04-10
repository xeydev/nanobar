import SwiftUI
import Monitors

public struct VolumeView: View {
    @EnvironmentObject private var state: BarState
    let config: [String: String]

    public init(config: [String: String]) { self.config = config }

    private var volume: Float { state.volume }
    private var pct: Int { Int(volume * 100) }
    private var isMuted: Bool { pct == 0 }

    private var color: Color {
        Theme.color(hex: config["color"]) ?? Theme.volumeColor
    }

    public var body: some View {
        HStack(spacing: Theme.iconLabelSpacing) {
            icon
            Text("\(pct)%")
                .font(.system(size: Theme.labelSize, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.labelColor)
                .lineLimit(1)
                .stableMinWidth()
        }
        .glassPill()
        .animation(.easeInOut(duration: 0.4), value: isMuted)
    }

    // Single Image view — identity preserved so Magic Replace fires correctly on mute/unmute.
    private var icon: some View {
        Image(
            systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill",
            variableValue: Double(volume)
        )
        .font(.system(size: 14))
        .foregroundStyle(color)
        .frame(width: 20, height: 14)
        .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
    }
}
