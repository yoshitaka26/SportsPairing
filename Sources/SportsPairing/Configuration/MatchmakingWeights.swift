//
//  MatchmakingWeights.swift
//  SportsPairing
//

/// マッチメイクの良し悪しを決める **標準化された重み**。
///
/// エンジンは候補となる組み合わせごとに「コスト（小さいほど良い）」を計算し、
/// 最小コストの組み合わせを選ぶ。各コスト項目は内部で **おおむね 0〜1 に正規化** されているため、
/// ここで指定する重みは「項目どうしの相対的な重要度」を表すと考えればよい。
///
/// たとえば `partnerRepeat` を大きくすると「同じ人と何度も組ませない」ことを強く優先し、
/// `skillBalance` を大きくすると「両チームの実力を揃える」ことを優先する。
///
/// > 出場回数の公平性は重みではなく **ハード制約** として扱われる
/// > （``MatchmakingOptions/fairness`` を参照）。これは PadeLovers の
/// > 「出場回数が最小の人から選ぶ」挙動を踏襲したもので、重みで緩めるべきでない最重要要件のため。
public struct MatchmakingWeights: Sendable, Equatable {

    /// 味方ペアの重複を避ける重み。大きいほど「同じ相手と組ませない」を優先。
    public var partnerRepeat: Double

    /// 対戦相手の重複を避ける重み。大きいほど「同じ相手と当てない」を優先。
    public var opponentRepeat: Double

    /// チーム間のスキル均衡をとる重み。大きいほど「実力を揃える」を優先。
    /// プレイヤーの ``Player/skill`` が `nil` の場合この項目は無視される。
    public var skillBalance: Double

    /// 希望サイド（ドライブ / バック）の尊重をとる重み。大きいほど希望どおりに配置する。
    public var sidePreference: Double

    public init(
        partnerRepeat: Double = 1.0,
        opponentRepeat: Double = 0.5,
        skillBalance: Double = 0.5,
        sidePreference: Double = 0.3
    ) {
        self.partnerRepeat = partnerRepeat
        self.opponentRepeat = opponentRepeat
        self.skillBalance = skillBalance
        self.sidePreference = sidePreference
    }

    // MARK: - プリセット

    /// 既定。重複回避を主軸に、スキル均衡とサイド希望も適度に考慮する汎用バランス。
    /// PadeLovers の通常モードに最も近い挙動。
    public static let balanced = MatchmakingWeights()

    /// 「同じ顔ぶれにならない」ことを最優先するプリセット。
    /// たくさんの相手と当たりたい交流会・乱取り向け。
    public static let maximizeVariety = MatchmakingWeights(
        partnerRepeat: 1.0,
        opponentRepeat: 1.0,
        skillBalance: 0.1,
        sidePreference: 0.2
    )

    /// 接戦になるよう、チームの実力均衡を最優先するプリセット。
    /// 実力差のあるメンバーで競った試合を作りたいとき向け。
    public static let competitiveBalance = MatchmakingWeights(
        partnerRepeat: 0.4,
        opponentRepeat: 0.3,
        skillBalance: 1.0,
        sidePreference: 0.3
    )
}
