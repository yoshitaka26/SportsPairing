//
//  Side.swift
//  SportsPairing
//

/// ダブルスにおけるコート上のポジション（サイド）。
///
/// パデルやテニスのダブルスでは、各チームが「ドライブ側（一般に右）」と
/// 「バック側（一般に左）」に 1 人ずつ立つ。プレイヤーは希望サイドを持てる。
public enum Side: String, CaseIterable, Sendable, Codable, Hashable {
    /// ドライブ側（多くの競技で右側）。
    case drive
    /// バック側（多くの競技で左側）。
    case back
    /// どちらでもよい（希望なし）。
    case any

    /// 実際に配置された `placed` サイドが、この希望に反しているかどうか。
    ///
    /// `.any` は常に満たされる。`.drive` / `.back` は同じサイドのときのみ満たされる。
    func conflicts(with placed: Side) -> Bool {
        switch self {
        case .any:
            return false
        default:
            return self != placed
        }
    }
}
