# CollectionViewPractice

UIKit + UICollectionViewDiffableDataSourceを学ぶためのWi-Fi設定デモ。iOS 16以降、外部ライブラリ・Storyboardなし。

## 起動

`CollectionViewPractice.xcodeproj`をXcodeで開き、CollectionViewPracticeスキームとiPhoneシミュレータを選んで実行します。実機ではSigning & CapabilitiesのTeamを設定してください。

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

## Macへの配置

ダウンロードしたZIPを展開し、フォルダ全体を`/Users/apple/Documents/workplace/GitHub/CollectionViewPractice`に置きます。既存フォルダがある場合は上書きせず、別名にしてください。

## Tomoaki-gに新しい非公開リポジトリを作成

GitHub CLI (`gh`)がない場合は先にインストールしてください。以下はMacのターミナルで実行します。

```bash
cd /Users/apple/Documents/workplace/GitHub/CollectionViewPractice
gh auth login
gh api user --jq .login
```

表示されたアカウントが`Tomoaki-g`であることを確認してから続けます。別アカウントなら`gh auth switch --user Tomoaki-g`で切り替え、もう一度確認してください。

```bash
git init -b main
git add .
git commit -m "Add UICollectionView Wi-Fi settings demo"
gh repo create Tomoaki-g/CollectionViewPractice --private --source=. --remote=origin --push
```

同名リポジトリがすでに存在する場合は作成を中止し、既存の内容を確認してから接続してください。force pushは不要です。

## 参考

- [Qiita記事のWiFiSettingsViewController](https://qiita.com/shiz/items/a6032543a237bf2e1d19)
- [Apple: Implementing modern collection views](https://developer.apple.com/documentation/uikit/implementing-modern-collection-views)

記事の「2セクション・トグル・定期更新」の構成を、UICollectionViewのリストレイアウトで独自に実装しています。

## 検証について

作成環境はLinuxのため、Xcodeによるビルドとシミュレータでの動作確認は未実施です。プロジェクト設定とファイル参照の整合性を静的確認しています。
