import UIKit

// スイッチとアクセサリはセルの生成時に一度だけ作る。
final class WiFiToggleTableCell: UITableViewCell {
    private let toggle = UISwitch()
    var onValueChanged: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        var content = defaultContentConfiguration()
        content.text = "Wi-Fi"
        content.textProperties.numberOfLines = 0
        contentConfiguration = content
        toggle.accessibilityLabel = "Wi-Fi（デモ）"
        toggle.addTarget(self,
                         action: #selector(handleWiFiSwitchValueChanged(_:)),
                         for: .valueChanged)

        accessoryView = toggle
        selectionStyle = .none
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setWiFiSwitch(isOn: Bool) {
        toggle.setOn(isOn, animated: false)
    }

    @objc private func handleWiFiSwitchValueChanged(_ sender: UISwitch) {
        onValueChanged?(sender.isOn)
    }
}
