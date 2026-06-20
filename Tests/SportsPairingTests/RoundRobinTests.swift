import Testing
@testable import SportsPairing

// MARK: - 総当たり表（ダブルス）

@Suite("総当たり表 ダブルス")
struct RoundRobinDoublesTests {

    @Test("8 人ダブルスは 210 カード（PadeLovers と同じ規模）")
    func generatesAllCards() throws {
        let generator = RoundRobinGenerator(format: .doubles)
        var rng = SeededRandomNumberGenerator(seed: 1)
        let table = try generator.generate(playerCount: 8, using: &rng)
        // N(N-1)(N-2)(N-3)/8 = 8*7*6*5/8 = 210
        #expect(table.count == 210)
    }

    @Test("各カードは 1〜8 の相異なる 4 人で構成される")
    func cardsHaveFourDistinctNumbers() throws {
        let generator = RoundRobinGenerator(format: .doubles)
        let table = try generator.generate(playerCount: 8)
        for match in table {
            #expect(match.numbers.count == 4)
            #expect(Set(match.numbers).count == 4)
            #expect(match.numbers.allSatisfy { (1...8).contains($0) })
        }
    }

    @Test("order は 1 から連番で振られる")
    func ordersAreSequential() throws {
        let generator = RoundRobinGenerator(format: .doubles)
        let table = try generator.generate(playerCount: 8)
        #expect(table.map(\.order) == Array(1...table.count))
    }

    @Test("全プレイヤーの出場数が均等（対称性より各 105 回）")
    func everyPlayerPlaysEqually() throws {
        let generator = RoundRobinGenerator(format: .doubles)
        let table = try generator.generate(playerCount: 8)
        var counts: [Int: Int] = [:]
        for match in table {
            for number in match.numbers { counts[number, default: 0] += 1 }
        }
        // 全カードを使い切るので、対称性から全員同じ回数になる。
        let values = Set(counts.values)
        #expect(values.count == 1)
        #expect(counts[1] == 210 * 4 / 8)
    }

    @Test("考えうる全ペア（28 通り）が味方として登場する")
    func coversAllPartnerships() throws {
        let generator = RoundRobinGenerator(format: .doubles)
        let table = try generator.generate(playerCount: 8)
        var teams = Set<NumberedTeam>()
        for match in table {
            teams.insert(match.teamA)
            teams.insert(match.teamB)
        }
        #expect(teams.count == 28)   // C(8,2)
    }

    @Test("同じシードなら同じ表になる")
    func reproducibleWithSeed() throws {
        let generator = RoundRobinGenerator(format: .doubles)
        var rng1 = SeededRandomNumberGenerator(seed: 99)
        var rng2 = SeededRandomNumberGenerator(seed: 99)
        let table1 = try generator.generate(playerCount: 6, using: &rng1)
        let table2 = try generator.generate(playerCount: 6, using: &rng2)
        #expect(table1 == table2)
    }

    @Test("人数が少なすぎ・多すぎるとエラー")
    func rejectsOutOfRange() {
        let generator = RoundRobinGenerator(format: .doubles)
        #expect(throws: (any Error).self) { _ = try generator.generate(playerCount: 3) }
        #expect(throws: (any Error).self) { _ = try generator.generate(playerCount: 17) }
    }

    @Test("maxMatches で先頭だけ取り出せる")
    func truncatesWithMaxMatches() throws {
        let generator = RoundRobinGenerator(format: .doubles)
        var rng = SeededRandomNumberGenerator(seed: 7)
        let table = try generator.generate(playerCount: 8, maxMatches: 5, using: &rng)
        #expect(table.count == 5)
    }
}

// MARK: - 総当たり表（シングルス）

@Suite("総当たり表 シングルス")
struct RoundRobinSinglesTests {

    @Test("5 人シングルスは 10 カード（全ペア）")
    func generatesAllPairs() throws {
        let generator = RoundRobinGenerator(format: .singles)
        let table = try generator.generate(playerCount: 5)
        #expect(table.count == 10)   // C(5,2)
        for match in table {
            #expect(match.teamA.numbers.count == 1)
            #expect(match.teamB.numbers.count == 1)
            #expect(match.numbers.count == 2)
        }
    }

    @Test("全ペアがちょうど 1 回ずつ登場する")
    func eachPairAppearsOnce() throws {
        let generator = RoundRobinGenerator(format: .singles)
        let table = try generator.generate(playerCount: 6)
        let groups = table.map { $0.numbers }
        #expect(Set(groups).count == table.count)   // 重複なし
        #expect(table.count == 15)                   // C(6,2)
    }
}

// MARK: - ラウンド分割

@Suite("ラウンド分割")
struct RoundPackingTests {

    @Test("各ラウンド内で番号が重複しない（ダブルス 8 人）")
    func roundsHaveNoOverlap() throws {
        let generator = RoundRobinGenerator(format: .doubles)
        var rng = SeededRandomNumberGenerator(seed: 2)
        let rounds = try generator.generateRounds(playerCount: 8, using: &rng)
        for round in rounds {
            let all = round.flatMap(\.numbers)
            #expect(all.count == Set(all).count)   // 重複なし
            #expect(round.count <= 2)              // 8 人 → 最大 2 コート
        }
    }

    @Test("全カードがいずれかのラウンドに含まれる")
    func roundsCoverAllMatches() throws {
        let generator = RoundRobinGenerator(format: .doubles)
        var rng = SeededRandomNumberGenerator(seed: 4)
        let table = try generator.generate(playerCount: 8, using: &rng)
        let rounds = RoundRobinGenerator.packIntoRounds(table)
        #expect(rounds.flatMap { $0 }.count == table.count)
    }
}
