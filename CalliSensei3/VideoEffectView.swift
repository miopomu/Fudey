import SwiftUI
import AVKit

struct VideoEffectView: UIViewRepresentable {
    let effectType: String
    let opacity: Float
    let imageSize: CGSize
    let maxHeight: CGFloat

    func makeUIView(context: Context) -> VideoEffectHostView {
        print("📱 VideoEffectView.makeUIView 呼び出し")
        print("   imageSize: \(imageSize)")
        print("   maxHeight: \(maxHeight)")
        let view = VideoEffectHostView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: VideoEffectHostView, context: Context) {
        print("🔄 VideoEffectView.updateUIView 呼び出し")
        print("   ビューサイズ: \(uiView.bounds)")
        print("   effectType: \(effectType)")

        if uiView.effectEngine == nil {
            print("   エンジン初期化")
            let engine = VideoEffectEngine()
            uiView.effectEngine = engine

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("⏰ 動画再生開始（遅延後）")
                print("   最終ビューサイズ: \(uiView.bounds)")
                engine.playFullScreenEffect(
                    type: effectType,
                    on: uiView,
                    opacity: opacity
                )
            }
        }
    }
}

class VideoEffectHostView: UIView {
    var effectEngine: VideoEffectEngine?

    override var bounds: CGRect {
        didSet {
            print("📐 VideoEffectHostView bounds変更: \(bounds)")
        }
    }

    deinit {
        print("🗑️ VideoEffectHostView deinit")
        effectEngine?.stopAll()
    }
}
