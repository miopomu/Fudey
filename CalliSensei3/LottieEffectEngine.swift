import UIKit
import SwiftUI

/// Lottieエフェクトを管理するエンジン
/// 注: Lottieライブラリをインストール後に機能が有効化されます
class LottieEffectEngine {

    // MARK: - Properties

    static let shared = LottieEffectEngine()

    // エフェクトタイプの定義
    enum EffectType: String, CaseIterable {
        case sparkles   // キラキラ
        case fire       // 炎
        case water      // 水
        case wind       // 風
        case earth      // 土
        case light      // 光
        case dark       // 暗闇
        case nature     // 自然

        var lottieFileName: String {
            // Lottieアニメーションファイル名（.json）
            // Assets/Lottie/ フォルダに配置することを想定
            switch self {
            case .sparkles:
                return "sparkles_effect"
            case .fire:
                return "fire_effect"
            case .water:
                return "water_effect"
            case .wind:
                return "wind_effect"
            case .earth:
                return "earth_effect"
            case .light:
                return "light_effect"
            case .dark:
                return "dark_effect"
            case .nature:
                return "nature_effect"
            }
        }

        var fallbackSymbol: String {
            // Lottieが使えない場合のSF Symbolsアイコン
            switch self {
            case .sparkles:
                return "sparkles"
            case .fire:
                return "flame.fill"
            case .water:
                return "drop.fill"
            case .wind:
                return "wind"
            case .earth:
                return "globe.americas.fill"
            case .light:
                return "sun.max.fill"
            case .dark:
                return "moon.fill"
            case .nature:
                return "leaf.fill"
            }
        }
    }

    private init() {
        print("✅ LottieEffectEngine初期化")
    }

    // MARK: - Public Methods

    /// エフェクトビューを生成
    /// - Parameters:
    ///   - effectType: エフェクトタイプ（文字列）
    ///   - size: ビューのサイズ
    /// - Returns: エフェクトビュー（SwiftUI View）
    func createEffectView(type effectType: String, size: CGSize = CGSize(width: 200, height: 200)) -> AnyView {
        guard let type = EffectType(rawValue: effectType) else {
            print("⚠️ 未知のエフェクトタイプ: \(effectType)")
            return createFallbackView(type: .sparkles, size: size)
        }

        // Lottieが利用可能かチェック
        if isLottieAvailable() {
            return createLottieView(type: type, size: size)
        } else {
            print("ℹ️ Lottieライブラリが未インストール - フォールバック表示を使用")
            return createFallbackView(type: type, size: size)
        }
    }

    /// 画像にエフェクトを合成
    /// - Parameters:
    ///   - image: 元画像
    ///   - effectType: エフェクトタイプ
    ///   - color: エフェクトの色
    /// - Returns: エフェクトが合成された画像
    func applyEffect(to image: UIImage, effectType: String, color: UIColor) -> UIImage {
        // シンプルなエフェクト: 画像の色調を変更
        return applyColorTint(to: image, color: color)
    }

    // MARK: - Private Methods

    /// Lottieライブラリが利用可能かチェック
    private func isLottieAvailable() -> Bool {
        // Lottieライブラリがインストールされているかチェック
        // 実際にはLottieのクラスが存在するか確認
        // ここでは仮の実装
        return NSClassFromString("Lottie.LottieAnimationView") != nil
    }

    /// Lottieビューを作成（将来実装）
    private func createLottieView(type: EffectType, size: CGSize) -> AnyView {
        // TODO: Lottieライブラリがインストールされたら実装
        // import Lottie
        // let animationView = LottieAnimationView(name: type.lottieFileName)
        // animationView.loopMode = .loop
        // animationView.play()

        print("🎬 Lottieアニメーション: \(type.lottieFileName)")

        // 現在はフォールバックを返す
        return createFallbackView(type: type, size: size)
    }

    /// フォールバックビュー（SF Symbols使用）
    private func createFallbackView(type: EffectType, size: CGSize) -> AnyView {
        let view = FallbackEffectView(symbolName: type.fallbackSymbol, size: size)
        return AnyView(view)
    }

