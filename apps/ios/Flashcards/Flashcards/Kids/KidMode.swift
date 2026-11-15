import SwiftUI

/// Tryb dziecięcy: jasny, kolorowy wygląd z dużymi literami i obrazkami (emoji) na fiszkach.
/// Ustawienie jest lokalne dla urządzenia (nie synchronizuje się z kontem).
let kidModeEnabledStorageKey: String = "kidMode.enabled"

/// Kolorowa paleta trybu dziecięcego.
enum KidPalette {
    static let sun = Color(red: 1.00, green: 0.80, blue: 0.20)
    static let orange = Color(red: 1.00, green: 0.55, blue: 0.25)
    static let pink = Color(red: 1.00, green: 0.45, blue: 0.65)
    static let purple = Color(red: 0.62, green: 0.45, blue: 0.95)
    static let sky = Color(red: 0.35, green: 0.70, blue: 1.00)
    static let mint = Color(red: 0.35, green: 0.85, blue: 0.65)
    static let grass = Color(red: 0.45, green: 0.80, blue: 0.30)

    /// Pastelowe gradienty kart: przód jest „słoneczny”, tył „niebiesko-miętowy”.
    static var frontGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 1.00, green: 0.95, blue: 0.70), Color(red: 1.00, green: 0.82, blue: 0.70)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    static var backGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.78, green: 0.92, blue: 1.00), Color(red: 0.78, green: 1.00, blue: 0.88)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let rainbow: [Color] = [pink, orange, sun, grass, mint, sky, purple]

    /// Stały (dla danego tekstu) kolor z tęczy – kolejne fiszki mają różne kolory.
    static func color(seed: String) -> Color {
        rainbow[kidStableIndex(seed: seed, count: rainbow.count)]
    }
}

/// Deterministyczny indeks z tekstu (`hashValue` w Swift zmienia się po każdym uruchomieniu).
func kidStableIndex(seed: String, count: Int) -> Int {
    guard count > 0 else { return 0 }
    var value: UInt64 = 5381
    for scalar in seed.unicodeScalars {
        value = (value &* 33) &+ UInt64(scalar.value)
    }
    return Int(value % UInt64(count))
}

/// Duży obrazek nad przodem fiszki w trybie dziecięcym.
struct KidCardPictureBanner: View {
    let frontText: String
    let backText: String

