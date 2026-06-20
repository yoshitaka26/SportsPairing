//
//  MatchmakingOptions.swift
//  SportsPairing
//

/// マッチメイクの制約・前提を指定するオプション。
///
/// 重み (``MatchmakingWeights``) が「組み合わせの好み」を表すのに対し、
/// こちらは「守るべき制約」や「正規化の前提」を表す。
public struct MatchmakingOptions<ID: Hashable & Sendable>: Sendable {

    /// 出場回数の公平性をどこまで厳密に守るか。
    public enum Fairness: Sendable, Equatable {
        /// 出場回数が少ないプレイヤーを厳密に優先する（既定）。
        ///
        /// 出場回数の多いプレイヤーが、より少ないプレイヤーを飛ばして選ばれることはない。
        /// PadeLovers の「出場回数が最小の人から選ぶ」挙動と同じ公平性保証。
        case strict
        /// 公平性を無視し、重複回避とスキル均衡のみで選ぶ。
        ///
        /// 全員が毎回参加する固定メンバー戦など、出場回数の偏りを気にしない場合に使う。
        case off
    }

    /// 試合形式（シングルス / ダブルスなど）。既定は ``MatchFormat/doubles``。
    public var format: MatchFormat

    /// 公平性モード。既定は ``Fairness/strict``。
    public var fairness: Fairness

    /// 固定ペア（必ず味方で組ませる 2 人組）の一覧。`teamSize < 2` の形式では無視される。
    public var fixedPairs: [FixedPair<ID>]

    /// スキル差の正規化に使うスキルの想定レンジ幅。
    ///
    /// 例: スキルを 1〜10 で運用しているなら `9`（= 10 − 1）。
    /// チーム平均スキル差をこの値で割って 0〜1 に正規化する。
    public var skillRange: Double

    public init(
        format: MatchFormat = .doubles,
        fairness: Fairness = .strict,
        fixedPairs: [FixedPair<ID>] = [],
        skillRange: Double = 10
    ) {
        self.format = format
        self.fairness = fairness
        self.fixedPairs = fixedPairs
        self.skillRange = max(skillRange, 1)   // 0 除算を避ける
    }
}
