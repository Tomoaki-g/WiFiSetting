import Foundation

final class WiFiDemoStore {
    struct Network: Codable {
        let id: String
        let name: String
        let isSecure: Bool
    }

    private var state: WiFiSavedState
    private let storage: NetworkFileStorage

    var isEnabled: Bool { state.isEnabled }
    var connectedID: String? { state.connectedID }

    var connectedNetwork: Network? {
        state.networks.first { $0.id == connectedID }
    }

    convenience init() throws {
        try self.init(storage: NetworkFileStorage())
    }

    init(storage: NetworkFileStorage) throws {
        self.storage = storage
        var loadedState = try storage.loadState()
            ?? WiFiSavedState(networks: [], connectedID: nil, isEnabled: true)

        // 存在しないネットワークを接続先として復元しない。
        if !loadedState.networks.contains(where: { $0.id == loadedState.connectedID }) {
            loadedState.connectedID = nil
        }
        state = loadedState
    }

    static func normalizeNetworkName(_ text: String?) -> String? {
        guard let text else { return nil }
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    @discardableResult
    func addNetwork(name: String, isSecure: Bool) throws -> Bool {
        guard let name = Self.normalizeNetworkName(name) else { return false }

        let network = Network(id: UUID().uuidString, name: name, isSecure: isSecure)
        var updatedState = state
        updatedState.networks.append(network)
        try saveState(updatedState)
        return true
    }

    func setWiFiEnabled(_ isEnabled: Bool) throws {
        var updatedState = state
        updatedState.isEnabled = isEnabled
        try saveState(updatedState)
    }

    func connectToNetwork(id: String) throws {
        guard isEnabled, findNetwork(id: id) != nil else { return }
        var updatedState = state
        updatedState.connectedID = id
        try saveState(updatedState)
    }

    func removeNetwork(id: String) throws {
        var updatedState = state
        updatedState.networks.removeAll { $0.id == id }
        if updatedState.connectedID == id {
            updatedState.connectedID = nil
        }
        try saveState(updatedState)
    }

    var availableNetworks: [Network] {
        state.networks
            .filter { $0.id != connectedID }
            .sorted { $0.name < $1.name }
    }

    func findNetwork(id: String) -> Network? {
        state.networks.first { $0.id == id }
    }

    private func saveState(_ updatedState: WiFiSavedState) throws {
        // 保存できた場合だけメモリ内の状態を確定する。
        try storage.saveState(updatedState)
        state = updatedState
    }
}
