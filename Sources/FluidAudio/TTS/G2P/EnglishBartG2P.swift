import Foundation

/// Public access to the English BART grapheme-to-phoneme model (the CoreML G2P that
/// KokoroAne's English frontend falls back to for out-of-vocabulary words), for callers
/// that run their own frontend and render only the words their lexicon lacks.
///
/// The word is passed as given — callers decide casing (KokoroAne's own frontend lowercases
/// first). Models load from the same cache as `KokoroAneManager` (`Models/kokoro`).
public enum EnglishBartG2P {
    /// Loads the encoder, decoder and vocabulary if needed; throws when they are unavailable.
    public static func prepare() async throws {
        try await G2PModel.shared.ensureModelsAvailable()
    }

    /// The word's phonemes (Misaki IPA), or `nil` when the model produces none.
    public static func phonemize(_ word: String) async throws -> String? {
        try await G2PModel.shared.phonemize(word: word)?.joined()
    }
}
