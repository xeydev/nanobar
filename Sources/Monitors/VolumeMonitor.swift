import Foundation
import CoreAudio

/// Push-based volume monitor using CoreAudio property listeners. Zero polling.
public final class VolumeMonitor: @unchecked Sendable {
    public static let shared = VolumeMonitor()

    private let broadcaster = MonitorBroadcaster<Float>()

    public func register(_ observer: @escaping @MainActor (Float) -> Void) {
        broadcaster.register(observer)
    }

    private var volumeListenerAdded = false
    private var muteListenerAdded   = false
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
            let m = Unmanaged<VolumeMonitor>.fromOpaque(ctx).takeUnretainedValue()
            m.attachToDefaultDevice(); m.refreshVolume()
            return noErr
        }, ctx)
        deviceListenerAdded = true
    }

    private func attachToDefaultDevice() {
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        if currentDeviceID != kAudioObjectUnknown {
            if volumeListenerAdded {
                var addr = volumePropertyAddress(forDevice: currentDeviceID)
                AudioObjectRemovePropertyListener(currentDeviceID, &addr, volumeListenerCallback, ctx)
                volumeListenerAdded = false
            }
            if muteListenerAdded {
                var addr = mutePropertyAddress(forDevice: currentDeviceID)
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

        var muteAddr = mutePropertyAddress(forDevice: currentDeviceID)
        if AudioObjectHasProperty(currentDeviceID, &muteAddr) {
            AudioObjectAddPropertyListener(currentDeviceID, &muteAddr, volumeListenerCallback, ctx)
            muteListenerAdded = true
        }
    }

    private let volumeListenerCallback: AudioObjectPropertyListenerProc = { _, _, _, ctx in
        guard let ctx else { return noErr }
        Unmanaged<VolumeMonitor>.fromOpaque(ctx).takeUnretainedValue().refreshVolume()
        return noErr
    }

    func refreshVolume() {
        broadcaster.notify(Self.readVolume(deviceID: currentDeviceID))
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

    private func volumePropertyAddress(forDevice deviceID: AudioDeviceID) -> AudioObjectPropertyAddress {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if !AudioObjectHasProperty(deviceID, &addr) { addr.mElement = 1 }
        return addr
    }

    private func mutePropertyAddress(forDevice _: AudioDeviceID) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}
