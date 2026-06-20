# SportsPairing ライブラリの切り出しと重み標準化

## 概要

PadeLovers の試合マッチング機能を、複数アプリで再利用できる汎用ダブルス（2 対 2）
マッチメイク・ライブラリ **SportsPairing**（Swift Package）として切り出した。
あわせて PadeLovers 側に利用ガイド README を整備した。

PadeLovers の「出場回数の公平性 + ペア重複回避 + 固定ペア」というロジックをベースに、
各観点を **0〜1 に正規化した重み付きコスト関数** へ一般化し、
`MatchmakingWeights` でチューニングできるようにしたのが今回の主眼。

## 背景

- 田中（開発者）は「ヒットした iOS アプリの機能を横展開する」多産戦略を取っている。
- パデルの試合マッチングは、テニス・バドミントンなど他のダブルス競技にも転用可能な汎用ロジックであり、
  毎回作り直すのは無駄が大きい。
- PadeLovers には実戦投入済みの 2 系統のマッチング実装が存在した。
  - `GameOrganizeManager`（通常モード・CoreData・固定ペア・drive/back・スコア記録）
  - `MixGameViewModel`（ミックスモード・メモリ完結・軽量）
- これらを共通の核として標準化し、ライブラリ化したいというのが要件。

## 原因・課題（既存実装の特性）

既存ロジックを読み解いた結果、共通する設計と弱点が見えた。

- **公平性**：`getMinCountsWithPlayers` / `makeCandidates` で「出場回数が最小の人」から選ぶ。
  これは最重要の UX 要件（待ち時間・試合数の均等化）。
- **重複回避**：`pair1` / `pairedPlayers` に直近の相手を記録し、`filterCandidates` でハード除外。
  ただし「除外すると候補が消える → 制約を緩める」「全員と組んだら履歴をリセット」という
  特別処理が必要で、ロジックが複雑かつデッドロックしやすい。
- **固定ペア**：Pairing A / B の 2 組まで。条件分岐が長く、可読性が低い。
- **スキルバランス**：実装なし（プレースホルダの試作にのみ概念があった）。
- 既存の `SportsPairing/Sources/.../SportsPairing.swift` は `PairingStrategy` プロトコル + 未完成の
  `PairingManager`（`availableParticipants` 未定義・`ongoingMatches` 未初期化）で **コンパイル不能**な試作だった。

## 対応内容

### 1. PadeLovers の README 整備（`PadeLovers/README.md`）

アプリ概要・用語・主な機能・2 つのゲームモード・画面構成・基本的な使い方・
マッチングアルゴリズムの概要・アーキテクチャ・ディレクトリ構成を追記。
末尾から SportsPairing への導線を張った。App Store リンク・著者・ライセンスは維持。

### 2. SportsPairing ライブラリの実装

コンパイル不能だった試作を破棄し、以下の構成で作り直した。

```
Sources/SportsPairing/
├── SportsPairing.swift                 # 名前空間 + version
├── Models/
│   ├── Side.swift                      # .drive / .back / .any
│   ├── Player.swift                    # 参加者（ジェネリック ID）
│   ├── Team.swift                      # 2 人組（drive/back）
│   ├── Match.swift                     # 1 試合（teamA vs teamB + court）
│   └── FixedPair.swift                 # 固定ペア
├── Configuration/
│   ├── MatchmakingWeights.swift        # 標準化された重み + プリセット
│   └── MatchmakingOptions.swift        # 公平性モード / 固定ペア / skillRange
├── Engine/
│   ├── MatchScorer.swift               # コスト計算（内部）
│   └── Matchmaker.swift                # エンジン本体（公開 API）
└── Support/
    ├── MatchmakingError.swift
    └── SeededRandomNumberGenerator.swift  # SplitMix64・再現性用
```

公開 API の要点：

- `Matchmaker.makeMatch(from:using:)` … 1 試合を生成。
- `Matchmaker.makeRound(from:courts:using:)` … 複数コートを一括生成。
- `Matchmaker.apply(_:to:)` … 試合終了の結果（出場回数・履歴）をプレイヤー配列へ反映。

### 3. テスト（`Tests/SportsPairingTests`）

Swift Testing で 9 スイート 20 ケース。公平性・固定ペア・スキルバランス・希望サイド・
重複回避・ラウンド生成・再現性・異常系（人数不足・不正な固定ペア）を網羅。`swift test` 全通過。

## 設計判断

### なぜ「重み付きコスト関数」にしたか

