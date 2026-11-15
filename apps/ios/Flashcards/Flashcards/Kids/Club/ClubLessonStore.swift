import AVFoundation
import Foundation
import Observation

/// Stały identyfikator lekcji przykładowej – dzięki temu iPhone i iPad nie dublują jej po synchronizacji.
let clubDemoLessonId: UUID = UUID(uuidString: "D3E1A7B2-0000-4000-8000-000000000002")!

/// Lekcje klubu: zapisane w pliku na urządzeniu (działa bez internetu) i – jeśli rodzic wybrał folder
/// synchronizacji (np. w iCloud Drive) – wymieniane przez ten folder między iPhone'em i iPadem.
@MainActor
@Observable
final class ClubLessonStore {
    /// Jedna instancja na całe życie aplikacji.
    static let shared = ClubLessonStore()

    private(set) var lessons: [ClubLesson] = []
    var lastError: String?
    private(set) var lastSyncDate: Date?
    private(set) var isSyncing: Bool = false
    private(set) var syncFolderName: String?

    private let fileURL: URL
    private var deletedIds: Set<UUID>
    private var needsAnotherSync: Bool = false

    private static let bookmarkKey = "club.sync.folderBookmark"
    private static let deletedKey = "club.sync.deletedIds"
    private static let deviceIdKey = "club.sync.deviceId"

    private init() {
        let directory = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        let clubDirectory = directory.appendingPathComponent("PlayAndLearnClub", isDirectory: true)
        try? FileManager.default.createDirectory(at: clubDirectory, withIntermediateDirectories: true)
        self.fileURL = clubDirectory.appendingPathComponent("lessons.json")
        let storedDeleted = UserDefaults.standard.stringArray(forKey: Self.deletedKey) ?? []
        self.deletedIds = Set(storedDeleted.compactMap(UUID.init(uuidString:)))
        if let bookmark = UserDefaults.standard.data(forKey: Self.bookmarkKey) {
            self.syncFolderName = ClubFolderSync.folderName(bookmark: bookmark)
        }
        self.load()
    }

    var hasSyncFolder: Bool {
        UserDefaults.standard.data(forKey: Self.bookmarkKey) != nil
    }

    func add(_ lesson: ClubLesson) {
        self.lessons.removeAll { $0.id == lesson.id }
        self.lessons.insert(lesson, at: 0)
        self.save()
        self.sync()
    }

    func delete(lessonId: UUID) {
        self.lessons.removeAll { $0.id == lessonId }
        self.deletedIds.insert(lessonId)
        UserDefaults.standard.set(self.deletedIds.map(\.uuidString), forKey: Self.deletedKey)
        self.save()
        self.sync()
    }

    func recordStars(lessonId: UUID, stars: Int) {
        guard let index = self.lessons.firstIndex(where: { $0.id == lessonId }),
              stars > self.lessons[index].bestStars else {
            return
        }
        self.lessons[index].bestStars = stars
        self.save()
        self.sync()
    }

    func lesson(id: UUID) -> ClubLesson? {
        self.lessons.first { $0.id == id }
    }

    /// Dodaje przykładową lekcję („Unit 2: Art Club”), żeby od razu było czym się bawić.
    /// Dodawana tylko raz – jeśli rodzic ją usunie (na dowolnym urządzeniu), nie wraca.
    func addDemoLessonIfMissing() {
        let flagKey = "club.demoLessonAdded"
        guard UserDefaults.standard.bool(forKey: flagKey) == false else { return }
        UserDefaults.standard.set(true, forKey: flagKey)
        guard self.lesson(id: clubDemoLessonId) == nil,
              self.deletedIds.contains(clubDemoLessonId) == false,
              let draft = try? ClubLessonDraft.decode(json: Data(clubDemoLessonJSON.utf8)) else {
            return
        }
        self.add(draft.makeLesson(id: clubDemoLessonId, now: Date()))
    }

    // MARK: - Folder synchronizacji

