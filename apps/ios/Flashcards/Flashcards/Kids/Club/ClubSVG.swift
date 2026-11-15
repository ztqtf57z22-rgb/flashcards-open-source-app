import Foundation
import SwiftUI

// Lekki renderer SVG dla ilustracji rysowanych przez Claude.
// iOS nie potrafi wyświetlić dowolnego SVG z tekstu, więc obsługujemy podzbiór, o który prosimy Claude:
// g, rect, circle, ellipse, line, polyline, polygon, path (M L H V C S Q T A Z), transform
// (translate, rotate, scale, matrix), kolory #rgb/#rrggbb/rgb()/nazwy oraz podstawowe style.

/// Gotowy do narysowania obrazek: kształty już w układzie współrzędnych viewBox.
struct ClubSVGDrawing: @unchecked Sendable {
    let viewBox: CGRect
    let items: [ClubSVGItem]
}

struct ClubSVGItem: @unchecked Sendable {
    let path: Path
    let fill: Color?
    let stroke: Color?
    let lineWidth: CGFloat
    let lineCap: CGLineCap
    let lineJoin: CGLineJoin
    let evenOdd: Bool
}

// MARK: - Widoki

/// Obrazek słówka: rysunek od Claude, a gdy go nie ma (lub się nie wczytał) – emoji.
struct ClubWordPicture: View {
    let word: ClubWord
    var size: CGFloat

    var body: some View {
        if let svg = self.word.picture(preferring: ClubStyleSettings.shared.style),
           let drawing = ClubSVGCache.drawing(for: svg) {
            ClubSVGView(drawing: drawing)
                .frame(width: self.size, height: self.size)
                .accessibilityHidden(true)
        } else {
            Text(self.word.emoji)
                .font(.system(size: self.size * 0.75))
                .minimumScaleFactor(0.3)
                .lineLimit(1)
                .frame(width: self.size, height: self.size)
                .accessibilityHidden(true)
        }
    }
}

struct ClubSVGView: View {
    let drawing: ClubSVGDrawing

    var body: some View {
        let drawing = self.drawing
        Canvas { context, size in
            let viewBox = drawing.viewBox
            guard viewBox.width > 0, viewBox.height > 0 else { return }
            let scale = min(size.width / viewBox.width, size.height / viewBox.height)
            context.translateBy(
                x: (size.width - viewBox.width * scale) / 2,
                y: (size.height - viewBox.height * scale) / 2
            )
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -viewBox.minX, y: -viewBox.minY)
            for item in drawing.items {
                if let fill = item.fill {
                    context.fill(item.path, with: .color(fill), style: FillStyle(eoFill: item.evenOdd))
                }
                if let stroke = item.stroke, item.lineWidth > 0 {
                    context.stroke(
                        item.path,
                        with: .color(stroke),
                        style: StrokeStyle(lineWidth: item.lineWidth, lineCap: item.lineCap, lineJoin: item.lineJoin)
                    )
                }
            }
        }
    }
}

/// Pamięć podręczna sparsowanych rysunków (parsowanie jest szybkie, ale widoki odświeżają się często).
@MainActor
enum ClubSVGCache {
    private static var drawings: [String: ClubSVGDrawing] = [:]
    private static var failures: Set<String> = []

    static func drawing(for svg: String) -> ClubSVGDrawing? {
        if let cached = self.drawings[svg] {
            return cached
        }
        if self.failures.contains(svg) {
            return nil
        }
        if let parsed = parseClubSVG(svg), parsed.items.isEmpty == false {
            self.drawings[svg] = parsed
            return parsed
        }
        self.failures.insert(svg)
        return nil
    }
}

// MARK: - Parser XML

func parseClubSVG(_ svg: String) -> ClubSVGDrawing? {
    guard let data = svg.data(using: .utf8) else { return nil }
    let builder = ClubSVGBuilder()
    let parser = XMLParser(data: data)
    parser.delegate = builder
    parser.shouldProcessNamespaces = false
    guard parser.parse() || builder.items.isEmpty == false else { return nil }
    return builder.finish()
}

