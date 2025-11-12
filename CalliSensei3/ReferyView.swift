import SwiftUI

/// お手本作成モード - お手本の作成と閲覧
struct ReferyView: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // タイトル
            VStack(spacing: 10) {
                Text("Refery 📚")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("お手本を作成・閲覧しましょう")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // ボタン
            VStack(spacing: 40) {
                // Makey - お手本作成
                NavigationLink(destination: MakeyView()) {
                    ReferyButton(
                        emoji: "✍️",
                        title: "Makey",
                        subtitle: "お手本を作成",
                        color: .blue
                    )
                }

                // Browsery - お手本閲覧
                NavigationLink(destination: BrowseryView()) {
                    ReferyButton(
                        emoji: "👁️",
                        title: "Browsery",
                        subtitle: "お手本を閲覧",
                        color: .cyan
                    )
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Refery Button Component

struct ReferyButton: View {
    let emoji: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            // 絵文字アイコン
            Text(emoji)
                .font(.system(size: 60))

            // タイトル
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            // サブタイトル
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(width: 280, height: 180)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [color, color.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(25)
        .shadow(color: color.opacity(0.4), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    ReferyView()
}
