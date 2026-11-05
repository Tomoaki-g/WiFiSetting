# WiFiSetting

UIKit と Diffable Data Source を学ぶための Wi-Fi 設定デモです。現在は `UITableView` と `UITableViewDiffableDataSource` を使い、設定とネットワーク一覧を１列で表示します。

iOS 16 以降に対応し、外部ライブラリ・Storyboard・XIB は使用していません。

## 実装の変遷

最初は `UICollectionView` と `UICollectionViewDiffableDataSource` を使い、リスト形式の Wi-Fi 設定画面を実装していました。その後、Compositional Layout によるネットワーク一覧の２列表示と、Supplementary View によるセル付属バッジを試しました。

現在はバッジを取り除き、`UITableView` の `.insetGrouped` スタイルで元の１列の画面構成に戻しています。データ管理と Snapshot による差分更新の考え方は維持し、セルの生成・配置、ヘッダー・フッター、タップ処理を TableView 用に変更しています。

## 起動

1. `WiFiSetting.xcodeproj` を Xcode で開きます。
2. `WiFiSetting` スキームと iPhone シミュレータを選択します。
3. Run で実行します。

実機で実行する場合は、Signing & Capabilities の Team を設定してください。

## 画面と動作

- 起動時は「設定」一覧を表示し、「Wi-Fi」の行をタップすると Wi-Fi 設定画面へ遷移します。ナビゲーションバーの戻るボタンで一覧に戻れます。
- 設定一覧の Wi-Fi 行には接続先名、未接続、またはオフを表示します。画面を行き来しても、スイッチ状態・接続先・追加や削除したネットワークを保持します。
- 設定セクションに Wi-Fi スイッチと接続中のネットワークを表示します。
- ネットワークセクションに、接続中のものを除いたデモネットワークを名前順で表示します。
- Wi-Fi をオフにすると、接続中の行とネットワークセクションを非表示にし、追加ボタンを無効にします。
- ネットワークの行をタップすると、デモの接続先と接続中の表示を切り替えます。
- 各ネットワークの ⓘ ボタンで、デモの詳細情報を表示します。
- 「＋」ボタンで入力ダイアログを開き、名前を入力してセキュリティの有無を選ぶと、デモネットワークを追加します。空欄・空白だけの場合は追加できません。
- 一覧は追加・削除・接続先変更・スイッチ操作時に更新します。以前のスキャンによる表示パターン切り替えと定期更新は取り除いています。
- 未接続ネットワークはスワイプで削除できます。設定スイッチと接続中の行は削除対象にしません。
- 行の追加・削除にはフェードを指定しています。
- セクションの見出しと説明文は、TableView の標準ヘッダー・フッターで表示します。

実際の Wi-Fi の検出・接続・端末設定の変更は行いません。スイッチをオフにしてもデモの接続先はメモリ内に保持し、アプリのプロセスを起動し直すと初期状態に戻ります。

## コードを読む順番

1. `AppDelegate.swift`：シーンの構成を作り、担当クラスに `SceneDelegate` を指定します。
2. `SceneDelegate.swift`：ウィンドウとナビゲーションコントローラを作り、`SettingsViewController.swift` の設定一覧を表示します。設定一覧がデモデータを保持し、Wi-Fi 行の選択時に同じデータを Wi-Fi 設定画面へ渡します。
3. `WiFiDemoStore.swift`：スイッチ状態、接続先、デモネットワークのデータと追加・削除・接続処理を管理します。名前の前後の空白除去と空欄の検証は `normalizeNetworkName` にまとめています。`findNetwork(id:)` で ID に一致するネットワークを検索し、`connectToNetwork(id:)` でデモの接続先を変更します。
4. `WiFiSettingsViewController.swift` の `viewDidLoad()`：一覧の準備 → DataSource の設定 → 初期 Snapshot の適用という順番で初期化します。
5. `setupTableView()`：１列の TableView を作り、Auto Layout で画面に配置します。
6. `setupDataSource()`：セルクラスを登録し、セル提供と削除通知を接続します。`dequeueConfiguredCell` と `configureNetworkCell` がセルの取得・表示設定を担当します。
7. `WiFiTableDataSource.swift`：セクションの識別子に応じて、ヘッダー・フッターの文字列を返します。削除可否を判定し、削除操作を ViewController に通知します。
8. `makeNetworkListSnapshot()` / `refreshNetworkList()`：現在の状態から表示項目を組み立て、指定された既存項目の再構成と差分更新を適用します。
9. `presentAddNetworkAlert`：ネットワーク追加の入力ダイアログを表示します。`setWiFiEnabled` / `deleteNetwork` / `tableView(_:didSelectRowAt:)` は操作を受けてデータを変更し、`refreshNetworkList` で一覧を更新します。
10. `WiFiToggleTableCell.swift`：右側のスイッチを配置し、値の変更を ViewController に通知します。

## ファイルを分けた役割

`WiFiSettingsViewController.swift` は画面の組み立て、デモデータの変更、Snapshot による一覧更新、ダイアログ表示を担当します。独立したクラスである DataSource とスイッチ付きセルは、それぞれ別ファイルに配置しています。

`WiFiToggleTableCell` は `onValueChanged` でスイッチの状態を通知し、`WiFiTableDataSource` は `onDeleteNetwork` で削除対象の ID を通知します。ViewController がこれらのクロージャを設定してデータを変更するので、セルや DataSource が直接 Store を操作する必要はありません。

別ファイルから参照する２つのクラスは、トップレベルの `private` を外し、同じモジュール内から利用できる `internal`（指定省略時のアクセスレベル）にしています。セル内部の `toggle` や DataSource 内部の補助メソッドは `private` のままです。

行のタップ処理を記述した `extension WiFiSettingsViewController` は、同じファイルに残しています。同じファイルの extension は ViewController の `private` メンバーを利用できますが、別ファイルへ移すと利用できなくなるためです。

## 差分更新の仕組み

Snapshot には表示文字列ではなく、`Section` と `Item` の識別子を渡します。ネットワークには固定の ID を使い、一覧の追加・削除・移動を Diffable Data Source が判別できるようにしています。

接続中の行は、接続先が変わっても `.currentNetwork` という同じ識別子を使います。そのため、接続先を変更した際には `reconfigureItems` を指定して、名前などの表示内容を更新します。内容の変化を自動検出する処理ではありません。

## 参考

- [Qiita：時代の変化に応じて進化するCollectionView](https://qiita.com/shiz/items/a6032543a237bf2e1d19)
- [Apple：Implementing modern collection views](https://developer.apple.com/documentation/uikit/implementing-modern-collection-views)
- [Apple：UITableViewDiffableDataSource](https://developer.apple.com/documentation/uikit/uitableviewdiffabledatasource-2euir)

CollectionView 版の学習では、これらの Compositional Layout と Diffable Data Source の解説を参考にしました。現在の TableView 版は、同じデモデータと差分更新の流れを使った実装です。

## 検証状況

設定一覧からの画面遷移を追加した変更は、iOS Simulator 向けの Debug ビルド成功を確認しています（コード署名なし、arm64 / x86_64）。画面遷移の実行確認は未実施です。以下は変更前の検証結果です。

iOS Simulator 向けの Debug ビルド成功を確認しています（コード署名なし）。シミュレータで、空欄・空白だけの入力時の追加アクション無効化、名前入力後の有効化、セキュリティあり・なしの追加と一覧への反映、Wi-Fi オフ時の追加ボタン無効化を確認しています。また、未接続ネットワークの削除と一覧への反映を確認しています。実機での動作は未確認です。
