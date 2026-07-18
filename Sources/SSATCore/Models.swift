import Foundation

// MARK: - Vocabulary

public enum WordSource: String, Codable {
    case notebook
    case supplement
}

public struct VocabWord: Codable, Identifiable, Hashable {
    public var id: String { word }
    public let word: String
    public let pos: String
    public let definition: String
    public let synonyms: [String]
    public let mnemonic: String
    public let root: String
    public let example: String
    public let yourNote: String
    public let source: WordSource
    public let difficulty: Int

    public init(word: String, pos: String, definition: String, synonyms: [String],
                mnemonic: String, root: String, example: String, yourNote: String,
                source: WordSource, difficulty: Int) {
        self.word = word
        self.pos = pos
        self.definition = definition
        self.synonyms = synonyms
        self.mnemonic = mnemonic
        self.root = root
        self.example = example
        self.yourNote = yourNote
        self.source = source
        self.difficulty = difficulty
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        word = try c.decode(String.self, forKey: .word)
        pos = try c.decodeIfPresent(String.self, forKey: .pos) ?? ""
        definition = try c.decodeIfPresent(String.self, forKey: .definition) ?? ""
        synonyms = try c.decodeIfPresent([String].self, forKey: .synonyms) ?? []
        mnemonic = try c.decodeIfPresent(String.self, forKey: .mnemonic) ?? ""
        root = try c.decodeIfPresent(String.self, forKey: .root) ?? ""
        example = try c.decodeIfPresent(String.self, forKey: .example) ?? ""
        yourNote = try c.decodeIfPresent(String.self, forKey: .yourNote) ?? ""
        source = try c.decodeIfPresent(WordSource.self, forKey: .source) ?? .supplement
        difficulty = try c.decodeIfPresent(Int.self, forKey: .difficulty) ?? 2
    }
}

// MARK: - Guides (shared by Reading guide + Test overview)

public struct GuideBlock: Codable, Hashable {
    public let heading: String
    public let body: String
    public let bullets: [String]

    public init(heading: String, body: String, bullets: [String]) {
        self.heading = heading
        self.body = body
        self.bullets = bullets
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        heading = try c.decodeIfPresent(String.self, forKey: .heading) ?? ""
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        bullets = try c.decodeIfPresent([String].self, forKey: .bullets) ?? []
    }
}

public struct GuideSection: Codable, Identifiable, Hashable {
    public var id: String { title }
    public let title: String
    public let icon: String
    public let blocks: [GuideBlock]

    public init(title: String, icon: String, blocks: [GuideBlock]) {
        self.title = title
        self.icon = icon
        self.blocks = blocks
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "book"
        blocks = try c.decodeIfPresent([GuideBlock].self, forKey: .blocks) ?? []
    }
}

// MARK: - Math

public struct WorkedExample: Codable, Hashable {
    public let problem: String
    public let solution: String
}

public struct PracticeProblem: Codable, Hashable {
    public let problem: String
    public let choices: [String]
    public let answer: String
    public let solution: String

    public init(problem: String, choices: [String], answer: String, solution: String) {
        self.problem = problem
        self.choices = choices
        self.answer = answer
        self.solution = solution
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        problem = try c.decode(String.self, forKey: .problem)
        choices = try c.decodeIfPresent([String].self, forKey: .choices) ?? []
        answer = try c.decodeIfPresent(String.self, forKey: .answer) ?? ""
        solution = try c.decodeIfPresent(String.self, forKey: .solution) ?? ""
    }

    /// Index of the correct choice, derived from the answer letter ("B" or "B) 12").
    public var answerIndex: Int? {
        guard let letter = answer.trimmingCharacters(in: .whitespaces).first?.uppercased().first,
              let ascii = letter.asciiValue, ascii >= 65, ascii <= 69 else { return nil }
        let idx = Int(ascii - 65)
        return idx < choices.count ? idx : nil
    }
}

