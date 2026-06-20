import Testing
@testable import SportsPairing

// MARK: - テスト用ヘルパー

private func makePlayers(_ count: Int) -> [Player<Int>] {
    (1...count).map { Player(id: $0, name: "P\($0)") }
}

/// 2 人が同じチームに属しているか。
private func sameTeam(_ match: Match<Int>, _ a: Int, _ b: Int) -> Bool {
    match.teamA.contains(a) && match.teamA.contains(b)
        || match.teamB.contains(a) && match.teamB.contains(b)
}

/// あるプレイヤーが配置されたサイドを返す。
private func side(of match: Match<Int>, _ id: Int) -> Side? {
    for team in [match.teamA, match.teamB] {
        if team.drive.id == id { return .drive }
        if team.back.id == id { return .back }
    }
    return nil
}

// MARK: - 基本

@Suite("基本のマッチメイク")
struct BasicMatchmakingTests {

    @Test("4 人ちょうどで 1 試合が組める")
    func makesMatchWithFourPlayers() throws {
        let matchmaker = Matchmaker<Int>()
        let match = try matchmaker.makeMatch(from: makePlayers(4))

        #expect(match.players.count == 4)
        #expect(match.teamA.players.count == 2)
        #expect(match.teamB.players.count == 2)
        // 4 人が重複なく出場している。
        #expect(Set(match.playerIDs).count == 4)
    }

    @Test("4 人未満ではエラーになる")
    func throwsWhenNotEnoughPlayers() {
        let matchmaker = Matchmaker<Int>()
        #expect(throws: MatchmakingError.notEnoughPlayers(available: 3)) {
            _ = try matchmaker.makeMatch(from: makePlayers(3))
        }
    }

    @Test("休憩中のプレイヤーは選ばれない")
    func skipsRestingPlayers() throws {
        var players = makePlayers(5)
        players[4].isResting = true   // P5 を休憩中にする
        let matchmaker = Matchmaker<Int>()
        let match = try matchmaker.makeMatch(from: players)
        #expect(!match.playerIDs.contains(5))
    }

    @Test("休憩で出場可能が 4 人未満になるとエラー")
    func throwsWhenRestingLeavesTooFew() {
        var players = makePlayers(5)
        players[3].isResting = true
        players[4].isResting = true
        let matchmaker = Matchmaker<Int>()
        #expect(throws: MatchmakingError.notEnoughPlayers(available: 3)) {
            _ = try matchmaker.makeMatch(from: players)
        }
    }
}

// MARK: - 公平性

@Suite("出場回数の公平性")
struct FairnessTests {

    @Test("出場回数が多いプレイヤーは、少ない人がいる限り選ばれない")
    func prefersLowestPlayCount() throws {
        var players = makePlayers(5)
        players[4].playCount = 5   // P5 だけ多く出場済み
        let matchmaker = Matchmaker<Int>()
        let match = try matchmaker.makeMatch(from: players)
        #expect(!match.playerIDs.contains(5))   // P5 は出ない
    }

    @Test("最も出場回数が少ないプレイヤーは必ず選ばれる")
    func includesTheLeastPlayedPlayer() throws {
        var players = makePlayers(5)
        // P1〜P4 は 1 回出場済み、P5 だけ未出場。
        for i in 0..<4 { players[i].playCount = 1 }
        let matchmaker = Matchmaker<Int>()
        let match = try matchmaker.makeMatch(from: players)
        #expect(match.playerIDs.contains(5))
    }

    @Test("繰り返し組んでも出場回数の差は 1 以内に収まる")
    func keepsPlayCountBalancedOverManyMatches() throws {
        var players = makePlayers(8)
        var rng = SeededRandomNumberGenerator(seed: 7)
        let matchmaker = Matchmaker<Int>()

        for _ in 0..<30 {
            let match = try matchmaker.makeMatch(from: players, using: &rng)
            Matchmaker.apply(match, to: &players)
        }
        let counts = players.map(\.playCount)
        let spread = (counts.max() ?? 0) - (counts.min() ?? 0)
        #expect(spread <= 1)
    }

