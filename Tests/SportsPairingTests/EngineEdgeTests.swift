import Testing
@testable import SportsPairing

// Matchmaker のエッジケースと、多人数形式（3 対 3）のテスト。

private func makePlayers(_ count: Int) -> [Player<Int>] {
    (1...count).map { Player(id: $0, name: "P\($0)") }
}

// MARK: - makeRound のエッジケース

@Suite("makeRound のエッジケース")
struct MakeRoundEdgeTests {

    @Test("コート数 0 では空を返す")
    func zeroCourts() {
        let matchmaker = Matchmaker<Int>()
        var rng = SeededRandomNumberGenerator(seed: 1)
        #expect(matchmaker.makeRound(from: makePlayers(8), courtCount: 0, using: &rng).isEmpty)
    }

    @Test("固定ペア設定が不正なら空を返す（例外を投げない）")
    func invalidFixedPairsReturnsEmpty() {
        let matchmaker = Matchmaker(options: MatchmakingOptions(fixedPairs: [FixedPair(1, 1)]))
        var rng = SeededRandomNumberGenerator(seed: 1)
        #expect(matchmaker.makeRound(from: makePlayers(8), courtCount: 2, using: &rng).isEmpty)
    }

    @Test("コート数より人数が少なければ作れた分だけ返し、コート名も作れた分だけ付く")
    func moreCourtsThanPlayers() {
        let matchmaker = Matchmaker<Int>()
        var rng = SeededRandomNumberGenerator(seed: 2)
        // 8 人ダブルス → 2 試合しか作れない。コートは 3 枚指定。
        let matches = matchmaker.makeRound(from: makePlayers(8), courts: ["A", "B", "C"], using: &rng)
        #expect(matches.count == 2)
        #expect(matches.map(\.court) == ["A", "B"])
    }
}

// MARK: - apply のエッジケース

@Suite("apply のエッジケース")
struct ApplyEdgeTests {

    @Test("同じ試合を 2 回 apply すると出場回数・履歴が累積する")
    func appliesTwice() throws {
        var players = makePlayers(4)
        let matchmaker = Matchmaker<Int>()
        var rng = SeededRandomNumberGenerator(seed: 13)
        let match = try matchmaker.makeMatch(from: players, using: &rng)

        Matchmaker.apply(match, to: &players)
        Matchmaker.apply(match, to: &players)

        #expect(players.allSatisfy { $0.playCount == 2 })
        let driveAID = match.teamA.drive.id
        let backAID = match.teamA.back.id
        let driveA = try #require(players.first { $0.id == driveAID })
        #expect(driveA.partnerCount(with: backAID) == 2)
    }

    @Test("試合に出ていないプレイヤーは apply の影響を受けない")
    func untouchedPlayerUnaffected() throws {
        var players = makePlayers(5)   // 1 人は試合に出ない
        let matchmaker = Matchmaker<Int>()
        var rng = SeededRandomNumberGenerator(seed: 21)
        let match = try matchmaker.makeMatch(from: players, using: &rng)
        Matchmaker.apply(match, to: &players)

        let excludedID = try #require(Set(1...5).subtracting(match.playerIDs).first)
        let excluded = try #require(players.first { $0.id == excludedID })
        #expect(excluded.playCount == 0)
        #expect(excluded.partnerCounts.isEmpty)
        #expect(excluded.opponentCounts.isEmpty)
    }
}

// MARK: - 3 対 3 形式（多人数チーム）

@Suite("3 対 3 形式")
struct ThreeVsThreeTests {

    private var matchmaker: Matchmaker<Int> {
        Matchmaker(options: MatchmakingOptions<Int>(format: MatchFormat(teamSize: 3, usesSides: false)))
    }

    @Test("6 人で 3 対 3 の試合が組める")
    func makesThreeVsThree() throws {
        var rng = SeededRandomNumberGenerator(seed: 51)
        let match = try matchmaker.makeMatch(from: makePlayers(6), using: &rng)
        #expect(match.teamA.players.count == 3)
        #expect(match.teamB.players.count == 3)
        #expect(Set(match.playerIDs).count == 6)
    }

    @Test("6 人未満ではエラー")
    func throwsWhenTooFew() {
        #expect(throws: MatchmakingError.notEnoughPlayers(available: 5)) {
            _ = try matchmaker.makeMatch(from: makePlayers(5))
        }
    }

    @Test("apply は味方 2 人・対戦 3 人を記録する")
    func recordsPartnersAndOpponents() throws {
        var players = makePlayers(6)
        var rng = SeededRandomNumberGenerator(seed: 53)
        let match = try matchmaker.makeMatch(from: players, using: &rng)
        Matchmaker.apply(match, to: &players)

        #expect(players.allSatisfy { $0.playCount == 1 })
        let memberID = match.teamA.players[0].id
        let member = try #require(players.first { $0.id == memberID })
        #expect(member.partnerCounts.values.reduce(0, +) == 2)   // 同チームの残り 2 人
        #expect(member.opponentCounts.values.reduce(0, +) == 3)  // 相手チーム 3 人
    }

    @Test("3 対 3 でも出場回数の公平性が保たれる")
    func keepsFairness() throws {
        var players = makePlayers(8)
        var rng = SeededRandomNumberGenerator(seed: 55)
        let mm = matchmaker
        for _ in 0..<20 {
            let match = try mm.makeMatch(from: players, using: &rng)
            Matchmaker.apply(match, to: &players)
        }
        let counts = players.map(\.playCount)
        #expect((counts.max() ?? 0) - (counts.min() ?? 0) <= 1)
    }
}
