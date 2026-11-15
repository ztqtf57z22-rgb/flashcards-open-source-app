import SwiftUI
import UIKit

enum ClubQuizKind: String, Hashable, Sendable {
    /// Zadania przygotowane przez Claude na podstawie kartki.
    case tasks
    /// Szybki quiz obrazkowy losowany ze słówek.
    case pictures
}

// MARK: - Ekran lekcji: cztery kolorowe zajęcia

struct ClubLessonView: View {
    let lessonId: UUID
    @Binding var path: [ClubRoute]
    @Environment(ClubLessonStore.self) private var lessonStore: ClubLessonStore
    @Environment(\.dismiss) private var dismiss
    @State private var isDeleteConfirmationPresented: Bool = false

    var body: some View {
        ZStack {
            ClubBackground()
            if let lesson = self.lessonStore.lesson(id: self.lessonId) {
                ScrollView {
                    VStack(spacing: 18) {
                        Text(lesson.themeEmoji)
                            .font(.system(size: 80))
                        Text(lesson.title)
                            .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                            .multilineTextAlignment(.center)

                        self.activityButton(
                            emoji: "🃏", title: "Słówka", subtitle: "\(lesson.words.count) obrazków do poznania",
                            color: KidPalette.orange, route: .words(lesson.id), isEnabled: lesson.words.isEmpty == false
                        )
                        self.activityButton(
                            emoji: "🎯", title: "Zgadnij obrazek", subtitle: "Szybki quiz ze słówek",
                            color: KidPalette.grass, route: .quiz(lesson.id, .pictures), isEnabled: lesson.words.count >= 3
                        )
                        if lesson.exercises.isEmpty == false {
                            self.activityButton(
                                emoji: "🧩", title: "Zadania", subtitle: "\(lesson.exercises.count) zadań z kartki",
                                color: KidPalette.purple, route: .quiz(lesson.id, .tasks), isEnabled: true
                            )
                        }
                        if lesson.grammar.isEmpty == false {
                            self.activityButton(
                                emoji: "📖", title: "Gramatyka", subtitle: "Krótko i z obrazkami",
                                color: KidPalette.sky, route: .grammar(lesson.id), isEnabled: true
                            )
                        }
                    }
                    .padding()
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Usuń lekcję", systemImage: "trash", role: .destructive) {
                        self.isDeleteConfirmationPresented = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Usunąć tę lekcję?", isPresented: self.$isDeleteConfirmationPresented, titleVisibility: .visible) {
            Button("Usuń", role: .destructive) {
                self.lessonStore.delete(lessonId: self.lessonId)
                self.dismiss()
            }
        }
    }

    private func activityButton(emoji: String, title: String, subtitle: String, color: Color, route: ClubRoute, isEnabled: Bool) -> some View {
        Button {
            self.path.append(route)
        } label: {
            HStack(spacing: 16) {
                Text(emoji)
                    .font(.system(size: 48))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                    Text(subtitle)
                        .font(.system(.subheadline, design: .rounded))
                        .opacity(0.9)
                }
                Spacer()
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title)
            }
            .foregroundStyle(.white)
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isEnabled == false)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

// MARK: - Słówka: duże karty do odwracania

struct ClubWordsView: View {
    let lessonId: UUID
    @Environment(ClubLessonStore.self) private var lessonStore: ClubLessonStore
    @Environment(ClubSpeaker.self) private var speaker: ClubSpeaker
    @State private var index: Int = 0
    @State private var isFlipped: Bool = false

    var body: some View {
        let words = self.lessonStore.lesson(id: self.lessonId)?.words ?? []
        ZStack {
            ClubBackground()
            if words.isEmpty == false {
                let word = words[min(self.index, words.count - 1)]
                VStack(spacing: 20) {
                    Text("\(min(self.index, words.count - 1) + 1) / \(words.count)")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(word.group)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)

                    Button {
                        withAnimation(.spring(duration: 0.4)) { self.isFlipped.toggle() }
                        if self.isFlipped == false {
                            self.speaker.speakEnglish(word.english)
                        }
                    } label: {
                        self.card(word: word)
                    }
                    .buttonStyle(.plain)

                    Button {
                        self.speaker.speakEnglish(word.english)
                    } label: {
                        ClubBigButtonLabel(title: "Posłuchaj", systemImage: "speaker.wave.2.fill", color: KidPalette.sky)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 16) {
                        Button {
                            self.move(by: -1, count: words.count)
                        } label: {
                            ClubBigButtonLabel(title: "Wstecz", systemImage: "arrow.left", color: KidPalette.purple)
                        }
                        .buttonStyle(.plain)
                        .disabled(self.index == 0)
                        .opacity(self.index == 0 ? 0.4 : 1)

                        Button {
                            self.move(by: 1, count: words.count)
                        } label: {
                            ClubBigButtonLabel(title: "Dalej", systemImage: "arrow.right", color: KidPalette.grass)
                        }
                        .buttonStyle(.plain)
                        .disabled(self.index >= words.count - 1)
                        .opacity(self.index >= words.count - 1 ? 0.4 : 1)
                    }
                }
                .padding()
                .frame(maxWidth: 560)
                .onAppear {
                    self.speaker.speakEnglish(word.english)
                }
            }
        }
        .navigationTitle("Słówka")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func card(word: ClubWord) -> some View {
        let color = KidPalette.color(seed: word.english)
        return VStack(spacing: 16) {
            Text(word.emoji)
                .font(.system(size: 120))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(self.isFlipped ? word.polish : word.english)
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.3))
            Text(self.isFlipped ? "🇵🇱 po polsku" : "🇬🇧 stuknij, by zobaczyć po polsku")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 340)
        .padding()
        .background(
            (self.isFlipped ? KidPalette.backGradient : KidPalette.frontGradient),
            in: RoundedRectangle(cornerRadius: 34, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(color, lineWidth: 5)
        )
        .rotation3DEffect(.degrees(self.isFlipped ? 360 : 0), axis: (x: 0, y: 1, z: 0))
    }

    private func move(by offset: Int, count: Int) {
        let next = min(max(self.index + offset, 0), count - 1)
        guard next != self.index else { return }
        self.isFlipped = false
        self.index = next
        if let word = self.lessonStore.lesson(id: self.lessonId)?.words[safe: next] {
            self.speaker.speakEnglish(word.english)
        }
    }
}

fileprivate extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Quiz / zadania: stukanie w odpowiedź, gwiazdki i pochwały

struct ClubQuizView: View {
    let lessonId: UUID
    let kind: ClubQuizKind
    @Environment(ClubLessonStore.self) private var lessonStore: ClubLessonStore
    @Environment(ClubSpeaker.self) private var speaker: ClubSpeaker
    @Environment(\.dismiss) private var dismiss

