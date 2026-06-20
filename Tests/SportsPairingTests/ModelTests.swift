import Testing
@testable import SportsPairing

// モデル層（値型）の単体テスト。
// エンジンを通さず、各型の等価性・正規化・派生プロパティの契約を直接検証する。

// MARK: - Player

@Suite("Player モデル")
struct PlayerModelTests {

    @Test("同一 ID なら出場回数や名前が違っても等価")
    func equatableByID() {
        let a = Player(id: 1, name: "A", playCount: 0)
        let b = Player(id: 1, name: "Different", playCount: 9)
        let c = Player(id: 2)
        #expect(a == b)   // ID が同じなら状態に関係なく同一プレイヤー
        #expect(a != c)
    }

    @Test("Set では ID で重複排除される")
    func hashableByID() {
        let set: Set = [
            Player(id: 1, playCount: 0),
            Player(id: 1, playCount: 5),   // 同じ ID → 1 件に潰れる
            Player(id: 2)
        ]
        #expect(set.count == 2)
    }

    @Test("履歴の取得は未登録の相手で 0 を返す")
    func countAccessors() {
        var p = Player(id: 1)
        p.partnerCounts = [2: 3]
        p.opponentCounts = [3: 1]
        #expect(p.partnerCount(with: 2) == 3)
        #expect(p.partnerCount(with: 99) == 0)
        #expect(p.opponentCount(with: 3) == 1)
        #expect(p.opponentCount(with: 99) == 0)
    }
}

// MARK: - Team

@Suite("Team モデル")
struct TeamModelTests {

    @Test("サイド未指定なら全員 .any、drive/back はフォールバックする")
    func defaultSides() {
        let team = Team([Player(id: 1), Player(id: 2)])
        #expect(team.members.allSatisfy { $0.side == .any })
        #expect(team.drive.id == 1)   // サイド情報なし → 先頭をドライブ扱い
        #expect(team.back.id == 2)    // サイド情報なし → 末尾をバック扱い
    }

    @Test("drive/back 指定の初期化ではサイドが設定される")
    func driveBackInit() {
        let team = Team(drive: Player(id: 1), back: Player(id: 2))
        #expect(team.drive.id == 1)
        #expect(team.back.id == 2)
        #expect(team.members.first { $0.side == .drive }?.player.id == 1)
        #expect(team.members.first { $0.side == .back }?.player.id == 2)
    }

    @Test("平均スキルは全メンバーに値があるときだけ算出（一部 nil なら nil）")
    func averageSkill() {
        #expect(Team([Player(id: 1, skill: 4), Player(id: 2, skill: 8)]).averageSkill == 6)
        #expect(Team([Player(id: 1, skill: 4), Player(id: 2, skill: nil)]).averageSkill == nil)
    }

    @Test("contains と players の順序")
    func containsAndPlayers() {
        let team = Team(drive: Player(id: 1), back: Player(id: 2))
        #expect(team.contains(1))
        #expect(!team.contains(3))
        #expect(team.players.map(\.id) == [1, 2])
    }
}

// MARK: - Match

@Suite("Match モデル")
struct MatchModelTests {

    private func sampleMatch(court: String? = nil) -> Match<Int> {
        let a = Team(drive: Player(id: 1, name: "Alice"), back: Player(id: 2, name: "Bob"))
        let b = Team(drive: Player(id: 3, name: "Carol"), back: Player(id: 4, name: "Dave"))
        return Match(teamA: a, teamB: b, court: court)
    }

    @Test("summary はダブルス形式で整形される")
    func summaryDoubles() {
        #expect(sampleMatch().summary == "Alice / Bob  vs  Carol / Dave")
    }

    @Test("コート名は summary の先頭に前置される")
    func summaryWithCourt() {
        #expect(sampleMatch(court: "A").summary == "[A] Alice / Bob  vs  Carol / Dave")
    }

    @Test("名前が空なら ID で表示される")
    func summaryFallbackToID() {
        let a = Team(drive: Player(id: 1), back: Player(id: 2))
        let b = Team(drive: Player(id: 3), back: Player(id: 4))
        #expect(Match(teamA: a, teamB: b).summary == "1 / 2  vs  3 / 4")
    }

    @Test("players と playerIDs は teamA→teamB の順で 4 人")
    func playersAndIDs() {
        #expect(sampleMatch().playerIDs == [1, 2, 3, 4])
        #expect(sampleMatch().players.count == 4)
    }

    @Test("skillGap はスキル未設定なら nil")
    func skillGapNil() {
        #expect(sampleMatch().skillGap == nil)
    }

    @Test("skillGap はチーム平均スキルの差（絶対値）")
    func skillGapValue() {
        let a = Team([Player(id: 1, skill: 10), Player(id: 2, skill: 10)])  // 平均 10
        let b = Team([Player(id: 3, skill: 2), Player(id: 4, skill: 4)])    // 平均 3
        #expect(Match(teamA: a, teamB: b).skillGap == 7)
    }
}

// MARK: - FixedPair

@Suite("FixedPair モデル")
struct FixedPairModelTests {

    @Test("contains / partner / ids のヘルパー")
    func helpers() {
        let pair = FixedPair(1, 2)
        #expect(pair.contains(1))
        #expect(pair.contains(2))
        #expect(!pair.contains(3))
        #expect(pair.partner(of: 1) == 2)
        #expect(pair.partner(of: 2) == 1)
        #expect(pair.partner(of: 3) == nil)
        #expect(pair.ids == [1, 2])
    }
}

// MARK: - MatchFormat

@Suite("MatchFormat")
struct MatchFormatModelTests {

    @Test("teamSize は 1 未満を 1 に丸める")
    func clampsTeamSize() {
        #expect(MatchFormat(teamSize: 0, usesSides: true).teamSize == 1)
        #expect(MatchFormat(teamSize: -3, usesSides: false).teamSize == 1)
    }

    @Test("playersPerMatch は teamSize × 2")
    func playersPerMatch() {
        #expect(MatchFormat.singles.playersPerMatch == 2)
        #expect(MatchFormat.doubles.playersPerMatch == 4)
        #expect(MatchFormat(teamSize: 3, usesSides: false).playersPerMatch == 6)
    }

    @Test("assignsSides は teamSize==2 かつ usesSides のときだけ true")
    func assignsSides() {
        #expect(MatchFormat.doubles.assignsSides)
        #expect(!MatchFormat.doublesNoSides.assignsSides)
        #expect(!MatchFormat.singles.assignsSides)
        #expect(!MatchFormat(teamSize: 3, usesSides: true).assignsSides)   // 3 対 3 はサイドなし
    }

    @Test("プリセットの構成")
    func presets() {
        #expect(MatchFormat.singles == MatchFormat(teamSize: 1, usesSides: false))
        #expect(MatchFormat.doubles == MatchFormat(teamSize: 2, usesSides: true))
        #expect(MatchFormat.doublesNoSides == MatchFormat(teamSize: 2, usesSides: false))
    }
}

// MARK: - Side

@Suite("Side")
struct SideModelTests {

    @Test(".any はどのサイドにも反しない")
    func anyNeverConflicts() {
        #expect(!Side.any.conflicts(with: .drive))
        #expect(!Side.any.conflicts(with: .back))
        #expect(!Side.any.conflicts(with: .any))
    }

    @Test("希望サイドと配置サイドが異なると反する")
    func conflictsOnMismatch() {
        #expect(!Side.drive.conflicts(with: .drive))
        #expect(Side.drive.conflicts(with: .back))
        #expect(Side.back.conflicts(with: .drive))
    }
}
