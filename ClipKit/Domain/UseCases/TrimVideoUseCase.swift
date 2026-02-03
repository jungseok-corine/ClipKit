//
//  TrimVideoUseCase.swift
//  ClipKit
//
//  Created by 오정석 on 21/1/2026.
//

import Foundation


final class TrimVideoUseCase {
    private let repository: VideoProjectRepository
    
    init(repository: VideoProjectRepository) {
        self.repository = repository
    }
    
    /// 트림 정보 업데이트
        /// - Parameters:
        ///   - project: 편집할 프로젝트
        ///   - start: 시작 시간 (초)
        ///   - end: 종료 시간 (초)
    func execute(project: VideoProject, start: Double, end: Double) async throws -> VideoProject {
        var updatedProject = project
        updatedProject.trimStart = start
        updatedProject.trimEnd = end
        try await repository.save(updatedProject)
        return updatedProject
    }
}
