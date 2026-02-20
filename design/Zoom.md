# Zoom機能 詳細仕様

### A. ZoomモードとLive Zoomの違い

ZoomItには2種類のズームがある。Mac実装でも両方必須。

| | Still Zoom | Live Zoom |
|---|---|---|
| ホットキー（デフォルト） | ⌃1 | ⌃⇧1 |
| 画面更新 | **静止**（スナップショット） | **リアルタイム**（動画・ターミナル等が動き続ける） |
| Draw連携 | ズーム中クリックで即Draw移行 | Drawに入った瞬間に静止に切替 |
| 実装難易度 | 低（1枚のCGImageを拡大） | 高（ScreenCaptureKitのストリームが必要） |

> **Live ZoomでDrawに入ると静止する**という挙動は仕様。リアルタイム映像に描画を重ねる複雑性を避けるため。

---

### B. Still Zoom の操作体系

#### ズームの起動・終了

| 操作 | 効果 |
|---|---|
| ⌃1（ホットキー） | 現在のマウス位置を中心にスナップショットを取得してズーム開始 |
| マウスホイール上 / ↑ | ズームイン |
| マウスホイール下 / ↓ | ズームアウト |
| マウス移動 | ズーム中の表示領域をパン |
| Escape / 右クリック | ズーム終了・元画面に戻る |
| 左クリック | **Drawモードに移行**（ズーム状態を維持したまま描画可能） |

#### ズームレベルの詳細

- デフォルト倍率: 設定ダイアログで指定（デフォルト2倍程度）
- ズームレベルは**設定で記憶**され、次回起動時も維持
- ⌃+スクロール: ペンサイズ変更（ズームレベルではない）

#### ズーム中のDraw移行

```
[ ⌃1で起動 ]
    ↓
[ スナップショット取得・ズーム表示 ]
    ↓
[ 左クリック ] ← これでDrawモードに入る
    ↓
[ ズームしたまま描画可能 ]
    ↓
[ Escape ] → ズーム+描画ともに終了
```

---

### C. Live Zoom の操作体系

| 操作 | 効果 |
|---|---|
| ⌃⇧1（ホットキー） | リアルタイムズーム開始 |
| マウスホイール上 / ↑ / ↓ | ズームイン / ズームアウト |
| マウス移動 | 表示領域をパン |
| ⌃2（Drawホットキー） | **Drawモードに移行（この瞬間に画面が静止する）** |
| Escape / 右クリック | 終了 |

> **重要:** Live Zoom中はマウスカーソルが常に見える。Still Zoomはスナップショットなのでカーソルが写らない場合がある。

---

### D. ズームウィンドウの挙動

- ズームは**全画面オーバーレイ**として表示（タスクバー等も隠れる）
- ズーム中、他のアプリへの操作は**すべてブロック**される
- マルチモニター環境: **カーソルがあるモニターのみ**にズームが適用
  - 別モニターに移動するにはEscapeでいったん終了が必要

---

### E. 設定項目（Zoomタブ）

| 設定 | 内容 |
|---|---|
| ズームホットキー | カスタマイズ可能（デフォルト: ⌃1） |
| Live Zoomホットキー | カスタマイズ可能（デフォルト: ⌃⇧1） |
| アニメーション | ズームイン/アウト時のスムーズアニメーションのON/OFF |

---

### F. Mac実装の技術方針

#### Still Zoom

**スナップショット取得 → CGImageをアフィン変換で拡大表示** の組み合わせが最も単純かつ確実。

```
1. ⌃1が押された瞬間に SCScreenshotManager でスクリーン全体をキャプチャ
2. 取得した CGImage をオーバーレイウィンドウの NSImageView / CALayer に設定
3. マウス移動に合わせて表示領域（CGRect）をずらす（パン）
4. スクロールホイールでズーム倍率を変更 → CALayer.contentsRect を更新
```

**CALayer.contentsRect を使う理由:**  
`CGAffineTransform`でNSViewを拡大するとぼやけるが、  
`CALayer`の`contentsRect`（0.0〜1.0のUV座標系）を更新する方式なら  
GPU側でサンプリングされ、高品質かつ低CPU負荷になる。

