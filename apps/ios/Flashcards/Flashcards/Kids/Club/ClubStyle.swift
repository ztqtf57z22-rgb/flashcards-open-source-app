import Foundation
import Observation
import SwiftUI

// MARK: - Styl ilustracji

/// Styl, w jakim Claude rysuje obrazki do słówek. Rysunki każdego stylu są zapisywane osobno,
/// więc po przełączeniu stylu wcześniejsze rysunki nie giną.
enum ClubIllustrationStyle: String, CaseIterable, Identifiable, Sendable {
    case textbook
    case cuteGoth
    case pastelKawaii

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .textbook: "Podręcznik"
        case .cuteGoth: "Słodki gotyk z Nocką"
        case .pastelKawaii: "Pastelowe kawaii"
        }
    }

    var subtitle: String {
        switch self {
        case .textbook: "Czytelne, kolorowe obrazki jak w podręczniku"
        case .cuteGoth: "Fiolet, róż i czerń, buźki, skrzydełka, gwiazdki; czasem pojawia się Nocka"
        case .pastelKawaii: "Miękkie pastele, uśmiechnięte buźki, serduszka"
        }
    }

    /// Przykładowy rysunek (kredka) pokazywany przy wyborze stylu.
    var sampleSVG: String {
        switch self {
        case .textbook: clubSampleTextbookPencil
        case .cuteGoth: clubSampleCuteGothPencil
        case .pastelKawaii: clubSamplePastelPencil
        }
    }

    /// Fragment polecenia dla Claude opisujący styl.
    var promptDescription: String {
        switch self {
        case .textbook:
            return """
            Styl „Podręcznik”: płaska grafika wektorowa jak w dobrym podręczniku dla dzieci, jasne i radosne \
            kolory, wyraźny ciemny kontur. Przedmioty bez buziek – realistyczne proporcje, prosto i czytelnie.
            """
        case .cuteGoth:
            return """
            Styl „Słodki gotyk”: paleta fiolet (#8e5cc7, #a88bd9, #4a3566), róż (#ff5fa8, #ff8fc6), czerń \
            (#2b2b2b) i akcenty żółte (#ffd84d); tło jasnolawendowe koło (#f3e8ff). Przedmioty mogą mieć \
            słodkie buźki (duże czarne oczka z białym błyskiem, różowe rumieńce, mały uśmiech), małe \
            nietoperzowe skrzydełka, gwiazdki i serduszka wokół. Nic strasznego: bez czaszek, krwi i potworów.
            Mniej więcej na co trzecim rysunku pojawia się maskotka klubu – NOCKA: mały okrągły fioletowy \
            nietoperek (#a88bd9) z jaśniejszym brzuszkiem (#d9c9f5), dwoma spiczastymi uszkami z różowym \
            środkiem, ciemnymi skrzydełkami (#4a3566), dużymi czarnymi oczami z białym błyskiem, różowymi \
            rumieńcami, uśmiechem z jednym małym białym kłykiem i żółtą gwiazdką przy uchu. Nocka trzyma, \
            pokazuje lub używa rysowanego przedmiotu, ale przedmiot zawsze musi być dobrze widoczny.
            """
        case .pastelKawaii:
            return """
            Styl „Pastelowe kawaii”: miękkie pastelowe kolory (mięta #a8e6cf, brzoskwinia #ffd3b6, róż \
            #ffaaa5, błękit #a0d2eb, lawenda #d4c1ec, jasna żółć #fff5ba), zaokrąglone kształty, cienki \
            kontur w kolorze #5a4a5e. Przedmioty mają słodkie buźki (małe czarne oczka, rumieńce, uśmiech), \
            wokół drobne serduszka lub iskierki. Delikatnie i radośnie.
            """
        }
    }
}

/// Wybrany styl (zapisywany w UserDefaults bez @AppStorage – patrz KidModeSettings).
@MainActor
@Observable
final class ClubStyleSettings {
    static let shared = ClubStyleSettings()

    var style: ClubIllustrationStyle {
        didSet {
            UserDefaults.standard.set(self.style.rawValue, forKey: Self.key)
        }
    }

    private static let key = "club.illustrationStyle"

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.key).flatMap(ClubIllustrationStyle.init(rawValue:))
        self.style = stored ?? .textbook
    }
}

// MARK: - Maskotka Nocka

/// Nocka – maskotka klubu (oryginalna postać: fioletowy nietoperek z wielką kredką).
struct ClubMascotView: View {
    var size: CGFloat
    var holdsCrayon: Bool = true

    var body: some View {
        if let drawing = ClubSVGCache.drawing(for: self.holdsCrayon ? clubNockaWithCrayonSVG : clubNockaWavingSVG) {
            ClubSVGView(drawing: drawing)
                .frame(width: self.size, height: self.size)
                .accessibilityLabel("Nocka")
        }
    }
}

