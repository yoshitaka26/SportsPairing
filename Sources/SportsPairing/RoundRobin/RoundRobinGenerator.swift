//
//  RoundRobinGenerator.swift
//  SportsPairing
//

/// 背番号（数字）で管理する **総当たり表（乱数表）** の生成器。
///
/// プレイヤーを 1〜N の番号で扱い、考えうる全カードを列挙したうえで、
/// 「全員の出場数を均し、同じペア・同じ顔ぶれが固まらない」公平な順番に並べる。
/// 出力は ``NumberedMatch`` の並び（= 総当たり表の各行）。
///
/// PadeLovers の `RandomNumberTableManager` を一般化したもので、
/// シングルス（1 対 1）・ダブルス（2 対 2）の両方に対応し、重み (``RoundRobinWeights``) で
/// 並び順を調整できる。同点はシード可能な乱数で決めるため再現性を確保できる。
///
/// ```swift
/// let generator = RoundRobinGenerator(format: .doubles)
/// let table = try generator.generate(playerCount: 8)
/// for match in table {
///     print("\(match.order). \(match.summary)")   // "1. 1,2 vs 3,4"
/// }
/// ```
public struct RoundRobinGenerator: Sendable {

    /// 試合形式（シングルス / ダブルス）。
    public var format: MatchFormat
    /// 並び順を決める重み。
    public var weights: RoundRobinWeights

    public init(format: MatchFormat = .doubles, weights: RoundRobinWeights = .default) {
        self.format = format
        self.weights = weights
    }

    /// 対応する最大人数。組み合わせ爆発を防ぐための上限。
    /// シングルスは多めに、ダブルスは控えめに設定している。
    public var maxPlayerCount: Int {
        format.teamSize == 1 ? 64 : 16
    }

    /// 必要な最小人数（= `teamSize × 2`）。
    public var minPlayerCount: Int {
        format.playersPerMatch
    }

    // MARK: - 生成

    /// 総当たり表を生成する。
    ///
    /// - Parameters:
    ///   - playerCount: 参加人数（番号は 1〜playerCount）。
    ///   - rng: 同点時のタイ・ブレイク用乱数。
    /// - Returns: 公平な順に並んだ全カード。
    /// - Throws: 人数が対応範囲外のとき ``MatchmakingError/invalidPlayerCount(reason:)``。
    public func generate(
        playerCount: Int,
        using rng: inout some RandomNumberGenerator
    ) throws -> [NumberedMatch] {
        try validate(playerCount: playerCount)
        let candidates = enumerateMatches(playerCount: playerCount)
        return order(candidates: candidates, playerCount: playerCount, using: &rng)
    }

    /// システム乱数を使う簡易版。
    public func generate(playerCount: Int) throws -> [NumberedMatch] {
        var rng = SystemRandomNumberGenerator()
        return try generate(playerCount: playerCount, using: &rng)
    }

    /// 先頭 `maxMatches` 試合だけを返す簡易版（公平な順の先頭から切り出す）。
    public func generate(
        playerCount: Int,
        maxMatches: Int,
        using rng: inout some RandomNumberGenerator
    ) throws -> [NumberedMatch] {
        let all = try generate(playerCount: playerCount, using: &rng)
        return Array(all.prefix(max(maxMatches, 0)))
    }

    /// 総当たり表を「ラウンド（同時進行できる試合のまとまり）」に区切って生成する。
    ///
    /// 各ラウンド内では同じ番号の人が重複しない。コートが複数あるときの進行表に使える。
    public func generateRounds(
        playerCount: Int,
        using rng: inout some RandomNumberGenerator
    ) throws -> [[NumberedMatch]] {
        let matches = try generate(playerCount: playerCount, using: &rng)
        return Self.packIntoRounds(matches)
    }

    /// 並んだ試合列を、番号が重複しないラウンドに貪欲にまとめる。
    public static func packIntoRounds(_ matches: [NumberedMatch]) -> [[NumberedMatch]] {
        var rounds: [[NumberedMatch]] = []
        var roundNumbers: [Set<Int>] = []
        for match in matches {
            let used = Set(match.numbers)
            // 既存ラウンドのうち、番号が衝突しない最初のものに入れる。
            if let index = roundNumbers.firstIndex(where: { $0.isDisjoint(with: used) }) {
                rounds[index].append(match)
                roundNumbers[index].formUnion(used)
            } else {
                rounds.append([match])
                roundNumbers.append(used)
            }
        }
        return rounds
    }

