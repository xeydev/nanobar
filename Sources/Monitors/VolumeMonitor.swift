import Foundation
import CoreAudio
import AudioToolbox

/// Push-based volume monitor using CoreAudio property listeners. Zero polling.
public final class VolumeMonitor: @unchecked Sendable {
    public static let shared = VolumeMonitor()
    public var onChange: (@MainActor (Float) -> Void)?

    private var volumeListenerAdded = false
    private var deviceListenerAdded = false
    private var currentDeviceID: AudioDeviceID = kAudioObjectUnknown

    private init() {}

    public func start() {
        listenForDefaultDeviceChange()
        attachToDefaultDevice()
        refreshVolume()
    }

    private func listenForDefaultDeviceChange() {
        guard !deviceListenerAdded else { return }
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        AudioObjectAddPropertyListener(AudioObjectID(kAudioObjectSystemObject), &addr, { _, _, _, ctx in
            guard let ctx else { return noErr }
            let monitor = Unmanaged<VolumeMonitor>.fromOpaque(ctx).takeUnretainedValue()
            monitor.attachToDefaultDevice()
            monitor.refreshVolume()
            return noErr
        }, ctx)
        deviceListenerAdded = true
    }

    private func attachToDefaultDevice() {
        // Remove listener from old device
        if volumeListenerAdded && currentDeviceID != kAudioObjectUnknown {
            var addr = volumePropertyAddress()
            let ctx = Unmanaged.passUnretained(self).toOpaque()
            AudioObjectRemovePropertyListener(currentDeviceID, &addr, volumeCallback, ctx)
            volumeListenerAdded = false
        }

        // Get new default device
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

        // Attach volume listener
        var volAddr = volumePropertyAddress()
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        AudioObjectAddPropertyListener(currentDeviceID, &volAddr, volumeCallback, ctx)
        volumeListenerAdded = true
    }

    private let volumeCallback: AudioObjectPropertyListenerProc = { _, _, _, ctx in
        guard let ctx else { return noErr }
        let monitor = Unmanaged<VolumeMonitor>.fromOpaque(ctx).takeUnretainedValue()
        monitor.refreshVolume()
        return noErr
    }

    func refreshVolume() {
        guard currentDeviceID != kAudioObjectUnknown else { return }
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var addr = volumePropertyAddress()
        AudioObjectGetPropertyData(currentDeviceID, &addr, 0, nil, &size, &volume)
        let vol = volume
        let cb = onChange
        DispatchQueue.main.async { cb?(vol) }
    }

    private func volumePropertyAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}
