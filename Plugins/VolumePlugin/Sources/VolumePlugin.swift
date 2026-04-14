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

        var volAddr = volumePropertyAddress(forDevice: currentDeviceID)
        AudioObjectAddPropertyListener(currentDeviceID, &volAddr, volumeListenerCallback, ctx)
        volumeListenerAdded = true

        var muteAddr = mutePropertyAddress()
        if AudioObjectHasProperty(currentDeviceID, &muteAddr) {
            AudioObjectAddPropertyListener(currentDeviceID, &muteAddr, volumeListenerCallback, ctx)
            muteListenerAdded = true
        }
    }

    nonisolated(unsafe) private let volumeListenerCallback: AudioObjectPropertyListenerProc = { _, _, _, ctx in
        guard let ctx else { return noErr }
        let s = Unmanaged<VolumeState>.fromOpaque(ctx).takeUnretainedValue()
        Task { @MainActor in s.refreshVolume() }
        return noErr
    }

    func refreshVolume() {
        volume = VolumeState.readVolume(deviceID: currentDeviceID)
    }

    private static func readVolume(deviceID: AudioDeviceID) -> Float {
        guard deviceID != kAudioObjectUnknown else { return 0 }
        if readMute(deviceID: deviceID) { return 0 }
        if let v = readScalar(deviceID: deviceID, element: kAudioObjectPropertyElementMain) { return v }
        if let v = readScalar(deviceID: deviceID, element: 1) { return v }
        return 0
    }

    private static func readMute(deviceID: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &addr) else { return false }
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &muted) == noErr else { return false }
        return muted != 0
    }

    private static func readScalar(deviceID: AudioDeviceID, element: AudioObjectPropertyElement) -> Float? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        guard AudioObjectHasProperty(deviceID, &addr) else { return nil }
        var vol: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &vol) == noErr else { return nil }
        return vol
    }

    nonisolated private func volumePropertyAddress(forDevice deviceID: AudioDeviceID) -> AudioObjectPropertyAddress {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if !AudioObjectHasProperty(deviceID, &addr) { addr.mElement = 1 }
        return addr
    }

    nonisolated private func mutePropertyAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
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
        .glassPill()
        .animation(.easeInOut(duration: 0.4), value: isMuted)
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
        .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
    }
}

// MARK: - Factory

private final class VolumeWidgetFactory: NSObject, NanoBarWidgetFactory {
    private let config: [String: String]
    init(config: [String: String]) { self.config = config }

    var widgetID: String { "volume" }

    @MainActor func makeViewBox() -> NanoBarViewBox {
        let color = Theme.color(hex: config["color"]) ?? Theme.volumeColor
        return NanoBarViewBox(AnyView(VolumeWidgetView(color: color)))
    }
}

// MARK: - Entry point

@objc(VolumePlugin)
public final class VolumePlugin: NSObject, NanoBarPluginEntry {
    public var pluginID: String { "volume" }
    @MainActor public func registerWidgets(with registry: any NanoBarWidgetRegistry, config: [String: String]) {
        registry.register(VolumeWidgetFactory(config: config))
    }
}
