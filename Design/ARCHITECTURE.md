# ZoomacIt — ソフトウェアアーキテクチャ

> **技術スタック:** Swift 6 + AppKit  
> **対象OS:** macOS 26+  
> **ビルドシステム:** Xcode プロジェクト（xcodegen で生成）

---

## ディレクトリ構成

```
ZoomacIt/
├── CONCEPT.md                     # 機能定義書（Windows版 ZoomIt v10.0 完全互換を目指す）
├── Tech-Design/
│   └── Draw.md                    # Draw機能の詳細技術設計
├── ARCHITECTURE.md                # 本ドキュメント
├── project.yml                    # xcodegen プロジェクト定義
│
├── ZoomacIt/                      # アプリケーション本体
│   ├── App/                       # アプリケーションライフサイクル
│   ├── Core/                      # OS基盤機能（権限・ホットキー）
│   ├── Overlay/                   # オーバーレイウィンドウ管理
│   ├── Draw/                      # 描画エンジン
│   ├── Models/                    # データモデル
│   ├── Utilities/                 # 汎用拡張
│   └── Resources/                 # Info.plist, Assets, Entitlements
│
└── ZoomacItTests/                 # ユニットテスト
```

---

## レイヤー構成

アプリケーションは**5つのレイヤー**で構成される。依存関係は上位→下位の一方向。

```
┌─────────────────────────────────────────────┐
│                  App 層                      │  アプリライフサイクル・UI起点
│  AppDelegate / StatusBarController          │
├─────────────────────────────────────────────┤
│                 Core 層                      │  OS機能への橋渡し
│  HotkeyManager / PermissionManager          │
├─────────────────────────────────────────────┤
│               Overlay 層                     │  ウィンドウ管理・画面キャプチャ
│  OverlayWindow / OverlayWindowController    │
├─────────────────────────────────────────────┤
│                Draw 層                       │  描画ロジック・レンダリング
│  DrawingCanvasView / ShapeRenderer / ...    │
├─────────────────────────────────────────────┤
│           Models + Utilities                 │  データ構造・拡張メソッド
│  Stroke / DrawingState / Extensions         │
└─────────────────────────────────────────────┘
```

---

## 各ディレクトリの役割

### `App/` — アプリケーションライフサイクル

| ファイル | 役割 |
|---|---|
| `AppDelegate.swift` | `@main` エントリーポイント。`NSApplicationDelegate` を実装。起動時に権限チェック・メニューバー・ホットキーを初期化し、Drawモードのトグルを管理する。`@MainActor` で隔離。 |
| `StatusBarController.swift` | `NSStatusItem` によるメニューバーアイコンの表示とメニュー構築。Draw起動・About・Quitのアクションを提供。 |

**設計ポイント:**
- `LSUIElement = YES` により Dock アイコンを非表示にし、メニューバー常駐アプリとして動作
- SwiftUI の `@main App` ではなく `NSApplicationDelegate` を採用（AppKit ネイティブのイベントハンドリングが必要なため）

---

### `Core/` — OS基盤機能

| ファイル | 役割 |
|---|---|
| `HotkeyManager.swift` | `CGEvent.tapCreate()` によるグローバルホットキーの登録と監視。⌃2 の押下を検知して Draw モードを起動する。`@unchecked Sendable` としてメインスレッド外のイベントタップから安全にコールバックを発火する。 |
| `PermissionManager.swift` | Accessibility（`AXIsProcessTrusted`）と Screen Recording（`CGPreflightScreenCaptureAccess`）の権限チェック・リクエスト。`@MainActor` で隔離し、`isAccessibilityGranted` / `isScreenRecordingGranted` は `nonisolated` として他スレッドからも参照可能。 |

**設計ポイント:**
- `CGEventTap` のコールバックは C 関数ポインタが必要なため `Unmanaged` で self を受け渡し
- タップが OS によりタイムアウト無効化された場合に自動再有効化する

---

### `Overlay/` — オーバーレイウィンドウ管理

| ファイル | 役割 |
|---|---|
| `OverlayWindow.swift` | `NSWindow` サブクラス。ボーダーレス・透明・最前面表示のウィンドウ。`canBecomeKey = true` でキーボードイベントを受信、`collectionBehavior` で全 Space に表示。 |
| `OverlayWindowController.swift` | オーバーレイの生成・表示・破棄のライフサイクル管理。`ScreenCaptureKit` で Draw モード開始時の画面をキャプチャし、`DrawingCanvasView` に背景として渡す。`@MainActor` で隔離。 |

**設計ポイント:**
- macOS 26 では `CGWindowListCreateImage` が廃止されたため `SCScreenshotManager.captureImage` を使用
- キャプチャは非同期（`async/await`）で行い、完了後に UI をセットアップ

