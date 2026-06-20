//
//  MatchFormat.swift
//  SportsPairing
//

/// 試合の形式（1 チーム何人か、サイドを使うか）。
///
/// さまざまな競技に対応するための設定。代表的な値はプリセットとして用意してある。
///
/// - シングルス（1 対 1）: テニス・卓球・バドミントンの個人戦など。
/// - ダブルス（2 対 2）: パデル・テニス・バドミントンのペア戦など。
///
/// `teamSize` を 3 以上にすることもできる（3 対 3 など）。その場合サイド（ドライブ / バック）は
/// 概念として持たないため `usesSides` は無視され、全員 ``Side/any`` として扱われる。
public struct MatchFormat: Sendable, Equatable {

    /// 1 チームあたりの人数。シングルスなら 1、ダブルスなら 2。
    public var teamSize: Int

    /// ドライブ / バックのようなサイド（ポジション）を割り当てるか。
    /// `teamSize == 2` のときのみ有効。
    public var usesSides: Bool

    public init(teamSize: Int, usesSides: Bool) {
        self.teamSize = max(teamSize, 1)
        self.usesSides = usesSides
    }

    /// 1 試合に必要な人数（= `teamSize * 2`）。
    public var playersPerMatch: Int { teamSize * 2 }

    /// サイドを実際に割り当てるか（`teamSize == 2 && usesSides` のときだけ true）。
    var assignsSides: Bool { teamSize == 2 && usesSides }

    // MARK: - プリセット

    /// シングルス（1 対 1）。サイドなし。
    public static let singles = MatchFormat(teamSize: 1, usesSides: false)

    /// ダブルス（2 対 2）。ドライブ / バックのサイドあり。
    public static let doubles = MatchFormat(teamSize: 2, usesSides: true)

    /// ダブルスだがサイドを区別しない（左右を固定しない競技向け）。
    public static let doublesNoSides = MatchFormat(teamSize: 2, usesSides: false)
}
