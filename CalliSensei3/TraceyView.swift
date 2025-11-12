import SwiftUI
import UIKit

struct TraceyView: View {
    let template: CustomTemplate
    @State private var showHeatmap = true
    @State private var showAudioControls = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Tracey ✏️: \(template.character)")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.leading, 20)

                Spacer()

                // Heatmap toggle button
                if template.hasHeatmapData {
                    Button(action: {
                        showHeatmap.toggle()
                        print("🔥 Heatmap visibility: \(showHeatmap)")
                    }) {
                        HStack {
                            Image(systemName: showHeatmap ? "speedometer" : "speedometer")
                            Text(showHeatmap ? "スピードマップを隠す" : "スピードマップを表示")
                        }
                        .font(.title2)
                        .foregroundColor(.red)
                    }
                    .padding(.trailing, 20)
                } else {
                    Text("スピードデータなし")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.trailing, 20)
                }
            }
            .padding(.vertical, 10)
            .background(Color(.systemGray6))

            // Combined Heatmap + Drawing Area
            ZStack {
                // Background: Heatmap Display
                if showHeatmap && template.hasHeatmapData {
                    HeatmapDisplayViewRepresentable(drawing: template.drawing)
                        .background(Color.white)
                } else {
                    VStack {
                        Spacer()
                        Image(systemName: "speedometer")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("スピードマップが無効です")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .padding(.top, 16)
                        Spacer()
                    }
                    .background(Color.white)
                }

                // Foreground: Interactive Drawing Layer
                TracingDrawingViewRepresentable(
                    templateDrawing: template.drawing,
                    character: template.character
                )
            }

            // Control buttons
            HStack(spacing: 40) {
                Button(action: {
                    print("✏️ Practice completed for: \(template.character)")
                    dismiss()
                }) {
                    Text("完了")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            CalligraphyAudioEngine.shared.startEngine()

            print("🔍 DEBUG: NewTracingView started for character: \(template.character)")
            print("🔍 DEBUG: Template has \(template.drawing.strokes.count) strokes")
            print("🔍 DEBUG: Has speed data: \(template.hasHeatmapData)")

            let totalPoints = template.drawing.strokes.reduce(0) { $0 + $1.points.count }
            let avgSpeed: CGFloat
            let avgForce: CGFloat
            if totalPoints > 0 {
                let allPoints = template.drawing.strokes.flatMap { $0.points }
                avgSpeed = allPoints.reduce(0) { $0 + $1.speed } / CGFloat(totalPoints)
                avgForce = allPoints.reduce(0) { $0 + $1.force } / CGFloat(totalPoints)
            } else {
                avgSpeed = 0.0
                avgForce = 0.0
            }
            print("🔍 DEBUG: Total points: \(totalPoints)")
            print("🔍 DEBUG: Average speed: \(String(format: "%.1f", avgSpeed))")
            print("🔍 DEBUG: Average force: \(String(format: "%.3f", avgForce))")
        }
        .onDisappear {
            CalligraphyAudioEngine.shared.stopEngine()
        }
    }
}

// MARK: - Tracing Drawing View Implementation

struct TracingDrawingViewRepresentable: UIViewRepresentable {
    let templateDrawing: CustomDrawing
    let character: String

    func makeUIView(context: Context) -> TracingDrawingView {
        let tracingView = TracingDrawingView()
        tracingView.setTemplateDrawing(templateDrawing)
        tracingView.backgroundColor = UIColor.clear
        return tracingView
    }

    func updateUIView(_ uiView: TracingDrawingView, context: Context) {
        // Update if needed
    }
}

class TracingDrawingView: UIView {

    // Extended drawing point with marker properties
    struct MarkerDrawingPoint {
        let drawingPoint: DrawingPoint
        let tiltAngle: CGFloat
        let dynamicWidth: CGFloat
        let azimuthAngle: CGFloat
    }

    // Template reference data
    private var templateDrawing: CustomDrawing?
    private var templateStrokes: [DrawingStroke] = []

    // Current user drawing
    private var currentStroke: [MarkerDrawingPoint] = []
    private var completedStrokes: [[MarkerDrawingPoint]] = []

    // Audio engine for touch-based sound - same as template mode
    private let audioEngine = CalligraphyAudioEngine.shared
    // Pattern recording state
    private var currentStrokeInitialForce: CGFloat = 0.5

