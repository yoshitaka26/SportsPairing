//
//  SportsPairing.swift
//  SportsPairing
//
//  ダブルス（2 対 2）競技向けの汎用マッチメイク・ライブラリ。
//

/// SportsPairing ライブラリの名前空間とメタ情報。
///
/// このライブラリは、パデル・テニス・バドミントンなどの **ダブルス（2 対 2）** 競技で
/// 「次に誰と誰を組ませ、どのコートで対戦させるか」を自動で決めるための
/// マッチメイク・エンジンを提供する。
///
/// 設計の中心は **標準化された重み (``MatchmakingWeights``)** であり、
/// 以下の観点を一つのコスト関数に統合してチューニングできる。
///
/// - 出場回数の公平性（ハード制約・``MatchmakingOptions/Fairness``）
/// - 味方ペアの重複回避（``MatchmakingWeights/partnerRepeat``）
/// - 対戦相手の重複回避（``MatchmakingWeights/opponentRepeat``）
/// - チーム間のスキル均衡（``MatchmakingWeights/skillBalance``）
/// - 希望サイド（ドライブ / バック）の尊重（``MatchmakingWeights/sidePreference``）
///
/// 使い方の概要:
///
/// ```swift
/// let players = [
///     Player(id: 1, name: "Alice", playCount: 0),
///     Player(id: 2, name: "Bob",   playCount: 0),
///     Player(id: 3, name: "Carol", playCount: 0),
///     Player(id: 4, name: "Dave",  playCount: 0),
/// ]
/// let matchmaker = Matchmaker<Int>()
/// let match = try matchmaker.makeMatch(from: players)
/// print(match.summary)   // "Alice / Bob  vs  Carol / Dave"
/// ```
public enum SportsPairing {
    /// ライブラリのセマンティックバージョン。
    public static let version = "0.2.0"
}
