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
    private var scanStep = 0

    private let catalog = [
        Network(id: "home", name: "Home Wi-Fi", isSecure: true),
        Network(id: "office", name: "Office Network", isSecure: true),
        Network(id: "cafe", name: "Cafe Free Wi-Fi", isSecure: false),
        Network(id: "guest", name: "Guest Network", isSecure: true),
        Network(id: "library", name: "Library Wi-Fi", isSecure: false)
    ]

    var connectedNetwork: Network? {
        catalog.first { $0.id == connectedID }
    }

    var availableNetworks: [Network] {
        // scan()が呼ばれるたびに、表示対象を３パターンで切り替える。各ネットワークのIDは固定。
        // availableNetworksの読み取りだけではパターンは進まない。５秒のTimerはViewController側で管理する。
        let visibleIDs: Set<String>
        switch scanStep % 3 {
        case 0: visibleIDs = ["home", "office", "cafe"]
        case 1: visibleIDs = ["home", "office", "guest", "library"]
        default: visibleIDs = ["home", "cafe", "guest"]
        }
        return catalog.filter { visibleIDs.contains($0.id) && $0.id != connectedID }
            .sorted { $0.name < $1.name }
    }

    func network(id: String) -> Network? { catalog.first { $0.id == id } }
    func scan() { scanStep += 1 }
}
