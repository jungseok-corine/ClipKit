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
        print("🎬 [Service] Export 시작")
        print("   - 필터: \(project.selectedFilter?.displayName ?? "없음")")
        print("   - 텍스트: \(project.textOverlays.count)개")
        
        
        // 1. Composition 생성 (트림 적용)
        let composition = try await createComposition(from: project)
        
        // 2. 비디오 크기 가져오기
        guard let videoTrack = try await composition.loadTracks(withMediaType: .video).first else {
            throw VideoEditingError.exportFailed
        }
        let videoSize = try await videoTrack.load(.naturalSize)
        print("   - 비디오 크기: \(videoSize)")
        
        // 3. VideoComposition 생성 (필터 + 텍스트 적용)
        let videoComposition = try await createVideoComposition(
            for: composition,
            filter: project.selectedFilter,
            textOverlays: project.textOverlays,
            videoSize: videoSize
        )
        
        if videoComposition != nil {
            print("✅ [Service] VideoComposition 생성됨")
        } else {
            print("⚠️ [Service] VideoComposition이 nil (필터/텍스트 없음)")
        }
        
        // 4. Export
        let outputURL = try await exportComposition(
            composition,
            videoComposition: videoComposition
        )
        
        print("✅ [Service] Export 완료")
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
        // 필터만 처리 (텍스트는 향후 추가 예정)
        guard let filter = filter, filter != .original else {
            return nil
        }
        
        print("🎨 [VideoComposition] 필터 적용: \(filter.displayName)")
        
        let videoComposition = AVMutableVideoComposition(
            asset: composition,
            applyingCIFiltersWithHandler: { [weak self] request in
                guard let self = self else {
                    request.finish(with: request.sourceImage, context: nil)
                    return
                }
                
                let source = request.sourceImage.clampedToExtent()
                
                guard let filteredImage = self.applyFilter(to: source, filterType: filter) else {
                    request.finish(with: source, context: nil)
                    return
                }
                
                request.finish(with: filteredImage, context: nil)
            }
        )
        
        videoComposition.renderSize = videoSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        return videoComposition
    }
    
    /// 이미지에 필터 적용
    private func applyFilter(to image: CIImage, filterType: FilterType) -> CIImage? {
        guard let filterName = filterType.filterName else {
            return image
        }
        
        switch filterType {
        case .sepia:
            guard let filter = CIFilter(name: filterName) else {
                print("⚠️ 필터 생성 실패: \(filterName)")
                return image
            }
            
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(0.8, forKey: kCIInputIntensityKey)
            return filter.outputImage ?? image
            
        case .noir:
            guard let filter = CIFilter(name: filterName) else {
                print("⚠️ 필터 생성 실패: \(filterName)")
                return image
            }
            filter.setValue(image, forKey: kCIInputImageKey)
            return filter.outputImage
            
        case .vivid:
            guard let filter = CIFilter(name: filterName) else {
                print("⚠️ 필터 생성 실패: \(filterName)")
                return image
            }
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(1.5, forKey: kCIInputSaturationKey)
            filter.setValue(0.1, forKey: kCIInputBrightnessKey)
            filter.setValue(1.2, forKey: kCIInputContrastKey)
            return filter.outputImage
            
        case .original:
            return image
        }
    }
    
