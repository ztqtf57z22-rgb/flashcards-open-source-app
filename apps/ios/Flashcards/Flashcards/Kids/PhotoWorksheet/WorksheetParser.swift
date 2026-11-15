import Foundation

/// Rodzaj pozycji odczytanej z kartki.
enum WorksheetItemKind: String, CaseIterable, Hashable, Sendable {
    /// Para słówek, np. „cat – kot”.
    case word
    /// Zadanie / polecenie, np. „Narysuj swój dom”.
    case task

    var title: String {
        switch self {
        case .word: "Słówko"
        case .task: "Zadanie"
        }
    }

    var sectionTitle: String {
        switch self {
        case .word: "Słówka"
        case .task: "Zadania"
        }
    }

    var systemImage: String {
        switch self {
        case .word: "textformat.abc"
        case .task: "star.fill"
        }
    }

    /// Tag dodawany do fiszek, dzięki któremu łatwo je potem filtrować.
    var tag: String {
        switch self {
        case .word: "słówka"
        case .task: "zadania"
        }
    }
}

/// Jedna pozycja z kartki, którą rodzic może poprawić przed zapisaniem.
struct WorksheetItem: Identifiable, Hashable, Sendable {
    let id: UUID
    var kind: WorksheetItemKind
    var frontText: String
    var backText: String
    var isIncluded: Bool