    /// 画像の黒い部分だけに色を適用
    private func applyColorTint(to image: UIImage, color: UIColor) -> UIImage {
        guard let ciImage = CIImage(image: image) else {
            print("❌ CIImage変換失敗")
            return image
        }

        print("🎨 色エフェクト適用開始")
        print("   元の色: 黒")
        print("   新しい色: RGB(\(color.cgColor.components?[0] ?? 0), \(color.cgColor.components?[1] ?? 0), \(color.cgColor.components?[2] ?? 0))")

        // 1. 黒い部分をマスクとして抽出
        let blackMask = createBlackMask(from: ciImage)

        // 2. 目標の色で塗りつぶした画像を作成
        let coloredLayer = createColorLayer(
            size: ciImage.extent.size,
            color: color
        )

        // 3. マスクを使って合成
        guard let composite = CIFilter(name: "CIBlendWithMask") else {
            print("❌ CIBlendWithMaskフィルタ取得失敗")
            return image
        }

        composite.setValue(coloredLayer, forKey: kCIInputImageKey)
        composite.setValue(ciImage, forKey: kCIInputBackgroundImageKey)
        composite.setValue(blackMask, forKey: kCIInputMaskImageKey)

        guard let output = composite.outputImage else {
            print("❌ 合成失敗")
            return image
        }

        // 光沢・グローエフェクトを追加
        let glowOutput = addGlowEffect(to: output)

        let context = CIContext()
        guard let cgImage = context.createCGImage(glowOutput, from: glowOutput.extent) else {
            print("❌ CGImage変換失敗")
            return image
        }

        print("✅ 色エフェクト適用完了（グロー付き）")
        return UIImage(cgImage: cgImage)
    }

    /// 黒い部分をマスクとして抽出
    private func createBlackMask(from image: CIImage) -> CIImage {
        // グレースケールに変換
        guard let grayscale = CIFilter(name: "CIPhotoEffectMono") else {
            print("⚠️ グレースケール変換スキップ")
            return image
        }
        grayscale.setValue(image, forKey: kCIInputImageKey)

        guard let gray = grayscale.outputImage else {
            return image
        }

        // 黒い部分を白く、それ以外を黒く（マスクを反転）
        guard let invert = CIFilter(name: "CIColorInvert") else {
            print("⚠️ 反転スキップ")
            return gray
        }
        invert.setValue(gray, forKey: kCIInputImageKey)

        guard let inverted = invert.outputImage else {
            return gray
        }

        // コントラストを強化（黒/白の境界をはっきり）
        guard let contrast = CIFilter(name: "CIColorControls") else {
            print("⚠️ コントラスト調整スキップ")
            return inverted
        }
        contrast.setValue(inverted, forKey: kCIInputImageKey)
        contrast.setValue(NSNumber(value: 2.0), forKey: kCIInputContrastKey)  // コントラスト強化

        return contrast.outputImage ?? inverted
    }

    /// 単色レイヤーを作成
    private func createColorLayer(size: CGSize, color: UIColor) -> CIImage {
        let rect = CGRect(origin: .zero, size: size)

        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        UIRectFill(rect)
        let colorImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let image = colorImage else {
            print("⚠️ カラーレイヤー作成失敗")
            return CIImage()
        }

        return CIImage(image: image) ?? CIImage()
    }

    /// グロー（光沢）エフェクトを追加
    private func addGlowEffect(to image: CIImage) -> CIImage {
        // CIBloomフィルタで白い光沢を追加
        guard let bloom = CIFilter(name: "CIBloom") else {
            print("⚠️ CIBloomフィルタ取得失敗 - グローなしで続行")
            return image
        }

        bloom.setValue(image, forKey: kCIInputImageKey)
        bloom.setValue(NSNumber(value: 3.0), forKey: kCIInputRadiusKey)  // グローの半径
        bloom.setValue(NSNumber(value: 1.0), forKey: kCIInputIntensityKey)  // グローの強度

        guard let bloomOutput = bloom.outputImage else {
            print("⚠️ グローエフェクト適用失敗")
            return image
        }

        print("✨ グローエフェクト追加完了")
        return bloomOutput
    }

