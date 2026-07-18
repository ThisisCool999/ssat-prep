import Foundation

public struct SynonymQuestion: Identifiable, Hashable {
    public let id = UUID()
    public let word: VocabWord
    public let choices: [String]
    public let answerIndex: Int
}

/// Generates SSAT-style synonym questions: a headword and five choices, one of
/// which is a real synonym; distractors are synonyms of *other* words that do
/// not also fit the target.
public enum QuizEngine {
    public static func makeQuestions(from pool: [VocabWord],
                                     count: Int,
                                     using rng: inout some RandomNumberGenerator) -> [SynonymQuestion] {
        let eligible = pool.filter { !$0.synonyms.isEmpty }
        guard eligible.count >= 6 else { return [] }
        let targets = eligible.shuffled(using: &rng).prefix(count)
        return targets.compactMap { makeQuestion(for: $0, pool: eligible, using: &rng) }
    }

    /// Builds one question per target word (targets may repeat), pulling
    /// distractors from `distractorPool`.
    public static func makeQuestions(targets: [VocabWord],
                                     distractorPool: [VocabWord],
                                     using rng: inout some RandomNumberGenerator) -> [SynonymQuestion] {
        let pool = distractorPool.filter { !$0.synonyms.isEmpty }
        guard pool.count >= 6 else { return [] }
        return targets.compactMap { makeQuestion(for: $0, pool: pool, using: &rng) }
    }

    public static func makeQuestion(for word: VocabWord,
                                    pool: [VocabWord],
                                    using rng: inout some RandomNumberGenerator) -> SynonymQuestion? {
        guard let correct = word.synonyms.shuffled(using: &rng).first else { return nil }

        // Anything synonymous with the target is off-limits as a distractor.
        var forbidden = Set(word.synonyms.map { $0.lowercased() })
        forbidden.insert(word.word.lowercased())
        forbidden.insert(correct.lowercased())

        var distractors: [String] = []
        var seen = Set<String>()
        let samePos = pool.filter { $0.word != word.word && $0.pos == word.pos }
        let others = pool.filter { $0.word != word.word && $0.pos != word.pos }
        for candidate in (samePos.shuffled(using: &rng) + others.shuffled(using: &rng)) {
            guard distractors.count < 4 else { break }
            guard let syn = candidate.synonyms.shuffled(using: &rng).first else { continue }
            let key = syn.lowercased()
            if forbidden.contains(key) || seen.contains(key) { continue }
            seen.insert(key)
            distractors.append(syn)
        }
        guard distractors.count == 4 else { return nil }

        var choices = distractors
        let answerIndex = Int.random(in: 0...4, using: &rng)
        choices.insert(correct, at: answerIndex)
        return SynonymQuestion(word: word, choices: choices, answerIndex: answerIndex)
    }
}
