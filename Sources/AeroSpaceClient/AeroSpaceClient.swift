import Foundation

/// Runs aerospace CLI commands and returns stdout.
public final class AeroSpaceClient: @unchecked Sendable {
    public static let shared = AeroSpaceClient()
    private init() {}

    /// Possible locations for the aerospace binary.
    private static let binaryPaths = [
        "/opt/homebrew/bin/aerospace",
        "/usr/local/bin/aerospace",
        "/usr/bin/aerospace",
    ]

    private static let binaryURL: URL? = binaryPaths
        .map { URL(fileURLWithPath: $0) }
        .first { FileManager.default.isExecutableFile(atPath: $0.path) }

    public func run(args: [String]) async throws -> String {
        guard let url = Self.binaryURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = url
            process.arguments = args
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()  // suppress stderr
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
