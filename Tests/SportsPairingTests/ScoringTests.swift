import Testing
@testable import SportsPairing

// コスト計算（MatchScorer）と、それを通したエンジンの選択挙動のテスト。
// 飽和曲線 n/(n+1) はアルゴリズムの核なので、値を直接固定する。

private func makePlayers(_ count: Int) -> [Player<Int>] {
    (1...count).map { Player(id: $0, name: "P\($0)") }
}

// MARK: - 飽和関数

@Suite("飽和関数 saturating")
struct SaturatingTests {

    private let scorer = MatchScorer<Int>(weights: .balanced, skillRange: 10)

    @Test("0 回は 0、1 回は 0.5、2 回は 2/3、3 回は 0.75")
    func knownValues() {
        #expect(scorer.saturating(0) == 0)
        #expect(scorer.saturating(1) == 0.5)
        #expect(abs(scorer.saturating(2) - 2.0 / 3.0) < 1e-12)
        #expect(scorer.saturating(3) == 0.75)
    }

    @Test("単調増加し、常に 1 未満に飽和する")
    func monotonicAndBounded() {
        #expect(scorer.saturating(1) < scorer.saturating(2))
        #expect(scorer.saturating(2) < scorer.saturating(3))
        #expect(scorer.saturating(100) < 1)
        #expect(scorer.saturating(10_000) < 1)
    }
}

// MARK: - スキル評価のスキップ

@Suite("スキル評価のスキップ")
struct SkillSkipTests {

    @Test("チームに 1 人でもスキル未設定がいると skillGap は nil（均衡評価をスキップ）")
    func skipsWhenSkillMissing() throws {
        let players = [
            Player(id: 1, skill: 10),
            Player(id: 2, skill: 1),
            Player(id: 3, skill: 10),
            Player(id: 4, skill: nil)   // 1 人だけ未設定
        ]
        let matchmaker = Matchmaker<Int>(weights: .competitiveBalance)
        var rng = SeededRandomNumberGenerator(seed: 1)
        let match = try matchmaker.makeMatch(from: players, using: &rng)
        // 未設定の人がどちらかのチームに入るため、平均が出せず nil になる。
        #expect(match.skillGap == nil)
    }
}

// MARK: - 対戦重複の回避（選出フェーズ）

@Suite("対戦重複の回避")
struct OpponentAvoidanceTests {

    @Test("対戦履歴が多い 4 人組より、新鮮な相手を含む組を選ぶ")
    func prefersFreshOpponents() throws {
        // P1〜P4 は互いに 2 回ずつ対戦済み。P5・P6 は誰とも未対戦。
        // 出場回数は全員 0 なので公平性フィルタは全候補を通し、
        // 新鮮さ（対戦重複の少なさ）で P5・P6 を含む組が最小コストになる。
        var players = makePlayers(6)
        players[0].opponentCounts = [2: 2, 3: 2, 4: 2]   // id1 視点で 1-2,1-3,1-4
        players[1].opponentCounts = [3: 2, 4: 2]          // id2 視点で 2-3,2-4
        players[2].opponentCounts = [4: 2]                // id3 視点で 3-4

        let matchmaker = Matchmaker<Int>()   // balanced
        for seed in 0..<20 {
            var rng = SeededRandomNumberGenerator(seed: UInt64(seed))
            let match = try matchmaker.makeMatch(from: players, using: &rng)
            // 最小コストの 4 人組は必ず P5・P6 の両方を含む。
            #expect(match.playerIDs.contains(5))
            #expect(match.playerIDs.contains(6))
        }
    }
}
