import Foundation

/// The 6-letter invite codes (no 0/O or 1/I, so they're easy to read out). Used by the real store and Mock mode,
/// so it must not live inside `#if DEBUG`.
enum InviteCodes {
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func generate() -> String {
        String((0..<6).map { _ in alphabet.randomElement() ?? "A" })
    }

    static func normalize(_ s: String) -> String {
        String(s.uppercased().filter { alphabet.contains($0) }.prefix(6))
    }
}
