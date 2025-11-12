import Foundation
import FirebaseFirestore
import UIKit

// MARK: - Firebase Template Model

struct FirebaseTemplate: Codable, Identifiable {
    let id: String
    let character: String
    let strokes: [FirebaseStroke]
    let totalDuration: Double
    let imageData: String  // Base64エンコードされたプレビュー画像
    let likes: Int
    let createdAt: Date

    // CustomTemplateからの変換用イニシャライザ
    init(from customTemplate: CustomTemplate, imageData: String) {
        self.id = customTemplate.id.uuidString
        self.character = customTemplate.character
        self.strokes = customTemplate.drawing.strokes.map { FirebaseStroke(from: $0) }
        self.totalDuration = customTemplate.drawing.strokes.flatMap { $0.points }.last?.timestamp ?? 0.0
        self.imageData = imageData
        self.likes = 0
        self.createdAt = customTemplate.createdDate
    }

    // Firestoreからのイニシャライザ
    init(id: String, data: [String: Any]) {
        self.id = id
        self.character = data["character"] as? String ?? ""

        // strokesをデコード
        if let strokesData = data["strokes"] as? [[String: Any]] {
            self.strokes = strokesData.compactMap { FirebaseStroke(from: $0) }
        } else {
            self.strokes = []
        }

        self.totalDuration = data["totalDuration"] as? Double ?? 0.0
        self.imageData = data["imageData"] as? String ?? ""
        self.likes = data["likes"] as? Int ?? 0

        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
    }

    // CustomTemplateへの変換
    func toCustomTemplate() -> CustomTemplate {
        let drawing = CustomDrawing(
            strokes: strokes.map { $0.toDrawingStroke() },
            createdDate: createdAt
        )

        return CustomTemplate(
            id: UUID(uuidString: id) ?? UUID(),
            character: character,
            createdDate: createdAt,
            drawing: drawing
        )
    }

