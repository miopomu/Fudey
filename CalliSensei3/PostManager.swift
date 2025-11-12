import Foundation
import FirebaseFirestore
import UIKit

/// Firestoreでの投稿管理クラス
class PostManager {

    // MARK: - Properties

    static let shared = PostManager()
    private let db = Firestore.firestore()
    private let postsCollection = "posts"

    private init() {
        print("✅ PostManager初期化")
    }

    // MARK: - Post Model

    struct Post: Codable, Identifiable {
        var id: String  // Firestoreドキュメ��トID
        let character: String
        let imageData: String  // Base64エンコード
        let colorRed: Double
        let colorGreen: Double
        let colorBlue: Double
        let effectType: String
        let soundType: String
        let description: String
        let caption: String  // ユーザーが入力したキャプション
        var likes: Int
        let createdAt: Date
        var comments: [Comment]

        struct Comment: Codable, Identifiable {
            var id: String { "\(userId)_\(createdAt.timeIntervalSince1970)" }
            let userId: String
            let text: String
            let createdAt: Date
        }

        // UIImageに変換
        var image: UIImage? {
            guard let data = Data(base64Encoded: imageData) else { return nil }
            return UIImage(data: data)
        }

        // UIColorに変換
        var color: UIColor {
            UIColor(red: CGFloat(colorRed), green: CGFloat(colorGreen), blue: CGFloat(colorBlue), alpha: 1.0)
        }
    }

    // MARK: - Public Methods

    /// 投稿をアップロード
    func uploadPost(
        character: String,
        image: UIImage,
        color: UIColor,
        effectType: String,
        soundType: String,
        description: String,
        caption: String
    ) async throws -> String {
        print("📤 投稿アップロード開始: \(character)")

        // 画像をBase64に変換
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw PostError.imageConversionFailed
        }
        let base64String = imageData.base64EncodedString()

        // 色情報を取得
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Firestoreドキュメント作成
        let docRef = db.collection(postsCollection).document()
        let postData: [String: Any] = [
            "character": character,
            "imageData": base64String,
            "colorRed": Double(red),
            "colorGreen": Double(green),
            "colorBlue": Double(blue),
            "effectType": effectType,
            "soundType": soundType,
            "description": description,
            "caption": caption,
            "likes": 0,
            "createdAt": Timestamp(date: Date()),
            "comments": []
        ]

        try await docRef.setData(postData)
        print("✅ 投稿アップロード成功: \(docRef.documentID)")

        return docRef.documentID
    }

    /// 投稿一覧を取得（新しい順）
    func fetchPosts(limit: Int = 50) async throws -> [Post] {
        print("📥 投稿一覧取得開始")

        let snapshot = try await db.collection(postsCollection)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()

        let posts = snapshot.documents.compactMap { document -> Post? in
            let data = document.data()

            guard let character = data["character"] as? String,
                  let imageData = data["imageData"] as? String,
                  let colorRed = data["colorRed"] as? Double,
                  let colorGreen = data["colorGreen"] as? Double,
                  let colorBlue = data["colorBlue"] as? Double,
                  let effectType = data["effectType"] as? String,
                  let soundType = data["soundType"] as? String,
                  let description = data["description"] as? String,
                  let likes = data["likes"] as? Int,
                  let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
                print("⚠️ 不正なデータをスキップ: \(document.documentID)")
                return nil
            }

            // captionは後から追加されたフィールドなので、存在しない場合は空文字列
            let caption = data["caption"] as? String ?? ""

            // コメント取得
            let commentsData = data["comments"] as? [[String: Any]] ?? []
            let comments = commentsData.compactMap { commentData -> Post.Comment? in
                guard let userId = commentData["userId"] as? String,
                      let text = commentData["text"] as? String,
                      let createdAt = (commentData["createdAt"] as? Timestamp)?.dateValue() else {
                    return nil
                }
                return Post.Comment(userId: userId, text: text, createdAt: createdAt)
            }

            return Post(
                id: document.documentID,
                character: character,
                imageData: imageData,
                colorRed: colorRed,
                colorGreen: colorGreen,
                colorBlue: colorBlue,
                effectType: effectType,
                soundType: soundType,
                description: description,
                caption: caption,
                likes: likes,
                createdAt: createdAt,
                comments: comments
            )
        }

        print("✅ 投稿取得成功: \(posts.count)件")
        return posts
    }

    /// いいねを追加
    func likePost(postId: String) async throws {
        print("❤️ いいね追加: \(postId)")

        let docRef = db.collection(postsCollection).document(postId)

        try await db.runTransaction { (transaction, errorPointer) -> Any? in
            let document: DocumentSnapshot
            do {
                try document = transaction.getDocument(docRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard let currentLikes = document.data()?["likes"] as? Int else {
                let error = NSError(domain: "PostManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "いいね数の取得に失敗しました"])
                errorPointer?.pointee = error
                return nil
            }

            transaction.updateData(["likes": currentLikes + 1], forDocument: docRef)
            return nil
        }

        print("✅ いいね追加成功")
    }

    /// コメントを追加
    func addComment(postId: String, userId: String, text: String) async throws {
        print("💬 コメント追加: \(postId)")

        let docRef = db.collection(postsCollection).document(postId)
        let commentData: [String: Any] = [
            "userId": userId,
            "text": text,
            "createdAt": Timestamp(date: Date())
        ]

        try await docRef.updateData([
            "comments": FieldValue.arrayUnion([commentData])
        ])

        print("✅ コメント追加成功")
    }
}

// MARK: - Errors

enum PostError: LocalizedError {
    case imageConversionFailed
    case postNotFound
    case invalidData

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "画像の変換に失敗しました"
        case .postNotFound:
            return "投稿が見つかりませんでした"
        case .invalidData:
            return "無効なデータです"
        }
    }
}
