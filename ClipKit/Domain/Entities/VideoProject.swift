//
//  VideoProject.swift
//  ClipKit
//
//  Created by 오정석 on 21/1/2026.
//

import Foundation
import AVFoundation

struct VideoProject {
    let id: UUID
    let videoURL: URL
    
    // 트림 정보
    var trimStart: Double
    var trimEnd: Double
    
    // 필터
    var selectedFilter: FilterType?
    
    // 텍스트 오버레이
    var textOverlays: [TextOverlay]
    
    // 생성 시간
    let createdAt: Date
    
    init(videoURL: URL) {
        self.id = UUID()
        self.videoURL = videoURL
        
        let asset = AVAsset(url: videoURL)
        let duration = asset.duration.seconds
        
        self.trimStart = 0
        self.trimEnd = duration
        
        self.selectedFilter = nil
        self.textOverlays = []
        self.createdAt = Date()
    }
}
