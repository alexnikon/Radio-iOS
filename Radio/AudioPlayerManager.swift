import AVFoundation
import Combine
import MediaPlayer

// Определяем имя для уведомления об обновлении Now Playing
extension Notification.Name {
    static let updateNowPlaying = Notification.Name("com.radio.updateNowPlaying")
}

enum StreamType: Int, CaseIterable {
    case wkncHD1
    case wkncHD2
    case radioT
    
    var url: URL {
        switch self {
        case .wkncHD1:
            return URL(string: "https://das-edge14-live365-dal02.cdnstream.com/a45877")!
        case .wkncHD2:
            return URL(string: "https://das-edge12-live365-dal02.cdnstream.com/a30009")!
        case .radioT:
            return URL(string: "https://stream.radio-t.com")!
        }
    }
    
    var title: String {
        switch self {
        case .wkncHD1: return "WKNC HD1"
        case .wkncHD2: return "WKNC HD2"
        case .radioT: return "Radio-T"
        }
    }
}

struct TrackInfo: Equatable {
    var title: String = ""
    var artist: String = ""
    var albumArt: Data? = nil
    
    static func == (lhs: TrackInfo, rhs: TrackInfo) -> Bool {
        return lhs.title == rhs.title && lhs.artist == rhs.artist
    }
}

class AudioPlayerManager: NSObject, ObservableObject, AVPlayerItemMetadataOutputPushDelegate {
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentStream: StreamType = .wkncHD2 // For UI selection
    @Published var playingStream: StreamType = .wkncHD2 // Currently playing stream
    @Published var currentTrackInfo: TrackInfo = TrackInfo()
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var metadataOutput: AVPlayerItemMetadataOutput?
    
    override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommands()
        setupInterruptionsHandler()
        
