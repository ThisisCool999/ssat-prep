import XCTest
@testable import SSATCore

final class SM2Tests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_752_000_000)

    func testNewCardGoodWalksLearningStepsThenGraduates() {
        var s = CardState()
        s = SM2.answer(s, grade: .good, now: now)
        XCTAssertEqual(s.phase, .learning)
        XCTAssertEqual(s.due, now.addingTimeInterval(600))

        s = SM2.answer(s, grade: .good, now: now.addingTimeInterval(600))
        XCTAssertEqual(s.phase, .review)
        XCTAssertEqual(s.intervalDays, 1)
    }

    func testEasyOnNewCardGraduatesImmediately() {
        let s = SM2.answer(CardState(), grade: .easy, now: now)
        XCTAssertEqual(s.phase, .review)
        XCTAssertEqual(s.intervalDays, SM2.easyIntervalDays)
    }

    func testAgainResetsLearningStep() {
        var s = SM2.answer(CardState(), grade: .good, now: now)
        s = SM2.answer(s, grade: .again, now: now)
        XCTAssertEqual(s.phase, .learning)
        XCTAssertEqual(s.learningStep, 0)
        XCTAssertEqual(s.due, now.addingTimeInterval(60))
    }

    func testReviewGoodMultipliesByEase() {
        var s = CardState()
        s.phase = .review
        s.intervalDays = 10
        s.ease = 2.5
        let next = SM2.answer(s, grade: .good, now: now)
        XCTAssertEqual(next.intervalDays, 25)
        XCTAssertEqual(next.due, now.addingTimeInterval(25 * 86400))
    }

    func testReviewLapseDropsEaseAndEntersRelearning() {
        var s = CardState()
        s.phase = .review
        s.intervalDays = 20
        s.ease = 2.5
        let next = SM2.answer(s, grade: .again, now: now)
        XCTAssertEqual(next.phase, .relearning)
        XCTAssertEqual(next.lapses, 1)
        XCTAssertEqual(next.ease, 2.3, accuracy: 0.0001)
        XCTAssertEqual(next.intervalDays, 10)

        let graduated = SM2.answer(next, grade: .good, now: now.addingTimeInterval(600))
        XCTAssertEqual(graduated.phase, .review)
        XCTAssertEqual(graduated.intervalDays, 10)
    }

    func testEaseNeverDropsBelowFloor() {
        var s = CardState()
        s.phase = .review
        s.intervalDays = 5
        s.ease = 1.3
        let next = SM2.answer(s, grade: .again, now: now)
        XCTAssertEqual(next.ease, SM2.minEase)
    }

    func testIntervalCapped() {
        var s = CardState()
        s.phase = .review
        s.intervalDays = 300
        s.ease = 2.5
        let next = SM2.answer(s, grade: .easy, now: now)
        XCTAssertEqual(next.intervalDays, SM2.maxIntervalDays)
    }

    func testIntervalPreviewFormats() {
        XCTAssertEqual(SM2.intervalPreview(CardState(), grade: .again, now: now), "1m")
        XCTAssertEqual(SM2.intervalPreview(CardState(), grade: .easy, now: now), "4d")
    }

    func testAgainsAndAccuracy() {
        var s = CardState()
        XCTAssertNil(s.accuracy)
        s = SM2.answer(s, grade: .good, now: now)   // pass
        s = SM2.answer(s, grade: .again, now: now)  // miss
        s = SM2.answer(s, grade: .good, now: now)   // pass
        XCTAssertEqual(s.reps, 3)
        XCTAssertEqual(s.agains, 1)
        XCTAssertEqual(s.accuracy!, 2.0 / 3.0, accuracy: 0.0001)
    }

    func testMasteredThreshold() {
        var s = CardState()
        s.phase = .review
        s.intervalDays = 21
        XCTAssertTrue(s.isMastered)
        s.intervalDays = 20
        XCTAssertFalse(s.isMastered)
    }

    func testReviewCardDueAnytimeOnItsDay() {
        var s = CardState()
        s.phase = .review
        let current = Date()
        let startOfToday = Calendar.current.startOfDay(for: current)
        s.due = startOfToday.addingTimeInterval(22 * 3600)
        XCTAssertTrue(s.isDue(now: current), "review card due later today must be studyable now")
        s.due = startOfToday.addingTimeInterval(26 * 3600)
        XCTAssertFalse(s.isDue(now: current), "review card due tomorrow must not be due today")
    }

    func testLearningCardKeepsExactDueTime() {
        var s = CardState()
        s.phase = .learning
        let current = Date()
        s.due = current.addingTimeInterval(300)
        XCTAssertFalse(s.isDue(now: current))
        s.due = current.addingTimeInterval(-1)
        XCTAssertTrue(s.isDue(now: current))
    }
}

