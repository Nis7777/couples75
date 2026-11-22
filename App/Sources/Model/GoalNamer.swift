import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Turns a typed personal goal into a clean, short rule name: "Learn to speak chinese" → "Learn Chinese".
/// Uses Apple's on-device Foundation Models when available (iOS 26+), otherwise keyword rules and
/// capitalisation. Never puts other apps' brand names in a title. Never calls an online service.
enum GoalNamer {
    static let maxNameLength = 26

    static func name(for text: String) async -> String {
        let fallback = keywordName(text)
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), let generated = await OnDeviceNamer.name(for: text) {
            let clean = sanitize(generated)
            if !clean.isEmpty { return clean }
        }
        #endif
        return fallback
    }

    static let languages = ["chinese", "mandarin", "cantonese", "spanish", "french", "german", "italian",
                            "portuguese", "japanese", "korean", "arabic", "russian", "hindi", "dutch", "greek",
                            "turkish", "swedish", "norwegian", "danish", "finnish", "polish", "english", "hebrew",
                            "vietnamese", "thai", "indonesian", "ukrainian", "czech", "romanian", "hungarian",
                            "catalan", "latin", "sign language"]
    static let instruments = ["guitar", "piano", "violin", "drums", "ukulele", "cello", "bass", "saxophone",
                              "flute", "trumpet", "harp", "keyboard", "clarinet"]
    /// Other apps' and companies' names: never in a rule title.
    static let brands = ["duolingo", "babbel", "rosetta stone", "busuu", "memrise", "headspace", "calm app",
                         "strava", "peloton", "instagram", "insta", "tiktok", "youtube", "netflix", "spotify",
                         "facebook", "snapchat", "twitter", "reddit", "kindle", "audible", "myfitnesspal",
                         "nike run club", "nike training club", "apple fitness", "chatgpt", "whatsapp",
                         "pinterest", "linkedin", "twitch", "hinge", "tinder", "simply piano", "yousician",
                         "masterclass", "coursera", "udemy", "khan academy", "brilliant", "chess.com", "lichess"]

    static func keywordName(_ text: String) -> String {
        var t = " " + text.lowercased()
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " .!?,;:\"'")) + " "
        t = removeBrands(t)
        for lang in languages where t.contains(" \(lang)") {
            return "Learn \(capitalised(lang))"
        }
        for inst in instruments where t.contains(" \(inst)") {
            return "Practise \(inst)"
        }
        let fillers = ["i want to ", "i'd like to ", "i would like to ", "want to ", "try to ", "trying to ",
                       "start to ", "get better at ", "be better at ", "improve my ", "work on ", "more "]
        var core = t.trimmingCharacters(in: .whitespaces)
        var changed = true
        while changed {
            changed = false
            for f in fillers where core.hasPrefix(f) {
                core = String(core.dropFirst(f.count))
                changed = true
            }
        }
        return sanitize(core)
    }

    /// Strips brands, quotes and trailing punctuation, capitalises the first word (and proper nouns),
    /// and keeps it short (whole words only).
    static func sanitize(_ raw: String) -> String {
        var t = " " + raw.lowercased()
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "“", with: "")
            .replacingOccurrences(of: "”", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: " .!?,;:'")) + " "
        t = removeBrands(t)
        let words = t.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return "" }
        var out: [String] = []
        for (i, w) in words.enumerated() {
            var word = w
            if languages.contains(word) || word == "i" { word = capitalised(word) }
            if i == 0 { word = capitalised(word) }
            let candidate = (out + [word]).joined(separator: " ")
            if candidate.count > maxNameLength { break }
            out.append(word)
        }
        if out.isEmpty { out = [String(capitalised(words[0]).prefix(maxNameLength))] }
        // Don't end on a dangling small word ("Learn to").
        while out.count > 1, let last = out.last, ["to", "a", "an", "the", "and", "of", "on", "for", "with", "my"].contains(last) {
            out.removeLast()
        }
        return out.joined(separator: " ")
    }

    static func removeBrands(_ text: String) -> String {
        var t = text
        for b in brands {
            for prep in ["on ", "with ", "using ", "via ", "in ", "through ", ""] {
                // Whole words only: `t` is padded with spaces at both ends.
                t = t.replacingOccurrences(of: " \(prep)\(b) ", with: " ")
            }
        }
        while t.contains("  ") { t = t.replacingOccurrences(of: "  ", with: " ") }
        return t
    }

    private static func capitalised(_ w: String) -> String {
        guard let f = w.first else { return w }
        return f.uppercased() + w.dropFirst()
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
private enum OnDeviceNamer {
    static func name(for text: String) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let prompt = """
        Turn this personal goal into a short daily habit name of at most 3 words, for example \
        "Learn to speak chinese" → "Learn Chinese", "get better at drawing" → "Practise drawing". \
        Sentence case, proper nouns capitalised. No app, company or brand names. No times or amounts. \
        Reply with only the name.
        Goal: "\(text)"
        """
        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            let line = response.content.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
            return line.isEmpty ? nil : line
        } catch {
            return nil
        }
    }
}
#endif
