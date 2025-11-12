import Foundation
import UIKit

/// 文字の属性をAIで自動判定するクラス
class CharacterAttributeAnalyzer {

    // MARK: - Properties

    static let shared = CharacterAttributeAnalyzer()

    private let apiEndpoint = "https://api.openai.com/v1/chat/completions"

    // APIキャッシュ（同じ文字は再判定しない）
    private var cache: [String: CharacterAttributes] = [:]

    private init() {
        print("✅ CharacterAttributeAnalyzer初期化")
    }

    // MARK: - Public Methods (既存インターフェース維持)

    /// 文字の属性を解析（completionベース）
    func analyzeCharacter(_ character: String, completion: @escaping (Result<CharacterAttributes, Error>) -> Void) {
        Task {
            do {
                let attributes = try await analyze(character)
                DispatchQueue.main.async {
                    completion(.success(attributes))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - AI Analysis

    /// 文字をAIで解析（async/await版）
    func analyze(_ character: String) async throws -> CharacterAttributes {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🤖 AI判定開始: 「\(character)」")

        // キャッシュチェック
        if let cached = cache[character] {
            print("✅ キャッシュから取得")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            return cached
        }

        // Claude APIで判定
        do {
            let attributes = try await analyzeWithAI(character)
            cache[character] = attributes
            print("✅ AI判定成功")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            return attributes
        } catch {
            print("⚠️ AI判定失敗、ミニマル辞書を使用")
            print("   エラー: \(error.localizedDescription)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            return getMinimalFallback(character)
        }
    }

    private func analyzeWithAI(_ character: String) async throws -> CharacterAttributes {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
              !apiKey.isEmpty else {
            print("⚠️ APIキー未設定")
            throw AnalyzerError.apiKeyMissing
        }

        let prompt = """
この漢字「\(character)」に最適な視覚エフェクトを判定してください。

以下の形式でJSON出力してください：

{
  "character": "\(character)",
  "element": "選択肢から1つ",
  "reasoning": "簡単な理由",
  "colors": ["#RRGGBB", "#RRGGBB"],
  "effectType": "選択肢から1つ",
  "soundType": "選択肢から1つ"
}

elementの選択肢：
- water（水、液体、流れ）
- fire（火、熱、激しさ）
- earth（土、石、安定）
- wind（風、空気、軽やかさ）
- light（光、明るさ、希望）
- plant（植物、成長、生命）
- metal（金属、硬さ、鋭さ）
- ice（氷、冷たさ、静寂）
- thunder（雷、電気、瞬発力）
- void（無、暗闇、神秘）
- abstract（抽象、感情、概念）

effectTypeの選択肢：
- sparkles（キラキラ）
- fire（炎）
- water（水滴）
- wind（風）
- earth（土）
- light（光）
- dark（暗闇）
- nature（自然）

soundTypeの選択肢（必ずこの8種類のいずれか1つを選んでください）：
- bell: 鐘の音（光、心、希望など）
- water: 水の音（水、海、川、流れなど）
- wind: 風の音（風、空、軽やかさなど）
- fire: 炎の音（火、熱、激しさ、燃える）
- drum: 太鼓の音（力、強さ、鼓動など）
- strings: 弦楽器（調和、優雅、美しさなど）
- nature: 自然の音（木、森、植物、大地など）
- mystical: 神秘的な音（魂、精神、無、静寂など）

【重要】どの文字でも必ず上記8種類のいずれか1つを選んでください。
最も近いイメージのものを選択してください。
他の値は使用しないでください

colors：
- 2色のグラデーション用カラーコード（#RRGGBB形式）
- その文字のイメージに最も合う色を選択
- 例：水なら["#00CED1", "#1E90FF"]（ターコイズ→青）

判定基準：
1. 文字の意味・イメージを最優先
2. 五行思想も参考に
3. 視覚的に美しい色の組み合わせ
4. 文字が持つ「動き」「温度」「重さ」を表現

例：
- 「永」→ water（永遠の流れ）、青系グラデーション
- 「山」→ earth（大地）、茶色系グラデーション
- 「愛」→ abstract（感情）、ピンク系グラデーション
- 「龍」→ thunder（力強さ）、紫→金色グラデーション
- 「静」→ void（静けさ）、藍色系グラデーション

JSON形式のみで回答してください。
"""

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw AnalyzerError.invalidURL
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
                    "content": prompt
                ]
            ],
            "max_tokens": 500
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("🚀 OpenAI APIリクエスト送信中...")

        let (data, _) = try await URLSession.shared.data(for: request)

        // レスポンスパース
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let text = response.choices.first?.message.content else {
            throw AnalyzerError.invalidResponse
        }

        print("📝 AI応答:")
        print(text)

        // JSONを抽出（```json ``` で囲まれている場合に対応）
        let jsonText = extractJSON(from: text)
        let jsonData = jsonText.data(using: .utf8)!
        let aiResult = try JSONDecoder().decode(AIAnalysisResult.self, from: jsonData)

        print("🎨 判定結果:")
        print("   Element: \(aiResult.element)")
        print("   Colors: \(aiResult.colors)")
        print("   Effect: \(aiResult.effectType)")
        print("   Sound: \(aiResult.soundType)")
        print("   理由: \(aiResult.reasoning)")

        // CharacterAttributesに変換
        return convertToCharacterAttributes(aiResult)
    }

    private func extractJSON(from text: String) -> String {
        // ```json ``` を除去
        if let startIndex = text.range(of: "```json")?.upperBound,
           let endIndex = text.range(of: "```", range: startIndex..<text.endIndex)?.lowerBound {
            return String(text[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // { } で囲まれた部分を抽出
        if let startIndex = text.firstIndex(of: "{"),
           let endIndex = text.lastIndex(of: "}") {
            return String(text[startIndex...endIndex])
        }

        return text
    }

    private func convertToCharacterAttributes(_ result: AIAnalysisResult) -> CharacterAttributes {
        // 2色グラデーションの平均色を使用（シンプルな実装）
        let color1 = hexToUIColor(result.colors.first ?? "#2F4F4F")
        let color2 = hexToUIColor(result.colors.last ?? "#708090")

        // 2色の平均を計算
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let avgColor = ColorInfo(
            red: Double((r1 + r2) / 2),
            green: Double((g1 + g2) / 2),
            blue: Double((b1 + b2) / 2),
            alpha: 0.95
        )

        return CharacterAttributes(
            character: result.character,
            color: avgColor,
            effectType: result.effectType,
            soundType: result.soundType,
            description: result.reasoning
        )
    }

    // MARK: - Minimal Fallback (APIエラー時のみ)

    private func getMinimalFallback(_ character: String) -> CharacterAttributes {
        // 超基本的な3文字だけ
        let minimal: [String: CharacterAttributes] = [
            "水": CharacterAttributes(
                character: "水",
                color: ColorInfo(red: 0.0, green: 0.808, blue: 0.82, alpha: 0.95),
                effectType: "water",
                soundType: "water",
                description: "水の流れ"
            ),
            "火": CharacterAttributes(
                character: "火",
                color: ColorInfo(red: 1.0, green: 0.27, blue: 0.0, alpha: 0.95),
                effectType: "fire",
                soundType: "fire",
                description: "炎の力"
            ),
            "風": CharacterAttributes(
                character: "風",
                color: ColorInfo(red: 0.53, green: 0.81, blue: 0.92, alpha: 0.9),
                effectType: "wind",
                soundType: "wind",
                description: "風の軽やかさ"
            )
        ]

        if let theme = minimal[character] {
            return theme
        }

        // 完全に未知の場合はデフォルト（黒→グレー）
        return CharacterAttributes(
            character: character,
            color: ColorInfo(red: 0.18, green: 0.31, blue: 0.31, alpha: 0.95),
            effectType: "sparkles",
            soundType: "bell",
            description: "書道の伝統的な墨色"
        )
    }

    // MARK: - Utilities

    private func hexToUIColor(_ hex: String) -> UIColor {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanHex = cleanHex.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&rgb)

        return UIColor(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}

// MARK: - Models

/// AI応答の構造体
struct AIAnalysisResult: Codable {
    let character: String
    let element: String
    let reasoning: String
    let colors: [String]
    let effectType: String
    let soundType: String
}

/// OpenAI API応答
struct OpenAIResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}

/// 文字の属性情報（既存との互換性維持）
struct CharacterAttributes: Codable {
    let character: String
    let color: ColorInfo
    let effectType: String
    let soundType: String
    let description: String

    var uiColor: UIColor {
        UIColor(
            red: CGFloat(color.red),
            green: CGFloat(color.green),
            blue: CGFloat(color.blue),
            alpha: CGFloat(color.alpha)
        )
    }

    var debugDescription: String {
        """
        文字: \(character)
        色: RGB(\(String(format: "%.2f", color.red)), \(String(format: "%.2f", color.green)), \(String(format: "%.2f", color.blue)))
        エフェクト: \(effectType)
        サウンド: \(soundType)
        説明: \(description)
        """
    }
}

/// 色情報
struct ColorInfo: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
}

// MARK: - Errors

enum AnalyzerError: LocalizedError {
    case invalidURL
    case noData
    case invalidResponse
    case apiKeyMissing

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無効なURL"
        case .noData:
            return "データが取得できませんでした"
        case .invalidResponse:
            return "無効なレスポンス"
        case .apiKeyMissing:
            return "APIキーが設定されていません"
        }
    }
}
