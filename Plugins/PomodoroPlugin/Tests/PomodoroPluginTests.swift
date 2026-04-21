import Foundation
import Testing
@testable import PomodoroPlugin

// MARK: - User Journeys
//
// As a user on any screen, I want the Pomodoro timer to be shared,
// so that starting/pausing/resetting on one screen affects all screens.
//
// As a user, I want the timer to count down accurately and transition
// phases immediately when time runs out, so there are no ghost alarms.
//
// As a user, I want reset to fully clear the timer state,
// so I can start fresh without leftover sounds or ticks.

// Convenience to build an isolated PomodoroState (no cross-test contamination)
@MainActor
private func makeState(workSecs: Int = 1500, shortBreakSecs: Int = 300,
                       longBreakSecs: Int = 900, pomodorosForLong: Int = 4) -> PomodoroState {
    PomodoroState(workSecs: workSecs, shortBreakSecs: shortBreakSecs,
                  longBreakSecs: longBreakSecs, pomodorosForLong: pomodorosForLong)
}

@MainActor
@Suite("PomodoroState — timer logic")
struct PomodoroStateTests {

    // MARK: Initial state

    @Test("starts idle with full work duration and no running timer")
    func initialState() {
        let state = makeState()
        #expect(state.phase == .idle)
        #expect(state.secondsRemaining == 1500)
        #expect(state.isRunning == false)
        #expect(state.isAlerting == false)
        #expect(state.completedPomodoros == 0)
    }

    // MARK: toggle

    @Test("toggle from idle transitions to working phase")
    func toggleFromIdleStartsWorking() {
        let state = makeState()
        state.toggle()
        #expect(state.phase == .working)
        #expect(state.secondsRemaining == 1500)
        #expect(state.isRunning == true)
    }

    @Test("toggle while running pauses without changing phase")
    func toggleWhileRunningPauses() {
        let state = makeState()
        state.toggle() // start
        state.toggle() // pause
        #expect(state.phase == .working)
        #expect(state.isRunning == false)
    }

    @Test("toggle while paused resumes")
    func toggleWhilePausedResumes() {
        let state = makeState()
        state.toggle() // start
        state.toggle() // pause
        state.toggle() // resume
        #expect(state.isRunning == true)
        #expect(state.phase == .working)
    }

    @Test("toggle while alerting silences alarm without starting break")
    func toggleWhileAlertingSilences() {
        let state = makeState(workSecs: 1)
        state.toggle()
        state.tick()   // decrement to 0 → transition → shortBreak + alert
        #expect(state.isAlerting == true)
        state.toggle() // silence only
        #expect(state.isAlerting == false)
        #expect(state.isRunning == false) // break not started yet
        #expect(state.phase == .shortBreak)
    }

    // MARK: reset

    @Test("reset from working returns to idle and clears all state")
    func resetFromWorking() {
        let state = makeState()
        state.toggle()
        state.reset()
        #expect(state.phase == .idle)
        #expect(state.secondsRemaining == 1500)
        #expect(state.isRunning == false)
        #expect(state.isAlerting == false)
        #expect(state.completedPomodoros == 0)
    }

    @Test("reset clears completed pomodoro count")
    func resetClearsCompletedPomodoros() {
        let state = makeState(workSecs: 1)
        state.toggle()
        state.tick()   // complete work session → completedPomodoros = 1
        #expect(state.completedPomodoros == 1)
        state.reset()
        #expect(state.completedPomodoros == 0)
    }

    @Test("reset while alerting stops the alarm")
    func resetWhileAlertingStopsAlarm() {
        let state = makeState(workSecs: 1)
        state.toggle()
        state.tick()   // → alarm
        #expect(state.isAlerting == true)
        state.reset()
        #expect(state.isAlerting == false)
        #expect(state.phase == .idle)
    }

    // MARK: skip

    @Test("skip from idle does nothing")
    func skipFromIdleIsNoop() {
        let state = makeState()
        state.skip()
        #expect(state.phase == .idle)
        #expect(state.isAlerting == false)
    }

    @Test("skip from working advances to short break without alerting")
    func skipFromWorkingAdvancesToShortBreak() {
        let state = makeState()
        state.toggle()
        state.skip()
        #expect(state.phase == .shortBreak)
        #expect(state.secondsRemaining == 300)
        #expect(state.isAlerting == false)
        #expect(state.isRunning == false)
    }

