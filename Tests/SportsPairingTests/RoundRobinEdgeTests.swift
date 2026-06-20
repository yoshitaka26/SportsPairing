import Testing
@testable import SportsPairing

// 総当たり表（RoundRobinGenerator）の境界値・並び順の公平性と、
// 背番号モデル（NumberedTeam / NumberedMatch）の正規化テスト。

// MARK: - 境界値

@Suite("総当たり表 境界値")
struct RoundRobinBoundaryTests {

    @Test("対応人数のレンジ")
    func playerCountRange() {
        let doubles = RoundRobinGenerator(format: .doubles)
        #expect(doubles.minPlayerCount == 4)
        #expect(doubles.maxPlayerCount == 16)

        let singles = RoundRobinGenerator(format: .singles)
        #expect(singles.minPlayerCount == 2)
        #expect(singles.maxPlayerCount == 64)
    }

    @Test("最小人数ちょうどでも生成できる")
    func generatesAtMinimum() throws {
        // ダブルス 4 人 → N(N-1)(N-2)(N-3)/8 = 4*3*2*1/8 = 3 カード。
        #expect(try RoundRobinGenerator(format: .doubles).generate(playerCount: 4).count == 3)
        // シングルス 2 人 → C(2,2) = 1 カード。
        #expect(try RoundRobinGenerator(format: .singles).generate(playerCount: 2).count == 1)
    }

    @Test("最小未満・最大超過はエラー")
    func rejectsOutOfRange() {
        let singles = RoundRobinGenerator(format: .singles)
        #expect(throws: (any Error).self) { _ = try singles.generate(playerCount: 1) }
        #expect(throws: (any Error).self) { _ = try singles.generate(playerCount: 65) }

        let doubles = RoundRobinGenerator(format: .doubles)
        #expect(throws: (any Error).self) { _ = try doubles.generate(playerCount: 3) }
        #expect(throws: (any Error).self) { _ = try doubles.generate(playerCount: 17) }
    }
}

// MARK: - maxMatches の境界

@Suite("総当たり表 maxMatches")
struct RoundRobinMaxMatchesTests {

    private let generator = RoundRobinGenerator(format: .doubles)

    @Test("maxMatches 0 は空")
    func zero() throws {
        var rng = SeededRandomNumberGenerator(seed: 1)
        #expect(try generator.generate(playerCount: 8, maxMatches: 0, using: &rng).isEmpty)
    }

    @Test("maxMatches 負数は空")
    func negative() throws {
        var rng = SeededRandomNumberGenerator(seed: 1)
        #expect(try generator.generate(playerCount: 8, maxMatches: -3, using: &rng).isEmpty)
    }

    @Test("総数を超える maxMatches では全件返る")
    func overflow() throws {
        var rng = SeededRandomNumberGenerator(seed: 1)
        #expect(try generator.generate(playerCount: 8, maxMatches: 9999, using: &rng).count == 210)
    }
}

// MARK: - 並び順の公平性

@Suite("総当たり表 並び順の公平性")
struct RoundRobinOrderingTests {

    @Test("ダブルス 8 人では先頭 2 試合で全 8 人が登場する")
    func firstRoundCoversEveryoneDoubles() throws {
        var rng = SeededRandomNumberGenerator(seed: 5)
        let table = try RoundRobinGenerator(format: .doubles).generate(playerCount: 8, using: &rng)
        let firstTwo = Set(table[0].numbers + table[1].numbers)
        #expect(firstTwo.count == 8)
    }

    @Test("シングルス 4 人では先頭 2 試合で全 4 人が登場する")
    func firstRoundCoversEveryoneSingles() throws {
        var rng = SeededRandomNumberGenerator(seed: 5)
        let table = try RoundRobinGenerator(format: .singles).generate(playerCount: 4, using: &rng)
        let firstTwo = Set(table[0].numbers + table[1].numbers)
        #expect(firstTwo.count == 4)
    }

    @Test("シングルスのラウンド分割は番号が重複せず全カードを含む")
    func singlesRoundPacking() throws {
        var rng = SeededRandomNumberGenerator(seed: 3)
        let generator = RoundRobinGenerator(format: .singles)
        let rounds = try generator.generateRounds(playerCount: 4, using: &rng)
        for round in rounds {
            let all = round.flatMap(\.numbers)
            #expect(all.count == Set(all).count)   // ラウンド内で重複なし
            #expect(round.count <= 2)               // 4 人 → 最大 2 試合同時
        }
        #expect(rounds.flatMap { $0 }.count == 6)   // C(4,2) = 全 6 カード
    }
}

// MARK: - 背番号モデル

@Suite("背番号モデル")
struct NumberedModelTests {

    @Test("NumberedTeam は番号を昇順に正規化し、順不同でも等価")
    func teamNormalization() {
        #expect(NumberedTeam([3, 1]).numbers == [1, 3])
        #expect(NumberedTeam([1, 2]) == NumberedTeam([2, 1]))
    }

    @Test("NumberedMatch の numbers / contains / summary")
    func matchAccessors() {
        let match = NumberedMatch(order: 1, teamA: NumberedTeam([2, 1]), teamB: NumberedTeam([4, 3]))
        #expect(match.numbers == [1, 2, 3, 4])
        #expect(match.contains(3))
        #expect(!match.contains(5))
        #expect(match.summary == "1,2 vs 3,4")
    }

    @Test("シングルスの summary は 1 番号同士")
    func singlesSummary() {
        let match = NumberedMatch(order: 1, teamA: NumberedTeam([1]), teamB: NumberedTeam([2]))
        #expect(match.summary == "1 vs 2")
    }
}
