import Foundation

// MARK: - Lekcja zapisana w aplikacji

/// Jedna kartka z klubu zamieniona w lekcję: słówka z obrazkami, gramatyka i zadania.
struct ClubLesson: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let createdAt: Date
    var title: String
    var themeEmoji: String
    var words: [ClubWord]
    var grammar: [ClubGrammarNote]
    var exercises: [ClubExercise]
    /// Najlepszy wynik w zadaniach (liczba gwiazdek).
    var bestStars: Int
}

struct ClubWord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var english: String
    var polish: String
    var emoji: String
    /// Nagłówek z kartki, np. „Unit 2 Vocabulary” albo „Experiment Lab”.
    var group: String
    /// Ilustracja SVG narysowana przez Claude (nil = pokazujemy emoji).
    var svg: String? = nil
}

extension ClubLesson {
    /// Ile słówek ma już ilustrację od Claude.
    var illustrationCount: Int {
        self.words.filter { $0.svg != nil }.count
    }
}

struct ClubGrammarNote: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var explanationPolish: String
    var examples: [ClubExample]
}

struct ClubExample: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var english: String
    var polish: String
    var emoji: String
}

/// Zadanie wielokrotnego wyboru – dziecko tylko stuka w odpowiedź, nie musi pisać.
struct ClubExercise: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var instructionPolish: String
    var question: String
    var emoji: String
    var options: [String]
    var answer: String
    var explanationPolish: String
}

// MARK: - Odpowiedź Claude (format JSON wymuszony schematem)

/// Dokładnie to, co zwraca Claude. Klucze w JSON są w stylu snake_case.
struct ClubLessonDraft: Codable, Sendable {
    struct Word: Codable, Sendable {
        let english: String
        let polish: String
        let emoji: String
        let group: String
    }

    struct Example: Codable, Sendable {
        let english: String
        let polish: String
        let emoji: String
    }

    struct Grammar: Codable, Sendable {
        let title: String
        let explanationPl: String
        let examples: [Example]
    }

    struct Exercise: Codable, Sendable {
        let instructionPl: String
        let question: String
        let emoji: String
        let options: [String]
        let answer: String
        let explanationPl: String
    }

    let title: String
    let themeEmoji: String
    let vocabulary: [Word]
    let grammar: [Grammar]
    let exercises: [Exercise]

    static func decode(json: Data) throws -> ClubLessonDraft {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ClubLessonDraft.self, from: json)
    }

    func makeLesson(id: UUID = UUID(), now: Date) -> ClubLesson {
        ClubLesson(
            id: id,
            createdAt: now,
            title: self.title,
            themeEmoji: self.themeEmoji,
            words: self.vocabulary.map {
                ClubWord(id: UUID(), english: $0.english, polish: $0.polish, emoji: $0.emoji, group: $0.group)
            },
            grammar: self.grammar.map { note in
                ClubGrammarNote(
                    id: UUID(),
                    title: note.title,
                    explanationPolish: note.explanationPl,
                    examples: note.examples.map {
                        ClubExample(id: UUID(), english: $0.english, polish: $0.polish, emoji: $0.emoji)
                    }
                )
            },
            // Zadanie bez poprawnej odpowiedzi wśród opcji byłoby frustrujące – takie pomijamy.
            exercises: self.exercises
                .filter { $0.options.count >= 2 && $0.options.contains($0.answer) && Set($0.options).count == $0.options.count }
                .map {
                    ClubExercise(
                        id: UUID(),
                        instructionPolish: $0.instructionPl,
                        question: $0.question,
                        emoji: $0.emoji,
                        options: $0.options,
                        answer: $0.answer,
                        explanationPolish: $0.explanationPl
                    )
                },
            bestStars: 0
        )
    }
}

// MARK: - Quiz obrazkowy budowany lokalnie ze słówek (bez internetu)

/// „Który obrazek to …?” oraz „Co znaczy …?” – losowane ze słówek lekcji.
func makeClubPictureQuiz(words: [ClubWord], count: Int) -> [ClubExercise] {
    guard words.count >= 3 else { return [] }
    var exercises: [ClubExercise] = []
    for (index, word) in words.shuffled().prefix(count).enumerated() {
        let others = words.filter { $0.id != word.id }.shuffled().prefix(2)
        if index.isMultiple(of: 2) {
            exercises.append(ClubExercise(
                id: UUID(),
                instructionPolish: "Który obrazek to:",
                question: word.english,
                emoji: "",
                options: ([word] + others).map { clubWordToken(word: $0) }.shuffled(),
                answer: clubWordToken(word: word),
                explanationPolish: "\(word.english) = \(word.polish)"
            ))
        } else {
            exercises.append(ClubExercise(
                id: UUID(),
                instructionPolish: "Co to znaczy po polsku?",
                question: word.english,
                emoji: clubWordToken(word: word),
                options: ([word.polish] + others.map(\.polish)).shuffled(),
                answer: word.polish,
                explanationPolish: "\(word.english) = \(word.polish)"
            ))
        }
    }
    // Dwa słówka mogą mieć ten sam obrazek – wtedy pytanie byłoby niejednoznaczne.
    return exercises.filter { Set($0.options).count == $0.options.count }
}

/// Odnośnik do słówka w zadaniu: zamiast tekstu pokazujemy jego obrazek.
func clubWordToken(word: ClubWord) -> String {
    "word:\(word.id.uuidString)"
}

func clubWordId(token: String) -> UUID? {
    guard token.hasPrefix("word:") else { return nil }
    return UUID(uuidString: String(token.dropFirst(5)))
}

/// „1 fiszkę”, „3 fiszki”, „5 fiszek” – polska odmiana (biernik).
func polishFlashcardCount(_ count: Int) -> String {
    let lastTwo = count % 100
    let last = count % 10
    if count == 1 {
        return "1 fiszkę"
    }
    if (2...4).contains(last) && (12...14).contains(lastTwo) == false {
        return "\(count) fiszki"
    }
    return "\(count) fiszek"
}
