import UIKit
import Vision

enum WorksheetTextRecognitionError: LocalizedError {
    case unreadableImage
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "Nie udało się odczytać zdjęcia. Spróbuj zrobić je jeszcze raz."
        case .noTextFound:
            return "Nie znaleziono tekstu. Zrób zdjęcie bliżej, w dobrym świetle i tak, by kartka była prosto."
        }
    }
}

/// Rozpoznaje tekst (drukowany i staranne pismo ręczne) na zdjęciach kartek – w całości na urządzeniu,
/// bez wysyłania zdjęć do internetu (Apple Vision).
enum WorksheetTextRecognizer {
    /// Zwraca linie tekstu ze wszystkich stron, od góry do dołu i od lewej do prawej.
    static func recognizeLines(images: [UIImage]) async throws -> [String] {
        var lines: [String] = []
        for image in images {
            lines.append(contentsOf: try await Self.recognizeLines(image: image))
        }
        guard lines.isEmpty == false else {
            throw WorksheetTextRecognitionError.noTextFound
        }
        return lines
    }

    private static func recognizeLines(image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else {
            throw WorksheetTextRecognitionError.unreadableImage
        }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        // Funkcja jest `nonisolated async`, więc Vision pracuje poza wątkiem interfejsu.
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let preferred = ["pl-PL", "en-US", "en-GB", "de-DE"]
        let supported = (try? request.supportedRecognitionLanguages()) ?? []
        let languages = preferred.filter { supported.contains($0) }
        if languages.isEmpty == false {
            request.recognitionLanguages = languages
        }
        request.automaticallyDetectsLanguage = true

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
        try handler.perform([request])
        let observations = request.results ?? []
        return Self.orderedLines(observations: observations)
    }

    /// Składa wyniki w czytelne linie. Słowa w dwóch kolumnach (np. „cat    kot”) leżące
    /// na tej samej wysokości łączy separatorem „ – ”, żeby parser rozpoznał parę.
    private static func orderedLines(observations: [VNRecognizedTextObservation]) -> [String] {
        struct Fragment {
            let text: String
            let box: CGRect
        }
        let fragments = observations.compactMap { observation -> Fragment? in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            return Fragment(text: text, box: observation.boundingBox)
        }
        // Vision ma początek układu w lewym dolnym rogu, więc sortujemy malejąco po Y.
        let sorted = fragments.sorted { $0.box.midY > $1.box.midY }

        var rows: [[Fragment]] = []
        for fragment in sorted {
            if var last = rows.last, let anchor = last.first,
               abs(anchor.box.midY - fragment.box.midY) < max(anchor.box.height, fragment.box.height) * 0.5 {
                last.append(fragment)
                rows[rows.count - 1] = last
            } else {
                rows.append([fragment])
            }
        }

        return rows.map { row in
            let ordered = row.sorted { $0.box.minX < $1.box.minX }
            return ordered.map(\.text).joined(separator: " – ")
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
