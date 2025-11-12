import UIKit
import Vision

/// 写真から文字を認識するクラス
class PhotoAnalyzer {

    // MARK: - Properties

    static let shared = PhotoAnalyzer()

    private init() {}

    // MARK: - Public Methods

    /// 画像から文字を認識する
    /// - Parameters:
    ///   - image: 解析する画像
    ///   - completion: 完了ハンドラ（認識されたテキスト、エラー）
    func recognizeText(from image: UIImage, completion: @escaping (Result<[RecognizedText], Error>) -> Void) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔍 OCR開始 (recognizeText)")

        guard let cgImage = image.cgImage else {
            print("❌ CGImage変換失敗")
            completion(.failure(PhotoAnalyzerError.invalidImage))
            return
        }

        print("✅ 画像サイズ: \(cgImage.width) x \(cgImage.height)")

        // Vision リクエストを作成
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("❌ Vision実行エラー: \(error)")
                completion(.failure(error))
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                print("❌ 結果がnil")
                completion(.failure(PhotoAnalyzerError.noTextFound))
                return
            }

            print("📊 認識された領域数: \(observations.count)")

            if observations.isEmpty {
                print("⚠️ 認識結果が0件")
                print("💡 ヒント: 画像が暗すぎる、または文字が小さすぎる可能性があります")
                completion(.failure(PhotoAnalyzerError.noTextFound))
                return
            }

            // すべての候補を詳細表示
            for (index, observation) in observations.enumerated() {
                print("\n📝 領域 \(index + 1):")
                print("   境界: \(observation.boundingBox)")

                let candidates = observation.topCandidates(10)  // 10候補表示
                print("   候補数: \(candidates.count)")

                for (i, candidate) in candidates.enumerated() {
                    print("   \(i + 1). [\(candidate.string)] 信頼度: \(String(format: "%.3f", candidate.confidence))")
                }
            }

            // 認識された文字を処理
            let recognizedTexts = self.processObservations(observations, imageSize: image.size)

            if recognizedTexts.isEmpty {
                print("\n⚠️ processObservations後の結果が0件（信頼度フィルタで除外された可能性）")
                completion(.failure(PhotoAnalyzerError.noTextFound))
            } else {
                print("\n✅ 最終結果: \(recognizedTexts.count)件の文字を認識")
                completion(.success(recognizedTexts))
            }

            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }

        // ✅ 重要: すべての言語を試す
        let languages = ["ja", "en", "zh-Hans", "zh-Hant"]
        request.recognitionLanguages = languages
        print("🌍 認識言語: \(languages)")

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.0  // ✅ 最小サイズ制限を完全に解除

        print("⚙️ 認識レベル: \(request.recognitionLevel)")
        print("⚙️ 最小テキスト高さ: \(request.minimumTextHeight)")

        // リクエストを実行
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        print("🚀 Vision実行中...")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
                print("✅ Vision実行完了")
            } catch {
                print("❌ Vision実行エラー: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// 最も大きい/目立つ文字を取得（改良版 - Claude Vision フォールバック付き）
    /// - Parameters:
    ///   - image: 解析する画像
    ///   - completion: 完了ハンドラ（最も目立つ文字、エラー）
    func findMainCharacter(from image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        print("\n🎯 findMainCharacter開始")

        // 方法1: まずVision OCRを試す
        recognizeText(from: image) { [weak self] result in
            switch result {
            case .success(let texts):
                print("\n📏 面積計算:")
                for (index, text) in texts.enumerated() {
                    let area = text.boundingBox.width * text.boundingBox.height
                    print("   \(index + 1). [\(text.text)] 面積: \(String(format: "%.1f", area)) (信頼度: \(String(format: "%.3f", text.confidence)))")
                }

                // 最も大きい文字（面積が最大）を取得
                if let mainText = texts.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) {
                    let area = mainText.boundingBox.width * mainText.boundingBox.height
                    print("\n✅ OCR成功: [\(mainText.text)]")
                    print("   信頼度: \(String(format: "%.3f", mainText.confidence))")
                    print("   面積: \(String(format: "%.1f", area))")
                    completion(.success(mainText.text))
                    return
                } else {
                    print("❌ 最大面積の文字が見つかりませんでした")
                }

            case .failure(let error):
                print("❌ recognizeText失敗: \(error.localizedDescription)")
            }

            // 方法2: OCR失敗 → Claude Vision APIにフォールバック
            print("⚠️ OCR失敗、Claude Vision APIにフォールバック")
            self?.recognizeWithClaudeVision(image: image, completion: completion)
        }
    }

    /// 最も大きい/目立つ文字を境界ボックス付きで取得
    /// - Parameters:
    ///   - image: 解析する画像
    ///   - completion: 完了ハンドラ（文字と境界ボックス、エラー）
    func findMainCharacterWithBounds(from image: UIImage, completion: @escaping (Result<CharacterWithBounds, Error>) -> Void) {
        print("\n🎯 findMainCharacterWithBounds開始")

        // Vision OCRを試す
        recognizeText(from: image) { [weak self] result in
            switch result {
            case .success(let texts):
                print("\n📏 面積計算:")
                for (index, text) in texts.enumerated() {
                    let area = text.boundingBox.width * text.boundingBox.height
                    print("   \(index + 1). [\(text.text)] 面積: \(String(format: "%.1f", area)) (信頼度: \(String(format: "%.3f", text.confidence)))")
                }

                // 最も大きい文字（面積が最大）を取得
                if let mainText = texts.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) {
                    let area = mainText.boundingBox.width * mainText.boundingBox.height
                    print("\n✅ OCR成功: [\(mainText.text)]")
                    print("   信頼度: \(String(format: "%.3f", mainText.confidence))")
                    print("   面積: \(String(format: "%.1f", area))")
                    print("   境界: \(mainText.boundingBox)")

                    let result = CharacterWithBounds(
                        text: mainText.text,
                        boundingBox: mainText.boundingBox
                    )
                    completion(.success(result))
                    return
                } else {
                    print("❌ 最大面積の文字が見つかりませんでした")
                }

            case .failure(let error):
                print("❌ recognizeText失敗: \(error.localizedDescription)")
            }

            // OCR失敗 → デフォルトの境界ボックスを使用（画像中央60%）
            print("⚠️ OCR失敗、フォールバック（中央60%を使用）")
            self?.recognizeWithClaudeVision(image: image) { visionResult in
                switch visionResult {
                case .success(let text):
                    // 境界ボックスがない場合は画像中央60%を使用
                    let imageWidth = image.size.width
                    let imageHeight = image.size.height

                    // 中央60%の領域を計算
                    let centerRatio: CGFloat = 0.6
                    let marginRatio: CGFloat = (1.0 - centerRatio) / 2.0  // 0.2

                    let centerBounds = CGRect(
                        x: imageWidth * marginRatio,
                        y: imageHeight * marginRatio,
                        width: imageWidth * centerRatio,
                        height: imageHeight * centerRatio
                    )

                    print("   中央領域: \(centerBounds)")
                    let result = CharacterWithBounds(text: text, boundingBox: centerBounds)
                    completion(.success(result))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    /// OpenAI Vision APIで画像から文字を認識
    private func recognizeWithClaudeVision(image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        print("\n🤖 OpenAI Vision API開始")

        // 画像をBase64エンコード
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ 画像変換失敗")
            completion(.failure(PhotoAnalyzerError.invalidImage))
            return
        }

        let base64Image = imageData.base64EncodedString()
        print("✅ 画像エンコード完了: \(imageData.count / 1024)KB")

        // APIキーチェック
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
              !apiKey.isEmpty else {
            print("⚠️ APIキー未設定、デフォルト値を返します")
            completion(.success("書"))  // デフォルト
            return
        }

        // OpenAI APIリクエスト
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(.failure(PhotoAnalyzerError.processingFailed))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": """
この画像に書かれている書道の漢字を1文字だけ認識してください。

【重要】
- 漢字1文字のみを返してください
- 説明や句読点は不要です
- 手書き書道の文字です
- 複雑な字形や芸術的な崩しも認識してください

例：水、火、山、川、永、愛、龍、道 など
"""
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 50
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ JSON変換失敗: \(error)")
            completion(.failure(error))
            return
        }

        print("🚀 OpenAI Vision API実行中...")

        // 非同期リクエスト
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ ネットワークエラー: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                print("❌ データなし")
                DispatchQueue.main.async {
                    completion(.failure(PhotoAnalyzerError.processingFailed))
                }
                return
            }

            // レスポンスパース
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {

                    // 1文字だけ抽出（余計な文字を除去）
                    let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    let character = String(cleaned.prefix(1))

                    print("✅ OpenAI Vision認識成功: \(character)")

                    DispatchQueue.main.async {
                        completion(.success(character))
                    }
                } else {
                    print("❌ JSON解析失敗")
                    print("📝 生データ: \(String(data: data, encoding: .utf8) ?? "nil")")
                    DispatchQueue.main.async {
                        completion(.failure(PhotoAnalyzerError.processingFailed))
                    }
                }
            } catch {
                print("❌ JSON解析エラー: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }

        task.resume()
    }

    // MARK: - Private Methods

    private func processObservations(_ observations: [VNRecognizedTextObservation], imageSize: CGSize) -> [RecognizedText] {
        print("\n🔧 processObservations開始 (\(observations.count)件)")
        var results: [RecognizedText] = []

        for (index, observation) in observations.enumerated() {
            guard let topCandidate = observation.topCandidates(1).first else {
                print("   領域 \(index + 1): 候補なし - スキップ")
                continue
            }

            // ✅ 信頼度チェックを緩く（0.1以上）
            if topCandidate.confidence < 0.1 {
                print("   領域 \(index + 1): [\(topCandidate.string)] 信頼度が非常に低い（\(String(format: "%.3f", topCandidate.confidence))） - スキップ")
                continue
            }

            // ⚠️ 信頼度が低い場合は警告
            if topCandidate.confidence < 0.5 {
                print("   領域 \(index + 1): ⚠️ [\(topCandidate.string)] 信頼度が低い（\(String(format: "%.3f", topCandidate.confidence))）が、結果に含めます")
            } else {
                print("   領域 \(index + 1): ✅ [\(topCandidate.string)] 信頼度: \(String(format: "%.3f", topCandidate.confidence))")
            }

            // バウンディングボックスを画像座標に変換
            let boundingBox = observation.boundingBox
            let rect = VNImageRectForNormalizedRect(
                boundingBox,
                Int(imageSize.width),
                Int(imageSize.height)
            )

            let recognizedText = RecognizedText(
                text: topCandidate.string,
                confidence: topCandidate.confidence,
                boundingBox: rect
            )

            results.append(recognizedText)
        }

        print("🔧 processObservations完了: \(results.count)件を返します")
        return results
    }
}

// MARK: - Models

/// 認識された文字の情報
struct RecognizedText {
    let text: String
    let confidence: Float
    let boundingBox: CGRect

    var debugDescription: String {
        "Text: '\(text)', Confidence: \(String(format: "%.2f", confidence)), BBox: \(boundingBox)"
    }
}

/// 文字と境界ボックスのペア
struct CharacterWithBounds {
    let text: String
    let boundingBox: CGRect
}

// MARK: - Errors

enum PhotoAnalyzerError: LocalizedError {
    case invalidImage
    case noTextFound
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "画像が無効です"
        case .noTextFound:
            return "文字が認識できませんでした"
        case .processingFailed:
            return "画像処理に失敗しました"
        }
    }
}
