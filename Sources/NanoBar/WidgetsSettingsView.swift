import SwiftUI
import Monitors
import Widgets
import NanoBarPluginAPI

// MARK: - WidgetsDetailView

struct WidgetsDetailView: View {
    @ObservedObject private var loader = ConfigLoader.shared
    @State private var zones = WidgetZoneState()
    /// Tracks the currently hovered drop target as "zone:widgetID" or "zone:_empty".
    @State private var dropTarget: String? = nil

    private var allPluginIDs: [String] { PluginLoader.shared.pluginSchemas.map(\.pluginID) }
    private var available: [PluginSchema] {
        let ids = zones.available(from: allPluginIDs)
        return PluginLoader.shared.pluginSchemas.filter { ids.contains($0.pluginID) }
    }

    var body: some View {
        Form {
            zoneSection("Left",   key: "left",   items: zones.left)
            zoneSection("Center", key: "center", items: zones.center)
            zoneSection("Right",  key: "right",  items: zones.right)

            if !available.isEmpty {
                Section("Available") {
                    ForEach(available, id: \.pluginID) { schema in
                        HStack {
                            Text(schema.displayName)
                            Spacer()
                            Menu {
                                Button("Add to Left")   { commitAdd(schema.pluginID, to: "left")   }
                                Button("Add to Center") { commitAdd(schema.pluginID, to: "center") }
                                Button("Add to Right")  { commitAdd(schema.pluginID, to: "right")  }
                            } label: {
                                Label("Add to zone", systemImage: "plus.circle")
                                    .labelStyle(.titleAndIcon)
                            }
                            .buttonStyle(.borderless)
                            .fixedSize()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Widgets")
        .onAppear { syncFromConfig() }
        .onChange(of: loader.config.widgets.left)   { _, v in zones.left   = v }
        .onChange(of: loader.config.widgets.center) { _, v in zones.center = v }
        .onChange(of: loader.config.widgets.right)  { _, v in zones.right  = v }
    }

    // MARK: - Zone section

    @ViewBuilder
    private func zoneSection(_ label: String, key: String, items: [String]) -> some View {
        Section(label) {
            ForEach(items, id: \.self) { id in
                let targetKey = "\(key):\(id)"
                WidgetRow(
                    displayName: displayName(for: id),
                    canMoveUp:   items.first != id,
                    canMoveDown: items.last  != id,
                    onMoveUp:    { commitMove { $0.moveUp(id,   in: key) } },
                    onMoveDown:  { commitMove { $0.moveDown(id, in: key) } },
                    onRemove:    { commitMove { $0.remove(id,   from: key) } },
                    onMoveTo:    { dest in commitMove { $0.moveBetween(id, from: key, to: dest) } }
                )
                .draggable(id)
                .dropDestination(for: String.self) { dropped, _ in
                    dropTarget = nil
                    return drop(dropped, before: id, in: key)
                } isTargeted: { isOver in
                    // Guard against the A→nil→B flicker when drag moves between rows.
                    if isOver { dropTarget = targetKey }
                    else if dropTarget == targetKey { dropTarget = nil }
                }
                // Insertion line: shown above the targeted row
                .overlay(alignment: .top) {
                    if dropTarget == targetKey {
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(height: 2)
                            .padding(.horizontal, 8)
                            .offset(y: -1)
                            .allowsHitTesting(false)
                    }
                }
            }

            // Empty zone — shows a dashed border when a drag hovers over it
            if items.isEmpty {
                let emptyKey = "\(key):_empty"
                Text("Drop here")
                    .foregroundStyle(dropTarget == emptyKey ? Color.accentColor : Color.secondary.opacity(0.5))
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                dropTarget == emptyKey ? Color.accentColor : Color.secondary.opacity(0.3),
                                style: StrokeStyle(lineWidth: dropTarget == emptyKey ? 2 : 1, dash: [6])
                            )
                    )
                    .padding(.vertical, 2)
                    .draggable("__placeholder__")  // prevents drop on self
                    .dropDestination(for: String.self) { dropped, _ in
                        dropTarget = nil
                        guard let draggedID = dropped.first,
                              let src = zoneContaining(draggedID) else { return false }
                        zones.moveBetween(draggedID, from: src, to: key)
                        writeAll(); return true
                    } isTargeted: { isOver in
                        if isOver { dropTarget = emptyKey }
                        else if dropTarget == emptyKey { dropTarget = nil }
                    }
            }
        }
    }

    // MARK: - Drop logic

    /// Insert the dragged widget before `targetID` in zone `key`.
    /// Handles both same-zone reorder and cross-zone move.
    @discardableResult
    private func drop(_ droppedIDs: [String], before targetID: String, in key: String) -> Bool {
        guard let draggedID = droppedIDs.first, draggedID != targetID else { return false }
        let source = zoneContaining(draggedID) ?? key

        // Remove from source
        zones.remove(draggedID, from: source)

        // Insert before targetID in destination zone
        var dest = zones[key]
        let insertIdx = dest.firstIndex(of: targetID) ?? dest.endIndex
        dest.insert(draggedID, at: insertIdx)
        zones.mutateZone(key, to: dest)

        writeAll()
        return true
    }

    private func zoneContaining(_ id: String) -> String? {
        if zones.left.contains(id)   { return "left"   }
        if zones.center.contains(id) { return "center" }
        if zones.right.contains(id)  { return "right"  }
        return nil
    }

    // MARK: - Mutations

    private func commitMove(_ transform: (inout WidgetZoneState) -> Void) {
        transform(&zones)
        writeAll()
    }

    private func commitAdd(_ id: String, to zone: String) {
        zones.add(id, to: zone)
        write(key: zone, ids: zones[zone])
    }

    private func writeAll() {
        write(key: "left",   ids: zones.left)
        write(key: "center", ids: zones.center)
        write(key: "right",  ids: zones.right)
    }

    private func write(key: String, ids: [String]) {
        ConfigLoader.shared.write(section: "widgets", key: key, value: .stringArray(ids))
    }

    // MARK: - Helpers

    private func syncFromConfig() {
        let w = loader.config.widgets
        zones = WidgetZoneState(left: w.left, center: w.center, right: w.right)
    }

    private func displayName(for pluginID: String) -> String {
        PluginLoader.shared.pluginSchemas
            .first(where: { $0.pluginID == pluginID })?
            .displayName
            ?? pluginID.split(separator: "_").map(\.localizedCapitalized).joined(separator: " ")
    }
}

// MARK: - WidgetRow

private struct WidgetRow: View {
    let displayName: String
    let canMoveUp:   Bool
    let canMoveDown: Bool
    let onMoveUp:    () -> Void
    let onMoveDown:  () -> Void
    let onRemove:    () -> Void
    let onMoveTo:    (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .frame(width: 16)

            Text(displayName)

            Spacer()

            HStack(spacing: 0) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up").frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .disabled(!canMoveUp)

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down").frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .disabled(!canMoveDown)
            }

            Menu {
                Button("Move to Left")   { onMoveTo("left")   }
                Button("Move to Center") { onMoveTo("center") }
                Button("Move to Right")  { onMoveTo("right")  }
                Divider()
                Button("Remove", role: .destructive) { onRemove() }
            } label: {
                Image(systemName: "ellipsis").frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}