    /// Zapamiętuje folder wybrany w aplikacji Pliki i od razu synchronizuje.
    func setSyncFolder(url: URL) {
        do {
            let bookmark = try ClubFolderSync.makeBookmark(folderURL: url)
            UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
            self.syncFolderName = url.lastPathComponent
            self.lastError = nil
            self.sync()
        } catch {
            self.lastError = "Nie udało się zapamiętać folderu: \(error.localizedDescription)"
        }
    }

    func removeSyncFolder() {
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        self.syncFolderName = nil
        self.lastSyncDate = nil
    }

    /// Wymiana zmian z folderem. Bezpieczne do wołania często – nakładające się wywołania są łączone.
    func sync() {
        guard let bookmark = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return }
        guard self.isSyncing == false else {
            self.needsAnotherSync = true
            return
        }
        self.isSyncing = true
        let input = ClubFolderSync.Input(
            folderBookmark: bookmark,
            deviceId: Self.deviceId(),
            lessons: self.lessons,
            deletedIds: self.deletedIds,
            progress: Dictionary(uniqueKeysWithValues: self.lessons.filter { $0.bestStars > 0 }.map { ($0.id, $0.bestStars) })
        )
        Task { @MainActor in
            defer {
                self.isSyncing = false
                if self.needsAnotherSync {
                    self.needsAnotherSync = false
                    self.sync()
                }
            }
            do {
                let output = try await ClubFolderSync.sync(input: input)
                self.apply(output: output)
                self.lastSyncDate = Date()
                if self.lastError == ClubFolderSync.SyncError.folderUnavailable.errorDescription {
                    self.lastError = nil
                }
            } catch {
                self.lastError = error.localizedDescription
            }
        }
    }

    private func apply(output: ClubFolderSync.Output) {
        if let refreshed = output.refreshedBookmark {
            UserDefaults.standard.set(refreshed, forKey: Self.bookmarkKey)
        }
        var changed = false

        if output.deletedIds.isSubset(of: self.deletedIds) == false {
            self.deletedIds.formUnion(output.deletedIds)
            UserDefaults.standard.set(self.deletedIds.map(\.uuidString), forKey: Self.deletedKey)
        }
        let countBefore = self.lessons.count
        self.lessons.removeAll { self.deletedIds.contains($0.id) }
        if self.lessons.count != countBefore {
            changed = true
        }

        for lesson in output.remoteLessons where self.lesson(id: lesson.id) == nil && self.deletedIds.contains(lesson.id) == false {
            self.lessons.append(lesson)
            changed = true
        }

        for index in self.lessons.indices {
            let remoteStars = output.bestStars[self.lessons[index].id] ?? 0
            if remoteStars > self.lessons[index].bestStars {
                self.lessons[index].bestStars = remoteStars
                changed = true
            }
        }

        if changed {
            self.lessons.sort { $0.createdAt > $1.createdAt }
            self.save()
        }
    }

    private static func deviceId() -> String {
        if let existing = UserDefaults.standard.string(forKey: self.deviceIdKey) {
            return existing
        }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: self.deviceIdKey)
        return created
    }

    // MARK: - Plik lokalny

    private func load() {
        guard let data = try? Data(contentsOf: self.fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            self.lessons = try decoder.decode([ClubLesson].self, from: data)
        } catch {
            self.lastError = "Nie udało się wczytać zapisanych lekcji: \(error.localizedDescription)"
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(self.lessons)
            try data.write(to: self.fileURL, options: [.atomic])
        } catch {
            self.lastError = "Nie udało się zapisać lekcji: \(error.localizedDescription)"
        }
    }
}

/// Czyta angielskie słówka na głos (brytyjski akcent, wolniej – dla dziecka).
@MainActor
@Observable
final class ClubSpeaker {
    private let synthesizer = AVSpeechSynthesizer()

    func speakEnglish(_ text: String) {
        self.speak(text, language: "en-GB")
    }

    func speakPolish(_ text: String) {
        self.speak(text, language: "pl-PL")
    }

    private func speak(_ text: String, language: String) {
        let cleaned = text.replacingOccurrences(of: "___", with: "…")
        guard cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
        if self.synthesizer.isSpeaking {
            self.synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        self.synthesizer.speak(utterance)
    }
}
