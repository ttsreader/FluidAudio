import Foundation

/// Caller edits applied between stages of the KokoroAne chain, for front ends that shape
/// timing or intonation themselves (e.g. lengthening a word, reshaping a pitch contour).
/// Every hook is optional; a `nil` hook keeps the chain's own behaviour.
public struct KokoroAneEdits: Sendable {
    /// PostAlbert's per-token `duration` (frames, as predicted; finite) → the frame counts
    /// the Alignment stage expands by. Replaces the built-in rounding. Must return one count
    /// per token, each ≥ 1; the acoustic-frame cap is checked on the result.
    public var durations: (@Sendable ([Float]) throws -> [Int32])?

    /// Prosody's `F0` and `N` curves (flat, fp32) plus the aligned durations → the curves
    /// fed to Noise (F0) and Vocoder (F0 and N). Must return arrays of the same lengths.
    public var prosody: (@Sendable (_ f0: [Float], _ n: [Float], _ durations: [Int32]) throws -> (f0: [Float], n: [Float]))?

    public init(
        durations: (@Sendable ([Float]) throws -> [Int32])? = nil,
        prosody: (@Sendable (_ f0: [Float], _ n: [Float], _ durations: [Int32]) throws -> (f0: [Float], n: [Float]))? = nil
    ) {
        self.durations = durations
        self.prosody = prosody
    }
}

extension KokoroAneSynthesizer {

    /// PostAlbert durations → the frame counts to align: the caller's `durations` hook when
    /// set (validated), else the built-in rounding. Non-finite input throws either way.
    static func alignedDurations(from durFloats: [Float], edits: KokoroAneEdits?) throws -> [Int32] {
        guard let hook = edits?.durations else { return try predictedDurations(from: durFloats) }
        guard durFloats.allSatisfy({ $0.isFinite }) else {
            throw KokoroAneError.nonFiniteModelOutput(
                stage: KokoroAneStage.postAlbert.rawValue, output: "duration")
        }
        let out = try hook(durFloats)
        guard out.count == durFloats.count else {
            throw KokoroAneError.invalidEdit(
                "durations: \(out.count) counts for \(durFloats.count) tokens")
        }
        guard out.allSatisfy({ $0 >= 1 }) else {
            throw KokoroAneError.invalidEdit("durations: every token needs at least one frame")
        }
        return out
    }

    /// Prosody curves → the caller's `prosody` hook output (validated), or `nil` when no hook
    /// is set (the chain then feeds the model's own arrays through unchanged).
    static func editedCurves(
        f0: [Float], n: [Float], durations: [Int32], edits: KokoroAneEdits?
    ) throws -> (f0: [Float], n: [Float])? {
        guard let hook = edits?.prosody else { return nil }
        let out = try hook(f0, n, durations)
        guard out.f0.count == f0.count, out.n.count == n.count else {
            throw KokoroAneError.invalidEdit(
                "prosody: got F0 \(out.f0.count) / N \(out.n.count), expected \(f0.count) / \(n.count)")
        }
        return out
    }
}
