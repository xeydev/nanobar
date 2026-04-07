import SwiftUI

public struct VolumeView: View {
    let volume: Float

    public init(volume: Float) { self.volume = volume }

    private var pct: Int { Int(volume * 100) }
    private var isMuted: Bool { pct == 0 }

    public var body: some View {
        HStack(spacing: Theme.iconLabelSpacing) {
            icon
            Text("\(pct)%")
                .font(.system(size: Theme.labelSize, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.labelColor)
                .stableMinWidth()
        }
        .glassPill()
        .animation(.easeInOut(duration: 0.4), value: isMuted)
    }

    // Single Image view — identity is preserved as symbol name/value change,
    // so Magic Replace fires correctly on mute/unmute.
    @ViewBuilder
    private var icon: some View {
        if #available(macOS 13, *) {
            Image(
                systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill",
                variableValue: Double(volume)
            )
            .font(.system(size: 14))
            .foregroundStyle(Theme.volumeColor)
            .frame(width: 20, height: 14)
            .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
        } else {
            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill")
                .font(.system(size: 14))
                .foregroundStyle(Theme.volumeColor)
                .frame(width: 20, height: 14)
        }
    }
}
