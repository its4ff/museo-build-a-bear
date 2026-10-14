import Foundation

/// Decodes one element of an array, or nil instead of failing the whole array.
///
/// ```swift
/// let rows = try JSONDecoder().decode([Lossy<Muse>].self, from: data)
/// let muses = rows.compactMap(\.value)      // one bad row never hides the rest
/// ```
nonisolated struct Lossy<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}
