import Foundation
import Security
import UIKit

// MARK: - Klucz API w pęku kluczy
// Próbujemy zapisać go w pęku kluczy iCloud (wtedy pojawi się też na iPadzie); jeśli się nie da – tylko na tym urządzeniu.

enum ClubAPIKeyStore {
    private static let service = "club.anthropic.api-key"
    private static let account = "default"

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: self.account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8),
              key.isEmpty == false else {
            return nil
        }
        return key
    }

    static func save(_ key: String) {
        self.delete()
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: self.account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: true,
            kSecValueData as String: Data(trimmed.utf8),
        ]
        if SecItemAdd(attributes as CFDictionary, nil) != errSecSuccess {
            // Aplikacje podpisane darmowym kontem mogą nie mieć dostępu do pęku kluczy iCloud – zapis tylko lokalnie.
            var localOnly = attributes
            localOnly[kSecAttrSynchronizable as String] = false
            SecItemAdd(localOnly as CFDictionary, nil)
        }
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: self.account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Błędy

enum ClubClaudeError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case rateLimited
    case overloaded
    case server(status: Int, message: String)
    case refused
    case tooLong
    case unreadableResponse
    case emptyLesson

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Brak klucza API Claude. Poproś rodzica o wpisanie go w ustawieniach klubu (⚙️)."
        case .invalidAPIKey:
            return "Klucz API Claude jest nieprawidłowy. Sprawdź go w ustawieniach klubu (⚙️)."
        case .rateLimited:
            return "Za dużo zapytań naraz. Spróbuj ponownie za minutę."
        case .overloaded:
            return "Claude jest teraz bardzo zajęty. Spróbuj ponownie za chwilę."
        case .server(let status, let message):
            return "Błąd serwera (\(status)): \(message)"
        case .refused:
            return "Claude nie przygotował lekcji z tego zdjęcia. Spróbuj z inną kartką."
        case .tooLong:
            return "Kartka ma za dużo treści naraz. Zrób zdjęcie mniejszej części."
        case .unreadableResponse:
            return "Nie udało się odczytać odpowiedzi. Spróbuj ponownie."
        case .emptyLesson:
            return "Na zdjęciu nie znaleziono słówek ani zadań. Zrób zdjęcie bliżej i w lepszym świetle."
        }
    }
}

// MARK: - Zapytanie do Claude

/// Wysyła zdjęcia kartki do Claude i dostaje gotową lekcję (słówka + emoji, gramatyka, zadania).
/// Swift nie ma oficjalnego SDK Anthropic, więc używamy bezpośrednio REST API (`POST /v1/messages`).
enum ClubClaudeClient {
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-opus-5-5"

    static func makeLesson(images: [UIImage], apiKey: String) async throws -> ClubLessonDraft {
        let imageBlocks: [[String: Any]] = images.compactMap { image in
            guard let jpeg = clubPreparedJPEG(image: image) else { return nil }
            return [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": jpeg.base64EncodedString(),
                ],
            ]
        }
        guard imageBlocks.isEmpty == false else {
            throw WorksheetTextRecognitionError.unreadableImage
        }

        let body: [String: Any] = [
            "model": self.model,
            "max_tokens": 16000,
            // Gdyby filtr bezpieczeństwa odrzucił zapytanie, serwer sam spróbuje zalecanym modelem zapasowym.
            "fallbacks": "default",
            "output_config": [
                "effort": "medium",
                "format": [
                    "type": "json_schema",
                    "schema": clubLessonJSONSchema(),
                ],
            ],
            "system": clubSystemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": imageBlocks + [
                        ["type": "text", "text": clubUserPrompt(pageCount: imageBlocks.count)],
                    ],
                ],
            ],
        ]

        var request = URLRequest(url: self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw self.httpError(status: status, data: data)
        }

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClubClaudeError.unreadableResponse
        }
        // Zawsze najpierw sprawdzamy powód zakończenia, dopiero potem treść.
        switch root["stop_reason"] as? String {
        case "refusal":
            throw ClubClaudeError.refused
        case "max_tokens":
            throw ClubClaudeError.tooLong
        default:
            break
        }
        let blocks = root["content"] as? [[String: Any]] ?? []
        let text = blocks
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
        guard let json = text.data(using: .utf8), let draft = try? ClubLessonDraft.decode(json: json) else {
            throw ClubClaudeError.unreadableResponse
        }
        guard draft.vocabulary.isEmpty == false || draft.exercises.isEmpty == false else {
            throw ClubClaudeError.emptyLesson
        }
        return draft
    }

    private static func httpError(status: Int, data: Data) -> ClubClaudeError {
        switch status {
        case 401, 403:
            return .invalidAPIKey
        case 429:
            return .rateLimited
        case 529:
            return .overloaded
        default:
            let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let message = (root?["error"] as? [String: Any])?["message"] as? String ?? "nieznany błąd"
            return .server(status: status, message: message)
        }
    }
}

