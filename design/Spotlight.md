# Spotlight 機能 詳細設計

## 概要

Draw モード中に有効化できる **「注目矩形以外を半透明グレーで覆う」** サブツール。
プレゼンや画面共有で「ここを見てほしい」を強調する用途。Windows 版 ZoomIt にはない ZoomacIt 独自の追加機能。

---

## A. 設計方針

### 1. Draw モードのサブツールとして統合

Spotlight を独立モード（新ホットキー ⌃4 など）にせず、Draw モード内のサブツールとして実装する。

**理由:**
- 「注目を促す」という目的が Draw（矢印・囲み線）と同じ。新ホットキーを増やすと使われなくなる。
- Spotlight + 描画の **併用** が強力（暗くした明部に矢印を描けば究極の注目誘導になる）。
- 既存の `DrawingCanvasView` を拡張するだけで実装でき、`Overlay/` に新ウィンドウクラスを追加する必要がない。

Zoom モードと統合しない理由: Zoom は「拡大して詳細を見せる」目的で、Spotlight の「広い文脈の中で一部に注目させる」と意図が逆。

### 2. MVP スコープ

| 含む | 含まない |
|------|----------|
| 矩形 1 つの spotlight | 複数矩形 |
| ドラッグで作成、再ドラッグで上書き | ハンドルでのリサイズ・移動 |
| ↑/↓ で暗部濃度調整 | アニメーション付きの矩形遷移 |
| 設定での初期濃度変更 | 矩形の形状（円形・自由形） |
| Spotlight 中の描画併用 | Spotlight 専用の undo スタック分離 |

矩形編集を入れない理由: 「間違えたら再ドラッグで上書き」が直感的で、ハンドル UI を出すと操作モードの状態数が増えて混乱する。

---

## B. 操作体系

### B.1 起動・終了

| 操作 | 効果 |
|------|------|
| `S` キー | Spotlight ツールを ON。次のドラッグで矩形を確定 |
| ドラッグ | 矩形プレビュー → mouseUp で spotlight 確定 |
| 矩形確定後の再ドラッグ | 既存矩形を破棄して新規作成（上書き）|
| `S` キー（再押下） | Spotlight OFF、矩形クリア |
| `Esc` | Draw モード終了（spotlight も同時に消える）|

### B.2 描画併用

Spotlight 確定後は **自動的に通常の描画ツールに戻る**。Spotlight 矩形は維持されたまま、ペン・シェイプ・テキストを使える。

これにより以下のフローが成立:
1. `S` 押下 → ドラッグで spotlight 矩形を作る
2. そのまま矢印を描く（修飾キーなしのフリーハンド、または Shift+⌃ で矢印）
3. `S` をもう一度押すと spotlight 解除、描画は残る

### B.3 暗部濃度の動的調整

| 操作 | 効果 |
|------|------|
| `↑` キー | 暗部濃度を +5%（最大 0.9）|
| `↓` キー | 暗部濃度を -5%（最小 0.1）|

**有効条件:** Spotlight が有効（矩形が確定済み）の場合のみ。
**衝突回避:** 既存の Draw 機能でペン太さ調整は `⌃ + ↑/↓` または `⌃ + スクロール` のみ。`↑/↓` 単体は未割り当てなので衝突しない。

---

## C. レンダリング設計

### C.1 レイヤー構成（Spotlight 追加版）

```
描画レイヤー構成（下→上）:
  [ background        (CGImage / 白 / 黒) ]    ← 既存
  [ finishedLayer     (CGImage)            ]   ← 既存：確定済みストローク
  [ spotlightLayer    (描画時に都度生成)    ]   ← 新規：暗部マスク
  [ previewLayer      (NSBezierPath)       ]   ← 既存：シェイプ プレビュー
  [ activeFreehand    (NSBezierPath)       ]   ← 既存：フリーハンド
```

**重要:** `spotlightLayer` を `previewLayer` / `activeFreehand` の **下** に置くことで、暗くなったエリア上にも描画線が常に視認できる順序になる。

### C.2 Spotlight 描画方法

`DrawingCanvasView.draw(_:)` 内で、以下の順序で描画:

