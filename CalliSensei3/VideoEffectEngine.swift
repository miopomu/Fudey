import AVKit
import AVFoundation
import UIKit

/// 動画エフェクトを管理するエンジン
class VideoEffectEngine {
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?

    // 8種類のエフェクト動画
    private let effectVideos: [String: String] = [
        // effectType に対応
        "sparkles": "mystical_effect",
        "water": "water_effect",
        "wind": "wind_effect",
        "fire": "fire_effect",
        "earth": "nature_effect",
        "light": "bell_effect",
        "nature": "nature_effect",

        // soundType にも対応（後方互換性）
        "bell": "bell_effect",
        "drum": "drum_effect",
        "strings": "strings_effect",
        "mystical": "mystical_effect",

        // デフォルト
        "default": "water_effect"
    ]

    /// 全画面に動画エフェクトを表示
    /// - Parameters:
    ///   - type: エフェクトタイプ
    ///   - view: 配置先のビュー
    ///   - opacity: 動画の不透明度
    func playFullScreenEffect(
        type: String,
        on view: UIView,
        opacity: Float = 0.5
    ) {
        print("🎬 全画面動画エフェクト開始: \(type)")

        let videoName = effectVideos[type] ?? effectVideos["default"]!
        print("   選択された動画: \(videoName)")

        print("🔍 動画ファイル検索:")
        print("   リソース名: \(videoName)")
        print("   拡張子: mp4")

        // Bundle内の全動画ファイルを確認
        let videoPaths = Bundle.main.paths(forResourcesOfType: "mp4", inDirectory: nil)
        print("   Bundle内のmp4ファイル:")
        for path in videoPaths {
            print("     - \((path as NSString).lastPathComponent)")
        }

        guard let videoURL = Bundle.main.url(
            forResource: videoName,
            withExtension: "mp4"
        ) else {
            print("❌ 動画ファイルが見つかりません: \(videoName).mp4")
            return
        }

        print("✅ 動画ファイル発見: \(videoURL.lastPathComponent)")

        // 既存のプレイヤーを停止
        stopAll()

        // 新しいプレイヤーを作成
        let player = AVPlayer(url: videoURL)
        player.isMuted = true

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = view.bounds
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.opacity = opacity

        // 背景レイヤーとして最下層に追加
        view.layer.insertSublayer(playerLayer, at: 0)

        // ループ再生
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        self.player = player
        self.playerLayer = playerLayer

        player.play()

        print("✅ 動画再生中: \(videoName)")
    }

    /// 全ての動画エフェクトを停止・削除
    func stopAll() {
        print("🛑 動画エフェクトを停止")
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        player = nil
        playerLayer = nil
    }
}
