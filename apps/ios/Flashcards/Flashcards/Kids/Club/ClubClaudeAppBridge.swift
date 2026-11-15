import Foundation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

// Współpraca z aplikacją Claude (abonament Pro/Max) – bez klucza API.
//
// 1. Fiszki kopiują do schowka gotowe polecenie (zasady lekcji + styl obrazków + wzór JSON).
// 2. Rodzic wkleja je w aplikacji Claude, dołącza zdjęcie kartki i wysyła.
// 3. Claude odpowiada jednym blokiem JSON (albo plikiem .json).
// 4. Fiszki wczytują odpowiedź ze schowka lub z pliku i tworzą lekcję z obrazkami.

/// Adres, który otwiera aplikację Claude (a gdy jej nie ma – claude.ai w Safari).
let clubClaudeAppURL = URL(string: "https://claude.ai/new")!

// MARK: - Polecenia do skopiowania

/// Polecenie: „zamień zdjęcie kartki w lekcję z obrazkami”.
func clubClaudeAppLessonPrompt(style: ClubIllustrationStyle) -> String {
    """
    [Play & Learn Club – przygotuj lekcję ze zdjęcia kartki]

    \(clubSystemPrompt)

    ILUSTRACJE: do każdego słówka narysuj obrazek SVG (pole „svg”) według tych zasad:
    \(clubIllustratorPrompt)

    STYL RYSUNKÓW (dla każdego obrazka):
    \(style.promptDescription)

    FORMAT ODPOWIEDZI – BARDZO WAŻNE:
    - Odpowiedz WYŁĄCZNIE jednym blokiem kodu ```json z jednym obiektem JSON, bez żadnego tekstu przed ani po nim.
    - W kodzie SVG używaj apostrofów w atrybutach (np. fill='#ff8fc6'), nigdy cudzysłowów – inaczej JSON się zepsuje.
    - Jeśli odpowiedź byłaby za długa na jedną wiadomość, utwórz plik lekcja.json do pobrania z tą samą zawartością.
    - Wzór (zachowaj dokładnie te nazwy pól):
    {
      "format": "play-and-learn-lesson",
      "style": "\(style.rawValue)",
      "title": "Unit 2: Art Club",
      "theme_emoji": "🎨",
      "vocabulary": [
        {"english": "crayon", "polish": "kredka świecowa", "emoji": "🖍️", "group": "Unit 2 Vocabulary",
         "svg": "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'>…</svg>"}
      ],
      "grammar": [
        {"title": "There's / There are", "explanation_pl": "…",
         "examples": [{"english": "There's a paintbrush.", "polish": "Jest jeden pędzel.", "emoji": "🖌️"}]}
      ],
      "exercises": [
        {"instruction_pl": "Uzupełnij lukę", "question": "There ___ two crayons.", "emoji": "🖍️🖍️",
         "options": ["is", "are"], "answer": "are", "explanation_pl": "Dwie kredki – There are."}
      ]
    }

    Zdjęcie kartki jest w załączniku.
    """
}

/// Polecenie: „dorysuj obrazki do słówek tej lekcji” (np. po zmianie stylu albo dla starszej lekcji).
func clubClaudeAppIllustrationPrompt(lesson: ClubLesson, style: ClubIllustrationStyle) -> String {
    let words = lesson.words
        .filter { $0.picture(style: style) == nil }
        .map { "- \($0.english) (po polsku: \($0.polish))" }
        .joined(separator: "\n")
    return """
    [Play & Learn Club – narysuj obrazki do słówek]

    \(clubIllustratorPrompt)

    STYL RYSUNKÓW (dla każdego obrazka):
    \(style.promptDescription)

    Słówka do narysowania (lekcja „\(lesson.title)”):
    \(words)

    FORMAT ODPOWIEDZI – BARDZO WAŻNE:
    - Odpowiedz WYŁĄCZNIE jednym blokiem kodu ```json, bez tekstu przed ani po nim.
    - W SVG używaj apostrofów w atrybutach (np. fill='#ff8fc6'), nigdy cudzysłowów.
    - Jeśli odpowiedź byłaby za długa, utwórz plik obrazki.json do pobrania z tą samą zawartością.
    - Wzór:
    {
      "format": "play-and-learn-illustrations",
      "style": "\(style.rawValue)",
      "illustrations": [
        {"english": "crayon", "svg": "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'>…</svg>"}
      ]
    }
    """
}