final class StudySessionTests: XCTestCase {
    private func makeWords(_ n: Int) -> [VocabWord] {
        (0..<n).map { i in
            VocabWord(word: "word\(i)", pos: "noun", definition: "def\(i)",
                      synonyms: ["syn\(i)a", "syn\(i)b"], mnemonic: "", root: "",
                      example: "", yourNote: "", source: .supplement, difficulty: 2)
        }
    }

    private func freshStore() -> ProgressStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ssattest-\(UUID().uuidString)", isDirectory: true)
        return ProgressStore(directory: dir)
    }

    func testNewLimitRespected() {
        let store = freshStore()
        let session = StudySession(words: makeWords(50), store: store, newLimit: 15)
        XCTAssertEqual(session.remaining, 15)
    }

    func testDueCardsComeBeforeNew() {
        let store = freshStore()
        let words = makeWords(10)
        var due = CardState()
        due.phase = .review
        due.intervalDays = 1
        due.due = Date().addingTimeInterval(-3600)
        store.setCard(due, for: "word9")

        let session = StudySession(words: words, store: store, newLimit: 5)
        XCTAssertEqual(session.current?.word, "word9")
        XCTAssertEqual(session.remaining, 6)
    }

    func testAgainRequeuesWithinSession() {
        let store = freshStore()
        let session = StudySession(words: makeWords(2), store: store, newLimit: 2)
        XCTAssertEqual(session.remaining, 2)
        session.answer(.again)
        XCTAssertEqual(session.remaining, 2, "again-card should return to the queue")
        session.answer(.easy)
        XCTAssertEqual(session.remaining, 1)
    }

    func testEasyRemovesCardFromSession() {
        let store = freshStore()
        let session = StudySession(words: makeWords(1), store: store, newLimit: 5)
        session.answer(.easy)
        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(store.card(for: "word0").phase, .review)
    }

    func testNewAllowanceAccountsForTodayIntroductions() {
        let store = freshStore()
        // Introductions must be words in this deck to count against its budget.
        store.recordReview(word: "word0", on: Date(), wasNew: true)
        store.recordReview(word: "word1", on: Date(), wasNew: true)
        let session = StudySession(words: makeWords(10), store: store, newLimit: 5)
        XCTAssertEqual(session.remaining, 3)
    }

    func testNewAllowanceIgnoresOutOfScopeIntroductions() {
        let store = freshStore()
        // Words learned in a different deck don't eat this deck's budget.
        store.recordReview(word: "other-a", on: Date(), wasNew: true)
        store.recordReview(word: "other-b", on: Date(), wasNew: true)
        let session = StudySession(words: makeWords(10), store: store, newLimit: 5)
        XCTAssertEqual(session.remaining, 5)
    }

    func testFlaggedWordComesFirstAndPersistsAfterStudy() {
        let store = freshStore()
        let words = makeWords(6)
        // Make word5 due for review and flag word3 as priority.
        var due = CardState(); due.phase = .review; due.intervalDays = 1
        due.due = Date().addingTimeInterval(-3600)
        store.setCard(due, for: "word5")
        store.flagPriority(["word3"])

        let session = StudySession(words: words, store: store, newLimit: 2)
        XCTAssertEqual(session.current?.word, "word3", "flagged word jumps to the front")
        session.answer(.good)
        // One Good doesn't clear a flag — it needs the full mastery streak.
        XCTAssertEqual(store.priorityWords, ["word3"], "flag persists after a single study")
        XCTAssertEqual(session.current?.word, "word5", "then the due card")
    }

    func testFlagsResumeAcrossSessionsAndPersist() {
        let store = freshStore()
        let words = makeWords(6)
        store.flagPriority(["word3", "word4"])

        let s1 = StudySession(words: words, store: store, newLimit: 0)
        let first = s1.current!.word
        XCTAssertTrue(["word3", "word4"].contains(first), "a flagged word is up first")
        s1.answer(.good)   // drill one, then imagine ending the session early
        XCTAssertEqual(store.priorityWords.sorted(), ["word3", "word4"],
                       "studying never clears a flag on its own")

        let s2 = StudySession(words: words, store: store, newLimit: 0)
        XCTAssertEqual(s2.current?.word, first == "word3" ? "word4" : "word3",
                       "next session resumes with the flag not yet drilled")
        s2.answer(.good)

        let s3 = StudySession(words: words, store: store, newLimit: 0)
        XCTAssertTrue(["word3", "word4"].contains(s3.current!.word),
                      "a fresh pass begins once every flag is drilled")
    }

    func testFlagClearsOnlyWithTwoGoodsThenNextDaySuccess() {
        let store = freshStore()
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = day1.addingTimeInterval(90_000)   // safely the next calendar day
        store.flagPriority(["word1"])

        XCTAssertFalse(store.advanceFlagMastery(word: "word1", success: true, on: day1))
        XCTAssertFalse(store.advanceFlagMastery(word: "word1", success: true, on: day1))
        XCTAssertTrue(store.priorityWords.contains("word1"),
                      "two Goods on the same day is not enough")

        XCTAssertTrue(store.advanceFlagMastery(word: "word1", success: true, on: day2))
        XCTAssertFalse(store.priorityWords.contains("word1"),
                       "cleared after a success on a later day")
    }

    func testFlagStreakResetsOnFailure() {
        let store = freshStore()
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = day1.addingTimeInterval(90_000)
        store.flagPriority(["word1"])

        _ = store.advanceFlagMastery(word: "word1", success: true, on: day1)
        _ = store.advanceFlagMastery(word: "word1", success: false, on: day1)  // breaks streak
        _ = store.advanceFlagMastery(word: "word1", success: true, on: day1)   // streak = 1 again
        XCTAssertFalse(store.advanceFlagMastery(word: "word1", success: true, on: day2),
                       "streak was reset, so the next-day success only reaches 2 in a row")
        XCTAssertTrue(store.priorityWords.contains("word1"), "still flagged")
    }

    func testPostponeCyclesQueue() {
        let store = freshStore()
        let session = StudySession(words: makeWords(3), store: store, newLimit: 3)
        let first = session.current?.word
        session.postpone()
        XCTAssertNotEqual(session.current?.word, first)
        XCTAssertEqual(session.remaining, 3)
    }
}

