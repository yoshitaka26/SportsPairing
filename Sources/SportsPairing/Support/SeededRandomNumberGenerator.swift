//
//  SeededRandomNumberGenerator.swift
//  SportsPairing
//

/// シード（種）を指定できる決定論的な乱数生成器。
///
/// マッチメイクは候補がコスト的に同点（タイ）のときランダムに 1 つを選ぶため、
/// 結果は乱数に依存する。テストで結果を再現したい場合や、アプリ側で
/// 「同じ操作なら同じ組み合わせ」を保証したい場合にこの生成器を使う。
///
/// アルゴリズムは SplitMix64。高速で素性が良く、シード再現性を持つ。
///
/// ```swift
/// var rng = SeededRandomNumberGenerator(seed: 42)
/// let match = try matchmaker.makeMatch(from: players, using: &rng)
/// ```
public struct SeededRandomNumberGenerator: RandomNumberGenerator {

    private var state: UInt64

    /// 指定したシードで初期化する。同じシードなら必ず同じ乱数列になる。
    public init(seed: UInt64) {
        // シード 0 でも縮退しないようにオフセットを加える。
        self.state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
