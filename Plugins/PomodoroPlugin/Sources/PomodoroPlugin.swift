import AppKit
import Foundation
import SwiftUI
import NanoBarPluginAPI

// MARK: - Phase

enum PomodoroPhase: Equatable {
    case idle, working, shortBreak, longBreak
}

extension PomodoroPhase: RawRepresentable {
    var rawValue: String {
        switch self {
        case .idle:       "idle"
        case .working:    "working"
        case .shortBreak: "shortBreak"
        case .longBreak:  "longBreak"
        }
    }
    init?(rawValue: String) {
        switch rawValue {
        case "idle":       self = .idle
        case "working":    self = .working
        case "shortBreak": self = .shortBreak
        case "longBreak":  self = .longBreak
        default:           return nil
        }
    }
}

// MARK: - State

private enum PersistenceKeys {
    static let phase               = "com.nanobar.pomodoro.phase"
    static let secondsRemaining    = "com.nanobar.pomodoro.secondsRemaining"
    static let completedPomodoros  = "com.nanobar.pomodoro.completedPomodoros"
}

@MainActor
final class PomodoroState: ObservableObject, @unchecked Sendable {
    @Published var phase: PomodoroPhase = .idle
    @Published var secondsRemaining: Int
    @Published var completedPomodoros: Int = 0
    @Published var isRunning: Bool = false
    @Published var isAlerting: Bool = false

    let workSecs: Int
    let shortBreakSecs: Int
    let longBreakSecs: Int
    let pomodorosForLong: Int

    private let defaults: UserDefaults

    nonisolated(unsafe) private var timer: DispatchSourceTimer?
    private var timerGeneration: Int = 0
    nonisolated(unsafe) private var alertSound: NSSound?

    init(workSecs: Int, shortBreakSecs: Int, longBreakSecs: Int, pomodorosForLong: Int,
         defaults: UserDefaults = .standard) {
        self.workSecs = workSecs
        self.shortBreakSecs = shortBreakSecs
        self.longBreakSecs = longBreakSecs
        self.pomodorosForLong = pomodorosForLong
        self.defaults = defaults
        self.secondsRemaining = workSecs

        // Restore persisted state
        if let phaseRaw = defaults.string(forKey: PersistenceKeys.phase),
           let savedPhase = PomodoroPhase(rawValue: phaseRaw) {
            self.phase = savedPhase
            self.secondsRemaining = defaults.integer(forKey: PersistenceKeys.secondsRemaining)
            self.completedPomodoros = defaults.integer(forKey: PersistenceKeys.completedPomodoros)
        }
    }

    deinit { timer?.cancel(); alertSound?.stop() }

    func toggle() {
        if isAlerting {
            stopAlert()
            save()
            return
        }
        switch (phase, isRunning) {
        case (.idle, _):
            phase = .working
            secondsRemaining = workSecs
            isRunning = true
            startTimer()
        case (_, true):
            isRunning = false
            stopTimer()
        case (_, false):
            isRunning = true
            startTimer()
        }
        save()
    }

    func reset() {
        stopAlert()
        stopTimer()
        phase = .idle
        secondsRemaining = workSecs
        isRunning = false
        completedPomodoros = 0
        save()
    }

    func skip() {
        guard phase != .idle else { return }
        stopAlert()
        stopTimer()
        transition()
        stopAlert() // skip should not ring
        save()
    }

    func tick() {
        guard isRunning else { return }
        guard secondsRemaining > 0 else { return }
        secondsRemaining -= 1
        if secondsRemaining == 0 {
            transition()
            save()
        } else {
            save()
        }
    }

    // MARK: - Private

    private func save() {
        defaults.set(phase.rawValue, forKey: PersistenceKeys.phase)
        defaults.set(secondsRemaining, forKey: PersistenceKeys.secondsRemaining)
        defaults.set(completedPomodoros, forKey: PersistenceKeys.completedPomodoros)
    }

    private func startAlert() {
        isAlerting = true
        let sound = NSSound(named: .init("Hero"))
        sound?.loops = true
        sound?.play()
        alertSound = sound
    }

    private func stopAlert() {
        isAlerting = false
        alertSound?.stop()
        alertSound = nil
    }

