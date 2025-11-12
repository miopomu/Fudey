import SwiftUI

/// Observey用お手本選択画面 - 3D鑑賞モード
struct ObserveyTemplateSelectView: View {
    @StateObject private var templateManager = TemplateManager.shared
    @State private var templates: [FirebaseTemplate] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            // 背景
            Color(.systemBackground)
                .ignoresSafeArea()

            if isLoading {
                VStack {
                    ProgressView("お手本を読み込み中...")
                        .scaleEffect(1.2)
                }
            } else if let error = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                    Button("再試行") {
                        Task {
                            await loadTemplates()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else if templates.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("お手本がまだありません")
                        .font(.title3)
                        .foregroundColor(.gray)
                    Text("Makeyでお手本を作成してみましょう")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(templates) { template in
                            NavigationLink(destination: ObserveyView(template: template.toCustomTemplate())) {
                                ObserveyTemplateCard(template: template)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await loadTemplates()
                }
            }
        }
        .navigationTitle("Observey 👀 - お手本を選択")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await loadTemplates()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            await loadTemplates()
        }
    }

    private func loadTemplates() async {
        isLoading = true
        errorMessage = nil

        do {
            templates = try await templateManager.fetchTemplates()
        } catch {
            errorMessage = "お手本の読み込みに失敗しました: \(error.localizedDescription)"
            print("❌ お手本読み込みエラー: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Observey Template Card Component

struct ObserveyTemplateCard: View {
    let template: FirebaseTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // プレビュー画像
            if let image = template.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.purple.opacity(0.1),
                                Color.blue.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
            } else {
                // プレースホルダー
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 300)
                        .cornerRadius(12)

                    Text(template.character)
                        .font(.system(size: 100, weight: .bold))
                        .foregroundColor(.gray.opacity(0.5))
                }
            }

            // 文字名とストローク情報
            HStack {
                Text(template.character)
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .foregroundColor(.primary)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.line")
                            .foregroundColor(.secondary)
                        Text("\(template.strokes.count)ストローク")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f秒", template.totalDuration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider()

            // タップ案内
            HStack {
                Image(systemName: "cube.fill")
                    .foregroundColor(.purple)
                Text("タップで3D鑑賞")
                    .font(.caption)
                    .foregroundColor(.purple)

                Spacer()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack {
        ObserveyTemplateSelectView()
    }
}