    // MARK: - 内部処理

    private func validate(playerCount: Int) throws {
        guard playerCount >= minPlayerCount else {
            throw MatchmakingError.invalidPlayerCount(
                reason: "最低 \(minPlayerCount) 人必要です（指定: \(playerCount)）。"
            )
        }
        guard playerCount <= maxPlayerCount else {
            throw MatchmakingError.invalidPlayerCount(
                reason: "この形式の対応上限は \(maxPlayerCount) 人です（指定: \(playerCount)）。"
            )
        }
    }

    /// 1〜playerCount から、考えうる全カード（チーム vs チーム）を列挙する。
    private func enumerateMatches(playerCount: Int) -> [NumberedMatch] {
        let teamSize = format.teamSize
        let numbers = Array(1...playerCount)

        // すべてのチーム（teamSize 人の組）を作る。
        let teamIndexSets = combinations(of: numbers.count, choose: teamSize)
        let teams = teamIndexSets.map { NumberedTeam($0.map { numbers[$0] }) }

        // 互いに番号が重ならない 2 チームを 1 カードにする。
        var matches: [NumberedMatch] = []
        for i in 0..<teams.count {
            for j in (i + 1)..<teams.count {
                let setI = Set(teams[i].numbers)
                let setJ = Set(teams[j].numbers)
                guard setI.isDisjoint(with: setJ) else { continue }
                matches.append(NumberedMatch(order: 0, teamA: teams[i], teamB: teams[j]))
            }
        }
        return matches
    }

    /// 候補カードを、公平になるよう貪欲に並べ替える。
    private func order(
        candidates: [NumberedMatch],
        playerCount: Int,
        using rng: inout some RandomNumberGenerator
    ) -> [NumberedMatch] {
        var remaining = candidates
        var results: [NumberedMatch] = []

        var playerGameNum: [Int: Int] = [:]
        var points: [Int: Int] = [:]
        for n in 1...playerCount {
            playerGameNum[n] = 0
            points[n] = 0
        }
        var teamUseNum: [NumberedTeam: Int] = [:]
        var groupUseNum: [[Int]: Int] = [:]

        let isDoubles = format.teamSize >= 2

        while !remaining.isEmpty {
            // 各候補の優先度を計算し、最小のものを集める。
            var minPriority = Int.max
            var bestIndices: [Int] = []
            for (index, match) in remaining.enumerated() {
                let priority = priorityOf(
                    match,
                    playerGameNum: playerGameNum,
                    points: points,
                    teamUseNum: teamUseNum,
                    groupUseNum: groupUseNum,
                    isDoubles: isDoubles
                )
                if priority < minPriority {
                    minPriority = priority
                    bestIndices = [index]
                } else if priority == minPriority {
                    bestIndices.append(index)
                }
            }

            // 同点は乱数で選ぶ。
            let pickedIndex = bestIndices.randomElement(using: &rng) ?? 0
            var picked = remaining.remove(at: pickedIndex)
            picked = NumberedMatch(order: results.count + 1, teamA: picked.teamA, teamB: picked.teamB)
            results.append(picked)

            // カウンタを更新する。
            for number in picked.numbers {
                playerGameNum[number, default: 0] += 1
                points[number, default: 0] += results.count   // 出場済みを後ろへ散らす
            }
            teamUseNum[picked.teamA, default: 0] += 1
            teamUseNum[picked.teamB, default: 0] += 1
            if isDoubles {
                groupUseNum[picked.groupKey, default: 0] += 1
            }
        }
        return results
    }

    /// 1 カードの優先度（小さいほど先に組まれる）。
    private func priorityOf(
        _ match: NumberedMatch,
        playerGameNum: [Int: Int],
        points: [Int: Int],
        teamUseNum: [NumberedTeam: Int],
        groupUseNum: [[Int]: Int],
        isDoubles: Bool
    ) -> Int {
        var priority = 0
        for number in match.numbers {
            priority += (playerGameNum[number] ?? 0) * weights.playerBalance
            priority += (points[number] ?? 0)
        }
        priority += (teamUseNum[match.teamA] ?? 0) * weights.pairRepeat
        priority += (teamUseNum[match.teamB] ?? 0) * weights.pairRepeat
        if isDoubles {
            priority += (groupUseNum[match.groupKey] ?? 0) * weights.groupRepeat
        }
        return priority
    }

    /// 0..<n から r 個を選ぶインデックス組み合わせ。
    private func combinations(of n: Int, choose r: Int) -> [[Int]] {
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
}
