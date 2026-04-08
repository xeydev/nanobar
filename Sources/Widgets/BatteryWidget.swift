import SwiftUI
import Monitors

public struct BatteryView: View {
    let info: BatteryInfo

    public init(info: BatteryInfo) { self.info = info }

    private var color: Color {
        if info.isCharging || info.percentage > 60 { return Theme.batteryGreen  }
        if info.percentage > 40                    { return Theme.batteryYellow }
        if info.percentage > 20                    { return Theme.batteryOrange }
        return Theme.batteryRed
    }

    public var body: some View {
        HStack(spacing: Theme.iconLabelSpacing) {
            icon
            Text("\(info.percentage)%")
                .font(.system(size: Theme.labelSize, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.labelColor)
                .stableMinWidth()
        }
        .glassPill()
        .animation(.easeInOut(duration: 0.4), value: info.isCharging)
    }

    private var icon: some View {
        let symbolName = info.isCharging ? "battery.100percent.bolt" : "battery.100percent"
        return Image(systemName: symbolName, variableValue: Double(info.percentage) / 100.0)
            .font(.system(size: 16))
            .foregroundStyle(color)
            .frame(width: 26, height: 14)
            .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
    }
}
