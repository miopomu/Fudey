import SwiftUI

/// 表現モード - 作品作成とコミュニティへのナビゲーション
struct ExpressyMenuView: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // タイトル
            VStack(spacing: 10) {
                Text("Expressy 🎨")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("作品を表現・共有しましょう")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // ボタン
            VStack(spacing: 40) {
                // Creaty - 作品作成モード
                NavigationLink(destination: CreatyView()) {
                    ExpressyButton(
                        emoji: "📸",
                        title: "Creaty",
                        subtitle: "作品を作成",
                        color: .orange
                    )
                }

                // Communy - みんなの作品
                NavigationLink(destination: CommunyView()) {
                    ExpressyButton(
                        emoji: "💬",
                        title: "Communy",
                        subtitle: "みんなの作品",
                        color: .purple
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

// MARK: - Expressy Button Component

struct ExpressyButton: View {
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
    ExpressyMenuView()
}