    private func startTimer() {
        stopTimer()
        let gen = timerGeneration
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + 1.0, repeating: 1.0, leeway: .milliseconds(50))
        t.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.timerGeneration == gen else { return }
                self.tick()
            }
        }
        t.resume()
        timer = t
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
        timerGeneration &+= 1
    }

    private func transition() {
        stopTimer()
        switch phase {
        case .idle:
            break
        case .working:
            completedPomodoros += 1
            if completedPomodoros % pomodorosForLong == 0 {
                phase = .longBreak
                secondsRemaining = longBreakSecs
            } else {
                phase = .shortBreak
                secondsRemaining = shortBreakSecs
            }
            isRunning = false
            startAlert()
        case .shortBreak, .longBreak:
            phase = .idle
            secondsRemaining = workSecs
            isRunning = false
            startAlert()
        }
    }
}

// MARK: - Session dots

private struct SessionDots: View {
    let filled: Int
    let total: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .frame(width: 4, height: 4)
                    .foregroundStyle(i < filled ? Color.primary.opacity(0.8) : Color.secondary.opacity(0.3))
            }
        }
    }
}

// MARK: - View

private struct PomodoroWidgetView: View {
    @ObservedObject var state: PomodoroState
    let workColor: Color
    let breakColor: Color
    @State private var hovered = false
    @State private var alertOffset: CGFloat = 0

    private var iconEmoji: String {
        switch state.phase {
        case .idle, .working:         "🍅"
        case .shortBreak, .longBreak: "☕️"
        }
    }

    private var timerText: String {
        let m = state.secondsRemaining / 60
        let s = state.secondsRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    // All dots filled during long break to indicate a completed cycle.
    private var dotsFilled: Int {
        guard state.pomodorosForLong > 0 else { return 0 }
        if state.phase == .longBreak { return state.pomodorosForLong }
        return state.completedPomodoros % state.pomodorosForLong
    }

    var body: some View {
        HStack(spacing: Theme.iconLabelSpacing) {
            Text(iconEmoji)
                .font(.system(size: Theme.iconSize))
                .opacity(state.phase == .idle && !state.isAlerting ? 0.5 : 1.0)
            Text(timerText)
                .font(.system(size: Theme.labelSize, weight: .semibold).monospacedDigit())
                .foregroundStyle(state.isRunning ? Theme.labelColor : Theme.grey)
                .stableMinWidth()
            SessionDots(filled: dotsFilled, total: state.pomodorosForLong)
        }
        .glassPill(hovered: hovered)
        .offset(x: alertOffset)
        .interactiveRegion()
        .onHover { hovered = $0 }
        .onTapGesture { state.toggle() }
        .contextMenu {
            Button("Reset") { state.reset() }
            Button("Skip") { state.skip() }
        }
        .onChange(of: state.isAlerting) { _, alerting in
            if alerting {
                alertOffset = -4
                withAnimation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true)) {
                    alertOffset = 4
                }
            } else {
                withAnimation(.spring(response: 0.2)) {
                    alertOffset = 0
                }
            }
        }
    }
}

// MARK: - Factory

final class PomodoroWidgetFactory: NSObject, NanoBarWidgetFactory {
    let state: PomodoroState
    private let workColor: Color
    private let breakColor: Color

    @MainActor init(config: [String: String], defaults: UserDefaults = .standard) {
        let workSecs         = Int((Double(config["work"]        ?? "25") ?? 25) * 60)
        let shortBreakSecs   = Int((Double(config["shortBreak"]  ?? "5")  ?? 5)  * 60)
        let longBreakSecs    = Int((Double(config["longBreak"]   ?? "15") ?? 15) * 60)
        let pomodorosForLong = max(1, Int(config["sessions"] ?? "4") ?? 4)
        self.workColor  = Theme.color(hex: config["workColor"])  ?? Color(red: 1.0, green: 0.420, blue: 0.420)
        self.breakColor = Theme.color(hex: config["breakColor"]) ?? Theme.spotifyActive
        self.state = PomodoroState(
            workSecs: workSecs,
            shortBreakSecs: shortBreakSecs,
            longBreakSecs: longBreakSecs,
            pomodorosForLong: pomodorosForLong,
            defaults: defaults
        )
    }

    var widgetID: String { "pomodoro" }

    @MainActor func makeViewBox() -> NanoBarViewBox {
        NanoBarViewBox(AnyView(PomodoroWidgetView(
            state: state,
            workColor: workColor,
            breakColor: breakColor
        )))
    }
}

// MARK: - Entry point

@objc(PomodoroPlugin)
public final class PomodoroPlugin: NSObject, NanoBarPluginEntry {
    public var pluginID: String { "pomodoro" }
    @MainActor public func registerWidgets(with registry: any NanoBarWidgetRegistry, config: [String: String]) {
        registry.register(PomodoroWidgetFactory(config: config))
    }
}
