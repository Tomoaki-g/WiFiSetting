import UIKit

final class WiFiSettingsViewController: UIViewController, UITableViewDelegate {
    enum Section: Hashable { case configuration, networks }

    // Snapshotには項目の識別子を渡す。接続先が変わってもcurrentNetworkの識別子は同じ。
    enum Item: Hashable {
        case wifiToggle
        case currentNetwork
        case network(String)
    }

    private let store = WiFiDemoStore()
    private var tableView: UITableView!
    private var dataSource: WiFiTableDataSource!
    private var actionButtons: [UIBarButtonItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Wi-Fi"
        view.backgroundColor = .systemGroupedBackground

        let addButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addNetworks)
        )
        addButton.accessibilityLabel = "追加"

        actionButtons = [addButton]
        self.navigationItem.rightBarButtonItems = actionButtons

        setupTableView()
        setupDataSource()
        applySnapshot(animated: false)
    }

    // MARK: - Layout

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
        tableView.register(
            WiFiToggleTableCell.self,
            forCellReuseIdentifier: "WiFiToggleCell"
        )

        tableView.register(
            UITableViewCell.self,
            forCellReuseIdentifier: "NetworkCell"
        )

        dataSource = WiFiTableDataSource(tableView: tableView) { [weak self] tableView, indexPath, item in
            guard let self else { return nil }

            // ① スイッチ用セルを取得して状態と通知先を設定。
            if item == .wifiToggle {
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: "WiFiToggleCell",
                    for: indexPath
                ) as! WiFiToggleTableCell

                cell.configure(isOn: self.store.isEnabled)
                cell.onValueChanged = { [weak self] toggle in
                    self?.wifiChanged(toggle)
                }
                return cell
            }

            // ② 接続中・未接続のネットワーク用セルを取得。
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "NetworkCell",
                for: indexPath
            )

            var content = cell.defaultContentConfiguration()

            // ③ Itemに応じて、最新の表示内容を設定。
            switch item {
            case .currentNetwork:
                content.text = self.store.connectedNetwork?.name
                content.secondaryText = "接続中（デモ）"
                content.image = UIImage(systemName: "checkmark")
                content.imageProperties.tintColor = .systemBlue

            case .network(let id):
                guard let network = self.store.network(id: id) else {
                    return nil
                }
                content.text = network.name
                content.secondaryText = nil
                content.image = UIImage(
                    systemName: network.isSecure ? "lock.fill" : "wifi"
                )

            case .wifiToggle:
                return nil // 上の専用セルの分岐で処理済み。
            }

            content.textProperties.numberOfLines = 0
            content.secondaryTextProperties.numberOfLines = 0
            cell.contentConfiguration = content
            cell.accessoryType = .detailButton

            return cell
        }

        // DataSourceから削除対象のIDを受け取り、元データと表示を更新する。
        dataSource.onDeleteNetwork = { [weak self] id in
            guard let self, self.store.isEnabled else { return }
            self.store.removeNetwork(id: id)
            self.applySnapshot()
        }
        dataSource.defaultRowAnimation = .fade
    }

    // MARK: - Snapshot

    private func applySnapshot(animated: Bool = true, reconfiguring items: [Item] = []) {
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

        // 呼び出し側が指定したitemsのうち、旧・新Snapshotの両方にある項目を再構成する。
        // 内容の変更を自動検出する処理ではない。新規項目は表示用セルの構成時に最新状態を反映する。
        let existing = Set(dataSource.snapshot().itemIdentifiers)
        let incoming = Set(snapshot.itemIdentifiers)
        snapshot.reconfigureItems(items.filter { existing.contains($0) && incoming.contains($0) })
        dataSource.apply(snapshot, animatingDifferences: animated)
        actionButtons.forEach { button in
            button.isEnabled = store.isEnabled
        }
    }

    // MARK: - Actions

    @objc private func wifiChanged(_ sender: UISwitch) {
        store.isEnabled = sender.isOn
        applySnapshot()
    }

    @objc private func addNetworks() {
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

        // 入力値を確認し、データの追加はStoreに任せる。
        let addNetwork: (Bool) -> Void = { [weak self, weak alert] isSecure in
            guard let self, self.store.isEnabled,
                  let text = alert?.textFields?.first?.text else { return }
            let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }

            self.store.addNetwork(name: name, isSecure: isSecure)
            self.applySnapshot()
        }

        let secureAction = UIAlertAction(
            title: "セキュリティありで追加", style: .default
        ) { _ in
            addNetwork(true)
        }

        let openAction = UIAlertAction(
            title: "セキュリティなしで追加", style: .default
        ) { _ in
            addNetwork(false)
        }

        secureAction.isEnabled = false
        openAction.isEnabled = false
        alert.addAction(secureAction)
        alert.addAction(openAction)

        // 入力のたびに両方の追加アクションを更新する。空欄・空白だけの場合は無効。
        alert.textFields?.first?.addAction(
            UIAction { [weak secureAction, weak openAction] action in
                guard let textField = action.sender as? UITextField else { return }
                let name = (textField.text ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                secureAction?.isEnabled = !name.isEmpty
                openAction?.isEnabled = !name.isEmpty
            },
            for: .editingChanged
        )

        present(alert, animated: true)
    }

    private func showDetails(_ network: WiFiDemoStore.Network) {
        let alert = UIAlertController(title: network.name,
            message: network.isSecure ? "セキュリティあり（ダミーデータ）" : "オープンネットワーク（ダミーデータ）",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "閉じる", style: .cancel))
        present(alert, animated: true)
    }
}