    var body: some View {
        let emoji = kidEmoji(frontText: self.frontText, backText: self.backText)
        Text(emoji)
            .font(.system(size: 88))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                KidPalette.color(seed: self.frontText).opacity(0.25),
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

/// Emoji pasujące do słowa z fiszki; gdy żadne nie pasuje – wesołe zwierzątko,
/// zawsze to samo dla tej samej fiszki.
func kidEmoji(frontText: String, backText: String) -> String {
    if let leading = leadingEmoji(text: frontText) ?? leadingEmoji(text: backText) {
        return leading
    }
    if let matched = kidMatchingEmoji(text: frontText) ?? kidMatchingEmoji(text: backText) {
        return matched
    }
    return kidFallbackEmoji[kidStableIndex(seed: frontText, count: kidFallbackEmoji.count)]
}

/// Emoji dopasowane do pierwszego rozpoznanego słowa w tekście albo nil.
func kidMatchingEmoji(text: String) -> String? {
    let words = text
        .lowercased()
        .components(separatedBy: CharacterSet.letters.inverted)
        .filter { $0.isEmpty == false }
    for word in words {
        if let emoji = kidEmojiDictionary[word] {
            return emoji
        }
        // Proste końcówki liczby mnogiej: cats → cat, koty → kot.
        for suffix in ["es", "s", "y", "i", "e", "a"] where word.count > suffix.count + 2 && word.hasSuffix(suffix) {
            if let emoji = kidEmojiDictionary[String(word.dropLast(suffix.count))] {
                return emoji
            }
        }
    }
    return nil
}

private func leadingEmoji(text: String) -> String? {
    guard let first = text.trimmingCharacters(in: .whitespacesAndNewlines).first else { return nil }
    // Część emoji (np. 🖍️ ✏️ ☀️) ma „wariant emoji” zapisany dodatkowym znakiem U+FE0F.
    let isEmoji = first.unicodeScalars.contains { $0.properties.isEmojiPresentation || $0.value == 0xFE0F }
    return isEmoji ? String(first) : nil
}

private let kidFallbackEmoji: [String] = [
    "🦊", "🐼", "🐨", "🐸", "🦁", "🐯", "🐵", "🐧", "🦄", "🐙", "🐢", "🦋", "🐝", "🐬", "🦉", "🐰",
]

/// Słowniczek: angielskie i polskie słowa → emoji. Można go dowolnie rozszerzać.
let kidEmojiDictionary: [String: String] = {
    let groups: [(String, [String])] = [
        // Zwierzęta
        ("🐱", ["cat", "kot", "kotek", "kitten"]),
        ("🐶", ["dog", "pies", "piesek", "puppy"]),
        ("🐭", ["mouse", "mysz", "myszka"]),
        ("🐰", ["rabbit", "bunny", "królik", "zając", "zajączek"]),
        ("🐻", ["bear", "miś", "niedźwiedź"]),
        ("🐼", ["panda"]),
        ("🦁", ["lion", "lew"]),
        ("🐯", ["tiger", "tygrys"]),
        ("🐮", ["cow", "krowa"]),
        ("🐷", ["pig", "świnia", "świnka"]),
        ("🐸", ["frog", "żaba"]),
        ("🐵", ["monkey", "małpa", "małpka"]),
        ("🐔", ["chicken", "hen", "kura", "kurczak"]),
        ("🐦", ["bird", "ptak", "ptaszek"]),
        ("🦆", ["duck", "kaczka"]),
        ("🐴", ["horse", "koń", "konik"]),
        ("🐑", ["sheep", "owca", "owieczka"]),
        ("🐐", ["goat", "koza"]),
        ("🐟", ["fish", "ryba", "rybka"]),
        ("🐘", ["elephant", "słoń"]),
        ("🦒", ["giraffe", "żyrafa"]),
        ("🦓", ["zebra"]),
        ("🐍", ["snake", "wąż"]),
        ("🐢", ["turtle", "tortoise", "żółw"]),
        ("🦋", ["butterfly", "motyl"]),
        ("🐝", ["bee", "pszczoła"]),
        ("🐞", ["ladybird", "ladybug", "biedronka"]),
        ("🕷️", ["spider", "pająk"]),
        ("🐧", ["penguin", "pingwin"]),
        ("🦊", ["fox", "lis"]),
        ("🐺", ["wolf", "wilk"]),
        ("🦉", ["owl", "sowa"]),
        ("🐬", ["dolphin", "delfin"]),
        ("🐳", ["whale", "wieloryb"]),
        ("🦈", ["shark", "rekin"]),
        ("🐙", ["octopus", "ośmiornica"]),
        ("🦀", ["crab", "krab"]),
        ("🐊", ["crocodile", "krokodyl"]),
        ("🦖", ["dinosaur", "dino", "dinozaur"]),
        ("🐹", ["hamster", "chomik"]),
        ("🦔", ["hedgehog", "jeż"]),
        ("🐿️", ["squirrel", "wiewiórka"]),
        ("🦄", ["unicorn", "jednorożec"]),
        ("🐉", ["dragon", "smok"]),
        // Jedzenie
        ("🍎", ["apple", "jabłko"]),
        ("🍌", ["banana", "banan"]),
        ("🍊", ["orange", "pomarańcza"]),
        ("🍐", ["pear", "gruszka"]),
        ("🍇", ["grapes", "grape", "winogrono", "winogrona"]),
        ("🍓", ["strawberry", "truskawka"]),
        ("🍒", ["cherry", "wiśnia", "czereśnia"]),
        ("🍋", ["lemon", "cytryna"]),
        ("🍉", ["watermelon", "arbuz"]),
        ("🍍", ["pineapple", "ananas"]),
        ("🥕", ["carrot", "marchew", "marchewka"]),
        ("🍅", ["tomato", "pomidor"]),
        ("🥔", ["potato", "ziemniak"]),
        ("🥒", ["cucumber", "ogórek"]),
        ("🌽", ["corn", "kukurydza"]),
        ("🍞", ["bread", "chleb"]),
        ("🧀", ["cheese", "ser"]),
        ("🥚", ["egg", "jajko", "jajo"]),
        ("🥛", ["milk", "mleko"]),
        ("💧", ["water", "woda"]),
        ("🧃", ["juice", "sok"]),
        ("🍕", ["pizza"]),
        ("🍦", ["ice", "lody", "lód"]),
        ("🍰", ["cake", "ciasto", "tort"]),
        ("🍪", ["cookie", "biscuit", "ciastko", "ciasteczko"]),
        ("🍫", ["chocolate", "czekolada"]),
        ("🍬", ["sweet", "sweets", "candy", "cukierek"]),
        ("🍯", ["honey", "miód"]),
        ("🥣", ["soup", "zupa"]),
        // Szkoła i dom
        ("🏫", ["school", "szkoła"]),
        ("📚", ["book", "książka"]),
        ("✏️", ["pencil", "ołówek"]),
        ("🖊️", ["pen", "długopis"]),
        ("🖍️", ["crayon", "kredka"]),
        ("📏", ["ruler", "linijka"]),
        ("🎒", ["bag", "backpack", "schoolbag", "plecak", "tornister"]),
        ("📓", ["notebook", "zeszyt"]),
        ("✂️", ["scissors", "nożyczki"]),
        ("🏠", ["house", "home", "dom", "domek"]),
        ("🚪", ["door", "drzwi"]),
        ("🪟", ["window", "okno"]),
        ("🪑", ["chair", "krzesło"]),
        ("🛏️", ["bed", "łóżko"]),
        ("🛁", ["bath", "wanna", "kąpiel"]),
        ("🧸", ["teddy", "toy", "zabawka", "misio"]),
        ("⚽", ["ball", "football", "piłka"]),
        ("🎈", ["balloon", "balon", "balonik"]),
        ("🪁", ["kite", "latawiec"]),
        ("🎁", ["present", "gift", "prezent"]),
        ("🎂", ["birthday", "urodziny"]),
        ("📱", ["phone", "telefon"]),
        ("💻", ["computer", "komputer"]),
        ("📺", ["tv", "television", "telewizor"]),
        ("⏰", ["clock", "zegar", "zegarek"]),
        ("🔑", ["key", "klucz"]),
        // Ubrania
        ("👕", ["shirt", "koszulka", "koszula"]),
        ("👖", ["trousers", "jeans", "spodnie"]),
        ("👗", ["dress", "sukienka"]),
        ("🧢", ["cap", "czapka"]),
        ("🎩", ["hat", "kapelusz"]),
        ("👟", ["shoe", "shoes", "but", "buty"]),
        ("🧦", ["sock", "socks", "skarpetka", "skarpetki"]),
        ("🧤", ["gloves", "rękawiczki"]),
        ("🧣", ["scarf", "szalik"]),
        ("🧥", ["coat", "jacket", "kurtka", "płaszcz"]),
        // Przyroda i pogoda
        ("☀️", ["sun", "sunny", "słońce", "słoneczko"]),
        ("🌙", ["moon", "księżyc"]),
        ("⭐", ["star", "gwiazda", "gwiazdka"]),
        ("☁️", ["cloud", "chmura"]),
        ("🌧️", ["rain", "rainy", "deszcz"]),
        ("❄️", ["snow", "śnieg"]),
        ("⛄", ["snowman", "bałwan"]),
        ("🌈", ["rainbow", "tęcza"]),
        ("⚡", ["storm", "burza"]),
        ("💨", ["wind", "windy", "wiatr"]),
        ("🌳", ["tree", "drzewo"]),
        ("🌸", ["flower", "kwiat", "kwiatek"]),
        ("🌹", ["rose", "róża"]),
        ("🍄", ["mushroom", "grzyb"]),
        ("🍂", ["autumn", "jesień", "leaf", "liść"]),
        ("🌷", ["spring", "wiosna"]),
        ("🏖️", ["summer", "lato", "beach", "plaża"]),
        ("🌨️", ["winter", "zima"]),
        ("🌊", ["sea", "morze", "ocean"]),
        ("⛰️", ["mountain", "góra", "góry"]),
        ("🔥", ["fire", "ogień"]),
        ("🌍", ["world", "earth", "ziemia", "świat"]),
        // Transport
        ("🚗", ["car", "auto", "samochód"]),
        ("🚌", ["bus", "autobus"]),
        ("🚂", ["train", "pociąg"]),
        ("✈️", ["plane", "airplane", "samolot"]),
        ("🚲", ["bike", "bicycle", "rower"]),
        ("🚢", ["ship", "statek"]),
        ("⛵", ["boat", "łódka", "łódź"]),
        ("🚀", ["rocket", "rakieta"]),
        ("🚒", ["firetruck", "straż"]),
        // Ludzie i rodzina
        ("👩", ["mum", "mom", "mother", "mama"]),
        ("👨", ["dad", "father", "tata"]),
        ("👵", ["grandma", "granny", "babcia"]),
        ("👴", ["grandpa", "dziadek"]),
        ("👶", ["baby", "dzidziuś", "niemowlę"]),
        ("👧", ["girl", "dziewczynka", "sister", "siostra"]),
        ("👦", ["boy", "chłopiec", "brother", "brat"]),
        ("👨‍👩‍👧", ["family", "rodzina"]),
        ("🧑‍🏫", ["teacher", "nauczyciel", "nauczycielka", "pani"]),
        ("👫", ["friend", "przyjaciel", "kolega", "koleżanka"]),
        // Ciało
        ("👀", ["eye", "eyes", "oko", "oczy"]),
        ("👂", ["ear", "ucho", "uszy"]),
        ("👃", ["nose", "nos"]),
        ("👄", ["mouth", "usta"]),
        ("✋", ["hand", "ręka", "dłoń"]),
        ("🦶", ["foot", "feet", "stopa"]),
        ("🦷", ["tooth", "teeth", "ząb", "zęby"]),
        ("❤️", ["heart", "serce", "love", "kocham"]),
        // Kolory
        ("🔴", ["red", "czerwony", "czerwona"]),
        ("🔵", ["blue", "niebieski", "niebieska"]),
        ("🟢", ["green", "zielony", "zielona"]),
        ("🟡", ["yellow", "żółty", "żółta"]),
        ("🟣", ["purple", "fioletowy", "fioletowa"]),
        ("🟤", ["brown", "brązowy", "brązowa"]),
        ("⚫", ["black", "czarny", "czarna"]),
        ("⚪", ["white", "biały", "biała"]),
        ("🩷", ["pink", "różowy", "różowa"]),
        // Liczby
        ("1️⃣", ["one", "jeden", "jedna"]),
        ("2️⃣", ["two", "dwa", "dwie"]),
        ("3️⃣", ["three", "trzy"]),
        ("4️⃣", ["four", "cztery"]),
        ("5️⃣", ["five", "pięć"]),
        ("6️⃣", ["six", "sześć"]),
        ("7️⃣", ["seven", "siedem"]),
        ("8️⃣", ["eight", "osiem"]),
        ("9️⃣", ["nine", "dziewięć"]),
        ("🔟", ["ten", "dziesięć"]),
        // Czynności i uczucia
        ("😀", ["happy", "wesoły", "szczęśliwy", "radość"]),
        ("😢", ["sad", "smutny", "smutna"]),
        ("😠", ["angry", "zły", "zła"]),
        ("😴", ["sleep", "sleepy", "tired", "spać", "śpi", "zmęczony"]),
        ("🏃", ["run", "biegać", "biegnie"]),
        ("🏊", ["swim", "pływać"]),
        ("💃", ["dance", "tańczyć"]),
        ("🎤", ["sing", "śpiewać"]),
        ("🎨", ["paint", "draw", "malować", "rysować"]),
        ("📖", ["read", "czytać", "czytanie"]),
        ("✍️", ["write", "pisać", "pisanie"]),
        ("🧮", ["count", "liczyć", "dodawanie", "odejmowanie", "math", "matematyka"]),
        ("🍽️", ["eat", "jeść"]),
        ("🥤", ["drink", "pić"]),
        ("🎮", ["play", "game", "bawić", "grać", "gra"]),
        ("🎵", ["music", "muzyka", "song", "piosenka"]),
    ]
    var dictionary: [String: String] = [:]
    for (emoji, words) in groups {
        for word in words where dictionary[word] == nil {
            dictionary[word] = emoji
        }
    }
    return dictionary
}()
