import SwiftUI

struct NewDrawingView: View {
    let character: String
    @State private var drawing = CustomDrawing()
    @State private var isRecording = false
    @State private var showingSaveAlert = false
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

            // Drawing Area
            CustomDrawingViewRepresentable(
                drawing: $drawing,
                isRecording: $isRecording,
                onDrawingChanged: { newDrawing in
                    drawing = newDrawing
                },
                onRecordingChanged: { recording in
                    isRecording = recording
                }
            )
            .background(Color.white)

            // Control Buttons
            HStack(spacing: 40) {
                Button(action: {
                    saveTemplate()
                }) {
                    Text("保存")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .cornerRadius(12)
                }

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
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .alert("お手本を保存しました", isPresented: $showingSaveAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("「\(character)」のお手本が保存されました。なぞり書きモードで練習できます。")
        }
    }

    private func toggleRecording() {
        isRecording.toggle()
        print("🎯 Recording toggled: \(isRecording)")
    }

    private func clearDrawing() {
        drawing = CustomDrawing()
        print("🗑️ Drawing cleared")
    }

    private func saveTemplate() {
        // Stop recording if active
        if isRecording {
            isRecording = false
        }

        // DEPRECATED: ローカル保存は廃止されました
        // お手本の作成・保存はMakeyView -> TemplateManager.uploadTemplate()を使用してください
        print("⚠️ NewDrawingView.saveTemplate() は廃止されました")
        print("⚠️ お手本の作成はMakeyViewを使用してください")

        // 互換性のため、描画データだけ記録
        let strokeCount = drawing.strokes.count
        let totalPoints = drawing.strokes.reduce(0) { $0 + $1.points.count }
        print("📝 Drawing info: \(character), \(strokeCount) strokes, \(totalPoints) points")

        showingSaveAlert = true
    }
}
