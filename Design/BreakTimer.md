# Break Timer機能 詳細仕様

### A. タイマーの起動と基本動作

| 操作 | 効果 |
|---|---|
| ホットキー（⌃3） | タイマーウィンドウを全画面表示して即座にカウントダウン開始 |
| メニューバーアイコン → Break | 同上 |
| Escape | タイマーを終了・画面を元に戻す |

**重要な挙動:**  
- ホットキーを押した瞬間、**前回設定した時間でそのまま自動スタート**する（確認ダイアログなし）
- スタート直後の数秒間だけ矢印キー / スクロールホイールで時間を増減できる
- 他のアプリに切り替えてもタイマーはバックグラウンドで継続動作
- メニューバーアイコンをクリックするとタイマー画面に戻れる

---

### B. タイマー表示中の操作

| 操作 | 効果 |
|---|---|
| ↑ / スクロールアップ | 残り時間を1分増やす |
| ↓ / スクロールダウン | 残り時間を1分減らす |
| R / G / B / O / Y / P | タイマーの文字色を変更（Drawと同じ色キー） |
| Escape | タイマー終了 |

**時間変更の受付タイミング:**  
ZoomItはカウントダウン開始後も↑↓で時間を変更できる。これは発表中に急遽「あと5分延長」がキーボードだけで完結するための設計。Mac版でも同様に実装すること。

---

### C. タイマー期限切れ後の挙動

- カウントが `0:00` になっても**タイマー画面は消えない**
- `0:00` の下に経過時間（elapsed）を括弧書きで表示し続ける  
  例: `0:00` → `0:00 (0:32)` → `0:00 (1:15)` ...
- Escapeを押すまでタイマー画面は維持される
- オプションで**期限切れ時に音を鳴らす**（後述）

---

### D. 設定項目（Advanced）

設定ダイアログのBreakタブ → Advancedボタンで設定可能。

#### デフォルト時間
- 設定値: デフォルト10分（一部の資料では2分とあるが、ZoomItの設定ダイアログで変更可）

#### タイマー表示位置
3×3のグリッドから選択（9か所）

```
┌───┬───┬───┐
│TL │TC │TR │
├───┼───┼───┤
│ML │ C │MR │   ← デフォルト: Center（C）
├───┼───┼───┤
│BL │BC │BR │
└───┴───┴───┘
```

#### タイマーの不透明度
- 10% 〜 100%（デフォルト: 100%）

#### 背景表示

| 設定 | 挙動 |
|---|---|
| 背景なし（デフォルト） | 真っ黒な画面にタイマーのみ表示 |
| デスクトップをフェードして背景に使用 | 現在のスクリーンをキャプチャ → 暗くフェードしたものを背景に |
| 画像ファイルを背景に使用 | 指定した画像ファイルを全画面表示し、その上にタイマーを重ねる |

**注意:** elapsed表示をONにしている場合、`0:00`以降にタイマー表示領域が上下に拡張されるため、背景画像を使う場合はその余白を考慮したデザインが必要。

#### 期限切れ時の音
- ON/OFF切替（デフォルト: OFF）
- ONの場合: 任意の音声ファイル（WAV等）を指定

#### elapsed表示（経過時間）
- ON/OFF切替（デフォルト: ON）
- 期限切れ後に `0:00 (経過時間)` 形式で表示

---

### E. Mac実装の技術方針

#### タイマーウィンドウ

```swift
// Drawオーバーレイとは独立した別ウィンドウ
let timerWindow = NSWindow(
    contentRect: NSScreen.main!.frame,
    styleMask: [.borderless],
    backing: .buffered,
    defer: false
)
timerWindow.level = .screenSaver
timerWindow.ignoresMouseEvents = true   // タイマー中は操作を下のアプリに透過
timerWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
```

#### タイマーのカウントダウンループ

`Timer.scheduledTimer`ではなく`DispatchSourceTimer`を使う。  
理由: `scheduledTimer`はRunLoopのブロックで精度が落ちる。発表中にCPU負荷が上がっても1秒の精度を保つため。

```swift
let source = DispatchSource.makeTimerSource(queue: .main)
source.schedule(deadline: .now(), repeating: .seconds(1))
source.setEventHandler {
    self.remainingSeconds -= 1
    self.updateDisplay()
    if self.remainingSeconds <= 0 {
        self.handleExpiration()
    }
}
source.resume()
```

#### 背景: デスクトップフェード

`ScreenCaptureKit`でタイマー起動直前のスクリーンをキャプチャ → `CIFilter`で暗くフェード → 背景として描画。  
スタティックな1枚絵なのでリアルタイム更新は不要（= Live Zoomの複雑さは不要）。

#### 背景: 画像ファイル

`NSImageView`で全画面に`scaleToFill`で表示するだけ。実装コストはほぼゼロ。

#### タイマー文字のレンダリング

- フォント: システムフォント（San Francisco）のMonospaced Digit variant  
  → 数字が変わっても横幅が変わらず、テキストが左右に揺れない
- `NSAttributedString` + `CTFrameDraw`でレンダリング

```swift
let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
```

#### elapsed表示による領域拡張

期限切れ後にelapsed行が追加されるため、タイマーのバウンディングボックスが縦に拡大する。  
これをアニメーションなしで突然変えるとガタつくので、`NSAnimationContext`で高さを0からフェードインさせる。

#### 音の再生

```swift
// AVFoundation
let player = try AVAudioPlayer(contentsOf: soundFileURL)
player.play()
```

macOSのシステムサウンドを使う場合は`NSSound`でもよい。

#### バックグラウンド継続

タイマーは`DispatchSourceTimer`なのでアプリがバックグラウンドに回っても継続する。  
メニューバーアイコンのクリックで`timerWindow.makeKeyAndOrderFront`を呼んでフォアグラウンドに戻す。

---