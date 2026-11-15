import Foundation

/// Synchronizacja klubu przez wspólny folder (najlepiej w iCloud Drive), wybrany przez rodzica w aplikacji Pliki.
///
/// Nie wymaga płatnego konta Apple Developer ani uprawnień iCloud w aplikacji – plikami zajmuje się iOS
/// (aplikacja Pliki / iCloud Drive), a aplikacja tylko czyta i zapisuje pliki w wybranym folderze.
///
/// Układ folderu `PlayAndLearnClub/` (każdy plik pisze tylko jedno urządzenie, więc nie ma konfliktów):
/// - `lessons/<id>.json`         – lekcja (zapisywana raz, potem tylko czytana),
/// - `deleted/<id>`              – „nagrobek”: lekcja usunięta na którymś urządzeniu znika wszędzie,
/// - `progress/<urządzenie>.json` – najlepsze wyniki z danego urządzenia; łączone przez „większy wygrywa”.
enum ClubFolderSync {
    struct Input: Sendable {
        let folderBookmark: Data
        let deviceId: String
        let lessons: [ClubLesson]
        let deletedIds: Set<UUID>
        let progress: [UUID: Int]
    }

    struct Output: Sendable {
        let remoteLessons: [ClubLesson]
        let deletedIds: Set<UUID>
        let bestStars: [UUID: Int]
        /// Odświeżona zakładka, gdy system ją unieważnił (np. po przeniesieniu folderu).
        let refreshedBookmark: Data?
    }

    enum SyncError: LocalizedError {
        case folderUnavailable

        var errorDescription: String? {
            "Brak dostępu do folderu synchronizacji. Wybierz go ponownie w ustawieniach rodzica (⚙️)."
        }
    }

    /// Tworzy zakładkę (trwały dostęp) do folderu wybranego w aplikacji Pliki.
    static func makeBookmark(folderURL: URL) throws -> Data {
        let didStart = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didStart { folderURL.stopAccessingSecurityScopedResource() }
        }
        return try folderURL.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    static func folderName(bookmark: Data) -> String? {
        var isStale = false
        let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
        return url?.lastPathComponent
    }

    /// Jedna runda synchronizacji: odczyt zmian z folderu i zapis lokalnych zmian. Działa poza wątkiem interfejsu.
    static func sync(input: Input) async throws -> Output {
        var isStale = false
        let folder = try URL(
            resolvingBookmarkData: input.folderBookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        guard folder.startAccessingSecurityScopedResource() else {
            throw SyncError.folderUnavailable
        }
        defer { folder.stopAccessingSecurityScopedResource() }

        let refreshedBookmark = isStale
            ? try? folder.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            : nil

        let root = folder.appendingPathComponent("PlayAndLearnClub", isDirectory: true)
        let lessonsDir = root.appendingPathComponent("lessons", isDirectory: true)
        let deletedDir = root.appendingPathComponent("deleted", isDirectory: true)
        let progressDir = root.appendingPathComponent("progress", isDirectory: true)
        for directory in [lessonsDir, deletedDir, progressDir] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        // 1. Odczyt
        var deletedIds = input.deletedIds
        for name in self.fileNames(in: deletedDir) {
            if let id = UUID(uuidString: name) {
                deletedIds.insert(id)
            }
        }

        var remoteLessons: [ClubLesson] = []
        var remoteIds: Set<UUID> = []
        for name in self.fileNames(in: lessonsDir) where name.hasSuffix(".json") {
            guard let id = UUID(uuidString: String(name.dropLast(5))) else { continue }
            remoteIds.insert(id)
            guard deletedIds.contains(id) == false,
                  let data = try? self.coordinatedRead(url: lessonsDir.appendingPathComponent(name)),
                  let lesson = try? decoder.decode(ClubLesson.self, from: data) else {
                continue
            }
            remoteLessons.append(lesson)
        }

        var bestStars = input.progress
        for name in self.fileNames(in: progressDir) where name.hasSuffix(".json") {
            guard let data = try? self.coordinatedRead(url: progressDir.appendingPathComponent(name)),
                  let entries = try? decoder.decode([String: Int].self, from: data) else {
                continue
            }
            for (key, stars) in entries {
                guard let id = UUID(uuidString: key) else { continue }
                bestStars[id] = max(bestStars[id] ?? 0, stars)
            }
        }

        // 2. Zapis lokalnych zmian
        for lesson in input.lessons where remoteIds.contains(lesson.id) == false && deletedIds.contains(lesson.id) == false {
            var shared = lesson
            shared.bestStars = 0
            try self.coordinatedWrite(
                data: try encoder.encode(shared),
                url: lessonsDir.appendingPathComponent("\(lesson.id.uuidString).json")
            )
        }
        let knownTombstones = Set(self.fileNames(in: deletedDir))
        for id in input.deletedIds where knownTombstones.contains(id.uuidString) == false {
            try self.coordinatedWrite(data: Data(), url: deletedDir.appendingPathComponent(id.uuidString))
        }
        let myProgress = Dictionary(uniqueKeysWithValues: input.progress.map { ($0.key.uuidString, $0.value) })
        try self.coordinatedWrite(
            data: try encoder.encode(myProgress),
            url: progressDir.appendingPathComponent("\(input.deviceId).json")
        )

        return Output(
            remoteLessons: remoteLessons,
            deletedIds: deletedIds,
            bestStars: bestStars,
            refreshedBookmark: refreshedBookmark
        )
    }

    /// Nazwy plików w folderze. Pliki iCloud jeszcze niepobrane na to urządzenie mają postać
    /// „.nazwa.icloud” – zlecamy ich pobranie i zwracamy prawdziwą nazwę (odczyt i tak je pobierze).
    private static func fileNames(in directory: URL) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.compactMap { name in
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                let realName = String(name.dropFirst().dropLast(".icloud".count))
                try? FileManager.default.startDownloadingUbiquitousItem(at: directory.appendingPathComponent(realName))
                return realName
            }
            return name.hasPrefix(".") ? nil : name
        }
    }

    private static func coordinatedRead(url: URL) throws -> Data {
        var coordinationError: NSError?
        var result: Result<Data, Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
            result = Result { try Data(contentsOf: readURL) }
        }
        if let coordinationError {
            throw coordinationError
        }
        return try result.get()
    }

    private static func coordinatedWrite(data: Data, url: URL) throws {
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { writeURL in
            do {
                try data.write(to: writeURL, options: [.atomic])
            } catch {
                writeError = error
            }
        }
        if let coordinationError {
            throw coordinationError
        }
        if let writeError {
            throw writeError
        }
    }
}
