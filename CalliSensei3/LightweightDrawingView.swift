import SwiftUI
import UIKit

// MARK: - Lightweight Drawing View with Brush Expression

struct LightweightDrawingView: View {
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
            Text("「\(character)」のお手本が保存されました。鑑賞モードとなぞり書きモードで練習できます。")
        }
    }

    private func toggleRecording() {
        isRecording.toggle()
        print("🎯 Lightweight drawing recording toggled: \(isRecording)")
    }

    private func clearDrawing() {
        drawing = CustomDrawing()
        print("🗑️ Lightweight drawing cleared")
    }
    
    private func saveTemplate() {
        if isRecording {
            isRecording = false
        }

        // DEPRECATED: ローカル保存は廃止されました
        // お手本の作成・保存はMakeyView -> TemplateManager.uploadTemplate()を使用してください
        print("⚠️ LightweightDrawingView.saveTemplate() は廃止されました")
        print("⚠️ お手本の作成はMakeyViewを使用してください")

        // 互換性のため、描画データだけ記録
        let strokeCount = drawing.strokes.count
        let totalPoints = drawing.strokes.reduce(0) { $0 + $1.points.count }
        print("📝 Drawing info: \(character), \(strokeCount) strokes, \(totalPoints) points")

        CalligraphyAudioEngine.shared.clearRecordedAudio()

        showingSaveAlert = true
    }
}

// MARK: - Enhanced Drawing View with Marker Expression

class EnhancedDrawingView: UIView {
    
    private var currentStroke: [MarkerDrawingPoint] = []
    private var drawing = CustomDrawing()
    private var isRecording = false
    
    // light_pressure再生許可フラグ
    private var canPlayLightPressure = false
    
    // Audio engine for touch-based sound
    private let audioEngine = CalligraphyAudioEngine.shared
    
    // Pattern recording state
    private var currentStrokeInitialForce: CGFloat = 0.5

    // Marker settings
    private let lineColor = UIColor.black
    private let minLineWidth: CGFloat = 16.0
    private let maxLineWidth: CGFloat = 100.0
    private let exponentialFactor: CGFloat = 1.5
    // ✅ 追加: 止めの検出用
    private var lastStopTime: Date?
    private var isInStopState = false
    private let stopSpeedThreshold: CGFloat = 50.0
    private let stopDuration: TimeInterval = 0.15
   
    
    // Callbacks
    var onDrawingChanged: ((CustomDrawing) -> Void)?
    
    // Extended drawing point with marker properties
    struct MarkerDrawingPoint {
        let drawingPoint: DrawingPoint
        let tiltAngle: CGFloat
        let dynamicWidth: CGFloat
        let azimuthAngle: CGFloat
        
        init(drawingPoint: DrawingPoint, tiltAngle: CGFloat, dynamicWidth: CGFloat, azimuthAngle: CGFloat) {
            self.drawingPoint = drawingPoint
            self.tiltAngle = tiltAngle
            self.dynamicWidth = dynamicWidth
            self.azimuthAngle = azimuthAngle
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = UIColor.white
        isMultipleTouchEnabled = false
        
        audioEngine.startEngine()
        print("🔍 SETUP: LightweightDrawingView initialized")
    }
    
    func startRecording() {
        isRecording = true
        print("🎯 Enhanced drawing audio recording started")
    }
    
    func stopRecording() {
        isRecording = false
        let recordings = audioEngine.getRecordedStrokeAudio()
        print("🎤 Recorded \(recordings.count) stroke audio recordings")
        print("🎯 Enhanced drawing audio recording stopped")
    }
    
    func clearDrawing() {
        drawing = CustomDrawing()
        currentStroke.removeAll()
        setNeedsDisplay()
        onDrawingChanged?(drawing)
        print("🗑️ Enhanced drawing cleared")
    }
    
    func getDrawing() -> CustomDrawing {
        return drawing
    }
    
