import Foundation

/// Communicates with AeroSpace via its Unix domain socket.
/// Socket path: /tmp/bobko.aerospace-{username}.sock
public final class AeroSpaceClient: @unchecked Sendable {
    public static let shared = AeroSpaceClient()

    private let socketPath: String

    private init() {
        socketPath = "/tmp/bobko.aerospace-\(NSUserName()).sock"
    }

    /// Send a command to AeroSpace and return stdout.
    public func run(args: [String]) async throws -> String {
        struct Request: Encodable {
            let args: [String]
            let stdin: String = ""
        }
        struct Response: Decodable {
            let exitCode: Int
            let stdout: String
            let stderr: String
        }

        let payload = try JSONEncoder().encode(Request(args: args))
        let responseData = try await sendRaw(payload)
        let response = try JSONDecoder().decode(Response.self, from: responseData)
        return response.stdout
    }

    private func sendRaw(_ data: Data) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            let queue = DispatchQueue.global(qos: .userInteractive)
            queue.async {
                do {
                    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
                    guard fd >= 0 else { throw NSError(domain: "AeroSpace", code: 1) }
                    defer { close(fd) }

                    var addr = sockaddr_un()
                    addr.sun_family = sa_family_t(AF_UNIX)
                    let path = self.socketPath
                    withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
                        path.withCString { cStr in
                            _ = strncpy(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self),
                                        cStr, 104)
                        }
                    }

                    let connectResult = withUnsafePointer(to: addr) { ptr in
                        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                            connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
                        }
                    }
                    guard connectResult == 0 else { throw NSError(domain: "AeroSpace", code: 2) }

                    // Write request
                    _ = data.withUnsafeBytes { write(fd, $0.baseAddress!, $0.count) }

                    // Read response
                    var result = Data()
                    var buf = [UInt8](repeating: 0, count: 4096)
                    while true {
                        let n = recv(fd, &buf, buf.count, 0)
                        if n <= 0 { break }
                        result.append(contentsOf: buf[0..<n])
                    }

                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
