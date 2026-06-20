import Testing
@testable import SportsPairing

private func makePlayers(_ count: Int) -> [Player<Int>] {
    (1...count).map { Player(id: $0, name: "P\($0)") }
}

// MARK: - シングルス

@Suite("シングルス形式")
struct SinglesTests {

    private var matchmaker: Matchmaker<Int> {
        Matchmaker(options: MatchmakingOptions<Int>(format: .singles))
    }

    @Test("2 人で 1 対 1 の試合が組める")
    func makesSinglesMatch() throws {
        let match = try matchmaker.makeMatch(from: makePlayers(2))
        #expect(match.teamA.players.count == 1)
        #expect(match.teamB.players.count == 1)
        #expect(Set(match.playerIDs).count == 2)
    }

    @Test("2 人未満ではエラー")
    func throwsWithOnePlayer() {
        #expect(throws: MatchmakingError.notEnoughPlayers(available: 1)) {
            _ = try matchmaker.makeMatch(from: makePlayers(1))
        }
    }

    @Test("シングルスでも出場回数の公平性が保たれる")
    func keepsFairnessInSingles() throws {
        var players = makePlayers(5)
        var rng = SeededRandomNumberGenerator(seed: 31)
        let mm = matchmaker
        for _ in 0..<20 {
            let match = try mm.makeMatch(from: players, using: &rng)
            Matchmaker.apply(match, to: &players)
        }
        let counts = players.map(\.playCount)
        #expect((counts.max() ?? 0) - (counts.min() ?? 0) <= 1)
    }

    @Test("apply はシングルスでは味方を記録しない（対戦のみ）")
    func recordsOnlyOpponentsInSingles() throws {
        var players = makePlayers(2)
        var rng = SeededRandomNumberGenerator(seed: 33)
        let match = try matchmaker.makeMatch(from: players, using: &rng)
        Matchmaker.apply(match, to: &players)

        let p1 = try #require(players.first { $0.id == 1 })
        #expect(p1.partnerCounts.isEmpty)            // 味方はいない
        #expect(p1.opponentCount(with: 2) == 1)      // 相手は記録される
    }
}

// MARK: - サイドなしダブルス

@Suite("サイドなしダブルス")
struct DoublesNoSidesTests {

    @Test("サイドを区別しない形式では全員 .any で配置される")
    func placesEveryoneAsAny() throws {
        let matchmaker = Matchmaker(options: MatchmakingOptions<Int>(format: .doublesNoSides))
        var rng = SeededRandomNumberGenerator(seed: 41)
        let match = try matchmaker.makeMatch(from: makePlayers(4), using: &rng)

        let sides = (match.teamA.members + match.teamB.members).map(\.side)
        #expect(sides.allSatisfy { $0 == .any })
        #expect(match.teamA.players.count == 2)
    }
}
