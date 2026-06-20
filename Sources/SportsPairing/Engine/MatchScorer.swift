//
//  MatchScorer.swift
//  SportsPairing
//

/// 候補となる組み合わせの「コスト」を計算する内部ユーティリティ。
///
/// すべてのコスト項目はおおむね 0〜1 に正規化したうえで重み (``MatchmakingWeights``) を掛ける。
/// これにより重みは「項目どうしの相対的な重要度」として一貫した意味を持つ（= 重みの標準化）。
struct MatchScorer<ID: Hashable & Sendable> {

    let weights: MatchmakingWeights
    /// スキル差の正規化に使うレンジ幅（``MatchmakingOptions/skillRange``）。
    let skillRange: Double

    /// 回数を 0〜1 未満に飽和させる関数。`n/(n+1)`。
    ///
    /// 0 回 → 0、1 回 → 0.5、2 回 → 0.667 … と、
    /// 「1 回でも重複するとペナルティが立ち、回数が増えるほど鈍く増える」標準曲線。
    func saturating(_ count: Int) -> Double {
        Double(count) / Double(count + 1)
    }

    // MARK: - 選出フェーズ（4 人を選ぶ）

    /// 4 人組の「新鮮さ」コスト。小さいほど、最近一緒にプレイしていない顔ぶれ。
    ///
    /// チームがまだ確定していない段階なので、4 人の全 6 ペアについて
    /// 味方履歴・対戦履歴の飽和値を平均して評価する。
    func varietyCost(of players: [Player<ID>]) -> Double {
        var partnerSum = 0.0
        var opponentSum = 0.0
        var pairCount = 0
        for i in players.indices {
            for j in (i + 1)..<players.count {
                let a = players[i]
                let b = players[j]
                partnerSum += saturating(a.partnerCount(with: b.id))
                opponentSum += saturating(a.opponentCount(with: b.id))
                pairCount += 1
            }
        }
        guard pairCount > 0 else { return 0 }
        let partner = partnerSum / Double(pairCount)
        let opponent = opponentSum / Double(pairCount)
        return weights.partnerRepeat * partner + weights.opponentRepeat * opponent
    }

    // MARK: - 配置フェーズ（チーム分割とサイド割当）

    /// 確定した 2 チーム（サイド込み）のコスト。小さいほど良い組み合わせ。
    ///
    /// チーム人数は任意（シングルス = 1 人、ダブルス = 2 人）に対応する。
    /// 各項目はチーム人数に依らず 0〜1 に正規化される。
    func matchCost(teamA: Team<ID>, teamB: Team<ID>) -> Double {
        // ① 味方の重複: 各チーム内の全ペアがこれまで組んだ回数の平均。
        //    シングルス（1 人チーム）はチーム内ペアが無いので 0。
        let partner = averagePartnerRepeat(teamA, teamB)

        // ② 対戦の重複: チームをまたぐ全ペアがこれまで対戦した回数の平均。
        let opponent = averageOpponentRepeat(teamA, teamB)

        // ③ スキル均衡: チーム平均スキルの差をレンジで正規化。未設定なら 0。
        var skill = 0.0
        if let gap = skillGap(teamA, teamB) {
            skill = min(gap / skillRange, 1)
        }

        // ④ サイド希望: 希望と異なるサイドに置かれた人数 / 出場人数。
        let totalPlayers = teamA.members.count + teamB.members.count
        let conflicts = sideConflicts(in: teamA) + sideConflicts(in: teamB)
        let side = totalPlayers > 0 ? Double(conflicts) / Double(totalPlayers) : 0

        return weights.partnerRepeat * partner
            + weights.opponentRepeat * opponent
            + weights.skillBalance * skill
            + weights.sidePreference * side
    }

    /// 両チームのチーム内ペアについて、味方重複の飽和値を平均する。
    private func averagePartnerRepeat(_ teamA: Team<ID>, _ teamB: Team<ID>) -> Double {
        var sum = 0.0
        var count = 0
        for team in [teamA, teamB] {
            let players = team.players
            for i in players.indices {
                for j in (i + 1)..<players.count {
                    sum += saturating(players[i].partnerCount(with: players[j].id))
                    count += 1
                }
            }
        }
        return count > 0 ? sum / Double(count) : 0
    }

    /// チームをまたぐ全ペアについて、対戦重複の飽和値を平均する。
    private func averageOpponentRepeat(_ teamA: Team<ID>, _ teamB: Team<ID>) -> Double {
        var sum = 0.0
        var count = 0
        for a in teamA.players {
            for b in teamB.players {
                sum += saturating(a.opponentCount(with: b.id))
                count += 1
            }
        }
        return count > 0 ? sum / Double(count) : 0
    }

    /// 2 チームの平均スキル差。どちらかでもスキル未設定なら `nil`。
    private func skillGap(_ teamA: Team<ID>, _ teamB: Team<ID>) -> Double? {
        guard let a = teamA.averageSkill, let b = teamB.averageSkill else { return nil }
        return abs(a - b)
    }

    /// チーム内で希望サイドに反して配置された人数。
    private func sideConflicts(in team: Team<ID>) -> Int {
        team.members.reduce(0) { count, member in
            count + (member.player.preferredSide.conflicts(with: member.side) ? 1 : 0)
        }
    }
}
