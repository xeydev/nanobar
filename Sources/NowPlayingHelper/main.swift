import Foundation

let h = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)!

typealias RegisterFn = @convention(c) (DispatchQueue) -> Void
typealias GetInfoFn  = @convention(c) (DispatchQueue, AnyObject) -> Void

let registerFn = unsafeBitCast(dlsym(h, "MRMediaRemoteRegisterForNowPlayingNotifications")!, to: RegisterFn.self)
let getInfoFn  = unsafeBitCast(dlsym(h, "MRMediaRemoteGetNowPlayingInfo")!, to: GetInfoFn.self)

func fetch() {
    let block: @convention(block) ([String: Any]) -> Void = { dict in
        let title  = dict["kMRMediaRemoteNowPlayingInfoTitle"]  as? String ?? ""
        let artist = dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
        let rate   = (dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double) ?? 0
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

let names = [
    "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
    "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
    "kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
]
for name in names {
    NotificationCenter.default.addObserver(
        forName: NSNotification.Name(name), object: nil, queue: .main) { _ in fetch() }
}

fetch()
RunLoop.main.run()
