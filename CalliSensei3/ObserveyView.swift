import SwiftUI
import SceneKit

struct ObserveyView: View {
    let template: CustomTemplate

    @State private var currentTime: TimeInterval = 0.0
    @State private var isPlaying = false
    @State private var playbackSpeed: Double = 1.0

    var body: some View {
        VStack(spacing: 0) {
            // 3Dシーン
            SceneKitView(
                template: template,
                currentTime: $currentTime
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // コントロールパネル
            VStack(spacing: 16) {
                // タイムスライダー
                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption)
                        .frame(width: 50)

                    Slider(
                        value: $currentTime,
                        in: 0...totalDuration,
                        onEditingChanged: { editing in
                            if editing {
                                isPlaying = false
                            }
                        }
                    )

                    Text(formatTime(totalDuration))
                        .font(.caption)
                        .frame(width: 50)
                }
                .padding(.horizontal)

                // 再生コントロール
                HStack(spacing: 30) {
                    Button(action: {
                        currentTime = 0.0
                        isPlaying = false
                        // ✅ 追加: 音声エンジンをリセット
                        CalligraphyAudioEngine.shared.stopDrawingAudio()
                        CalligraphyAudioEngine.shared.resetStrokeIndex()
                    }) {
                        Image(systemName: "backward.end.fill")
                            .font(.title2)
                    }

                    Button(action: {
                        isPlaying.toggle()
                    }) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                    }

                    Button(action: {
                        currentTime = totalDuration
                        isPlaying = false
                        // ✅ 追加: 最後まで進んだら音を止める
                        CalligraphyAudioEngine.shared.stopDrawingAudio()
                    }) {
                        Image(systemName: "forward.end.fill")
                            .font(.title2)
                    }
                }

                // 速度調整
                HStack {
                    Text("速度: \(String(format: "%.1fx", playbackSpeed))")
                        .font(.caption)
                        .frame(width: 80)

                    Slider(value: $playbackSpeed, in: 0.1...5.0)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 20)
            .background(Color(.systemGray6))
        }
        .navigationTitle("Observey 👀: \(template.character)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startPlaybackTimer()
        }
        .onDisappear {
            // ✅ 追加: 画面を離れたら音声を停止して学習モードを解除
            CalligraphyAudioEngine.shared.stopDrawingAudio()
            CalligraphyAudioEngine.shared.setLearningMode(false)
            print("🔧 鑑賞モード終了: 音声エンジンをクリーンアップ")
        }
    }

    private var totalDuration: TimeInterval {
        guard !template.drawing.strokes.isEmpty else { return 1.0 }

        var maxTime: TimeInterval = 0.0
        for stroke in template.drawing.strokes {
            if let lastPoint = stroke.points.last {
                maxTime = max(maxTime, lastPoint.timestamp)
            }
        }

        // 最初のタイムスタンプを基準に正規化
        if let firstStroke = template.drawing.strokes.first,
           let firstPoint = firstStroke.points.first {
            return maxTime - firstPoint.timestamp
        }

        return maxTime
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let seconds = Int(time)
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1.0)) * 10)
        return String(format: "%d.%ds", seconds, milliseconds)
    }

    private func startPlaybackTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            if isPlaying {
                currentTime += 0.016 * playbackSpeed
                if currentTime >= totalDuration {
                    currentTime = totalDuration
                    isPlaying = false
                }
            }
        }
    }
}

// MARK: - SceneKit View

struct SceneKitView: UIViewRepresentable {
    let template: CustomTemplate
    @Binding var currentTime: TimeInterval

    func makeUIView(context: Context) -> SCNView {
        print("🎨 3Dビュー初期化 - ストローク数: \(template.drawing.strokes.count)")

        let sceneView = SCNView()
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.backgroundColor = .white

        // ✅ 追加: タッチイベントを有効化
        sceneView.isUserInteractionEnabled = true

        let scene = SCNScene()

        // カメラの設定（斜め上から見下ろす、机の上の紙を見る角度）
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 12, z: 12)