- 元実装の「ハード除外 → 候補が消えたら緩める」は分岐が多く、リセット処理も必要で脆い。
- 重み付きコスト（最小コストを選ぶ）に置き換えると、「避けたいができないときは最も影響の小さい選択をする」
  が自然に表現でき、**候補ゼロによるデッドロックも履歴リセットも不要**になる。
- 各コスト項目を 0〜1 に正規化することで、重みが「項目間の相対重要度」という一貫した意味を持つ
  （= ユーザー要望の「重みをうまく標準化」）。

### なぜ公平性だけハード制約のままにしたか

- 出場回数の均等化はマッチングアプリの根幹であり、重みで緩めると体験が大きく劣化する。
- そこで公平性は「出場回数の昇順列が辞書順最小の候補だけ残す」というハード制約とし、
  その自由度の **中で** 重みによる最適化を行う 2 段階構成にした。
- 固定メンバー戦などのために `.off` モードも用意し、抜け道を確保。

### なぜ `PairingStrategy` プロトコルを捨てたか

- プロトコル + associatedtype による戦略差し替えは、この規模では過剰な抽象化。
- ユーザー要望は「1 つのアルゴリズムを重みで作り込む」なので、
  単一エンジン + チューナブルな重みに集約する方が目的に合致し、保守も容易。

### 一時対応か恒久対応か

- 恒久対応。ライブラリの v0.1.0 として設計を確定。属性バランスや大域最適化は将来拡張（README のロードマップ参照）。

## 技術的ポイント

- **ジェネリック ID**：`Player<ID: Hashable & Sendable>`。PadeLovers は `Int16`、UUID ベースのアプリにも対応。
  履歴は `[ID: Int]` 辞書で保持し、エンジンは純粋関数として動作（状態を持たない）。
- **飽和関数 `n/(n+1)`**：重複ペナルティを 0→0、1→0.5、2→0.667 … と飽和させる。
  「1 回でも重複は嫌、ただし増えるほど鈍く」という直感に合い、履歴リセットを不要にする鍵。
- **固定ペアのユニット化**：選出フェーズで固定ペアをサイズ 2 の分割不可ユニットとして扱い、
  公平性キーをペアの最小出場回数にすることで「ペアの片方が出場適齢なら一緒に呼ぶ」を実現。
- **組み合わせ爆発の抑制**：選出時は公平性キー昇順で上位 12 ユニットに探索を限定。
  公平性は最小回数を優先するため、低キーのユニットだけで最適解が得られる。
- **タイ・ブレイクの乱数**：コスト同点の候補は乱数で選ぶ。`SeededRandomNumberGenerator`（SplitMix64）で
  テスト・デバッグ時の再現性を担保。
- **Swift 6 / Sendable**：すべて `Sendable` な値型。`Matchmaker` も値型で、並行実行時も安全。
- 注意：実装中にエディタの SourceKit が同一モジュール内の別ファイル型を「型が見つからない」と誤検知したが、
  `swift build` は正常に通った（インデックス遅延による偽陽性）。判断はコンパイラ結果を優先すること。

## 影響範囲

- **PadeLovers**：`README.md` のみ更新。アプリの挙動・ソースには手を加えていない（回帰リスクなし）。
- **SportsPairing**：新規ライブラリ。既存の試作 `SportsPairing.swift` を置き換え（試作はコンパイル不能だったため実害なし）。
- 現時点で PadeLovers 本体は SportsPairing を **まだ参照していない**。次段階で差し替えると効果が出る。

## 確認内容

- 実施：`swift build`（警告・エラーなし）、`swift test`（9 スイート 20 ケース全通過）。
- 未実施：
  - PadeLovers 本体への組み込み（CoreData `Player` → `SportsPairing.Player` の詰め替え）。
  - 実機・シミュレータでの統合動作確認（ライブラリ単体のため未実施）。
  - 大規模人数（数百人）での性能測定。

## 今後の改善案

- **PadeLovers への統合**：`GameOrganizeManager` / `MixGameViewModel` を SportsPairing 呼び出しに置換し、
  二重実装を解消する。
- **属性バランス制約**：性別ミックス比率など（各チーム男女 1 人ずつ等）。
- **大域最適化**：1 試合ずつの貪欲法から、ラウンド全体を見たバッチ最適化へ。
- **レスト制御**：連続出場・連続休憩の偏りを重み化。
- **レーティング連携**：試合結果からスキルを自動更新し、`skill` に反映。
