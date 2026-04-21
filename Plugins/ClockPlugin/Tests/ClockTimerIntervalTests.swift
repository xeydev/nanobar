import Testing
@testable import ClockPlugin

// MARK: - User Journey
//
// As a user who configures format = "HH:mm:ss",
// I want the clock to update every second,
// so that the seconds counter is not frozen for up to 30 seconds.
//
// As a user with a minute-only format (the default),
// I want the clock to update every 30 seconds,
// so it is not refreshing more often than necessary.

@Suite("clockTimerInterval")
struct ClockTimerIntervalTests {

    @Test("minute-only format uses 30-second interval")
    func minuteFormatUses30s() {
        #expect(clockTimerInterval(for: "HH:mm") == 30.0)
    }

    @Test("default format uses 30-second interval")
    func defaultFormatUses30s() {
        #expect(clockTimerInterval(for: "EEE dd MMM HH:mm") == 30.0)
    }

    @Test("format with seconds component uses 1-second interval")
    func secondsFormatUses1s() {
        #expect(clockTimerInterval(for: "HH:mm:ss") == 1.0)
    }

    @Test("format with uppercase SS does not trigger second resolution")
    func uppercaseSSIsNotSeconds() {
        // "SS" is fractional seconds; only lowercase "ss" means clock seconds in DateFormatter.
        #expect(clockTimerInterval(for: "HH:mm:SS") == 30.0)
    }

    @Test("format with seconds embedded in longer pattern uses 1-second interval")
    func secondsEmbeddedInLongerPattern() {
        #expect(clockTimerInterval(for: "yyyy-MM-dd HH:mm:ss") == 1.0)
    }
}
