import SwiftUI
import Monitors

public struct NowPlayingView: View {
    let info: NowPlayingInfo

    public init(info: NowPlayingInfo) { self.info = info }

    private var fullText: String {
        var t = info.title ?? ""
        if let artist = info.artist, !artist.isEmpty { t += " — " + artist }
        return t
    }

    @ViewBuilder
    public var body: some View {
        if info.title != nil {
            HStack(spacing: Theme.iconPadRight + Theme.labelPadLeft) {
                Image(systemName: info.isPlaying ? "play.fill" : "pause.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Theme.nowPlayingIconSize, height: Theme.nowPlayingIconSize)
                    .foregroundStyle(info.isPlaying ? Theme.spotifyActive : Theme.spotifyPaused)
                    .contentTransition(.symbolEffect(.replace))

                MarqueeText(text: fullText, maxWidth: 180)
            }
            .glassPill()
            .animation(.default, value: info.isPlaying)
        }
    }
}

// MARK: - Marquee text

private struct MarqueeText: View {
    let text: String
    let maxWidth: CGFloat

    @State private var textWidth: CGFloat = 0
    @State private var animOffset: CGFloat = 0
    @State private var scrollTask: Task<Void, Never>?

    private static let speed:    CGFloat = 30   // px/sec
    private static let pauseEnd: Double  = 3.0 // pause at each end before reversing
    private static let nsFont: NSFont = NSFont(name: "SF Pro Semibold", size: Theme.labelSize)
        ?? NSFont.systemFont(ofSize: Theme.labelSize, weight: .semibold)
    private static let suiFont: Font = .system(size: Theme.labelSize, weight: .semibold)

    private var needsScroll: Bool { textWidth > maxWidth }
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
        .onAppear {
            textWidth = measure(text)
            startScroll()
        }
        .onChange(of: text) { _, new in
            textWidth = measure(new)
            startScroll()
        }
        .onDisappear { scrollTask?.cancel() }
    }

    private var label: some View {
        Text(text)
            .font(Self.suiFont)
            .foregroundStyle(Theme.labelColor)
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
