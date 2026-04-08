import Foundation

let h = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)!

typealias RegisterFn = @convention(c) (DispatchQueue) -> Void
typealias GetInfoFn  = @convention(c) (DispatchQueue, AnyObject) -> Void

let registerFn = unsafeBitCast(dlsym(h, "MRMediaRemoteRegisterForNowPlayingNotifications")!, to: RegisterFn.self)
let getInfoFn  = unsafeBitCast(dlsym(h, "MRMediaRemoteGetNowPlayingInfo")!, to: GetInfoFn.self)

private let kTitle  = "kMRMediaRemoteNowPlayingInfoTitle"
private let kArtist = "kMRMediaRemoteNowPlayingInfoArtist"
private let kRate   = "kMRMediaRemoteNowPlayingInfoPlaybackRate"

func fetch() {
    let block: @convention(block) ([String: Any]) -> Void = { dict in
        let title  = dict[kTitle]  as? String ?? ""
        let artist = dict[kArtist] as? String ?? ""
        let rate   = dict[kRate]   as? Double  ?? 0
        let payload: [String: Any] = ["title": title, "artist": artist, "rate": rate]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let json = String(data: data, encoding: .utf8) {
            print(json)
            fflush(stdout)
        }
    }
    getInfoFn(.main, block as AnyObject)
}

registerFn(.main)

let notificationNames = [
    "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
    "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
    "kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
]
for name in notificationNames {
    NotificationCenter.default.addObserver(
        forName: NSNotification.Name(name), object: nil, queue: .main) { _ in fetch() }
}

fetch()
RunLoop.main.run()