    var isValid: Bool {
        self.frontText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && self.backText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

/// Domyślny tył fiszki-zadania – dziecko po wykonaniu zadania odsłania pochwałę.
let worksheetTaskDefaultBackText: String = "Brawo! Zadanie zrobione! ⭐"

/// Separatory między słówkiem a tłumaczeniem, od najbardziej jednoznacznych.
private let worksheetPairSeparators: [String] = [" – ", " — ", " - ", " = ", " : ", "–", "—", "=", " -", "- ", ":", "→", "->", "\t"]

/// Słowa, od których zwykle zaczynają się polecenia na kartkach dla dzieci.
private let worksheetTaskKeywords: [String] = [
    "napisz", "przepisz", "narysuj", "pokoloruj", "pomaluj", "wytnij", "wklej", "połącz", "podkreśl", "zakreśl",
    "otocz", "uzupełnij", "dopisz", "wpisz", "przeczytaj", "naucz", "powtórz", "policz", "oblicz", "dodaj", "odejmij",
    "odpowiedz", "ułóż", "znajdź", "wskaż", "zaznacz", "opowiedz", "posłuchaj", "zaśpiewaj", "wymień", "dokończ",
    "zadanie", "ćwiczenie", "zad.", "ćw.",
    "write", "draw", "colour", "color", "read", "match", "circle", "complete", "listen", "count", "find", "copy",
    "fill", "answer", "sing", "say", "learn", "practice", "practise",
]

/// Zamienia rozpoznane linie tekstu z kartki na listę słówek i zadań.
///
/// Zasady (proste, by rodzic łatwo poprawił wynik):
/// - linia z poleceniem (np. „Narysuj…”, „Zad. 2”, „Write…”) → zadanie,
/// - linia z separatorem („cat – kot”, „pies = dog”, „sun: słońce”) → para słówek,
/// - samotne słowo, po którym w następnej linii jest samotne słowo → para słówek (dwie kolumny),
/// - inna dłuższa linia → zadanie.
func parseWorksheetLines(_ rawLines: [String]) -> [WorksheetItem] {
    let lines = rawLines
        .map(cleanWorksheetLine)
        .filter { $0.isEmpty == false }

    var items: [WorksheetItem] = []
    var pendingLoneWord: String?

    func flushPendingLoneWord() {
        if let word = pendingLoneWord {
            // Pojedyncze słowo bez pary – zostawiamy z pustym tyłem, rodzic dopisze tłumaczenie.
            items.append(WorksheetItem(id: UUID(), kind: .word, frontText: word, backText: "", isIncluded: true))
            pendingLoneWord = nil
        }
    }

    for line in lines {
        // Nagłówki kartki („Słówka – Unit 3”, „Lekcja 5”) nie są fiszkami.
        if isWorksheetHeadingLine(line) {
            flushPendingLoneWord()
            continue
        }
        if isWorksheetTaskLine(line) {
            flushPendingLoneWord()
            items.append(WorksheetItem(
                id: UUID(),
                kind: .task,
                frontText: line,
                backText: worksheetTaskDefaultBackText,
                isIncluded: true
            ))
            continue
        }

        if let pair = splitWorksheetPair(line) {
            flushPendingLoneWord()
            items.append(WorksheetItem(id: UUID(), kind: .word, frontText: pair.front, backText: pair.back, isIncluded: true))
            continue
        }

        if isLoneWorksheetWord(line) {
            if let previous = pendingLoneWord {
                items.append(WorksheetItem(id: UUID(), kind: .word, frontText: previous, backText: line, isIncluded: true))
                pendingLoneWord = nil
            } else {
                pendingLoneWord = line
            }
            continue
        }

        flushPendingLoneWord()
        // Krótkie śmieci z OCR (np. „3.”, „a)”) pomijamy.
        guard line.count >= 4 else { continue }
        items.append(WorksheetItem(
            id: UUID(),
            kind: .task,
            frontText: line,
            backText: worksheetTaskDefaultBackText,
            isIncluded: true
        ))
    }
    flushPendingLoneWord()
    return items
}

/// Usuwa numerację i punktory z początku linii: „1.”, „2)”, „a)”, „•”, „-”.
private func cleanWorksheetLine(_ line: String) -> String {
    var text = line.trimmingCharacters(in: .whitespacesAndNewlines)
    let prefixPattern = #"^((\d{1,2}[\.\)]|[a-hA-H]\)|[•·\*▪■●○◦–—-])\s*)+"#
    if let range = text.range(of: prefixPattern, options: .regularExpression) {
        text.removeSubrange(range)
    }
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
}

private let worksheetHeadingPrefixes: [String] = [
    "słówka", "słowniczek", "słownictwo", "lekcja", "temat", "rozdział", "unit", "lesson", "vocabulary", "words",
]

private func isWorksheetHeadingLine(_ line: String) -> Bool {
    let lowered = line.lowercased()
    return worksheetHeadingPrefixes.contains { lowered.hasPrefix($0) } && lowered.split(separator: " ").count <= 5
}

private func isWorksheetTaskLine(_ line: String) -> Bool {
    let lowered = line.lowercased()
    if worksheetTaskKeywords.contains(where: { lowered.hasPrefix($0) }) {
        return true
    }
    // Zdanie z poleceniem zakończone wykrzyknikiem lub pytajnikiem i składające się z kilku słów.
    let wordCount = lowered.split(separator: " ").count
    return wordCount >= 4 && (lowered.hasSuffix("!") || lowered.hasSuffix("?"))
}

private func splitWorksheetPair(_ line: String) -> (front: String, back: String)? {
    for separator in worksheetPairSeparators {
        guard let range = line.range(of: separator) else { continue }
        let front = line[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        let back = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        // Para słówek to krótkie wyrażenia po obu stronach.
        guard front.isEmpty == false, back.isEmpty == false,
              front.split(separator: " ").count <= 4, back.split(separator: " ").count <= 6 else {
            continue
        }
        return (front, back)
    }
    // Ostatnia deska ratunku: myślnik bez spacji („crayon-kredka świecowa” – OCR często gubi spację).
    // Tylko gdy linia ma kilka słów, żeby nie rozcinać pojedynczych słów typu „ice-cream”.
    if line.contains(" "), let range = line.range(of: "-") {
        let front = line[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        let back = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        if front.isEmpty == false, back.isEmpty == false,
           front.split(separator: " ").count <= 4, back.split(separator: " ").count <= 6 {
            return (front, back)
        }
    }
    return nil
}

private func isLoneWorksheetWord(_ line: String) -> Bool {
    let words = line.split(separator: " ")
    return words.count <= 2 && line.count <= 24 && line.rangeOfCharacter(from: .letters) != nil
}