// MARK: - Odczyt odpowiedzi

enum ClubClaudeAppResponse {
    case lesson(ClubLesson)
    case illustrations(style: ClubIllustrationStyle, drawings: [String: String])
    case package([ClubLesson])
}

enum ClubClaudeAppResponseError: LocalizedError {
    case empty
    case noJSON
    case unknownFormat(String)

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Schowek jest pusty. W aplikacji Claude stuknij „Kopiuj” pod odpowiedzią i wróć tutaj."
        case .noJSON:
            return "W skopiowanym tekście nie ma lekcji od Claude. Skopiuj cały blok kodu z odpowiedzi Claude."
        case .unknownFormat(let detail):
            return "Nie udało się odczytać odpowiedzi Claude (\(detail)). Poproś Claude: „Popraw JSON, żeby był poprawny” i skopiuj ponownie."
        }
    }
}

/// Wyciąga JSON z odpowiedzi Claude (także gdy jest w bloku ```json albo otoczony tekstem).
func clubExtractJSON(from text: String) -> Data? {
    var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if let fenceStart = body.range(of: "```") {
        let afterFence = body[fenceStart.upperBound...]
        let contentStart = afterFence.firstIndex(of: "\n").map { afterFence.index(after: $0) } ?? afterFence.startIndex
        if let fenceEnd = body[contentStart...].range(of: "```") {
            body = String(body[contentStart..<fenceEnd.lowerBound])
        }
    }
    guard let first = body.firstIndex(of: "{"), let last = body.lastIndex(of: "}"), first < last else {
        return nil
    }
    return String(body[first...last]).data(using: .utf8)
}

func clubParseClaudeAppResponse(_ text: String) throws -> ClubClaudeAppResponse {
    guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
        throw ClubClaudeAppResponseError.empty
    }
    guard let data = clubExtractJSON(from: text) else {
        throw ClubClaudeAppResponseError.noJSON
    }
    let root: [String: Any]
    do {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClubClaudeAppResponseError.unknownFormat("to nie jest obiekt JSON")
        }
        root = object
    } catch let error as ClubClaudeAppResponseError {
        throw error
    } catch {
        throw ClubClaudeAppResponseError.unknownFormat("błąd JSON: \(error.localizedDescription)")
    }

    let format = root["format"] as? String ?? ""

    if format == ClubLessonPackage.currentFormat {
        return .package(try ClubLessonPackage.decode(data: data).lessons)
    }

    if format == "play-and-learn-illustrations" || (root["illustrations"] != nil && root["vocabulary"] == nil) {
        let style = (root["style"] as? String).flatMap(ClubIllustrationStyle.init(rawValue:)) ?? .textbook
        let items = root["illustrations"] as? [[String: Any]] ?? []
        var drawings: [String: String] = [:]
        for item in items {
            if let english = item["english"] as? String, let svg = item["svg"] as? String, svg.contains("<svg") {
                drawings[english] = svg
            }
        }
        guard drawings.isEmpty == false else {
            throw ClubClaudeAppResponseError.unknownFormat("brak obrazków w odpowiedzi")
        }
        return .illustrations(style: style, drawings: drawings)
    }

    if root["vocabulary"] != nil || format == "play-and-learn-lesson" {
        do {
            let draft = try ClubLessonDraft.decode(json: data)
            guard draft.vocabulary.isEmpty == false || draft.exercises.isEmpty == false else {
                throw ClubClaudeError.emptyLesson
            }
            return .lesson(draft.makeLesson(now: Date()))
        } catch let error as ClubClaudeError {
            throw error
        } catch {
            throw ClubClaudeAppResponseError.unknownFormat("brakuje pól lekcji")
        }
    }

    throw ClubClaudeAppResponseError.unknownFormat("nieznany format")
}

// MARK: - Widok: krok po kroku z aplikacją Claude

/// Trzy kroki: skopiuj polecenie → otwórz Claude → wklej odpowiedź. Używany do nowej kartki i do dorysowania obrazków.
struct ClubClaudeAppSteps: View {
    let copyTitle: String
    let prompt: () -> String
    let pasteTitle: String
    let attachPhotoHint: Bool
    let onResponseText: (String) -> Void
    let onFile: (URL) -> Void

    @Environment(\.openURL) private var openURL
    @State private var didCopy: Bool = false
    @State private var isFileImporterPresented: Bool = false

