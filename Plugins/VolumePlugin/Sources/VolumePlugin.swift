import CoreAudio
import Foundation
import SwiftUI
import NanoBarPluginAPI

// MARK: - State

@MainActor
private final class VolumeState: ObservableObject, @unchecked Sendable {
    @Published var volume: Float = 0.5

    // nonisolated(unsafe): deinit is nonisolated in Swift 6 but needs these for cleanup.
    nonisolated(unsafe) private var ctx: UnsafeMutableRawPointer?
    nonisolated(unsafe) private var volumeListenerAdded = false
    nonisolated(unsafe) private var muteListenerAdded   = false
    nonisolated(unsafe) private var deviceListenerAdded = false
    nonisolated(unsafe) private var currentDeviceID: AudioDeviceID = kAudioObjectUnknown

    // Cached at device-attach time — avoids Mach IPC (AudioObjectHasProperty) in the hot read path.
    nonisolated(unsafe) private var cachedVolumeElement: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    nonisolated(unsafe) private var cachedHasMute: Bool = false

    // Serial queue + debounce: serializes CoreAudio IPC reads, prevents thread explosion.
    // All access to pendingRead is from readQueue, so no additional lock needed.
    nonisolated(unsafe) private let readQueue = DispatchQueue(label: "com.nanobar.volume.read", qos: .userInitiated)
    nonisolated(unsafe) private var pendingRead: DispatchWorkItem?

    init() {
        ctx = Unmanaged.passRetained(self).toOpaque()
        listenForDefaultDeviceChange()
        attachToDefaultDevice()
        refreshVolume()
    }

    deinit {
        guard let ctx else { return }
        if deviceListenerAdded {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListener(AudioObjectID(kAudioObjectSystemObject), &addr, deviceListenerCallback, ctx)
        }
        if currentDeviceID != kAudioObjectUnknown {
            if volumeListenerAdded {
                var addr = volumePropertyAddress(forDevice: currentDeviceID)
                AudioObjectRemovePropertyListener(currentDeviceID, &addr, volumeListenerCallback, ctx)
            }
            if muteListenerAdded {
                var addr = mutePropertyAddress()
                AudioObjectRemovePropertyListener(currentDeviceID, &addr, volumeListenerCallback, ctx)
            }
        }
        Unmanaged<VolumeState>.fromOpaque(ctx).release()
    }

    private func listenForDefaultDeviceChange() {
        guard !deviceListenerAdded else { return }
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListener(AudioObjectID(kAudioObjectSystemObject), &addr, deviceListenerCallback, ctx)
        deviceListenerAdded = true
    }

    nonisolated(unsafe) private let deviceListenerCallback: AudioObjectPropertyListenerProc = { _, _, _, ctx in
        guard let ctx else { return noErr }
        let s = Unmanaged<VolumeState>.fromOpaque(ctx).takeUnretainedValue()
        Task { @MainActor in s.attachToDefaultDevice(); s.refreshVolume() }
        return noErr
    }

    private func attachToDefaultDevice() {
        if currentDeviceID != kAudioObjectUnknown {
            if volumeListenerAdded {
                var addr = volumePropertyAddress(forDevice: currentDeviceID)
                AudioObjectRemovePropertyListener(currentDeviceID, &addr, volumeListenerCallback, ctx)
                volumeListenerAdded = false
            }
            if muteListenerAdded {
                var addr = mutePropertyAddress()
                AudioObjectRemovePropertyListener(currentDeviceID, &addr, volumeListenerCallback, ctx)
                muteListenerAdded = false
            }
        }
        var deviceID = kAudioObjectUnknown as AudioDeviceID
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID)
        currentDeviceID = deviceID
        guard currentDeviceID != kAudioObjectUnknown else { return }

