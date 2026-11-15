import SwiftUI
import UniformTypeIdentifiers

/// Prosta „bramka dla rodzica”: działanie, którego 7-latek raczej jeszcze nie policzy.
struct ClubParentGateView: View {
    let onPassed: () -> Void

    @State private var first: Int = Int.random(in: 6...9)
    @State private var second: Int = Int.random(in: 6...9)
    @State private var answer: String = ""
    @State private var isWrong: Bool = false

    var body: some View {
        VStack(spacing: 18) {
            Text("🔒 Tylko dla rodzica")
                .font(.system(.title2, design: .rounded).weight(.heavy))
            Text("Ile to \(self.first) × \(self.second)?")
                .font(.system(.title3, design: .rounded))
            TextField("Wynik", text: self.$answer)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .font(.title2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 160)
            if self.isWrong {
                Text("Niestety nie 🙂")
                    .foregroundStyle(.red)
            }
            Button("Dalej") {
                if Int(self.answer) == self.first * self.second {
                    self.onPassed()
                } else {
                    self.isWrong = true
                    self.answer = ""
                    self.first = Int.random(in: 6...9)
                    self.second = Int.random(in: 6...9)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

/// Ustawienia rodzica: klucz API Claude i przenoszenie słówek do zwykłych fiszek.
struct ClubParentSettingsView: View {
    @Environment(ClubLessonStore.self) private var lessonStore: ClubLessonStore
    @Environment(FlashcardsStore.self) private var flashcardsStore: FlashcardsStore
    @Environment(\.dismiss) private var dismiss

    @State private var apiKeyDraft: String = ""
    @State private var hasSavedKey: Bool = ClubAPIKeyStore.load() != nil
    @State private var exportingLessonId: UUID?
    @State private var message: String?
    @State private var isFolderPickerPresented: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if self.hasSavedKey {
                        Label("Klucz jest zapisany na tym telefonie", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Button("Usuń klucz", role: .destructive) {
                            ClubAPIKeyStore.delete()
                            self.hasSavedKey = false
                        }
                    }
                    SecureField("sk-ant-…", text: self.$apiKeyDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button(self.hasSavedKey ? "Zamień klucz" : "Zapisz klucz") {
                        ClubAPIKeyStore.save(self.apiKeyDraft)
                        self.apiKeyDraft = ""
                        self.hasSavedKey = ClubAPIKeyStore.load() != nil
                    }
                    .disabled(self.apiKeyDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("Klucz API Claude")
                } footer: {
                    Text("""
                    Klucz utworzysz na platform.claude.com (Settings → API Keys). Jest przechowywany w pęku kluczy \
                    iPhone'a i wysyłany tylko do api.anthropic.com razem ze zdjęciem kartki. Jedna kartka \
                    kosztuje zwykle kilka–kilkanaście groszy. Bez klucza aplikacja odczyta tylko słówka (bez zadań).
                    """)
                }

                Section {
                    if let folderName = self.lessonStore.syncFolderName {
                        LabeledContent("Folder", value: folderName)
                        if let lastSync = self.lessonStore.lastSyncDate {
                            LabeledContent("Ostatnia synchronizacja") {
                                Text(lastSync, style: .relative)
                            }
                        }
                        Button("Synchronizuj teraz", systemImage: "arrow.triangle.2.circlepath") {
                            self.lessonStore.sync()
                        }
                        .disabled(self.lessonStore.isSyncing)
                        Button("Zmień folder", systemImage: "folder") {
                            self.isFolderPickerPresented = true
                        }
                        Button("Wyłącz synchronizację", role: .destructive) {
                            self.lessonStore.removeSyncFolder()
                        }
                    } else {
                        Button("Wybierz folder synchronizacji", systemImage: "folder.badge.plus") {
                            self.isFolderPickerPresented = true
                        }
                    }
                    if let error = self.lessonStore.lastError {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Synchronizacja iPhone ↔ iPad")
                } footer: {
                    Text("""
                    W aplikacji Pliki utwórz w iCloud Drive folder, np. „Fiszki-Sync”, i wybierz go tutaj \
                    na KAŻDYM urządzeniu (to samo Apple ID). Lekcje i gwiazdki wymieniają się co ok. 30 s, \
                    gdy klub jest otwarty. Działa bez płatnego konta dewelopera.
                    """)
                }

                Section {
                    if self.lessonStore.lessons.isEmpty {
                        Text("Brak lekcji.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(self.lessonStore.lessons) { lesson in
                        Button {
                            self.export(lesson: lesson)
                        } label: {
                            HStack {
                                Text(lesson.themeEmoji)
                                VStack(alignment: .leading) {
                                    Text(lesson.title)
                                        .foregroundStyle(Color.primary)
                                    Text("\(lesson.words.count) słówek")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if self.exportingLessonId == lesson.id {
                                    ProgressView()
                                } else {
                                    Image(systemName: "square.and.arrow.down.on.square")
                                }
                            }
                        }
                        .disabled(self.exportingLessonId != nil || lesson.words.isEmpty)
                    }
                    if let message {
                        Text(message)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Dodaj słówka do zwykłych fiszek")
                } footer: {
                    Text("Słówka z lekcji trafią do standardowej aplikacji z powtórkami (FSRS), z tagiem „play-and-learn” i tytułem lekcji.")
                }
            }
            .fileImporter(isPresented: self.$isFolderPickerPresented, allowedContentTypes: [.folder]) { result in
                switch result {
                case .success(let url):
                    self.lessonStore.setSyncFolder(url: url)
                case .failure(let error):
                    self.lessonStore.lastError = error.localizedDescription
                }
            }
            .navigationTitle("Dla rodzica")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") { self.dismiss() }
                }
            }
        }
    }

    private func export(lesson: ClubLesson) {
        guard let scope = self.flashcardsStore.spreadsheetImportScope else {
            self.message = "Zwykła aplikacja jeszcze się przygotowuje – spróbuj za chwilę."
            return
        }
        let cards = lesson.words.map { word in
            WorkspaceSpreadsheetCard(
                id: UUID(),
                frontText: "\(word.emoji) \(word.english)",
                backText: word.polish
            )
        }
        self.exportingLessonId = lesson.id
        self.message = nil
        Task { @MainActor in
            defer { self.exportingLessonId = nil }
            do {
                let count = try await self.flashcardsStore.createSpreadsheetImportCards(
                    scope: scope,
                    cards: cards,
                    tags: ["play-and-learn", lesson.title]
                )
                self.message = "Dodano \(polishFlashcardCount(count)) z lekcji „\(lesson.title)”."
            } catch {
                self.message = Flashcards.errorMessage(error: error)
            }
        }
    }
}
