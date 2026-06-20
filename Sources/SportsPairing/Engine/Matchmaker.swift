//
//  Matchmaker.swift
//  SportsPairing
//

/// マッチメイク・エンジン。シングルス（1 対 1）・ダブルス（2 対 2）など
/// ``MatchmakingOptions/format`` で指定した形式に対応する。
///
/// PadeLovers のマッチングロジック（出場回数の公平性 + ペア重複回避 + 固定ペア）を
/// 一般化し、重み (``MatchmakingWeights``) で挙動を調整できるようにしたもの。
///
/// エンジンは **状態を持たない純粋な値型**。プレイヤーの現在状態を渡すと組み合わせを返すだけで、
/// 試合終了後の履歴更新はアプリ側が ``apply(_:to:)`` を呼んで行う。
///
/// ## アルゴリズムの 2 段階
///
/// 1. **選出**: 出場可能なプレイヤーから必要人数（`teamSize × 2`）を選ぶ。出場回数の公平性を
///    （`.strict` なら）ハード制約として最優先し、その自由度の中で
///    「最近組んでいない新鮮な顔ぶれ」を重みで選ぶ。固定ペアは分割不可の単位として扱う。
/// 2. **配置**: 選んだ人を 2 チームに分割し、（ダブルスなら）各人のドライブ / バックを決める。
///    味方重複・対戦重複・スキル均衡・サイド希望を統合したコストが最小になる配置を選ぶ。
///
/// 同点（タイ）の候補が複数あるときは乱数で 1 つを選ぶため、毎回まったく同じ組み合わせには
/// なりにくい。再現性が必要なときは ``SeededRandomNumberGenerator`` を渡す。
public struct Matchmaker<ID: Hashable & Sendable>: Sendable {

    /// 組み合わせの好みを表す重み。
    public var weights: MatchmakingWeights
    /// 制約・前提を表すオプション。
    public var options: MatchmakingOptions<ID>

    public init(
        weights: MatchmakingWeights = .balanced,
        options: MatchmakingOptions<ID> = .init()
    ) {
        self.weights = weights
        self.options = options
    }

    private var scorer: MatchScorer<ID> {
        MatchScorer(weights: weights, skillRange: options.skillRange)
    }

    /// コストがこの差以内なら「同点」とみなして乱数で選ぶ。
    private static var tieEpsilon: Double { 1e-9 }

    // MARK: - 公開 API

    /// 1 試合分の組み合わせを作る。形式（シングルス / ダブルス）は ``MatchmakingOptions/format``。
    ///
    /// - Parameters:
    ///   - players: 候補プレイヤー全員（休憩中の人も渡してよい。内部で除外する）。
    ///   - rng: 乱数生成器（タイ・ブレイク用）。
    /// - Returns: 必要人数を 2 チームに分け、（ダブルスなら）サイドまで割り当てた 1 試合。
    /// - Throws: 出場可能なプレイヤーが必要人数未満、または固定ペア設定が不正な場合。
    public func makeMatch(
        from players: [Player<ID>],
        using rng: inout some RandomNumberGenerator
    ) throws -> Match<ID> {
        try validateFixedPairs()
        let needed = options.format.playersPerMatch
        let available = players.filter { !$0.isResting }
        guard available.count >= needed else {
            throw MatchmakingError.notEnoughPlayers(available: available.count)
        }
        let selected = selectPlayers(count: needed, from: available, using: &rng)
        return buildMatch(from: selected, using: &rng)
    }

    /// システム乱数を使う簡易版 ``makeMatch(from:using:)``。
    public func makeMatch(from players: [Player<ID>]) throws -> Match<ID> {
        var rng = SystemRandomNumberGenerator()
        return try makeMatch(from: players, using: &rng)
    }

    /// 複数コート分の組み合わせ（= 1 ラウンド）をまとめて作る。
    ///
    /// 同じプレイヤーが同時に 2 試合に出ることはない。出場可能な人数が尽きるか、
    /// `courtCount` に達するまで試合を作る。各試合の ``Match/playCount`` 等は
    /// **増やさない**（同時進行のため、実際にプレイし終えてから ``apply(_:to:)`` で反映する想定）。
    ///
    /// - Returns: 0〜`courtCount` 個の試合。人数が必要人数未満になった時点で打ち切る。
    public func makeRound(
        from players: [Player<ID>],
        courtCount: Int,
        using rng: inout some RandomNumberGenerator
    ) -> [Match<ID>] {
        guard courtCount > 0, (try? validateFixedPairs()) != nil else { return [] }
        let needed = options.format.playersPerMatch
        var pool = players.filter { !$0.isResting }
        var matches: [Match<ID>] = []
        while matches.count < courtCount, pool.count >= needed {
            let selected = selectPlayers(count: needed, from: pool, using: &rng)
            matches.append(buildMatch(from: selected, using: &rng))
            let usedIDs = Set(selected.map(\.id))
            pool.removeAll { usedIDs.contains($0.id) }
        }
        return matches
    }

