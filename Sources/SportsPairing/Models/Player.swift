//
//  Player.swift
//  SportsPairing
//

/// マッチメイクの対象となる参加者（プレイヤー）。
///
/// `ID` はアプリ側の識別子に合わせて自由に選べる（`Int`・`UUID`・`String` など）。
/// PadeLovers の `Player.playerID`（`Int16`）や、UUID ベースのアプリのどちらにも対応する。
///
/// このライブラリのエンジンは **純粋関数的** に動作する。すなわち `Matchmaker` は
/// この値型を読み取って組み合わせを返すだけで、状態を内部に持たない。
/// 試合終了後の履歴更新はアプリ側が ``Matchmaker/apply(_:to:)`` を呼んで行う。
public struct Player<ID: Hashable & Sendable>: Identifiable, Sendable {

    /// アプリ固有の安定した識別子。
    public let id: ID

    /// 表示名。マッチングには影響しない（ログ・UI 用）。
    public var name: String

    /// これまでの出場（試合）回数。公平性の判定に使う。
    public var playCount: Int

    /// スキル評価値（任意）。`nil` のプレイヤーが 1 人でも含まれる試合では
    /// スキルバランスの評価はスキップされる。値域はアプリで統一すること
    /// （既定の正規化は ``MatchmakingOptions/skillRange`` を用いる）。
    public var skill: Double?

    /// 希望サイド（ドライブ / バック / どちらでも）。
    public var preferredSide: Side

    /// 一時的に休憩中で、次の試合に出さないプレイヤーは `true`。
    public var isResting: Bool

    /// 各プレイヤー（ID）と **味方として** 組んだ回数の履歴。
    /// ``Matchmaker/apply(_:to:)`` が更新する。
    public var partnerCounts: [ID: Int]

    /// 各プレイヤー（ID）と **対戦相手として** 当たった回数の履歴。
    public var opponentCounts: [ID: Int]

    public init(
        id: ID,
        name: String = "",
        playCount: Int = 0,
        skill: Double? = nil,
        preferredSide: Side = .any,
        isResting: Bool = false,
        partnerCounts: [ID: Int] = [:],
        opponentCounts: [ID: Int] = [:]
    ) {
        self.id = id
        self.name = name
        self.playCount = playCount
        self.skill = skill
        self.preferredSide = preferredSide
        self.isResting = isResting
        self.partnerCounts = partnerCounts
        self.opponentCounts = opponentCounts
    }

    /// 指定した相手と味方として組んだ回数。
    public func partnerCount(with otherID: ID) -> Int {
        partnerCounts[otherID] ?? 0
    }

    /// 指定した相手と対戦した回数。
    public func opponentCount(with otherID: ID) -> Int {
        opponentCounts[otherID] ?? 0
    }
}

extension Player: Equatable {
    /// 同一性は ID のみで判定する（履歴や出場回数が変わっても同じプレイヤー）。
    public static func == (lhs: Player<ID>, rhs: Player<ID>) -> Bool {
        lhs.id == rhs.id
    }
}

extension Player: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
