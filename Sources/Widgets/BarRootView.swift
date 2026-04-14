import SwiftUI
import Monitors

// Reports whether center widgets fit on the right side of the built-in bar.
private struct CenterFitsRightKey: PreferenceKey {
    static let defaultValue = true
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = nextValue() }
}

public struct BarRootView: View {
    @EnvironmentObject private var config: ConfigLoader
    let isBuiltIn: Bool
    let monitorID: Int
    @State private var centerFitsRight = true

    public init(isBuiltIn: Bool, monitorID: Int) {
        self.isBuiltIn = isBuiltIn
        self.monitorID = monitorID
    }

    private var cfg: NanoConfig { config.config }
    private var bar: BarStyle    { BarStyle(cfg.bar) }

    public var body: some View {
        VStack(spacing: 0) {
            Group {
                if isBuiltIn { builtIn } else { external }
            }
            .fixedSize(horizontal: false, vertical: true)
            .background(barBackground)
            .padding(bar.margin)
            .environment(\.monitorID, monitorID)
            .environment(\.pillStyle, PillStyle(cfg.pill))
            .environment(\.barStyle, bar)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private var barBackground: some View {
        let shape = RoundedRectangle(cornerRadius: bar.cornerRadius, style: .continuous)
        ZStack {
            switch bar.background {
            case .none:                  Color.clear
            case .blur:                  shape.fill(.regularMaterial)
            case let .color(r, g, b, a): shape.fill(Color(red: r, green: g, blue: b, opacity: a))
            }
            if bar.border {
                shape.strokeBorder(bar.borderColor, lineWidth: bar.borderWidth)
            }
        }
        .shadow(color: bar.shadow ? .black.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
    }

    // MARK: - Widget dispatch

    @ViewBuilder
    private func widgetView(for id: String) -> some View {
        if let view = WidgetRegistry.shared.view(for: id) {
            view
        }
        // Unknown IDs: silently skip (error reported by ConfigLoader at load time).
    }

    @ViewBuilder
    private func zoneWidgets(_ ids: [String]) -> some View {
        ForEach(ids, id: \.self) { id in
            widgetView(for: id)
        }
    }

    // MARK: - Built-in layout (notch avoidance)

    private var builtIn: some View {
        HStack(spacing: 0) {
            HStack(spacing: Theme.itemGap) {
                zoneWidgets(cfg.widgets.left)
                Spacer(minLength: 0)
                if !centerFitsRight {
                    zoneWidgets(cfg.widgets.center)
                }
            }
            .padding(bar.padding)

            Spacer().frame(width: Theme.notchWidth)

            HStack(spacing: Theme.itemGap) {
                Spacer(minLength: 0)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Theme.itemGap) {
                        zoneWidgets(cfg.widgets.center)
                        zoneWidgets(cfg.widgets.right)
                    }
                    .preference(key: CenterFitsRightKey.self, value: true)

                    HStack(spacing: Theme.itemGap) {
                        zoneWidgets(cfg.widgets.right)
                    }
                    .preference(key: CenterFitsRightKey.self, value: false)
                }
            }
            .padding(bar.padding)
            .onPreferenceChange(CenterFitsRightKey.self) { centerFitsRight = $0 }
        }
    }

    // MARK: - External layout (center widgets centered)

    private var external: some View {
        ZStack {
            zoneWidgets(cfg.widgets.center)
            HStack(spacing: Theme.itemGap) {
                zoneWidgets(cfg.widgets.left)
                Spacer()
            }
            HStack(spacing: Theme.itemGap) {
                Spacer()
                zoneWidgets(cfg.widgets.right)
            }
        }
        .padding(bar.padding)
    }
}