// MARK: - Rysunki SVG (format obsługiwany przez ClubSVG)

let clubNockaWithCrayonSVG: String = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
<path d="M34 52 C24 42 12 42 6 48 C11 49 12 53 10 56 C15 54 19 57 19 61 C23 58 28 59 31 62 Z" fill="#4a3566" stroke="#2b2b2b" stroke-width="1.8" stroke-linejoin="round"/>
<path d="M66 52 C76 42 88 42 94 48 C89 49 88 53 90 56 C85 54 81 57 81 61 C77 58 72 59 69 62 Z" fill="#4a3566" stroke="#2b2b2b" stroke-width="1.8" stroke-linejoin="round"/>
<ellipse cx="50" cy="70" rx="17" ry="15" fill="#a88bd9" stroke="#2b2b2b" stroke-width="2"/>
<ellipse cx="50" cy="73" rx="10" ry="8" fill="#d9c9f5"/>
<polygon points="34,30 31,12 44,24" fill="#a88bd9" stroke="#2b2b2b" stroke-width="2" stroke-linejoin="round"/>
<polygon points="66,30 69,12 56,24" fill="#a88bd9" stroke="#2b2b2b" stroke-width="2" stroke-linejoin="round"/>
<polygon points="35,26 33.5,17 40,23" fill="#ff8fc6"/>
<polygon points="65,26 66.5,17 60,23" fill="#ff8fc6"/>
<circle cx="50" cy="41" r="19" fill="#a88bd9" stroke="#2b2b2b" stroke-width="2"/>
<polygon points="70,15 71.4,18.6 75.2,18.6 72.2,21 73.3,24.7 70,22.5 66.7,24.7 67.8,21 64.8,18.6 68.6,18.6" fill="#ffd84d" stroke="#2b2b2b" stroke-width="1" stroke-linejoin="round"/>
<ellipse cx="43" cy="40" rx="4.4" ry="5.4" fill="#2b2b2b"/>
<ellipse cx="57" cy="40" rx="4.4" ry="5.4" fill="#2b2b2b"/>
<circle cx="44.5" cy="38" r="1.5" fill="#ffffff"/>
<circle cx="58.5" cy="38" r="1.5" fill="#ffffff"/>
<ellipse cx="37" cy="47" rx="3.2" ry="1.9" fill="#ff8fc6" opacity="0.9"/>
<ellipse cx="63" cy="47" rx="3.2" ry="1.9" fill="#ff8fc6" opacity="0.9"/>
<path d="M45.5 48 Q50 52 54.5 48" fill="none" stroke="#2b2b2b" stroke-width="1.5" stroke-linecap="round"/>
<polygon points="47.6,49.6 49.2,49.9 48.3,52" fill="#ffffff" stroke="#2b2b2b" stroke-width="0.8" stroke-linejoin="round"/>
<g transform="rotate(-38 50 70)">
<rect x="12" y="64" width="9" height="12" rx="3.5" fill="#ff8fc6" stroke="#2b2b2b" stroke-width="2"/>
<rect x="20" y="63.5" width="7" height="13" rx="1.2" fill="#d9d3e6" stroke="#2b2b2b" stroke-width="2"/>
<rect x="26" y="63" width="50" height="14" rx="1.5" fill="#ff5fa8" stroke="#2b2b2b" stroke-width="2"/>
<rect x="27" y="64" width="48" height="3.5" fill="#ff8fc6"/>
<polygon points="76,63 90,70 76,77" fill="#f4d3a1" stroke="#2b2b2b" stroke-width="2" stroke-linejoin="round"/>
<polygon points="85.5,67.4 90,70 85.5,72.6" fill="#c2185b" stroke="#2b2b2b" stroke-width="1.4" stroke-linejoin="round"/>
</g>
<ellipse cx="40" cy="69" rx="4.5" ry="3.8" fill="#a88bd9" stroke="#2b2b2b" stroke-width="1.8"/>
<ellipse cx="58" cy="60" rx="4.5" ry="3.8" fill="#a88bd9" stroke="#2b2b2b" stroke-width="1.8"/>
<ellipse cx="43" cy="86" rx="5" ry="3" fill="#4a3566" stroke="#2b2b2b" stroke-width="1.6"/>
<ellipse cx="57" cy="86" rx="5" ry="3" fill="#4a3566" stroke="#2b2b2b" stroke-width="1.6"/>
</svg>
"""

/// Nocka machająca łapką – do pochwał w quizie.
let clubNockaWavingSVG: String = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
<path d="M34 52 C24 42 12 42 6 48 C11 49 12 53 10 56 C15 54 19 57 19 61 C23 58 28 59 31 62 Z" fill="#4a3566" stroke="#2b2b2b" stroke-width="1.8" stroke-linejoin="round"/>
<path d="M66 52 C76 42 88 42 94 48 C89 49 88 53 90 56 C85 54 81 57 81 61 C77 58 72 59 69 62 Z" fill="#4a3566" stroke="#2b2b2b" stroke-width="1.8" stroke-linejoin="round"/>
<ellipse cx="50" cy="70" rx="17" ry="15" fill="#a88bd9" stroke="#2b2b2b" stroke-width="2"/>
<ellipse cx="50" cy="73" rx="10" ry="8" fill="#d9c9f5"/>
<polygon points="34,30 31,12 44,24" fill="#a88bd9" stroke="#2b2b2b" stroke-width="2" stroke-linejoin="round"/>
<polygon points="66,30 69,12 56,24" fill="#a88bd9" stroke="#2b2b2b" stroke-width="2" stroke-linejoin="round"/>
<polygon points="35,26 33.5,17 40,23" fill="#ff8fc6"/>
<polygon points="65,26 66.5,17 60,23" fill="#ff8fc6"/>
<circle cx="50" cy="41" r="19" fill="#a88bd9" stroke="#2b2b2b" stroke-width="2"/>
<polygon points="70,15 71.4,18.6 75.2,18.6 72.2,21 73.3,24.7 70,22.5 66.7,24.7 67.8,21 64.8,18.6 68.6,18.6" fill="#ffd84d" stroke="#2b2b2b" stroke-width="1" stroke-linejoin="round"/>
<path d="M39 41 Q43 36 47 41" fill="none" stroke="#2b2b2b" stroke-width="2" stroke-linecap="round"/>
<path d="M53 41 Q57 36 61 41" fill="none" stroke="#2b2b2b" stroke-width="2" stroke-linecap="round"/>
<ellipse cx="37" cy="47" rx="3.2" ry="1.9" fill="#ff8fc6" opacity="0.9"/>
<ellipse cx="63" cy="47" rx="3.2" ry="1.9" fill="#ff8fc6" opacity="0.9"/>
<path d="M44 47 Q50 54 56 47 Z" fill="#c2185b" stroke="#2b2b2b" stroke-width="1.4" stroke-linejoin="round"/>
<polygon points="46.5,47.3 48.3,47.6 47.3,50" fill="#ffffff" stroke="#2b2b2b" stroke-width="0.8" stroke-linejoin="round"/>
<ellipse cx="36" cy="72" rx="4.5" ry="3.8" fill="#a88bd9" stroke="#2b2b2b" stroke-width="1.8"/>
<ellipse cx="70" cy="56" rx="4.5" ry="3.8" fill="#a88bd9" stroke="#2b2b2b" stroke-width="1.8" transform="rotate(-30 70 56)"/>
<polygon points="80,40 81.2,43 84.4,43 81.8,45 82.8,48 80,46.2 77.2,48 78.2,45 75.6,43 78.8,43" fill="#ffd84d" stroke="#2b2b2b" stroke-width="1" stroke-linejoin="round"/>
<ellipse cx="43" cy="86" rx="5" ry="3" fill="#4a3566" stroke="#2b2b2b" stroke-width="1.6"/>
<ellipse cx="57" cy="86" rx="5" ry="3" fill="#4a3566" stroke="#2b2b2b" stroke-width="1.6"/>
</svg>
"""

