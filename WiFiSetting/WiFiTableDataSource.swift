import UIKit

final class WiFiTableDataSource: UITableViewDiffableDataSource<WiFiSettingsViewController.Section, WiFiSettingsViewController.Item> {
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
        guard let section = sectionIdentifier(at: section) else { return nil }
        switch section {
        case .configuration:
            return nil
        case .networks:
            return "ネットワーク"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let section = sectionIdentifier(at: section) else { return nil }
        switch section {
        case .configuration:
            return "動作確認用の画面です。端末のWi-Fi設定は変更しません。"
        case .networks:
            return "接続中のネットワークは上部に表示されます。"
        }
    }

    private func sectionIdentifier(at index: Int) -> WiFiSettingsViewController.Section? {
        let sections = snapshot().sectionIdentifiers
        return sections.indices.contains(index) ? sections[index] : nil
    }

}