    /// 文字だけの画像を生成（背景透明）
    /// - Parameters:
    ///   - image: 元画像
    ///   - attributes: 文字の属性
    /// - Returns: 文字だけの画像（背景透明）
    func createCharacterOnlyImage(
        from image: UIImage,
        attributes: CharacterAttributes
    ) -> UIImage? {
        print("🎨 文字だけの画像生成開始")

        guard let ciImage = CIImage(image: image) else {
            print("❌ CIImage変換失敗")
            return nil
        }

        // 1. 黒い部分をマスクとして抽出
        let blackMask = createBlackMask(from: ciImage)

        // 2. 目標の色で塗りつぶした画像を作成
        let coloredLayer = createColorLayer(
            size: ciImage.extent.size,
            color: attributes.uiColor
        )

        // 3. マスクを使って合成（背景は透明）
        guard let composite = CIFilter(name: "CIBlendWithMask") else {
            print("❌ CIBlendWithMaskフィルタ取得失敗")
            return nil
        }

        // 透明な背景を作成
        let transparentBackground = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0))
            .cropped(to: ciImage.extent)

        composite.setValue(coloredLayer, forKey: kCIInputImageKey)
        composite.setValue(transparentBackground, forKey: kCIInputBackgroundImageKey)
        composite.setValue(blackMask, forKey: kCIInputMaskImageKey)

        guard let output = composite.outputImage else {
            print("❌ 合成失敗")
            return nil
        }

        // 光沢・グローエフェクトを追加
        let glowOutput = addGlowEffect(to: output)

        let context = CIContext()
        guard let cgImage = context.createCGImage(glowOutput, from: glowOutput.extent) else {
            print("❌ CGImage変換失敗")
            return nil
        }

        print("✅ 文字だけの画像生成完了（グロー付き）")
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Fallback Effect View (SF Symbols)

struct FallbackEffectView: View {
    let symbolName: String
    let size: CGSize

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // 背景エフェクト（ぼかし）
            ForEach(0..<3) { index in
                Image(systemName: symbolName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width * 0.6, height: size.height * 0.6)
                    .foregroundColor(.white.opacity(0.2))
                    .blur(radius: 10)
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .opacity(isAnimating ? 0.3 : 0.7)
                    .animation(
                        Animation.easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.3),
                        value: isAnimating
                    )
            }

            // メインアイコン
            Image(systemName: symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: size.width * 0.5, height: size.height * 0.5)
                .foregroundColor(.white.opacity(0.8))
                .scaleEffect(isAnimating ? 1.1 : 0.9)
                .animation(
                    Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
        }
        .frame(width: size.width, height: size.height)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Extensions

extension LottieEffectEngine {
    /// CharacterAttributesからエフェクトビューを生成
    func createEffectView(for attributes: CharacterAttributes, size: CGSize = CGSize(width: 200, height: 200)) -> AnyView {
        return createEffectView(type: attributes.effectType, size: size)
    }

    /// CharacterAttributesを使って画像にエフェクトを適用
    func applyEffect(to image: UIImage, attributes: CharacterAttributes) -> UIImage {
        return applyEffect(to: image, effectType: attributes.effectType, color: attributes.uiColor)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        FallbackEffectView(symbolName: "sparkles", size: CGSize(width: 100, height: 100))
            .background(Color.blue.opacity(0.3))

        FallbackEffectView(symbolName: "flame.fill", size: CGSize(width: 100, height: 100))
            .background(Color.red.opacity(0.3))

        FallbackEffectView(symbolName: "drop.fill", size: CGSize(width: 100, height: 100))
            .background(Color.cyan.opacity(0.3))
    }
    .padding()
}