```swift
// ズーム倍率とパン位置からcontentsRectを計算
func updateContentsRect(zoom: CGFloat, pan: CGPoint, imageSize: CGSize) -> CGRect {
    let visibleW = 1.0 / zoom
    let visibleH = 1.0 / zoom
    let originX = (pan.x / imageSize.width) - visibleW / 2
    let originY = (pan.y / imageSize.height) - visibleH / 2
    return CGRect(
        x: originX.clamped(to: 0...(1 - visibleW)),
        y: originY.clamped(to: 0...(1 - visibleH)),
        width: visibleW,
        height: visibleH
    )
}
```

#### Live Zoom

**ScreenCaptureKit（SCStream）でフレームを受け取り、MetalまたはCALayerに表示する。**  
これがZoom機能の中で最も技術的難易度が高い部分。

```swift
// 最小構成のSCStream設定
let config = SCStreamConfiguration()
config.width = Int(NSScreen.main!.frame.width * NSScreen.main!.backingScaleFactor)
config.height = Int(NSScreen.main!.frame.height * NSScreen.main!.backingScaleFactor)
config.minimumFrameInterval = CMTime(value: 1, timescale: 60)  // 最大60fps
config.pixelFormat = kCVPixelFormatType_32BGRA
config.showsCursor = true   // Live Zoomではカーソルを表示

// SCStreamOutputプロトコルでフレームを受け取る
func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
    guard let pixelBuffer = buffer.imageBuffer else { return }
    // CALayerのcontentsをCVPixelBufferから更新
    DispatchQueue.main.async {
        self.overlayLayer.contents = pixelBuffer  // Metalテクスチャ経由でゼロコピー
    }
}
```

**ゼロコピー描画の重要性:**  
`CMSampleBuffer → CGImage → NSImage → NSImageView` のパスは毎フレームメモリコピーが発生してCPUが燃える。  
`CALayer.contents`に`CVPixelBuffer`を直接渡す（Metalバックエンド経由）のがベストプラクティス。

#### SCStream の権限とSandbox問題

`ScreenCaptureKit`の使用には**Screen Recording権限**が必要（macOS 12.3+）。

```swift
// 初回起動時に権限を確認・要求
SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
    if let error = error {
        // 権限なし → System Settings への誘導UIを表示
        self.promptForPermission()
    }
}
```

**macOS 26.1 (Tahoe) の注意点:**  
`.app`バンドルでない plain executable は Screen Recording の権限UIに表示されなくなった（Developer Forums確認）。  
→ **必ず `.app` バンドルとして配布すること。** CLIツールとしての配布は権限管理が壊れる。

#### パン（表示領域の移動）

Still/Live どちらも **マウス座標 → 表示中心点** のマッピングが必要。

```
ズーム中のマウス移動 = 「どこを見ているか」の中心点を変える

pan.x = mousePosition.x / screenWidth   (0.0 〜 1.0)
pan.y = mousePosition.y / screenHeight  (0.0 〜 1.0)
→ これをcontentsRectのoriginにフィードバック
```

エッジに達したらパンを止める（クランプ処理）ことで、画像外の黒帯が見えないようにする。

#### アニメーション

ズームイン/アウトのスムーズアニメーションは`CABasicAnimation`で実装。

```swift
let anim = CABasicAnimation(keyPath: "contentsRect")
anim.duration = 0.15
anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
overlayLayer.add(anim, forKey: "zoom")
overlayLayer.contentsRect = newRect
```

アニメーションOFF設定のときは`CATransaction.setDisableActions(true)`でスキップ。

---

### G. Still ZoomとLive Zoomの実装フロー比較

```
【Still Zoom】
⌃1押下
  → SCScreenshotManager.captureImage()  ← 1枚だけキャプチャ
  → CGImageをCALayerに設定
  → マウス移動/スクロールでcontentsRect更新
  → Escape/右クリックでオーバーレイ破棄

【Live Zoom】
⌃⇧1押下
  → SCStream.startCapture()  ← フレームストリーム開始
  → 毎フレーム: pixelBuffer → CALayer.contents更新（60fps）
  → マウス移動/スクロールでcontentsRect更新（Still Zoomと同じ）
  → ⌃2押下 → SCStream.stopCapture() → スナップショット1枚に切替 → Drawモードへ
  → Escape/右クリック → SCStream.stopCapture() → オーバーレイ破棄
```

---