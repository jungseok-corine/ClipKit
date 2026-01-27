//
//  VideoProjectRepository.swift
//  ClipKit
//
//  Created by 오정석 on 22/1/2026.
//

import Foundation

protocol VideoProjectRepository {
    /// 프로젝트 저장
    func save(_ project: VideoProject) async throws
    
    /// 모든 프로젝트 불러오기 (최신순)
    func loadAll() async throws -> [VideoProject]
    
    /// 특정 프로젝트 불러오기
    func load(id: UUID) async throws -> VideoProject?
    
    /// 프로젝트 삭제
    func delete(id: UUID) async throws
}
