//
//  Audio.swift
//  VideoPlayerApp
//
//  Created by shoichiyamazaki on 2025/02/08.
//

import Foundation
import AVFoundation

class Audio {
    static func extractAudio(from videoURL: URL) async -> URL? {
        let asset = AVURLAsset(url: videoURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            print("エクスポートセッションの作成失敗")
            return nil
        }
        
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("extracted_audio.m4a")
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.shouldOptimizeForNetworkUse = true
        
        do {
            try await exportSession.export(to: outputURL, as: .m4a)
            print("音声の抽出成功")
            return outputURL
        } catch {
            print("音声抽出失敗：\(error.localizedDescription)")
            return nil
        }
        
//        return await withCheckedContinuation{ continuation in
//            await exportSession.export(to: outputURL, as: .m4a)

//            exportSession.exportAsynchronously {
//                switch exportSession.status {
//                case .waiting:
//                    print("処理中")
//                case .exporting:
//                    print("抽出中")
//                case .completed:
//                    print("音声の抽出成功 \(outputURL)")
//                    continuation.resume(returning: outputURL)
//                case .failed, .cancelled:
//                    print("音声の抽出失敗：\(exportSession.error?.localizedDescription)")
//                    continuation.resume(throwing: exportSession.error as! Never)
//                case default:
//                    break
//                }
//            }
//        }
        
    }
}
