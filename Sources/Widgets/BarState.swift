import SwiftUI
import Monitors
import AeroSpaceClient

@MainActor
public final class BarState: ObservableObject {
    @Published public var clockText: String = ""
    @Published public var battery        = BatteryInfo(percentage: 100, isCharging: false)
    @Published public var volume: Float  = 0.5
    @Published public var keyboardLayout = "US"
    @Published public var nowPlaying     = NowPlayingInfo(title: nil, artist: nil, isPlaying: false)
    @Published public var workspaceStates: [WorkspaceState] = []

    public init() {
        ClockMonitor.shared.register      { [weak self] v in self?.clockText       = v }
        BatteryMonitor.shared.register    { [weak self] v in self?.battery         = v }
        VolumeMonitor.shared.register     { [weak self] v in self?.volume          = v }
        KeyboardMonitor.shared.register   { [weak self] v in self?.keyboardLayout  = v }
        MediaRemoteMonitor.shared.register{ [weak self] v in self?.nowPlaying      = v }
        AeroSpaceMonitor.shared.register  { [weak self] v in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                self?.workspaceStates = v
            }
        }
    }
}
