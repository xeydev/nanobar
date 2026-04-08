import Foundation

public struct WorkspaceState: Sendable, Equatable {
    public let id: String
    public let isFocused: Bool
    public let windows: [WindowInfo]
    public let monitorID: Int

    public init(id: String, isFocused: Bool, windows: [WindowInfo], monitorID: Int) {
        self.id = id
        self.isFocused = isFocused
        self.windows = windows
        self.monitorID = monitorID
    }
}

public struct WindowInfo: Sendable, Equatable {
    public let windowID: Int
    public let appName: String

    public init(windowID: Int, appName: String) {
        self.windowID = windowID
        self.appName = appName
    }
}
