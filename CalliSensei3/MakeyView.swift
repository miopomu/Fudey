import SwiftUI
import UIKit

/// お手本作成画面 - 文字入力とFirebaseアップロード
struct MakeyView: View {
    @State private var inputText: String = ""
    @State private var showDrawingView = false

    var body: some View {
        VStack(spacing: 40) {
            Text("Makey ✍️")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 50)

            Text("練習したい文字のお手本を作成しましょう")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 20) {
                TextField("文字を入力してください", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.title2)
                    .padding(.horizontal, 40)

                NavigationLink(destination: MakeyDrawingView(character: inputText)) {
                    HStack {
                        Image(systemName: "hand.draw.fill")
                            .font(.title2)
                        Text("描画開始")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: inputText.isEmpty ? [Color.gray, Color.gray.opacity(0.8)] : [Color.blue, Color.blue.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: (inputText.isEmpty ? Color.gray : Color.blue).opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(inputText.isEmpty)
                .padding(.horizontal, 40)
            }

            Spacer()
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Makey Drawing View with Firebase Upload

struct MakeyDrawingView: View {
    let character: String
    @State private var drawing = CustomDrawing()
    @State private var isRecording = false
    @State private var isUploading = false
    @State private var showSuccessAlert = false
    @State private var uploadError: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(character)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.leading, 20)

                Spacer()

                Button(action: {
                    toggleRecording()
                }) {
                    Image(systemName: "record.circle.fill")
                        .font(.title)
                        .foregroundColor(isRecording ? .red : .blue)
                }
                .padding(.trailing, 20)
            }
            .padding(.vertical, 10)
            .background(Color(.systemGray6))

            // Enhanced Drawing Area
            EnhancedDrawingViewRepresentable(
                drawing: $drawing,
                isRecording: $isRecording,
                onDrawingChanged: { newDrawing in
                    drawing = newDrawing
                }
            )
            .background(Color.white)

            // Control Buttons
            HStack(spacing: 40) {
                Button(action: {
                    saveAndUploadTemplate()
                }) {
                    if isUploading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .cornerRadius(12)
                    } else {
                        Text("保存してアップロード")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                }
                .disabled(isUploading || drawing.strokes.isEmpty)

                Button(action: {
                    clearDrawing()
                }) {
                    Text("クリア")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red)
                        .cornerRadius(12)
                }
                .disabled(isUploading)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .alert("お手本をアップロードしました", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("「\(character)」のお手本がみんなと共有されました。BrowseryでSNS形式で閲覧できます。")
        }
        .alert("アップロードエラー", isPresented: .constant(uploadError != nil)) {
            Button("OK") {
                uploadError = nil
            }
        } message: {
            Text(uploadError ?? "不明なエラーが発生しました")
        }
    }

    private func toggleRecording() {
        isRecording.toggle()
        print("🎯 Makey drawing recording toggled: \(isRecording)")
    }

    private func clearDrawing() {
        drawing = CustomDrawing()
        print("🗑️ Makey drawing cleared")
    }

    private func saveAndUploadTemplate() {
        if isRecording {
            isRecording = false
        }

        isUploading = true

        Task {
            do {
                // プレビュー画像を生成
                let previewImage = generatePreviewImage()

                // Firebaseにアップロード
                let templateId = try await TemplateManager.shared.uploadTemplate(
                    character: character,
                    drawing: drawing,
                    previewImage: previewImage
                )

                DispatchQueue.main.async {
                    isUploading = false
                    showSuccessAlert = true
                }

                print("✅ お手本アップロード成功: \(templateId)")
                print("   文字: \(character)")
                print("   ストローク数: \(drawing.strokes.count)")
                print("   総ポイント数: \(drawing.strokes.reduce(0) { $0 + $1.points.count })")

            } catch {
                DispatchQueue.main.async {
                    isUploading = false
                    uploadError = error.localizedDescription
                }
                print("❌ お手本アップロード失敗: \(error)")
            }
        }
    }

    private func generatePreviewImage() -> UIImage {
        // 全ての点から bounding box を計算
        var minX = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var minY = CGFloat.infinity
        var maxY = -CGFloat.infinity

        for stroke in drawing.strokes {
            for point in stroke.points {
                minX = min(minX, point.location.x)
                maxX = max(maxX, point.location.x)
                minY = min(minY, point.location.y)
                maxY = max(maxY, point.location.y)
            }
        }

        let drawingWidth = maxX - minX
        let drawingHeight = maxY - minY

        print("📏 描画範囲: \(drawingWidth) x \(drawingHeight)")
        print("📍 位置: (\(minX), \(minY)) - (\(maxX), \(maxY))")

        // 600x600 に収まるようにスケール計算
        let targetSize: CGFloat = 600
        let scale = min(targetSize / drawingWidth, targetSize / drawingHeight) * 0.9  // 余白を確保

        let size = CGSize(width: targetSize, height: targetSize)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let cgContext = context.cgContext
            cgContext.setLineCap(.round)
            cgContext.setLineJoin(.round)
            cgContext.setStrokeColor(UIColor.black.cgColor)

            // 中央に配置するためのオフセット計算
            let offsetX = (targetSize - drawingWidth * scale) / 2 - minX * scale
            let offsetY = (targetSize - drawingHeight * scale) / 2 - minY * scale

            // 座標変換を適用
            cgContext.translateBy(x: offsetX, y: offsetY)
            cgContext.scaleBy(x: scale, y: scale)

            for stroke in drawing.strokes {
                drawStrokeInContext(stroke.points, in: cgContext)
            }
        }
    }

    private func drawStrokeInContext(_ points: [DrawingPoint], in context: CGContext) {
        guard points.count >= 2 else { return }

        for i in 0..<(points.count - 1) {
            let current = points[i]
            let next = points[i + 1]
            let avgWidth = (current.brushWidth + next.brushWidth) / 2

            context.setLineWidth(avgWidth)
            context.beginPath()
            context.move(to: current.location)
            context.addLine(to: next.location)
            context.strokePath()
        }
    }
}

#Preview {
    MakeyView()
}