    /// コート名を指定して 1 ラウンドを作る。各試合に ``Match/court`` を設定する。
    public func makeRound(
        from players: [Player<ID>],
        courts: [String],
        using rng: inout some RandomNumberGenerator
    ) -> [Match<ID>] {
        var matches = makeRound(from: players, courtCount: courts.count, using: &rng)
        for index in matches.indices {
            matches[index].court = courts[index]
        }
        return matches
    }

    /// 試合終了の結果をプレイヤー配列に反映する。
    ///
    /// 出場した全員の ``Player/playCount`` を 1 増やし、
    /// 味方・対戦相手それぞれの履歴 (``Player/partnerCounts`` / ``Player/opponentCounts``) を更新する。
    /// この履歴が次回以降の重複回避に効く。
    public static func apply(_ match: Match<ID>, to players: inout [Player<ID>]) {
        let teamAIDs = Set(match.teamA.players.map(\.id))
        let teamBIDs = Set(match.teamB.players.map(\.id))
        let allIDs = teamAIDs.union(teamBIDs)

        for index in players.indices {
            let id = players[index].id
            guard allIDs.contains(id) else { continue }

            players[index].playCount += 1

            let (partners, opponents): (Set<ID>, Set<ID>)
            if teamAIDs.contains(id) {
                partners = teamAIDs.subtracting([id])
                opponents = teamBIDs
            } else {
                partners = teamBIDs.subtracting([id])
                opponents = teamAIDs
            }
            for partnerID in partners {
                players[index].partnerCounts[partnerID, default: 0] += 1
            }
            for opponentID in opponents {
                players[index].opponentCounts[opponentID, default: 0] += 1
            }
        }
    }

    // MARK: - 選出フェーズ

    /// 出場可能なプレイヤーから、公平性と新鮮さを考慮して `count` 人を選ぶ。
    private func selectPlayers(
        count: Int,
        from available: [Player<ID>],
        using rng: inout some RandomNumberGenerator
    ) -> [Player<ID>] {
        // 固定ペア（両者とも出場可能）を分割不可の「ユニット」にまとめる。
        let units = makeUnits(from: available)

        // 候補ユニットを公平性キー（最小出場回数）で昇順に並べ、上位だけを探索対象にする。
        // 公平性は最小回数を優先するため、低キーのユニットだけで最適解は得られる。
        let sortedUnits = units.sorted { $0.fairnessKey < $1.fairnessKey }
        let searchUnits = Array(sortedUnits.prefix(Self.unitSearchCap))

        // 合計サイズがちょうど `count` になるユニットの組み合わせを列挙する。
        var combinations = playerCombinations(targetSize: count, from: searchUnits)
        if combinations.isEmpty {
            // 念のためのフォールバック（通常は到達しない）。
            combinations = playerCombinations(targetSize: count, from: sortedUnits)
        }

        // ① 公平性フィルタ: 出場回数の昇順列が辞書順最小のものだけ残す。
        let fairnessFiltered: [[Player<ID>]]
        switch options.fairness {
        case .strict:
            fairnessFiltered = combinations.filter {
                fairnessKey(of: $0) == bestFairnessKey(in: combinations)
            }
        case .off:
            fairnessFiltered = combinations
        }

        // ② 新鮮さフィルタ: variety コスト最小の候補を残し、同点なら乱数で選ぶ。
        return pickFreshest(from: fairnessFiltered, using: &rng)
    }

    /// 公平性キー（選んだ人の出場回数を昇順に並べた配列）。辞書順比較で「より公平」を判定する。
    private func fairnessKey(of players: [Player<ID>]) -> [Int] {
        players.map(\.playCount).sorted()
    }

