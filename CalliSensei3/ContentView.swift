import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 40) {
            // タイトル
            Text("Fudey")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.top, 60)

                Text("書道を楽しく学ぼう")
                    .font(.title3)
                    .foregroundColor(.secondary)

                // メインメニュー（3つ）
                VStack(spacing: 30) {
                    // Refery 📚
                    NavigationLink(destination: ReferyView()) {
                        MainMenuButton(
                            emoji: "📚",
                            title: "Refery",
                            subtitle: "お手本作成",
                            color: .blue
                        )
                    }

                    // Learny 🖋️
                    NavigationLink(destination: LearnyView()) {
                        MainMenuButton(
                            emoji: "🖋️",
                            title: "Learny",
                            subtitle: "お手本で学習",
                            color: .green
                        )
                    }

                    // Expressy 🎨
                    NavigationLink(destination: ExpressyMenuView()) {
                        MainMenuButton(
                            emoji: "🎨",
                            title: "Expressy",
                            subtitle: "作品を表現",
                            color: .orange
                        )
                    }
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .background(Color(.systemBackground))
    }
}

// MARK: - Main Menu Button Component

struct MainMenuButton: View {
    let emoji: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 20) {
            // 絵文字アイコン
            Text(emoji)
                .font(.system(size: 60))
                .frame(width: 80)

            // テキスト
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer()

            // 矢印アイコン
            Image(systemName: "chevron.right")
                .font(.title3)
                .foregroundColor(.white.opacity(0.7))
                .padding(.trailing, 10)
        }
        .padding(.horizontal, 24)
        .frame(height: 100)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [color, color.opacity(0.7)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(20)
        .shadow(color: color.opacity(0.4), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    ContentView()
}