---

### `Draw/` — 描画エンジン

Draw 層はアプリの中核。**3層合成アーキテクチャ**に基づいて設計されている。

```
描画時のレイヤースタック（draw(_:) 内で下から順に描画）:

  ┌──────────────────────────────┐
  │  activeFreehand (NSBezierPath) │  ← ドラッグ中のフリーハンド軌跡
  ├──────────────────────────────┤
  │  previewLayer   (NSBezierPath) │  ← ドラッグ中のシェイプ（直線/矩形/円/矢印）
  ├──────────────────────────────┤
  │  finishedLayer  (CGImage)      │  ← 確定済み全ストロークのラスタライズ済みビットマップ
  └──────────────────────────────┘
```

| ファイル | 役割 |
|---|---|
| `DrawingCanvasView.swift` | **最重要ファイル。** `NSView` サブクラスで3層合成を実装。`draw(_:)` で描画、`mouseDown/Dragged/Up` でストローク管理、`keyDown/Up` で色変更・ツール切替・Undo を処理。Esc/右クリックで Draw モード終了。⌘C でクリップボード、⌘S でファイル保存。 |
| `ShapeRenderer.swift` | 直線・矩形・楕円・矢印の `NSBezierPath` 生成。矢印は**ドラッグ開始点が先端**（ZoomIt 独自仕様）。 |
| `FreehandRenderer.swift` | Catmull-Rom スプライン補間によるフリーハンドパスのスムージング。生のマウス座標を滑らかな3次ベジェ曲線に変換。 |
| `StrokeManager.swift` | `CGImage` スナップショットによる Undo スタック管理。上限30レベル。 |
| `HighlighterRenderer.swift` | 半透明ハイライターストロークの描画補助。Multiply ブレンドモードでリアルなマーカー表現。 |
| `BlurRenderer.swift` | `CIGaussianBlur` を使用したぼかし描画（X / Shift+X）。元の画面キャプチャから対象領域を切り出してぼかす。 |
| `TextInputController.swift` | T キーで起動するテキスト入力モード。`NSTextView` をオーバーレイ上に配置し、Escape 確定時にオフスクリーン `CGBitmapContext` にレンダリングして `finishedLayer` に焼き込む。 |

**設計ポイント — 修飾キーによるシェイプ切替:**

ZoomIt の最大の特徴は「ツールバーや状態切替ではなく、ドラッグ中に修飾キーを押している間だけシェイプが変わる」こと。

```
mouseDown  → 開始点を記録
mouseDragged →
  修飾キーなし       → フリーハンド（ポイント蓄積 + Catmull-Rom）
  Shift 押下中       → 直線プレビュー
  Control 押下中     → 矩形プレビュー
  Tab 押下中         → 楕円プレビュー（Tab はキーイベントで boolean 管理）
  Shift + Control    → 矢印プレビュー
mouseUp    → previewLayer を finishedLayer にラスタライズして焼き込み
```

ドラッグ途中で修飾キーを変更しても即座に対応する。常に `mouseDown` の原点は保持される。

---

### `Models/` — データモデル

| ファイル | 役割 |
|---|---|
| `Stroke.swift` | 1本のストロークを表す構造体。ポイント配列・色・太さ・シェイプ種別・ハイライター/ぼかしフラグを保持。 |
| `DrawingState.swift` | 描画の現在状態（ミュータブル）。アクティブな色・ペン幅・ハイライターモード・ぼかしモード・テキストモード・Tab キー状態・背景モード（透明/ホワイトボード/ブラックボード）を管理。修飾キーから `ShapeType` を導出する `currentShapeType(modifiers:)` メソッドを提供。 |

**補助型:**
- `ShapeType` — `freehand / line / rectangle / ellipse / arrow`
- `PenColor` — `red / green / blue / orange / yellow / pink`（キー文字からのマッピング付き）
- `BlurStrength` — `weak (10pt) / strong (30pt)`

---

### `Utilities/` — 汎用拡張

| ファイル | 役割 |
|---|---|
| `CGContext+Extensions.swift` | RGBA `CGBitmapContext` の生成ファクトリ。`finishedLayer` へのストローク焼き込みに使用。 |
| `NSBezierPath+Extensions.swift` | `NSBezierPath` → `CGPath` 変換。AppKit の `NSBezierPath` を CoreGraphics コンテキストに描画する際に必要。 |
| `NSScreen+Extensions.swift` | マウスカーソル位置のスクリーン検出、Retina スケールファクター・ピクセルサイズの取得。 |

---

### `Resources/` — リソース・設定