    /// 候補群の中で辞書順最小の公平性キー。
    private func bestFairnessKey(in combinations: [[Player<ID>]]) -> [Int] {
        combinations
            .map { fairnessKey(of: $0) }
            .min { lexicographicallyLess($0, $1) } ?? []
    }

    /// Int 配列の辞書順比較（`a < b`）。
    private func lexicographicallyLess(_ a: [Int], _ b: [Int]) -> Bool {
        for (x, y) in zip(a, b) where x != y { return x < y }
        return a.count < b.count
    }

    /// variety コスト最小の 4 人組を選ぶ（同点は乱数）。
    private func pickFreshest(
        from combinations: [[Player<ID>]],
        using rng: inout some RandomNumberGenerator
    ) -> [Player<ID>] {
        let s = scorer
        guard let minCost = combinations.map({ s.varietyCost(of: $0) }).min() else {
            return combinations.first ?? []
        }
        let best = combinations.filter { s.varietyCost(of: $0) <= minCost + Self.tieEpsilon }
        return best.randomElement(using: &rng) ?? combinations[0]
    }

    // MARK: - 配置フェーズ

    /// 選んだプレイヤーを 2 チームに分け、（ダブルスなら）サイドまで割り当てて 1 試合を作る。
    private func buildMatch(
        from selected: [Player<ID>],
        using rng: inout some RandomNumberGenerator
    ) -> Match<ID> {
        let s = scorer
        var bestCost = Double.infinity
        var candidates: [(Team<ID>, Team<ID>)] = []

        // 選手を 2 つのチームに分ける全通り。固定ペアを壊す分割は除外する。
        for (groupOne, groupTwo) in teamSplits(of: selected) where keepsFixedPairs(groupOne, groupTwo) {
            // 各チームのサイド割当（ダブルスのみドライブ / バックの 2 通り）を試す。
            for teamA in teamArrangements(of: groupOne) {
                for teamB in teamArrangements(of: groupTwo) {
                    let cost = s.matchCost(teamA: teamA, teamB: teamB)
                    if cost < bestCost - Self.tieEpsilon {
                        bestCost = cost
                        candidates = [(teamA, teamB)]
                    } else if cost <= bestCost + Self.tieEpsilon {
                        candidates.append((teamA, teamB))
                    }
                }
            }
        }

        let chosen = candidates.randomElement(using: &rng) ?? defaultArrangement(of: selected)
        // どちらを teamA とするかは結果に影響しないので、見栄えのため乱数で入れ替える。
        return Bool.random(using: &rng)
            ? Match(teamA: chosen.0, teamB: chosen.1)
            : Match(teamA: chosen.1, teamB: chosen.0)
    }

    /// 2k 人を、サイズ k の 2 チームに分ける全通り。
    ///
    /// 重複（A|B と B|A）を避けるため、必ず先頭の人をチーム 1 側に固定し、
    /// 残りから k−1 人を選んでチーム 1 とする。
    private func teamSplits(of players: [Player<ID>]) -> [([Player<ID>], [Player<ID>])] {
        let teamSize = players.count / 2
        guard teamSize >= 1 else { return [] }
        let head = players[0]
        let rest = Array(players.dropFirst())

        var result: [([Player<ID>], [Player<ID>])] = []
        for indices in indexCombinations(choosing: teamSize - 1, from: rest.count) {
            let chosenSet = Set(indices)
            let teamOne = [head] + indices.map { rest[$0] }
            let teamTwo = rest.enumerated()
                .filter { !chosenSet.contains($0.offset) }
                .map(\.element)
            result.append((teamOne, teamTwo))
        }
        return result
    }

    /// 1 チーム分の人をサイドまで割り当てた候補チームの一覧。
    ///
    /// ダブルス（2 人・サイドあり）はドライブ / バックの 2 通り。
    /// それ以外は全員 ``Side/any`` の 1 通り。
    private func teamArrangements(of group: [Player<ID>]) -> [Team<ID>] {
        guard options.format.assignsSides, group.count == 2 else {
            return [Team(group)]   // サイドなし（全員 .any）
        }
        return [
            Team(drive: group[0], back: group[1]),
            Team(drive: group[1], back: group[0])
        ]
    }

