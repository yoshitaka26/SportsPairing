# SportsPairing

**さまざまなスポーツのペアリング／組み合わせを自動化する汎用ライブラリ**（Swift Package）。

「次に誰と誰を組ませ、どのコートで対戦させるか」を自動で決めます。
パデル・テニス・バドミントン・卓球・ピックルボールなど、**シングルス（1 対 1）・ダブルス（2 対 2）**で
人を入れ替えながら回す競技全般に使えます。

2 つの使い方を提供します。

1. **ライブメイク（``Matchmaker``）**: 参加者が入れ替わる現場で、その場の状況から次の 1 試合（または 1 ラウンド）を組む。
2. **総当たり表（``RoundRobinGenerator`` / 乱数）**: 背番号で全カードを事前に列挙し、公平な順に並べた進行表を作る。

ベースは [PadeLovers](../PadeLovers/) の実戦投入済みマッチングロジック。
それを **重みで標準化** し、複数アプリで再利用できる形に切り出したものです。

```swift
let players = [
    Player(id: 1, name: "Alice"),
    Player(id: 2, name: "Bob"),
    Player(id: 3, name: "Carol"),
    Player(id: 4, name: "Dave"),
]
let matchmaker = Matchmaker<Int>()
let match = try matchmaker.makeMatch(from: players)
print(match.summary)   // "Alice / Bob  vs  Carol / Dave"
```

---

## ✨ 特徴

- **多競技対応**：シングルス / ダブルス（サイドあり・なし）を ``MatchFormat`` で切り替え。`teamSize` は 3 以上も可。
- **総当たり表（乱数）**：背番号ベースで全カードを公平な順に並べる進行表を生成。
- **出場回数の公平性**：出場が少ない人を優先し、待ち時間・試合数の偏りを抑える（ハード制約）。
- **重複回避**：同じ味方・同じ対戦相手が続かないようにする。
- **固定ペア**：「この 2 人は必ず同じチーム」という制約に対応。
- **スキルバランス**：両チームの実力が拮抗するように分割（任意）。
- **希望サイド**：ドライブ / バックの希望を尊重して配置（任意）。
- **重みで挙動を調整**：上記の優先度を ``MatchmakingWeights`` / ``RoundRobinWeights`` で一括チューニング。
- **再現性**：シード付き乱数でテスト・デバッグ時に同じ結果を再現可能。
- **依存ゼロ / Sendable**：標準ライブラリのみ。Swift 6・iOS 17+ 対応の純粋な値型設計。

---

## 📦 インストール

`Package.swift` に追加：

```swift
dependencies: [
    .package(path: "../SportsPairing")          // ローカル参照の例
    // または
    // .package(url: "https://github.com/<you>/SportsPairing.git", from: "0.1.0")
],
targets: [
    .target(name: "YourApp", dependencies: ["SportsPairing"])
]
```

```swift
import SportsPairing
```

---

## 🧩 コアモデル

| 型 | 役割 |
| --- | --- |
| `Player<ID>` | 参加者。`ID` は `Int`・`UUID`・`String` など自由。出場回数・スキル・希望サイド・対戦/味方履歴を持つ。 |
| `MatchFormat` | 試合形式。`teamSize` とサイド有無。`.singles` / `.doubles` / `.doublesNoSides`。 |
| `Side` | `.drive` / `.back` / `.any`（希望サイド）。 |
| `Team<ID>` | 1 チーム（メンバー + サイド）。ダブルス互換の `drive`・`back` あり。 |
| `Match<ID>` | 1 試合。`teamA` vs `teamB`、任意の `court`。 |
| `FixedPair<ID>` | 「必ず同じチーム」の 2 人組。 |
| `Matchmaker<ID>` | ライブメイク・エンジン本体（状態を持たない値型）。 |
| `MatchmakingWeights` | 標準化された重み。 |
| `MatchmakingOptions<ID>` | 試合形式・公平性モード・固定ペア・スキル正規化レンジ。 |
| `RoundRobinGenerator` | 背番号ベースの総当たり表（乱数）生成器。 |
| `NumberedMatch` / `NumberedTeam` | 総当たり表の 1 行 / チーム（番号で管理）。 |
| `RoundRobinWeights` | 総当たり表の並び順を決める重み。 |

> `Player` は「アプリのドメインモデル → `SportsPairing.Player` に詰め替えて渡す」想定です。
> エンジンは状態を持たないため、毎回その時点のプレイヤー状態を渡し、
> 試合終了後に `Matchmaker.apply(_:to:)` で履歴を更新します（CoreData 等の永続化はアプリ側の責務）。

---

## 🚀 使い方

### 1 試合を組む

```swift
let matchmaker = Matchmaker<Int>()
let match = try matchmaker.makeMatch(from: players)
```

### 複数コートを一気に埋める（1 ラウンド）

```swift
let matches = matchmaker.makeRound(from: players, courts: ["A コート", "B コート"], using: &rng)
// 同じ人が 2 試合に同時に出ることはない。人数が尽きたら打ち切る。
```