        // Cache capabilities — AudioObjectHasProperty is a Mach IPC call, do it once here.
        var volAddrMain = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(currentDeviceID, &volAddrMain) {
            cachedVolumeElement = kAudioObjectPropertyElementMain
        } else {
            cachedVolumeElement = 1
        }
        var volAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: cachedVolumeElement
        )
        AudioObjectAddPropertyListener(currentDeviceID, &volAddr, volumeListenerCallback, ctx)
        volumeListenerAdded = true

        var muteAddr = mutePropertyAddress()
        cachedHasMute = AudioObjectHasProperty(currentDeviceID, &muteAddr)
        if cachedHasMute {
            AudioObjectAddPropertyListener(currentDeviceID, &muteAddr, volumeListenerCallback, ctx)
            muteListenerAdded = true
        }
    }

    nonisolated(unsafe) private let volumeListenerCallback: AudioObjectPropertyListenerProc = { _, _, _, ctx in
        guard let ctx else { return noErr }
        let s = Unmanaged<VolumeState>.fromOpaque(ctx).takeUnretainedValue()
        let deviceID = s.currentDeviceID
        let element  = s.cachedVolumeElement
        let hasMute  = s.cachedHasMute
        // Enqueue onto serial readQueue — serializes all access to pendingRead.
        // The asyncAfter debounce lets coreaudiod finish processing before we IPC into it.
        s.readQueue.async {
            s.pendingRead?.cancel()
            let item = DispatchWorkItem {
                let new = VolumeState.readVolume(deviceID: deviceID, element: element, hasMute: hasMute)
                DispatchQueue.main.async { if s.volume != new { s.volume = new } }
            }
            s.pendingRead = item
            s.readQueue.asyncAfter(deadline: .now() + 0.05, execute: item)
        }
        return noErr
    }

    func refreshVolume() {
        let new = VolumeState.readVolume(deviceID: currentDeviceID, element: cachedVolumeElement, hasMute: cachedHasMute)
        if new != volume { volume = new }
    }

    /// No AudioObjectHasProperty calls — all capability info is pre-cached at device-attach time.
    nonisolated private static func readVolume(deviceID: AudioDeviceID, element: AudioObjectPropertyElement, hasMute: Bool) -> Float {
        guard deviceID != kAudioObjectUnknown else { return 0 }
        if hasMute && readMute(deviceID: deviceID) { return 0 }
        return readScalar(deviceID: deviceID, element: element) ?? 0
    }

    nonisolated private static func readMute(deviceID: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &muted) == noErr else { return false }
        return muted != 0
    }

    nonisolated private static func readScalar(deviceID: AudioDeviceID, element: AudioObjectPropertyElement) -> Float? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        var vol: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &vol) == noErr else { return nil }
        return vol
    }

    nonisolated private func mutePropertyAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    nonisolated private func volumePropertyAddress(forDevice deviceID: AudioDeviceID) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: cachedVolumeElement
        )
    }
}

// MARK: - View

private struct VolumeWidgetView: View {
    @StateObject private var state = VolumeState()
    let color: Color

    private var volume: Float { state.volume }
    private var pct: Int { Int(volume * 100) }
    private var isMuted: Bool { pct == 0 }

    var body: some View {
        HStack(spacing: Theme.iconLabelSpacing) {
            icon
            Text("\(pct)%")
                .font(.system(size: Theme.labelSize, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.labelColor)
                .lineLimit(1)
                .stableMinWidth()
        }
        .nanoPill()
    }

    // Single Image — identity preserved so Magic Replace fires correctly on mute/unmute.
    private var icon: some View {
        Image(
            systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill",
            variableValue: Double(volume)
        )
        .font(.system(size: 14))
        .foregroundStyle(color)
        .frame(width: 20, height: 14)
        .contentTransition(.symbolEffect(.replace))
    }
}

// MARK: - Factory

private final class VolumeWidgetFactory: NSObject, NanoBarWidgetFactory {
    private let config: [String: String]
    init(config: [String: String]) { self.config = config }

    var widgetID: String { "volume" }

    @MainActor func makeViewBox() -> NanoBarViewBox {
        let color = Theme.color(hex: config["color"]!) ?? Theme.volumeColor
        return NanoBarViewBox(AnyView(VolumeWidgetView(color: color)))
    }
}

// MARK: - Entry point

@objc(VolumePlugin)
public final class VolumePlugin: NSObject, NanoBarPluginEntry, NanoBarPluginSettingsProvider {
    public var pluginID: String { "volume" }
    @MainActor public func registerWidgets(with registry: any NanoBarWidgetRegistry, config: [String: String]) {
        registry.register(VolumeWidgetFactory(config: resolvedSettings(config)))
    }

    public var displayName: String { "Volume" }
    public func settingsSchema() -> [SettingsField] {[
        SettingsField(key: "color", label: "Icon color", type: .color, defaultValue: Theme.volumeColor.toHex8() ?? ""),
    ]}
}