    func setDrawing(_ newDrawing: CustomDrawing) {
        self.drawing = newDrawing
        setNeedsDisplay()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        let location = touch.location(in: self)
        let timestamp = Date().timeIntervalSince1970
        
        let force: CGFloat
        if touch.maximumPossibleForce > 0 {
            force = touch.force / touch.maximumPossibleForce
        } else {
            force = 0.5
        }
        
        let tiltAngle = touch.altitudeAngle
        let azimuthAngle = touch.azimuthAngle(in: self)
        let azimuthVector = touch.azimuthUnitVector(in: self)
        let dynamicWidth = calculateMarkerWidth(tiltAngle: tiltAngle)

        let drawingPoint = DrawingPoint(
            location: location,
            timestamp: timestamp,
            speed: 0.0,
            force: force,
            brushWidth: dynamicWidth,
            tiltAngle: tiltAngle,
            altitude: touch.altitudeAngle,
            azimuthAngle: azimuthAngle,
            azimuthX: azimuthVector.dx,
            azimuthY: azimuthVector.dy
        )
        
        let markerPoint = MarkerDrawingPoint(
            drawingPoint: drawingPoint,
            tiltAngle: tiltAngle,
            dynamicWidth: dynamicWidth,
            azimuthAngle: azimuthAngle
        )
        
        currentStroke = [markerPoint]
        
        let strokeCount = drawing.strokes.count + 1
        
        if audioEngine.isInLearningMode {
            print("🎓 LEARNING MODE: touchesBegan")
            audioEngine.playRecordedStrokeAudio()
        } else {
            print("📝 TEMPLATE MODE: touchesBegan - stroke \(strokeCount)")
            
            currentStrokeInitialForce = force
            
            canPlayLightPressure = false
            
            audioEngine.playInitialTouch(force: force)
            audioEngine.startStrokeAudioRecording(strokeNumber: strokeCount)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.canPlayLightPressure = true
                print("✅ light_pressure再生許可")
            }
        }
        
        setNeedsDisplay()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        let location = touch.location(in: self)
        let timestamp = Date().timeIntervalSince1970
        
        let speed: CGFloat
        if let previousBrushPoint = currentStroke.last {
            let previousLocation = previousBrushPoint.drawingPoint.location
            let distance = sqrt(pow(location.x - previousLocation.x, 2) +
                                pow(location.y - previousLocation.y, 2))
            let timeInterval = timestamp - previousBrushPoint.drawingPoint.timestamp
            speed = timeInterval > 0 ? distance / timeInterval : 0.0
        } else {
            speed = 0.0
        }
        
        let force: CGFloat
        if touch.maximumPossibleForce > 0 {
            force = touch.force / touch.maximumPossibleForce
        } else {
            let maxSpeed: CGFloat = 1000.0
            let normalizedSpeed = min(speed / maxSpeed, 1.0)
            force = max(0.2, 1.0 - normalizedSpeed * 0.6)
        }
        
        let tiltAngle = touch.altitudeAngle
        let azimuthAngle = touch.azimuthAngle(in: self)
        let azimuthVector = touch.azimuthUnitVector(in: self)
        let dynamicWidth = calculateMarkerWidth(tiltAngle: tiltAngle)

        let drawingPoint = DrawingPoint(
            location: location,
            timestamp: timestamp,
            speed: speed,
            force: force,
            brushWidth: dynamicWidth,
            tiltAngle: tiltAngle,
            altitude: touch.altitudeAngle,
            azimuthAngle: azimuthAngle,
            azimuthX: azimuthVector.dx,
            azimuthY: azimuthVector.dy
        )
        
        let markerPoint = MarkerDrawingPoint(
            drawingPoint: drawingPoint,
            tiltAngle: tiltAngle,
            dynamicWidth: dynamicWidth,
            azimuthAngle: azimuthAngle
        )
        
        currentStroke.append(markerPoint)
        
        if audioEngine.isInLearningMode {
            // なぞり書きモード：リアルタイム音声無効化
        } else {
            audioEngine.recordForce(force)
            
            if canPlayLightPressure {
                audioEngine.playContinuousDrawing(force: force)
            }
        }
        
        currentStroke.append(markerPoint)

