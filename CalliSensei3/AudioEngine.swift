import AVFoundation
import UIKit

struct ForceSample: Codable {
    let time: TimeInterval
    let force: CGFloat
}

struct StrokeAudioRecording: Codable {
    let strokeNumber: Int
    let audioData: Data
    let duration: TimeInterval
    let timestamp: Date
    let sampleRate: Double
    let channels: UInt32
    
    let initialForce: CGFloat
    let forceSamples: [ForceSample]
}

// シンプルな音声エンジン - 習字アプリ用
class CalligraphyAudioEngine: NSObject, ObservableObject {
    
    static let shared = CalligraphyAudioEngine()
    
    // 2つの音声プレイヤー
    private var heavyPlayer: AVAudioPlayer?      // 筆を置くときの音
    private var lightPlayer: AVAudioPlayer?      // 書いている最中の音
    
    // なぞり書きモード用
    var isLearningMode: Bool = false
        
        // 録音用（ここから追加）
        private var currentStrokeForces: [ForceSample] = []
        private var strokeRecordingStartTime: Date?
        private var recordedStrokes: [StrokeAudioRecording] = []
        
        // 再生用
        private var currentPlayingStrokeIndex = 0
        private var strokeRecordings: [StrokeAudioRecording] = []
        private var playbackTimer: Timer?
    
    override init() {
        super.init()
        setupAudioSession()
        loadAudioFiles()
    }
    