public struct MathTopic: Codable, Identifiable, Hashable {
    public var id: String { title }
    public let title: String
    public let keyPoints: [String]
    public let formulas: [String]
    public let examples: [WorkedExample]
    public let traps: [String]
    public let practice: [PracticeProblem]

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        keyPoints = try c.decodeIfPresent([String].self, forKey: .keyPoints) ?? []
        formulas = try c.decodeIfPresent([String].self, forKey: .formulas) ?? []
        examples = try c.decodeIfPresent([WorkedExample].self, forKey: .examples) ?? []
        traps = try c.decodeIfPresent([String].self, forKey: .traps) ?? []
        practice = try c.decodeIfPresent([PracticeProblem].self, forKey: .practice) ?? []
    }
}

public struct MathStrand: Codable, Identifiable, Hashable {
    public var id: String { strand }
    public let strand: String
    public let topics: [MathTopic]
}

// MARK: - Reading passages

public struct PassageQuestion: Codable, Hashable {
    public let prompt: String
    public let choices: [String]
    public let answerIndex: Int
    public let type: String
    public let explanation: String

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        prompt = try c.decode(String.self, forKey: .prompt)
        choices = try c.decodeIfPresent([String].self, forKey: .choices) ?? []
        answerIndex = try c.decodeIfPresent(Int.self, forKey: .answerIndex) ?? 0
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        explanation = try c.decodeIfPresent(String.self, forKey: .explanation) ?? ""
    }
}

public struct Passage: Codable, Identifiable, Hashable {
    public var id: String { title }
    public let title: String
    public let genre: String
    public let attribution: String
    public let context: String
    public let text: String
    public let questions: [PassageQuestion]

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        genre = try c.decodeIfPresent(String.self, forKey: .genre) ?? ""
        attribution = try c.decodeIfPresent(String.self, forKey: .attribution) ?? ""
        context = try c.decodeIfPresent(String.self, forKey: .context) ?? ""
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        questions = try c.decodeIfPresent([PassageQuestion].self, forKey: .questions) ?? []
    }
}

// MARK: - Source books

public struct SourceBook: Codable, Identifiable, Hashable {
    public var id: String { title }
    public let title: String
    public let author: String
    public let year: Int
    public let genre: String
    public let overview: String
    public let ssatNote: String
    public let synopsis: String
    public let difficulty: Int

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        author = try c.decodeIfPresent(String.self, forKey: .author) ?? ""
        year = try c.decodeIfPresent(Int.self, forKey: .year) ?? 0
        genre = try c.decodeIfPresent(String.self, forKey: .genre) ?? ""
        overview = try c.decodeIfPresent(String.self, forKey: .overview) ?? ""
        ssatNote = try c.decodeIfPresent(String.self, forKey: .ssatNote) ?? ""
        synopsis = try c.decodeIfPresent(String.self, forKey: .synopsis) ?? ""
        difficulty = try c.decodeIfPresent(Int.self, forKey: .difficulty) ?? 2
    }
}

// MARK: - Timed practice sections

public struct PracticeSection: Codable, Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let minutes: Int
    public let passages: [Passage]

    public var questionCount: Int { passages.reduce(0) { $0 + $1.questions.count } }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        minutes = try c.decodeIfPresent(Int.self, forKey: .minutes) ?? 40
        passages = try c.decodeIfPresent([Passage].self, forKey: .passages) ?? []
    }
}

// MARK: - Analogies

public struct AnalogyBridge: Codable, Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let pattern: String
    public let example: String
    public let tip: String
}

public struct AnalogyHowTo: Codable, Hashable {
    public let heading: String
    public let body: String
}

public struct AnalogyQuestion: Codable, Hashable {
    public let stem: String
    public let choices: [String]
    public let answerIndex: Int
    public let bridge: String
    public let explanation: String
}

public struct AnalogyModule: Codable {
    public let bridges: [AnalogyBridge]
    public let howTo: [AnalogyHowTo]
    public let practice: [AnalogyQuestion]

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bridges = try c.decodeIfPresent([AnalogyBridge].self, forKey: .bridges) ?? []
        howTo = try c.decodeIfPresent([AnalogyHowTo].self, forKey: .howTo) ?? []
        practice = try c.decodeIfPresent([AnalogyQuestion].self, forKey: .practice) ?? []
    }
}