```swift
// finishedLayer 描画後、previewLayer 描画前に挿入
if let rect = drawingState.spotlightRect {
    drawSpotlightMask(rect: rect, in: context)
}
```

`drawSpotlightMask` の実装方針:

```
1. context.saveGState()
2. context.setFillColor(NSColor.black.withAlphaComponent(spotlightDarkness).cgColor)
3. context.fill(bounds)                    // 全体を暗くする
4. context.setBlendMode(.clear)
5. context.fill(rect)                      // spotlight 矩形をくり抜く
6. context.restoreGState()
```

`.clear` ブレンドモードは「描画したピクセルを完全透明にする」ので、矩形領域だけ元の背景が透けて見える。

### C.3 Spotlight 作成中のプレビュー

ドラッグ中は `previewLayer` を流用するのではなく、専用の `spotlightDragRect: CGRect?` を `DrawingCanvasView` に持たせる:

```
mouseDragged (Spotlight ツール時):
  spotlightDragRect = CGRect(from: dragOrigin, to: currentPoint).standardized

draw():
  if let dragRect = spotlightDragRect {
      drawSpotlightMask(rect: dragRect, in: context)  // ライブプレビュー
  } else if let confirmedRect = drawingState.spotlightRect {
      drawSpotlightMask(rect: confirmedRect, in: context)  // 確定済み
  }

mouseUp (Spotlight ツール時):
  drawingState.spotlightRect = spotlightDragRect
  spotlightDragRect = nil
  drawingState.activeTool = .draw   // 描画ツールに自動復帰
```

---

## D. 状態管理

### D.1 `DrawingState` への追加

```swift
enum DrawingTool {
    case draw          // 通常の描画（既存挙動）
    case spotlight     // Spotlight 矩形作成中
}

var activeTool: DrawingTool = .draw
var spotlightRect: CGRect?           // nil なら spotlight 無効
var spotlightDarkness: CGFloat = Settings.shared.spotlightDarkness
```

### D.2 状態遷移

```
[Draw 通常状態] --(S 押下)--> [Spotlight ツール]
                                    |
                            (ドラッグ→mouseUp)
                                    |
                                    v
                          [Spotlight 有効・Draw 通常状態]
                                    |
                                    +-- (S 押下) --> [Spotlight OFF]
                                    +-- (Esc) --> [Draw モード終了]
                                    +-- (S 押下→再ドラッグ) --> 上書き
```

### D.3 mouseDown の分岐

`DrawingCanvasView.mouseDown` の冒頭で `activeTool` を見て分岐:

```swift
override func mouseDown(with event: NSEvent) {
    if drawingState.isTextMode { ...既存... }

    let point = convert(event.locationInWindow, from: nil)
    dragOrigin = point

    if drawingState.activeTool == .spotlight {
        // Spotlight ドラッグ開始
        spotlightDragRect = CGRect(origin: point, size: .zero)
        isDragging = true
        return
    }

    // ...既存のフリーハンド/シェイプ初期化...
}
```

`mouseDragged` / `mouseUp` も同様に冒頭で分岐。Spotlight ツール時は既存の `freehandPoints` / `previewLayer` を **触らない**。

---

## E. キーバインド統合

`DrawingCanvasView.keyDown` への追加:

```swift
case "S" where !modifiers.contains(.command):  // ⌘S（保存）と区別
    toggleSpotlightTool()

case String(UnicodeScalar(NSUpArrowFunctionKey)!) where drawingState.spotlightRect != nil:
    drawingState.spotlightDarkness = min(drawingState.spotlightDarkness + 0.05, 0.9)
    setNeedsDisplay(bounds)

case String(UnicodeScalar(NSDownArrowFunctionKey)!) where drawingState.spotlightRect != nil:
    drawingState.spotlightDarkness = max(drawingState.spotlightDarkness - 0.05, 0.1)
    setNeedsDisplay(bounds)
```

`toggleSpotlightTool()` の挙動:

```swift
private func toggleSpotlightTool() {
    if drawingState.spotlightRect != nil {
        // 既に有効 → クリア
        drawingState.spotlightRect = nil
        drawingState.activeTool = .draw
    } else {
        // 無効 → ツール ON（次のドラッグ待ち）
        drawingState.activeTool = .spotlight
    }
    updateCursor()
    setNeedsDisplay(bounds)
}
```