private enum ClubSVGPaint {
    case none
    case color(Color)
    case reference(String)
}

private struct ClubSVGStyle {
    var fill: ClubSVGPaint = .color(.black)
    var stroke: ClubSVGPaint = .none
    var strokeWidth: CGFloat = 1
    var opacity: Double = 1
    var fillOpacity: Double = 1
    var strokeOpacity: Double = 1
    var lineCap: CGLineCap = .butt
    var lineJoin: CGLineJoin = .miter
    var evenOdd: Bool = false
    var transform: CGAffineTransform = .identity
}

private struct ClubSVGPendingItem {
    let path: Path
    let style: ClubSVGStyle
    let hasFill: Bool
}

private final class ClubSVGBuilder: NSObject, XMLParserDelegate {
    private(set) var items: [ClubSVGPendingItem] = []
    private var styleStack: [ClubSVGStyle] = [ClubSVGStyle()]
    private var viewBox: CGRect?
    private var gradientFirstStop: [String: Color] = [:]
    private var currentGradientId: String?
    private var skipDepth: Int = 0

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes: [String: String]
    ) {
        let name = elementName.lowercased().components(separatedBy: ":").last ?? elementName
        let parent = self.styleStack.last ?? ClubSVGStyle()

        if self.skipDepth > 0 {
            self.skipDepth += 1
            self.styleStack.append(parent)
            if name == "stop", let id = self.currentGradientId, self.gradientFirstStop[id] == nil {
                let styleAttributes = clubSVGStyleAttributes(attributes)
                if let color = clubSVGColor(styleAttributes["stop-color"] ?? "") {
                    self.gradientFirstStop[id] = color
                }
            }
            return
        }

        switch name {
        case "lineargradient", "radialgradient":
            self.currentGradientId = attributes["id"]
            self.skipDepth = 1
            self.styleStack.append(parent)
            return
        case "defs", "clippath", "mask", "filter", "pattern", "symbol", "text", "style", "title", "desc", "metadata":
            // Wewnątrz defs mogą być gradienty – przeglądamy je, ale niczego nie rysujemy.
            if name == "defs" {
                self.styleStack.append(parent)
                self.defsDepth += 1
                return
            }
            self.skipDepth = 1
            self.styleStack.append(parent)
            return
        default:
            break
        }

        var style = parent
        let styleAttributes = clubSVGStyleAttributes(attributes)
        clubApplyStyle(&style, attributes: styleAttributes)
        if let transformText = attributes["transform"] {
            style.transform = clubSVGTransform(transformText).concatenating(parent.transform)
        }
        self.styleStack.append(style)

        if self.defsDepth > 0 {
            return
        }

        switch name {
        case "svg":
            if self.viewBox == nil {
                if let box = attributes["viewBox"] ?? attributes["viewbox"] {
                    let values = clubSVGNumbers(box)
                    if values.count == 4, values[2] > 0, values[3] > 0 {
                        self.viewBox = CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
                    }
                }
                if self.viewBox == nil,
                   let width = attributes["width"].flatMap(clubSVGLength),
                   let height = attributes["height"].flatMap(clubSVGLength) {
                    self.viewBox = CGRect(x: 0, y: 0, width: width, height: height)
                }
            }
        case "rect":
            let x = clubNumber(attributes["x"]), y = clubNumber(attributes["y"])
            let width = clubNumber(attributes["width"]), height = clubNumber(attributes["height"])
            guard width > 0, height > 0 else { return }
            var rx = attributes["rx"].map { clubNumber($0) }
            var ry = attributes["ry"].map { clubNumber($0) }
            if rx == nil { rx = ry }
            if ry == nil { ry = rx }
            let rect = CGRect(x: x, y: y, width: width, height: height)
            let cornerWidth = min(max(rx ?? 0, 0), width / 2)
            let cornerHeight = min(max(ry ?? 0, 0), height / 2)
            let path = cornerWidth > 0 || cornerHeight > 0
                ? Path(roundedRect: rect, cornerSize: CGSize(width: cornerWidth, height: cornerHeight))
                : Path(rect)
            self.add(path: path, style: style, hasFill: true)
        case "circle":
            let r = clubNumber(attributes["r"])
            guard r > 0 else { return }
            let cx = clubNumber(attributes["cx"]), cy = clubNumber(attributes["cy"])
            self.add(path: Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)), style: style, hasFill: true)
        case "ellipse":
            let rx = clubNumber(attributes["rx"]), ry = clubNumber(attributes["ry"])
            guard rx > 0, ry > 0 else { return }
            let cx = clubNumber(attributes["cx"]), cy = clubNumber(attributes["cy"])
            self.add(path: Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: 2 * rx, height: 2 * ry)), style: style, hasFill: true)
        case "line":
            var path = Path()
            path.move(to: CGPoint(x: clubNumber(attributes["x1"]), y: clubNumber(attributes["y1"])))
            path.addLine(to: CGPoint(x: clubNumber(attributes["x2"]), y: clubNumber(attributes["y2"])))
            self.add(path: path, style: style, hasFill: false)
        case "polyline", "polygon":
            let values = clubSVGNumbers(attributes["points"] ?? "")
            guard values.count >= 4 else { return }
            var path = Path()
            path.move(to: CGPoint(x: values[0], y: values[1]))
            var index = 2
            while index + 1 < values.count {
                path.addLine(to: CGPoint(x: values[index], y: values[index + 1]))
                index += 2
            }
            if name == "polygon" {
                path.closeSubpath()
            }
            self.add(path: path, style: style, hasFill: true)
        case "path":
            guard let d = attributes["d"], d.isEmpty == false else { return }
            self.add(path: clubSVGPath(d), style: style, hasFill: true)
        default:
            break
        }
    }

    private var defsDepth: Int = 0

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.lowercased().components(separatedBy: ":").last ?? elementName
        if self.styleStack.count > 1 {
            self.styleStack.removeLast()
        }
        if self.skipDepth > 0 {
            self.skipDepth -= 1
            if self.skipDepth == 0 {
                self.currentGradientId = nil
            }
            return
        }
        if name == "defs", self.defsDepth > 0 {
            self.defsDepth -= 1
        }
    }

    private func add(path: Path, style: ClubSVGStyle, hasFill: Bool) {
        let transformed = style.transform.isIdentity ? path : path.applying(style.transform)
        self.items.append(ClubSVGPendingItem(path: transformed, style: style, hasFill: hasFill))
    }

    func finish() -> ClubSVGDrawing {
        let drawingItems = self.items.map { pending -> ClubSVGItem in
            let style = pending.style
            let fill = pending.hasFill
                ? self.resolve(style.fill).map { $0.opacity(style.opacity * style.fillOpacity) }
                : nil
            let stroke = self.resolve(style.stroke).map { $0.opacity(style.opacity * style.strokeOpacity) }
            // Grubość linii skalujemy razem z przekształceniem (np. scale(2)).
            let transform = style.transform
            let scale = sqrt(abs(transform.a * transform.d - transform.b * transform.c))
            return ClubSVGItem(
                path: pending.path,
                fill: fill,
                stroke: stroke,
                lineWidth: style.strokeWidth * (scale > 0 ? scale : 1),
                lineCap: style.lineCap,
                lineJoin: style.lineJoin,
                evenOdd: style.evenOdd
            )
        }
        return ClubSVGDrawing(viewBox: self.viewBox ?? CGRect(x: 0, y: 0, width: 100, height: 100), items: drawingItems)
    }

    private func resolve(_ paint: ClubSVGPaint) -> Color? {
        switch paint {
        case .none:
            return nil
        case .color(let color):
            return color
        case .reference(let id):
            return self.gradientFirstStop[id] ?? Color(red: 0.6, green: 0.6, blue: 0.6)
        }
    }
}

