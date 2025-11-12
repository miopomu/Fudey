import UIKit
import SwiftUI

// MARK: - Data Models for Custom Drawing

struct DrawingPoint: Codable {
    let location: CGPoint
    let timestamp: TimeInterval
    let speed: CGFloat  // Drawing speed at this point (distance/time)
    let force: CGFloat  // Pressure force (0.0 - 1.0)
    let brushWidth: CGFloat  // Dynamic brush width at this point
    let tiltAngle: CGFloat   // Tilt angle for brush expression

    // 3D再生用の追加データ
    let altitude: CGFloat         // ペンの傾き角度 (0-π/2)
    let azimuthAngle: CGFloat     // ペンの方向角度
    let azimuthX: CGFloat         // 方向ベクトルX成分
    let azimuthY: CGFloat         // 方向ベクトルY成分

    // カスタムイニシャライザー（後方互換性のため）
    init(location: CGPoint, timestamp: TimeInterval, speed: CGFloat, force: CGFloat, brushWidth: CGFloat = 60.0, tiltAngle: CGFloat = 0.0, altitude: CGFloat = 0.0, azimuthAngle: CGFloat = 0.0, azimuthX: CGFloat = 0.0, azimuthY: CGFloat = 0.0) {
        self.location = location
        self.timestamp = timestamp
        self.speed = speed
        self.force = force
        self.brushWidth = brushWidth
        self.tiltAngle = tiltAngle
        self.altitude = altitude
        self.azimuthAngle = azimuthAngle
        self.azimuthX = azimuthX
        self.azimuthY = azimuthY
    }

    // Codable対応のための既存デコーディング（デフォルト値を使用）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        location = try container.decode(CGPoint.self, forKey: .location)
        timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        speed = try container.decode(CGFloat.self, forKey: .speed)
        force = try container.decode(CGFloat.self, forKey: .force)
        brushWidth = try container.decodeIfPresent(CGFloat.self, forKey: .brushWidth) ?? 60.0
        tiltAngle = try container.decodeIfPresent(CGFloat.self, forKey: .tiltAngle) ?? 0.0
        altitude = try container.decodeIfPresent(CGFloat.self, forKey: .altitude) ?? 0.0
        azimuthAngle = try container.decodeIfPresent(CGFloat.self, forKey: .azimuthAngle) ?? 0.0
        azimuthX = try container.decodeIfPresent(CGFloat.self, forKey: .azimuthX) ?? 0.0
        azimuthY = try container.decodeIfPresent(CGFloat.self, forKey: .azimuthY) ?? 0.0
    }

    private enum CodingKeys: String, CodingKey {
        case location, timestamp, speed, force, brushWidth, tiltAngle, altitude, azimuthAngle, azimuthX, azimuthY
    }

    // Distance calculation helper
    func distance(to point: DrawingPoint) -> CGFloat {
        let dx = location.x - point.location.x
        let dy = location.y - point.location.y
        return sqrt(dx * dx + dy * dy)
    }

    // Convert speed to color using HSB color space
    var heatColor: UIColor {
        // Define speed range for color mapping
        let maxSpeed: CGFloat = 1000.0  // Maximum speed for color calculation

        // Normalize speed to 0-1 range
        let normalizedSpeed = min(speed / maxSpeed, 1.0)

        // Apply sensitivity curve for enhanced visual differences
        let sensitivityCurve = pow(normalizedSpeed, 0.6)  // Moderate curve for smooth transitions

        // Map to HSB color space: Slow (Blue 240°) → Fast (Red 0°)
        let hue = (1.0 - sensitivityCurve) * (240.0 / 360.0)  // 240° to 0° mapped to 0-1 range

        // Create smooth HSB gradient
        return UIColor(
            hue: hue,           // Smooth hue transition from blue to red
            saturation: 1.0,    // Maximum saturation for vivid colors
            brightness: 1.0,    // Maximum brightness for clear visibility
            alpha: 1.0
        )
    }
}

struct DrawingStroke: Codable {
    let points: [DrawingPoint]
    let createdDate: Date