//    /// Animation Tool 생성 (텍스트 오버레이)
//    private func createAnimationTool(
//        textOverlays: [TextOverlay],
//        videoSize: CGSize,
//        duration: CMTime
//    ) -> AVVideoCompositionCoreAnimationTool {
//        print("📝 [AnimationTool] 텍스트 레이어 생성 시작")
//        
//        // Video Layer (비디오가 렌더링될 레이어)
//        let videoLayer = CALayer()
//        videoLayer.frame = CGRect(origin: .zero, size: videoSize)
//        
//        // Parent Layer (전체 컴포지션)
//        let parentLayer = CALayer()
//        parentLayer.frame = CGRect(origin: .zero, size: videoSize)
//        
//        // Video Layer를 먼저 추가
//        parentLayer.addSublayer(videoLayer)
//        
//        // 텍스트 레이어들 추가
//        for overlay in textOverlays {
//            let textLayer = CATextLayer()
//            
//            // 텍스트 설정
//            let text = overlay.text as NSString
//            textLayer.string = text
//            textLayer.font = UIFont.systemFont(ofSize: overlay.fontSize, weight: .bold) as CFTypeRef
//            textLayer.fontSize = overlay.fontSize
//            textLayer.foregroundColor = overlay.color.cgColor
//            textLayer.alignmentMode = .center
//            textLayer.isWrapped = true
//            
//            // 배경
//            textLayer.backgroundColor = UIColor.black.withAlphaComponent(0.7).cgColor
//            textLayer.cornerRadius = 8
//            
//            // 크기 및 위치
//            let textWidth: CGFloat = videoSize.width * 0.8
//            let textHeight: CGFloat = 100
//            let x = (videoSize.width - textWidth) / 2
//            let y = (videoSize.height - textHeight) / 2
//            
//            textLayer.frame = CGRect(x: x, y: y, width: textWidth, height: textHeight)
//            textLayer.contentsScale = 2.0
//            
//            // 애니메이션 범위 (전체 비디오 길이)
//            textLayer.opacity = 1.0
//            
//            print("   텍스트 추가: '\(text)' at (\(x), \(y))")
//            
//            // Parent Layer에 추가
//            parentLayer.addSublayer(textLayer)
//        }
//        
//        print("✅ [AnimationTool] VideoLayer와 \(textOverlays.count)개 텍스트 레이어 생성 완료")
//        
//        // AnimationTool 생성
//        return AVVideoCompositionCoreAnimationTool(
//            postProcessingAsVideoLayer: videoLayer,
//            in: parentLayer
//        )
//    }
    
    /// Composition Export
    private func exportComposition(
        _ composition: AVMutableComposition,
        videoComposition: AVMutableVideoComposition?
    ) async throws -> URL {
        print("💾 [Export] 시작")
        
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
            print("❌ [Export] ExportSession 생성 실패")
            throw VideoEditingError.exportFailed
        }
        
        // 4. Export 설정
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // VideoComposition 적용 (필터/텍스트)
        if let videoComposition = videoComposition {
            print("   VideoComposition 적용 중...")
            exportSession.videoComposition = videoComposition
        } else {
            print("   VideoComposition 없음 (원본)")
        }
        
        // 5. Export 실행
        print("   Export 진행 중...")
        await exportSession.export()
        
        // 6. 결과 확인
        switch exportSession.status {
        case .completed:
            print("✅ [Export] 완료: \(outputURL)")
            return outputURL
        case .failed:
            let error = exportSession.error
            print("❌ [Export] 실패: \(error?.localizedDescription ?? "Unknown")")
            throw error ?? VideoEditingError.exportFailed
        case .cancelled:
            print("❌ [Export] 취소됨")
            throw VideoEditingError.exportFailed
        default:
            print("❌ [Export] 알 수 없는 상태: \(exportSession.status.rawValue)")
            throw VideoEditingError.exportFailed
        }
    }
    
//    /// 텍스트를 CIImage로 변환
//    private func createTextImage(
//        text: String,
//        fontSize: CGFloat,
//        color: UIColor,
//        videoSize: CGSize
//    ) -> CIImage? {
//        // 텍스트 속성
//        let attributes: [NSAttributedString.Key: Any] = [
//            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
//            .foregroundColor: color,
//            .backgroundColor: UIColor.black.withAlphaComponent(0.7)
//        ]
//        
//        let attributedText = NSAttributedString(string: text, attributes: attributes)
//        
//        // 텍스트 크기 계산
//        let textSize = attributedText.boundingRect(
//            with: CGSize(width: videoSize.width * 0.8, height: .greatestFiniteMagnitude),
//            options: [.usesLineFragmentOrigin, .usesFontLeading],
//            context: nil
//        ).size
//        
//        // 패딩 추가
//        let paddedSize = CGSize(
//            width: textSize.width + 40,
//            height: textSize.height + 20
//        )
//        
//        // 이미지 생성
//        UIGraphicsBeginImageContextWithOptions(paddedSize, false, 0)
//        defer { UIGraphicsEndImageContext() }
//        
//        guard let context = UIGraphicsGetCurrentContext() else { return nil }
//        
//        // 배경 그리기
//        context.setFillColor(UIColor.black.withAlphaComponent(0.7).cgColor)
//        let rect = CGRect(origin: .zero, size: paddedSize)
//        let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
//        path.fill()
//        
//        // 텍스트 그리기
//        let textRect = CGRect(
//            x: 20,
//            y: 10,
//            width: textSize.width,
//            height: textSize.height
//        )
//        attributedText.draw(in: textRect)
//        
//        guard let uiImage = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
//        guard let cgImage = uiImage.cgImage else { return nil }
//        
//        return CIImage(cgImage: cgImage)
//    }
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