    // Drawing properties - same as LightweightDrawingView
    private let minLineWidth: CGFloat = 16.0
    private let maxLineWidth: CGFloat = 100.0
    private let exponentialFactor: CGFloat = 1.5
    private let lineColor = UIColor.black

    // Template path correction settings
    private let snapDistance: CGFloat = 30.0  // Pixel distance for auto-correction
    private let correctionStrength: CGFloat = 0.7  // How strong the correction is (0.0-1.0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        isMultipleTouchEnabled = false
        backgroundColor = UIColor.clear

        // Start audio engine for learning mode
        audioEngine.startEngine()
    }

    func setTemplateDrawing(_ drawing: CustomDrawing) {
        templateDrawing = drawing
        templateStrokes = drawing.strokes
        print("📝 Tracing: Template set with \(templateStrokes.count) strokes")
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        let location = touch.location(in: self)
        let correctedLocation = applyCorrectionToPoint(location)

        let markerPoint = createMarkerPoint(from: touch, at: correctedLocation)
        currentStroke = [markerPoint]

        // Play initial touch sound with force-based volume control for each stroke - same as template mode
        let force: CGFloat
        if touch.maximumPossibleForce > 0 {
            force = touch.force / touch.maximumPossibleForce
        } else {
            force = 0.5 // Default force for non-3D Touch devices
        }

        // なぞり書きモードとお手本モードで音声制御を完全分岐
        let strokeCount = completedStrokes.count + 1  // +1 for current stroke being started

        if audioEngine.isInLearningMode {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🎓 LEARNING MODE: NewTracingView touchesBegan - stroke \(strokeCount)")
            print("   🚫 Real-time audio generation DISABLED")
            print("   📢 Playing recorded audio ONLY")
            print("   ⚠️ playInitialTouch will NOT be called")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            audioEngine.playRecordedStrokeAudio()
            // ここで処理終了 - playInitialTouch は呼び出さない
        } else {
            print("📝 TEMPLATE MODE: TRACING touchesBegan - stroke \(strokeCount)")
            print("   🎵 Real-time heavy_pressure generation")
            print("   🎙️ Starting stroke pattern recording")

            // Store initial force for pattern recording
            currentStrokeInitialForce = force

            // お手本モード:リアルタイム音声生成とストローク音声録音を同時実行
            audioEngine.playInitialTouch(force: force)
            audioEngine.startStrokeAudioRecording(strokeNumber: strokeCount)
        }

        // Log stroke start for debugging
        print("🎯 TRACING STROKE \(strokeCount) STARTED - force: \(String(format: "%.3f", force))")
        print("   🔧 Mode: \(audioEngine.isInLearningMode ? "LEARNING (recorded only)" : "TEMPLATE (real-time)")")

        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        let location = touch.location(in: self)
        let correctedLocation = applyCorrectionToPoint(location)

        let markerPoint = createMarkerPoint(from: touch, at: correctedLocation)
        currentStroke.append(markerPoint)

        // なぞり書きモードとお手本モードで連続音声制御を分岐
        let force: CGFloat
        if touch.maximumPossibleForce > 0 {
            force = touch.force / touch.maximumPossibleForce
        } else {
            force = 0.5 // Default force for non-3D Touch devices
        }

        if audioEngine.isInLearningMode {
            // なぞり書きモード：リアルタイム音声を完全無効化
            if currentStroke.count % 20 == 0 {
                print("🎓 LEARNING MODE: NewTracingView touchesMoved - リアルタイム音声を無効化")
                print("   🚫 playContinuousDrawing NOT called")
                print("   📢 録音音声のみ再生中")
                print("   ⚠️ Real-time audio engine BYPASSED")
            }
            // playContinuousDrawing は一切呼び出さない
        } else {
            // お手本モード：リアルタイム連続音声生成
            audioEngine.recordForce(force)  // ← この行を追加
            audioEngine.playContinuousDrawing(force: force)

            // デバッグ: 筆圧値をリアルタイム表示（10回に1回）
            if currentStroke.count % 10 == 0 {
                let forcePercent = Int(force * 100)
                print("📝 TEMPLATE MODE: TRACING REAL-TIME PRESSURE: force=\(String(format: "%.3f", force)) (\(forcePercent)%)")
            }
        }

        setNeedsDisplay()
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !currentStroke.isEmpty {
            completedStrokes.append(currentStroke)
            currentStroke = []
        }

        // ✅ 修正: なぞり書きモードでも音を停止
        if audioEngine.isInLearningMode {
            // なぞり書きモード：録音音声を停止
            audioEngine.stopDrawingAudio()
            audioEngine.moveToNextStroke()
            print("🎓 LEARNING MODE: TRACING touchesEnded - 音声停止 & 次のストローク準備")
        } else {
            // お手本モード：音声を停止して録音終了
            audioEngine.stopDrawingAudio()
            let strokeNumber = completedStrokes.count
            audioEngine.stopStrokeAudioRecording(strokeNumber: strokeNumber)
            print("📝 TEMPLATE MODE: TRACING touchesEnded - stroke audio recording saved")
        }

        // Log stroke completion for debugging
        let completedStrokeCount = completedStrokes.count
        print("🏁 TRACING STROKE \(completedStrokeCount) COMPLETED")

        setNeedsDisplay()
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentStroke = []

        // Stop drawing audio - same as template mode
        audioEngine.stopDrawingAudio()

        setNeedsDisplay()
    }

    // MARK: - Point Creation and Correction

    private func createMarkerPoint(from touch: UITouch, at location: CGPoint) -> MarkerDrawingPoint {
        let timestamp = Date().timeIntervalSince1970

        // ✅ 速度を計算
        let speed: CGFloat
        if let lastPoint = currentStroke.last {
            let previousLocation = lastPoint.drawingPoint.location
            let distance = sqrt(pow(location.x - previousLocation.x, 2) +
                              pow(location.y - previousLocation.y, 2))
            let timeInterval = timestamp - lastPoint.drawingPoint.timestamp
            speed = timeInterval > 0 ? distance / timeInterval : 0.0
        } else {
            speed = 0.0
        }

        let tiltAngle = touch.altitudeAngle
        let azimuthAngle = touch.azimuthAngle(in: self)
        let azimuthVector = touch.azimuthUnitVector(in: self)
        let force: CGFloat
        if touch.maximumPossibleForce > 0 {
            force = touch.force / touch.maximumPossibleForce
        } else {
            force = 0.5
        }

        let dynamicWidth = calculateMarkerWidth(tiltAngle: tiltAngle)

        let drawingPoint = DrawingPoint(
            location: location,
            timestamp: timestamp,
            speed: speed,  // ✅ 計算した速度を使用
            force: force,
            brushWidth: dynamicWidth,
            tiltAngle: tiltAngle,
            altitude: touch.altitudeAngle,  // ✅ 追加
            azimuthAngle: azimuthAngle,      // ✅ 追加
            azimuthX: azimuthVector.dx,      // ✅ 追加
            azimuthY: azimuthVector.dy       // ✅ 追加
        )

        return MarkerDrawingPoint(
            drawingPoint: drawingPoint,
            tiltAngle: tiltAngle,
            dynamicWidth: dynamicWidth,
            azimuthAngle: azimuthAngle
        )
    }

    private func calculateMarkerWidth(tiltAngle: CGFloat) -> CGFloat {
        let normalizedTilt = tiltAngle / (CGFloat.pi / 2)
        let exponentialTilt = pow(normalizedTilt, exponentialFactor)
        let widthRatio = 1.0 - exponentialTilt
        return minLineWidth + (maxLineWidth - minLineWidth) * widthRatio
    }

    /// 位置のみを補正（太さ、筆圧、チルト角度は一切変更しない）
    private func applyCorrectionToPoint(_ originalPoint: CGPoint) -> CGPoint {
        guard !templateStrokes.isEmpty else { return originalPoint }

        var closestPoint = originalPoint
        var minDistance = CGFloat.greatestFiniteMagnitude

        // お手本の軌跡から最も近い点を検索（位置のみ）
        for stroke in templateStrokes {
            for point in stroke.points {
                let distance = distanceBetweenPoints(originalPoint, point.location)
                if distance < minDistance {
                    minDistance = distance
                    closestPoint = point.location  // 位置座標のみ取得
                }
            }
        }

        // 指定距離内であれば位置のみ補正（太さや筆圧データは無視）
        if minDistance <= snapDistance {
            let correctionVector = CGPoint(
                x: (closestPoint.x - originalPoint.x) * correctionStrength,
                y: (closestPoint.y - originalPoint.y) * correctionStrength
            )

            // 補正された位置を返す（XY座標のみ）
            return CGPoint(
                x: originalPoint.x + correctionVector.x,
                y: originalPoint.y + correctionVector.y
            )
        }

        // 補正範囲外の場合はユーザーの入力位置をそのまま使用
        return originalPoint
    }

    private func distanceBetweenPoints(_ point1: CGPoint, _ point2: CGPoint) -> CGFloat {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setStrokeColor(lineColor.cgColor)

        // Draw completed strokes
        for stroke in completedStrokes {
            drawVariableWidthStroke(stroke, in: context)
        }

        // Draw current stroke
        if !currentStroke.isEmpty {
            drawVariableWidthStroke(currentStroke, in: context)
        }
    }

    private func drawVariableWidthStroke(_ stroke: [MarkerDrawingPoint], in context: CGContext) {
        guard stroke.count >= 2 else { return }
        
        let drawingPoints = stroke.map { $0.drawingPoint }
        drawStrokeAsPolygon(drawingPoints, in: context)
    }

    private func drawStrokeAsPolygon(_ points: [DrawingPoint], in context: CGContext) {
        guard points.count >= 2 else { return }
        
        let speedThreshold: CGFloat = 500.0
        let minSegmentsForHarai: Int = 3

        var haraiSegments = Set<Int>()
        for i in 0..<(points.count - 1) {
            let next = points[i + 1]
            let isNearEnd = i >= max(0, points.count - minSegmentsForHarai - 1)
            if next.speed > speedThreshold && isNearEnd {
                haraiSegments.insert(i)
                if i > 0 {
                    haraiSegments.insert(i - 1)
                }
            }
        }

        
        
        for i in 0..<(points.count - 1) {
            if haraiSegments.contains(i) { continue }
            
            let current = points[i]
            let next = points[i + 1]
            let avgWidth = (current.brushWidth + next.brushWidth) / 2
            
            context.setLineWidth(avgWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.beginPath()
            context.move(to: current.location)
            context.addLine(to: next.location)
            context.strokePath()
        }
        
        if !haraiSegments.isEmpty {
            let sortedSegments = haraiSegments.sorted()
            guard let firstSegment = sortedSegments.first,
                  let lastSegment = sortedSegments.last else { return }
            
            let startPoint = points[firstSegment]
            let endPoint = points[lastSegment + 1]
            
            let dx = endPoint.location.x - startPoint.location.x
            let dy = endPoint.location.y - startPoint.location.y
            let distance = sqrt(dx * dx + dy * dy)
            
            guard distance > 0 else { return }
            
            let perpX = -dy / distance
            let perpY = dx / distance
            
            let startWidth = startPoint.brushWidth / 2
            
            let endSpeed = points[lastSegment + 1].speed
            let speedRatio = min((endSpeed - speedThreshold) / 500.0, 1.0)
            let extendLength: CGFloat = 30.0 + speedRatio * 50.0
            
            let startTop = CGPoint(
                x: startPoint.location.x + perpX * startWidth,
                y: startPoint.location.y + perpY * startWidth
            )
            let startBottom = CGPoint(
                x: startPoint.location.x - perpX * startWidth,
                y: startPoint.location.y - perpY * startWidth
            )
            
            let tipX = endPoint.location.x + (dx / distance) * extendLength
            let tipY = endPoint.location.y + (dy / distance) * extendLength
            
            let tipBottom = CGPoint(x: tipX, y: tipY)
            let tipTop = CGPoint(
                x: endPoint.location.x + perpX * (endPoint.brushWidth / 2 * 0.2),
                y: endPoint.location.y + perpY * (endPoint.brushWidth / 2 * 0.2)
            )
            
            context.setFillColor(lineColor.cgColor)
            context.beginPath()
            context.move(to: startTop)
            context.addLine(to: tipTop)
            context.addLine(to: tipBottom)
            context.addLine(to: startBottom)
            context.closePath()
            context.fillPath()
        }
    }
}
