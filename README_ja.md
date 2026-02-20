<p align="center">
  <img src="images/1024.png" width="200">
</p>

<p align="center"><a href="README.md">English</a> | 日本語</p>

# ZoomacIt
ZoomacIt は [Windows 版 ZoomIt](https://learn.microsoft.com/ja-jp/sysinternals/downloads/zoomit) にインスパイアされた、ネイティブ macOS メニューバーアプリです。
ZoomIt との機能互換を目指しており、システム全体で使えるホットキー、スムーズなズーム、画面上へのアノテーション機能を、最小限の権限で提供します。

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
|ズーム||
|ドロー|✅|
|テキスト||
|デモタイプ||
|休憩タイマー||
|スニップ||
|録画||

## 機能詳細
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
| T | テキスト入力モード（Escape で確定） |
| X | ぼかし（弱） |
| Shift + X | ぼかし（強） |
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
| Escape / 右クリック | ドローモード終了 |

## ライセンス

本プロジェクトは [GNU General Public License v3.0](LICENSE) の下で公開されています。
