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
    /// Komunikat po wczytaniu pliku `.fiszki` (pokazywany w klubie).
    var importMessage: String?

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

    // MARK: - Ilustracje od Claude

    /// Lekcje, do których Claude właśnie rysuje obrazki, z postępem (narysowane, wszystkie).
    private(set) var illustrationProgress: [UUID: (done: Int, total: Int)] = [:]
    var illustrationError: String?

    func isIllustrating(lessonId: UUID) -> Bool {
        self.illustrationProgress[lessonId] != nil
    }

    /// Prosi Claude o rysunki do słówek, które jeszcze ich nie mają. Działa w tle; postęp widać w lekcji.
    func illustrate(lessonId: UUID) {
        guard self.isIllustrating(lessonId: lessonId) == false,
              let lesson = self.lesson(id: lessonId) else { return }
        guard let apiKey = ClubAPIKeyStore.load() else {
            self.illustrationError = ClubClaudeError.missingAPIKey.errorDescription
            return
        }
        let style = ClubStyleSettings.shared.style
        let requests = lesson.words
            .filter { $0.picture(style: style) == nil }
            .map { ClubClaudeClient.IllustrationRequest(english: $0.english, polish: $0.polish) }
        guard requests.isEmpty == false else { return }
        self.illustrationError = nil
        self.illustrationProgress[lessonId] = (0, requests.count)

        Task { @MainActor in
            defer { self.illustrationProgress[lessonId] = nil }
            do {
                let drawings = try await ClubClaudeClient.makeIllustrations(
                    words: requests,
                    style: style,
                    apiKey: apiKey,
                    onProgress: { done, total in
                        if ClubLessonStore.shared.illustrationProgress[lessonId] != nil {
                            ClubLessonStore.shared.illustrationProgress[lessonId] = (done, total)
                        }
                    }
                )
                self.applyIllustrations(lessonId: lessonId, drawings: drawings, style: style)
                if drawings.count < requests.count {
                    self.illustrationError = "Narysowano \(drawings.count) z \(requests.count) obrazków. Brakujące możesz dorysować z menu ⋯ w lekcji."
                }
            } catch {
                self.illustrationError = error.localizedDescription
            }
        }
    }

    private func applyIllustrations(lessonId: UUID, drawings: [String: String], style: ClubIllustrationStyle) {
        guard let index = self.lessons.firstIndex(where: { $0.id == lessonId }) else { return }
        var changed = false
        for wordIndex in self.lessons[index].words.indices {
            let english = self.lessons[index].words[wordIndex].english
            if self.lessons[index].words[wordIndex].picture(style: style) == nil, let svg = drawings[english],
               ClubSVGCache.drawing(for: svg) != nil {
                self.lessons[index].words[wordIndex].setPicture(svg, style: style)
                changed = true
            }
        }
        if changed {
            self.save()
            self.sync()
        }
    }

    // MARK: - Plik .fiszki (AirDrop)

    /// Wczytuje lekcje z pliku `.fiszki`. Nowe lekcje są dodawane, a przy istniejących zostaje lepszy wynik.
    @discardableResult
    func importLessons(from url: URL) -> Int {
        do {
            let package = try readClubLessonPackage(url: url)
            var added = 0
            var changed = false
            for incoming in package.lessons {
                if let index = self.lessons.firstIndex(where: { $0.id == incoming.id }) {
                    if incoming.bestStars > self.lessons[index].bestStars {
                        self.lessons[index].bestStars = incoming.bestStars
                        changed = true
                    }
                    if self.lessons[index].mergeIllustrations(from: incoming) {
                        changed = true
                    }
                } else {
                    // Świadomie wczytana lekcja wraca, nawet jeśli kiedyś została tu usunięta.
                    self.deletedIds.remove(incoming.id)
                    self.lessons.append(incoming)
                    added += 1
                    changed = true
                }
            }
            if changed {
                UserDefaults.standard.set(self.deletedIds.map(\.uuidString), forKey: Self.deletedKey)
                self.lessons.sort { $0.createdAt > $1.createdAt }
                self.save()
                self.sync()
            }
            let total = package.lessons.count
            if added > 0 {
                self.importMessage = added == 1
                    ? "Dodano nową lekcję! 🎉"
                    : "Dodano nowe lekcje: \(added) 🎉"
            } else if total > 0 {
                self.importMessage = "Te lekcje już tu są – zaktualizowano wyniki ⭐"
            } else {
                self.importMessage = "Plik nie zawiera lekcji."
            }
            return added
        } catch {
            self.importMessage = error.localizedDescription
            return 0
        }
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

        for lesson in output.remoteLessons where self.deletedIds.contains(lesson.id) == false {
            if let index = self.lessons.firstIndex(where: { $0.id == lesson.id }) {
                if self.lessons[index].mergeIllustrations(from: lesson) {
                    changed = true
                }
            } else {
                self.lessons.append(lesson)
                changed = true
            }
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
