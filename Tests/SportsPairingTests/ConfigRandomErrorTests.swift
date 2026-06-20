import Testing
@testable import SportsPairing

// 設定型・乱数器・エラー・ライブラリ情報の単体テスト。

// MARK: - MatchmakingOptions

@Suite("MatchmakingOptions")
struct MatchmakingOptionsTests {

    @Test("skillRange は 1 未満を 1 に丸める（0 除算回避）")
    func clampsSkillRange() {
        #expect(MatchmakingOptions<Int>(skillRange: 0).skillRange == 1)
        #expect(MatchmakingOptions<Int>(skillRange: -5).skillRange == 1)
        #expect(MatchmakingOptions<Int>(skillRange: 9).skillRange == 9)
    }

    @Test("既定値")
    func defaults() {
        let options = MatchmakingOptions<Int>()
        #expect(options.format == .doubles)
        #expect(options.fairness == .strict)
        #expect(options.fixedPairs.isEmpty)
        #expect(options.skillRange == 10)
    }
}

// MARK: - MatchmakingWeights

@Suite("MatchmakingWeights")
struct MatchmakingWeightsTests {

    @Test("既定（balanced）の値")
    func balancedValues() {
        let w = MatchmakingWeights.balanced
        #expect(w == MatchmakingWeights())
        #expect(w.partnerRepeat == 1.0)
        #expect(w.opponentRepeat == 0.5)
        #expect(w.skillBalance == 0.5)
        #expect(w.sidePreference == 0.3)
    }

    @Test("プリセットごとの主眼となる重み")
    func presetEmphasis() {
        #expect(MatchmakingWeights.maximizeVariety.opponentRepeat == 1.0)
        #expect(MatchmakingWeights.competitiveBalance.skillBalance == 1.0)
        #expect(MatchmakingWeights.balanced != MatchmakingWeights.maximizeVariety)
    }
}

// MARK: - MatchmakingError

@Suite("MatchmakingError")
struct MatchmakingErrorTests {

    @Test("Equatable は付随値まで比較する")
    func equatable() {
        #expect(MatchmakingError.notEnoughPlayers(available: 2) == .notEnoughPlayers(available: 2))
        #expect(MatchmakingError.notEnoughPlayers(available: 2) != .notEnoughPlayers(available: 3))
    }

    @Test("description は内容を含む非空文字列")
    func description() {
        #expect(MatchmakingError.notEnoughPlayers(available: 2).description.contains("2"))
        #expect(!MatchmakingError.invalidFixedPairs(reason: "x").description.isEmpty)
        #expect(!MatchmakingError.invalidPlayerCount(reason: "y").description.isEmpty)
    }
}

// MARK: - SeededRandomNumberGenerator

@Suite("SeededRandomNumberGenerator")
struct SeededRNGTests {

    @Test("同じシードは同じ乱数列を生む")
    func deterministic() {
        var a = SeededRandomNumberGenerator(seed: 42)
        var b = SeededRandomNumberGenerator(seed: 42)
        for _ in 0..<16 {
            #expect(a.next() == b.next())
        }
    }

    @Test("異なるシードは異なる乱数列を生む")
    func distinctSeeds() {
        var a = SeededRandomNumberGenerator(seed: 1)
        var b = SeededRandomNumberGenerator(seed: 2)
        #expect(a.next() != b.next())
    }

    @Test("シード 0 でも縮退せず連続値が異なる")
    func seedZeroNotDegenerate() {
        var z = SeededRandomNumberGenerator(seed: 0)
        let v1 = z.next()
        let v2 = z.next()
        let v3 = z.next()
        #expect(v1 != 0)
        #expect(Set([v1, v2, v3]).count == 3)
    }
}

// MARK: - ライブラリ情報

@Suite("ライブラリ情報")
struct LibraryInfoTests {

    @Test("version は 0.2.0")
    func version() {
        #expect(SportsPairing.version == "0.2.0")
    }
}