// MARK: - Style

/// Łączy atrybuty z wpisami w `style="fill:...;stroke:..."` (style ma pierwszeństwo).
private func clubSVGStyleAttributes(_ attributes: [String: String]) -> [String: String] {
    var result = attributes
    if let style = attributes["style"] {
        for declaration in style.split(separator: ";") {
            let parts = declaration.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            result[key] = value
        }
    }
    return result
}

private func clubApplyStyle(_ style: inout ClubSVGStyle, attributes: [String: String]) {
    if let fill = attributes["fill"] {
        style.fill = clubSVGPaint(fill)
    }
    if let stroke = attributes["stroke"] {
        style.stroke = clubSVGPaint(stroke)
    }
    if let width = attributes["stroke-width"].flatMap(clubSVGLength) {
        style.strokeWidth = width
    }
    if let opacity = attributes["opacity"].flatMap(Double.init) {
        style.opacity *= max(0, min(1, opacity))
    }
    if let opacity = attributes["fill-opacity"].flatMap(Double.init) {
        style.fillOpacity = max(0, min(1, opacity))
    }
    if let opacity = attributes["stroke-opacity"].flatMap(Double.init) {
        style.strokeOpacity = max(0, min(1, opacity))
    }
    switch attributes["stroke-linecap"] {
    case "round": style.lineCap = .round
    case "square": style.lineCap = .square
    case "butt": style.lineCap = .butt
    default: break
    }
    switch attributes["stroke-linejoin"] {
    case "round": style.lineJoin = .round
    case "bevel": style.lineJoin = .bevel
    case "miter": style.lineJoin = .miter
    default: break
    }
    if let rule = attributes["fill-rule"] {
        style.evenOdd = rule == "evenodd"
    }
}

