//
//  NumberedMatch.swift
//  SportsPairing
//

/// 背番号（数字）で管理するチーム。総当たり表 (``RoundRobinGenerator``) の出力で使う。
///
/// シングルスなら 1 つ、ダブルスなら 2 つの番号を持つ。番号は昇順に正規化される。
public struct NumberedTeam: Sendable, Equatable, Hashable {

    /// このチームの背番号（昇順）。
    public let numbers: [Int]

    public init(_ numbers: [Int]) {
        self.numbers = numbers.sorted()
    }

    /// 指定した番号がこのチームに含まれるか。
    public func contains(_ number: Int) -> Bool {
        numbers.contains(number)
    }
}

/// 背番号で管理する 1 試合。総当たり表の 1 行に相当する。
public struct NumberedMatch: Sendable, Equatable {

    /// スケジュール内での順番（1 始まり）。
    public let order: Int
    /// 一方のチーム。
    public let teamA: NumberedTeam
    /// もう一方のチーム。
    public let teamB: NumberedTeam

    public init(order: Int, teamA: NumberedTeam, teamB: NumberedTeam) {
        self.order = order
        self.teamA = teamA
        self.teamB = teamB
    }

    /// この試合に出場する全番号（昇順）。
    public var numbers: [Int] {
        (teamA.numbers + teamB.numbers).sorted()
    }

    /// 指定した番号がこの試合に出場するか。
    public func contains(_ number: Int) -> Bool {
        teamA.contains(number) || teamB.contains(number)
    }

    /// 出場する番号の集合を表す正規化キー（同一カードの判定に使う）。
    var groupKey: [Int] { numbers }

    /// "1,2 vs 3,4" 形式の概要文字列。
    public var summary: String {
        func label(_ team: NumberedTeam) -> String {
            team.numbers.map(String.init).joined(separator: ",")
        }
        return "\(label(teamA)) vs \(label(teamB))"
    }
}
