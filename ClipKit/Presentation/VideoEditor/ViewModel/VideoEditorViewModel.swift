//
//  VideoEditorViewModel.swift
//  ClipKit
//
//  Created by 오정석 on 2/2/2026.
//

import UIKit
import AVFoundation
import Combine

/// 비디오 편집 화면 ViewModel
final class VideoEditorViewModel {
    // MARK: - Properties
    
    private(set) var project: VideoProject
    
    // UseCases
    private let trimVideoUseCase: TrimVideoUseCase
    private let applyFilterUseCase: ApplyFilterUseCase
    private let addTextOverlayUseCase: AddTextOverlayUseCase
    private let exportVideoUseCase: ExportVideoUseCase
    
    // State
    @Published private(set) var isExporting: Bool = false
    @Published private(set) var exportProgress: Double = 0.0
    
    // MARK: - Initialiaztion
    
    init(
        project: VideoProject,
        trimVideoUseCase: TrimVideoUseCase,
        applyFilterUseCase: ApplyFilterUseCase,
        addTextOverlayUseCase: AddTextOverlayUseCase,
        exportVideoUseCase: ExportVideoUseCase
    ) {
        self.project = project
        self.trimVideoUseCase = trimVideoUseCase
        self.applyFilterUseCase = applyFilterUseCase
        self.addTextOverlayUseCase = addTextOverlayUseCase
        self.exportVideoUseCase = exportVideoUseCase
    }
    
    // MARK: - Public Methods
    
    /// 트림 적용
    func applyTrim(start: Double, end: Double) async throws {
        project = try await trimVideoUseCase.execute(project: project, start: start, end: end)
    }

    /// 필터 적용
    func applyFilter(_ filter: FilterType?) async throws {
        print("🎨 [ViewModel] 필터 적용 시작: \(filter?.displayName ?? "없음")")
        project = try await applyFilterUseCase.execute(project: project, filter: filter)
        print("✅ [ViewModel] 필터 적용 완료: \(project.selectedFilter?.displayName ?? "없음")")
    }

//    /// 텍스트 추가
//    func addText(_ text: String, color: UIColor) async throws {
//        print("📝 [ViewModel] 텍스트 추가 시작: \(text)")
//        let overlay = TextOverlay(text: text, color: color)
//        project = try await addTextOverlayUseCase.execute(project: project, overlay: overlay)
//        print("✅ [ViewModel] 텍스트 추가 완료. 총 개수: \(project.textOverlays.count)")
//    }
//
//    /// 텍스트 삭제
//    func removeText(at index: Int) async throws {
//        let overlay = project.textOverlays[index]
//        project = try await addTextOverlayUseCase.remove(project: project, overlayId: overlay.id)
//    }
    
    /// Export
    func exportVideo() async throws -> URL {
        isExporting = true
        defer { isExporting = false }
        
        print("🎬 [ViewModel] Export 시작")
        print("   - 필터: \(project.selectedFilter?.displayName ?? "없음")")
        print("   - 텍스트: \(project.textOverlays.count)개")
        print("   - 트림: \(project.trimStart)초 ~ \(project.trimEnd)초")
        print("   - VideoURL: \(project.videoURL)")
        
        let result = try await exportVideoUseCase.execute(project: project)
        
        print("✅ [ViewModel] Export 완료: \(result)")
        return result
    }
    
    /// 비디오 길이
    var videoDuration: Double {
        return project.trimEnd
    }
}
