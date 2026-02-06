//
//  VideoSelectionViewController.swift
//  ClipKit
//
//  Created by 오정석 on 2/2/2026.
//

import UIKit
import PhotosUI
import SnapKit

final class VideoSelectionViewController: UIViewController {
    
    // MARK: - Properties
    
    private var viewModel: VideoSelectionViewModel!
    
    // MARK: - UI Components
    
    private let selectButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("비디오 선택", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "ClipKit"
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .center
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "간편한 비디오 편집"
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupViewModel()
        setupActions()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        [titleLabel, subtitleLabel, selectButton].forEach {
            view.addSubview($0)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalTo(view.snp.centerX)
            make.centerY.equalTo(view.snp.centerY).offset(-100)
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.centerX.equalTo(view.snp.centerX)
        }
        
        selectButton.snp.makeConstraints { make in
            make.centerX.equalTo(view.snp.centerX)
            make.top.equalTo(subtitleLabel.snp.bottom).offset(60)
            make.width.equalTo(200)
            make.height.equalTo(50)
        }
    }
    
    private func setupViewModel() {
        // TODO: DI Container에서 주입받기
        viewModel = VideoSelectionViewModel()
    }
    
    private func setupActions() {
        selectButton.addTarget(self, action: #selector(selectButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    
    @objc private func selectButtonTapped() {
        presentVideoPicker()
    }
    
    // MARK: - PHPicker
    
    private func presentVideoPicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .videos
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    private func handleSelectedVideo(url: URL) {
        // VideoProject 생성
        let project = VideoProject(videoURL: url)
        
        // Repository & Service 생성 (임시 - 나중에 DI Container로 교체)
        let repository = FileManagerVideoProjectRepository()
        let service = AVFoundationVideoEditingService()
        
        // UseCase 생성
        let trimUseCase = TrimVideoUseCase(repository: repository)
        let filterUseCase = ApplyFilterUseCase(repository: repository)
        let textUseCase = AddTextOverlayUseCase(repository: repository)
        let exportUseCase = ExportVideoUseCase(
            repository: repository,
            editingService: service
        )
        
        // ViewModel 생성
        let viewModel = VideoEditorViewModel(
            project: project,
            trimVideoUseCase: trimUseCase,
            applyFilterUseCase: filterUseCase,
            addTextOverlayUseCase: textUseCase,
            exportVideoUseCase: exportUseCase
        )
        
        // VideoEditorViewController
        let editorVC = VideoEditorViewController(viewModel: viewModel)
        navigationController?.pushViewController(editorVC, animated: true)
    }
}

// MARK: - PHPickerViewControllerDelegate

extension VideoSelectionViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let result = results.first else { return }
        
        // 비디오 URL 가져오기
        result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
            guard let url = url, error == nil else {
                print("비디오 로드 실패: \(error?.localizedDescription ?? "")")
                return
            }
            
            // ✅ Documents 디렉토리 사용
            let documentsURL = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
            let videosDirectory = documentsURL.appendingPathComponent("OriginalVideos")
            
            // 디렉토리 생성
            if !FileManager.default.fileExists(atPath: videosDirectory.path) {
                try? FileManager.default.createDirectory(
                    at: videosDirectory,
                    withIntermediateDirectories: true
                )
            }
            
            // 고유 파일명으로 복사
            let fileName = "\(UUID().uuidString)_\(url.lastPathComponent)"
            let permanentURL = videosDirectory.appendingPathComponent(fileName)
            
            do {
                if FileManager.default.fileExists(atPath: permanentURL.path) {
                    try FileManager.default.removeItem(at: permanentURL)
                }
                try FileManager.default.copyItem(at: url, to: permanentURL)
                
                DispatchQueue.main.async {
                    self.handleSelectedVideo(url: permanentURL) // ← 영구 경로 사용
                }
            } catch {
                print("파일 복사 실패: \(error)")
            }
        }
    }
}