    // MARK: - 初期設定
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            print("✅ 音声セッション設定完了")
        } catch {
            print("❌ 音声セッション設定失敗: \(error)")
        }
    }
    
    private func loadAudioFiles() {
        // heavy_pressure.wav を読み込み
        if let heavyURL = Bundle.main.url(forResource: "heavy_pressure", withExtension: "wav") {
            do {
                heavyPlayer = try AVAudioPlayer(contentsOf: heavyURL)
                heavyPlayer?.prepareToPlay()
                print("✅ heavy_pressure.wav 読み込み完了")
            } catch {
                print("❌ heavy_pressure.wav 読み込み失敗: \(error)")
            }
        }
        
        // light_pressure.wav を読み込み
        if let lightURL = Bundle.main.url(forResource: "light_pressure", withExtension: "wav") {
            do {
                lightPlayer = try AVAudioPlayer(contentsOf: lightURL)
                lightPlayer?.numberOfLoops = -1  // 無限ループ
                lightPlayer?.prepareToPlay()
                print("✅ light_pressure.wav 読み込み完了")
            } catch {
                print("❌ light_pressure.wav 読み込み失敗: \(error)")
            }
        }
    }
    
    // MARK: - 音声再生メソッド
    
    /// 筆を置いたとき（heavy_pressure を1回再生）
    func playInitialTouch(force: CGFloat = 0.7) {
        guard !isLearningMode else {
            print("⚠️ なぞり書きモードのため音声再生スキップ")
            return
        }

        print("🥁 筆を置く: heavy_pressure 再生試行")
        print("   heavyPlayer存在: \(heavyPlayer != nil)")

        if heavyPlayer == nil {
            print("❌ heavyPlayerがnil - 音声ファイルが読み込まれていません")
            return
        }

        // ✅ 修正: 音量を大きく（0.2-1.0 → 0.5-1.0）
        let adjustedForce = pow(Float(force), 1.5)
        let volume = max(0.5, min(1.0, 0.5 + adjustedForce * 0.5))  // 最小50%
        heavyPlayer?.volume = volume
        heavyPlayer?.play()

        print("   設定音量: \(Int(volume * 100))%")
        print("   再生中: \(heavyPlayer?.isPlaying ?? false)")
    }
    
    /// 書いている最中（light_pressure をループ再生）
    func playContinuousDrawing(force: CGFloat) {
        guard !isLearningMode else { return }

        // 既に再生中でなければ開始
        if lightPlayer?.isPlaying != true {
            print("🌊 書き始め: light_pressure ループ開始")
            lightPlayer?.play()
        }

        // ✅ 修正: 音量を大きく（0.1-1.0 → 0.4-1.0）
        let adjustedForce = pow(Float(force), 2.0)
        let volume = 0.4 + adjustedForce * 0.6  // 最小40%
        lightPlayer?.volume = volume

        print("📊 筆圧: \(Int(force * 100))% → 音量: \(Int(volume * 100))%")
    }
    
    /// 筆を離したとき（すべての音を停止）
    func stopDrawingAudio() {
        print("🛑 筆を離す: すべての音を停止")

        // ✅ タイマーを先に停止
        playbackTimer?.invalidate()
        playbackTimer = nil

        // ✅ light_pressureを確実に停止
        lightPlayer?.stop()
        lightPlayer?.currentTime = 0
        lightPlayer?.numberOfLoops = -1  // ループ設定を復元

        // ✅ heavy_pressureを確実に停止
        heavyPlayer?.stop()
        heavyPlayer?.currentTime = 0

        print("   停止確認: light=\(!(lightPlayer?.isPlaying ?? true)), heavy=\(!(heavyPlayer?.isPlaying ?? true))")
    }
    
    // MARK: - エンジン制御（互換性のため残す）
    
    func startEngine() {
        print("✅ エンジン開始（シンプル版では不要）")
    }
    
    func stopEngine() {
        print("🛑 エンジン停止")
        heavyPlayer?.stop()
        lightPlayer?.stop()
    }
    
    // MARK: - なぞり書きモード関連（後で実装）
    
    var isInLearningMode: Bool {
        return isLearningMode
    }
    
    func setLearningMode(_ enabled: Bool, strokeRecordings: [StrokeAudioRecording] = []) {
        isLearningMode = enabled
        self.strokeRecordings = strokeRecordings
        currentPlayingStrokeIndex = 0
        
        if enabled {
            print("🔧 なぞり書きモード: ON - \(strokeRecordings.count)ストロークのデータを読み込み")
        } else {
            print("🔧 テンプレートモード: ON")
        }
    }
    
    func loadRecordedAudio(for character: String) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔍 音声データ読み込み試行: \(character)")

        // DEPRECATED: ローカル音声データ機能は廃止されました
        print("⚠️ 音声録音機能は現在非対応です")
        print("❌ \(character) の音声データが見つかりません")
        print("   ファイルパス確認が必要")
        self.strokeRecordings = []
        self.isLearningMode = true  // ✅ 鑑賞モード用に true に変更
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    // 外部からストロークインデックスにアクセス可能にする
    var currentStrokeIndex: Int {
        get { return currentPlayingStrokeIndex }
        set { currentPlayingStrokeIndex = newValue }
    }
    
    func moveToNextStroke() {
        currentPlayingStrokeIndex += 1
        print("➡️ 次のストローク: \(currentPlayingStrokeIndex + 1)")
    }
    
    func resetStrokeIndex() {
        currentPlayingStrokeIndex = 0
        print("🔄 ストローク番号をリセット")
    }
    
    func playRecordedStrokeAudio() {
        // ✅ デバッグログ追加
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎵 playRecordedStrokeAudio呼び出し")
        print("   isLearningMode: \(isLearningMode)")
        print("   currentPlayingStrokeIndex: \(currentPlayingStrokeIndex)")
        print("   strokeRecordings.count: \(strokeRecordings.count)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        guard isLearningMode else {
            print("❌ isLearningMode=falseのため音声再生スキップ")
            return
        }

        guard currentPlayingStrokeIndex < strokeRecordings.count else {
            print("⚠️ ストローク \(currentPlayingStrokeIndex + 1) のデータがありません")
            print("   strokeRecordings.count = \(strokeRecordings.count)")
            return
        }

        // ✅ 追加: 完全リセット
        print("🔄 音声プレイヤーを完全リセット")
        playbackTimer?.invalidate()
        playbackTimer = nil

        lightPlayer?.stop()
        lightPlayer?.currentTime = 0
        lightPlayer?.numberOfLoops = -1
        lightPlayer?.prepareToPlay()  // ✅ 追加

        heavyPlayer?.stop()
        heavyPlayer?.currentTime = 0
        heavyPlayer?.prepareToPlay()  // ✅ 追加

        print("✅ リセット完了")

        // ✅ 修正: 待ち時間を短縮（0.15秒 → 0.05秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }

            let recording = self.strokeRecordings[self.currentPlayingStrokeIndex]

            print("🎓 なぞり書きモード: ストローク \(recording.strokeNumber) の音声再生開始")
            print("   初期筆圧: \(String(format: "%.2f", recording.initialForce))")
            print("   筆圧サンプル数: \(recording.forceSamples.count)")

            // 1. heavy_pressureを初期筆圧で再生
            let adjustedForce = pow(Float(recording.initialForce), 1.5)
            let volume = max(0.5, min(1.0, 0.5 + adjustedForce * 0.5))
            self.heavyPlayer?.volume = volume
            self.heavyPlayer?.play()
            print("🥁 heavy_pressure再生: 音量\(Int(volume * 100))%")

            let heavyDuration = self.heavyPlayer?.duration ?? 0.3
            print("⏱️ heavy_pressure長さ: \(String(format: "%.3f", heavyDuration))秒")

            self.playForceSamples(recording.forceSamples, afterDelay: heavyDuration)
        }
    }

    private func playForceSamples(_ samples: [ForceSample], afterDelay delay: TimeInterval) {
        guard !samples.isEmpty else { return }
        guard let lastSample = samples.last else { return }

        // ✅ 修正: 2.8秒 → 0.0秒（短縮なし）
        let totalDuration = max(0.1, lastSample.time - 0.0)  // 元の長さのまま
        let interval = totalDuration / Double(samples.count)

        print("🎵 再生設定: \(samples.count)サンプル, 長さ\(String(format: "%.2f", totalDuration))秒, 遅延\(String(format: "%.3f", delay))秒")

        // heavy_pressureが終わるのを待つ
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }

            // 再度確認して停止
            self.lightPlayer?.stop()
            self.lightPlayer?.currentTime = 0

            // light_pressureループ開始
            self.lightPlayer?.numberOfLoops = -1  // ✅ 念のため再設定
            self.lightPlayer?.play()
            print("🌊 なぞり書きモード: light_pressureループ開始")

            // 筆圧変化を再現
            var sampleIndex = 0

            self.playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                if sampleIndex < samples.count {
                    let sample = samples[sampleIndex]
                    let adjustedForce = pow(Float(sample.force), 2.0)
                    let volume = 0.4 + adjustedForce * 0.6  // ✅ 変更（0.1 → 0.4）
                    self.lightPlayer?.volume = volume

                    sampleIndex += 1

                    print("📊 サンプル \(sampleIndex)/\(samples.count), 音量: \(Int(volume * 100))%")
                } else {
                    // ✅ 全サンプル再生完了
                    print("🛑 筆圧サンプル再生完了 (\(samples.count)サンプル) - 即座に停止")
                    timer.invalidate()
                    self.playbackTimer = nil

                    // ✅ 修正: ループを即座に解除してから停止
                    self.lightPlayer?.numberOfLoops = 0

                    // 少し待ってから停止（現在のループを終わらせる）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                        self?.lightPlayer?.stop()
                        self?.lightPlayer?.currentTime = 0
                        print("✅ なぞり書きモード: ストローク音声完全停止")
                    }
                }
            }
        }
    }
    
    func startStrokeAudioRecording(strokeNumber: Int) {
        guard !isLearningMode else { return }
        
        print("🎙️ ストローク \(strokeNumber) の筆圧データ録音開始")
        currentStrokeForces.removeAll()
        strokeRecordingStartTime = Date()
    }

    func recordForce(_ force: CGFloat) {
        guard !isLearningMode else { return }
        guard strokeRecordingStartTime != nil else { return }
        guard let startTime = strokeRecordingStartTime else { return }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        let sample = ForceSample(time: elapsedTime, force: force)
        currentStrokeForces.append(sample)
    }

    func stopStrokeAudioRecording(strokeNumber: Int) {
        guard !isLearningMode else { return }
        guard let startTime = strokeRecordingStartTime else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        let initialForce = currentStrokeForces.first?.force ?? 0.5
        
        let recording = StrokeAudioRecording(
            strokeNumber: strokeNumber,
            audioData: Data(),
            duration: duration,
            timestamp: Date(),
            sampleRate: 44100.0,
            channels: 1,
            initialForce: initialForce,
            forceSamples: currentStrokeForces
        )
        
        recordedStrokes.append(recording)
        
        print("💾 ストローク \(strokeNumber) 筆圧データ保存: \(currentStrokeForces.count)サンプル, \(String(format: "%.2f", duration))秒")
        
        currentStrokeForces.removeAll()
        strokeRecordingStartTime = nil
    }

    func getRecordedStrokeAudio() -> [StrokeAudioRecording] {
        return recordedStrokes
    }
    
    func clearRecordedAudio() {
        recordedStrokes.removeAll()
        currentStrokeForces.removeAll()
        strokeRecordingStartTime = nil
        print("🗑️ 録音データをクリアしました")
    }
}
