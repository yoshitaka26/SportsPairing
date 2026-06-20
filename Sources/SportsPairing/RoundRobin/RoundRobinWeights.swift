//
//  RoundRobinWeights.swift
//  SportsPairing
//

/// 総当たり表 (``RoundRobinGenerator``) の並び順を決める重み。
///
/// 生成器は、各試合に「優先度（小さいほど先に組まれる）」を付け、最も優先度の低い試合から
/// 順番にスケジュールへ並べていく。優先度は以下の重み付き和：
///
/// ```
/// 優先度 = Σ(各選手の出場回数) × playerBalance
///        + Σ(各チームの使用回数) × pairRepeat
///        + (この顔ぶれの登場回数) × groupRepeat
///        + (出場済みの偏りを散らす項)
/// ```
///
/// PadeLovers の `RandomNumberTableManager` で使われていた重み
/// （プレイヤー 15 / ペア 10 / グループ 10）を既定値として踏襲している。
public struct RoundRobinWeights: Sendable, Equatable {

    /// 出場回数の均等化の重み。大きいほど「全員の出場数を揃える」を優先。
    public var playerBalance: Int

    /// 同じチーム（ペア）の再登場を避ける重み。
    public var pairRepeat: Int

    /// 同じ顔ぶれ（同じ 4 人の組）の再登場を避ける重み。シングルスでは無視される。
    public var groupRepeat: Int

    public init(playerBalance: Int = 15, pairRepeat: Int = 10, groupRepeat: Int = 10) {
        self.playerBalance = playerBalance
        self.pairRepeat = pairRepeat
        self.groupRepeat = groupRepeat
    }

    /// PadeLovers 由来の既定値。
    public static let `default` = RoundRobinWeights()
}
