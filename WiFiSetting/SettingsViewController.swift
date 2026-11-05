import UIKit

final class SettingsViewController: UITableViewController {
    private let store = WiFiDemoStore()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "設定"
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Wi-Fi画面で変更した接続先やスイッチの状態を一覧に反映する。
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingCell")
            ?? UITableViewCell(style: .value1, reuseIdentifier: "SettingCell")
        var content = cell.defaultContentConfiguration()
        content.text = "Wi-Fi"
        content.secondaryText = store.isEnabled ? (store.connectedNetwork?.name ?? "未接続") : "オフ"
        content.image = UIImage(systemName: "wifi")
        content.imageProperties.tintColor = .systemBlue
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.numberOfLines = 0
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        navigationController?.pushViewController(WiFiSettingsViewController(store: store), animated: true)
    }
}
