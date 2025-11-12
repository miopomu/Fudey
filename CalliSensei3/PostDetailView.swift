import SwiftUI
import SpriteKit

/// 投稿詳細画面
struct PostDetailView: View {

    // MARK: - Properties

    let post: PostManager.Post
    let onDismiss: () -> Void

    @State private var isPlayingAudio = false
    @State private var isLiking = false
    @State private var commentText = ""
    @State private var isSubmittingComment = false

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 文字画像 + パーティクルエフェクト
                    ZStack {
                        if let image = post.image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 400)
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
                                .cornerRadius(16)
                        }

                        // パーティクルエフェクトは詳細表示では簡略化
                        // 実際のパーティクルは文字の輪郭データが必要なため省略
                    }

                    // 文字情報
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            Text(post.character)
                                .font(.system(size: 60, weight: .bold, design: .serif))
                                .foregroundColor(Color(post.color))

                            Spacer()

                            VStack(alignment: .trailing, spacing: 8) {
                                Label(post.effectType, systemImage: effectIcon(post.effectType))
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                                Label(post.soundType, systemImage: "speaker.wave.2")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Text(post.description)
                            .font(.body)
                            .foregroundColor(.primary)

                        // キャプション（ユーザー入力）
                        if !post.caption.isEmpty {
                            Divider()
                                .padding(.vertical, 4)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("キャプション")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                Text(post.caption)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }

                        Text(formatDate(post.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)

                    // 音声再生ボタン
                    Button(action: {
                        playAudio()
                    }) {
                        HStack {
                            Image(systemName: isPlayingAudio ? "speaker.wave.3" : "play.circle")
                                .font(.title2)
                            Text(isPlayingAudio ? "音声再生中..." : "音声を再生")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isPlayingAudio ? Color.blue.opacity(0.3) : Color.blue)
                        .foregroundColor(isPlayingAudio ? .blue : .white)
                        .cornerRadius(12)
                    }
                    .disabled(isPlayingAudio)

                    Divider()

                    // いいね・コメント統計
                    HStack(spacing: 32) {
                        Button(action: {
                            Task {
                                await likePost()
                            }
                        }) {
                            VStack {
                                Image(systemName: "heart.fill")
                                    .font(.title)
                                    .foregroundColor(.red)
                                Text("\(post.likes)")
                                    .font(.headline)
                            }
                        }
                        .disabled(isLiking)

                        VStack {
                            Image(systemName: "bubble.right.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                            Text("\(post.comments.count)")
                                .font(.headline)
                        }

                        Spacer()
                    }
                    .padding()

                    Divider()

                    // コメント一覧
                    VStack(alignment: .leading, spacing: 12) {
                        Text("コメント")
                            .font(.headline)

                        if post.comments.isEmpty {
                            Text("まだコメントがありません")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(post.comments) { comment in
                                CommentRow(comment: comment)
                            }
                        }
                    }

                    // コメント入力
                    VStack(alignment: .leading, spacing: 8) {
                        Text("コメントを追加")
                            .font(.headline)

                        HStack {
                            TextField("コメントを入力...", text: $commentText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                            Button(action: {
                                Task {
                                    await addComment()
                                }
                            }) {
                                if isSubmittingComment {
                                    ProgressView()
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .disabled(commentText.isEmpty || isSubmittingComment)
                        }
                    }
                    .padding(.bottom, 32)
                }
                .padding()
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.95, green: 0.95, blue: 0.97),
                        Color(red: 0.98, green: 0.98, blue: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("作品詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        onDismiss()
                    }
                }
            }
        }
    }

    // MARK: - Methods

    private func playAudio() {
        isPlayingAudio = true

        // ExpressionAudioEngineを使用して音声再生
        ExpressionAudioEngine.shared.playSound(type: post.soundType, volume: 0.8)

        // 10秒後に再生状態をリセット
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            isPlayingAudio = false
        }
    }

    private func likePost() async {
        isLiking = true
        defer {
            isLiking = false
        }

        do {
            try await PostManager.shared.likePost(postId: post.id)
        } catch {
            print("❌ いいねエラー: \(error)")
        }
    }

    private func addComment() async {
        guard !commentText.isEmpty else { return }

        isSubmittingComment = true
        defer {
            isSubmittingComment = false
        }

        do {
            // ユーザーIDは仮で"anonymous"を使用（将来的には認証機能を追加）
            try await PostManager.shared.addComment(
                postId: post.id,
                userId: "anonymous",
                text: commentText
            )
            commentText = ""
        } catch {
            print("❌ コメント追加エラー: \(error)")
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
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

// MARK: - Comment Row Component

struct CommentRow: View {
    let comment: PostManager.Post.Comment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.userId)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)

                Spacer()

                Text(formatDate(comment.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(comment.text)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

struct PostDetailView_Previews: PreviewProvider {
    static var previews: some View {
        PostDetailView(
            post: PostManager.Post(
                id: "preview",
                character: "龍",
                imageData: "",
                colorRed: 0.5,
                colorGreen: 0.0,
                colorBlue: 0.8,
                effectType: "sparkles",
                soundType: "mystical",
                description: "龍の力強さを表現しました",
                caption: "書道で表現した龍の作品です",
                likes: 42,
                createdAt: Date(),
                comments: []
            ),
            onDismiss: {}
        )
    }
}
