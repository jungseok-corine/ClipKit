//
//  DIContainer.swift
//  ClipKit
//
//  Created by 오정석 on 4/2/2026.
//

import Foundation
import Swinject

/*
 ⚠️ 현재 미사용 - Technical Debt
 
 # 배경
 Swinject를 활용한 DI Container 구현을 시도했으나,
 AVFoundation의 CIFilter 클로저와 생명주기 충돌로 인해
 메모리 접근 오류가 발생하여 보류
 
 # 발생한 문제
 - CIFilter 클로저에서 Service 인스턴스 접근 시 EXC_BAD_ACCESS
 - Service가 싱글톤 스코프일 때도, transient일 때도 동일한 크래시
 - Export 비동기 처리 중 메모리 해제 시점 문제
 
 # 시도한 해결책
 1. [weak self] 제거 → 실패
 2. Service transient 스코프 → 실패
 3. Filter를 미리 생성 (클로저 외부) → 미시도
 
 # 향후 개선 방안
 1. CIFilter 생명주기 재설계
    - 클로저 외부에서 필터 생성
    - Service 없이 필터 적용 가능하도록
 2. Metal 기반 필터링으로 전환
 3. 실제 기기에서 메모리 프로파일링
 
 # 우선순위
 - 현재: 수동 의존성 생성으로 안정성 확보 ✅
 - Phase 2: DI Container 재시도
 
 # 작성일
 2026-02-04
 */

final class DIContainer {
    static let shared = DIContainer()
    private let container = Container()
    
    private init() {
        registerRepositories()
        registerServices()
        registerUseCases()
    }
    
    // MARK: - Registration
    
    private func registerRepositories() {
        container.register(VideoProjectRepository.self) { _ in
            FileManagerVideoProjectRepository()
        }.inObjectScope(.container)  // 싱글톤
    }
    
    private func registerServices() {
        container.register(VideoEditingService.self) { _ in
            AVFoundationVideoEditingService()
        }.inObjectScope(.container)  // ← 여기서 문제 발생
    }
    
    private func registerUseCases() {
        // TrimVideoUseCase
        container.register(TrimVideoUseCase.self) { resolver in
            TrimVideoUseCase(
                repository: resolver.resolve(VideoProjectRepository.self)!
            )
        }
        
        // ApplyFilterUseCase
        container.register(ApplyFilterUseCase.self) { resolver in
            ApplyFilterUseCase(
                repository: resolver.resolve(VideoProjectRepository.self)!
            )
        }
        
        // AddTextOverlayUseCase
        container.register(AddTextOverlayUseCase.self) { resolver in
            AddTextOverlayUseCase(
                repository: resolver.resolve(VideoProjectRepository.self)!
            )
        }
        
        // ExportVideoUseCase
        container.register(ExportVideoUseCase.self) { resolver in
            ExportVideoUseCase(
                repository: resolver.resolve(VideoProjectRepository.self)!,
                editingService: resolver.resolve(VideoEditingService.self)!
            )
        }
    }
    
    // MARK: - Resolve
    
    func makeVideoEditorViewModel(project: VideoProject) -> VideoEditorViewModel {
        VideoEditorViewModel(
            project: project,
            trimVideoUseCase: container.resolve(TrimVideoUseCase.self)!,
            applyFilterUseCase: container.resolve(ApplyFilterUseCase.self)!,
            addTextOverlayUseCase: container.resolve(AddTextOverlayUseCase.self)!,
            exportVideoUseCase: container.resolve(ExportVideoUseCase.self)!
        )
    }
}
