import SwiftUI

/// 投稿フィード画面
struct CommunyView: View {

    // MARK: - Properties

    @State private var posts: [PostManager.Post] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedPost: PostManager.Post?
    @State private var showingDetail = false

    // MARK: - Body

    var body: some View {
        ZStack {
                // 背景グラデーション
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.95, green: 0.95, blue: 0.97),
                        Color(red: 0.98, green: 0.98, blue: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if isLoading {
                    ProgressView("読み込み中...")
                        .scaleEffect(1.2)
                } else if let error = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                        Button("再試行") {
                            Task {
                                await loadPosts()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                } else if posts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("投稿がまだありません")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text("あなたの書道作品を\n最初に投稿してみませんか？")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(posts) { post in
                                PostCard(post: post)
                                    .onTapGesture {
                                        selectedPost = post
                                        showingDetail = true
                                    }
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await loadPosts()
                    }
                }
            }
            .navigationTitle("Communy 💬")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await loadPosts()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingDetail) {
                if let post = selectedPost {
                    PostDetailView(post: post, onDismiss: {
                        showingDetail = false
                        Task {
                            await loadPosts()
                        }
                    })
                }
            }
            .task {
                await loadPosts()
            }
    }

    // MARK: - Methods

    private func loadPosts() async {
        isLoading = true
        errorMessage = nil

        do {
            posts = try await PostManager.shared.fetchPosts()
        } catch {
            errorMessage = "投稿の読み込みに失敗しました: \(error.localizedDescription)"
            print("❌ 投稿読み込みエラー: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Post Card Component

struct PostCard: View {

    let post: PostManager.Post
    @State private var isLiking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 文字画像
            if let image = post.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(post.color).opacity(0.3),
                                Color(post.color).opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
            }

            // 文字名とエフェクト情報
            HStack {
                Text(post.character)
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .foregroundColor(Color(post.color))

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: effectIcon(post.effectType))
                            .foregroundColor(.secondary)
                        Text(post.effectType)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2")
                            .foregroundColor(.secondary)
                        Text(post.soundType)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // 説明文
            Text(post.description)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(2)

            // キャプション（ユーザー入力）
            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .padding(.top, 4)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
            }

            // 投稿日時
            Text(formatDate(post.createdAt))
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            // いいね・コメントボタン
            HStack(spacing: 24) {
                Button(action: {
                    Task {
                        await likePost()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiking ? "heart.fill" : "heart")
                            .foregroundColor(isLiking ? .red : .gray)
                        Text("\(post.likes)")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
                .disabled(isLiking)

                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                        .foregroundColor(.gray)
                    Text("\(post.comments.count)")
                        .font(.body)
                        .foregroundColor(.primary)
                }

                Spacer()

                Text("タップで詳細")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }

    private func likePost() async {
        isLiking = true
        defer { isLiking = false }

        do {
            try await PostManager.shared.likePost(postId: post.id)
            // Note: 実際のアプリではpostのlikesをローカルで更新するか、再取得する
        } catch {
            print("❌ いいねエラー: \(error)")
        }
    }

    private func effectIcon(_ effectType: String) -> String {
        switch effectType {
        case "sparkles": return "sparkles"
        case "fire": return "flame"
        case "water": return "drop"
        case "wind": return "wind"
        case "earth": return "mountain.2"
        case "light": return "sun.max"
        case "dark": return "moon"
        case "nature": return "leaf"
        default: return "sparkles"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

struct CommunyView_Previews: PreviewProvider {
    static var previews: some View {
        CommunyView()
    }
}
