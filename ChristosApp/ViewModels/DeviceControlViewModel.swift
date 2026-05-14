import Foundation
import Combine

@MainActor
final class DeviceControlViewModel: ObservableObject {
    @Published var device: Device
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var volume: Int = 0
    @Published var isMuted = false
    @Published var isPoweredOn = false
    @Published var availableInputs: [String] = []
    @Published var installedApps: [AppInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastCommandFeedback: String?

    private var adapter: DeviceAdapter?
    private var feedbackClearTask: Task<Void, Never>?

    init(device: Device) {
        self.device = device
    }

    // MARK: - Connection

    func connect(historyManager: ConnectionHistoryManager) async {
        guard connectionStatus != .connected else { return }
        connectionStatus = .connecting
        errorMessage = nil

        do {
            let adp = AdapterFactory.make(for: device)
            adapter = adp
            try await adp.connect()
            connectionStatus = .connected
            device.connectionStatus = .connected
            historyManager.recordConnection(for: device)
            await loadDeviceState()
        } catch {
            connectionStatus = .error
            errorMessage = error.localizedDescription
        }
    }

    func disconnect(historyManager: ConnectionHistoryManager) {
        adapter?.disconnect()
        adapter = nil
        connectionStatus = .disconnected
        device.connectionStatus = .disconnected
        historyManager.recordDisconnection(deviceId: device.id)
    }

    // MARK: - Commands

    func send(_ command: DeviceCommand) {
        Task {
            guard let adapter else {
                errorMessage = "Not connected"
                return
            }
            do {
                try await adapter.send(command)
                showFeedback(command.displayName)
                await updateStateAfter(command)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func setVolume(_ newVolume: Int) {
        volume = newVolume
        send(.volumeSet(newVolume))
    }

    // MARK: - State Loading

    func loadDeviceState() async {
        guard let adapter else { return }
        async let vol   = try? adapter.getVolume()
        async let power = try? adapter.getPowerState()
        async let apps  = try? adapter.getInstalledApps()
        async let inputs = try? adapter.getAvailableInputs()

        let (v, p, a, i) = await (vol, power, apps, inputs)
        volume = v ?? 0
        isPoweredOn = p ?? false
        installedApps = a ?? AppInfo.presets
        availableInputs = i ?? []
    }

    // MARK: - Private

    private func updateStateAfter(_ command: DeviceCommand) async {
        switch command {
        case .mute, .muteToggle:  isMuted = true
        case .unmute:             isMuted = false
        case .powerOn:            isPoweredOn = true
        case .powerOff:           isPoweredOn = false
        case .volumeUp:           volume = min(100, volume + 5)
        case .volumeDown:         volume = max(0, volume - 5)
        default: break
        }
    }

    private func showFeedback(_ text: String) {
        lastCommandFeedback = text
        feedbackClearTask?.cancel()
        feedbackClearTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            lastCommandFeedback = nil
        }
    }
}