private func clubSVGPaint(_ value: String) -> ClubSVGPaint {
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    if trimmed == "none" || trimmed == "transparent" {
        return .none
    }
    if trimmed.hasPrefix("url(") {
        let id = trimmed
            .replacingOccurrences(of: "url(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespaces)
        return .reference(id)
    }
    if let color = clubSVGColor(trimmed) {
        return .color(color)
    }
    return .color(.black)
}

func clubSVGColor(_ value: String) -> Color? {
    let text = value.trimmingCharacters(in: .whitespaces).lowercased()
    if text.hasPrefix("#") {
        var hex = String(text.dropFirst())
        if hex.count == 3 || hex.count == 4 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        guard hex.count == 6 || hex.count == 8, let value = UInt64(hex, radix: 16) else { return nil }
        let hasAlpha = hex.count == 8
        let red = Double((value >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let green = Double((value >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let blue = Double((value >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let alpha = hasAlpha ? Double(value & 0xFF) / 255 : 1
        return Color(red: red, green: green, blue: blue).opacity(alpha)
    }
    if text.hasPrefix("rgb") {
        let inside = text.drop { $0 != "(" }.dropFirst().prefix { $0 != ")" }
        let parts = inside.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 3 else { return nil }
        func channel(_ part: String) -> Double {
            if part.hasSuffix("%") {
                return (Double(part.dropLast()) ?? 0) / 100
            }
            return (Double(part) ?? 0) / 255
        }
        let alpha = parts.count >= 4 ? (Double(parts[3]) ?? 1) : 1
        return Color(red: channel(parts[0]), green: channel(parts[1]), blue: channel(parts[2])).opacity(alpha)
    }
    let named: [String: (Double, Double, Double)] = [
        "black": (0, 0, 0), "white": (1, 1, 1), "red": (1, 0, 0), "green": (0, 0.5, 0), "lime": (0, 1, 0),
        "blue": (0, 0, 1), "yellow": (1, 1, 0), "orange": (1, 0.65, 0), "purple": (0.5, 0, 0.5),
        "pink": (1, 0.75, 0.8), "brown": (0.65, 0.16, 0.16), "gray": (0.5, 0.5, 0.5), "grey": (0.5, 0.5, 0.5),
        "lightgray": (0.83, 0.83, 0.83), "lightgrey": (0.83, 0.83, 0.83), "darkgray": (0.66, 0.66, 0.66),
        "silver": (0.75, 0.75, 0.75), "gold": (1, 0.84, 0), "navy": (0, 0, 0.5), "skyblue": (0.53, 0.81, 0.92),
        "lightblue": (0.68, 0.85, 0.9), "cyan": (0, 1, 1), "magenta": (1, 0, 1), "beige": (0.96, 0.96, 0.86),
        "tan": (0.82, 0.71, 0.55), "salmon": (0.98, 0.5, 0.45), "coral": (1, 0.5, 0.31), "khaki": (0.94, 0.9, 0.55),
        "crimson": (0.86, 0.08, 0.24), "teal": (0, 0.5, 0.5), "olive": (0.5, 0.5, 0), "maroon": (0.5, 0, 0),
        "currentcolor": (0, 0, 0),
    ]
    if let rgb = named[text] {
        return Color(red: rgb.0, green: rgb.1, blue: rgb.2)
    }
    return nil
}

private func clubNumber(_ value: String?) -> CGFloat {
    guard let value else { return 0 }
    return clubSVGLength(value) ?? 0
}

/// Liczba z jednostką „px” lub bez (inne jednostki traktujemy jak px).
private func clubSVGLength(_ value: String) -> CGFloat? {
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    let digits = trimmed.prefix { "0123456789.-+eE".contains($0) }
    return Double(digits).map { CGFloat($0) }
}

func clubSVGNumbers(_ text: String) -> [CGFloat] {
    var scanner = ClubSVGPathScanner(text)
    var values: [CGFloat] = []
    while let value = scanner.number() {
        values.append(value)
    }
    return values
}

// MARK: - transform

func clubSVGTransform(_ text: String) -> CGAffineTransform {
    var result = CGAffineTransform.identity
    for part in text.split(separator: ")") {
        let pieces = part.split(separator: "(", maxSplits: 1)
        guard pieces.count == 2 else { continue }
        let name = pieces[0].trimmingCharacters(in: CharacterSet(charactersIn: " ,\n\t")).lowercased()
        let values = clubSVGNumbers(String(pieces[1]))
        var item = CGAffineTransform.identity
        switch name {
        case "translate":
            item = CGAffineTransform(translationX: values.first ?? 0, y: values.count > 1 ? values[1] : 0)
        case "scale":
            let sx = values.first ?? 1
            item = CGAffineTransform(scaleX: sx, y: values.count > 1 ? values[1] : sx)
        case "rotate":
            let angle = (values.first ?? 0) * .pi / 180
            if values.count >= 3 {
                let cx = values[1], cy = values[2]
                item = CGAffineTransform(translationX: -cx, y: -cy)
                    .concatenating(CGAffineTransform(rotationAngle: angle))
                    .concatenating(CGAffineTransform(translationX: cx, y: cy))
            } else {
                item = CGAffineTransform(rotationAngle: angle)
            }
        case "matrix":
            if values.count == 6 {
                item = CGAffineTransform(a: values[0], b: values[1], c: values[2], d: values[3], tx: values[4], ty: values[5])
            }
        default:
            continue
        }
        // Lista przekształceń działa od prawej: ostatnie na liście stosowane jest jako pierwsze.
        result = item.concatenating(result)
    }
    return result
}

// MARK: - path d

struct ClubSVGPathScanner {
    private let characters: [Character]
    private var index: Int = 0

    init(_ text: String) {
        self.characters = Array(text)
    }

    private mutating func skipSeparators() {
        // isWhitespace obejmuje też „\r\n”, które Swift traktuje jako jeden znak.
        while self.index < self.characters.count,
              self.characters[self.index].isWhitespace || self.characters[self.index] == "," {
            self.index += 1
        }
    }

    mutating func command() -> Character? {
        self.skipSeparators()
        guard self.index < self.characters.count else { return nil }
        let character = self.characters[self.index]
        guard character.isLetter, character != "e", character != "E" else { return nil }
        self.index += 1
        return character
    }

    mutating func hasNumber() -> Bool {
        self.skipSeparators()
        guard self.index < self.characters.count else { return false }
        let character = self.characters[self.index]
        return character.isNumber || character == "-" || character == "+" || character == "."
    }

    mutating func number() -> CGFloat? {
        guard self.hasNumber() else { return nil }
        let start = self.index
        if self.characters[self.index] == "-" || self.characters[self.index] == "+" {
            self.index += 1
        }
        var seenDot = false
        while self.index < self.characters.count {
            let character = self.characters[self.index]
            if character.isNumber {
                self.index += 1
            } else if character == ".", seenDot == false {
                seenDot = true
                self.index += 1
            } else {
                break
            }
        }
        if self.index < self.characters.count, self.characters[self.index] == "e" || self.characters[self.index] == "E" {
            let exponentStart = self.index
            self.index += 1
            if self.index < self.characters.count, self.characters[self.index] == "-" || self.characters[self.index] == "+" {
                self.index += 1
            }
            if self.index < self.characters.count, self.characters[self.index].isNumber {
                while self.index < self.characters.count, self.characters[self.index].isNumber {
                    self.index += 1
                }
            } else {
                self.index = exponentStart
            }
        }
        guard self.index > start, let value = Double(String(self.characters[start..<self.index])) else {
            self.index = start
            return nil
        }
        return CGFloat(value)
    }

    /// Flaga łuku: pojedyncza cyfra 0/1 (może być sklejona z kolejną liczbą, np. „a1 1 0 01 2 2”).
    mutating func flag() -> Bool? {
        self.skipSeparators()
        guard self.index < self.characters.count else { return nil }
        let character = self.characters[self.index]
        guard character == "0" || character == "1" else { return nil }
        self.index += 1
        return character == "1"
    }
}

func clubSVGPath(_ d: String) -> Path {
    var scanner = ClubSVGPathScanner(d)
    var path = Path()
    var current = CGPoint.zero
    var subpathStart = CGPoint.zero
    var lastCubicControl: CGPoint?
    var lastQuadControl: CGPoint?

    commands: while let command = scanner.command() {
        let relative = command.isLowercase
        let kind = Character(command.uppercased())
        if kind == "Z" {
            path.closeSubpath()
            current = subpathStart
            lastCubicControl = nil
            lastQuadControl = nil
            continue
        }

        var isFirst = true
        repeat {
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
            }
            switch kind {
            case "M":
                guard let x = scanner.number(), let y = scanner.number() else { break commands }
                let target = point(x, y)
                if isFirst {
                    path.move(to: target)
                    subpathStart = target
                } else {
                    path.addLine(to: target)
                }
                current = target
                lastCubicControl = nil
                lastQuadControl = nil
            case "L":
                guard let x = scanner.number(), let y = scanner.number() else { break commands }
                current = point(x, y)
                path.addLine(to: current)
                lastCubicControl = nil
                lastQuadControl = nil
            case "H":
                guard let x = scanner.number() else { break commands }
                current = CGPoint(x: relative ? current.x + x : x, y: current.y)
                path.addLine(to: current)
                lastCubicControl = nil
                lastQuadControl = nil
            case "V":
                guard let y = scanner.number() else { break commands }
                current = CGPoint(x: current.x, y: relative ? current.y + y : y)
                path.addLine(to: current)
                lastCubicControl = nil
                lastQuadControl = nil
            case "C":
                guard let x1 = scanner.number(), let y1 = scanner.number(),
                      let x2 = scanner.number(), let y2 = scanner.number(),
                      let x = scanner.number(), let y = scanner.number() else { break commands }
                let control1 = point(x1, y1), control2 = point(x2, y2), target = point(x, y)
                path.addCurve(to: target, control1: control1, control2: control2)
                current = target
                lastCubicControl = control2
                lastQuadControl = nil
            case "S":
                guard let x2 = scanner.number(), let y2 = scanner.number(),
                      let x = scanner.number(), let y = scanner.number() else { break commands }
                let control1 = lastCubicControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                let control2 = point(x2, y2), target = point(x, y)
                path.addCurve(to: target, control1: control1, control2: control2)
                current = target
                lastCubicControl = control2
                lastQuadControl = nil
            case "Q":
                guard let x1 = scanner.number(), let y1 = scanner.number(),
                      let x = scanner.number(), let y = scanner.number() else { break commands }
                let control = point(x1, y1), target = point(x, y)
                path.addQuadCurve(to: target, control: control)
                current = target
                lastQuadControl = control
                lastCubicControl = nil
            case "T":
                guard let x = scanner.number(), let y = scanner.number() else { break commands }
                let control = lastQuadControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                let target = point(x, y)
                path.addQuadCurve(to: target, control: control)
                current = target
                lastQuadControl = control
                lastCubicControl = nil
            case "A":
                guard let rx = scanner.number(), let ry = scanner.number(), let rotation = scanner.number(),
                      let largeArc = scanner.flag(), let sweep = scanner.flag(),
                      let x = scanner.number(), let y = scanner.number() else { break commands }
                let target = point(x, y)
                clubAddArc(to: &path, from: current, rx: rx, ry: ry, rotation: rotation, largeArc: largeArc, sweep: sweep, end: target)
                current = target
                lastCubicControl = nil
                lastQuadControl = nil
            default:
                break commands
            }
            isFirst = false
        } while scanner.hasNumber()
    }
    return path
}

/// Łuk eliptyczny SVG zamieniony na krzywe Béziera (algorytm z dodatku F.6 specyfikacji SVG).
private func clubAddArc(
    to path: inout Path,
    from start: CGPoint,
    rx radiusX: CGFloat,
    ry radiusY: CGFloat,
    rotation: CGFloat,
    largeArc: Bool,
    sweep: Bool,
    end: CGPoint
) {
    guard start != end else { return }
    var rx = abs(radiusX), ry = abs(radiusY)
    guard rx > 0, ry > 0 else {
        path.addLine(to: end)
        return
    }
    let phi = rotation * .pi / 180
    let cosPhi = cos(phi), sinPhi = sin(phi)
    let dx = (start.x - end.x) / 2, dy = (start.y - end.y) / 2
    let x1 = cosPhi * dx + sinPhi * dy
    let y1 = -sinPhi * dx + cosPhi * dy
    let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
    if lambda > 1 {
        let factor = sqrt(lambda)
        rx *= factor
        ry *= factor
    }
    let numerator = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
    let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
    var coefficient = denominator == 0 ? 0 : sqrt(max(0, numerator / denominator))
    if largeArc == sweep {
        coefficient = -coefficient
    }
    let cxPrime = coefficient * rx * y1 / ry
    let cyPrime = coefficient * -ry * x1 / rx
    let cx = cosPhi * cxPrime - sinPhi * cyPrime + (start.x + end.x) / 2
    let cy = sinPhi * cxPrime + cosPhi * cyPrime + (start.y + end.y) / 2

    func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
        atan2(ux * vy - uy * vx, ux * vx + uy * vy)
    }
    let theta1 = angle(1, 0, (x1 - cxPrime) / rx, (y1 - cyPrime) / ry)
    var deltaTheta = angle((x1 - cxPrime) / rx, (y1 - cyPrime) / ry, (-x1 - cxPrime) / rx, (-y1 - cyPrime) / ry)
    if sweep == false, deltaTheta > 0 {
        deltaTheta -= 2 * .pi
    } else if sweep, deltaTheta < 0 {
        deltaTheta += 2 * .pi
    }

    let segments = max(1, Int(ceil(abs(deltaTheta) / (.pi / 2))))
    let delta = deltaTheta / CGFloat(segments)
    let handle = 4 / 3 * tan(delta / 4)
    func map(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: cx + rx * x * cosPhi - ry * y * sinPhi, y: cy + rx * x * sinPhi + ry * y * cosPhi)
    }
    var theta = theta1
    for _ in 0..<segments {
        let next = theta + delta
        let cos1 = cos(theta), sin1 = sin(theta), cos2 = cos(next), sin2 = sin(next)
        path.addCurve(
            to: map(cos2, sin2),
            control1: map(cos1 - handle * sin1, sin1 + handle * cos1),
            control2: map(cos2 + handle * sin2, sin2 - handle * cos2)
        )
        theta = next
    }
}
