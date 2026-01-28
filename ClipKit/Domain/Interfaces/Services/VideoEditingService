//
//  VideoEditingService.swift
//  ClipKit
//
//  Created by 오정석 on 21/1/2026.
//

import Foundation


protocol VideoEditingService {
    /// 비디오 편집 적용 & Export
    /// - Parameters:
    ///  - project: 편집할 프로젝트
    ///  - outputURL: 저장할 경로
    /// - Returns: Export된 비디오 URL
    /// Export 시점에 모든 편집 한번에 적용
    func export(project: VideoProject) async throws -> URL  // ← project 파라미터 필요

    /// 사진 앱에 저장
    ///  - Parameter videoURL: 저장할 비디오 URL
    func saveToPhotos(videoURL: URL) async throws
}