/// Zmniejsza zdjęcie (dłuższy bok maks. 1800 px) – tekst nadal czytelny, a wysyłka szybka i tańsza.
private func clubPreparedJPEG(image: UIImage) -> Data? {
    let maxSide: CGFloat = 1800
    let size = image.size
    let scale = min(1, maxSide / max(size.width, size.height))
    let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
        image.draw(in: CGRect(origin: .zero, size: target))
    }
    return resized.jpegData(compressionQuality: 0.82)
}

// MARK: - Polecenia dla Claude

private let clubSystemPrompt = """
Jesteś nauczycielem angielskiego dla 7-letniego polskiego dziecka. Rodzic robi zdjęcie kartki z zajęć \
„Play & Learn Club”, a Ty zamieniasz ją w kolorową lekcję w aplikacji. Dziecko dopiero uczy się czytać, \
więc wszystko ma być krótkie, proste i wesołe.

Zasady:
1. Słówka (vocabulary): przepisz WSZYSTKIE pary angielskie–polskie z kartki, dokładnie w tej pisowni \
(brytyjskiej, jak na kartce). Nie dodawaj słówek, których nie ma na kartce. Pole „group” to nagłówek \
sekcji z kartki (np. „Unit 2 Vocabulary”, „Experiment Lab”).
2. Do każdego słówka dobierz emoji, które 7-latek od razu rozpozna. Jedno emoji, a gdy jedno nie \
wystarcza – najwyżej trzy połączone (np. „secondary colours” → 🟠🟢🟣). Dla słów abstrakcyjnych \
wybierz coś obrazowego (dark → 🌑, light → 💡). Unikaj tego samego emoji dla dwóch różnych słówek.
3. Gramatyka (grammar): każdą ramkę z gramatyką opisz po polsku w 1–2 krótkich zdaniach zrozumiałych \
dla 7-latka. Przykłady przepisz z kartki (angielski + polskie tłumaczenie) i dodaj do każdego emoji.
4. Zadania (exercises): przygotuj 12–16 zadań wielokrotnego wyboru (2–4 odpowiedzi, dziecko tylko \
stuka). Używaj wyłącznie słówek i gramatyki z kartki. Mieszaj rodzaje: obrazek → angielskie słowo, \
słowo → polskie znaczenie, uzupełnij lukę (is/are, am/is/are, can/can't, and), „How many…?” \
z policzalnymi emoji, mieszanie kolorów (🔴 + 🟡 = ?), odpowiedź na pytanie (Yes, I can.).
   - „instruction_pl”: krótkie polecenie po polsku, np. „Co to jest?”, „Uzupełnij lukę”.
   - „question”: angielskie słowo lub zdanie (lukę zaznacz jako „___”); może być puste, gdy pytanie \
jest tylko obrazkiem.
   - „emoji”: obrazek do zadania, który NIE zdradza odpowiedzi.
   - „answer” musi być identyczne jak jedna z „options”. Odpowiedzi nie mogą się powtarzać.
   - „explanation_pl”: jedno krótkie, ciepłe zdanie po polsku pokazywane po odpowiedzi.
5. „title”: krótki tytuł lekcji z kartki (np. „Unit 2: Art Club”), „theme_emoji”: jedno emoji tematu.
"""

private func clubUserPrompt(pageCount: Int) -> String {
    let pages = pageCount == 1 ? "To jest zdjęcie kartki." : "To są zdjęcia \(pageCount) stron jednej kartki."
    return "\(pages) Przygotuj z niej lekcję zgodnie z zasadami."
}

/// Schemat JSON odpowiedzi – API gwarantuje, że Claude zwróci dokładnie taki kształt danych.
private func clubLessonJSONSchema() -> [String: Any] {
    func object(_ properties: [String: Any]) -> [String: Any] {
        [
            "type": "object",
            "properties": properties,
            "required": Array(properties.keys).sorted(),
            "additionalProperties": false,
        ]
    }
    let string: [String: Any] = ["type": "string"]
    let stringArray: [String: Any] = ["type": "array", "items": string]
    let word = object(["english": string, "polish": string, "emoji": string, "group": string])
    let example = object(["english": string, "polish": string, "emoji": string])
    let grammar = object([
        "title": string,
        "explanation_pl": string,
        "examples": ["type": "array", "items": example],
    ])
    let exercise = object([
        "instruction_pl": string,
        "question": string,
        "emoji": string,
        "options": stringArray,
        "answer": string,
        "explanation_pl": string,
    ])
    return object([
        "title": string,
        "theme_emoji": string,
        "vocabulary": ["type": "array", "items": word],
        "grammar": ["type": "array", "items": grammar],
        "exercises": ["type": "array", "items": exercise],
    ])
}
