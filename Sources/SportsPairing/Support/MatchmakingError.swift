//
//  MatchmakingError.swift
//  SportsPairing
//

/// マッチメイクに失敗したときのエラー。
public enum MatchmakingError: Error, Equatable, Sendable {

    /// 出場可能なプレイヤーが必要人数に満たない。
    case notEnoughPlayers(available: Int)

    /// 固定ペアの設定が不正（同一人物の重複指定、3 つ以上のペアに同じ人が属する等）。
    case invalidFixedPairs(reason: String)

    /// 総当たり表生成で、人数が対応範囲外（少なすぎる / 多すぎる）。
    case invalidPlayerCount(reason: String)
}

extension MatchmakingError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .notEnoughPlayers(available):
            return "出場可能なプレイヤーが足りません（現在: \(available)）。"
        case let .invalidFixedPairs(reason):
            return "固定ペアの設定が不正です: \(reason)"
        case let .invalidPlayerCount(reason):
            return "人数が対応範囲外です: \(reason)"
        }
    }
}
