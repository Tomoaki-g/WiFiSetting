import UIKit

final class WiFiSettingsViewController: UIViewController, UITableViewDelegate {
    enum Section: Hashable { case configuration, networks }

    // Snapshotには項目の識別子を渡す。接続先が変わってもcurrentNetworkの識別子は同じ。
    enum Item: Hashable {
        case wifiToggle
        case currentNetwork
        case network(String)
    }

    private enum ReuseIdentifier {
        static let toggle = "WiFiToggleCell"
        static let network = "NetworkCell"
    }

    private let store: WiFiDemoStore
    private var tableView: UITableView!
    private var dataSource: WiFiTableDataSource!
    private var actionButtons: [UIBarButtonItem] = []

    init(store: WiFiDemoStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationBar()
        setupTableView()
        setupDataSource()
        refreshNetworkList(animated: false)
    }

    // MARK: - Layout

    private func setupNavigationBar() {
        title = "Wi-Fi"
        view.backgroundColor = .systemGroupedBackground

        let addButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(presentAddNetworkAlert)
        )
        addButton.accessibilityLabel = "追加"

        actionButtons = [addButton]
        navigationItem.rightBarButtonItems = actionButtons
    }

    private func setupTableView() {
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    // MARK: - Cell registrations

    private func setupDataSource() {
        tableView.register(WiFiToggleTableCell.self, forCellReuseIdentifier: ReuseIdentifier.toggle)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: ReuseIdentifier.network)

        dataSource = WiFiTableDataSource(tableView: tableView) { [weak self] tableView, indexPath, item in
            self?.dequeueConfiguredCell(in: tableView, at: indexPath, for: item)
        }
        
        dataSource.onDeleteNetwork = { [weak self] id in
            self?.deleteNetwork(id: id)
        }
        
        dataSource.defaultRowAnimation = .fade
    }

    private func dequeueConfiguredCell(in tableView: UITableView, at indexPath: IndexPath, for item: Item) -> UITableViewCell {
        if item == .wifiToggle {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: ReuseIdentifier.toggle, for: indexPath
            ) as! WiFiToggleTableCell
            
            cell.setWiFiSwitch(isOn: store.isEnabled)
            cell.onValueChanged = { [weak self] isEnabled in
                self?.setWiFiEnabled(isEnabled)
            }
            
            return cell
        }

        guard let network = findNetwork(for: item) else {
            preconditionFailure("SnapshotのネットワークIDに対応するデータがありません")
        }
        
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ReuseIdentifier.network, for: indexPath
        )
        
        configureNetworkCell(cell, network: network, isConnected: item == .currentNetwork)
        return cell
    }

    private func configureNetworkCell(
        _ cell: UITableViewCell, network: WiFiDemoStore.Network, isConnected: Bool
    ) {
        var content = cell.defaultContentConfiguration()
        content.text = network.name
        content.secondaryText = isConnected ? "接続中（デモ）" : nil
        content.image = UIImage(systemName: isConnected ? "checkmark" : (network.isSecure ? "lock.fill" : "wifi"))
        content.imageProperties.tintColor = isConnected ? .systemBlue : tableView.tintColor
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.numberOfLines = 0
        cell.contentConfiguration = content
        cell.accessoryType = .detailButton
    }

    private func findNetwork(for item: Item) -> WiFiDemoStore.Network? {
        switch item {
        case .currentNetwork:
            return store.connectedNetwork
        case .network(let id):
            return store.findNetwork(id: id)
        case .wifiToggle:
            return nil
        }
    }

    // MARK: - Snapshot

    private func makeNetworkListSnapshot() -> NSDiffableDataSourceSnapshot<Section, Item> {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.configuration])
        snapshot.appendItems([.wifiToggle], toSection: .configuration)
        
        if store.isEnabled {
            if store.connectedNetwork != nil {
                snapshot.appendItems([.currentNetwork], toSection: .configuration)
            }
            
            snapshot.appendSections([.networks])
            snapshot.appendItems(store.availableNetworks.map { .network($0.id) }, toSection: .networks)
        }
        
        return snapshot
    }

    private func refreshNetworkList(animated: Bool = true, reconfiguring items: [Item] = []) {
        var snapshot = makeNetworkListSnapshot()
        // 内容の変更は自動検出されないため、指定された既存項目だけを再構成する。
        let retainedItems = Set(dataSource.snapshot().itemIdentifiers)
            .intersection(snapshot.itemIdentifiers)
        snapshot.reconfigureItems(items.filter { retainedItems.contains($0) })
        dataSource.apply(snapshot, animatingDifferences: animated)
        actionButtons.forEach { $0.isEnabled = store.isEnabled }
    }

    // MARK: - Actions

    private func setWiFiEnabled(_ isEnabled: Bool) {
        do {
            try store.setWiFiEnabled(isEnabled)
            refreshNetworkList()
        } catch {
            // 操作済みのスイッチを、保存されている状態へ戻す。
            refreshNetworkList(reconfiguring: [.wifiToggle])
            presentSaveError(error)
        }
    }

    private func deleteNetwork(id: String) {
        guard store.isEnabled else { return }
        do {
            try store.removeNetwork(id: id)
            refreshNetworkList()
        } catch {
            presentSaveError(error)
        }
    }

    @objc private func presentAddNetworkAlert() {
        guard store.isEnabled else { return }

        let alert = UIAlertController(
            title: "ネットワークを追加",
            message: "名前とセキュリティの有無を指定してください。",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "ネットワーク名"
            textField.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))

        let secureAction = makeAddNetworkAction(isSecure: true, alert: alert)
        let openAction = makeAddNetworkAction(isSecure: false, alert: alert)
        alert.addAction(secureAction)
        alert.addAction(openAction)

        // 入力時と追加確定時に同じ名前の検証を使う。
        alert.textFields?.first?.addAction(
            UIAction { [weak secureAction, weak openAction] action in
                guard let textField = action.sender as? UITextField else { return }
                let hasValidName = WiFiDemoStore.normalizeNetworkName(textField.text) != nil
                secureAction?.isEnabled = hasValidName
                openAction?.isEnabled = hasValidName
            },
            for: .editingChanged
        )
        
        present(alert, animated: true)
    }

    private func makeAddNetworkAction(isSecure: Bool, alert: UIAlertController) -> UIAlertAction {
        let title = isSecure ? "セキュリティありで追加" : "セキュリティなしで追加"
        let action = UIAlertAction(title: title, style: .default) { [weak self, weak alert] _ in
            guard let self, self.store.isEnabled,
                  let name = alert?.textFields?.first?.text else { return }
            do {
                guard try self.store.addNetwork(name: name, isSecure: isSecure) else { return }
                self.refreshNetworkList()
            } catch {
                // 入力ダイアログを閉じてからエラーを表示する。
                self.dismiss(animated: true) {
                    self.presentSaveError(error)
                }
            }
        }
        action.isEnabled = false
        return action
    }

    private func presentNetworkDetailsAlert(for network: WiFiDemoStore.Network) {
        let alert = UIAlertController(title: network.name,
            message: network.isSecure ? "セキュリティあり（ダミーデータ）" : "オープンネットワーク（ダミーデータ）",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "閉じる", style: .cancel))
        present(alert, animated: true)
    }

    private func presentSaveError(_ error: Error) {
        let alert = UIAlertController(
            title: "変更を保存できませんでした",
            message: "変更前の状態を保持しています。\n\(error.localizedDescription)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "閉じる", style: .cancel))
        present(alert, animated: true)
    }
}

extension WiFiSettingsViewController {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let item = dataSource.itemIdentifier(for: indexPath),
              case .network(let id) = item else { return }

        do {
            try store.connectToNetwork(id: id)
            refreshNetworkList(reconfiguring: [.currentNetwork])
        } catch {
            presentSaveError(error)
        }
    }

    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        guard let network = findNetwork(for: item) else { return }
        presentNetworkDetailsAlert(for: network)
    }
}
