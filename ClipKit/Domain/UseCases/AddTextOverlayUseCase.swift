//
//  AddTextOverlayUseCase.swift
//  ClipKit
//
//  Created by 오정석 on 27/1/2026.
//

import Foundation

final class AddTextOverlayUseCase {
    private let repository: VideoProjectRepository
    
    init(repository: VideoProjectRepository) {
        self.repository = repository
    }
    
    /// 텍스트 오버레이 추가
    /// - Parameters:
    ///   - project: 편집할 프로젝트
    ///   - overlay: 추가할 텍스트 오버레이
    func execute(project: VideoProject, overlay: TextOverlay) async throws -> VideoProject {
        var updatedProject = project
        updatedProject.textOverlays.append(overlay)
        try await repository.save(updatedProject)
        return updatedProject
    }
    
    /// 텍스트 오버레이 삭제
    /// - Parameters:
    ///   - project: 편집할 프로젝트
    ///   - overlayId: 삭제할 오버레이 ID
    func remove(project: VideoProject, overlayId: UUID) async throws -> VideoProject {
        var updatedProject = project
        updatedProject.textOverlays.removeAll { $0.id == overlayId }
        try await repository.save(updatedProject)
        return updatedProject
    }
    
    /// 텍스트 오버레이 업데이트
    /// - Parameters:
    ///   - project: 편집할 프로젝트
    ///   - overlay: 업데이트할 오버레이
    func update(project: VideoProject, overlay: TextOverlay) async throws {
        var updatedProject = project
        if let index = updatedProject.textOverlays.firstIndex(where: { $0.id == overlay.id }) {
            updatedProject.textOverlays[index] = overlay
        }
        
        try await repository.save(updatedProject)
    }
}