        // Добавляем наблюдателя за уведомлением
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUpdateNowPlaying),
            name: .updateNowPlaying,
            object: nil
        )
    }
    
    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    func switchStream(_ streamType: StreamType) {
        // Only switch if it's a different stream
        if currentStream == streamType {
            return
        }
        
        // Update the current stream selection
        currentStream = streamType
        
        // If player exists and is playing, restart with new stream
        if isPlaying {
            // Need to reset player to use new stream
            player?.pause()
            player = nil
            
            // Update the playing stream to match the selected stream
            playingStream = streamType
            
            // Clear track info when switching streams
            currentTrackInfo = TrackInfo()
            
            // Setup new player with current stream and start playing
            setupPlayer()
        }
        
        // If not playing, just update the stream selection
        // When user presses play, it will use the selected stream
    }
    
    func playPause() {
        if player == nil {
            setupPlayer()
            return
        }
        isPlaying ? pause() : play()
    }
    
    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        
        // Очищаем информацию Now Playing
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        
        // Очищаем информацию о треке
        currentTrackInfo = TrackInfo()
    }
    
    func play() {
        if player == nil {
            // Update playing stream to match the selected stream when starting playback
            playingStream = currentStream
            setupPlayer()
            return
        }
        
        do {
            // Активируем аудио сессию
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player?.play()
            isPlaying = true
            
            // Special handling for Radio-T metadata
            if currentStream == .radioT {
                fetchRadioTMetadata()
            }
            
            // Обновляем информацию Now Playing и активируем управление воспроизведением
            setupNowPlaying()
            UIApplication.shared.beginReceivingRemoteControlEvents()
        } catch {
            print("Failed to activate audio session:", error)
            errorMessage = "Failed to activate audio session"
        }
    }
    
    private func setupPlayer() {
        isLoading = true
        errorMessage = nil
        
        let asset = AVURLAsset(url: currentStream.url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": ["User-Agent": "Radio/1.0 (iOS)"]
        ])
        
        Task { @MainActor in
            do {
                let (isPlayable, _) = try await asset.load(.isPlayable, .duration)
                
                guard isPlayable else {
                    throw NSError(domain: "Audio", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "Stream unavailable"])
                }
                
                let playerItem = AVPlayerItem(asset: asset)
                
                // Setup metadata output
                let metadataOutput = AVPlayerItemMetadataOutput(identifiers: nil)
                metadataOutput.setDelegate(self, queue: DispatchQueue.main)
                playerItem.add(metadataOutput)
                self.metadataOutput = metadataOutput
                
                player = AVPlayer(playerItem: playerItem)
                
                // Используем уведомление вместо прямого вызова метода
                timeObserver = player?.addPeriodicTimeObserver(
                    forInterval: CMTime(seconds: 1, preferredTimescale: 1),
                    queue: .main
                ) { _ in
                    NotificationCenter.default.post(name: .updateNowPlaying, object: nil)
                }
                
                player?.currentItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.new], context: nil)
                
                isLoading = false
                play()
                
            } catch {
                handleError(error)
                isLoading = false
            }
        }
    }
    
    // Обработчик уведомления
    @objc private func handleUpdateNowPlaying() {
        setupNowPlaying()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayerItem.status) {
            if let statusNumber = change?[.newKey] as? NSNumber,
               let status = AVPlayerItem.Status(rawValue: statusNumber.intValue) {
                switch status {
                case .readyToPlay:
                    // Когда плеер готов к воспроизведению, обновляем информацию и включаем команды
                    DispatchQueue.main.async { [weak self] in
                        self?.setupNowPlaying()
                        UIApplication.shared.beginReceivingRemoteControlEvents()
                    }
                case .failed:
                    errorMessage = "Failed to load stream"
                default:
                    break
                }
            }
        }
    }
    
    private func pause() {
        player?.pause()
        isPlaying = false
        setupNowPlaying()
    }
    
    private func setupAudioSession() {
        do {
            // Настраиваем аудио сессию для фонового воспроизведения
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                policy: .longFormAudio
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error.localizedDescription)")
        }
    }
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.stopCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }
        
        commandCenter.stopCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            if self?.isPlaying == true {
                self?.stop()
            } else {
                self?.play()
            }
            return .success
        }
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.stopCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false
        commandCenter.seekForwardCommand.isEnabled = false
        commandCenter.seekBackwardCommand.isEnabled = false
    }
    
    private func setupInterruptionsHandler() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        switch type {
        case .began:
            pause()
        case .ended:
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    play()
                }
            }
        default: break
        }
    }
    
    private func setupNowPlaying() {
        // Если не играем, очищаем информацию
        guard isPlaying else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo = [String: Any]()
        
        // Добавляем обложку
        if let image = UIImage(named: "AppIcon") {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in return image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        // Используем информацию о треке, если она есть
        let title = currentTrackInfo.title.isEmpty ? currentStream.title : currentTrackInfo.title
        let artist = currentTrackInfo.artist.isEmpty ? "Radio" : currentTrackInfo.artist
        
        // Добавляем основные метаданные
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        
        // Добавляем информацию о потоковом воспроизведении
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        
        // Добавляем тип медиа
        nowPlayingInfo[MPMediaItemPropertyMediaType] = MPMediaType.anyAudio.rawValue
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        
        // Устанавливаем информацию
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        print("Now playing info updated: \(String(describing: MPNowPlayingInfoCenter.default().nowPlayingInfo))")
    }
    
    @MainActor
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        print("Player error: \(error)")
    }
    
    // Implement AVPlayerItemMetadataOutputPushDelegate method
    func metadataOutput(_ output: AVPlayerItemMetadataOutput, 
                      didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup], 
                      from track: AVPlayerItemTrack?) {
        // Basic metadata processing
        guard let group = groups.first, let metadata = group.items.first else { return }

        Task { [weak self] in
            guard let self = self else { return }
            if let title = try? await metadata.load(.stringValue) {
                // Parse "Artist - Title" format
                let components = title.components(separatedBy: " - ")
                let artist = components.count > 1 ? components[0].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                let trackTitle = components.count > 1 ? components[1].trimmingCharacters(in: .whitespacesAndNewlines) : title.trimmingCharacters(in: .whitespacesAndNewlines)

                await MainActor.run {
                    self.currentTrackInfo = TrackInfo(title: trackTitle, artist: artist)
                    self.setupNowPlaying()
                }
            }
        }
    }
    
    // Add a method to fetch Radio-T metadata specifically
    private func fetchRadioTMetadata() {
        guard let url = URL(string: "https://radio-t.com/site-api/last/5") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let latestEpisode = json.first,
                   let title = latestEpisode["title"] as? String {
                    
                    DispatchQueue.main.async {
                        var trackInfo = TrackInfo()
                        trackInfo.title = "Radio"
                        trackInfo.artist = title
                        self.currentTrackInfo = trackInfo
                        
                        // Update Now Playing info
                        self.setupNowPlaying()
                    }
                }
            } catch {
                print("Radio-T metadata parse error: \(error)")
            }
        }.resume()
    }
}
