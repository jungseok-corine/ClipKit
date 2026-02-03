//
//  ApplyFilterUseCase.swift
//  ClipKit
//
//  Created by 오정석 on 27/1/2026.
//

import Foundation

final class ApplyFilterUseCase {
    private let repository: VideoProjectRepository
    
    init(repository: VideoProjectRepository) {
        self.repository = repository
    }
    
    /// 필터 적용
    /// - Parameters:
    ///   - project: 편집할 프로젝트
    ///   - filter: 적용할 필터 (nil이면 필터 제거)
    func execute(project: VideoProject, filter: FilterType?) async throws -> VideoProject {
        var updatedProject = project
        updatedProject.selectedFilter = filter
        try await repository.save(updatedProject)
        return updatedProject
    }
}
