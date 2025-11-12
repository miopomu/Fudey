import SwiftUI

/// 学習モード - 鑑賞とトレース練習へのナビゲーション
struct LearnyView: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // タイトル
            VStack(spacing: 10) {
                Text("Learny 🖋️")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("お手本を使って学習しましょう")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // ボタン
            VStack(spacing: 40) {
                // 3D鑑賞モード
                NavigationLink(destination: ObserveyTemplateSelectView()) {
                    LearnyButton(
                        emoji: "👀",
                        title: "Observey",
                        subtitle: "3D鑑賞で学習",
                        color: .purple
                    )
                }

                // なぞり書きモード
                NavigationLink(destination: TraceyTemplateSelectView()) {
                    LearnyButton(
                        emoji: "✏️",
                        title: "Tracey",
                        subtitle: "なぞり書きで練習",
                        color: .green
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

// MARK: - Learny Button Component

struct LearnyButton: View {
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
    LearnyView()
}
