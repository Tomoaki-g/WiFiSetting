import Foundation

/// 本物のWi-Fiではなく、画面更新を確認するためのデータ。
final class WiFiDemoStore {
    struct Network {
        let id: String
        let name: String
        let isSecure: Bool
    }

    var isEnabled = true
    var connectedID: String? = "home"

    private var catalog = [
        Network(id: "home", name: "Home Wi-Fi", isSecure: true),
        Network(id: "office", name: "Office Network", isSecure: true),
        Network(id: "cafe", name: "Cafe Free Wi-Fi", isSecure: false),
        Network(id: "guest", name: "Guest Network", isSecure: true),
        Network(id: "library", name: "Library Wi-Fi", isSecure: false)
    ]

    var connectedNetwork: Network? {
        catalog.first { $0.id == connectedID }
    }

    func addNetwork(name: String, isSecure: Bool) {
        let network = Network(
            id: UUID().uuidString,
            name: name,
            isSecure: isSecure
        )
        catalog.append(network)
    }

    func removeNetwork(id: String) {
        catalog.removeAll { $0.id == id }

        if connectedID == id {
            connectedID = nil
        }
    }

    var availableNetworks: [Network] {
        return catalog
            .filter { $0.id != connectedID }
            .sorted { $0.name < $1.name }
    }

    func network(id: String) -> Network? { catalog.first { $0.id == id } }
}
