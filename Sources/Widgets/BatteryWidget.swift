import Monitors
import SwiftUI

public struct BatteryView: View {
    let info: BatteryInfo

    public init(info: BatteryInfo) { self.info = info }

    private var color: Color {
        if info.isCharging || info.percentage > 75 { return Theme.batteryGreen }
        if info.percentage > 50 { return Theme.batteryYellow }
        if info.percentage > 25 { return Theme.batteryOrange }
        return Theme.batteryRed
    }

    private var symbolName: String {
        if info.isCharging { return "battery.100percent.bolt" }
        switch info.percentage {
        case ..<13:  return "battery.0percent"
        case ..<38:  return "battery.25percent"
        case ..<63:  return "battery.50percent"
        case ..<88:  return "battery.75percent"
        default:     return "battery.100percent"
        }
    }

    public var body: some View {
        HStack(spacing: Theme.iconLabelSpacing) {
            Image(systemName: symbolName)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 26, height: 14)
                .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
            Text("\(info.percentage)%")
                .font(.system(size: Theme.labelSize, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.labelColor)
                .stableMinWidth()
        }
        .glassPill()
        .animation(.easeInOut(duration: 0.4), value: info.isCharging)
        .animation(.easeInOut(duration: 0.4), value: symbolName)
    }
}
