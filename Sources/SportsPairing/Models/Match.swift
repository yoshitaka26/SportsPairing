//
//  Match.swift
//  SportsPairing
//

/// 1 試合（2 対 2）。対戦する 2 つのチームと、任意のコート名を持つ。
public struct Match<ID: Hashable & Sendable>: Sendable {

    /// チーム A（`teamB` と対戦する）。
    public let teamA: Team<ID>
    /// チーム B。
    public let teamB: Team<ID>
    /// 割り当てられたコート名（任意）。``Matchmaker/makeRound(from:courts:using:)`` が設定する。
    public var court: String?

    public init(teamA: Team<ID>, teamB: Team<ID>, court: String? = nil) {
        self.teamA = teamA
        self.teamB = teamB
        self.court = court
    }

    /// 試合に出場する 4 人（teamA のドライブ・バック、teamB のドライブ・バック）。
    public var players: [Player<ID>] {
        teamA.players + teamB.players
    }

    /// 出場 4 人の ID。
    public var playerIDs: [ID] {
        players.map(\.id)
    }

    /// 2 チームの平均スキル差（絶対値）。スキル未設定の場合は `nil`。
    public var skillGap: Double? {
        guard let a = teamA.averageSkill, let b = teamB.averageSkill else { return nil }
        return abs(a - b)
    }

    /// "Alice / Bob  vs  Carol / Dave" 形式の概要文字列（ログ・デバッグ用）。
    /// シングルスなら "Alice  vs  Bob" のようにチーム人数に応じて並ぶ。
    public var summary: String {
        func label(_ team: Team<ID>) -> String {
            team.players
                .map { $0.name.isEmpty ? "\($0.id)" : $0.name }
                .joined(separator: " / ")
        }
        let body = "\(label(teamA))  vs  \(label(teamB))"
        if let court { return "[\(court)] \(body)" }
        return body
    }
}

extension Match: Equatable {
    public static func == (lhs: Match<ID>, rhs: Match<ID>) -> Bool {
        lhs.teamA == rhs.teamA && lhs.teamB == rhs.teamB && lhs.court == rhs.court
    }
}
