//
//  VideoSelectionViewModel.swift
//  ClipKit
//
//  Created by 오정석 on 2/2/2026.
//

import Foundation


final class VideoSelectionViewModel {
    // MARK: - Properties
    
    private(set) var selectedVideoURL: URL?
    
    // MARK: - Public Methods
    
    /// 비디오 URL 설정
    func setVideoURL(_ url: URL) {
        selectedVideoURL = url
    }
    
    /// VideoProject 생성
    func createVideoProject() -> VideoProject? {
        guard let url = selectedVideoURL else {
            return nil
        }
        return VideoProject(videoURL: url)
    }
}
