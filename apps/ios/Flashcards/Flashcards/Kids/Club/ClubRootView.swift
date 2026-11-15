import PhotosUI
import SwiftUI
import UIKit

/// Tło całego klubu: jasne, ciepłe, z delikatnym gradientem.
struct ClubBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 1.0, green: 0.97, blue: 0.86), Color(red: 0.88, green: 0.96, blue: 1.0)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

/// Duży, kolorowy przycisk – łatwy do trafienia małym palcem.
struct ClubBigButtonLabel: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(self.title, systemImage: self.systemImage)
            .font(.system(.title3, design: .rounded).weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

enum ClubRoute: Hashable {
    case lesson(UUID)
    case words(UUID)
    case quiz(UUID, ClubQuizKind)
    case grammar(UUID)
}

/// Strona główna Play & Learn Club.
struct ClubRootView: View {
    @State private var lessonStore = ClubLessonStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var speaker = ClubSpeaker()
    @State private var path: [ClubRoute] = []
    @State private var isScanPresented: Bool = false
    @State private var isParentGatePresented: Bool = false
    @State private var isParentSettingsPresented: Bool = false

    var body: some View {
        NavigationStack(path: self.$path) {
            self.home
                .navigationDestination(for: ClubRoute.self) { route in
                    self.destination(route: route)
                }
        }
        .environment(self.lessonStore)
        .environment(self.speaker)
        .tint(KidPalette.orange)
        .preferredColorScheme(.light)
        .fontDesign(.rounded)
        .onAppear {
            self.lessonStore.addDemoLessonIfMissing()
            self.lessonStore.sync()
        }
        .onChange(of: self.scenePhase) { _, phase in
            if phase == .active {
                self.lessonStore.sync()
            }
        }
        .task {
            // Gdy klub jest otwarty, co 30 s sprawdzamy, czy drugie urządzenie coś dodało.
            while Task.isCancelled == false {
                try? await Task.sleep(for: .seconds(30))
                self.lessonStore.sync()
            }
        }
        .fullScreenCover(isPresented: self.$isScanPresented) {
            ClubScanView { lesson in
                self.isScanPresented = false
                if let lesson {
                    self.lessonStore.add(lesson)
                    self.path = [.lesson(lesson.id)]
                    // Od razu prosimy Claude o rysunki do słówek (w tle; postęp widać w lekcji).
                    if ClubAPIKeyStore.load() != nil {
                        self.lessonStore.illustrate(lessonId: lesson.id)
                    }
                }
            }
            .environment(self.lessonStore)
        }
        .sheet(isPresented: self.$isParentGatePresented) {
            ClubParentGateView {
                self.isParentGatePresented = false
                self.isParentSettingsPresented = true
            }
            .presentationDetents([.medium])
        }
        .alert(
            "Lekcje z pliku",
            isPresented: Binding(
                get: { self.lessonStore.importMessage != nil },
                set: { if $0 == false { self.lessonStore.importMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { self.lessonStore.importMessage = nil }
        } message: {
            Text(self.lessonStore.importMessage ?? "")
        }
        .sheet(isPresented: self.$isParentSettingsPresented) {
            ClubParentSettingsView()
                .environment(self.lessonStore)
                .environment(self.speaker)
        }
    }

    @ViewBuilder
    private func destination(route: ClubRoute) -> some View {
        switch route {
        case .lesson(let id):
            ClubLessonView(lessonId: id, path: self.$path)
        case .words(let id):
            ClubWordsView(lessonId: id)
        case .quiz(let id, let kind):
            ClubQuizView(lessonId: id, kind: kind)
        case .grammar(let id):
            ClubGrammarView(lessonId: id)
        }
    }

    private var home: some View {
        ZStack {
            ClubBackground()
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("🎨 Play & Learn Club")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                        Text("Wybierz lekcję albo zrób zdjęcie nowej kartki")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    Button {
                        self.isScanPresented = true
                    } label: {
                        ClubBigButtonLabel(title: "Nowa kartka 📸", systemImage: "camera.fill", color: KidPalette.orange)
                    }
                    .buttonStyle(.plain)

                    if let error = self.lessonStore.lastError {
                        Text(error)
                            .foregroundStyle(.red)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                        ForEach(self.lessonStore.lessons) { lesson in
                            Button {
                                self.path.append(.lesson(lesson.id))
                            } label: {
                                ClubLessonTile(lesson: lesson)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    self.isParentGatePresented = true
                } label: {
                    Label("Dla rodzica", systemImage: "gearshape.fill")
                }
            }
        }
    }
}

struct ClubLessonTile: View {
    let lesson: ClubLesson

    var body: some View {
        let color = KidPalette.color(seed: self.lesson.title)
        VStack(spacing: 8) {
            if let first = self.lesson.words.first {
                ClubWordPicture(word: first, size: 72)
            } else {
                Text(self.lesson.themeEmoji)
                    .font(.system(size: 52))
            }
            Text(self.lesson.title)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            HStack(spacing: 4) {
                ForEach(self.lesson.words.dropFirst().prefix(3)) { word in
                    ClubWordPicture(word: word, size: 30)
                }
            }
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < clubTrophyLevel(stars: self.lesson.bestStars, total: self.lesson.exercises.count) ? "star.fill" : "star")
                        .foregroundStyle(KidPalette.sun)
                }
            }
        }
        .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.3))
        .frame(maxWidth: .infinity, minHeight: 190)
        .padding(12)
        .background(color.opacity(0.22), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(color.opacity(0.6), lineWidth: 3)
        )
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

/// 0–3 duże gwiazdki za najlepszy wynik w zadaniach.
func clubTrophyLevel(stars: Int, total: Int) -> Int {
    guard total > 0, stars > 0 else { return 0 }
    let ratio = Double(stars) / Double(total)
    if ratio >= 0.9 { return 3 }
    if ratio >= 0.6 { return 2 }
    return 1
}

// MARK: - Skanowanie kartki

struct ClubScanView: View {
    let onFinish: (ClubLesson?) -> Void

    private enum Phase: Equatable {
        case start
        case working
    }

    @State private var phase: Phase = .start
    @State private var isScannerPresented: Bool = false
    @State private var photoSelection: PhotosPickerItem?
    @State private var errorMessage: String?
    @State private var workingStep: Int = 0

    private var hasAPIKey: Bool {
        ClubAPIKeyStore.load() != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ClubBackground()
                switch self.phase {
                case .start:
                    self.startScreen
                case .working:
                    self.workingScreen
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") { self.onFinish(nil) }
                        .disabled(self.phase == .working)
                }
            }
        }
        .preferredColorScheme(.light)
        .fullScreenCover(isPresented: self.$isScannerPresented) {
            WorksheetDocumentScanner(
                onScan: { images in
                    self.isScannerPresented = false
                    self.process(images: images)
                },
                onFailure: { error in
                    self.isScannerPresented = false
                    self.errorMessage = error.localizedDescription
                },
                onCancel: {
                    self.isScannerPresented = false
                }
            )
            .ignoresSafeArea()
        }
        .onChange(of: self.photoSelection) { _, selection in
            guard let selection else { return }
            self.photoSelection = nil
            self.loadPhoto(item: selection)
        }
        .alert(
            "Ups!",
            isPresented: Binding(
                get: { self.errorMessage != nil },
                set: { if $0 == false { self.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { self.errorMessage = nil }
        } message: {
            Text(self.errorMessage ?? "")
        }
    }

    private var startScreen: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("📸✨🧠")
                    .font(.system(size: 72))
                    .padding(.top, 16)
                Text("Zrób zdjęcie kartki z klubu, a Claude zamieni ją w lekcję z obrazkami, quizem i zadaniami!")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .multilineTextAlignment(.center)

                if self.hasAPIKey == false {
                    Text("Brak klucza Claude – odczytam tylko słówka bez zadań. Rodzic może dodać klucz w ustawieniach (⚙️).")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                if WorksheetDocumentScanner.isSupported {
                    Button {
                        self.isScannerPresented = true
                    } label: {
                        ClubBigButtonLabel(title: "Zrób zdjęcie kartki", systemImage: "camera.fill", color: KidPalette.orange)
                    }
                    .buttonStyle(.plain)
                }

                PhotosPicker(selection: self.$photoSelection, matching: .images) {
                    ClubBigButtonLabel(title: "Wybierz z galerii", systemImage: "photo.on.rectangle.angled", color: KidPalette.sky)
                }
                .buttonStyle(.plain)

                Text("Wskazówka: kartka płasko, w całości w kadrze, w dobrym świetle.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
    }

    private var workingScreen: some View {
        let steps = [
            "Czytam kartkę… 🔍",
            "Szukam obrazków do słówek… 🖍️",
            "Wymyślam zadania… 🧩",
            "Jeszcze chwilka… ⭐",
        ]
        return VStack(spacing: 24) {
            ProgressView()
                .controlSize(.large)
            Text(steps[min(self.workingStep, steps.count - 1)])
                .font(.system(.title2, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
            Text("To może potrwać około minuty.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .task {
            while Task.isCancelled == false {
                try? await Task.sleep(for: .seconds(12))
                withAnimation { self.workingStep += 1 }
            }
        }
    }

    private func loadPhoto(item: PhotosPickerItem) {
        Task { @MainActor in
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    throw WorksheetTextRecognitionError.unreadableImage
                }
                self.process(images: [image])
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func process(images: [UIImage]) {
        guard images.isEmpty == false else { return }
        self.phase = .working
        self.workingStep = 0
        Task { @MainActor in
            do {
                let lesson: ClubLesson
                if let apiKey = ClubAPIKeyStore.load() {
                    let draft = try await ClubClaudeClient.makeLesson(images: images, apiKey: apiKey)
                    lesson = draft.makeLesson(now: Date())
                } else {
                    lesson = try await makeOfflineClubLesson(images: images)
                }
                self.onFinish(lesson)
            } catch {
                self.phase = .start
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

/// Tryb bez Claude: rozpoznawanie tekstu na telefonie + słowniczek emoji. Tylko słówka, bez zadań od Claude.
func makeOfflineClubLesson(images: [UIImage]) async throws -> ClubLesson {
    let lines = try await WorksheetTextRecognizer.recognizeLines(images: images)
    let words = parseWorksheetLines(lines)
        .filter { $0.kind == .word && $0.isValid }
        .map { item in
            ClubWord(
                id: UUID(),
                english: item.frontText,
                polish: item.backText,
                emoji: kidEmoji(frontText: item.frontText, backText: item.backText),
                group: "Słówka"
            )
        }
    guard words.isEmpty == false else {
        throw ClubClaudeError.emptyLesson
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "pl_PL")
    formatter.dateFormat = "d MMMM"
    return ClubLesson(
        id: UUID(),
        createdAt: Date(),
        title: "Kartka z \(formatter.string(from: Date()))",
        themeEmoji: "📝",
        words: words,
        grammar: [],
        exercises: [],
        bestStars: 0
    )
}
