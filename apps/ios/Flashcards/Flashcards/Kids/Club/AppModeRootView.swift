import Observation
import SwiftUI

/// Który „świat” aplikacji jest otwarty. Po każdym uruchomieniu zaczynamy od ekranu wyboru.
enum AppLaunchMode: Equatable {
    case chooser
    case standard
    case club
}

@MainActor
@Observable
final class AppModeModel {
    var mode: AppLaunchMode = .club
}

/// Korzeń okna. Aplikacja pokazuje wyłącznie Play & Learn Club – standardowe fiszki są ukryte.
/// (Ekran wyboru `AppModeChooserView` zostaje w kodzie, gdyby kiedyś trzeba było go przywrócić.)
struct AppModeRootView: View {
    let model: AppModeModel

    var body: some View {
        ClubRootView()
            .environment(self.model)
    }
}

struct AppModeChooserView: View {
    let model: AppModeModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 1.0, green: 0.97, blue: 0.85), Color(red: 0.86, green: 0.95, blue: 1.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Text("Cześć! 👋")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.3))
                        .padding(.top, 32)
                    Text("W co dziś gramy?")
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color(red: 0.35, green: 0.35, blue: 0.45))

                    Button {
                        self.model.mode = .club
                    } label: {
                        AppModeTile(
                            emoji: "🎨🦁⭐",
                            title: "Play & Learn Club",
                            subtitle: "Angielski z obrazkami, quizy i zadania",
                            colors: [KidPalette.orange, KidPalette.pink]
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        self.model.mode = .standard
                    } label: {
                        AppModeTile(
                            emoji: "🗂️",
                            title: "Fiszki",
                            subtitle: "Standardowa aplikacja",
                            colors: [KidPalette.sky, KidPalette.purple]
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.light)
    }
}

private struct AppModeTile: View {
    let emoji: String
    let title: String
    let subtitle: String
    let colors: [Color]

    var body: some View {
        VStack(spacing: 10) {
            Text(self.emoji)
                .font(.system(size: 64))
                .accessibilityHidden(true)
            Text(self.title)
                .font(.system(.title, design: .rounded).weight(.heavy))
            Text(self.subtitle)
                .font(.system(.headline, design: .rounded))
                .opacity(0.9)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 210)
        .padding()
        .background(
            LinearGradient(colors: self.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .shadow(color: self.colors[0].opacity(0.35), radius: 12, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}
