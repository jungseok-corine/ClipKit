//
//  FileManagerVideoProjectRepository.swift
//  ClipKit
//
//  Created by 오정석 on 28/1/2026.
//

import Foundation

/// FileManager를 사용한 VideoProjectRepository 구현체
class FileManagerVideoProjectRepository: VideoProjectRepository {
    
    private let fileManager = FileManager.default
    private let directoryName = "VideoProjects"
    
    // MARK: - Directory URL
    
    // 프로젝트 저장 디렉토리 URL
    private var projectDirectoryURL: URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent(directoryName)
    }
    
    /// 프로젝트 파일 URL
    /// - Parameter id: 프로젝트 ID
    /// - Returns: 파일 URL
    private func projectFileURL(for id: UUID) -> URL {
        projectDirectoryURL.appendingPathComponent("\(id.uuidString).json")
    }
    
    // MARK: - Initialization
    
    init() {
        createDirectoryIfNeeded()
    }
    
    /// 디렉토리가 없으면 생성
    private func createDirectoryIfNeeded() {
        guard !fileManager.fileExists(atPath: projectDirectoryURL.path) else { return }
        
        try? fileManager.createDirectory(
            at: projectDirectoryURL,
            withIntermediateDirectories: true
        )
    }
    
    // MARK: - VideoProjectRepository
    
    /// 프로젝트 저장
    func save(_ project: VideoProject) async throws {
        let fileURL = projectFileURL(for: project.id)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(project)
        try data.write(to: fileURL)
    }
    
    /// 모든 프로젝트 불러오기 (최신순)
    func loadAll() async throws -> [VideoProject] {
        let fileURLs = try fileManager.contentsOfDirectory(
            at: projectDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let projects = try fileURLs.compactMap { url -> VideoProject? in
            guard url.pathExtension == "json" else { return nil }
            let data = try Data(contentsOf: url)
            return try decoder.decode(VideoProject.self, from: data)
        }
        
        // 최신순 정렬
        return  projects.sorted { $0.createdAt > $1.createdAt }
    }
    
    /// 특정 프로젝트 불러오기
    func load(id: UUID) async throws -> VideoProject? {
        let fileURL = projectFileURL(for: id)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(VideoProject.self, from: data)
    }
    
    /// 프로젝트 삭제
    func delete(id: UUID) async throws {
        let fileURL = projectFileURL(for: id)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }
        
        try fileManager.removeItem(at: fileURL)
    }
}
