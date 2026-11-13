import AppKit
import IOKit.pwr_mgt
import SwiftUI

@MainActor
final class AwakeLoopController: ObservableObject {
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "isEnabled")
            updateActivity()
        }
    }

    @Published var intervalSeconds: Int {
        didSet {
            UserDefaults.standard.set(intervalSeconds, forKey: "intervalSeconds")
            if isEnabled {
                restartTimer()
            }
        }
    }

    @Published private(set) var sleepPreventionAvailable = true
    @Published private(set) var cursorMovementAvailable = true

    private var timer: Timer?
    private var assertionID: IOPMAssertionID = 0
    private var nudgeDirection: CGFloat = 1

    init() {
        let defaults = UserDefaults.standard
        let savedInterval: Int
        if let seconds = defaults.object(forKey: "intervalSeconds") as? Int {
            savedInterval = max(1, seconds)
        } else {
            let minutes = defaults.object(forKey: "intervalMinutes") as? Int ?? 5
            savedInterval = max(1, minutes * 60)
        }
        intervalSeconds = savedInterval
        defaults.set(savedInterval, forKey: "intervalSeconds")
        isEnabled = UserDefaults.standard.bool(forKey: "isEnabled")
        if isEnabled {
            updateActivity()
        }
    }

    var intervalHours: Int { intervalSeconds / 3600 }
    var intervalMinutes: Int { (intervalSeconds % 3600) / 60 }
    var intervalRemainderSeconds: Int { intervalSeconds % 60 }

    func setInterval(hours: Int? = nil, minutes: Int? = nil, seconds: Int? = nil) {
        let newHours = hours ?? intervalHours
        let newMinutes = minutes ?? intervalMinutes
        let newSeconds = seconds ?? intervalRemainderSeconds
        intervalSeconds = max(1, newHours * 3600 + newMinutes * 60 + newSeconds)
    }

    private func updateActivity() {
        if isEnabled {
            acquireSleepAssertion()
            nudgeCursor()
            restartTimer()
        } else {
            timer?.invalidate()
            timer = nil
            releaseSleepAssertion()
        }
    }

    private func restartTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalSeconds), repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.nudgeCursor()
            }
        }
    }

    private func nudgeCursor() {
        guard let currentPosition = CGEvent(source: nil)?.location else { return }
        let destination = CGPoint(x: currentPosition.x + nudgeDirection * 12, y: currentPosition.y)
        cursorMovementAvailable = CGWarpMouseCursorPosition(destination) == .success
        nudgeDirection *= -1
    }

    func testCursorMovement() {
        nudgeCursor()
    }

    private func acquireSleepAssertion() {
        guard assertionID == 0 else { return }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoIdleSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "AwakeLoop is enabled" as CFString,
            &assertionID
        )
        sleepPreventionAvailable = result == kIOReturnSuccess
    }

    private func releaseSleepAssertion() {
        guard assertionID != 0 else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        sleepPreventionAvailable = true
    }
}

@main
struct AwakeLoopApp: App {
    @StateObject private var controller = AwakeLoopController()

    var body: some Scene {
        MenuBarExtra {
            ControlPanel(controller: controller)
        } label: {
            Label("AwakeLoop", systemImage: controller.isEnabled ? "cursorarrow.motionlines" : "cursorarrow")
        }
        .menuBarExtraStyle(.window)
    }
}

struct ControlPanel: View {
    @ObservedObject var controller: AwakeLoopController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "moon.zzz")
                    .foregroundStyle(controller.isEnabled ? .green : .secondary)
                Text("AwakeLoop")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(controller.isEnabled ? Color.green : Color.secondary.opacity(0.45))
                    .frame(width: 8, height: 8)
            }

            Toggle("保持 Mac 喚醒", isOn: $controller.isEnabled)

            VStack(alignment: .leading, spacing: 6) {
                Text("游標移動間隔")
                HStack(spacing: 4) {
                    intervalPicker(title: "時", range: 0..<24, selection: controller.intervalHours) {
                        controller.setInterval(hours: $0)
                    }
                    Text("時")
                    intervalPicker(title: "分", range: 0..<60, selection: controller.intervalMinutes) {
                        controller.setInterval(minutes: $0)
                    }
                    Text("分")
                    intervalPicker(title: "秒", range: 0..<60, selection: controller.intervalRemainderSeconds) {
                        controller.setInterval(seconds: $0)
                    }
                    Text("秒")
                }
            }

            if !controller.cursorMovementAvailable {
                Label("無法移動游標", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if controller.isEnabled && !controller.sleepPreventionAvailable {
                Label("無法啟用防止睡眠", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text(controller.isEnabled ? "防止閒置睡眠中" : "目前未啟用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: controller.testCursorMovement) {
                Label("立即測試", systemImage: "cursorarrow.motionlines")
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 280)
    }

    private func intervalPicker(title: String, range: Range<Int>, selection: Int, onSelect: @escaping (Int) -> Void) -> some View {
        Picker(title, selection: Binding(get: { selection }, set: onSelect)) {
            ForEach(range, id: \.self) { value in
                Text(String(format: "%02d", value)).tag(value)
            }
        }
        .labelsHidden()
        .fixedSize()
    }
}