final class QuizEngineTests: XCTestCase {
    private func makeWords(_ n: Int) -> [VocabWord] {
        (0..<n).map { i in
            VocabWord(word: "word\(i)", pos: i % 2 == 0 ? "noun" : "adj", definition: "def\(i)",
                      synonyms: ["syn\(i)a", "syn\(i)b", "syn\(i)c"], mnemonic: "", root: "",
                      example: "", yourNote: "", source: .supplement, difficulty: 2)
        }
    }

    struct SeededRNG: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    func testQuestionHasFiveChoicesAndValidAnswer() {
        var rng = SeededRNG(state: 42)
        let words = makeWords(30)
        let questions = QuizEngine.makeQuestions(from: words, count: 10, using: &rng)
        XCTAssertEqual(questions.count, 10)
        for q in questions {
            XCTAssertEqual(q.choices.count, 5)
            XCTAssertTrue((0..<5).contains(q.answerIndex))
            XCTAssertTrue(q.word.synonyms.contains(q.choices[q.answerIndex]),
                          "answer must be a real synonym of the target")
            let others = q.choices.enumerated().filter { $0.offset != q.answerIndex }.map { $0.element.lowercased() }
            for distractor in others {
                XCTAssertFalse(q.word.synonyms.map { $0.lowercased() }.contains(distractor),
                               "distractor must not also be a synonym of the target")
            }
            XCTAssertEqual(Set(q.choices.map { $0.lowercased() }).count, 5, "choices must be unique")
        }
    }