    /// この分割が、出場者に含まれる固定ペアをすべて味方として保っているか。
    private func keepsFixedPairs(_ groupOne: [Player<ID>], _ groupTwo: [Player<ID>]) -> Bool {
        guard options.format.teamSize >= 2 else { return true }   // シングルスでは固定ペアなし
        let setOne = Set(groupOne.map(\.id))
        let setTwo = Set(groupTwo.map(\.id))
        for fixed in options.fixedPairs {
            let bothPresent = (setOne.union(setTwo)).isSuperset(of: fixed.ids)
            guard bothPresent else { continue }
            // 両者が同じチームに入っているか（= 分割で引き裂かれていないか）。
            let together = fixed.ids.isSubset(of: setOne) || fixed.ids.isSubset(of: setTwo)
            if !together { return false }
        }
        return true
    }

    /// 候補が空のときのフォールバック配置（前半・後半で機械的に 2 分割）。
    private func defaultArrangement(of players: [Player<ID>]) -> (Team<ID>, Team<ID>) {
        let half = players.count / 2
        return (Team(Array(players.prefix(half))), Team(Array(players.suffix(half))))
    }

    /// 0..<n から r 個を選ぶインデックスの組み合わせを列挙する。
    private func indexCombinations(choosing r: Int, from n: Int) -> [[Int]] {
        guard r >= 0, r <= n else { return [] }
        if r == 0 { return [[]] }
        var result: [[Int]] = []
        func recurse(_ start: Int, _ chosen: [Int]) {
            if chosen.count == r {
                result.append(chosen)
                return
            }
            for i in start..<n {
                recurse(i + 1, chosen + [i])
            }
        }
        recurse(0, [])
        return result
    }

    // MARK: - ユニット（固定ペアの原子化）

    /// 選出時の最小単位。固定ペアはサイズ 2、その他はサイズ 1。
    private struct Unit {
        let members: [Player<ID>]
        /// 公平性キー = 構成メンバーの最小出場回数（ペアは少ない方が出るタイミングで参加）。
        var fairnessKey: Int { members.map(\.playCount).min() ?? 0 }
        var size: Int { members.count }
    }

    /// 探索対象とするユニット数の上限（組み合わせ爆発を防ぐ）。
    private static var unitSearchCap: Int { 12 }

    /// 出場可能プレイヤーをユニットに分解する。
    private func makeUnits(from available: [Player<ID>]) -> [Unit] {
        var usedInPair = Set<ID>()
        var units: [Unit] = []

        // 固定ペアはチームサイズ 2 以上のときだけ意味を持つ。
        if options.format.teamSize >= 2 {
            let byID = Dictionary(uniqueKeysWithValues: available.map { ($0.id, $0) })
            // 両者とも出場可能な固定ペアをサイズ 2 のユニットにする。
            for fixed in options.fixedPairs {
                guard let p1 = byID[fixed.first], let p2 = byID[fixed.second] else { continue }
                guard !usedInPair.contains(p1.id), !usedInPair.contains(p2.id) else { continue }
                units.append(Unit(members: [p1, p2]))
                usedInPair.insert(p1.id)
                usedInPair.insert(p2.id)
            }
        }
        // 残りはサイズ 1 のユニット。
        for player in available where !usedInPair.contains(player.id) {
            units.append(Unit(members: [player]))
        }
        return units
    }

    /// 合計サイズがちょうど `targetSize` になるユニットの組み合わせを列挙し、各々を人配列にして返す。
    private func playerCombinations(targetSize: Int, from units: [Unit]) -> [[Player<ID>]] {
        var results: [[Player<ID>]] = []

        func recurse(_ start: Int, _ chosen: [Unit], _ size: Int) {
            if size == targetSize {
                results.append(chosen.flatMap(\.members))
                return
            }
            if size > targetSize || start >= units.count { return }
            for index in start..<units.count {
                let unit = units[index]
                if size + unit.size > targetSize { continue }
                recurse(index + 1, chosen + [unit], size + unit.size)
            }
        }
        recurse(0, [], 0)
        return results
    }

    // MARK: - バリデーション

    /// 固定ペア設定の整合性を検証する。
    private func validateFixedPairs() throws {
        var seen = Set<ID>()
        for fixed in options.fixedPairs {
            if fixed.first == fixed.second {
                throw MatchmakingError.invalidFixedPairs(reason: "同じプレイヤーをペアにできません。")
            }
            for id in fixed.ids {
                if seen.contains(id) {
                    throw MatchmakingError.invalidFixedPairs(
                        reason: "1 人が複数の固定ペアに属しています。"
                    )
                }
                seen.insert(id)
            }
        }
    }
}
