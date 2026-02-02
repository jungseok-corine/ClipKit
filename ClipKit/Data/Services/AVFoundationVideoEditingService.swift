//
//  AVFoundationVideoEditingService.swift
//  ClipKit
//
//  Created by 오정석 on 29/1/2026.
//

import UIKit
import AVFoundation
import Photos
import CoreImage


final class AVFoundationVideoEditingService: VideoEditingService {
    
    // MARK: - VideoEditingService
    
    /// 비디오 Export (트림 + 필터 + 텍스트)
    func export(project: VideoProject) async throws -> URL {
        // 1. Composition 생성 (트림 적용)
        let composition = try await createComposition(from: project)
        
        // 2. 비디오 크기 가져오기
        guard let videoTrack = try await composition.loadTracks(withMediaType: .video).first else {
            throw VideoEditingError.exportFailed
        }
        let videoSize = try await videoTrack.load(.naturalSize)
        
        // 3. VideoComposition 생성 (필터 + 텍스트 적용)
        let videoComposition = try await createVideoComposition(
            for: composition,
            filter: project.selectedFilter,
            textOverlays: project.textOverlays,
            videoSize: videoSize
        )
        
        // 4. Export
        let outputURL = try await exportComposition(
            composition,
            videoComposition: videoComposition
        )
        
        return outputURL
    }
    
