import Foundation

/// Decodes the embedded content JSON once at launch. Content ships inside the
/// binary (Data/*.swift raw strings) so the app has no resource-bundle
/// dependencies in either the SwiftPM or Xcode build.
public final class ContentStore {
    public let words: [VocabWord]
    public let readingGuide: [GuideSection]
    public let overview: [GuideSection]
    public let mathStrands: [MathStrand]
    public let passages: [Passage]
    public let practiceSections: [PracticeSection]
    public let books: [SourceBook]
    public let analogies: AnalogyModule

    public static let shared = ContentStore()

    public init() {
        let decoder = JSONDecoder()

        struct WordsFile: Codable { let words: [VocabWord] }
        struct SectionsFile: Codable { let sections: [GuideSection] }
        struct StrandsFile: Codable { let strands: [MathStrand] }
        struct PassagesFile: Codable { let passages: [Passage] }
        struct PracticeFile: Codable { let sections: [PracticeSection] }
        struct BooksFile: Codable { let books: [SourceBook] }

        func decode<T: Decodable>(_ type: T.Type, _ json: String, _ name: String) -> T? {
            do {
                return try decoder.decode(T.self, from: Data(json.utf8))
            } catch {
                assertionFailure("Embedded \(name) JSON failed to decode: \(error)")
                return nil
            }
        }

        words = decode(WordsFile.self, EmbeddedData.wordsJSON, "words")?.words ?? []
        readingGuide = decode(SectionsFile.self, EmbeddedData.readingGuideJSON, "reading guide")?.sections ?? []
        overview = decode(SectionsFile.self, EmbeddedData.overviewJSON, "overview")?.sections ?? []
        mathStrands = decode(StrandsFile.self, EmbeddedData.mathJSON, "math")?.strands ?? []
        passages = decode(PassagesFile.self, EmbeddedData.passagesJSON, "passages")?.passages ?? []
        practiceSections = decode(PracticeFile.self, EmbeddedData.practiceSectionsJSON, "practice sections")?.sections ?? []
        books = decode(BooksFile.self, EmbeddedData.booksJSON, "books")?.books ?? []
        analogies = decode(AnalogyModule.self, EmbeddedData.analogiesJSON, "analogies")
            ?? (try! decoder.decode(AnalogyModule.self, from: Data(#"{"bridges":[],"howTo":[],"practice":[]}"#.utf8)))
    }

    public var notebookWords: [VocabWord] { words.filter { $0.source == .notebook } }
    public var supplementWords: [VocabWord] { words.filter { $0.source == .supplement } }
}