    // Firestoreへの保存用辞書
    var dictionary: [String: Any] {
        return [
            "character": character,
            "strokes": strokes.map { $0.dictionary },
            "totalDuration": totalDuration,
            "imageData": imageData,
            "likes": likes,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}

struct FirebaseStroke: Codable {
    let points: [FirebasePoint]
    let createdDate: Date

    init(from drawingStroke: DrawingStroke) {
        self.points = drawingStroke.points.map { FirebasePoint(from: $0) }
        self.createdDate = drawingStroke.createdDate
    }

    init?(from data: [String: Any]) {
        guard let pointsData = data["points"] as? [[String: Any]] else { return nil }

        self.points = pointsData.compactMap { FirebasePoint(from: $0) }

        if let timestamp = data["createdDate"] as? Timestamp {
            self.createdDate = timestamp.dateValue()
        } else {
            self.createdDate = Date()
        }
    }

    func toDrawingStroke() -> DrawingStroke {
        return DrawingStroke(
            points: points.map { $0.toDrawingPoint() },
            createdDate: createdDate
        )
    }

    var dictionary: [String: Any] {
        return [
            "points": points.map { $0.dictionary },
            "createdDate": Timestamp(date: createdDate)
        ]
    }
}

struct FirebasePoint: Codable {
    let x: Double
    let y: Double
    let pressure: Double
    let timestamp: Double
    let tiltX: Double
    let tiltY: Double
    let azimuth: Double
    let altitude: Double
    let brushWidth: Double
    let speed: Double

    init(from drawingPoint: DrawingPoint) {
        self.x = Double(drawingPoint.location.x)
        self.y = Double(drawingPoint.location.y)
        self.pressure = Double(drawingPoint.force)
        self.timestamp = drawingPoint.timestamp
        self.tiltX = Double(drawingPoint.azimuthX)
        self.tiltY = Double(drawingPoint.azimuthY)
        self.azimuth = Double(drawingPoint.azimuthAngle)
        self.altitude = Double(drawingPoint.altitude)
        self.brushWidth = Double(drawingPoint.brushWidth)
        self.speed = Double(drawingPoint.speed)
    }

    init?(from data: [String: Any]) {
        guard let x = data["x"] as? Double,
              let y = data["y"] as? Double else { return nil }

        self.x = x
        self.y = y
        self.pressure = data["pressure"] as? Double ?? 0.0
        self.timestamp = data["timestamp"] as? Double ?? 0.0
        self.tiltX = data["tiltX"] as? Double ?? 0.0
        self.tiltY = data["tiltY"] as? Double ?? 0.0
        self.azimuth = data["azimuth"] as? Double ?? 0.0
        self.altitude = data["altitude"] as? Double ?? 0.0
        self.brushWidth = data["brushWidth"] as? Double ?? 60.0
        self.speed = data["speed"] as? Double ?? 0.0
    }

    func toDrawingPoint() -> DrawingPoint {
        return DrawingPoint(
            location: CGPoint(x: x, y: y),
            timestamp: timestamp,
            speed: CGFloat(speed),
            force: CGFloat(pressure),
            brushWidth: CGFloat(brushWidth),
            tiltAngle: 0.0,
            altitude: CGFloat(altitude),
            azimuthAngle: CGFloat(azimuth),
            azimuthX: CGFloat(tiltX),
            azimuthY: CGFloat(tiltY)
        )
    }

    var dictionary: [String: Any] {
        return [
            "x": x,
            "y": y,
            "pressure": pressure,
            "timestamp": timestamp,
            "tiltX": tiltX,
            "tiltY": tiltY,
            "azimuth": azimuth,
            "altitude": altitude,
            "brushWidth": brushWidth,
            "speed": speed
        ]
    }
}

// MARK: - CustomTemplate Extension for CustomDrawing

extension CustomTemplate {
    init(id: UUID, character: String, createdDate: Date, drawing: CustomDrawing) {
        self.id = id
        self.character = character
        self.createdDate = createdDate
        self.drawing = drawing
    }
}

extension CustomDrawing {
    init(strokes: [DrawingStroke], createdDate: Date) {
        self.strokes = strokes
        self.createdDate = createdDate
    }
}

// MARK: - Template Manager

class TemplateManager: ObservableObject {
    static let shared = TemplateManager()

    private let db = Firestore.firestore()
    private let templatesCollection = "templates"

    @Published var templates: [FirebaseTemplate] = []
    @Published var isLoading = false

    private init() {}

    // MARK: - Upload Template

    @MainActor
    func uploadTemplate(
        character: String,
        drawing: CustomDrawing,
        previewImage: UIImage
    ) async throws -> String {
        print("📤 お手本アップロード開始: \(character)")

        // プレビュー画像を300x300にリサイズ
        let resizedImage = resizeImage(previewImage, targetSize: CGSize(width: 300, height: 300))

        // プレビュー画像をBase64エンコード (JPEG圧縮率 0.5)
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.5) else {
            throw NSError(domain: "TemplateManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "画像データの変換に失敗しました"])
        }
        let base64Image = imageData.base64EncodedString()

        print("   画像サイズ: \(imageData.count / 1024)KB (リサイズ後)")

        // CustomTemplateを作成
        let customTemplate = CustomTemplate(character: character, drawing: drawing)

        // FirebaseTemplateに変換
        let firebaseTemplate = FirebaseTemplate(from: customTemplate, imageData: base64Image)

        // Firestoreにアップロード
        let docRef = try await db.collection(templatesCollection).addDocument(data: firebaseTemplate.dictionary)

        print("✅ お手本アップロード完了: \(docRef.documentID)")
        print("   文字: \(character)")
        print("   ストローク数: \(drawing.strokes.count)")
        print("   総ポイント数: \(drawing.strokes.reduce(0) { $0 + $1.points.count })")

        return docRef.documentID
    }

    // MARK: - Fetch Templates

    @MainActor
    func fetchTemplates() async throws -> [FirebaseTemplate] {
        print("📥 お手本一覧を取得中...")

        isLoading = true
        defer { isLoading = false }

        let snapshot = try await db.collection(templatesCollection)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        let templates = snapshot.documents.compactMap { document -> FirebaseTemplate? in
            let data = document.data()
            return FirebaseTemplate(id: document.documentID, data: data)
        }

        // @MainActorなので直接代入可能
        self.templates = templates

        print("✅ お手本取得完了: \(templates.count)件")
        return templates
    }

    // MARK: - Like Template

    @MainActor
    func likeTemplate(templateId: String) async throws {
        print("❤️ いいね追加: \(templateId)")

        let templateRef = db.collection(templatesCollection).document(templateId)

        try await templateRef.updateData([
            "likes": FieldValue.increment(Int64(1))
        ])

        print("✅ いいね追加完了")

        // ローカルのtemplatesも更新（@MainActorなので直接更新可能）
        if let index = templates.firstIndex(where: { $0.id == templateId }) {
            let updatedTemplate = self.templates[index]
            self.templates[index] = FirebaseTemplate(
                id: updatedTemplate.id,
                character: updatedTemplate.character,
                strokes: updatedTemplate.strokes,
                totalDuration: updatedTemplate.totalDuration,
                imageData: updatedTemplate.imageData,
                likes: updatedTemplate.likes + 1,
                createdAt: updatedTemplate.createdAt
            )
        }
    }

    // MARK: - Get Template by ID

    func getTemplate(by id: String) async throws -> FirebaseTemplate {
        print("🔍 お手本取得: \(id)")

        let document = try await db.collection(templatesCollection).document(id).getDocument()

        guard let data = document.data() else {
            throw NSError(domain: "TemplateManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "お手本が見つかりません"])
        }

        let template = FirebaseTemplate(id: document.documentID, data: data)
        print("✅ お手本取得完了: \(template.character)")

        return template
    }

    // MARK: - Helper Methods

    /// 画像を指定サイズにリサイズ
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height

        // アスペクト比を維持して収まるサイズを計算
        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Helper Extension for FirebaseTemplate

extension FirebaseTemplate {
    init(id: String, character: String, strokes: [FirebaseStroke], totalDuration: Double, imageData: String, likes: Int, createdAt: Date) {
        self.id = id
        self.character = character
        self.strokes = strokes
        self.totalDuration = totalDuration
        self.imageData = imageData
        self.likes = likes
        self.createdAt = createdAt
    }

    var previewImage: UIImage? {
        guard let data = Data(base64Encoded: imageData) else {
            print("❌ Base64デコード失敗")
            return nil
        }

        guard let image = UIImage(data: data) else {
            print("❌ UIImage変換失敗")
            return nil
        }

        // 画像の向きを正規化
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let normalizedImage = renderer.image { context in
            image.draw(at: .zero)
        }

        print("✅ 画像変換成功: \(normalizedImage.size)")
        return normalizedImage
    }
}
