import SwiftUI

struct ErrorBanner: View {
    let message: String
    @Binding var isVisible: Bool
    
    var body: some View {
        VStack {
            if isVisible {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.white)
                    Text(message)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { isVisible = false }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.9))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: isVisible)
    }
}

struct ContentView: View {
    @StateObject private var player = AudioPlayerManager()
    @State private var showError = false
    @State private var selectedTab = 0 // 0 for player, 1 for chat, 2 for news

    
    var body: some View {
        VStack(spacing: 20) {
            // Stream selector at the top
            Picker("Stream Source", selection: $player.currentStream) {
                ForEach(StreamType.allCases, id: \.self) { streamType in
                    Text(streamType.title).tag(streamType)
                }
            }
            .pickerStyle(.segmented)
            .padding(.top, 24)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .onChange(of: player.currentStream) { oldValue, newValue in
                // When stream selection changes, call switchStream
                // This will handle playback correctly
                player.switchStream(newValue)
            }
            
            // Content based on selected tab
            if selectedTab == 0 {
                playerView
            } else if selectedTab == 1 {
                chatView
            } else {
                newsView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            UIApplication.shared.beginReceivingRemoteControlEvents()
        }

    }
    
    // Player view
    private var playerView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                // Display "Radio" when nothing is playing, or the title of the stream that's actually playing
                Text(player.isPlaying ? player.playingStream.title : "Radio")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                
                // Отображение информации о треке
                if player.isPlaying {
                    VStack(spacing: 5) {
                        if !player.currentTrackInfo.title.isEmpty {
                            Text(player.currentTrackInfo.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.horizontal)
                        }
                        
                        if !player.currentTrackInfo.artist.isEmpty {
                            Text(player.currentTrackInfo.artist)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.horizontal)
                        } else if player.currentTrackInfo.title.isEmpty {
                            Text("Now Playing")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .animation(.easeInOut, value: player.currentTrackInfo)
                }
            }
            
            Spacer(minLength: 30)
            
            // Показ ошибки, если есть
            if let error = player.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }
            
            // Кнопка Play/Stop в фиксированной позиции
            Button(action: {
                if player.isPlaying {
                    HapticManager.shared.stopFeedback()
                    player.stop()
                } else {
                    HapticManager.shared.playFeedback()
                    player.play()
                }
            }) {
                Image(systemName: player.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .disabled(player.isLoading)
            .overlay {
                if player.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            
            // Фиксированная высота для нижней панели с кнопками
            VStack {
                // Панель управления внизу - show buttons when Radio-T is selected
                if player.currentStream == .radioT {
                    HStack(spacing: 40) {
                        Button(action: { 
                            // Haptic feedback для кнопки новостей
                            HapticManager.shared.lightImpact()
                            // Open News in browser
                            if let url = URL(string: "https://news.radio-t.com") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            VStack(spacing: 5) {
                                Image(systemName: "globe")
                                    .font(.title2)
                                Text("Новости")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                        }
                        
                        Button(action: { 
                            // Haptic feedback для кнопки чата
                            HapticManager.shared.lightImpact()
                            // Open Chat in browser
                            if let url = URL(string: "https://t.me/radio_t_chat") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            VStack(spacing: 5) {
                                Image(systemName: "message.fill")
                                    .font(.title2)
                                Text("Чат")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                } else {
                    // Пустое пространство, но визуально соответствует высоте кнопок
                    Color.clear
                }
            }
            .frame(height: 60) // Фиксированная высота, соответствующая высоте кнопок
            .padding(.top, 30)
            .padding(.bottom, 20)
        }
    }
    

    
    // Chat view
    private var chatView: some View {
        VStack {
            Text("Чат")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            Text("Функционал чата будет реализован здесь")
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Вернуться к плееру") {
                selectedTab = 0
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
    
    // News view
    private var newsView: some View {
        VStack {
            Text("Новости")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            Text("Новости будут отображаться здесь")
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Вернуться к плееру") {
                selectedTab = 0
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

// MARK: - Subviews
extension ContentView {
    private struct ErrorView: View {
        let error: String
        
        var body: some View {
            VStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
                Text(error)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
    
    private struct PlayButton: View {
        let isPlaying: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    ContentView()
}