private final class WiFiTableDataSource: UITableViewDiffableDataSource<WiFiSettingsViewController.Section, WiFiSettingsViewController.Item> {
    var onDeleteNetwork: ((String) -> Void)?

    // 設定スイッチと接続中の行は削除対象にせず、未接続ネットワークだけ編集可能にする。
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard let item = itemIdentifier(for: indexPath),
              case .network = item else { return false }
        return true
    }

    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard editingStyle == .delete,
              let item = itemIdentifier(for: indexPath),
              case .network(let id) = item else { return }
        onDeleteNetwork?(id)
    }

    override func tableView(_ tableView: UITableView,titleForHeaderInSection section: Int) -> String? {
        let sections = snapshot().sectionIdentifiers
        guard sections.indices.contains(section) else { return nil }

        switch sections[section] {
        case .configuration:
            return nil
        case .networks:
            return "ネットワーク"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let sections = snapshot().sectionIdentifiers
        guard sections.indices.contains(section) else { return nil }

        switch sections[section] {
        case .configuration:
            return "動作確認用の画面です。端末のWi-Fi設定は変更しません。"
        case .networks:
            return "接続中のネットワークは上部に表示されます。"
        }
    }
}

extension WiFiSettingsViewController {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let item = dataSource.itemIdentifier(for: indexPath),
              case .network(let id) = item else { return }

        store.connectedID = id
        applySnapshot(reconfiguring: [.currentNetwork])
    }

    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        let network: WiFiDemoStore.Network?

        switch item {
        case .currentNetwork:
            network = store.connectedNetwork
        case .network(let id):
            network = store.network(id: id)
        case .wifiToggle:
            return
        }

        guard let network else { return }
        showDetails(network)
    }
}

// スイッチとアクセサリはセルの生成時に一度だけ作る。
private final class WiFiToggleTableCell: UITableViewCell {
    private let toggle = UISwitch()
    var onValueChanged: ((UISwitch) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        var content = defaultContentConfiguration()
        content.text = "Wi-Fi"
        content.textProperties.numberOfLines = 0
        contentConfiguration = content
        toggle.accessibilityLabel = "Wi-Fi（デモ）"
        toggle.addTarget(self, action: #selector(valueChanged(_:)), for: .valueChanged)

        accessoryView = toggle
        selectionStyle = .none
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(isOn: Bool) {
        toggle.setOn(isOn, animated: false)
    }

    @objc private func valueChanged(_ sender: UISwitch) {
        onValueChanged?(sender)
    }
}
