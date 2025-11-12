import SwiftUI

// MARK: - Custom Template Model

struct CustomTemplate: Codable, Identifiable {
    let id: UUID
    let character: String
    let createdDate: Date
    let drawing: CustomDrawing

    var hasHeatmapData: Bool {
        guard !drawing.isEmpty else { return false }
        return drawing.strokes.contains { stroke in
            !stroke.points.isEmpty && stroke.points.contains { point in
                point.speed > 0.0
            }
        }
    }

    var totalPoints: Int {
        return drawing.strokes.reduce(0) { $0 + $1.points.count }
    }

    init(character: String, drawing: CustomDrawing) {
        self.id = UUID()
        self.character = character
        self.createdDate = Date()
        self.drawing = drawing
    }
}

// MARK: - Custom Template Manager
// NOTE: ローカルストレージ機能は削除されました
// 現在はFirebase (TemplateManager.swift) を使用しています

class CustomTemplateManager: ObservableObject {
    @Published var savedTemplates: [CustomTemplate] = []

    static let shared = CustomTemplateManager()

    private init() {
        // Firebase移行後はローカルストレージを使用しません
        print("⚠️ CustomTemplateManagerは非推奨です。TemplateManager.sharedを使用してください")
    }

    // DEPRECATED: Firebase移行のため削除
    // お手本の作成・保存はMakeyView -> TemplateManager.uploadTemplate()を使用してください
    /*
    func saveTemplate(character: String, drawing: CustomDrawing) {
        print("❌ この機能は廃止されました。TemplateManager.uploadTemplate()を使用してください")
    }

    func saveTemplate(character: String, drawing: CustomDrawing, audioRecordings: [StrokeAudioRecording]) {
        print("❌ この機能は廃止されました。TemplateManager.uploadTemplate()を使用してください")
    }

    func saveTemplateWithAudio(
        character: String,
        drawing: CustomDrawing,
        audioRecordings: [StrokeAudioRecording]
    ) {
        print("❌ この機能は廃止されました。TemplateManager.uploadTemplate()を使用してください")
    }
    */

    // DEPRECATED: お手本の取得はTemplateManager.fetchTemplates()を使用してください
    func getTemplateForCharacter(_ character: String) -> CustomTemplate? {
        print("⚠️ この機能は廃止されました。TemplateManager.fetchTemplates()を使用してください")
        return nil
    }

    // DEPRECATED: Firebase上のお手本はTemplateManager経由で管理してください
    /*
    func clearAllTemplates() {
        print("❌ この機能は廃止されました")
    }

    func deleteTemplate(_ template: CustomTemplate) {
        print("❌ この機能は廃止されました")
    }
    */
}
