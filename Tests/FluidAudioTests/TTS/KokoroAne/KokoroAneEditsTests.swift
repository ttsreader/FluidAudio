import Foundation
import XCTest

@testable import FluidAudio

/// The edit hooks' contract (no models needed): no hook = the chain's own behaviour; a hook's
/// result is validated before it can reach a CoreML stage.
final class KokoroAneEditsTests: XCTestCase {

    func testNoHookKeepsTheBuiltInRounding() throws {
        let floats: [Float] = [0.2, 2.5, 7.9]
        XCTAssertEqual(
            try KokoroAneSynthesizer.alignedDurations(from: floats, edits: nil),
            try KokoroAneSynthesizer.predictedDurations(from: floats))
        XCTAssertEqual(
            try KokoroAneSynthesizer.alignedDurations(from: floats, edits: KokoroAneEdits(prosody: { f, n, _ in (f, n) })),
            try KokoroAneSynthesizer.predictedDurations(from: floats))
    }

    func testDurationHookReplacesTheRounding() throws {
        let edits = KokoroAneEdits(durations: { floats in floats.map { Int32(($0 * 2).rounded(.up)) } })
        XCTAssertEqual(try KokoroAneSynthesizer.alignedDurations(from: [1.0, 2.2], edits: edits), [2, 5])
    }

    func testDurationHookMustReturnOneCountPerToken() {
        let edits = KokoroAneEdits(durations: { _ in [1] })
        XCTAssertThrowsError(try KokoroAneSynthesizer.alignedDurations(from: [1, 2, 3], edits: edits)) { error in
            guard case KokoroAneError.invalidEdit = error else { return XCTFail("got \(error)") }
        }
    }

    func testDurationHookMustKeepEveryTokenAudible() {
        let edits = KokoroAneEdits(durations: { floats in floats.map { _ in 0 } })
        XCTAssertThrowsError(try KokoroAneSynthesizer.alignedDurations(from: [1, 2], edits: edits))
    }

    func testNonFiniteDurationsThrowBeforeTheHookRuns() {
        let edits = KokoroAneEdits(durations: { _ in XCTFail("hook must not run"); return [] })
        XCTAssertThrowsError(try KokoroAneSynthesizer.alignedDurations(from: [1, .nan], edits: edits)) { error in
            guard case KokoroAneError.nonFiniteModelOutput = error else { return XCTFail("got \(error)") }
        }
    }

    func testProsodyHookIsAppliedAndValidated() throws {
        XCTAssertNil(try KokoroAneSynthesizer.editedCurves(f0: [1], n: [2], durations: [1], edits: nil))
        let raise = KokoroAneEdits(prosody: { f, n, d in
            XCTAssertEqual(d, [3])
            return (f.map { $0 * 2 }, n)
        })
        let out = try XCTUnwrap(try KokoroAneSynthesizer.editedCurves(f0: [100, 110], n: [1, 1], durations: [3], edits: raise))
        XCTAssertEqual(out.f0, [200, 220])
        XCTAssertEqual(out.n, [1, 1])
        let short = KokoroAneEdits(prosody: { f, n, _ in (Array(f.dropLast()), n) })
        XCTAssertThrowsError(try KokoroAneSynthesizer.editedCurves(f0: [1, 2], n: [1, 2], durations: [1], edits: short))
    }
}
