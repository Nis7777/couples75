import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Rule ideas for "Something else?" (Part 8).
///
/// On iOS 26+ with Apple Intelligence available, Apple's on-device Foundation Models write 3 ideas.
/// Otherwise (and if the model fails) a keyword match against the curated library is used.
/// Nothing ever leaves the device: no online AI service is called.
enum RuleIdeas {
    /// Curated rules matching a few common words, then generic ideas built from the text itself.
    static func keywordIdeas(for text: String, intensity: Intensity) -> [RuleIdea] {
        let t = text.lowercased()
        let table: [(words: [String], key: String)] = [
            (["language", "spanish", "french", "german", "italian", "portuguese", "japanese", "chinese",
              "korean", "english", "duolingo", "vocab"], "language"),
            (["guitar", "piano", "violin", "drum", "instrument", "ukulele", "sing", "music"], "instrument"),
            (["meditat", "mindful", "breath", "calm"], "meditate"),
            (["save", "money", "spend", "budget", "takeaway", "delivery"], "noTakeaway"),
            (["social", "instagram", "tiktok", "scroll", "screen", "youtube"], "lessSocial"),
            (["cook", "meal", "recipe", "kitchen"], "cookAtHome"),
            (["journal", "diary", "write", "writing", "gratitude"], "journal"),
            (["stretch", "yoga", "mobility", "flexib"], "stretch"),
            (["study", "exam", "course", "learn", "homework", "revise"], "study"),
            (["read", "book", "pages"], "reading"),
            (["run", "gym", "workout", "train", "lift", "fit", "swim", "bike", "cycle"], "workout"),
            (["walk", "steps"], "steps"),
            (["water", "hydrat", "drink more"], "water"),
            (["sugar", "sweets", "candy", "chocolate"], "noSugar"),
            (["alcohol", "drink", "beer", "wine"], "noAlcohol"),
            (["sleep", "bed", "early"], "bedtime"),
            (["junk", "fast food", "snack"], "noJunk"),
        ]
        var ideas: [RuleIdea] = []
        for row in table where row.words.contains(where: { t.contains($0) }) {
            if let idea = RuleIdea.library(row.key, intensity: intensity), !ideas.contains(idea) { ideas.append(idea) }
            if ideas.count == 2 { break }
        }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            let name = GoalNamer.keywordName(clean)
            let minutes = intensity == .gentle ? 10 : intensity == .hard ? 30 : 15
            let generic = [
                RuleIdea(title: "\(name): \(minutes) min", type: .photo, libraryKey: nil,
                         photoHint: "Photo that shows you did it today."),
                RuleIdea(title: name, type: .honour, libraryKey: nil, photoHint: nil),
            ]
            for g in generic where ideas.count < 3 && !ideas.contains(g) { ideas.append(g) }
        }
        return Array(ideas.prefix(3))
    }

    /// 3 ideas for the free text: on-device model when available, else the keyword match.
    static func ideas(for text: String, intensity: Intensity) async -> [RuleIdea] {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return [] }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if let ideas = await OnDeviceIdeas.generate(for: clean), !ideas.isEmpty { return ideas }
        }
        #endif
        return keywordIdeas(for: clean, intensity: intensity)
    }

    /// Parses lines like "PHOTO | 15 min guitar practice | Photo of your guitar".
    static func parse(_ output: String) -> [RuleIdea] {
        var ideas: [RuleIdea] = []
        for line in output.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\"*"))) }
            guard parts.count >= 2 else { continue }
            // Drop list numbering or bullets in front of the kind ("1. PHOTO", "- HONOUR").
            let kind = parts[0].trimmingCharacters(in: CharacterSet(charactersIn: " -*•0123456789.)")).uppercased()
            guard kind == "PHOTO" || kind == "HONOUR" || kind == "HONOR" else { continue }
            let title = String(parts[1].prefix(RuleLibrary.customTitleMaxLength))
            guard !title.isEmpty else { continue }
            // Never another app's brand name in a rule title.
            let padded = " " + title.lowercased() + " "
            guard GoalNamer.removeBrands(padded) == padded else { continue }
            let type: RuleType = kind == "PHOTO" ? .photo : .honour
            let hint = parts.count > 2 && type == .photo ? String(parts[2].prefix(80)) : nil
            let idea = RuleIdea(title: title, type: type, libraryKey: nil, photoHint: hint)
            if !ideas.contains(idea) { ideas.append(idea) }
            if ideas.count == 3 { break }
        }
        return ideas
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
private enum OnDeviceIdeas {
    static func generate(for text: String) async -> [RuleIdea]? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let instructions = """
        You suggest daily habits for a couple leveling up together: body, looks, mind and money. \
        Each rule must be something one person can do every single day and prove. \
        Use the short format "Name: amount", like "Guitar: 15 min". \
        Never suggest anything about bodies, weight or intimacy. Never use app, company or brand names.
        """
        let prompt = """
        Someone wants to work on: "\(text)".
        Write exactly 3 daily rules, one per line, in this format:
        PHOTO | rule title (max 40 characters) | what to photograph as proof
        or
        HONOUR | rule title (max 40 characters)
        Use PHOTO when a photo can prove it, HONOUR otherwise. No other text.
        """
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            return RuleIdeas.parse(response.content)
        } catch {
            return nil
        }
    }
}
#endif
