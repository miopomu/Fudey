import SwiftUI

/// お手本詳細画面
struct TemplateDetailView: View {
    let template: FirebaseTemplate
    @State private var isLiking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // プレビュー画像
                if let image = template.previewImage {
                    let _ = print("🖼️ 画像サイズ: \(image.size.width) x \(image.size.height)")
                    let _ = print("🖼️ 画像スケール: \(image.scale)")

                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .containerRelativeFrame(.horizontal) { length, _ in
                            length - 32  // 左右16pxずつパディング
                        }
                        .frame(maxHeight: 400)
                        .clipped()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.1),
                                    Color.cyan.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)
                } else {
                    // プレースホルダー
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 400)
                            .cornerRadius(16)

                        Text(template.character)
                            .font(.system(size: 150, weight: .bold))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }

                // 文字情報
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        Text(template.character)
                            .font(.system(size: 60, weight: .bold, design: .serif))
                            .foregroundColor(.primary)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 8) {
                            Label("\(template.strokes.count)ストローク", systemImage: "pencil.line")
                                .font(.callout)
                                .foregroundColor(.secondary)
                            Label(String(format: "%.1f秒", template.totalDuration), systemImage: "timer")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text(formatDate(template.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // 統計情報
                VStack(alignment: .leading, spacing: 12) {
                    Text("統計情報")
                        .font(.headline)

                    HStack(spacing: 32) {
                        StatItem(
                            icon: "heart.fill",
                            label: "いいね",
                            value: "\(template.likes)",
                            color: .red
                        )

                        StatItem(
                            icon: "point.3.connected.trianglepath.dotted",
                            label: "総ポイント数",
                            value: "\(template.strokes.reduce(0) { $0 + $1.points.count })",
                            color: .blue
                        )

                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // いいねボタン
                Button(action: {
                    Task {
                        await likeTemplate()
                    }
                }) {
                    HStack {
                        if isLiking {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "heart.fill")
                                .font(.title2)
                            Text("いいね")
                                .font(.headline)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .cornerRadius(12)
                }
                .disabled(isLiking)

                // 練習ボタン
                VStack(spacing: 12) {
                    Text("このお手本で練習する")
                        .font(.headline)

                    HStack(spacing: 12) {
                        // 3D鑑賞モード
                        NavigationLink(destination: ObserveyView(template: template.toCustomTemplate())) {
                            VStack {
                                Image(systemName: "cube.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.purple)
                                Text("3D鑑賞")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(12)
                        }

                        // なぞり書きモード
                        NavigationLink(destination: TraceyView(template: template.toCustomTemplate())) {
                            VStack {
                                Image(systemName: "speedometer")
                                    .font(.system(size: 40))
                                    .foregroundColor(.green)
                                Text("なぞり書き")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .navigationTitle("お手本詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func likeTemplate() async {
        isLiking = true
        defer { isLiking = false }

        do {
            try await TemplateManager.shared.likeTemplate(templateId: template.id)
        } catch {
            print("❌ いいねエラー: \(error)")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

// MARK: - Stat Item Component

struct StatItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    let sampleTemplate = FirebaseTemplate(
        id: "preview",
        character: "龍",
        strokes: [],
        totalDuration: 5.5,
        imageData: "",
        likes: 42,
        createdAt: Date()
    )

    return NavigationStack {
        TemplateDetailView(template: sampleTemplate)
    }
}