let clubSampleTextbookPencil: String = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
<g transform="rotate(-30 50 50)">
<rect x="8" y="42" width="10" height="16" rx="3" fill="#f48fb1" stroke="#2b2b2b" stroke-width="2.5"/>
<rect x="17" y="41" width="8" height="18" rx="1" fill="#cfd8dc" stroke="#2b2b2b" stroke-width="2.5"/>
<rect x="24" y="40" width="50" height="20" rx="1.5" fill="#1e88e5" stroke="#2b2b2b" stroke-width="2.5"/>
<rect x="25" y="41.5" width="48" height="5" fill="#64b5f6"/>
<polygon points="74,40 92,50 74,60" fill="#ffe0b2" stroke="#2b2b2b" stroke-width="2.5" stroke-linejoin="round"/>
<polygon points="86,46.7 92,50 86,53.3" fill="#1565c0" stroke="#2b2b2b" stroke-width="2" stroke-linejoin="round"/>
</g>
</svg>
"""

let clubSampleCuteGothPencil: String = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
<circle cx="50" cy="50" r="44" fill="#f3e8ff" stroke="#2b2b2b" stroke-width="1.5"/>
<polygon points="16,22 18,27 23,27 19,30 20.5,35 16,32 11.5,35 13,30 9,27 14,27" fill="#ffd84d" stroke="#2b2b2b" stroke-width="1" stroke-linejoin="round"/>
<path d="M78 20 C78 17 82 16 83 19 C84 16 88 17 88 20 C88 24 83 26 83 28 C83 26 78 24 78 20 Z" fill="#ff5fa8" stroke="#2b2b2b" stroke-width="1" stroke-linejoin="round"/>
<g transform="rotate(-30 50 52)">
<path d="M38 41 C33 33 25 32 20 35 C24 36 25 39 23 41 C27 40 30 42 30 45 C33 43 36 43 38 45 Z" fill="#3b2f4a" stroke="#2b2b2b" stroke-width="1.5" stroke-linejoin="round"/>
<path d="M58 41 C63 33 71 32 76 35 C72 36 71 39 73 41 C69 40 66 42 66 45 C63 43 60 43 58 45 Z" fill="#3b2f4a" stroke="#2b2b2b" stroke-width="1.5" stroke-linejoin="round"/>
<rect x="5" y="44" width="11" height="16" rx="4" fill="#ff8fc6" stroke="#2b2b2b" stroke-width="2"/>
<rect x="14" y="43" width="9" height="18" rx="1.5" fill="#d9d3e6" stroke="#2b2b2b" stroke-width="2"/>
<rect x="22" y="42" width="52" height="20" rx="2" fill="#8e5cc7" stroke="#2b2b2b" stroke-width="2"/>
<rect x="23" y="43" width="50" height="4.5" fill="#a97ce0"/>
<polygon points="74,42 90,52 74,62" fill="#f4d3a1" stroke="#2b2b2b" stroke-width="2" stroke-linejoin="round"/>
<polygon points="84,48.3 90,52 84,55.7" fill="#5b2d8a" stroke="#2b2b2b" stroke-width="1.5" stroke-linejoin="round"/>
<ellipse cx="42" cy="51" rx="2.6" ry="3.4" fill="#2b2b2b"/>
<ellipse cx="54" cy="51" rx="2.6" ry="3.4" fill="#2b2b2b"/>
<circle cx="43" cy="49.6" r="0.9" fill="#ffffff"/>
<circle cx="55" cy="49.6" r="0.9" fill="#ffffff"/>
<ellipse cx="37" cy="56" rx="3" ry="1.8" fill="#ff8fc6" opacity="0.85"/>
<ellipse cx="59" cy="56" rx="3" ry="1.8" fill="#ff8fc6" opacity="0.85"/>
<path d="M45 56 Q48 59 51 56" fill="none" stroke="#2b2b2b" stroke-width="1.4" stroke-linecap="round"/>
</g>
</svg>
"""