**カーソル:** Spotlight ツール ON 中は `.crosshair`（既存と同じ）で十分。視覚的フィードバックは「カーソル形」より「次のドラッグで実際に矩形が出る」ことで分かる。

---

## F. Undo との統合

Spotlight 操作も `⌘Z` で undo できるべき。既存の `StrokeManager.pushUndoSnapshot` は `finishedLayer` と `backgroundMode` を保存しているので、これに `spotlightRect` を追加する。

```swift
struct UndoSnapshot {
    let finishedLayer: CGImage?
    let backgroundMode: DrawingState.BackgroundMode
    let spotlightRect: CGRect?     // 追加
}
```

`pushUndoSnapshot` を呼ぶタイミング（既存のストローク確定時に加えて）:
- Spotlight 矩形確定時（mouseUp 直前）
- Spotlight クリア時（S での無効化直前）
- Spotlight 上書き時（mouseUp 直前。1 度の操作で 1 回）

---

## G. 設定

`Settings` に追加:

```swift
// Keys
static let spotlightDarkness = "spotlightDarkness"

// registerDefaults に追加
Keys.spotlightDarkness: 0.6,

// アクセサ
var spotlightDarkness: CGFloat {
    get { CGFloat(defaults.double(forKey: Keys.spotlightDarkness)) }
    set { defaults.set(Double(newValue), forKey: Keys.spotlightDarkness) }
}
```

`DrawTab.swift` に「Spotlight 暗部の濃さ（0.1 〜 0.9）」スライダーを追加。

`resetToDefaults` の `allKeys` リストにも追加。

---

## H. エクスポート（⌘C / ⌘S）との整合

`renderFinalImage()` も spotlight を含めて書き出す必要がある。`DrawingCanvasView` の既存実装に同じ `drawSpotlightMask` 呼び出しを `finishedLayer` 描画後に追加するだけで対応可能。

これにより「spotlight 込みのプレゼン画面」をスクショとして共有できる。

---

## I. テスト方針

ユニットテスト（`ZoomacItTests/`）で以下をカバー:

| テスト対象 | 内容 |
|-----------|------|
| `DrawingState` | `activeTool` の遷移、`spotlightDarkness` のクランプ（0.1 〜 0.9）|
| Spotlight 矩形の標準化 | dragOrigin から各方向にドラッグした時の `CGRect.standardized` 変換 |
| Settings | `spotlightDarkness` の永続化と読み出し |

**ユニットテスト対象外:**
- `DrawingCanvasView` の描画結果（既存方針通り、ビュー系は手動検証）
- キーバインドの統合動作（同上）

---

## J. 実装順序

1. `Settings.swift`: `spotlightDarkness` 追加 + デフォルト登録
2. `DrawingState.swift`: `DrawingTool` enum と `activeTool` / `spotlightRect` / `spotlightDarkness` 追加
3. `StrokeManager.swift` / `UndoSnapshot`: `spotlightRect` を含める
4. `DrawingCanvasView.swift`:
   - `spotlightDragRect` プロパティ追加
   - `drawSpotlightMask` メソッド追加
   - `draw(_:)` の順序に組み込み
   - `mouseDown` / `mouseDragged` / `mouseUp` で `activeTool` 分岐
   - `keyDown` に `S` / `↑` / `↓` 追加
   - `renderFinalImage()` にも spotlight を反映
5. `DrawTab.swift`: Spotlight 暗部スライダー追加
6. テスト追加

---

## K. 既知の制約・将来拡張余地

- **MVP では矩形 1 つのみ**。複数 spotlight が必要なら配列化と「どれを編集中か」の状態追加が必要。
- **MVP では矩形編集なし**。リサイズ/移動を入れる場合はハンドル UI と hit-test、編集モード状態が必要になり、操作の状態数が大きく増える。
- **アニメーション付きフェード**は将来検討。Core Animation で `spotlightLayer` を実 NSView レイヤー化すれば実現できるが、現在の `draw(_:)` 中心の設計から外れる。
- **円形 spotlight** はユースケース次第。実装は `drawSpotlightMask` 内の `context.fill(rect)` を `context.fillEllipse(in: rect)` に切り替えるだけで可能。