        if audioEngine.isInLearningMode {
            // なぞり書きモード：リアルタイム音声無効化
        } else {
            audioEngine.recordForce(force)
            
            if canPlayLightPressure {
                audioEngine.playContinuousDrawing(force: force)
            }
            
            // ✅ 追加: 止めの検出
            if speed < stopSpeedThreshold {
                if !isInStopState {
                    lastStopTime = Date()
                    isInStopState = true
                } else if let stopTime = lastStopTime {
                    let stoppedDuration = Date().timeIntervalSince(stopTime)
                    if stoppedDuration >= stopDuration {
                        audioEngine.playInitialTouch(force: force)
                        print("🛑 止め検出: heavy_pressure再生")
                        lastStopTime = nil
                    }
                }
            } else {
                isInStopState = false
                lastStopTime = nil
            }
        }

        setNeedsDisplay()
        
        setNeedsDisplay()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isInStopState = false
        lastStopTime = nil
            
        if !currentStroke.isEmpty {
            let drawingPoints = currentStroke.map { $0.drawingPoint }
            let stroke = DrawingStroke(points: drawingPoints, createdDate: Date())
            drawing.strokes.append(stroke)
            currentStroke.removeAll()
            onDrawingChanged?(drawing)
        }
        
        audioEngine.stopDrawingAudio()
        
        if audioEngine.isInLearningMode {
            audioEngine.moveToNextStroke()
        } else {
            let strokeNumber = drawing.strokes.count
            audioEngine.stopStrokeAudioRecording(strokeNumber: strokeNumber)
        }
        
        setNeedsDisplay()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isInStopState = false
        lastStopTime = nil
            
        currentStroke.removeAll()
        audioEngine.stopDrawingAudio()
        setNeedsDisplay()
    }
    
    private func calculateMarkerWidth(tiltAngle: CGFloat) -> CGFloat {
        let normalizedTilt = tiltAngle / (CGFloat.pi / 2)
        let exponentialTilt = pow(normalizedTilt, exponentialFactor)
        let widthRatio = 1.0 - exponentialTilt
        return minLineWidth + (maxLineWidth - minLineWidth) * widthRatio
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setStrokeColor(lineColor.cgColor)
        
        for stroke in drawing.strokes {
            let drawingPoints = stroke.points
            drawStrokeAsPolygon(drawingPoints, in: context)
        }
        
        if !currentStroke.isEmpty {
            drawCurrentStroke(currentStroke, in: context)
        }
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
        
        // 通常部分の描画
        for i in 0..<(points.count - 1) {
            if haraiSegments.contains(i) { continue }

            let current = points[i]
            let next = points[i + 1]
            let avgWidth = (current.brushWidth + next.brushWidth) / 2

            // ✅ 元に戻す: 透明度なし（常に真っ黒）
            context.setStrokeColor(lineColor.cgColor)
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
    
    private func drawCurrentStroke(_ markerStroke: [MarkerDrawingPoint], in context: CGContext) {
        guard markerStroke.count > 1 else {
            if let markerPoint = markerStroke.first {
                drawSinglePoint(markerPoint.drawingPoint, in: context)
            }
            return
        }
        
        let drawingPoints = markerStroke.map { $0.drawingPoint }
        drawStrokeAsPolygon(drawingPoints, in: context)
    }
    
    private func drawSinglePoint(_ point: DrawingPoint, in context: CGContext) {
        // ✅ 元に戻す: 透明度なし
        context.setFillColor(lineColor.cgColor)

        let width = point.brushWidth
        let rect = CGRect(
            x: point.location.x - width/2,
            y: point.location.y - width/2,
            width: width,
            height: width
        )
        context.fillEllipse(in: rect)
    }
}

// MARK: - SwiftUI Wrapper

struct EnhancedDrawingViewRepresentable: UIViewRepresentable {
    @Binding var drawing: CustomDrawing
    @Binding var isRecording: Bool
    let onDrawingChanged: (CustomDrawing) -> Void

    func makeUIView(context: Context) -> EnhancedDrawingView {
        let view = EnhancedDrawingView()
        view.onDrawingChanged = onDrawingChanged
        return view
    }

    func updateUIView(_ uiView: EnhancedDrawingView, context: Context) {
        if isRecording {
            uiView.startRecording()
        } else {
            uiView.stopRecording()
        }
    }
}

#Preview {
    LightweightDrawingView(character: "字")
}