let clubSamplePastelPencil: String = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
<circle cx="50" cy="50" r="44" fill="#fff5ba" stroke="#5a4a5e" stroke-width="1.2"/>
<path d="M18 26 C18 24 21 23.5 21.5 25.5 C22 23.5 25 24 25 26 C25 28.5 21.5 30 21.5 31.5 C21.5 30 18 28.5 18 26 Z" fill="#ffaaa5" stroke="#5a4a5e" stroke-width="1"/>
<polygon points="82,70 83,72.5 85.5,73 83.5,74.5 84,77 82,75.6 80,77 80.5,74.5 78.5,73 81,72.5" fill="#a0d2eb" stroke="#5a4a5e" stroke-width="0.8" stroke-linejoin="round"/>
<g transform="rotate(-30 50 50)">
<rect x="8" y="41" width="11" height="18" rx="5" fill="#ffaaa5" stroke="#5a4a5e" stroke-width="1.8"/>
<rect x="17" y="40.5" width="8" height="19" rx="2" fill="#d4c1ec" stroke="#5a4a5e" stroke-width="1.8"/>
<rect x="24" y="40" width="50" height="20" rx="4" fill="#a8e6cf" stroke="#5a4a5e" stroke-width="1.8"/>
<polygon points="74,40.5 91,50 74,59.5" fill="#ffd3b6" stroke="#5a4a5e" stroke-width="1.8" stroke-linejoin="round"/>
<polygon points="85.5,46.9 91,50 85.5,53.1" fill="#5fb89a" stroke="#5a4a5e" stroke-width="1.4" stroke-linejoin="round"/>
<circle cx="43" cy="49" r="1.8" fill="#5a4a5e"/>
<circle cx="55" cy="49" r="1.8" fill="#5a4a5e"/>
<ellipse cx="38.5" cy="53.5" rx="2.6" ry="1.6" fill="#ffaaa5"/>
<ellipse cx="59.5" cy="53.5" rx="2.6" ry="1.6" fill="#ffaaa5"/>
<path d="M46.5 53 Q49 55.5 51.5 53" fill="none" stroke="#5a4a5e" stroke-width="1.3" stroke-linecap="round"/>
</g>
</svg>
"""
