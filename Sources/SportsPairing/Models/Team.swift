//
//  Team.swift
//  SportsPairing
//

/// 1 チーム。1 人以上のメンバーで構成され、各メンバーは配置サイドを持つ。
///
/// シングルスならメンバー 1 人、ダブルスなら 2 人（ドライブ / バック）。
/// ダブルス向けに ``drive`` / ``back`` の互換アクセサを用意してある。
public struct Team<ID: Hashable & Sendable>: Sendable {

    /// チームのメンバー（プレイヤー + 配置サイド）。
    public struct Member: Sendable, Equatable {
        public let player: Player<ID>
        public let side: Side

        public init(player: Player<ID>, side: Side) {
            self.player = player
            self.side = side
        }
    }

    /// チームを構成するメンバー一覧。
    public let members: [Member]

    /// 任意のメンバー配列で初期化する。
    public init(members: [Member]) {
        self.members = members
    }

    /// プレイヤーとサイドの組から初期化する。
    public init(_ players: [Player<ID>], sides: [Side]? = nil) {
        self.members = players.enumerated().map { index, player in
            Member(player: player, side: sides?[index] ?? .any)
        }
    }

    /// ダブルス用の簡易初期化（ドライブ・バックを指定）。
    public init(drive: Player<ID>, back: Player<ID>) {
        self.members = [
            Member(player: drive, side: .drive),
            Member(player: back, side: .back)
        ]
    }

    /// チームを構成するプレイヤー。
    public var players: [Player<ID>] { members.map(\.player) }

    /// ドライブ側のプレイヤー（ダブルス互換）。
    /// サイド指定がなければ先頭メンバーを返す。
    public var drive: Player<ID> {
        members.first { $0.side == .drive }?.player ?? members[0].player
    }

    /// バック側のプレイヤー（ダブルス互換）。
    /// サイド指定がなければ末尾メンバーを返す。
    public var back: Player<ID> {
        members.first { $0.side == .back }?.player ?? members[members.count - 1].player
    }

    /// チームの平均スキル。いずれかのメンバーが未設定なら `nil`。
    public var averageSkill: Double? {
        let skills = members.compactMap(\.player.skill)
        guard skills.count == members.count, !skills.isEmpty else { return nil }
        return skills.reduce(0, +) / Double(skills.count)
    }

    /// 指定したプレイヤー（ID）がこのチームに含まれるか。
    public func contains(_ id: ID) -> Bool {
        members.contains { $0.player.id == id }
    }
}

extension Team: Equatable {
    public static func == (lhs: Team<ID>, rhs: Team<ID>) -> Bool {
        lhs.members == rhs.members
    }
}