    @Test("fairness=.off では出場回数が多い人も選ばれうる")
    func offModeIgnoresPlayCount() throws {
        // P5 だけ大量に出場済み。strict なら絶対に選ばれないが、.off なら選ばれうる。
        var players = makePlayers(5)
        players[4].playCount = 99

        let matchmaker = Matchmaker(options: MatchmakingOptions<Int>(fairness: .off))
        var appearedAtLeastOnce = false
        for seed in 0..<30 {
            var rng = SeededRandomNumberGenerator(seed: UInt64(seed))
            let match = try matchmaker.makeMatch(from: players, using: &rng)
            if match.playerIDs.contains(5) { appearedAtLeastOnce = true; break }
        }
        #expect(appearedAtLeastOnce)
    }
}

// MARK: - 固定ペア

@Suite("固定ペア")
struct FixedPairTests {

    @Test("固定ペアは必ず同じチームになる")
    func fixedPairAlwaysOnSameTeam() throws {
        let options = MatchmakingOptions(fixedPairs: [FixedPair(1, 2)])
        let matchmaker = Matchmaker(options: options)
        var rng = SeededRandomNumberGenerator(seed: 1)
        // 何度引いても 1 と 2 は同じチーム。
        for _ in 0..<20 {
            let match = try matchmaker.makeMatch(from: makePlayers(4), using: &rng)
            #expect(sameTeam(match, 1, 2))
        }
    }

    @Test("固定ペアの片方が選ばれたら相方も必ず出場する")
    func fixedPairMembersComeTogether() throws {
        let options = MatchmakingOptions(fixedPairs: [FixedPair(1, 2)])
        let matchmaker = Matchmaker(options: options)
        var rng = SeededRandomNumberGenerator(seed: 3)
        for _ in 0..<20 {
            let match = try matchmaker.makeMatch(from: makePlayers(6), using: &rng)
            let has1 = match.playerIDs.contains(1)
            let has2 = match.playerIDs.contains(2)
            #expect(has1 == has2)   // 片方だけ出場することはない
        }
    }

    @Test("同じ人物を 2 つの固定ペアに入れるとエラー")
    func rejectsOverlappingFixedPairs() {
        let options = MatchmakingOptions(fixedPairs: [FixedPair(1, 2), FixedPair(1, 3)])
        let matchmaker = Matchmaker(options: options)
        #expect(throws: (any Error).self) {
            _ = try matchmaker.makeMatch(from: makePlayers(4))
        }
    }

    @Test("同一人物のペアはエラー")
    func rejectsSelfPair() {
        let options = MatchmakingOptions(fixedPairs: [FixedPair(1, 1)])
        let matchmaker = Matchmaker(options: options)
        #expect(throws: (any Error).self) {
            _ = try matchmaker.makeMatch(from: makePlayers(4))
        }
    }
}

// MARK: - スキルバランス

@Suite("スキルバランス")
struct SkillBalanceTests {

    @Test("competitiveBalance では実力が拮抗するチーム分割を選ぶ")
    func balancesTeamSkill() throws {
        let players = [
            Player(id: 1, name: "強1", skill: 10),
            Player(id: 2, name: "強2", skill: 10),
            Player(id: 3, name: "弱1", skill: 1),
            Player(id: 4, name: "弱2", skill: 1)
        ]
        let matchmaker = Matchmaker<Int>(weights: .competitiveBalance)
        var rng = SeededRandomNumberGenerator(seed: 5)
        let match = try matchmaker.makeMatch(from: players, using: &rng)
        // (強, 弱) vs (強, 弱) になり、平均スキル差は 0 になるはず。
        let gap = try #require(match.skillGap)
        #expect(gap == 0)
    }
}

// MARK: - サイド希望

@Suite("希望サイド")
struct SidePreferenceTests {

    @Test("希望サイドどおりに配置される")
    func respectsPreferredSide() throws {
        let players = [
            Player(id: 1, name: "ドライブ希望", preferredSide: .drive),
            Player(id: 2, name: "バック希望", preferredSide: .back),
            Player(id: 3, name: "自由3", preferredSide: .any),
            Player(id: 4, name: "自由4", preferredSide: .any)
        ]
        let matchmaker = Matchmaker<Int>()
        var rng = SeededRandomNumberGenerator(seed: 9)
        let match = try matchmaker.makeMatch(from: players, using: &rng)
        #expect(side(of: match, 1) == .drive)
        #expect(side(of: match, 2) == .back)
    }
}

// MARK: - 重複回避（履歴）

