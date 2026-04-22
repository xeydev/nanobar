import Foundation
import SwiftUI
import NanoBarPluginAPI

// MARK: - Now-playing state

/// Launches NowPlayingHelper (next to the host executable) and parses its JSON lines.
@MainActor
private final class NowPlayingState: ObservableObject, @unchecked Sendable {
    @Published var title:     String? = nil
    @Published var artist:    String? = nil
    @Published var isPlaying: Bool    = false

    private var process:    Process?
    private var lineBuffer: String = ""

    init() { start() }
    deinit { process?.terminate() }

    private func start() {
        let exe       = URL(fileURLWithPath: CommandLine.arguments[0])
        let helperURL = exe.deletingLastPathComponent().appendingPathComponent("NowPlayingHelper")
        let proc      = Process()
        proc.executableURL = helperURL
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError  = Pipe()
        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1))
                self?.start()
            }
        }
        guard (try? proc.run()) != nil else { return }
        process = proc

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in self?.ingest(chunk) }
        }
    }

    private func ingest(_ chunk: String) {
        lineBuffer += chunk
        let parts = lineBuffer.components(separatedBy: "\n")
        lineBuffer = parts.last ?? ""
        for line in parts.dropLast() { parse(line) }
    }

    private func parse(_ line: String) {
        let s = line.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty,
              let data = s.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        let t = json["title"]  as? String
        let a = json["artist"] as? String
        let newTitle    = t.flatMap { $0.isEmpty ? nil : $0 }
        let newArtist   = a.flatMap { $0.isEmpty ? nil : $0 }
        let newPlaying  = (json["rate"] as? Double ?? 0) > 0
        if newTitle   != title     { title     = newTitle   }
        if newArtist  != artist    { artist    = newArtist  }
        if newPlaying != isPlaying { isPlaying = newPlaying }
    }
}

// MARK: - Marquee text

private struct MarqueeText: View {
    let text:     String
    let maxWidth: CGFloat

    @State private var textWidth:   CGFloat = 0
    @State private var animOffset:  CGFloat = 0
    @State private var scrollTask:  Task<Void, Never>?

    private static let speed:    CGFloat = 30
    private static let pauseEnd: Double  = 3.0
    private static let nsFont:   NSFont  = NSFont(name: "SF Pro Semibold", size: 12)
        ?? NSFont.systemFont(ofSize: 12, weight: .semibold)
    private static let suiFont:  Font    = .system(size: 12, weight: .semibold)

    private var needsScroll:    Bool    { textWidth > maxWidth }
    private var scrollDistance: CGFloat { textWidth - maxWidth }

    var body: some View {
        ZStack(alignment: .leading) {
            if needsScroll {
                label
                    .offset(x: -animOffset)
                    .frame(width: maxWidth, alignment: .leading)
                    .clipped()
                    .mask {
                        let fadeW: CGFloat = 14
                        let leftAlpha  = Double(min(animOffset / fadeW, 1))
                        let rightAlpha = Double(min((scrollDistance - animOffset) / fadeW, 1))
                        LinearGradient(
                            stops: [
                                .init(color: .black.opacity(1 - leftAlpha),  location: 0),
                                .init(color: .black,                          location: fadeW / maxWidth),
                                .init(color: .black,                          location: 1 - fadeW / maxWidth),
                                .init(color: .black.opacity(1 - rightAlpha), location: 1),
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    }
            } else {
                label.frame(width: maxWidth, alignment: .leading)
            }
        }
        .onAppear      { textWidth = measure(text); startScroll() }
        .onChange(of: text) { _, new in textWidth = measure(new); startScroll() }
        .onDisappear   { scrollTask?.cancel() }
    }

    private var label: some View {
        Text(text)
            .font(Self.suiFont)
            .foregroundStyle(Color.primary)
            .fixedSize()
    }

    private func measure(_ s: String) -> CGFloat {
        NSAttributedString(string: s, attributes: [.font: Self.nsFont]).size().width
    }

    private func startScroll() {
        scrollTask?.cancel()
        withAnimation(nil) { animOffset = 0 }
        guard needsScroll else { return }
        scrollTask = Task { @MainActor in
            while !Task.isCancelled && needsScroll {
                let dur = Double(scrollDistance) / Double(Self.speed)
                try? await Task.sleep(for: .seconds(Self.pauseEnd))
                guard !Task.isCancelled else { break }
                withAnimation(.linear(duration: dur)) { animOffset = scrollDistance }
                try? await Task.sleep(for: .seconds(dur))
                try? await Task.sleep(for: .seconds(Self.pauseEnd))
                guard !Task.isCancelled else { break }
                withAnimation(.linear(duration: dur)) { animOffset = 0 }
                try? await Task.sleep(for: .seconds(dur))
            }
        }
    }
}

// MARK: - Widget view

private struct SpotifyWidgetView: View {
    @StateObject private var state = NowPlayingState()
    let activeColor: Color

    private static let iconSize:  CGFloat = 12
    private static let spacing:   CGFloat = 8   // iconPadRight + labelPadLeft

    private var fullText: String {
        var t = state.title ?? ""
        if let a = state.artist, !a.isEmpty { t += " — " + a }
        return t
    }

    @ViewBuilder
    var body: some View {
        if state.title != nil {
            HStack(spacing: Self.spacing) {
                Image(systemName: state.isPlaying ? "play.fill" : "pause.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Self.iconSize, height: Self.iconSize)
                    .foregroundStyle(state.isPlaying ? activeColor : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                MarqueeText(text: fullText, maxWidth: 180)
            }
            .nanoPill()
            .animation(.default, value: state.isPlaying)
        }
    }
}

// MARK: - Factory

private final class SpotifyWidgetFactory: NSObject, NanoBarWidgetFactory {
    private let config: [String: String]
    init(config: [String: String]) { self.config = config }

    var widgetID: String { "now_playing" }

    @MainActor func makeViewBox() -> NanoBarViewBox {
        NanoBarViewBox(AnyView(SpotifyWidgetView(activeColor: activeColor)))
    }

    private var activeColor: Color {
        Theme.color(hex: config["activeColor"]) ?? Theme.spotifyActive
    }
}

// MARK: - Entry point

@objc(SpotifyPlugin)
public final class SpotifyPlugin: NSObject, NanoBarPluginEntry {
    public var pluginID: String { "now_playing" }
    @MainActor public func registerWidgets(with registry: any NanoBarWidgetRegistry, config: [String: String]) {
        registry.register(SpotifyWidgetFactory(config: config))
    }
}
