//
//  FixedPair.swift
//  SportsPairing
//

/// 固定ペア。「この 2 人は必ず同じチーム（味方）で組ませる」という制約。
///
/// PadeLovers の Pairing A / Pairing B に相当する。同じ試合に固定ペアの
/// 一方が選ばれた場合、もう一方も必ず同じ試合に呼ばれ、かつ味方として配置される。
public struct FixedPair<ID: Hashable & Sendable>: Sendable, Equatable {

    /// 固定ペアを構成する一方のプレイヤー ID。
    public let first: ID
    /// もう一方のプレイヤー ID。
    public let second: ID

    public init(_ first: ID, _ second: ID) {
        self.first = first
        self.second = second
    }

    /// 指定した ID がこの固定ペアに含まれるか。
    public func contains(_ id: ID) -> Bool {
        first == id || second == id
    }

    /// 指定した ID の相方を返す（含まれない場合は `nil`）。
    public func partner(of id: ID) -> ID? {
        if first == id { return second }
        if second == id { return first }
        return nil
    }

    /// 2 人を集合として返す。
    public var ids: Set<ID> { [first, second] }
}
