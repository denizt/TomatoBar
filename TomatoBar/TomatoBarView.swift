import SwiftUI

public struct TomatoBarView: View {
    @ObservedObject var timer = TomatoBarTimer()

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                timer.startStopAction()
                AppDelegate.shared.closePopover(nil)
            } label: {
                Text(timer.startStopString)
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .padding(.top, 4)
            Divider()
            Toggle(isOn: $timer.stopAfterBreak) {
                Text("Stop after break").frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
            Toggle(isOn: $timer.displayInMenuBar) {
                Text("Display timer in menu bar").frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
                .onChange(of: timer.displayInMenuBar) { _ in
                    timer.toggleMenuBar()
                }
            Group {
                Stepper(value: $timer.workIntervalLength, in: 1...60) {
                    Text("Work interval:").frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(timer.workIntervalLength) min")
                }
                Stepper(value: $timer.shortRestInterval, in: 1...60) {
                    Text("Short rest interval:").frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(timer.shortRestInterval) min")
                }
                Stepper(value: $timer.longRestInterval, in: 1...60) {
                    Text("Long rest interval:").frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(timer.longRestInterval) min")
                }
                Stepper(value: $timer.shortToLongBreakCounter, in: 1...3) {
                    Text("Short rest count:").frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(timer.shortToLongBreakCounter) times").onChange(of: timer.shortToLongBreakCounter) { _ in
                        timer.updateBreakCounter()
                    }
                }
                // Text("Remaining short breaks: \(timer.shortToLongBreakCounterLocal)")
            }
            Divider()
            Text("Sounds:")
            HStack {
                Toggle("Windup", isOn: $timer.isWindupEnabled)
                Spacer()
                Toggle("Ding", isOn: $timer.isDingEnabled)
                Spacer()
                Toggle("Ticking", isOn: $timer.isTickingEnabled)
                    .onChange(of: timer.isTickingEnabled) { _ in
                        timer.toggleTickingAction()
                    }
            }
            Button {
                NSApplication.shared.terminate(self)
            } label: {
                Text("Quit")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .padding(.bottom, 4)
        }
        .padding(12)
    }
}
