//
//  ExportVideoUseCase.swift
//  ClipKit
//
//  Created by 오정석 on 27/1/2026.
//

import Foundation

/// 비디오를 최종 Export하고 사진 앱에 저장하는 UseCase
final class ExportVideoUseCase {
    private let repository: VideoProjectRepository
    private let editingService: VideoEditingService
    
    init(repository: VideoProjectRepository, editingService: VideoEditingService) {
        self.repository = repository
        self.editingService = editingService
    }
    
    /// 비디오 Export 및 저장
    /// - Parameter project: Export할 프로젝트
    /// - Returns: Export된 비디오 URL
    func execute(project: VideoProject) async throws -> URL {
        // 1. Export 전에 최신 상태 저장
        try await repository.save(project)
        
        // 2. 비디오 편집 (트림 + 필터 + 텍스트)
        let exportedURL = try await editingService.export(project: project)
        
        // 3. 사진 앱에 저장
        try await editingService.saveToPhotos(videoURL: exportedURL)
        
        return exportedURL
    }
}


// MARK: - Error
enum ExportError: Error {
    case projectNotFound
    
    var localizedDescription: String {
        switch self {
        case .projectNotFound:
            return "프로젝트를 찾을 수 없습니다."
        }
    }
}
