import Testing
@testable import Monitors

@Suite("WidgetZoneState")
struct WidgetZoneStateTests {

    // MARK: - available

    @Test("available excludes widgets placed in any zone")
    func availableExcludesPlaced() {
        let state = WidgetZoneState(left: ["clock"], center: ["now_playing"], right: ["volume", "battery"])
        let all = ["clock", "now_playing", "volume", "battery", "keyboard", "workspaces"]
        #expect(state.available(from: all).sorted() == ["keyboard", "workspaces"])
    }

    @Test("available returns all when every zone is empty")
    func availableAllWhenEmpty() {
        let state = WidgetZoneState()
        #expect(state.available(from: ["clock", "battery"]) == ["clock", "battery"])
    }

    @Test("available returns empty when all plugins are placed")
    func availableEmptyWhenAllPlaced() {
        let state = WidgetZoneState(left: ["clock"], right: ["battery"])
        #expect(state.available(from: ["clock", "battery"]) == [])
    }

    // MARK: - moveUp

    @Test("moveUp swaps item with its predecessor")
    func moveUpSwaps() {
        var state = WidgetZoneState(right: ["a", "b", "c"])
        state.moveUp("b", in: "right")
        #expect(state.right == ["b", "a", "c"])
    }

    @Test("moveUp is a no-op when item is first")
    func moveUpNoopAtFirst() {
        var state = WidgetZoneState(right: ["a", "b"])
        state.moveUp("a", in: "right")
        #expect(state.right == ["a", "b"])
    }

    @Test("moveUp is a no-op when item is not found")
    func moveUpNoopWhenMissing() {
        var state = WidgetZoneState(right: ["a", "b"])
        state.moveUp("x", in: "right")
        #expect(state.right == ["a", "b"])
    }

    // MARK: - moveDown

    @Test("moveDown swaps item with its successor")
    func moveDownSwaps() {
        var state = WidgetZoneState(right: ["a", "b", "c"])
        state.moveDown("b", in: "right")
        #expect(state.right == ["a", "c", "b"])
    }

    @Test("moveDown is a no-op when item is last")
    func moveDownNoopAtLast() {
        var state = WidgetZoneState(right: ["a", "b"])
        state.moveDown("b", in: "right")
        #expect(state.right == ["a", "b"])
    }

    // MARK: - remove

    @Test("remove deletes item from zone")
    func removeDeletesItem() {
        var state = WidgetZoneState(right: ["a", "b", "c"])
        state.remove("b", from: "right")
        #expect(state.right == ["a", "c"])
    }

    @Test("remove is a no-op when item is not in zone")
    func removeNoopWhenMissing() {
        var state = WidgetZoneState(right: ["a", "b"])
        state.remove("x", from: "right")
        #expect(state.right == ["a", "b"])
    }

    // MARK: - add

    @Test("add appends item to zone")
    func addAppends() {
        var state = WidgetZoneState(right: ["a"])
        state.add("b", to: "right")
        #expect(state.right == ["a", "b"])
    }

    @Test("add works on each zone key")
    func addToEachZone() {
        var state = WidgetZoneState()
        state.add("x", to: "left");   #expect(state.left   == ["x"])
        state.add("y", to: "center"); #expect(state.center == ["y"])
        state.add("z", to: "right");  #expect(state.right  == ["z"])
    }

    // MARK: - moveBetween

    @Test("moveBetween removes from source and appends to destination")
    func moveBetween() {
        var state = WidgetZoneState(left: ["a", "b"], right: ["c"])
        state.moveBetween("a", from: "left", to: "right")
        #expect(state.left  == ["b"])
        #expect(state.right == ["c", "a"])
    }

    @Test("moveBetween center to left")
    func moveBetweenCenterToLeft() {
        var state = WidgetZoneState(left: ["a"], center: ["x"])
        state.moveBetween("x", from: "center", to: "left")
        #expect(state.center == [])
        #expect(state.left   == ["a", "x"])
    }
}
