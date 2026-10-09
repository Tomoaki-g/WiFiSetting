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

    private func createLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            guard let self, let dataSource = self.dataSource else { return nil }
            let sections = dataSource.snapshot().sectionIdentifiers
            guard sections.indices.contains(sectionIndex) else { return nil }

            // 設定と接続中のネットワークは、幅いっぱいのリスト表示。
            if sections[sectionIndex] == .configuration {
                var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                configuration.headerMode = .supplementary
                configuration.footerMode = .supplementary
                return NSCollectionLayoutSection.list(
                    using: configuration, layoutEnvironment: environment
                )
            }

            let spacing: CGFloat = 10
            let sideInset: CGFloat = 10

            // 左右の余白と列間の余白を除き、２列で等分する。
            let availableWidth =
                environment.container.effectiveContentSize.width
                - sideInset * 2
                - spacing

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(availableWidth / 2),
                heightDimension: .fractionalHeight(1)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(44)
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                repeatingSubitem: item,
                count: 2
            )
            group.interItemSpacing = .fixed(spacing)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = spacing
            section.contentInsets = NSDirectionalEdgeInsets(
                top: 0,
                leading: sideInset,
                bottom: 0,
                trailing: sideInset
            )

            let supplementarySize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(44)
            )
            section.boundarySupplementaryItems = [
                NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: supplementarySize,
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                ),
                NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: supplementarySize,
                    elementKind: UICollectionView.elementKindSectionFooter,
                    alignment: .bottom
                )
            ]
            return section
        }
    }

    private func setupCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .systemGroupedBackground
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
        let toggleRegistration = UICollectionView.CellRegistration<WiFiToggleCell, Item> { [weak self] cell, _, _ in
            guard let self else { return }

            cell.configure(isOn: self.store.isEnabled)
            cell.onValueChanged = { [weak self] toggle in
                self?.wifiChanged(toggle)
            }
        }

        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> {
            [weak self] cell, _, item in
            guard let self else { return }

            var content = cell.defaultContentConfiguration()
            cell.accessories = []

            switch item {
            case .wifiToggle:
                // トグルは専用セルで構成し、アクセサリを入れ替えない。
                return

            case .currentNetwork:
                content.text = self.store.connectedNetwork?.name
                content.secondaryText = "接続中（デモ）"
                content.image = UIImage(systemName: "checkmark")
                content.imageProperties.tintColor = .systemBlue
                cell.accessories = [.detail(displayed: .always, actionHandler: { [weak self] in
                    guard let self, let network = self.store.connectedNetwork else { return }
                    self.showDetails(network)
                })]

            case .network:
                return // ネットワークはグリッド専用セルで表示する。
            }
            content.textProperties.numberOfLines = 0
            content.secondaryTextProperties.numberOfLines = 0
            cell.contentConfiguration = content
        }

        let networkRegistration = UICollectionView.CellRegistration<NetworkGridCell, Item> {
            [weak self] cell, _, item in
            guard let self, case .network(let id) = item,
                  let network = self.store.network(id: id) else { return }
            cell.configure(network: network)
            cell.onDetails = { [weak self] in
                self?.showDetails(network)
            }
        }

        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            if item == .wifiToggle {
                return collectionView.dequeueConfiguredReusableCell(
                    using: toggleRegistration, for: indexPath, item: item
                )
            }

            if case .network = item {
                return collectionView.dequeueConfiguredReusableCell(
                    using: networkRegistration, for: indexPath, item: item
                )
            }
            return collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
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

        // 内容が変わった既存セルだけを更新する。追加セルは初回構成で反映される。
        let existing = Set(dataSource.snapshot().itemIdentifiers)
        let incoming = Set(snapshot.itemIdentifiers)
        snapshot.reconfigureItems(items.filter { existing.contains($0) && incoming.contains($0) })
        dataSource.apply(snapshot, animatingDifferences: animated)
        navigationItem.rightBarButtonItem?.isEnabled = store.isEnabled
    }

    // MARK: - Actions

    @objc private func wifiChanged(_ sender: UISwitch) {
        store.isEnabled = sender.isOn

        if store.isEnabled {
            startScanning()
        } else {
            stopScanning()
        }

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
        applySnapshot(reconfiguring: [.currentNetwork])
    }
}

// スイッチとアクセサリはセルの生成時に一度だけ作る。
private final class WiFiToggleCell: UICollectionViewListCell {
    private let toggle = UISwitch()
    var onValueChanged: ((UISwitch) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        var content = defaultContentConfiguration()
        content.text = "Wi-Fi"
        content.textProperties.numberOfLines = 0
        contentConfiguration = content
        toggle.accessibilityLabel = "Wi-Fi（デモ）"
        toggle.addTarget(self, action: #selector(valueChanged(_:)), for: .valueChanged)

        let accessory = UICellAccessory.CustomViewConfiguration(
            customView: toggle, placement: .trailing(displayed: .always)
        )
        accessories = [.customView(configuration: accessory)]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(isOn: Bool) {
        // 画面外からの再表示でも、現在の状態を余計なアニメーションなしで反映する。
        UIView.performWithoutAnimation {
            toggle.setOn(isOn, animated: false)
        }
    }

    @objc private func valueChanged(_ sender: UISwitch) {
        onValueChanged?(sender)
    }
}

// リスト用セルのサイズ調整に依存せず、グリッドの寸法に従うセル。
private final class NetworkGridCell: UICollectionViewCell {
    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let detailButton = UIButton(type: .detailDisclosure)
    var onDetails: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 16
        iconView.tintColor = .secondaryLabel
        iconView.contentMode = .scaleAspectFit
        nameLabel.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(
            for: .systemFont(ofSize: 13)
        )
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 2
        detailButton.addTarget(self, action: #selector(showDetails), for: .touchUpInside)

        for subview in [iconView, nameLabel, detailButton] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(subview)
        }
        NSLayoutConstraint.activate([
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            detailButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            detailButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            detailButton.widthAnchor.constraint(equalToConstant: 44),
            detailButton.heightAnchor.constraint(equalToConstant: 44),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            nameLabel.trailingAnchor.constraint(equalTo: detailButton.leadingAnchor),
            nameLabel.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 4),
            nameLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -4)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(network: WiFiDemoStore.Network) {
        nameLabel.text = network.name
        iconView.image = UIImage(systemName: network.isSecure ? "lock.fill" : "wifi")
        detailButton.accessibilityLabel = "\(network.name)の詳細"
    }

    override var isHighlighted: Bool {
        didSet { contentView.alpha = isHighlighted ? 0.6 : 1 }
    }

    @objc private func showDetails() { onDetails?() }
}