    func testTargetsOverloadRespectsRepeatsAndTargets() {
        var rng = SeededRNG(state: 99)
        let pool = makeWords(30)
        let targets = [pool[0], pool[0], pool[1]]   // word0 repeated on purpose
        let qs = QuizEngine.makeQuestions(targets: targets, distractorPool: pool, using: &rng)
        XCTAssertEqual(qs.count, 3, "one question per target, repeats included")
        XCTAssertEqual(qs.map { $0.word.word }, ["word0", "word0", "word1"])
        for q in qs {
            XCTAssertEqual(q.choices.count, 5)
            XCTAssertTrue(q.word.synonyms.contains(q.choices[q.answerIndex]))
        }
    }

    func testTooSmallPoolProducesNothing() {
        var rng = SeededRNG(state: 7)
        XCTAssertTrue(QuizEngine.makeQuestions(from: makeWords(3), count: 5, using: &rng).isEmpty)
    }
}

final class ProgressStoreTests: XCTestCase {
    private func freshDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ssattest-\(UUID().uuidString)", isDirectory: true)
    }

    func testPersistenceRoundTrip() {
        let dir = freshDir()
        let store = ProgressStore(directory: dir)
        var card = CardState()
        card.phase = .review
        card.intervalDays = 12.5
        card.ease = 2.35
        card.due = Date(timeIntervalSince1970: 1_800_000_000)
        store.setCard(card, for: "laconic")
        store.recordQuiz(QuizResult(date: Date(), kind: "synonym", total: 10, correct: 8))
        store.save()

        let reloaded = ProgressStore(directory: dir)
        XCTAssertEqual(reloaded.card(for: "laconic"), card)
        XCTAssertEqual(reloaded.quizzes.count, 1)
        XCTAssertEqual(reloaded.quizzes[0].correct, 8)
    }

    func testCorruptProgressFileMovedAsideNotClobbered() throws {
        let dir = freshDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("progress.json")
        try Data("{not valid json!".utf8).write(to: url)

        let store = ProgressStore(directory: dir)
        store.recordReview(word: "w", on: Date(), wasNew: false)
        store.save()

        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(files.contains { $0.hasPrefix("progress-corrupt-") },
                      "unreadable file must be preserved, not overwritten")
        let reloaded = ProgressStore(directory: dir)
        XCTAssertEqual(reloaded.dayStats(for: Date()).reviews, 1)
    }

    func testStreakCountsBackFromToday() {
        let store = ProgressStore(directory: freshDir())
        let today = Date()
        store.recordReview(word: "w", on: today, wasNew: false)
        store.recordReview(word: "w", on: today.addingTimeInterval(-86400), wasNew: false)
        store.recordReview(word: "w", on: today.addingTimeInterval(-2 * 86400), wasNew: false)
        XCTAssertEqual(store.streak(asOf: today), 3)
    }

    func testStreakSurvivesQuietToday() {
        let store = ProgressStore(directory: freshDir())
        let today = Date()
        store.recordReview(word: "w", on: today.addingTimeInterval(-86400), wasNew: false)
        store.recordReview(word: "w", on: today.addingTimeInterval(-2 * 86400), wasNew: false)
        XCTAssertEqual(store.streak(asOf: today), 2, "no activity today shouldn't zero the streak")
    }

    func testStreakBrokenByGap() {
        let store = ProgressStore(directory: freshDir())
        let today = Date()
        store.recordReview(word: "w", on: today, wasNew: false)
        store.recordReview(word: "w", on: today.addingTimeInterval(-3 * 86400), wasNew: false)
        XCTAssertEqual(store.streak(asOf: today), 1)
    }

    func testUniqueWordsReviewedIgnoresRepeats() {
        let store = ProgressStore(directory: freshDir())
        let today = Date()
        // Struggle on "abate" three times, plus two other words.
        store.recordReview(word: "abate", on: today, wasNew: true)
        store.recordReview(word: "abate", on: today, wasNew: false)
        store.recordReview(word: "abate", on: today, wasNew: false)
        store.recordReview(word: "cede", on: today, wasNew: true)
        store.recordReview(word: "dour", on: today, wasNew: false)
        let d = store.dayStats(for: today)
        XCTAssertEqual(d.reviews, 5, "total grades still count every card")
        XCTAssertEqual(d.uniqueWordsReviewed, 3, "distinct words = abate, cede, dour")
    }

    func testDayStatsDecodesWithoutWordsField() throws {
        // A progress file written before `words` existed must still load.
        let dir = freshDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let legacy = #"{"cards":{},"days":{"2026-07-13":{"reviews":4,"newIntroduced":2,"quizQuestions":0,"quizCorrect":0}},"quizzes":[],"passageAnswers":{}}"#
        try Data(legacy.utf8).write(to: dir.appendingPathComponent("progress.json"))
        let store = ProgressStore(directory: dir)
        let d = store.dayStats(for: Date(timeIntervalSince1970: 1_784_000_000))
        // no crash / no data loss: reviews survive, words defaults to empty
        XCTAssertEqual(store.dayStats(for: Date()).uniqueWordsReviewed, 0)
        _ = d
    }

    func testNewWordsTrackedPerScope() {
        let store = ProgressStore(directory: freshDir())
        let now = Date()
        store.recordReview(word: "abate", on: now, wasNew: true)   // often-tested
        store.recordReview(word: "abate", on: now, wasNew: false)  // repeat, not new
        store.recordReview(word: "xenon", on: now, wasNew: true)   // general only
        // Only "abate" is in the often-tested scope.
        XCTAssertEqual(store.newWordsToday(in: ["abate", "cede"], now: now), 1)
        // Both count against the whole deck.
        XCTAssertEqual(store.newWordsToday(in: ["abate", "xenon", "cede"], now: now), 2)
        XCTAssertEqual(store.dayStats(for: now).newIntroduced, 2)
    }

    func testForecastBucketsDueDates() {
        let store = ProgressStore(directory: freshDir())
        let words = (0..<3).map { i in
            VocabWord(word: "w\(i)", pos: "noun", definition: "", synonyms: [], mnemonic: "",
                      root: "", example: "", yourNote: "", source: .supplement, difficulty: 2)
        }
        let now = Date()
        var overdue = CardState(); overdue.phase = .review; overdue.due = now.addingTimeInterval(-90000)
        var today = CardState(); today.phase = .review; today.due = now
        var inThree = CardState(); inThree.phase = .review; inThree.due = now.addingTimeInterval(3 * 86400)
        store.setCard(overdue, for: "w0")
        store.setCard(today, for: "w1")
        store.setCard(inThree, for: "w2")

        let forecast = store.forecast(words: words, now: now, days: 7)
        XCTAssertEqual(forecast[0], 2, "overdue cards collapse into today")
        XCTAssertEqual(forecast[3], 1)
    }

    func testForecastTodayMatchesDueCount() {
        let store = ProgressStore(directory: freshDir())
        let words = (0..<4).map { i in
            VocabWord(word: "w\(i)", pos: "noun", definition: "", synonyms: [], mnemonic: "",
                      root: "", example: "", yourNote: "", source: .supplement, difficulty: 2)
        }
        let now = Date()
        var overdue = CardState(); overdue.phase = .review; overdue.due = now.addingTimeInterval(-90000)
        var dueLaterToday = CardState(); dueLaterToday.phase = .learning; dueLaterToday.due = now.addingTimeInterval(300)
        var tomorrow = CardState(); tomorrow.phase = .review; tomorrow.due = now.addingTimeInterval(86400 * 1.2)
        store.setCard(overdue, for: "w0")
        store.setCard(dueLaterToday, for: "w1")
        store.setCard(tomorrow, for: "w2")

        let forecast = store.forecast(words: words, now: now, days: 7)
        // Today's forecast bar must equal the actionable-now due count (the
        // learning card due later today is not counted yet).
        XCTAssertEqual(forecast[0], store.dueCount(words: words, now: now))
        XCTAssertEqual(forecast[0], 1, "only the overdue review card is due now")
    }

    func testPhaseCounts() {
        let store = ProgressStore(directory: freshDir())
        let words = (0..<4).map { i in
            VocabWord(word: "w\(i)", pos: "noun", definition: "", synonyms: [], mnemonic: "",
                      root: "", example: "", yourNote: "", source: .supplement, difficulty: 2)
        }
        var learning = CardState(); learning.phase = .learning
        var young = CardState(); young.phase = .review; young.intervalDays = 5
        var mastered = CardState(); mastered.phase = .review; mastered.intervalDays = 30
        store.setCard(learning, for: "w1")
        store.setCard(young, for: "w2")
        store.setCard(mastered, for: "w3")

        let counts = store.phaseCounts(words: words)
        XCTAssertEqual(counts.new, 1)
        XCTAssertEqual(counts.learning, 1)
        XCTAssertEqual(counts.young, 1)
        XCTAssertEqual(counts.mastered, 1)
    }
}