@Suite("ペア・対戦の重複回避")
struct RepetitionTests {

    @Test("直前に組んだ相手とは別の組み合わせになる")
    func avoidsRecentPartners() throws {
        // 1-2 と 3-4 がそれぞれ 1 回ずつ組んだ履歴を仕込む。
        var players = makePlayers(4)
        players[0].partnerCounts = [2: 1]
        players[1].partnerCounts = [1: 1]
        players[2].partnerCounts = [4: 1]
        players[3].partnerCounts = [3: 1]

        let matchmaker = Matchmaker<Int>()
        var rng = SeededRandomNumberGenerator(seed: 11)
        let match = try matchmaker.makeMatch(from: players, using: &rng)
        // 4 人しかいないので foursome は固定。新鮮な分割（1-2 を割る）が選ばれる。
        #expect(!sameTeam(match, 1, 2))
        #expect(!sameTeam(match, 3, 4))
    }
}

// MARK: - 履歴の反映

@Suite("結果の反映 apply")
struct ApplyTests {

    @Test("apply で出場回数と履歴が更新される")
    func updatesCountsAndHistory() throws {
        var players = makePlayers(4)
        let matchmaker = Matchmaker<Int>()
        var rng = SeededRandomNumberGenerator(seed: 13)
        let match = try matchmaker.makeMatch(from: players, using: &rng)

        Matchmaker.apply(match, to: &players)

        // 全員 1 回出場済みになる。
        #expect(players.allSatisfy { $0.playCount == 1 })

        // teamA のドライブは、バックを「味方」、teamB の 2 人を「対戦相手」として記録する。
        let driveAID = match.teamA.drive.id
        let backAID = match.teamA.back.id
        let opponents = match.teamB.players.map(\.id)
        let driveA = try #require(players.first { $0.id == driveAID })

        #expect(driveA.partnerCount(with: backAID) == 1)
        for opponentID in opponents {
            #expect(driveA.opponentCount(with: opponentID) == 1)
        }
        // 味方を対戦相手として数えていないこと。
        #expect(driveA.opponentCount(with: backAID) == 0)
    }
}

// MARK: - ラウンド（複数コート）

@Suite("ラウンド生成")
struct RoundTests {

    @Test("2 コート・8 人で 2 試合・全員重複なく出場")
    func fillsTwoCourts() {
        let players = makePlayers(8)
        let matchmaker = Matchmaker<Int>()
        var rng = SeededRandomNumberGenerator(seed: 17)
        let matches = matchmaker.makeRound(from: players, courtCount: 2, using: &rng)

        #expect(matches.count == 2)
        let allIDs = matches.flatMap(\.playerIDs)
        #expect(allIDs.count == 8)
        #expect(Set(allIDs).count == 8)   // 同じ人が 2 試合に出ていない
    }

    @Test("コート名を渡すと各試合に割り当てられる")
    func assignsCourtNames() {
        let players = makePlayers(8)
        let matchmaker = Matchmaker<Int>()
        var rng = SeededRandomNumberGenerator(seed: 19)
        let matches = matchmaker.makeRound(from: players, courts: ["A コート", "B コート"], using: &rng)

        #expect(matches.count == 2)
        #expect(matches[0].court == "A コート")
        #expect(matches[1].court == "B コート")
    }

    @Test("人数が足りない分のコートは埋めない")
    func stopsWhenPlayersRunOut() {
        let players = makePlayers(5)   // 5 人では 1 試合分しか作れない
        let matchmaker = Matchmaker<Int>()
        var rng = SeededRandomNumberGenerator(seed: 23)
        let matches = matchmaker.makeRound(from: players, courtCount: 3, using: &rng)
        #expect(matches.count == 1)
    }
}

// MARK: - 決定論（再現性）

@Suite("シードによる再現性")
struct DeterminismTests {

    @Test("同じシードなら同じ組み合わせになる")
    func sameSeedSameResult() throws {
        let players = makePlayers(8)
        let matchmaker = Matchmaker<Int>()

        var rng1 = SeededRandomNumberGenerator(seed: 1234)
        var rng2 = SeededRandomNumberGenerator(seed: 1234)
        let match1 = try matchmaker.makeMatch(from: players, using: &rng1)
        let match2 = try matchmaker.makeMatch(from: players, using: &rng2)

        #expect(match1 == match2)
    }
}
