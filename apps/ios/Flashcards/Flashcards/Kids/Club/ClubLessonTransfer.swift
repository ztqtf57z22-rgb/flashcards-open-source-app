import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Plik z lekcjami klubu (rozszerzenie `.fiszki`) – do przesłania przez AirDrop, Wiadomości albo Pliki.
/// Typ jest zadeklarowany w Info.plist, dzięki czemu iPad po odebraniu pliku proponuje „Otwórz w Fiszki”.
extension UTType {
    static let clubLessonFile = UTType(exportedAs: "pl.fiszki.club-lesson", conformingTo: .data)
}

/// Zawartość pliku `.fiszki`: wersja formatu i lista lekcji (z gwiazdkami).
struct ClubLessonPackage: Codable, Sendable {
    static let currentFormat = "play-and-learn-club"

    let format: String
    let version: Int
    let lessons: [ClubLesson]

    init(lessons: [ClubLesson]) {
        self.format = Self.currentFormat
        self.version = 1
        self.lessons = lessons
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(data: Data) throws -> ClubLessonPackage {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let package = try decoder.decode(ClubLessonPackage.self, from: data)
        guard package.format == Self.currentFormat else {
            throw ClubLessonTransferError.wrongFormat
        }
        return package
    }
}

enum ClubLessonTransferError: LocalizedError {
    case wrongFormat
    case unreadable

    var errorDescription: String? {
        switch self {
        case .wrongFormat:
            return "To nie jest plik z lekcjami Play & Learn Club."
        case .unreadable:
            return "Nie udało się odczytać pliku z lekcjami."
        }
    }
}

/// Element do `ShareLink`: przy udostępnianiu powstaje plik „<tytuł>.fiszki”.
struct ClubLessonShareItem: Transferable, Sendable {
    let lessons: [ClubLesson]
    let fileName: String

    init(lessons: [ClubLesson], fileName: String) {
        self.lessons = lessons
        // Znaki niedozwolone w nazwach plików zamieniamy na myślnik.
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = fileName.components(separatedBy: forbidden).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.fileName = cleaned.isEmpty ? "Lekcje" : cleaned
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .clubLessonFile) { item in
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("ClubExport-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(item.fileName).appendingPathExtension("fiszki")
            try ClubLessonPackage(lessons: item.lessons).encoded().write(to: url, options: [.atomic])
            return SentTransferredFile(url)
        }
    }
}

/// Odczyt pliku `.fiszki` otrzymanego przez AirDrop / z aplikacji Pliki.
func readClubLessonPackage(url: URL) throws -> ClubLessonPackage {
    let didStart = url.startAccessingSecurityScopedResource()
    defer {
        if didStart { url.stopAccessingSecurityScopedResource() }
    }
    var coordinationError: NSError?
    var result: Result<Data, Error> = .failure(ClubLessonTransferError.unreadable)
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
        result = Result { try Data(contentsOf: readURL) }
    }
    if let coordinationError {
        throw coordinationError
    }
    return try ClubLessonPackage.decode(data: try result.get())
}
