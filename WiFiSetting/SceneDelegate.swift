import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        configureRootViewController(in: window)
        self.window = window
        window.makeKeyAndVisible()
    }

    private func configureRootViewController(in window: UIWindow) {
        do {
            let store = try WiFiDemoStore()
            let settings = SettingsViewController(store: store)

            window.rootViewController = UINavigationController(
                rootViewController: settings
            )
        } catch {
            let controller = UIViewController()
            controller.title = "設定"
            controller.view.backgroundColor = .systemGroupedBackground

            let label = UILabel()
            label.text = "保存データを読み込めませんでした。\n保存データは変更していません。\n\(error.localizedDescription)"
            label.numberOfLines = 0
            label.textAlignment = .center
            label.font = .preferredFont(forTextStyle: .body)
            label.adjustsFontForContentSizeCategory = true

            let retryButton = UIButton(type: .system)
            retryButton.setTitle("再読み込み", for: .normal)
            retryButton.addAction(UIAction { [weak self, weak window] _ in
                guard let window else { return }
                self?.configureRootViewController(in: window)
            }, for: .touchUpInside)

            let stack = UIStackView(arrangedSubviews: [label, retryButton])
            stack.axis = .vertical
            stack.spacing = 20
            stack.translatesAutoresizingMaskIntoConstraints = false
            controller.view.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.centerYAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.centerYAnchor),
                stack.leadingAnchor.constraint(equalTo: controller.view.layoutMarginsGuide.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: controller.view.layoutMarginsGuide.trailingAnchor)
            ])
            window.rootViewController = UINavigationController(rootViewController: controller)
        }
    }
}
