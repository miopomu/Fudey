import AVFoundation
import UIKit

/// 表現モード専用の音声再生エンジン
class ExpressionAudioEngine {

    // MARK: - Properties

    static let shared = ExpressionAudioEngine()

    private var audioPlayers: [String: AVAudioPlayer] = [:]
    private var currentPlayer: AVAudioPlayer?
    private var stopTimer: Timer?  // 10秒で停止するタイマー
    private let maxDuration: TimeInterval = 10.0  // 最大再生時間

    // MARK: - 音声タイプの定義
    enum SoundType: String, CaseIterable {
        case bell       // 鐘の音（光、心など）
        case water      // 水の音（水、海、川など）
        case wind       // 風の音（風、空など）
        case fire       // 炎の音（火、熱、激しさ）
        case drum       // 太鼓の音（力、強さ）
        case strings    // 弦楽器（調和、優雅など）
        case nature     // 自然の音（木、森など）
        case mystical   // 神秘的な音（魂、精神など）

        var fileName: String {
            // 音声ファイル名（実際のファイルを用意する必要があります）
            switch self {
            case .bell:
                return "bell_sound"
            case .water:
                return "water_sound"
            case .wind:
                return "wind_sound"
            case .fire:
                return "fire_sound"
            case .drum:
                return "drum_sound"
            case .strings:
                return "strings_sound"
            case .nature:
                return "nature_sound"
            case .mystical:
                return "mystical_sound"
            }
        }
    }

    private init() {
        setupAudioSession()
        preloadSounds()
    }

    // MARK: - Setup

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            print("✅ ExpressionAudioEngine: 音声セッション設定完了")
        } catch {
            print("❌ ExpressionAudioEngine: 音声セッション設定失敗: \(error)")
        }
    }

    /// すべての音声ファイルを事前に読み込む
    private func preloadSounds() {
        for soundType in SoundType.allCases {
            loadSound(soundType)
        }
    }

    /// 特定の音声ファイルを読み込む
    private func loadSound(_ soundType: SoundType) {
        let fileName = soundType.fileName

        // 音声ファイルが存在しない場合はシステムサウンドで代替
        // 実際のプロジェクトでは、適切な音声ファイルをBundleに追加してください
        if let url = Bundle.main.url(forResource: fileName, withExtension: "wav") {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                audioPlayers[soundType.rawValue] = player
                print("✅ 音声読み込み成功: \(fileName).wav")
            } catch {
                print("❌ 音声読み込み失敗: \(fileName).wav - \(error)")
                // フォールバック: システムサウンドIDを記憶
                createFallbackSound(for: soundType)
            }
        } else {
            print("⚠️ 音声ファイルが見つかりません: \(fileName).wav - フォールバック音を使用")
            createFallbackSound(for: soundType)
        }
    }

    /// フォールバック用のシンプルな音を生成
    private func createFallbackSound(for soundType: SoundType) {
        // システムサウンドやビープ音などを使用
        // ここではプレースホルダーとして何もしない
        print("ℹ️ \(soundType.rawValue) のフォールバック音を設定")
    }

    // MARK: - Public Methods

    /// 指定した音声タイプを再生
    /// - Parameters:
    ///   - soundType: 再生する音声タイプ（文字列）
    ///   - volume: 音量（0.0〜1.0）
    func playSound(type soundType: String, volume: Float = 0.8) {
        // 既存の再生を停止
        stopCurrentSound()

        // 音声タイプを検証
        guard let type = SoundType(rawValue: soundType) else {
            print("⚠️ 未知の音声タイプ: \(soundType)")
            // フォールバック: bellを再生
            playSound(type: SoundType.bell.rawValue, volume: volume)
            return
        }

        if let player = audioPlayers[type.rawValue] {
            player.volume = volume
            player.currentTime = 0
            player.play()
            currentPlayer = player

            let playDuration = min(player.duration, maxDuration)
            print("🎵 音声再生: \(type.rawValue) (音量: \(Int(volume * 100))%, 再生時間: \(String(format: "%.1f", playDuration))秒)")

            // 10秒で停止するタイマーを設定
            stopTimer?.invalidate()
            stopTimer = Timer.scheduledTimer(withTimeInterval: maxDuration, repeats: false) { [weak self] _ in
                self?.stopCurrentSound()
                print("⏹️ 音声を10秒で停止しました")
            }
        } else {
            print("⚠️ 音声プレイヤーが見つかりません: \(type.rawValue)")
            playFallbackSound(for: type)
        }
    }

    /// 現在再生中の音声を停止
    func stopCurrentSound() {
        stopTimer?.invalidate()
        stopTimer = nil
        currentPlayer?.stop()
        currentPlayer?.currentTime = 0
        currentPlayer = nil
    }

    /// すべての音声を停止
    func stopAllSounds() {
        stopTimer?.invalidate()
        stopTimer = nil
        for (_, player) in audioPlayers {
            player.stop()
            player.currentTime = 0
        }
        currentPlayer = nil
    }

    /// フォールバック音を再生（音声ファイルがない場合）
    private func playFallbackSound(for soundType: SoundType) {
        // システムサウンドを使用
        // AudioServicesPlaySystemSoundなどを使用可能
        print("🔔 フォールバック音を再生: \(soundType.rawValue)")

        // iOS標準のシステムサウンドを再生（例）
        let systemSoundID: UInt32
        switch soundType {
        case .bell:
            systemSoundID = 1007 // SMS Received 1
        case .water:
            systemSoundID = 1023 // SMS Received 5
        case .wind:
            systemSoundID = 1013 // Anticipate
        case .fire:
            systemSoundID = 1020 // SMS Received 4 (炎のような音)
        case .drum:
            systemSoundID = 1003 // Tock
        case .strings:
            systemSoundID = 1025 // Swish
        case .nature:
            systemSoundID = 1033 // Bloom
        case .mystical:
            systemSoundID = 1036 // Calypso
        }

        AudioServicesPlaySystemSound(systemSoundID)
    }

    /// 音声ファイルが利用可能かチェック
    func isSoundAvailable(type: String) -> Bool {
        return audioPlayers[type] != nil
    }

    /// 利用可能な音声タイプのリストを取得
    func availableSoundTypes() -> [String] {
        return audioPlayers.keys.map { $0 }
    }
}

// MARK: - Extensions

extension ExpressionAudioEngine {
    /// CharacterAttributesから音声を再生
    func playSound(for attributes: CharacterAttributes, volume: Float = 0.8) {
        playSound(type: attributes.soundType, volume: volume)
    }
}