    var boundingRect: CGRect {
        guard !points.isEmpty else { return .zero }

        let minX = points.map { $0.location.x }.min() ?? 0
        let maxX = points.map { $0.location.x }.max() ?? 0
        let minY = points.map { $0.location.y }.min() ?? 0
        let maxY = points.map { $0.location.y }.max() ?? 0

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

struct CustomDrawing: Codable {
    var strokes: [DrawingStroke]
    let createdDate: Date

    init() {
        self.strokes = []
        self.createdDate = Date()
    }

    var boundingRect: CGRect {
        guard !strokes.isEmpty else { return .zero }

        let strokeBounds = strokes.map { $0.boundingRect }
        let minX = strokeBounds.map { $0.minX }.min() ?? 0
        let maxX = strokeBounds.map { $0.maxX }.max() ?? 0
        let minY = strokeBounds.map { $0.minY }.min() ?? 0
        let maxY = strokeBounds.map { $0.maxY }.max() ?? 0

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    var isEmpty: Bool {
        return strokes.isEmpty || strokes.allSatisfy { $0.points.isEmpty }
    }
}

// MARK: - Custom Drawing View for Template Mode

class CustomDrawingView: UIView {

    // MARK: - Properties

    private var currentStroke: [DrawingPoint] = []
    private var drawing = CustomDrawing()
    private var isRecording = false

    // Drawing settings
    private let lineWidth: CGFloat = 60.0  // Dramatically increased for very thick strokes
    private let lineColor = UIColor.black

    // ✅ 追加: デバッグ用カウンター
    private var alphaLogCount = 0

    // Callbacks
    var onDrawingChanged: ((CustomDrawing) -> Void)?
    var onRecordingChanged: ((Bool) -> Void)?

    // MARK: - Initialization

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
    }

    // MARK: - Public Methods

    func startRecording() {
        isRecording = true
        onRecordingChanged?(true)
        print("🎯 Custom drawing recording started")
    }

    func stopRecording() {
        isRecording = false
        onRecordingChanged?(false)
        print("🎯 Custom drawing recording stopped")
    }

    func clearDrawing() {
        drawing = CustomDrawing()
        currentStroke.removeAll()
        setNeedsDisplay()
        onDrawingChanged?(drawing)
        print("🗑️ Drawing cleared")
    }

    func getDrawing() -> CustomDrawing {
        return drawing
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        let location = touch.location(in: self)
        let timestamp = Date().timeIntervalSince1970

        // First point always has speed 0 (no previous point to calculate from)
        let force = CGFloat(touch.force / touch.maximumPossibleForce)
        let point = DrawingPoint(
            location: location,
            timestamp: timestamp,
            speed: 0.0,
            force: force,
            brushWidth: lineWidth,
            tiltAngle: 0.0
        )
        currentStroke = [point]

        if isRecording {
            print("🖊️ Recording touch began at speed: 0.0")
        }

        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        let location = touch.location(in: self)
        let timestamp = Date().timeIntervalSince1970

        // Calculate speed from previous point
        let speed: CGFloat
        if let previousPoint = currentStroke.last {
            let distance = sqrt(pow(location.x - previousPoint.location.x, 2) +
                              pow(location.y - previousPoint.location.y, 2))
            let timeInterval = timestamp - previousPoint.timestamp

            // Avoid division by zero
            speed = timeInterval > 0 ? distance / timeInterval : 0.0
        } else {
            speed = 0.0
        }

        let force = CGFloat(touch.force / touch.maximumPossibleForce)
        let point = DrawingPoint(
            location: location,
            timestamp: timestamp,
            speed: speed,
            force: force,
            brushWidth: lineWidth,
            tiltAngle: 0.0
        )
        currentStroke.append(point)

        if isRecording && currentStroke.count % 10 == 0 {  // Log every 10th point to avoid spam
            print("🖊️ Recording point: speed=\(String(format: "%.1f", speed)), force=\(String(format: "%.3f", force))")
        }

        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !currentStroke.isEmpty {
            let stroke = DrawingStroke(points: currentStroke, createdDate: Date())
            drawing.strokes.append(stroke)
            currentStroke.removeAll()

            onDrawingChanged?(drawing)

            let avgSpeed: CGFloat
            let avgForce: CGFloat
            if stroke.points.count > 0 {
                avgSpeed = stroke.points.reduce(0) { $0 + $1.speed } / CGFloat(stroke.points.count)
                avgForce = stroke.points.reduce(0) { $0 + $1.force } / CGFloat(stroke.points.count)
            } else {
                avgSpeed = 0.0
                avgForce = 0.0
            }
            let maxSpeed = stroke.points.map { $0.speed }.max() ?? 0
            let maxForce = stroke.points.map { $0.force }.max() ?? 0

            if isRecording {
                print("🎯 Stroke recorded: \(stroke.points.count) points")
                print("   📊 Speed - avg: \(String(format: "%.1f", avgSpeed)), max: \(String(format: "%.1f", maxSpeed))")
                print("   💪 Force - avg: \(String(format: "%.3f", avgForce)), max: \(String(format: "%.3f", maxForce))")
            } else {
                print("✏️ Stroke drawn: \(stroke.points.count) points, avg speed: \(String(format: "%.1f", avgSpeed)), avg force: \(String(format: "%.3f", avgForce))")
            }
        }

        setNeedsDisplay()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentStroke.removeAll()
        setNeedsDisplay()
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // Draw all completed strokes
        for stroke in drawing.strokes {
            drawStroke(stroke, in: context)
        }

        // Draw current stroke being drawn
        if !currentStroke.isEmpty {
            let currentStrokeObj = DrawingStroke(points: currentStroke, createdDate: Date())
            drawStroke(currentStrokeObj, in: context)
        }
    }

    private func drawStroke(_ stroke: DrawingStroke, in context: CGContext) {
        guard stroke.points.count > 1 else {
            // Draw single point with saved brush width
            if let point = stroke.points.first {
                // ✅ 速度に応じた透明度（遅いほど濃い）
                let alpha = calculateAlphaFromSpeed(point.speed)
                let color = lineColor.withAlphaComponent(alpha)
                context.setFillColor(color.cgColor)

                let width = point.brushWidth
                let rect = CGRect(
                    x: point.location.x - width/2,
                    y: point.location.y - width/2,
                    width: width,
                    height: width
                )
                context.fillEllipse(in: rect)
            }
            return
        }

        // Draw stroke as path with dynamic width and opacity
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Draw segments with individual widths and opacity
        for i in 0..<(stroke.points.count - 1) {
            let currentPoint = stroke.points[i]
            let nextPoint = stroke.points[i + 1]

            // ✅ 速度に応じた透明度（遅いほど濃い）
            let alpha = calculateAlphaFromSpeed(currentPoint.speed)
            let color = lineColor.withAlphaComponent(alpha)
            context.setStrokeColor(color.cgColor)

            // Use average width for this segment
            let avgWidth = (currentPoint.brushWidth + nextPoint.brushWidth) / 2
            context.setLineWidth(avgWidth)

            context.beginPath()
            context.move(to: currentPoint.location)
            context.addLine(to: nextPoint.location)
            context.strokePath()
        }
    }

    // ✅ 追加: 速度から透明度を計算するヘルパーメソッド
    private func calculateAlphaFromSpeed(_ speed: CGFloat) -> CGFloat {
        // 速度の閾値設定
        let slowSpeed: CGFloat = 100.0   // これより遅いと最大濃度
        let fastSpeed: CGFloat = 500.0   // これより速いと最小濃度

        // 透明度の範囲
        let minAlpha: CGFloat = 0.3  // 速い部分（薄い）
        let maxAlpha: CGFloat = 1.0  // 遅い部分（濃い）

        // 速度を正規化（0.0〜1.0）
        let normalizedSpeed = min(max((speed - slowSpeed) / (fastSpeed - slowSpeed), 0.0), 1.0)

        // 速度が遅い → alpha高い（濃い）
        // 速度が速い → alpha低い（薄い）
        let alpha = maxAlpha - (normalizedSpeed * (maxAlpha - minAlpha))

        // ✅ デバッグログ追加（最初の10回だけ表示）
        if alphaLogCount < 10 {
            print("🎨 Alpha計算: speed=\(String(format: "%.1f", speed)) → normalized=\(String(format: "%.2f", normalizedSpeed)) → alpha=\(String(format: "%.2f", alpha))")
            alphaLogCount += 1
        }

        return alpha
    }
}

// MARK: - SwiftUI Wrapper for Custom Drawing View

struct CustomDrawingViewRepresentable: UIViewRepresentable {
    @Binding var drawing: CustomDrawing
    @Binding var isRecording: Bool

    let onDrawingChanged: (CustomDrawing) -> Void
    let onRecordingChanged: (Bool) -> Void

    func makeUIView(context: Context) -> CustomDrawingView {
        let view = CustomDrawingView()

        view.onDrawingChanged = onDrawingChanged
        view.onRecordingChanged = onRecordingChanged

        return view
    }

    func updateUIView(_ uiView: CustomDrawingView, context: Context) {
        // Update recording state if needed
        if isRecording {
            uiView.startRecording()
        } else {
            uiView.stopRecording()
        }
    }
}

// MARK: - Heatmap Display View

class HeatmapDisplayView: UIView {

    private var drawing: CustomDrawing?
    // ストローク幅は各ポイントのbrushWidthを使用（固定値を削除）

    func setDrawing(_ drawing: CustomDrawing) {
        self.drawing = drawing
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let drawing = drawing else { return }

        // Clear background
        context.setFillColor(UIColor.white.cgColor)
        context.fill(rect)

        // Draw all strokes as smooth curves with color gradients
        for stroke in drawing.strokes {
            drawSmoothHeatmapStroke(stroke, in: context)
        }
    }

    private func drawSmoothHeatmapStroke(_ stroke: DrawingStroke, in context: CGContext) {
        guard stroke.points.count >= 2 else {
            if let point = stroke.points.first {
                drawSingleHeatPoint(point, in: context)
            }
            return
        }
        
        // 払いに対応した描画を使用
        drawStrokeAsPolygonWithHeatmap(stroke.points, in: context)
    }

    private func drawStrokeAsPolygonWithHeatmap(_ points: [DrawingPoint], in context: CGContext) {
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
        
        // 通常部分の描画（ヒートマップカラー）
        for i in 0..<(points.count - 1) {
            if haraiSegments.contains(i) { continue }
            
            let current = points[i]
            let next = points[i + 1]
            let avgWidth = (current.brushWidth + next.brushWidth) / 2
            
            context.setLineWidth(avgWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setStrokeColor(current.heatColor.cgColor)
            context.beginPath()
            context.move(to: current.location)
            context.addLine(to: next.location)
            context.strokePath()
        }
        
        // 払い部分の描画
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
            
            // ヒートマップカラーで塗りつぶし
            context.setFillColor(endPoint.heatColor.cgColor)
            context.beginPath()
            context.move(to: startTop)
            context.addLine(to: tipTop)
            context.addLine(to: tipBottom)
            context.addLine(to: startBottom)
            context.closePath()
            context.fillPath()
        }
    }

    // Cubic Bezier curve calculation
    private func bezierPoint(t: CGFloat, start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint) -> CGPoint {
        let oneMinusT = 1.0 - t
        let oneMinusTSquared = oneMinusT * oneMinusT
        let oneMinusTCubed = oneMinusTSquared * oneMinusT
        let tSquared = t * t
        let tCubed = tSquared * t

        let x = oneMinusTCubed * start.x +
                3.0 * oneMinusTSquared * t * control1.x +
                3.0 * oneMinusT * tSquared * control2.x +
                tCubed * end.x

        let y = oneMinusTCubed * start.y +
                3.0 * oneMinusTSquared * t * control1.y +
                3.0 * oneMinusT * tSquared * control2.y +
                tCubed * end.y

        return CGPoint(x: x, y: y)
    }


    private func drawSingleHeatPoint(_ point: DrawingPoint, in context: CGContext) {
        let color = point.heatColor
        context.setFillColor(color.cgColor)

        // Use the point's actual brush width instead of fixed stroke width
        let pointRadius = point.brushWidth / 2
        let pointRect = CGRect(
            x: point.location.x - pointRadius,
            y: point.location.y - pointRadius,
            width: pointRadius * 2,
            height: pointRadius * 2
        )

        context.fillEllipse(in: pointRect)
    }
}

// MARK: - SwiftUI Wrapper for Heatmap Display

struct HeatmapDisplayViewRepresentable: UIViewRepresentable {
    let drawing: CustomDrawing

    func makeUIView(context: Context) -> HeatmapDisplayView {
        let view = HeatmapDisplayView()
        view.backgroundColor = UIColor.white
        return view
    }

    func updateUIView(_ uiView: HeatmapDisplayView, context: Context) {
        uiView.setDrawing(drawing)
    }
}
