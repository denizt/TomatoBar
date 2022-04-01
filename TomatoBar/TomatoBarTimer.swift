import AppKit
import Foundation
import SwiftState
import SwiftUI
import UserNotifications

let digitFont = NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular)

public class TomatoBarTimer: ObservableObject {
    @AppStorage("isWindupEnabled") public var isWindupEnabled = true
    @AppStorage("isDingEnabled") public var isDingEnabled = true
    @AppStorage("isTickingEnabled") public var isTickingEnabled = true
    @AppStorage("stopAfterBreak") public var stopAfterBreak = false
    @AppStorage("displayInMenuBar") public var displayInMenuBar = true
    @AppStorage("workIntervalLength") public var workIntervalLength = 25
    @AppStorage("shortRestIntervalLength") public var shortRestInterval = 5
    @AppStorage("longRestIntervalLength") public var longRestInterval = 15
    @AppStorage("shortToLongBreakCounter") public var shortToLongBreakCounter = 3

    @Published var startStopString: String = "Start"

    public var shortToLongBreakCounterLocal = 0
    private var stateMachine = TomatoBarStateMachine(state: .ready)
    private var statusBarItem: NSStatusItem? {
        return AppDelegate.shared.statusBarItem
    }

    private let player = TomatoBarPlayer()
    private var timeLeftSeconds: Int = 0
    private var timer: DispatchSourceTimer?

    init() {
        /*
         * State diagram
         *
         *                               start/stop
         *                     +--------------+-------------+
         *                     |              |             |
         *       viewDidLoad   |  start/stop  |  timerFired |
         *            |        V    |         |    |        |
         * +--------+ |  +--------+ |  +--------+  | +--------+
         * | ready  |--->| idle   |--->| work   |--->| rest   |
         * +--------+    +--------+    +--------+    +--------+
         *                 A                  A        |    |
         *                 |                  |        |    |
         *                 |                  +--------+    |
         *                 |  timerFired (!stopAfterBreak)  |
         *                 |                                |
         *                 +--------------------------------+
         *                    timerFired (stopAfterBreak)
         *
         */
        updateBreakCounter()
        stateMachine.addRoute(.ready => .idle)
        stateMachine.addRoutes(event: .startStop, transitions: [
            .idle => .work, .work => .idle, .rest => .idle,
        ])
        stateMachine.addRoutes(event: .timerFired, transitions: [.work => .rest])
        stateMachine.addRoutes(event: .timerFired, transitions: [.rest => .idle]) { _ in
            self.stopAfterBreak
        }
        stateMachine.addRoutes(event: .timerFired, transitions: [.rest => .work]) { _ in
            !self.stopAfterBreak
        }

        /*
         * "Finish" handlers are called when time interval ended
         * "End"    handlers are called when time interval ended or was cancelled
         */
        stateMachine.addAnyHandler(.any => .work, handler: onWorkStart)
        stateMachine.addAnyHandler(.work => .rest, order: 0, handler: onWorkFinish)
        stateMachine.addAnyHandler(.work => .any, order: 1, handler: onWorkEnd)
        stateMachine.addAnyHandler(.any => .rest, handler: onRestStart)
        stateMachine.addAnyHandler(.rest => .work, handler: onRestFinish)
        stateMachine.addAnyHandler(.any => .idle, handler: onIdleStart)

        stateMachine.addErrorHandler { ctx in fatalError("state machine context: <\(ctx)>") }

        stateMachine <- .idle
    }

    public func startStopAction() {
        stateMachine <-! .startStop
    }

    public func toggleTickingAction() {
        if stateMachine.state == .work {
            player.toggleTicking()
        }
    }

    public func updateBreakCounter() {
        // keeping logic simple, we might want to change it so it 'updates' count
        // but it seems overly complex or I am missing something
        shortToLongBreakCounterLocal = shortToLongBreakCounter
    }

    public func toggleMenuBar() {
        if self.displayInMenuBar {
            self.updateTimeInMenuBar()
        } else {
            self.statusBarItem?.button?.attributedTitle = NSAttributedString(string: "")
        }
    }

    private func startTimer(seconds: Int) {
        startStopString = "Stop"

        timeLeftSeconds = seconds

        let queue = DispatchQueue(label: "Timer")
        timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        timer?.schedule(deadline: .now(), repeating: .seconds(1), leeway: .never)
        timer?.setEventHandler(handler: onTimerTick)
        timer?.resume()
    }

    private func updateTimeInMenuBar() {
        let buttonTitle = NSAttributedString(
            string: String(
            format: " %.2i:%.2i",
            self.timeLeftSeconds / 60,
            self.timeLeftSeconds % 60
        ),
            attributes: [NSAttributedString.Key.font: digitFont]
        )
        self.statusBarItem?.button?.attributedTitle = buttonTitle
    }

    private func onTimerTick() {
        timeLeftSeconds -= 1
        DispatchQueue.main.async {
            if self.timeLeftSeconds >= 0 {
                if self.displayInMenuBar {
                    self.updateTimeInMenuBar()
                }
            } else {
                self.stateMachine <-! .timerFired
            }
        }
    }

    private func onWorkStart(context _: TomatoBarContext) {
        if isWindupEnabled {
            player.playWindup()
        }
        if isTickingEnabled {
            player.startTicking()
        }
        startTimer(seconds: workIntervalLength * 60)
    }

    private func onWorkFinish(context _: TomatoBarContext) {
        if shortToLongBreakCounterLocal == 0 {
            sendNotification(title: "Time's up", body: "It's time for a long break!")
        } else {
            sendNotification(title: "Time's up", body: "It's time for a break!")
        }
        if isDingEnabled {
            player.playDing()
        }
    }

    private func onWorkEnd(context _: TomatoBarContext) {
        player.stopTicking()
    }

    private func onRestStart(context _: TomatoBarContext) {
        if shortToLongBreakCounterLocal > 0 {
            startTimer(seconds: shortRestInterval * 60)
            shortToLongBreakCounterLocal -= 1
        } else {
            startTimer(seconds: longRestInterval * 60)
            shortToLongBreakCounterLocal = shortToLongBreakCounter
        }
    }

    private func onRestFinish(context _: TomatoBarContext) {
        sendNotification(title: "Break is over", body: "Keep up the good work!")
    }

    private func onIdleStart(context _: TomatoBarContext) {
        startStopString = "Start"
        statusBarItem?.button?.title = ""

        if timer != nil {
            timer?.cancel()
            timer = nil
        }
    }

    private func sendNotification(title: String, body: String) {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.getNotificationSettings { settings in
            if settings.authorizationStatus != .authorized ||
                settings.alertSetting != .enabled
            {
                return
            }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            notificationCenter.add(request) { error in
                if error != nil {
                    print("Error adding notification: \(error!)")
                }
            }
        }
    }
}