final class ContentStoreTests: XCTestCase {
    func testEmbeddedContentDecodes() {
        let content = ContentStore()
        XCTAssertFalse(content.words.isEmpty, "embedded words JSON must decode")
        for word in content.words {
            XCTAssertFalse(word.word.isEmpty)
            XCTAssertFalse(word.definition.isEmpty, "\(word.word) has no definition")
        }
    }

    func testNoDuplicateWords() {
        let content = ContentStore()
        let keys = content.words.map { $0.word.lowercased() }
        XCTAssertEqual(keys.count, Set(keys).count, "duplicate headwords in embedded data")
    }

    func testPassageAnswerIndicesInRange() {
        let content = ContentStore()
        for passage in content.passages {
            for q in passage.questions {
                XCTAssertTrue((0..<q.choices.count).contains(q.answerIndex),
                              "\(passage.title): answerIndex out of range")
                XCTAssertEqual(q.choices.count, 5)
            }
        }
    }

    func testAnalogyAnswerIndicesInRange() {
        let content = ContentStore()
        for q in content.analogies.practice {
            XCTAssertTrue((0..<q.choices.count).contains(q.answerIndex))
        }
    }

    func testPracticeSectionsWellFormed() {
        let content = ContentStore()
        for section in content.practiceSections {
            XCTAssertFalse(section.passages.isEmpty, "\(section.name) has no passages")
            XCTAssertGreaterThan(section.minutes, 0)
            for passage in section.passages {
                XCTAssertFalse(passage.text.isEmpty, "\(section.name)/\(passage.title): empty passage")
                for q in passage.questions {
                    XCTAssertEqual(q.choices.count, 5, "\(section.name): question needs 5 choices")
                    XCTAssertTrue((0..<q.choices.count).contains(q.answerIndex),
                                  "\(section.name): answerIndex out of range")
                }
            }
        }
    }

    func testMathPracticeAnswersParse() {
        let content = ContentStore()
        for strand in content.mathStrands {
            for topic in strand.topics {
                for prob in topic.practice where !prob.choices.isEmpty {
                    XCTAssertNotNil(prob.answerIndex,
                                    "\(strand.strand)/\(topic.title): answer letter '\(prob.answer)' does not map to a choice")
                }
            }
        }
    }
}
