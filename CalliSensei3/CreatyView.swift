import SwiftUI
import PhotosUI
import AVFoundation
import Photos
import Metal

struct CreatyView: View {
    // MARK: - State Properties
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var isProcessing = false
    @State private var recognizedText: String = ""
    @State private var processedImage: UIImage?
    @State private var originalImage: UIImage?  // 元の半紙
    @State private var characterOnlyImage: UIImage?  // 文字だけ
    @State private var showResult = false
    @State private var characterAttributes: CharacterAttributes?
    @State private var characterBoundingBox: CGRect?  // 文字の境界ボックス
    @State private var isSavingVideo = false  // 動画保存中フラグ
    @State private var isPostingToFeed = false  // 投稿中フラグ
    @State private var showPostSuccess = false  // 投稿成功アラート
    @State private var showFeed = false  // フィード画面表示フラグ
    @State private var postCaption: String = ""  // 投稿キャプション
    @State private var showCaptionSheet = false  // キャプション入力シート表示フラグ
    @State private var capturedSnapshot: UIImage?  // スナップショット

    // Video Effect Engine
    private let videoEffectEngine = VideoEffectEngine()
    @State private var showVideoEffect = false
    @State private var videoEffectType = "water"
    @State private var videoCharacterBounds = CGRect.zero

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // MARK: - Header
                Text("Creaty 📸")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 20)

                Text("筆で書いた文字を撮影して、エフェクトを追加しましょう")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // MARK: - Image Selection Buttons
                VStack(spacing: 20) {
                    Button(action: {
                        showCamera = true
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                            Text("カメラで撮影")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }

                    Button(action: {
                        showImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo.fill")
                                .font(.title2)
                            Text("ライブラリから選択")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 40)

                // MARK: - Image Preview
                if let image = selectedImage {
                    VStack(spacing: 16) {
                        Text("選択した写真")
                            .font(.headline)

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .cornerRadius(12)
                            .shadow(radius: 5)

                        // Process Button
                        Button(action: {
                            processImage()
                        }) {
                            HStack {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    Text("処理中...")
                                        .font(.headline)
                                } else {
                                    Image(systemName: "sparkles")
                                        .font(.title2)
                                    Text("エフェクト生成")
                                        .font(.headline)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isProcessing ? Color.gray : Color.orange)
                            .cornerRadius(12)
                        }
                        .disabled(isProcessing)
                    }
                    .padding(.horizontal, 40)
                }

                // MARK: - Processing Indicator
                if isProcessing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("文字を認識してエフェクトを生成中...")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 30)
                }

                // MARK: - Result Display
                if showResult, let processedImage = processedImage {
                    VStack(spacing: 16) {
                        Text("結果")
                            .font(.title2)
                            .fontWeight(.bold)

                        if !recognizedText.isEmpty {
                            Text("認識された文字: \(recognizedText)")
                                .font(.headline)
                                .foregroundColor(.orange)
                        }

                        // 属性情報の表示
                        if let attributes = characterAttributes {
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "paintpalette.fill")
                                        .foregroundColor(Color(attributes.uiColor))
                                    Text("色: \(attributes.color.red > 0.5 ? "暖色系" : "寒色系")")
                                        .font(.caption)
                                }

                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("エフェクト: \(attributes.effectType)")
                                        .font(.caption)
                                }

                                HStack {
                                    Image(systemName: "speaker.wave.2.fill")
                                    Text("サウンド: \(attributes.soundType)")
                                        .font(.caption)
                                }

                                Text(attributes.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }

                        // 画像表示（3層構造）
                        ZStack {
                            // 1. 最下層：元の半紙画像
                            Image(uiImage: originalImage ?? processedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 400)
                                .cornerRadius(12)

                            // 2. 中間層：動画エフェクト
                            if showVideoEffect {
                                VideoEffectView(
                                    effectType: videoEffectType,
                                    opacity: 0.7,
                                    imageSize: (originalImage ?? processedImage).size,
                                    maxHeight: 400
                                )
                                .scaledToFit()
                                .frame(maxHeight: 400)
                                .cornerRadius(12)
                            }

                            // 3. 最上層：色が変わった文字だけ
                            if let charImage = characterOnlyImage {
                                Image(uiImage: charImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 400)
                                    .cornerRadius(12)
                            }
                        }
                        .shadow(radius: 8)

                        // Action Buttons
                        VStack(spacing: 12) {
                            HStack(spacing: 20) {
                                Button(action: {
                                    saveImage()
                                }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.down")
                                        Text("保存")
                                    }
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 24)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                                }

                                Button(action: {
                                    shareImage()
                                }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("シェア")
                                    }
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 24)
                                    .background(Color.green)
                                    .cornerRadius(8)
                                }
                            }

                            // Video Save Button
                            Button(action: {
                                saveVideo()
                            }) {
                                HStack {
                                    if isSavingVideo {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        Text("動画作成中...")
                                    } else {
                                        Image(systemName: "video.fill")
                                        Text("動画で保存")
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(isSavingVideo ? Color.gray : Color.purple)
                                .cornerRadius(8)
                            }
                            .disabled(isSavingVideo)

                            // Post to Feed Button
                            Button(action: {
                                // まずスナップショットを撮る
                                captureScreenSnapshot()

                                // 少し待ってからキャプション入力画面を表示
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showCaptionSheet = true
                                }
                            }) {
                                HStack {
                                    if isPostingToFeed {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        Text("投稿中...")
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                        Text("フィードに投稿")
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(isPostingToFeed ? Color.gray : Color.orange)
                                .cornerRadius(8)
                            }
                            .disabled(isPostingToFeed)
                        }

                        // Reset Button
                        Button(action: {
                            resetView()
                        }) {
                            Text("新しい写真を選択")
                                .foregroundColor(.orange)
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 40)
                }

                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(image: $selectedImage, sourceType: .camera)
        }
        .sheet(isPresented: $showFeed) {
            CommunyView()
        }
        .sheet(isPresented: $showCaptionSheet) {
            CaptionInputView(
                caption: $postCaption,
                isPosting: $isPostingToFeed,
                onPost: {
                    postToFeed()
                },
                onCancel: {
                    showCaptionSheet = false
                    postCaption = ""
                }
            )
        }
        .alert("投稿完了", isPresented: $showPostSuccess) {
            Button("フィードを見る") {
                showFeed = true
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("作品をフィードに投稿しました！")
        }
    }

    // MARK: - Methods

    private func processImage() {
        guard let image = selectedImage else { return }

        isProcessing = true
        showResult = false

        // 元画像を保持
        originalImage = image

        print("🎨 画像処理開始")

        // Step 1: OCR - 文字認識（境界ボックス付き）
        PhotoAnalyzer.shared.findMainCharacterWithBounds(from: image) { result in
            switch result {
            case .success(let characterWithBounds):
                print("✅ 文字認識成功: \(characterWithBounds.text)")
                print("   境界ボックス: \(characterWithBounds.boundingBox)")
                recognizedText = characterWithBounds.text
                characterBoundingBox = characterWithBounds.boundingBox

                // Step 2: Claude API - 文字の属性を解析
                CharacterAttributeAnalyzer.shared.analyzeCharacter(characterWithBounds.text) { attributeResult in
                    switch attributeResult {
                    case .success(let attributes):
                        print("✅ 属性解析成功")
                        print(attributes.debugDescription)
                        characterAttributes = attributes

                        // Step 3: エフェクトを適用
                        let effectEngine = LottieEffectEngine.shared

                        // 文字だけの画像を生成（背景透明）
                        let characterOnly = effectEngine.createCharacterOnlyImage(
                            from: image,
                            attributes: attributes
                        )

                        // Step 4: 音声を再生
                        ExpressionAudioEngine.shared.playSound(for: attributes, volume: 0.8)

                        // 結果を表示
                        DispatchQueue.main.async {
                            characterOnlyImage = characterOnly
                            processedImage = image  // 元画像をそのまま使用
                            isProcessing = false
                            showResult = true

                            // 動画エフェクトを表示
                            showVideoEffect = true
                            videoEffectType = attributes.effectType
                            videoCharacterBounds = characterWithBounds.boundingBox

                            print("🎉 処理完了")
                        }

                    case .failure(let error):
                        print("❌ 属性解析エラー: \(error.localizedDescription)")
                        handleProcessingError(error)
                    }
                }

            case .failure(let error):
                print("❌ 文字認識エラー: \(error.localizedDescription)")
                handleProcessingError(error)
            }
        }
    }

    private func handleProcessingError(_ error: Error) {
        DispatchQueue.main.async {
            isProcessing = false
            // TODO: Show error alert
            print("⚠️ エラー: \(error.localizedDescription)")
        }
    }

    private func saveImage() {
        guard let image = processedImage else { return }

        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)

        // TODO: Show save confirmation alert
        print("💾 画像を保存しました")
    }

    private func shareImage() {
        guard let image = processedImage else { return }

        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func saveVideo() {
        guard let image = processedImage,
              let attributes = characterAttributes else {
            print("❌ 動画保存: 画像または属性が見つかりません")
            return
        }

        isSavingVideo = true
        print("🎬 動画作成開始")

        DispatchQueue.global(qos: .userInitiated).async {
            // 動画を作成
            if let videoURL = self.createVideo(
                backgroundImage: image,
                attributes: attributes,
                croppingBounds: self.characterBoundingBox
            ) {
                // フォトライブラリに保存
                self.saveVideoToPhotoLibrary(videoURL)
            } else {
                DispatchQueue.main.async {
                    self.isSavingVideo = false
                    print("❌ 動画作成失敗")
                }
            }
        }
    }

    private func createVideo(backgroundImage: UIImage, attributes: CharacterAttributes, croppingBounds: CGRect?) -> URL? {
        // 動画設定
        let videoSize = CGSize(width: 1080, height: 1920)  // 縦型動画
        let fps: Int32 = 30
        let duration: Double = 10.0  // 10秒
        let totalFrames = Int(duration * Double(fps))

        // 一時ファイルパス
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("calligraphy_effect_\(UUID().uuidString).mp4")

        // 既存ファイルを削除
        try? FileManager.default.removeItem(at: outputURL)

        // AVAssetWriterを作成
        guard let assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            print("❌ AVAssetWriter作成失敗")
            return nil
        }

        // ビデオ設定
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoSize.width,
            AVVideoHeightKey: videoSize.height
        ]

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: videoSize.width,
            kCVPixelBufferHeightKey as String: videoSize.height
        ]

        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        if assetWriter.canAdd(videoInput) {
            assetWriter.add(videoInput)
        } else {
            print("❌ ビデオトラック追加失敗")
            return nil
        }

        // 書き込み開始
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)

        print("📹 フレーム生成開始 (合計: \(totalFrames)フレーム)")

        // TODO: VideoEffectEngine との統合により、動画生成機能は現在無効化されています

        // フレームを生成
        var frameCount = 0
        while frameCount < totalFrames {
            if videoInput.isReadyForMoreMediaData {
                let presentationTime = CMTime(value: Int64(frameCount), timescale: fps)

                // フレーム画像を生成
                if let pixelBuffer = createPixelBuffer(
                    backgroundImage: backgroundImage,
                    size: videoSize
                ) {
                    pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                }

                frameCount += 1

                if frameCount % 30 == 0 {
                    print("   進捗: \(frameCount)/\(totalFrames)フレーム")
                }
            } else {
                Thread.sleep(forTimeInterval: 0.01)
            }
        }

        // 書き込み終了
        videoInput.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)

        assetWriter.finishWriting {
            semaphore.signal()
        }

        semaphore.wait()

        if assetWriter.status == .completed {
            print("✅ 動画作成完了: \(outputURL.path)")

            // 音声を追加
            return self.addAudioToVideo(videoURL: outputURL, attributes: attributes)
        } else {
            print("❌ 動画書き込み失敗: \(assetWriter.error?.localizedDescription ?? "不明")")
            return nil
        }
    }

    private func createPixelBuffer(backgroundImage: UIImage, size: CGSize) -> CVPixelBuffer? {
        let options: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            options as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])

        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )

        guard let ctx = context else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return nil
        }

        // 背景画像を描画
        ctx.clear(CGRect(origin: .zero, size: size))

        if let cgImage = backgroundImage.cgImage {
            let imageRect = CGRect(origin: .zero, size: size)
            ctx.draw(cgImage, in: imageRect)
        }

        // パーティクルのレンダリングは複雑なため、現在のバージョンではスキップ
        // TODO: 将来的にSpriteKitのテクスチャレンダリングを実装

        CVPixelBufferUnlockBaseAddress(buffer, [])

        return buffer
    }

    private func addAudioToVideo(videoURL: URL, attributes: CharacterAttributes) -> URL? {
        // 音声ファイルのパスを取得
        guard let audioFileName = ExpressionAudioEngine.SoundType(rawValue: attributes.soundType)?.fileName,
              let audioURL = Bundle.main.url(forResource: audioFileName, withExtension: "wav") else {
            print("⚠️ 音声ファイルが見つかりません。動画のみ保存します")
            return videoURL
        }

        let composition = AVMutableComposition()

        // ビデオトラックを追加
        guard let videoAsset = AVAsset(url: videoURL).tracks(withMediaType: .video).first else {
            print("❌ ビデオトラック取得失敗")
            return videoURL
        }

        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            return videoURL
        }

        do {
            try compositionVideoTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: videoAsset.timeRange.duration),
                of: videoAsset,
                at: .zero
            )
        } catch {
            print("❌ ビデオトラック挿入失敗: \(error)")
            return videoURL
        }

        // 音声トラックを追加（最大10秒）
        let audioAsset = AVAsset(url: audioURL)
        guard let audioTrack = audioAsset.tracks(withMediaType: .audio).first else {
            print("⚠️ 音声トラックが見つかりません")
            return videoURL
        }

        guard let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            return videoURL
        }

        let audioDuration = min(audioAsset.duration.seconds, 10.0)

        do {
            try compositionAudioTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: CMTime(seconds: audioDuration, preferredTimescale: 600)),
                of: audioTrack,
                at: .zero
            )
        } catch {
            print("❌ 音声トラック挿入失敗: \(error)")
            return videoURL
        }

        // 合成動画を出力
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("calligraphy_final_\(UUID().uuidString).mp4")

        try? FileManager.default.removeItem(at: outputURL)

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            print("❌ エクスポートセッション作成失敗")
            return videoURL
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        let semaphore = DispatchSemaphore(value: 0)

        exportSession.exportAsynchronously {
            semaphore.signal()
        }

        semaphore.wait()

        if exportSession.status == .completed {
            print("✅ 音声付き動画作成完了")
            return outputURL
        } else {
            print("❌ エクスポート失敗: \(exportSession.error?.localizedDescription ?? "不明")")
            return videoURL
        }
    }

    private func saveVideoToPhotoLibrary(_ videoURL: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                }) { success, error in
                    DispatchQueue.main.async {
                        self.isSavingVideo = false

                        if success {
                            print("✅ 動画をフォトライブラリに保存しました")
                        } else {
                            print("❌ 動画保存失敗: \(error?.localizedDescription ?? "不明")")
                        }

                        // 一時ファイルを削除
                        try? FileManager.default.removeItem(at: videoURL)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isSavingVideo = false
                    print("❌ フォトライブラリへのアクセスが許可されていません")
                }
            }
        }
    }

    private func captureScreenSnapshot() {
        print("📸 画面のスナップショット取得開始")

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("❌ ウィンドウが見つかりません")
            return
        }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let snapshot = renderer.image { context in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }

        // ZStack の部分だけをクロップ
        if let originalImage = originalImage {
            // ZStack の位置とサイズを計算して切り取る
            // (この部分は画面上の実際の位置を計算する必要があります)
            capturedSnapshot = snapshot
        }

        print("✅ スナップショット取得完了")
    }

    private func captureCurrentView() -> UIImage? {
        print("📸 現在の表示をキャプチャ")

        guard let originalImage = originalImage else { return processedImage }

        let size = originalImage.size
        let renderer = UIGraphicsImageRenderer(size: size)

        let capturedImage = renderer.image { context in
            // 1. 元の半紙
            originalImage.draw(at: .zero)

            // 2. 動画エフェクトの現在のフレーム
            // VideoEffectView をレンダリング
            if showVideoEffect {
                let videoView = VideoEffectView(
                    effectType: videoEffectType,
                    opacity: 0.7,
                    imageSize: size,
                    maxHeight: CGFloat(size.height)
                )

                let hostingController = UIHostingController(rootView: videoView)
                hostingController.view.frame = CGRect(origin: .zero, size: size)
                hostingController.view.backgroundColor = .clear

                // 少し待ってからレンダリング（動画の読み込みを待つ）
                Thread.sleep(forTimeInterval: 1.0)

                hostingController.view.drawHierarchy(
                    in: CGRect(origin: .zero, size: size),
                    afterScreenUpdates: true
                )
            }

            // 3. 色が変わった文字
            if let charImage = characterOnlyImage {
                charImage.draw(at: .zero, blendMode: .normal, alpha: 1.0)
            }
        }

        print("✅ キャプチャ完了")
        return capturedImage
    }

    private func postToFeed() {
        guard let image = capturedSnapshot ?? captureCurrentView(),
              let attributes = characterAttributes else {
            print("❌ 投稿: 画像または属性が見つかりません")
            return
        }

        isPostingToFeed = true
        print("📤 フィードに投稿中...")

        Task {
            do {
                let postId = try await PostManager.shared.uploadPost(
                    character: recognizedText,
                    image: image,
                    color: attributes.uiColor,
                    effectType: attributes.effectType,
                    soundType: attributes.soundType,
                    description: attributes.description,
                    caption: postCaption
                )

                DispatchQueue.main.async {
                    self.isPostingToFeed = false
                    self.showCaptionSheet = false
                    self.showPostSuccess = true
                    self.postCaption = ""
                    self.capturedSnapshot = nil
                    print("✅ 投稿完了: \(postId)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.isPostingToFeed = false
                    print("❌ 投稿失敗: \(error.localizedDescription)")
                    // TODO: Show error alert
                }
            }
        }
    }

    private func resetView() {
        selectedImage = nil
        processedImage = nil
        originalImage = nil
        characterOnlyImage = nil
        capturedSnapshot = nil
        recognizedText = ""
        characterAttributes = nil
        showResult = false
        isProcessing = false

        // 音声を停止
        ExpressionAudioEngine.shared.stopCurrentSound()

        // VideoEffectEngine の動画を停止
        showVideoEffect = false
        videoEffectEngine.stopAll()
    }
}