### 試合終了 → 履歴を反映

```swift
var players = loadPlayers()
let match = try matchmaker.makeMatch(from: players, using: &rng)
// …試合をプレイ…
Matchmaker.apply(match, to: &players)   // 出場回数 +1、味方/対戦履歴を更新
```

この履歴更新が、次回以降の「重複回避」を効かせます。

### 再現性のある乱数

```swift
var rng = SeededRandomNumberGenerator(seed: 42)
let match = try matchmaker.makeMatch(from: players, using: &rng)
// 同じ seed・同じ入力なら必ず同じ組み合わせ。
```

---

## 🏸 試合形式（多競技対応）

`MatchmakingOptions.format` で形式を切り替えます。

```swift
// シングルス（1 対 1）
let singles = Matchmaker(options: MatchmakingOptions<Int>(format: .singles))
let match = try singles.makeMatch(from: players)   // teamA 1 人 vs teamB 1 人

// ダブルス（2 対 2・ドライブ/バックあり、既定）
let doubles = Matchmaker<Int>()

// ダブルスだが左右サイドを固定しない競技
let flat = Matchmaker(options: MatchmakingOptions<Int>(format: .doublesNoSides))
```

| プリセット | teamSize | サイド | 例 |
| --- | --- | --- | --- |
| `.singles` | 1 | なし | テニス/卓球の個人戦 |
| `.doubles`（既定） | 2 | ドライブ / バック | パデル・テニスのペア戦 |
| `.doublesNoSides` | 2 | なし | 左右を固定しない競技 |

`MatchFormat(teamSize: 3, usesSides: false)` のように 3 対 3 以上も指定できます（サイドはダブルスのみ）。
形式に応じて、選出人数・チーム分割・履歴（味方/対戦）の扱いは自動で切り替わります。
シングルスでは「味方」が存在しないため、`partnerRepeat` や固定ペアは無視されます。

---

## 🎲 総当たり表（乱数）

背番号（1〜N の数字）で参加者を管理し、考えうる全カードを **公平な順番** に並べた進行表を作ります。
アプリにメンバー登録していない集まりでも、その場で公平な対戦順を配れます
（PadeLovers の「乱数表」機能に相当）。

```swift
let generator = RoundRobinGenerator(format: .doubles)
let table = try generator.generate(playerCount: 8)
for match in table {
    print("\(match.order). \(match.summary)")   // "1. 1,2 vs 3,4"
}
```

- **全カード列挙 + 公平な並び**：全員の出場数を均し、同じペア・同じ顔ぶれが固まらない順に並べます。
- **シングルス / ダブルス両対応**：シングルスは全ペア（C(N,2)）、ダブルスは全ペア対決を生成。
- **コート進行用にラウンド分割**：

```swift
var rng = SeededRandomNumberGenerator(seed: 1)
let rounds = try generator.generateRounds(playerCount: 8, using: &rng)
// rounds[0] = 同時に進行できる試合のまとまり（番号は重複しない）
```

- **件数の制限**：`generate(playerCount:maxMatches:using:)` で先頭だけ取り出せます。
- **重みの調整**：

```swift
let generator = RoundRobinGenerator(
    format: .doubles,
    weights: RoundRobinWeights(playerBalance: 15, pairRepeat: 10, groupRepeat: 10)
)
```

並び順は「優先度（小さいほど先）」の貪欲選択で決まり、優先度は次の重み付き和です。

```
優先度 = Σ(各選手の出場回数) × playerBalance
       + Σ(各チームの使用回数) × pairRepeat
       + (この顔ぶれの登場回数) × groupRepeat
       + (出場済みを後ろへ散らす項)
```

> 対応人数の目安：ダブルスは最大 16 人、シングルスは最大 64 人（組み合わせ爆発を防ぐ上限）。
> 範囲外は `MatchmakingError.invalidPlayerCount` を投げます。

---

## ⚖️ アルゴリズム（2 段階）

### フェーズ 1 — 選出（誰が出るか）

1. 休憩中を除いた出場可能なプレイヤーを集める。
2. **固定ペアは分割不可の「ユニット」**として扱う（ペアの少ない方の出場回数で参加タイミングを判定）。
3. 合計 4 人になるユニットの組み合わせを列挙し、
   - `fairness == .strict`（既定）なら、**出場回数の昇順列が辞書順で最小**の組み合わせだけを残す。
     → 出場回数が多い人が、少ない人を飛ばして選ばれることは決して起きない。
   - `fairness == .off` なら出場回数を無視。
4. 残った候補の中から **新鮮さ（最近組んでいない顔ぶれ）** が最も高いものを選ぶ。同点は乱数。

### フェーズ 2 — 配置（どう組むか）

1. 選んだ 4 人を 2 ペアに分ける 3 通りを列挙（固定ペアを引き裂く分割は除外）。
2. 各ペアのドライブ / バック割当（2×2 通り）まで含めて全配置を評価。
3. 次のコストを統合し、**最小コストの配置**を選ぶ（同点は乱数）。

