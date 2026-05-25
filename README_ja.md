<p align="center">
  <img src="images/banner.png" width="500">
</p>

<p align="center">
  <a href="https://github.com/07JP27/ZoomacIt/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/07JP27/ZoomacIt/ci.yml?style=flat&label=CI" alt="CI"></a>
  <a href="https://github.com/07JP27/ZoomacIt/releases/latest"><img src="https://img.shields.io/github/v/release/07JP27/ZoomacIt?style=flat" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/07JP27/ZoomacIt?style=flat" alt="License"></a>
  <a href="CONTRIBUTORS.md"><img src="https://img.shields.io/github/contributors/07JP27/ZoomacIt?style=flat" alt="Contributors"></a>
  <img src="https://img.shields.io/badge/Swift-6.0-orange?style=flat&logo=swift&logoColor=white" alt="Swift 6.0">
  <img src="https://img.shields.io/badge/macOS-target%2015%2B%20%7C%20supported%2026%2B-blue?style=flat&logo=apple&logoColor=white" alt="macOS target 15+ | supported 26+">
  <a href="https://github.com/sponsors/07JP27"><img src="https://img.shields.io/badge/Sponsor-%E2%9D%A4-ea4aaa?style=flat&logo=githubsponsors&logoColor=white" alt="Sponsor"></a>
</p>

<p align="center"><a href="README.md">English</a> | 日本語</p>

---

ZoomacIt は [Windows 版 ZoomIt](https://learn.microsoft.com/ja-jp/sysinternals/downloads/zoomit) にインスパイアされた、ネイティブ macOS メニューバーアプリです。
ZoomIt との機能互換を目指しており、システム全体で使えるホットキー、スムーズなズーム、画面上へのアノテーション機能を、最小限の権限で提供します。

> **📖 インストール方法・使い方・キーボードショートカットをお探しですか？**
> **[ZoomacIt ドキュメントサイト](https://zoomacit.07jp27.net/ja/)** をご覧ください。

https://github.com/user-attachments/assets/5f7563e4-584b-4bab-99c4-70f7d3265f54

[🎥 高画質で見る](images/demo.mp4)

## 機能カバレッジ

| 機能 | 状態 |
|---|---|
| ズーム（静止画ズーム） | ✅ |
| ズーム（ライブズーム） | ✅ |
| ドロー | ✅ |
| デモタイプ | |
| 休憩タイマー | ✅ |
| スニップ | |
| 録画 | |

## アーキテクチャ

純粋な **Swift 6 + AppKit**（SwiftUI は Settings UI のみ使用）。macOS 15+。外部依存なし。Xcode プロジェクトは [xcodegen](https://github.com/yonaskolb/XcodeGen) により `src/project.yml` から生成されます。

| レイヤー | ディレクトリ | 役割 |
|---|---|---|
| **App** | `src/ZoomacIt/App/` | エントリーポイント (`main.swift`)、`AppDelegate`、`StatusBarController`（メニューバー） |
| **Core** | `src/ZoomacIt/Core/` | `HotkeyManager` — Carbon `RegisterEventHotKey` API |
| **Overlay** | `src/ZoomacIt/Overlay/` | フルスクリーンオーバーレイウィンドウ、ズームコントローラー、`ZoomMath` |
| **Draw** | `src/ZoomacIt/Draw/` | `DrawingCanvasView`（3レイヤー合成）、レンダラー、`StrokeManager` |
| **Settings** | `src/ZoomacIt/Settings/` | SwiftUI ベースの設定画面（ホットキーカスタマイズ） |
| **Models / Utils** | `src/ZoomacIt/Models/`、`Utilities/` | 状態モデル (`DrawingState`、`Stroke`、`Settings`)、拡張 |

詳細な設計ドキュメントは [`design/`](design/) にあります。

## 開発

### 前提条件

- macOS 15+（ビルドターゲット）
- Xcode（Swift 6 ツールチェーン）

> **互換性について:** 最小デプロイターゲットは macOS 15 ですが、公式にテスト・サポートされているのは macOS 26 のみです。それ以前のバージョンでも動作する可能性はありますが、保証はされません。
- [xcodegen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）— `src/project.yml` を編集する場合のみ必要

### ビルドコマンド

```bash
make build       # デバッグビルド
make test        # ユニットテストの実行
make run         # ビルドしてアプリを起動
make release     # リリースビルド（Developer ID 署名付き）
make notarize    # リリースビルド + Apple 公証
make dmg VERSION=1.0.0  # 公証 + 配布用 DMG 作成
make clean       # ビルド成果物のクリーンアップ
make generate    # .xcodeproj を再生成（src/project.yml 編集後）
make docs        # ドキュメントサイトのローカル開発サーバーを起動
make docs-build  # ドキュメントサイトをビルド
```

### コントリビューターとしてビルドする

プロジェクトの `src/project.yml` にはメンテナーのチーム ID がハードコードされています。ローカルでビルド・実行するには、自分のチーム ID に置き換えてください：

1. チーム ID を確認: `security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject | grep -o 'OU=[^,]*' | cut -d= -f2`
2. `src/project.yml` を編集 — `DEVELOPMENT_TEAM` の値を自分のものに置き換え（2箇所）
3. 再生成してビルド:
   ```bash
   make generate
   make build
   make run
   ```

> **注意:** macOS がアプリを起動し、画面収録（TCC）権限を付与するには、有効なコード署名が必要です。チーム ID はコミットしないでください — ローカルのみの変更です。

### コード署名と公証

macOS の Gatekeeper は、インターネットからダウンロードされた未署名のアプリをブロックします。Gatekeeper の警告を回避して ZoomacIt を配布するには、Developer ID 証明書で署名し、Apple の公証を受ける必要があります。

`.env.example` を `.env` にコピーし、認証情報を入力してください：

```bash
cp .env.example .env
```

| 変数 | 説明 |
| --- | --- |
| `APPLE_ID` | Apple ID のメールアドレス |
| `TEAM_ID` | Apple Developer Team ID（`make release` / `make notarize` で使用） |
| `APP_PASSWORD` | appleid.apple.com で生成した[アプリ用パスワード](https://support.apple.com/ja-jp/102654) |
| `DEVELOPER_NAME` | Developer ID 証明書に記載されている名前 |

次のコマンドを実行します：

```bash
make dmg VERSION=1.0.0
```

Developer ID で署名されたリリースバイナリをビルドし、Apple に公証を申請し、公証チケットをステープルし、配布用 DMG にパッケージします。

> **注意:** 公証には [Apple Developer Program](https://developer.apple.com/programs/) のメンバーシップが必要です。`.env` ファイルは gitignore に含まれており、コミットしないでください。

## コントリビューター

<a href="https://github.com/07JP27/ZoomacIt/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=07JP27/ZoomacIt" alt="Contributors" />
</a>

ZoomacIt の改善に協力してくださるすべての方に感謝します。謝辞は [CONTRIBUTORS.md](CONTRIBUTORS.md) をご覧ください。

## ライセンス

本プロジェクトは [GNU General Public License v3.0](LICENSE) の下で公開されています。