    /// 사진 앱에 저장
    func saveToPhotos(videoURL: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: VideoEditingError.saveToPhotosFailed)
                }
            }
            
        }
    }
    
    // MARK: - Private Methods
    
    /// Composition 생성 (트림 적용)
    private func createComposition(from project: VideoProject) async throws -> AVMutableComposition {
        let asset = AVAsset(url: project.videoURL)
        let composition = AVMutableComposition()
        
        // 비디오 트랙 추가
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoEditingError.exportFailed
        }
        
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoEditingError.exportFailed
        }
        
        // 오디오 트랙 추가 (있으면)
        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
            if let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) {
                let audioTimeRange = CMTimeRange(
                    start: CMTime(seconds: project.trimStart, preferredTimescale: 600),
                    duration: CMTime(seconds: project.trimEnd - project.trimStart, preferredTimescale: 600)
                )
                
                try compositionAudioTrack.insertTimeRange(
                    audioTimeRange,
                    of: audioTrack,
                    at: .zero
                )
            }
        }
        
        // 트림 시간 범위 설정
        let startTime = CMTime(seconds: project.trimStart, preferredTimescale: 600)
        let duration = CMTime(seconds: project.trimEnd - project.trimStart, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: startTime, duration: duration)
        
        try compositionVideoTrack.insertTimeRange(
            timeRange,
            of: videoTrack,
            at: .zero
        )
        
        // 원본 트랙의 transform 유지 (회전 정보)
        let transform = try await videoTrack.load(.preferredTransform)
        compositionVideoTrack.preferredTransform = transform
        
        return composition
    }
    
    /// VideoComposition 생성 (필터 적용)
    private func createVideoComposition(
        for composition: AVMutableComposition,
        filter: FilterType?,
        textOverlays: [TextOverlay],
        videoSize: CGSize
    ) async throws -> AVMutableVideoComposition? {
        // 비디오 트랙 가져오기
        guard let videoTrack = try await composition.loadTracks(withMediaType: .video).first else {
            throw VideoEditingError.filterFailed
        }
        
        let trackTransform = try await videoTrack.load(.preferredTransform)
        
        // 필터가 있을 때만 VideoComposition 생성
        if let filter = filter, filter != .original {
            // 필터 적용
            let videoComposition = AVMutableVideoComposition(
                asset: composition) { request in
                    let source = request.sourceImage.clampedToExtent()
                    
                    guard let filteredImage = self.applyFilter(to: source, filterType: filter) else {
                        request.finish(with: source, context: nil)
                        return
                    }
                    
                    request.finish(with: filteredImage, context: nil)
                }
            
            
            videoComposition.renderSize = videoSize
            videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            layerInstruction.setTransform(trackTransform, at: .zero)
            
            instruction.layerInstructions = [layerInstruction]
            videoComposition.instructions = [instruction]
            
            // 텍스트 오버레이 추가
            if !textOverlays.isEmpty {
                let animationTool = createAnimationTool(
                    textOverlays: textOverlays,
                    videoSize: videoSize,
                    duration: composition.duration
                )
                videoComposition.animationTool = animationTool
            }
            
            return videoComposition
            
        } else if !textOverlays.isEmpty {
            // 필터 없고 텍스트만 있을 때
            let videoComposition = AVMutableVideoComposition(
                asset: composition,
                applyingCIFiltersWithHandler: { request in
                    request.finish(with: request.sourceImage, context: nil)
                }
            )
            videoComposition.renderSize = videoSize
            videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            layerInstruction.setTransform(trackTransform, at: .zero)
            
            instruction.layerInstructions = [layerInstruction]
            videoComposition.instructions = [instruction]
            
            let animationTool = createAnimationTool(
                textOverlays: textOverlays,
                videoSize: videoSize,
                duration: composition.duration
            )
            videoComposition.animationTool = animationTool
            
            return videoComposition
        }
        
        // 필터도 텍스트도 없으면 nil
        return nil
    }
    
    /// 이미지에 필터 적용
    private func applyFilter(to image: CIImage, filterType: FilterType) -> CIImage? {
        guard let filterName = filterType.filterName else {
            return image
        }
        
        switch filterType {
        case .sepia:
            guard let filter = CIFilter(name: filterName) else { return image }
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(0.8, forKey: kCIInputIntensityKey)
            return filter.outputImage
            
        case .noir:
            guard let filter = CIFilter(name: filterName) else { return image }
            filter.setValue(image, forKey: kCIInputImageKey)
            return filter.outputImage
            
        case .vivid:
            guard let filter = CIFilter(name: filterName) else { return image }
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(1.5, forKey: kCIInputSaturationKey)
            filter.setValue(0.1, forKey: kCIInputBrightnessKey)
            filter.setValue(1.2, forKey: kCIInputContrastKey)
            return filter.outputImage
            
        case .original:
            return image
        }
    }
    
    /// Animation Tool 생성 (텍스트 오버레이)
    private func createAnimationTool(
        textOverlays: [TextOverlay],
        videoSize: CGSize,
        duration: CMTime
    ) -> AVVideoCompositionCoreAnimationTool {
        // Parent Layer (비디오 크기)
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: videoSize)
        
        // Video Layer
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: videoSize)
        parentLayer.addSublayer(videoLayer)
        
        // 각 텍스트 오버레이마다 CATextLayer 생성
        for overlay in textOverlays {
            let textLayer = CATextLayer()
            
            // 텍스트 설정
            textLayer.string = overlay.text
            textLayer.fontSize = overlay.fontSize
            textLayer.foregroundColor = overlay.color.cgColor
            textLayer.alignmentMode = .center
            textLayer.isWrapped = true
            
            // 위치 계산 (0.0~1.0 → 실제 픽셀)
            let xPosition = overlay.position.x * videoSize.width
            let yPosition = (1.0 - overlay.position.y) * videoSize.height  // Y축 반전
            
            // 텍스트 크기 추정
            let textWidth = videoSize.width * 0.8  // 화면의 80%
            let textHeight = overlay.fontSize * 1.5
            
            textLayer.frame = CGRect(
                x: xPosition - textWidth / 2,
                y: yPosition - textHeight / 2,
                width: textWidth,
                height: textHeight
            )
            
            // 배경 투명
            textLayer.backgroundColor = UIColor.clear.cgColor
            
            parentLayer.addSublayer(textLayer)
        }
        
        return AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )
    }
    
    /// Composition Export
    private func exportComposition(
        _ composition: AVMutableComposition,
        videoComposition: AVMutableVideoComposition?
    ) async throws -> URL {
        // 1. 출력 URL 생성
        let outputURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("export_\(UUID().uuidString).mp4")
        
        // 2. 기존 파일 있으면 삭제
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        // 3. Export Session 생성
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoEditingError.exportFailed
        }
        
        // 4. Export 설정
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.videoComposition = videoComposition // ← 핵심!
        
        // 5. Export 실행
        await exportSession.export()
        
        // 6. 결과 확인
        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            throw exportSession.error ?? VideoEditingError.exportFailed
        case .cancelled:
            throw VideoEditingError.exportFailed
        default:
            throw VideoEditingError.exportFailed
        }
        
    }
}

// MARK: - Error
enum VideoEditingError: Error {
    case exportFailed
    case filterFailed
    case textOverlayFailed
    case saveToPhotosFailed
    
    var localizedDescription: String {
        switch self {
        case .exportFailed:
            return "비디오 Export에 실패했습니다."
        case .filterFailed:
            return "필터 적용에 실패했습니다."
        case .textOverlayFailed:
            return "텍스트 추가에 실패했습니다."
        case .saveToPhotosFailed:
            return "사진 앱 저장에 실패했습니다."
        }
    }
}

