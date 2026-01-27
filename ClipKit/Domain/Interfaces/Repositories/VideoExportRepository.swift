//
//  VideoExportRepository.swift
//  ClipKit
//
//  Created by 오정석 on 23/1/2026.
//

import Foundation
import AVFoundation

protocol VideoExportRepository {
    /// 비디오 편집 적용 & Export
    /// - Parameters:
    ///  - project: 편집할 프로젝트
    ///  - outputURL: 저장할 경로
    /// - Returns: Export된 비디오 URL
    func export(project: VideoProject, to outputURL: URL) async throws -> URL
    
    /// 사진 앱에 저장
    ///  - Parameter videoURL: 저장할 비디오 URL
    func saveToPhotos(videoURL: URL) async throws
}