    @State private var exercises: [ClubExercise] = []
    @State private var index: Int = 0
    @State private var stars: Int = 0
    @State private var chosen: String?
    @State private var wrongChoices: Set<String> = []
    @State private var isFinished: Bool = false

    private let praise = ["Super! 🎉", "Brawo! ⭐", "Świetnie! 🦁", "Ekstra! 🚀", "Tak trzymaj! 🌈", "Mistrz! 🏆"]

    var body: some View {
        ZStack {
            ClubBackground()
            if self.isFinished {
                self.finishScreen
            } else if let exercise = self.exercises[safe: self.index] {
                self.exerciseScreen(exercise: exercise)
            }
        }
        .navigationTitle(self.kind == .tasks ? "Zadania" : "Zgadnij obrazek")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard self.exercises.isEmpty, let lesson = self.lessonStore.lesson(id: self.lessonId) else { return }
            switch self.kind {
            case .tasks:
                self.exercises = lesson.exercises
            case .pictures:
                self.exercises = makeClubPictureQuiz(words: lesson.words, count: 10)
            }
            if let first = self.exercises.first {
                self.speakQuestion(first)
            }
        }
    }

    private func exerciseScreen(exercise: ClubExercise) -> some View {
        let isAnsweredCorrectly = self.chosen == exercise.answer
        return ScrollView {
            VStack(spacing: 18) {
                ProgressView(value: Double(self.index), total: Double(max(self.exercises.count, 1)))
                    .tint(KidPalette.grass)
                    .scaleEffect(y: 2)
                HStack {
                    Text("Zadanie \(self.index + 1) z \(self.exercises.count)")
                    Spacer()
                    Label("\(self.stars)", systemImage: "star.fill")
                        .foregroundStyle(KidPalette.orange)
                }
                .font(.system(.headline, design: .rounded))

                Text(exercise.instructionPolish)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)

                if exercise.emoji.isEmpty == false {
                    Text(exercise.emoji)
                        .font(.system(size: 90))
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                }

                if exercise.question.isEmpty == false {
                    Button {
                        self.speaker.speakEnglish(exercise.question)
                    } label: {
                        HStack {
                            Text(exercise.question)
                                .font(.system(size: 30, weight: .heavy, design: .rounded))
                                .multilineTextAlignment(.center)
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(KidPalette.sky)
                        }
                        .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.3))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                ForEach(exercise.options, id: \.self) { option in
                    Button {
                        self.choose(option: option, exercise: exercise)
                    } label: {
                        Text(option)
                            .font(.system(size: clubIsEmojiOnly(option) ? 44 : 24, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 66)
                            .padding(.horizontal)
                            .background(
                                self.optionColor(option: option, exercise: exercise).gradient,
                                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isAnsweredCorrectly || self.wrongChoices.contains(option))
                }

                if isAnsweredCorrectly {
                    VStack(spacing: 8) {
                        Text(self.praise[self.index % self.praise.count])
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(KidPalette.grass)
                        if exercise.explanationPolish.isEmpty == false {
                            Text(exercise.explanationPolish)
                                .font(.system(.body, design: .rounded))
                                .multilineTextAlignment(.center)
                        }
                        Button {
                            self.next()
                        } label: {
                            ClubBigButtonLabel(title: "Dalej", systemImage: "arrow.right", color: KidPalette.orange)
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else if self.wrongChoices.isEmpty == false {
                    Text("Prawie! Spróbuj jeszcze raz 💪")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(KidPalette.pink)
                }
            }
            .padding()
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
    }

    private var finishScreen: some View {
        let trophies = clubTrophyLevel(stars: self.stars, total: self.exercises.count)
        return VStack(spacing: 20) {
            Spacer()
            Text(trophies == 3 ? "🏆" : "🎉")
                .font(.system(size: 120))
            Text("Koniec! Zdobyte gwiazdki: \(self.stars) z \(self.exercises.count)")
                .font(.system(.title, design: .rounded).weight(.heavy))
                .multilineTextAlignment(.center)
            HStack {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < trophies ? "star.fill" : "star")
                        .font(.system(size: 48))
                        .foregroundStyle(KidPalette.sun)
                }
            }
            Button {
                self.restart()
            } label: {
                ClubBigButtonLabel(title: "Jeszcze raz", systemImage: "arrow.counterclockwise", color: KidPalette.purple)
            }
            .buttonStyle(.plain)
            Button {
                self.dismiss()
            } label: {
                ClubBigButtonLabel(title: "Wróć do lekcji", systemImage: "house.fill", color: KidPalette.sky)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding()
        .frame(maxWidth: 560)
    }

    private func optionColor(option: String, exercise: ClubExercise) -> Color {
        if self.chosen == exercise.answer && option == exercise.answer {
            return KidPalette.grass
        }
        if self.wrongChoices.contains(option) {
            return Color.gray
        }
        let palette = [KidPalette.sky, KidPalette.orange, KidPalette.purple, KidPalette.pink]
        let position = exercise.options.firstIndex(of: option) ?? 0
        return palette[position % palette.count]
    }

    private func choose(option: String, exercise: ClubExercise) {
        if option == exercise.answer {
            // Gwiazdka tylko za trafienie za pierwszym razem.
            if self.wrongChoices.isEmpty {
                self.stars += 1
            }
            withAnimation(.spring(duration: 0.35)) { self.chosen = option }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if clubIsEmojiOnly(option) == false {
                self.speaker.speakEnglish(option)
            }
        } else {
            withAnimation { _ = self.wrongChoices.insert(option) }
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    private func next() {
        self.chosen = nil
        self.wrongChoices = []
        if self.index + 1 >= self.exercises.count {
            if self.kind == .tasks {
                self.lessonStore.recordStars(lessonId: self.lessonId, stars: self.stars)
            }
            withAnimation { self.isFinished = true }
        } else {
            self.index += 1
            if let exercise = self.exercises[safe: self.index] {
                self.speakQuestion(exercise)
            }
        }
    }

    private func restart() {
        self.index = 0
        self.stars = 0
        self.chosen = nil
        self.wrongChoices = []
        self.isFinished = false
        if self.kind == .pictures, let lesson = self.lessonStore.lesson(id: self.lessonId) {
            self.exercises = makeClubPictureQuiz(words: lesson.words, count: 10)
        }
        if let first = self.exercises.first {
            self.speakQuestion(first)
        }
    }

    private func speakQuestion(_ exercise: ClubExercise) {
        if exercise.question.isEmpty == false {
            self.speaker.speakEnglish(exercise.question)
        }
    }
}

/// Czy tekst składa się tylko z emoji (wtedy pokazujemy go większą czcionką).
func clubIsEmojiOnly(_ text: String) -> Bool {
    let trimmed = text.filter { $0.isWhitespace == false && $0 != "+" && $0 != "=" }
    guard trimmed.isEmpty == false else { return false }
    return trimmed.allSatisfy { character in
        character.unicodeScalars.contains { $0.properties.isEmojiPresentation || $0.value == 0xFE0F }
    }
}

// MARK: - Gramatyka: kolorowe karteczki z przykładami do odsłuchania

struct ClubGrammarView: View {
    let lessonId: UUID
    @Environment(ClubLessonStore.self) private var lessonStore: ClubLessonStore
    @Environment(ClubSpeaker.self) private var speaker: ClubSpeaker

    var body: some View {
        let notes = self.lessonStore.lesson(id: self.lessonId)?.grammar ?? []
        ZStack {
            ClubBackground()
            ScrollView {
                VStack(spacing: 18) {
                    ForEach(notes) { note in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(note.title)
                                .font(.system(.title2, design: .rounded).weight(.heavy))
                            Text(note.explanationPolish)
                                .font(.system(.body, design: .rounded))
                            ForEach(note.examples) { example in
                                Button {
                                    self.speaker.speakEnglish(example.english)
                                } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        Text(example.emoji)
                                            .font(.system(size: 34))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(example.english)
                                                .font(.system(.title3, design: .rounded).weight(.bold))
                                            Text(example.polish)
                                                .font(.system(.subheadline, design: .rounded))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "speaker.wave.2.fill")
                                            .foregroundStyle(KidPalette.sky)
                                    }
                                    .padding(12)
                                    .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.3))
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(KidPalette.color(seed: note.title).opacity(0.22), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    }
                }
                .padding()
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Gramatyka")
        .navigationBarTitleDisplayMode(.inline)
    }
}
