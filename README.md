# WiFiSetting

UIKit + UICollectionViewDiffableDataSourceを学ぶためのWi-Fi設定デモ。iOS 16以降、外部ライブラリ・Storyboardなし。

## 起動

`WiFiSetting.xcodeproj`をXcodeで開き、WiFiSettingスキームとiPhoneシミュレータを選んで実行します。実機ではSigning & CapabilitiesのTeamを設定してください。

## 確認できる動作

- Wi-Fiスイッチで接続中セルとネットワークセクションが表示・非表示になる。
- ネットワークをタップすると接続中表示が変わる。
- 5秒ごと、または「更新」でネットワークが追加・削除される。
- ⓘでダミーネットワークの詳細が表示される。
- ヘッダー・フッターと複数行セルが表示される。Dynamic Type対応。

実際のWi-Fi検出・接続・OSのスイッチ変更は行いません。オフにしてもデモの接続先は保持します。アプリを再起動すると初期状態に戻ります。

## コードを読む順番

1. `SceneDelegate.swift`: UIWindow → UINavigationController → 画面生成。
2. `WiFiDemoStore.swift`: 表示状態と安定したネットワークID。
3. `WiFiSettingsViewController.swift`の`setupCollectionView()`: リストレイアウト。
4. `setupDataSource()`: CellRegistration、セルの種類、ヘッダー・フッター。
5. `applySnapshot()`: 状態からセクション・アイテムを構築し、applyで反映。
6. `wifiChanged` / `scanNetworks` / `didSelectItemAt`: 状態更新 → Snapshot更新。

Snapshotにタイトルや接続状態ではなく安定したIDを渡し、同じIDの内容変更は`reconfigureItems`で反映します。

## 参考

- [Qiita記事のWiFiSettingsViewController](https://qiita.com/shiz/items/a6032543a237bf2e1d19)
- [Apple: Implementing modern collection views](https://developer.apple.com/documentation/uikit/implementing-modern-collection-views)

記事の「2セクション・トグル・定期更新」の構成を、UICollectionViewのリストレイアウトで独自に実装しています。

## 検証について

XcodeでiOS Simulator向けのDebugビルド成功を確認しています（コード署名なし）。シミュレータでの起動・操作確認は未実施です。
