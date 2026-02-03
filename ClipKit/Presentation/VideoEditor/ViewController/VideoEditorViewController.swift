//
//  VideoEditorViewController.swift
//  ClipKit
//
//  Created by 오정석 on 2/2/2026.
//

import UIKit
import AVFoundation
import SnapKit
import Combine

/// 비디오 편집 화면
final class VideoEditorViewController: UIViewController {
    // MARK: - Properties
    private var viewModel: VideoEditorViewModel!
    private var cancellables = Set<AnyCancellable>()
    
    // AVPlayer
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    
    // MARK: - UI Components
    
    private let playerContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }()
    
    private let playButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
        button.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = .black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 35
        return button
    }()
    
    private let controlStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 12
        return stack
    }()
    
    private let trimButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "scissors"), for: .normal)
        button.setTitle("트림", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14)
        button.tintColor = .label
        return button
    }()
    
    private let filterButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "camera.filters"), for: .normal)
        button.setTitle("필터", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14)
        button.tintColor = .label
        return button
    }()
    
    private let textButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "textformat"), for: .normal)
        button.setTitle("텍스트", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14)
        button.tintColor = .label
        return button
    }()
    
    private let exportButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("저장", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        return button
    }()
    
    // MARK: - Initialization
    
    init(viewModel: VideoEditorViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPlayer()
        setupActions()
        setupBindings()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = playerContainerView.bounds
    }
    
    deinit {
        player?.pause()
        player = nil
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "편집"
        
        // Player Container
        view.addSubview(playerContainerView)
        playerContainerView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.left.right.equalToSuperview()
            make.height.equalTo(UIScreen.main.bounds.height * 0.4)
        }
        
        // Play Button
        playerContainerView.addSubview(playButton)
        playButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(70)
        }
        
        // Control Buttons
        [trimButton, filterButton, textButton].forEach {
            controlStackView.addArrangedSubview($0)
            //            $0.setContentCompressionResistancePriority(.required, for: .vertical)
            configureControlButton($0)
        }
        
        view.addSubview(controlStackView)
        controlStackView.snp.makeConstraints { make in
            make.top.equalTo(playerContainerView.snp.bottom).offset(30)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(80)
        }
        
        // Export Button
        view.addSubview(exportButton)
        exportButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.height.equalTo(54)
        }
    }
    
    private func configureControlButton(_ button: UIButton) {
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 12
        button.titleLabel?.font = .systemFont(ofSize: 14)
        
        // 아이콘 크기 조정
        var config = UIButton.Configuration.plain()
        config.imagePadding = 8
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        button.configuration = config
        
        if let imageView = button.imageView, let titleLabel = button.titleLabel {
            button.contentVerticalAlignment = .center
            
            // 이미지는 위, 텍스트는 아래
            let spacing: CGFloat = 0
            button.imageEdgeInsets = UIEdgeInsets(
                top: -(titleLabel.intrinsicContentSize.height + spacing),
                left: 0,
                bottom: 0,
                right: -titleLabel.intrinsicContentSize.width
            )
        }
        
        // 이미지와 텍스트 세로 배치
        button.contentVerticalAlignment = .center
        button.contentHorizontalAlignment = .center
        button.titleEdgeInsets = UIEdgeInsets(top: 30, left: -30, bottom: 0, right: 0)
        button.imageEdgeInsets = UIEdgeInsets(top: -10, left: 0, bottom: 0, right: 0)
    }
    
    private func setupPlayer() {
        let asset = AVAsset(url: viewModel.project.videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspect
        playerLayer?.frame = playerContainerView.bounds
        
        if let playerLayer = playerLayer {
            playerContainerView.layer.addSublayer(playerLayer)
        }
        
        // 재생 완료 알림
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem)
    }
    
    private func setupActions() {
        playButton.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
        trimButton.addTarget(self, action: #selector(trimButtonTapped), for: .touchUpInside)
        filterButton.addTarget(self, action: #selector(filterButtonTapped), for: .touchUpInside)
        textButton.addTarget(self, action: #selector(textButtonTapped), for: .touchUpInside)
        exportButton.addTarget(self, action: #selector(exportButtonTapped), for: .touchUpInside)
    }
    
    private func setupBindings() {
        viewModel.$isExporting
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isExporting in
                self?.exportButton.isEnabled = !isExporting
                self?.exportButton.alpha = isExporting ? 0.5 : 1.0
            }
            .store(in: &cancellables)
    }
    
    // Actions
    
    @objc func playButtonTapped() {
        guard let player = player else { return }
        
        if player.timeControlStatus == .playing {
            player.pause()
            let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
            playButton.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
        } else {
            player.play()
            let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
            playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
    }
    
    @objc func playerDidFinishPlaying() {
        player?.seek(to: .zero)
        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
        playButton.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
    }
    
    @objc func trimButtonTapped() {
        // TODO: 트림 시트 표시
        showAlert(message: "트림 기능 (구현 예정)")
    }
    
    @objc func filterButtonTapped() {
        showFilterSheet()
    }
    
    @objc func textButtonTapped() {
        let alert = UIAlertController(
            title: "개발 예정 기능",
            message: "텍스트 오버레이 기능은 향후 버전에서 지원 예정입니다.\n\n현재는 트림 및 필터 기능을 사용해주세요!",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    @objc func exportButtonTapped() {
        Task {
            do {
                let url = try await viewModel.exportVideo()
                await MainActor.run {
                    showAlert(message: "비디오가 사진 앱에 저장되었습니다!")
                }
            } catch {
                await MainActor.run {
                    showAlert(message: "저장 실패: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Helper
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}


extension VideoEditorViewController {
    func showFilterSheet() {
        let alert = UIAlertController(
            title: "필터 선택",
            message: nil,
            preferredStyle: .actionSheet
        )
        
        // 필터 옵션들
        let filters: [(FilterType, String)] = [
            (.original, "원본"),
            (.sepia, "세피아"),
            (.noir, "흑백"),
            (.vivid, "선명")
        ]
        
        for (filterType, name) in filters {
            let action = UIAlertAction(title: name, style: .default) { [weak self] _ in
                self?.applyFilter(filterType)
            }
            
            // 현재 선택된 필터 표시
            if self.viewModel.project.selectedFilter == filterType {
                action.setValue(true, forKey: "checked")
            }
            
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func applyFilter(_ filter: FilterType) {
        Task {
            do {
                try await viewModel.applyFilter(filter)
                await MainActor.run {
                    // 프리뷰 업데이트 (선택)
                    showAlert(message: "\(filter.displayName) 필터 적용됨")
                }
            } catch {
                await MainActor.run {
                    showAlert(message: "필터 적용 실패: \(error.localizedDescription)")
                }
            }
        }
    }
    
//    func showTextInputSheet() {
//        let alert = UIAlertController(
//            title: "텍스트 추가",
//            message: nil,
//            preferredStyle: .alert
//        )
//        
//        // 텍스트 입력 필드
//        alert.addTextField { textField in
//            textField.placeholder = "텍스트를 입력하세요"
//        }
//        
//        // 색상 선택 (간단 버전)
//        let whiteAction = UIAlertAction(title: "흰색으로 추가", style: .default) { [weak self] _ in
//            if let text = alert.textFields?.first?.text, !text.isEmpty {
//                self?.addText(text, color: .white)
//            }
//        }
//        
//        let blackAction = UIAlertAction(title: "검은색으로 추가", style: .default) { [weak self] _ in
//            if let text = alert.textFields?.first?.text, !text.isEmpty {
//                self?.addText(text, color: .black)
//            }
//        }
//        
//        alert.addAction(whiteAction)
//        alert.addAction(blackAction)
//        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
//        
//        present(alert, animated: true)
//    }
//    
//    private func addText(_ text: String, color: UIColor) {
//        Task {
//            do {
//                try await viewModel.addText(text, color: color)
//                await MainActor.run {
//                    showAlert(message: "텍스트가 추가되었습니다")
//                }
//            } catch {
//                await MainActor.run {
//                    showAlert(message: "텍스트 추가 실패: \(error.localizedDescription)")
//                }
//            }
//        }
//    }
}