| ファイル | 役割 |
|---|---|
| `Info.plist` | `LSUIElement = YES`（Dock 非表示）、`NSScreenCaptureUsageDescription`（Screen Recording 用途説明）、バンドル情報。 |
| `ZoomacIt.entitlements` | `com.apple.security.app-sandbox = false`（CGEventTap / ScreenCaptureKit にはサンドボックス外が必要）、`cs.allow-unsigned-executable-memory = true`。 |
| `Assets.xcassets/` | AppIcon（空スロット）。 |

---

### `ZoomacItTests/` — ユニットテスト

| ファイル | テスト対象 |
|---|---|
| `StrokeManagerTests.swift` | Undo スタックの push/pop、30レベル上限キャップ、履歴クリア |
| `DrawingStateTests.swift` | デフォルト値、ペン幅の上限/下限バウンド、色キーマッピング |
| `ShapeRendererTests.swift` | 直線/矩形/楕円/矢印パスの要素数検証 |
| `FreehandRendererTests.swift` | 空ポイント、1点、2点、複数点のスムージング結果検証 |

---

## データフロー

### Draw モード起動〜終了の流れ

```
ユーザー: ⌃2 押下
    │
    ▼
HotkeyManager (CGEventTap コールバック)
    │ onDrawHotkey()
    ▼
AppDelegate.toggleDrawMode()
    │
    ▼
OverlayWindowController.showOverlay()
    │ ① ScreenCaptureKit で画面キャプチャ
    │ ② OverlayWindow を生成（全画面・透明・最前面）
    │ ③ DrawingCanvasView を配置（キャプチャ画像を背景に）
    ▼
DrawingCanvasView がキーウィンドウに
    │ マウス/キーボードイベントを受信
    │ ストローク描画 → finishedLayer に焼き込み
    ▼
ユーザー: Escape or 右クリック
    │
    ▼
DrawingCanvasView.onDismiss()
    │
    ▼
OverlayWindowController.dismiss()
    │ ウィンドウ破棄
    ▼
AppDelegate.drawModeDidEnd()
    │ overlayController = nil
    ▼
通常状態に復帰
```

### ストローク確定の流れ

```
mouseDown
    │ dragOrigin = 現在位置
    │ freehandPoints = [現在位置]
    ▼
mouseDragged (修飾キーで分岐)
    ├─ フリーハンド → freehandPoints に追加 → Catmull-Rom → activeFreehand
    └─ シェイプ    → dragOrigin〜現在位置 → ShapeRenderer → previewLayer
    │
    ▼ setNeedsDisplay(bounds) → draw(_:) で3層を合成描画
    │
mouseUp
    │ ① strokeManager.pushUndoSnapshot(finishedLayer)  ← Undo 用保存
    │ ② CGBitmapContext に finishedLayer + 新ストロークを合成
    │ ③ → 新しい CGImage を finishedLayer に設定
    │ ④ previewLayer / activeFreehand を nil に
    ▼
    setNeedsDisplay(bounds)
```

---

## 技術選定の理由

### Swift + AppKit（SwiftUI 不採用）

| 観点 | AppKit | SwiftUI |
|---|---|---|
| 透明オーバーレイウィンドウ | `NSWindow` で直接制御 | `NSViewRepresentable` ハック必要 |
| 3層合成描画 | `draw(_:)` + `CGContext` で命令的に制御 | `Canvas` は宣言的、毎フレーム全再描画 |
| 修飾キー中ドラッグ | `mouseDragged` + `modifierFlags` | `DragGesture` では修飾キー取得不可 |
| イベントハンドリング | mouseDown/Dragged/Up/keyDown/flagsChanged | 粒度が不足 |

Draw 機能の全要件が AppKit ネイティブ API に 1:1 で対応するため採用。
将来の設定画面は `NSHostingController` 経由で SwiftUI を導入可能。

### Xcode プロジェクト（SPM 不採用）

`.app` バンドル生成、`Info.plist`、コード署名、Entitlements の管理が Xcode ネイティブで必要。
`project.yml`（xcodegen）から生成し、`.xcodeproj` 自体は Git 管理対象。

---

## 必要な macOS 権限

| 権限 | 用途 | API |
|---|---|---|
| **Accessibility** | `CGEventTap` によるグローバルホットキー | `AXIsProcessTrusted()` |
| **Screen Recording** | Draw モード開始時の画面キャプチャ | `CGPreflightScreenCaptureAccess()` / `ScreenCaptureKit` |

権限が拒否された場合の動作:
- Accessibility 拒否 → ホットキー無効（メニューからのみ起動可能）
- Screen Recording 拒否 → 黒背景上に描画（graceful degradation）
