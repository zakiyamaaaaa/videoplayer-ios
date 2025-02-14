//
//  ContentView.swift
//  VideoPlayerApp
//
//  Created by shoichiyamazaki on 2025/02/04.
//

import SwiftUI
import AVKit
import Photos
import PhotosUI
import WhisperKit

struct Movie: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_movie.mp4")
            
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            
            try FileManager.default.moveItem(at: received.file, to: tempURL)
            print(tempURL)
            return Self.init(url: tempURL)
        }
    }
}

struct ContentView: View {
    enum LoadState {
        case unknown, loading, loaded(Movie), failed
    }
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var movieURL: URL?
    @State private var loadState = LoadState.unknown
    @State private var videoPlayer: AVPlayer?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioURL: URL?
    @State private var whisperKit: WhisperKit?
    @State private var isProcessing = false
//    let progressView = ProgressView()
    
    @MainActor @State private var currentTime: Double = 0
    @State private var timeObserverToken: Any?

    func addTimeObserver() {
        let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = videoPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            Task { @MainActor in
                currentTime = time.seconds
            }
        }
    }

    func removeTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            videoPlayer?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    func getTranscriptionFromAudio(url: URL) async throws -> [TranscriptionResult] {
        let pipe = whisperKit
        //        let pipe =  try await WhisperKit()
        
        let transcription = try await pipe?.transcribe(audioPath: url.path, decodeOptions: DecodingOptions(language: "ja"),callback: nil)
        return transcription ?? []
        //        let audioFileSamples = try await Task {
        //            try autoreleasepool {
        //                try AudioProcessor.loadAudioAsFloatArray(fromPath: url.path())
        //            }
        //        }
        //        let transcription = try await transcri
        //        let detachedIsolationDomainTask = Task.detached(priority: .userInitiated) { @Sendable () -> [TranscriptionResult] in
        //            do {
        //                let pipe =  try await WhisperKit()
        //
        //                let transcription = try await pipe.transcribe(audioPath: url.path, decodeOptions: DecodingOptions(language: "ja"),callback: nil)
        //                return transcription
        //            } catch {
        //                print("Transcription failed: \(error.localizedDescription)")
        //                return []
        //            }
        //        }
        
        //        return await detachedIsolationDomainTask.value
    }
    
    //    func getTranscripionFromAudio(url: URL) async throws -> String? {
    //        let detachedIsolationDomainTask = Task<<#Success: Sendable#>, <#Failure: Error#>>.detaced {
    //            let pipe = try await WhisperKit()
    //            let transcription = try await pipe.transcribe(audioPath: url.path, decodeOptions: DecodingOptions.init(language: "ja"))?.text
    //            return transcription
    //        }
    //        let str = detachedIsolationDomainTask.value
    //        return str
    ////        do {
    ////            let pipe = try await WhisperKit()
    ////            let transcription = try await pipe.transcribe(audioPath: url.path, decodeOptions: DecodingOptions.init(language: "ja"))?.text
    ////            return transcription
    ////        } catch {
    ////            return nil
    ////        }
    //    }
    
    var body: some View {
        VStack {
            PhotosPicker("Select movie", selection: $selectedItem, matching: .videos)
                .task {
                    do {
                        self.whisperKit = try await WhisperKit()
                    } catch {
                        print("WhisperKit error: \(error.localizedDescription)")
                    }
                }
            switch loadState {
            case .unknown:
                EmptyView()
            case .loading:
                ProgressView()
            case .loaded:
                VStack{
                    VideoPlayer(player: videoPlayer)
                        .scaledToFit()
                        .frame(width: 300, height: 300)
                        .onAppear{
                            // ビデオの再生時間を監視
                            addTimeObserver()
                        }
                    Text("\(currentTime, specifier: "%.1f") 秒")
                }
            case .failed:
                Text("Import failed")
            }
            if videoPlayer != nil {
                HStack {
                    Button("Resume") { videoPlayer?.seek(to: .zero) }.padding()
                    Button("Play") {
                        videoPlayer?.play()
                    }
                    .padding()
                    
                    Button("Pause") {
                        videoPlayer?.pause()
                    }
                    .padding()
                }
                Button("Extract Audio") {
                    Task {
                        if let url = movieURL {
                            audioURL = await Audio.extractAudio(from: url)
                            if let audioURL {
                                do {
                                    audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
                                    print("saved auido file: URL \(url)")
                                } catch {
                                    print("error Audio extract")
                                }
                            }
                        }
                    }
                }
            }
            
            if isProcessing {
                ProgressView("Processing...")
                                 .padding()
            }
            
            if let audioPlayer, let url = audioPlayer.url {
                Text("Audio etracted: \(url.lastPathComponent)")
                    .foregroundColor(.green)
                HStack {
                    Button("Play Audio") {
                        audioPlayer.play()
                    }
                    .padding()
                    
                    Button("Pause Audio") {
                        audioPlayer.pause()
                    }
                    .padding()
                    
                    Button("Restart Audio") {
                        audioPlayer.currentTime = 0
                        audioPlayer.play()
                    }
                    .padding()
                    
                    if whisperKit != nil {
                        Button("whisper") {
                            Task {
                                isProcessing = true
                                let transcription = try await getTranscriptionFromAudio(url: url)
                                isProcessing = false
                                print(transcription)
                                
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: selectedItem) {
            Task {
                do {
                    loadState = .loading
                    
                    if let movie = try await selectedItem?.loadTransferable(type: Movie.self) {
                        loadState = .loaded(movie)
                        movieURL = movie.url
                        videoPlayer = AVPlayer(url: movie.url)
                    } else {
                        loadState = .failed
                    }
                } catch {
                    loadState = .failed
                }
            }
        }
    }
}

//struct Movie: Transferable {
//
//  let url: URL
//
//  static var transferRepresentation: some TransferRepresentation {
//    FileRepresentation(contentType: .movie) { movie in
//      SentTransferredFile(movie.url)
//    } importing: { receivedData in
//      let fileName = receivedData.file.lastPathComponent
//
//      let copy: URL =  FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
//
//      try FileManager.default.copyItem(at: receivedData.file, to: copy)
//
//      return .init(url: copy)
//    }
//  }
//}

struct VideoPlayerView: View {
    @State private var player: AVPlayer? = nil
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var photoLibraryAccessGranted = false
    
    var body: some View {
        VStack {
            if let player = player {
                VideoPlayer(player: player)
                    .frame(height: 300)
            } else {
                Text("動画を選択してください").padding()
            }
            
            PhotosPicker("動画を選択", selection: $selectedItem, matching: .videos)
                .padding()
                .onChange(of: selectedItem) {
                    loadVideo()
                }
            
            HStack {
                Button("巻き戻し") { player?.seek(to: .zero) }.padding()
                Button("再生") { player?.play() }.padding()
                Button("停止") { player?.pause() }.padding()
                
            }
            
            if !photoLibraryAccessGranted {
                Button("設定を開く") {
                    openSettings()
                }
                .padding()
            }
        }
        .onAppear {
            requestPhotoLibraryAccess { granted in
                photoLibraryAccessGranted = granted
            }
        }
    }
    
    private func loadVideo() {
        guard let item = selectedItem else { return }
        item.loadTransferable(type: Movie.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let playerItem):
                    player = AVPlayer(url: playerItem!.url)
                case .failure(let error):
                    print("Error loading video: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func requestPhotoLibraryAccess(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    completion(newStatus == .authorized)
                }
            }
        case .denied, .restricted, .limited:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

//struct ContentView: View {
//    var body: some View {
//        VideoPlayerView()
//    }
//}


#Preview {
    ContentView()
}