```
コスト = partnerRepeat × 味方の重複
       + opponentRepeat × 対戦相手の重複
       + skillBalance   × チーム平均スキル差
       + sidePreference × 希望サイドとの不一致
```

各項目は内部でおおむね **0〜1 に正規化** されているため、重みは「項目どうしの相対的な重要度」として一貫した意味を持ちます（= **重みの標準化**）。
重複回数のペナルティは `n / (n + 1)` で飽和させ、「1 回でも重複すると効き、回数が増えるほど鈍く増える」標準曲線を使います。

---

## 🎛 重みのプリセット

| プリセット | 用途 | 特徴 |
| --- | --- | --- |
| `.balanced`（既定） | 通常の練習・ゲーム会 | 重複回避を主軸に、スキルとサイドも適度に。PadeLovers 通常モード相当。 |
| `.maximizeVariety` | 交流会・乱取り | とにかく多くの相手と当たる。スキル均衡は弱め。 |
| `.competitiveBalance` | 接戦を作りたい | チームの実力均衡を最優先。 |

```swift
let matchmaker = Matchmaker<Int>(weights: .competitiveBalance)
```

カスタムも可能：

```swift
let weights = MatchmakingWeights(
    partnerRepeat: 1.0,
    opponentRepeat: 0.5,
    skillBalance: 0.8,
    sidePreference: 0.3
)
```

---

## 🔧 オプション

```swift
let options = MatchmakingOptions(
    fairness: .strict,                      // .strict（既定） / .off
    fixedPairs: [FixedPair(1, 2)],          // 必ず同じチームにする 2 人組
    skillRange: 9                           // スキルを 1〜10 運用なら 9（= 10 − 1）
)
let matchmaker = Matchmaker(weights: .balanced, options: options)
```

- **fairness**：`.strict` は出場回数を厳密に均す。`.off` は出場回数を無視（固定メンバー戦など）。
- **fixedPairs**：1 人が複数のペアに属する・自分自身とのペアは実行時にエラー（`MatchmakingError.invalidFixedPairs`）。
- **skillRange**：スキル差の正規化に使う想定レンジ幅。

---

## 🔁 PadeLovers ロジックとの対応

| PadeLovers | SportsPairing | 一般化したこと |
| --- | --- | --- |
| `getMinCountsWithPlayers` で最小出場回数の人から選ぶ | `fairness: .strict`（辞書順最小） | ハード制約として明文化。`.off` で無効化も可能に。 |
| `pair1` / `pairedPlayers` で直近の相手を避ける | `partnerRepeat` / `opponentRepeat` の重み | ハード除外 → **重み付きコスト**に。候補が尽きてデッドロックしない。 |
| 「全員と組んだら履歴リセット」 | 飽和関数 `n/(n+1)` | リセット不要。回数が増えても破綻せず、自然に新鮮さを優先。 |
| Pairing A / B（固定ペア） | `FixedPair` + ユニット選出 | 任意個数の固定ペアに一般化。 |
| driveA / backA / driveB / backB | `Team.drive` / `Team.back` ×2 | サイド希望を重みで尊重。 |
| `RandomNumberTableManager`（乱数表） | `RoundRobinGenerator` | シングルス対応・重み設定可・シード再現性を追加。 |
| （ダブルス固定） | `MatchFormat` | シングルス / サイドなし / 3 対 3 以上に一般化。 |
| （なし） | `skillBalance` | 新規。実力均衡を重みで追加。 |

> **設計判断**：元実装はペア重複を「ハード除外 → 候補が消えたら緩める」で扱っていましたが、
> 本ライブラリでは **重み付きコスト** に置き換えました。これにより
> 「避けたいができないときは最も影響の小さい選択をする」を自然に表現でき、
> 候補ゼロによるデッドロックや特別なリセット処理が不要になります。

---

## ✅ 動作確認

```bash
swift build
swift test
```

37 のテスト（公平性・固定ペア・スキルバランス・サイド希望・重複回避・シングルス・総当たり表・ラウンド分割・再現性など）が通ることを確認済み。

---

## 🗺 ロードマップ（今後の作り込み候補）

- 性別ミックス比率などの **属性バランス制約**（例: 各チーム男女 1 人ずつ）。
- ラウンド全体を見渡した **大域最適化**（1 試合ずつの貪欲法 → ラウンド一括最適化）。
- 連続出場・連続休憩を避ける **レスト制御**の重み化。
- スキルの自動推定（試合結果からのレーティング更新）との連携。
- 総当たり表の **大人数対応**（近似アルゴリズムで上限を引き上げ）。

### 実装済み（v0.2.0）

- ✅ シングルス / サイドなしダブルスなど **多形式対応**（`MatchFormat`）。
- ✅ 背番号ベースの **総当たり表（乱数）生成**（`RoundRobinGenerator`）とラウンド分割。

---

## 📄 ライセンス

MIT（予定）。
