import UIKit

final class WiFiSettingsViewController: UIViewController {
    enum Section: Hashable { case configuration, networks }

    // 表示内容ではなく、変わらないIDをSnapshotに渡す。
    enum Item: Hashable {
        case wifiToggle
        case currentNetwork
        case network(String)
    }

    private let store = WiFiDemoStore()
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var scanTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Wi-Fi"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "更新", style: .plain, target: self, action: #selector(scanNetworks)
        )
        setupCollectionView()
        setupDataSource()
        applySnapshot(animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    deinit { scanTimer?.invalidate() }

    // MARK: - Layout

    private func setupCollectionView() {
        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.headerMode = .supplementary
        configuration.footerMode = .supplementary
        let layout = UICollectionViewCompositionalLayout.list(using: configuration)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    // MARK: - Cell / Supplementary registrations

    private func setupDataSource() {
        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> {
            [weak self] cell, _, item in
            guard let self else { return }
            var content = cell.defaultContentConfiguration()
            cell.accessories = []
            switch item {
            case .wifiToggle:
                content.text = "Wi-Fi"
                let toggle = UISwitch()
                toggle.isOn = self.store.isEnabled
                toggle.accessibilityLabel = "Wi-Fi（デモ）"
                toggle.addTarget(self, action: #selector(self.wifiChanged(_:)), for: .valueChanged)
                let accessory = UICellAccessory.CustomViewConfiguration(
                    customView: toggle, placement: .trailing(displayed: .always)
                )
                cell.accessories = [.customView(configuration: accessory)]

            case .currentNetwork:
                content.text = self.store.connectedNetwork?.name
                content.secondaryText = "接続中（デモ）"
                content.image = UIImage(systemName: "checkmark")
                content.imageProperties.tintColor = .systemBlue
                cell.accessories = [.detail(displayed: .always, actionHandler: { [weak self] in
                    guard let self, let network = self.store.connectedNetwork else { return }
                    self.showDetails(network)
                })]

            case .network(let id):
                guard let network = self.store.network(id: id) else { return }
                content.text = network.name
                content.image = UIImage(systemName: network.isSecure ? "lock.fill" : "wifi")
                content.imageProperties.tintColor = .secondaryLabel
                cell.accessories = [.detail(displayed: .always, actionHandler: { [weak self] in
                    self?.showDetails(network)
                })]
            }
            content.textProperties.numberOfLines = 0
            content.secondaryTextProperties.numberOfLines = 0
            cell.contentConfiguration = content
        }

        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) {
            collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
        }

        let header = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] view, _, indexPath in
            var content = UIListContentConfiguration.groupedHeader()
            let section = self?.dataSource.snapshot().sectionIdentifiers[indexPath.section]
            content.text = section == .networks ? "ネットワーク" : nil
            view.contentConfiguration = content
        }
        let footer = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { [weak self] view, _, indexPath in
            var content = UIListContentConfiguration.groupedFooter()
            let section = self?.dataSource.snapshot().sectionIdentifiers[indexPath.section]
            if section == .configuration {
                content.text = "動作確認用の画面です。端末のWi-Fi設定は変更しません。"
            } else {
                content.text = "5秒ごとに一覧を更新します。ネットワークをタップすると接続表示が切り替わります。"
            }
            content.textProperties.numberOfLines = 0
            view.contentConfiguration = content
        }
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            switch kind {
            case UICollectionView.elementKindSectionHeader:
                return collectionView.dequeueConfiguredReusableSupplementary(using: header, for: indexPath)
            case UICollectionView.elementKindSectionFooter:
                return collectionView.dequeueConfiguredReusableSupplementary(using: footer, for: indexPath)
            default: return nil
            }
        }
    }

    // MARK: - Snapshot

    private func applySnapshot(animated: Bool = true) {
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

        // IDが同じでも内容（スイッチや接続先）が変わったセルを更新する。
        let existing = Set(dataSource.snapshot().itemIdentifiers)
        snapshot.reconfigureItems(snapshot.itemIdentifiers.filter { existing.contains($0) })
        dataSource.apply(snapshot, animatingDifferences: animated)
        navigationItem.rightBarButtonItem?.isEnabled = store.isEnabled
    }

    // MARK: - Actions

    @objc private func wifiChanged(_ sender: UISwitch) {
        store.isEnabled = sender.isOn
        if store.isEnabled { startScanning() } else { stopScanning() }
        applySnapshot()
    }

    @objc private func scanNetworks() {
        guard store.isEnabled else { return }
        store.scan()
        applySnapshot()
    }

    private func startScanning() {
        guard store.isEnabled, scanTimer == nil else { return }
        // Target方式ならTimerの実行もメインRunLoop上で行われる。
        let timer = Timer(timeInterval: 5, target: self,
                          selector: #selector(scanNetworks), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        scanTimer = timer
    }

    private func stopScanning() {
        scanTimer?.invalidate()
        scanTimer = nil
    }

    private func showDetails(_ network: WiFiDemoStore.Network) {
        let alert = UIAlertController(title: network.name,
            message: network.isSecure ? "セキュリティあり（ダミーデータ）" : "オープンネットワーク（ダミーデータ）",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "閉じる", style: .cancel))
        present(alert, animated: true)
    }
}

extension WiFiSettingsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath),
              case .network(let id) = item else { return }
        store.connectedID = id
        applySnapshot()
    }
}
