<p align="center">
  <img src="images/banner.png" width="500">
</p>

<p align="center">
  <a href="https://github.com/07JP27/ZoomacIt/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/07JP27/ZoomacIt/ci.yml?style=flat&label=CI" alt="CI"></a>
  <a href="https://github.com/07JP27/ZoomacIt/releases/latest"><img src="https://img.shields.io/github/v/release/07JP27/ZoomacIt?style=flat" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/07JP27/ZoomacIt?style=flat" alt="License"></a>
  <img src="https://img.shields.io/badge/Swift-6.0-orange?style=flat&logo=swift&logoColor=white" alt="Swift 6.0">
  <img src="https://img.shields.io/badge/macOS-26%2B-blue?style=flat&logo=apple&logoColor=white" alt="macOS 26+">
  <a href="https://github.com/sponsors/07JP27"><img src="https://img.shields.io/badge/Sponsor-%E2%9D%A4-ea4aaa?style=flat&logo=githubsponsors&logoColor=white" alt="Sponsor"></a>
</p>

<p align="center"><a href="README.md">English</a> | 日本語</p>

---
ZoomacIt は [Windows 版 ZoomIt](https://learn.microsoft.com/ja-jp/sysinternals/downloads/zoomit) にインスパイアされた、ネイティブ macOS メニューバーアプリです。
ZoomIt との機能互換を目指しており、システム全体で使えるホットキー、スムーズなズーム、画面上へのアノテーション機能を、最小限の権限で提供します。

https://github.com/user-attachments/assets/5f7563e4-584b-4bab-99c4-70f7d3265f54

[🎥 高画質で見る](images/demo.mp4)

## インストール

1. [Releases](https://github.com/07JP27/ZoomacIt/releases) から最新の `.dmg` をダウンロード
2. `.dmg` を開き、**ZoomacIt.app** を **Applications** フォルダにドラッグ
3. 「Appleは、“ZoomacIt”にMacに損害を与えたり、プライバシーを侵害する可能性のあるマルウェアが含まれていないことを検証できませんでした。」という警告が表示された場合は、以下のコマンドで検疫フラグを解除できます。本リポジトリのコードの内容を確認の上、自己責任で実行してください。
   ```bash
   xattr -cr /Applications/ZoomacIt.app
   ```
4. Applications から ZoomacIt を起動
5. プロンプトが表示されたら **画面収録** 権限を許可

## 現在の機能カバレッジ
| 機能 | 状態 |
|---|---|
|ズーム（静止画ズーム）|✅|
|ズーム（ライブズーム）||
|ドロー|✅|
|デモタイプ||
|休憩タイマー|✅|
|スニップ||
|録画||

## 機能詳細

各機能はグローバルホットキーまたはメニューバーのアイコンから起動できます。
メニューバーのアイコンをクリックすると、以下のようなメニューが表示されます。

<img src="images/app_bar.png" width="200">

### ズーム

**⌃1**（Control+1）を押すとズームモードに入ります。画面がキャプチャされ、ズームイン・アウトやパンが可能です。

#### 操作

| 入力 | アクション |
|---|---|
| マウス移動 | パン |
| スクロールホイール / ↑↓ | ズームイン / ズームアウト |
| クリック | ドローモードに入る（ズーム中の画面が描画キャンバスになります） |
| Escape | ズームモードを終了（ドローから入った場合はズームに戻る） |
| 右クリック | ズームモードを終了 |

#### ズーム → ドロー → ズームの流れ

ズームモード中にクリックすると、ズーム中の画面の上でドローモードに入ります。ドローモードで **Escape** を押すとズームモードに戻ります（テキストモードと同様の2段階解除）。もう一度 **Escape** を押すとズームを完全に終了します。

### ドロー

**⌃2**（Control+2）を押すとドローモードに入ります。画面がフリーズし、その上に描画できます。

#### 描画

| 入力 | アクション |
|---|---|
| ドラッグ | フリーハンド描画 |
| Shift + ドラッグ | 直線 |
| Control + ドラッグ | 矩形 |
| Tab + ドラッグ | 楕円 |
| Shift + Control + ドラッグ | 矢印 |

#### 色

| キー | 色 |
|---|---|
| R | 赤（デフォルト） |
| G | 緑 |
| B | 青 |
| O | オレンジ |
| Y | 黄 |
| P | ピンク |
| Shift + 色キー | 蛍光ペンモード |

#### ツール

| キー | アクション |
|---|---|
| T | テキスト入力モード |
| ⌃ + スクロールホイール | ペン幅の変更 |
| E | すべて消去 |
| W | ホワイトボード背景 |
| K | ブラックボード背景 |

#### アクション

| キー | アクション |
|---|---|
| ⌘Z | 元に戻す |
| ⌘C | クリップボードにコピー |
| ⌘S | ファイルに保存 |
| Space | カーソルを中央に移動 |
| Escape | テキストモード終了（テキスト確定）/ ドローモード終了 |
| 右クリック | ドローモード終了 |

#### テキストモード

**T** を押すとテキストモードに入ります。任意の場所をクリックしてテキストフィールドを配置し、入力を開始します。

- **別の位置をクリック** — 現在のテキストが確定（ラスタライズ）され、新しいテキストフィールドが配置されます
- **Escape** — 現在のテキストを確定し、ペンモードに戋ります（ドローモードは継続）
- **スクロールホイール** — フォントサイズ変更
- **色キー**（R/G/B/O/Y/P）— テキストの色を変更
- **右クリック** — 現在のテキストを確定してドローモードを終了

### 休憩タイマー

**⌃3**（Control+3）を押すと休憩タイマーを開始します。全画面のカウントダウンが表示され、デフォルトの時間（10分）で即座にカウントダウンが始まります。

#### タイマー操作

| 入力 | アクション |
|---|---|
| ↑ | 1分追加 |
| ↓ | 1分減少 |
| R / G / B / O / Y / P | タイマーの文字色を変更 |
| Escape | タイマーを終了 |

#### 動作

- ホットキーを押した瞬間にタイマーが開始します（確認ダイアログなし）
- カウントダウン中でも ↑/↓ で時間を調整できます
- タイマーが **0:00** になっても画面は消えず、経過時間が下に表示されます（例: `0:00 (1:15)`）
- 他のアプリに切り替えてもタイマーはバックグラウンドで継続動作します
- メニューバーアイコン → **Break** からも起動できます
- ドローモード（⌃2）と休憩タイマー（⌃3）は同時に使用できます

## 開発

本プロジェクトは Swift 6 + AppKit を使用し、macOS 26+ をターゲットとしています。Xcode プロジェクトは [xcodegen](https://github.com/yonaskolb/XcodeGen) により `src/project.yml` から生成されます。

```bash
make build       # デバッグビルド
make test        # ユニットテストの実行
make run         # ビルドしてアプリを起動
make release     # リリースビルド（Developer ID 署名付き）
make notarize    # リリースビルド + Apple 公証
make dmg VERSION=1.0.0  # 公証 + 配布用 DMG 作成
make clean       # ビルド成果物のクリーンアップ
make generate    # .xcodeproj を再生成（src/project.yml 編集後）
```

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

次のコマンドを実行します：

```bash
make dmg VERSION=1.0.0
```

Developer ID で署名されたリリースバイナリをビルドし、Apple に公証を申請し、公証チケットをステープルし、配布用 DMG にパッケージします。

> **注意:** 公証には [Apple Developer Program](https://developer.apple.com/programs/) のメンバーシップが必要です。`.env` ファイルは gitignore に含まれており、コミットしないでください。

## ライセンス

本プロジェクトは [GNU General Public License v3.0](LICENSE) の下で公開されています。