    var body: some View {
        VStack(spacing: 14) {
            self.step(number: 1, text: "Skopiuj polecenie dla Claude") {
                Button {
                    UIPasteboard.general.string = self.prompt()
                    withAnimation { self.didCopy = true }
                } label: {
                    ClubBigButtonLabel(
                        title: self.didCopy ? "Skopiowano ✓" : self.copyTitle,
                        systemImage: "doc.on.doc.fill",
                        color: KidPalette.purple
                    )
                }
                .buttonStyle(.plain)
            }

            self.step(
                number: 2,
                text: self.attachPhotoHint
                    ? "W aplikacji Claude wklej polecenie, dołącz zdjęcie kartki (📎 → Aparat lub Zdjęcia) i wyślij. Gdy Claude skończy, stuknij „Kopiuj” przy bloku kodu."
                    : "W aplikacji Claude wklej polecenie i wyślij. Gdy Claude skończy, stuknij „Kopiuj” przy bloku kodu."
            ) {
                Button {
                    self.openURL(clubClaudeAppURL)
                } label: {
                    ClubBigButtonLabel(title: "Otwórz Claude", systemImage: "arrow.up.forward.app.fill", color: KidPalette.orange)
                }
                .buttonStyle(.plain)
            }

            self.step(number: 3, text: "Wróć tutaj i wklej odpowiedź (albo wybierz plik .json od Claude).") {
                VStack(spacing: 10) {
                    Button {
                        self.onResponseText(UIPasteboard.general.string ?? "")
                    } label: {
                        ClubBigButtonLabel(title: self.pasteTitle, systemImage: "doc.on.clipboard.fill", color: KidPalette.grass)
                    }
                    .buttonStyle(.plain)
                    Button {
                        self.isFileImporterPresented = true
                    } label: {
                        Label("Wybierz plik od Claude", systemImage: "folder")
                            .font(.system(.headline, design: .rounded))
                    }
                }
            }
        }
        .fileImporter(
            isPresented: self.$isFileImporterPresented,
            allowedContentTypes: [.json, .clubLessonFile, .plainText, .data]
        ) { result in
            if case .success(let url) = result {
                self.onFile(url)
            }
        }
    }

    private func step<Content: View>(number: Int, text: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(number)")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(KidPalette.purple, in: Circle())
                Text(text)
                    .font(.system(.callout, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
        .padding()
        .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Odczyt tekstu z pliku wybranego w aplikacji Pliki (np. lekcja.json pobrana z Claude).
func clubReadText(url: URL) throws -> String {
    let didStart = url.startAccessingSecurityScopedResource()
    defer {
        if didStart { url.stopAccessingSecurityScopedResource() }
    }
    var coordinationError: NSError?
    var result: Result<String, Error> = .failure(ClubClaudeAppResponseError.noJSON)
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
        result = Result {
            let data = try Data(contentsOf: readURL)
            return String(decoding: data, as: UTF8.self)
        }
    }
    if let coordinationError {
        throw coordinationError
    }
    return try result.get()
}

// MARK: - Arkusz: dorysuj obrazki przez aplikację Claude

struct ClubClaudeIllustrateSheet: View {
    let lessonId: UUID
    @Environment(ClubLessonStore.self) private var lessonStore: ClubLessonStore
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ZStack {
                ClubBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        Text("Obrazki w stylu „\(ClubStyleSettings.shared.style.title)”")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .multilineTextAlignment(.center)
                        if let lesson = self.lessonStore.lesson(id: self.lessonId) {
                            ClubClaudeAppSteps(
                                copyTitle: "Kopiuj polecenie (obrazki)",
                                prompt: { clubClaudeAppIllustrationPrompt(lesson: lesson, style: ClubStyleSettings.shared.style) },
                                pasteTitle: "Wklej obrazki od Claude",
                                attachPhotoHint: false,
                                onResponseText: { self.handle(text: $0) },
                                onFile: { url in
                                    do {
                                        self.handle(text: try clubReadText(url: url))
                                    } catch {
                                        self.message = error.localizedDescription
                                    }
                                }
                            )
                        }
                        if let message {
                            Text(message)
                                .font(.system(.callout, design: .rounded))
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .padding()
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Dorysuj obrazki")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") { self.dismiss() }
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private func handle(text: String) {
        self.message = self.lessonStore.importClaudeAppResponse(text, targetLessonId: self.lessonId).message
    }
}