        // カメラを原点に向ける
        let lookAtConstraint = SCNLookAtConstraint(target: scene.rootNode)
        lookAtConstraint.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAtConstraint]

        scene.rootNode.addChildNode(cameraNode)

        // HeatmapDisplayViewから描画画像を生成
        let drawingImage = context.coordinator.captureDrawingAsImage(
            drawing: template.drawing,
            size: CGSize(width: 1000, height: 1000)
        )

        // 紙を表現する平面を追加（水平に配置）
        let paperPlane = SCNPlane(width: 10, height: 10)

        // 描画画像をテクスチャとして適用
        if let image = drawingImage {
            paperPlane.firstMaterial?.diffuse.contents = image
        } else {
            paperPlane.firstMaterial?.diffuse.contents = UIColor(white: 0.95, alpha: 1.0)
        }

        paperPlane.firstMaterial?.isDoubleSided = true
        paperPlane.firstMaterial?.lightingModel = .lambert
        paperPlane.firstMaterial?.writesToDepthBuffer = true

        let paperNode = SCNNode(geometry: paperPlane)
        paperNode.position = SCNVector3(x: 0, y: 0, z: 0)
        // X軸周りに-90度回転して水平に
        paperNode.eulerAngles.x = -.pi / 2
        paperNode.castsShadow = false
        scene.rootNode.addChildNode(paperNode)

        // paperNodeをCoordinatorに保存
        context.coordinator.paperNode = paperNode

        // ライトの設定（斜め上から）
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.position = SCNVector3(x: 10, y: 10, z: 15)
        scene.rootNode.addChildNode(lightNode)

        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = UIColor.lightGray
        scene.rootNode.addChildNode(ambientLightNode)

        sceneView.scene = scene
        context.coordinator.sceneView = sceneView
        context.coordinator.template = template

        return sceneView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.updateScene(currentTime: currentTime)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var sceneView: SCNView?
        var template: CustomTemplate?
        var paperNode: SCNNode?
        var penNode: SCNNode?

        static var logCount = 0

        private var baseTimestamp: TimeInterval = 0.0
        private var currentStrokeIndex: Int = -1        // ✅ 追加
        private var hasLoadedAudio = false              // ✅ 追加

        // HeatmapDisplayViewの描画結果をUIImageとしてキャプチャ
        func captureDrawingAsImage(drawing: CustomDrawing, size: CGSize) -> UIImage? {
            let drawingView = EnhancedDrawingView(frame: CGRect(origin: .zero, size: size))
            drawingView.backgroundColor = .white
            drawingView.setDrawing(drawing)

            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            guard let context = UIGraphicsGetCurrentContext() else { return nil }
            drawingView.layer.render(in: context)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            return image
        }
        
        // 指定時刻までの描画を部分的にキャプチャ
        func capturePartialDrawingAsImage(drawing: CustomDrawing, currentTime: TimeInterval, size: CGSize) -> UIImage? {
            // 基準タイムスタンプを取得
            guard let firstStroke = drawing.strokes.first,
                  let firstPoint = firstStroke.points.first else {
                return nil
            }
            let baseTime = firstPoint.timestamp
            
            // currentTimeまでのストロークとポイントを抽出
            var partialDrawing = CustomDrawing()
            
            for stroke in drawing.strokes {
                var partialPoints: [DrawingPoint] = []
                
                for point in stroke.points {
                    let pointTime = point.timestamp - baseTime
                    
                    if pointTime <= currentTime {
                        partialPoints.append(point)
                    } else {
                        break  // このストロークはここまで
                    }
                }
                
                // ポイントが2つ以上ある場合のみストロークを追加
                if partialPoints.count >= 2 {
                    let partialStroke = DrawingStroke(points: partialPoints, createdDate: stroke.createdDate)
                    partialDrawing.strokes.append(partialStroke)
                }
            }
            
            // 部分的な描画を画像化
            let drawingView = EnhancedDrawingView(frame: CGRect(origin: .zero, size: size))
            drawingView.backgroundColor = .white
            drawingView.setDrawing(partialDrawing)
            
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            guard let context = UIGraphicsGetCurrentContext() else { return nil }
            drawingView.layer.render(in: context)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return image
        }

        func updateScene(currentTime: TimeInterval) {
            guard let scene = sceneView?.scene,
                  let template = template else {
                return
            }

            // ✅ 追加: 時刻が0に戻ったらストローク番号もリセット
            if currentTime < 0.01 && currentStrokeIndex != -1 {
                currentStrokeIndex = -1
                CalligraphyAudioEngine.shared.resetStrokeIndex()
                print("🔄 再生リセット: ストローク番号をリセット")
            }

            // ✅ 追加: 初回のみ音声を読み込む
            if !hasLoadedAudio {
                CalligraphyAudioEngine.shared.loadRecordedAudio(for: template.character)
                hasLoadedAudio = true
                print("🎵 鑑賞モード: 音声データ読み込み完了")
            }
            
            if let paper = paperNode,
                let partialImage = capturePartialDrawingAsImage(
                drawing: template.drawing,
                currentTime: currentTime,
                size: CGSize(width: 1000, height: 1000)
                ) {
                paper.geometry?.firstMaterial?.diffuse.contents = partialImage
            }

            // ペンノードをクリア
            penNode?.removeFromParentNode()
            penNode = nil

            // 基準タイムスタンプを設定
            if baseTimestamp == 0.0, let firstStroke = template.drawing.strokes.first,
               let firstPoint = firstStroke.points.first {
                baseTimestamp = firstPoint.timestamp
            }

            var currentPenPosition: DrawingPoint?
            var newStrokeIndex = -1
            var isDrawing = false  // ✅ 追加: 現在描画中かどうか

            // 全ストロークをスキャンして現在のペン位置を見つける
            for (strokeIndex, stroke) in template.drawing.strokes.enumerated() {
                guard !stroke.points.isEmpty else { continue }

                // このストロークの開始時刻と終了時刻を取得
                let strokeStartTime = stroke.points.first!.timestamp - baseTimestamp
                let strokeEndTime = stroke.points.last!.timestamp - baseTimestamp

                for i in 0..<stroke.points.count {
                    let point = stroke.points[i]
                    let pointTime = point.timestamp - baseTimestamp

                    // 現在時刻に最も近いポイントを見つける
                    if pointTime <= currentTime {
                        currentPenPosition = point
                        newStrokeIndex = strokeIndex

                        // ✅ 追加: このストロークの範囲内にいるか確認
                        if currentTime >= strokeStartTime && currentTime <= strokeEndTime {
                            isDrawing = true
                        }
                    } else {
                        break
                    }
                }
            }

            // ✅ 修正: ストロークが変わったら音声を再生
            if newStrokeIndex != currentStrokeIndex && newStrokeIndex >= 0 && currentTime > 0.01 {
                currentStrokeIndex = newStrokeIndex
                CalligraphyAudioEngine.shared.currentStrokeIndex = newStrokeIndex
                CalligraphyAudioEngine.shared.playRecordedStrokeAudio()
                print("🎵 鑑賞モード: ストローク \(newStrokeIndex + 1) の音声再生")
            }

            // ✅ 修正: ペンモデルを表示（描画中の場合のみ）
            if let penPos = currentPenPosition, isDrawing {
                let pen = createPenNode(at: penPos)
                scene.rootNode.addChildNode(pen)
                penNode = pen
            } else {
                // ストローク間ではペンを非表示 + 音を停止
                penNode?.removeFromParentNode()
                penNode = nil

                // ✅ 追加: ストローク間では音を停止
                CalligraphyAudioEngine.shared.stopDrawingAudio()
            }
        }


        private func createPenNode(at drawingPoint: DrawingPoint) -> SCNNode {
            // ペンのルートノード
            let penRootNode = SCNNode()
            penRootNode.castsShadow = true

            // 1. ペン本体（細い円柱）
            let bodyRadius: CGFloat = 0.15  // 変更: 0.08 → 0.15
            let bodyHeight: CGFloat = 3.0   // 変更: 1.5 → 3.0
            let body = SCNCylinder(radius: bodyRadius, height: bodyHeight)
            body.firstMaterial?.diffuse.contents = UIColor(red: 0.2, green: 0.15, blue: 0.1, alpha: 1.0)  // 茶色

            let bodyNode = SCNNode(geometry: body)
            bodyNode.position = SCNVector3(0, bodyHeight / 2 + 0.3, 0)  // 本体を上に配置
            penRootNode.addChildNode(bodyNode)

            // 2. 筆先（細い円錐）
            let tipRadius: CGFloat = 0.1    // 変更: 0.05 → 0.1
            let tipHeight: CGFloat = 0.8    // 変更: 0.4 → 0.8
            let tip = SCNCone(topRadius: 0.02, bottomRadius: tipRadius, height: tipHeight)  // 変更: 0.01 → 0.02
            tip.firstMaterial?.diffuse.contents = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)  // 黒い筆先

            let tipNode = SCNNode(geometry: tip)
            tipNode.position = SCNVector3(0, tipHeight / 2, 0)
            penRootNode.addChildNode(tipNode)

            // 3. 筆の毛先（柔らかい筆先）
            let bristleHeight: CGFloat = 0.8
            let bristleGeometry = SCNCone(topRadius: 0.15, bottomRadius: 0.06, height: bristleHeight)  // ✅ 0.08 → 0.15, 0.03 → 0.06 に変更
            bristleGeometry.firstMaterial?.diffuse.contents = UIColor(red: 0.15, green: 0.12, blue: 0.08, alpha: 1.0)

            let bristleNode = SCNNode(geometry: bristleGeometry)
            bristleNode.position = SCNVector3(0, -bristleHeight / 2, 0)
            penRootNode.addChildNode(bristleNode)

            let pos3D = convertTo3D(drawingPoint)

            // ペンの先端（一番下）が軌跡の位置に来るように配置
            // 筆圧に応じて筆先が沈む表現を追加
            let pressureDepth = Float(drawingPoint.force) * 0.6  // 筆圧 × 0.3 の深さ
            penRootNode.position = SCNVector3(pos3D.x, pos3D.y + Float(bristleHeight) - pressureDepth, pos3D.z)
            
            // ペンの傾きと方向を再現
            // altitude: ペンの傾き角度 (0 = 水平, π/2 = 垂直)
            // azimuthX, azimuthY: ペンが傾く方向のベクトル
            let altitude = (CGFloat.pi / 2) - drawingPoint.altitude  // 座標系を反転
            let azimuthX = drawingPoint.azimuthX
            let azimuthY = drawingPoint.azimuthY
            
            if Coordinator.logCount < 5 {
                print("🖊️ ペン角度のログ: ...")
                Coordinator.logCount += 1
            }


            // ペンの向きベクトルを3D空間で計算
            // altitudeが小さい = ペンが寝ている（払い）
            // altitudeが大きい（π/2に近い）= ペンが立っている（止め）

            // azimuthベクトルを3D座標系に変換
            let azimuthDirX = Float(azimuthX)
            let azimuthDirZ = Float(azimuthY)  // 画面Y → 3DのZ

            // ペンの方向ベクトルを計算
            // Y軸が上向き、XZ平面が紙面
            let penVectorY = Float(cos(altitude))  // 垂直成分
            let horizontalLength = Float(sin(altitude))  // 水平成分の長さ

            let penVectorX = azimuthDirX * horizontalLength
            let penVectorZ = azimuthDirZ * horizontalLength

            // ペン方向ベクトル（正規化済み）
            let penDirection = SCNVector3(penVectorX, penVectorY, penVectorZ)

            // デフォルトのペン向き（Y軸正方向 = 垂直）から目的の向きへの回転を計算
            let defaultDirection = SCNVector3(0, 1, 0)

            // 外積で回転軸を求める
            let rotationAxis = SCNVector3(
                defaultDirection.y * penDirection.z - defaultDirection.z * penDirection.y,
                defaultDirection.z * penDirection.x - defaultDirection.x * penDirection.z,
                defaultDirection.x * penDirection.y - defaultDirection.y * penDirection.x
            )

            let axisLength = sqrt(rotationAxis.x * rotationAxis.x +
                                 rotationAxis.y * rotationAxis.y +
                                 rotationAxis.z * rotationAxis.z)

            if axisLength > 0.001 {
                // 内積で回転角度を求める
                let dotProduct = defaultDirection.x * penDirection.x +
                               defaultDirection.y * penDirection.y +
                               defaultDirection.z * penDirection.z
                let angle = acos(max(-1, min(1, dotProduct)))

                // 回転を適用（ルートノードに適用）
                penRootNode.rotation = SCNVector4(
                    rotationAxis.x / axisLength,
                    rotationAxis.y / axisLength,
                    rotationAxis.z / axisLength,
                    angle
                )
            }

            return penRootNode
        }

        private func convertTo3D(_ point: DrawingPoint) -> SCNVector3 {
            // 画面座標(0-1000)を3D座標(-5〜5)にマッピング
            // 画像サイズが1000x1000、紙のサイズが10x10なので、100ピクセル = 1単位
            let normalizedX = Float(point.location.x / 1000.0)
            let normalizedY = Float(point.location.y / 1000.0)

            let x = (normalizedX - 0.5) * 10     // 横位置 (-5〜5)
            let z = (normalizedY - 0.5) * 10     // 奥行き（正しい向き）

            // Y座標: 紙の高さ(0)を基準に、筆圧で紙に沈む深さを表現
            let y = Float(point.force * 0.2)  // 0〜0.2の範囲（紙面付近）

            return SCNVector3(x, y, z)
        }
    }
}

#Preview {
    NavigationView {
        ObserveyView(template: CustomTemplate(
            character: "字",
            drawing: CustomDrawing()
        ))
    }
}
