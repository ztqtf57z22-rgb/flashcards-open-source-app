import AVFoundation
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

/// Ustawienia rodzica: klucz API Claude, lektor, przenoszenie lekcji i synchronizacja.
struct ClubParentSettingsView: View {
    @Environment(ClubLessonStore.self) private var lessonStore: ClubLessonStore
    @Environment(ClubSpeaker.self) private var speaker: ClubSpeaker
    @Environment(\.dismiss) private var dismiss

    @State private var apiKeyDraft: String = ""
    @State private var hasSavedKey: Bool = ClubAPIKeyStore.load() != nil
    @State private var isFolderPickerPresented: Bool = false
    @State private var isLessonFileImporterPresented: Bool = false

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
                    Text("Opcjonalnie: klucz API Claude")
                } footer: {
                    Text("""
                    NIE jest potrzebny, jeśli korzystasz z aplikacji Claude (abonament Pro) – wtedy lekcje i obrazki \
                    przygotowujesz przyciskami „Kopiuj polecenie” i „Wklej od Claude”. Klucz API (płatny osobno, \
                    platform.claude.com) pozwala robić to automatycznie. Jest przechowywany w pęku kluczy \
                    iPhone'a i wysyłany tylko do api.anthropic.com razem ze zdjęciem kartki. Jedna kartka \
                    kosztuje zwykle kilka–kilkanaście groszy. Bez klucza aplikacja odczyta tylko słówka (bez zadań).
                    """)
                }

                Section {
                    if self.lessonStore.lessons.isEmpty == false {
                        ShareLink(
                            item: ClubLessonShareItem(lessons: self.lessonStore.lessons, fileName: "Wszystkie lekcje"),
                            preview: SharePreview("Wszystkie lekcje (\(self.lessonStore.lessons.count))")
                        ) {
                            Label("Wyślij wszystkie lekcje (AirDrop)", systemImage: "square.and.arrow.up.on.square")
                        }
                    }
                    Button("Wczytaj lekcje z pliku", systemImage: "square.and.arrow.down") {
                        self.isLessonFileImporterPresented = true
                    }
                    if let message = self.lessonStore.importMessage {
                        Text(message)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Przenoszenie lekcji bez synchronizacji")
                } footer: {
                    Text("""
                    Pojedynczą lekcję wyślesz z menu ⋯ w lekcji. Na drugim urządzeniu odbierz AirDrop i wybierz \
                    „Otwórz w Fiszki” – lekcja doda się sama. Wysłanie lekcji z powrotem przenosi też gwiazdki.
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
                    Text("Automatyczna synchronizacja (opcjonalnie)")
                } footer: {
                    Text("""
                    W aplikacji Pliki utwórz w iCloud Drive folder, np. „Fiszki-Sync”, i wybierz go tutaj \
                    na KAŻDYM urządzeniu (to samo Apple ID). Lekcje i gwiazdki wymieniają się co ok. 30 s, \
                    gdy klub jest otwarty. Działa bez płatnego konta dewelopera.
                    """)
                }

                Section {
                    ForEach(ClubIllustrationStyle.allCases) { style in
                        Button {
                            ClubStyleSettings.shared.style = style
                        } label: {
                            HStack(spacing: 12) {
                                if let drawing = ClubSVGCache.drawing(for: style.sampleSVG) {
                                    ClubSVGView(drawing: drawing)
                                        .frame(width: 64, height: 64)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(style.title)
                                        .font(.headline)
                                        .foregroundStyle(Color.primary)
                                    Text(style.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if ClubStyleSettings.shared.style == style {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(KidPalette.grass)
                                        .font(.title2)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Styl obrazków")
                } footer: {
                    Text("""
                    Nowe kartki Claude narysuje w wybranym stylu. Do starszych lekcji dorysujesz obrazki z menu ⋯ \
                    w lekcji. Rysunki każdego stylu są zapamiętane – możesz przełączać style bez rysowania od nowa; \
                    gdy w danym stylu rysunku brak, pokazujemy rysunek z innego stylu.
                    """)
                }

                self.narratorSection(language: .english)
                self.narratorSection(language: .polish)
                Section {
                    VStack(alignment: .leading) {
                        Text("Tempo czytania")
                        Slider(
                            value: Binding(get: { self.speaker.rateMultiplier }, set: { self.speaker.rateMultiplier = $0 }),
                            in: 0.6...1.1
                        ) {
                            Text("Tempo czytania")
                        } minimumValueLabel: {
                            Image(systemName: "tortoise.fill")
                        } maximumValueLabel: {
                            Image(systemName: "hare.fill")
                        }
                    }
                } footer: {
                    Text("""
                    Najlepiej brzmią darmowe głosy „Premium” i „Rozszerzony”. Pobierzesz je w Ustawieniach iPhone'a/iPada: \
                    Dostępność → Treść mówiona → Głosy → English (np. Serena, Daniel – Premium) oraz Polski (np. Zosia, \
                    Krzysztof – Rozszerzony). Potem wróć tutaj i wybierz je powyżej.
                    """)
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
            .fileImporter(
                isPresented: self.$isLessonFileImporterPresented,
                allowedContentTypes: [.clubLessonFile, .json, .data]
            ) { result in
                switch result {
                case .success(let url):
                    self.lessonStore.importLessons(from: url)
                case .failure(let error):
                    self.lessonStore.importMessage = error.localizedDescription
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

    /// Wybór głosu lektora dla jednego języka + przycisk „Posłuchaj”.
    private func narratorSection(language: ClubSpeechLanguage) -> some View {
        let voices = ClubSpeaker.availableVoices(for: language)
        let selectedId = self.speaker.voice(for: language)?.identifier
        let sample = language == .english ? "Hello! This is a crayon and a paintbrush." : "Cześć! To jest kredka i pędzel."
        return Section {
            if voices.isEmpty {
                Text("Brak głosu dla tego języka. Pobierz go w Ustawieniach (opis niżej).")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Głos", selection: Binding(
                    get: { selectedId ?? "" },
                    set: { self.speaker.selectVoice(identifier: $0.isEmpty ? nil : $0, for: language) }
                )) {
                    ForEach(voices, id: \.identifier) { voice in
                        Text("\(voice.name) – \(clubQualityLabel(voice.quality)) (\(voice.language))")
                            .tag(voice.identifier)
                    }
                }
                if ClubSpeaker.hasHighQualityVoice(for: language) == false {
                    Label("Zainstalowany jest tylko głos standardowy – pobierz lepszy (opis niżej).", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            Button("Posłuchaj", systemImage: "speaker.wave.2.fill") {
                self.speaker.speak(sample, language: language)
            }
        } header: {
            Text("Lektor – \(language.title.lowercased())")
        }
    }
}