    @Test("skip from short break returns to idle without alerting")
    func skipFromShortBreakReturnsToIdle() {
        let state = makeState()
        state.toggle()
        state.skip() // working → shortBreak
        state.skip() // shortBreak → idle
        #expect(state.phase == .idle)
        #expect(state.secondsRemaining == 1500)
        #expect(state.isAlerting == false)
    }

    // MARK: tick

    @Test("tick decrements secondsRemaining by one")
    func tickDecrements() {
        let state = makeState()
        state.toggle()
        state.tick()
        #expect(state.secondsRemaining == 1499)
    }

    @Test("tick does nothing when paused")
    func tickWhilePausedDoesNothing() {
        let state = makeState()
        state.toggle() // start
        state.toggle() // pause — isRunning = false
        state.tick()
        #expect(state.secondsRemaining == 1500)
        #expect(state.phase == .working)
    }

    @Test("tick at 1 second immediately transitions to break (no dangling zero window)")
    func tickAtOneSecondTransitionsImmediately() {
        let state = makeState(workSecs: 1)
        state.toggle()   // secondsRemaining = 1, isRunning = true
        state.tick()     // decrement → 0 → transition() fires immediately
        #expect(state.phase == .shortBreak)
        #expect(state.secondsRemaining == 300) // reset to shortBreakSecs
        #expect(state.isAlerting == true)
        #expect(state.isRunning == false)
        #expect(state.completedPomodoros == 1)
    }

    @Test("tick when secondsRemaining is 0 is a noop (no spurious alarm)")
    func tickAtZeroIsNoop() {
        let state = makeState()
        state.toggle()
        state.secondsRemaining = 0  // force zero to simulate stale state
        state.tick()
        #expect(state.phase == .working)    // no transition
        #expect(state.isAlerting == false)  // no alarm
    }

    @Test("tick after transition does nothing (isRunning = false)")
    func tickAfterTransitionIsNoop() {
        let state = makeState(workSecs: 1)
        state.toggle()
        state.tick()   // → shortBreak, isRunning = false
        let phaseSnapshot = state.phase
        let secsSnapshot = state.secondsRemaining
        state.tick()   // should do nothing (isRunning = false)
        #expect(state.phase == phaseSnapshot)
        #expect(state.secondsRemaining == secsSnapshot)
    }

    // MARK: Phase transitions

    @Test("4th completed work session triggers long break")
    func longBreakAfterFourPomodoros() {
        let state = makeState(workSecs: 1, shortBreakSecs: 1)
        for _ in 0..<3 {
            state.toggle()
            state.skip()  // working → shortBreak (silent)
            state.skip()  // shortBreak → idle
        }
        // completedPomodoros == 3
        state.toggle()
        state.skip()  // 4th → should be longBreak
        #expect(state.phase == .longBreak)
        #expect(state.secondsRemaining == 900)
        #expect(state.completedPomodoros == 4)
    }

    @Test("break completion via tick returns to idle with alert")
    func breakCompletionReturnsToIdle() {
        let state = makeState(workSecs: 1, shortBreakSecs: 1)
        state.toggle()
        state.tick()   // work done → shortBreak + alert, secondsRemaining = 1
        state.toggle() // silence alert
        state.toggle() // start break timer
        state.tick()   // break done → idle + alert, secondsRemaining = workSecs = 1
        #expect(state.phase == .idle)
        #expect(state.isAlerting == true)
        #expect(state.secondsRemaining == 1)
    }
}

// MARK: - Sharing tests

@MainActor
@Suite("PomodoroWidgetFactory — shared state")
struct PomodoroFactoryTests {

    @Test("factory stores state as a shared property")
    func factoryHasSharedState() {
        let factory = PomodoroWidgetFactory(config: [:])
        let s1 = factory.state
        let s2 = factory.state
        #expect(s1 === s2)
    }

    @Test("toggle on factory state is visible via second reference")
    func factoryStateIsShared() {
        let factory = PomodoroWidgetFactory(config: [:])
        let s1 = factory.state
        let s2 = factory.state
        s1.toggle()
        #expect(s2.phase == .working)
        #expect(s2.isRunning == true)
    }
}

