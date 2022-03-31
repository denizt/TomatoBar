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
            Stepper(value: $timer.workIntervalLength, in: 1 ... 60) {
                Text("Work interval:").frame(maxWidth: .infinity, alignment: .leading)
                Text("\(timer.workIntervalLength) min")
            }
            Stepper(value: $timer.restIntervalLength, in: 1 ... 60) {
                Text("Rest interval:").frame(maxWidth: .infinity, alignment: .leading)
                Text("\(timer.restIntervalLength) min")
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