// MARK: - ImagePicker (UIKit Integration)

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let originalImage = info[.originalImage] as? UIImage {
                print("📸 画像取得:")
                print("   元の向き: \(originalImage.imageOrientation.rawValue)")
                print("   元のサイズ: \(originalImage.size)")

                // 画像を正しい向きに再描画
                let fixedImage = originalImage.normalizedImage()

                print("   修正後の向き: \(fixedImage.imageOrientation.rawValue)")
                print("   修正後のサイズ: \(fixedImage.size)")

                parent.image = fixedImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Caption Input View

struct CaptionInputView: View {
    @Binding var caption: String
    @Binding var isPosting: Bool
    let onPost: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    private let maxCharacters = 200

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Character count
                HStack {
                    Spacer()
                    Text("\(caption.count)/\(maxCharacters)")
                        .font(.caption)
                        .foregroundColor(caption.count > maxCharacters ? .red : .secondary)
                }
                .padding(.horizontal)

                // Text editor
                ZStack(alignment: .topLeading) {
                    if caption.isEmpty {
                        Text("この作品について...")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                    }

                    TextEditor(text: $caption)
                        .focused($isFocused)
                        .frame(minHeight: 150)
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("キャプションを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        onCancel()
                    }
                    .disabled(isPosting)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        onPost()
                    }) {
                        if isPosting {
                            ProgressView()
                        } else {
                            Text("投稿")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(caption.count > maxCharacters || isPosting)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}

#Preview {
    NavigationView {
        CreatyView()
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func normalizedImage() -> UIImage {
        // すでに正しい向きの場合
        if imageOrientation == .up {
            return self
        }

        // UIGraphicsImageRenderer を使って再描画
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
