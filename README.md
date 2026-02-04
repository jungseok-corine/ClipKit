# ClipKit

> Clean Architecture 기반 비디오 편집 iOS 앱

ClipKit은 Clean Architecture와 SOLID 원칙을 적용한 비디오 편집 애플리케이션입니다. 비디오 선택, 필터 적용, Export 등 핵심 기능을 제공하며, Protocol 기반의 확장 가능한 구조로 설계되었습니다.

<br>

## 📱 주요 기능

### ✅ 구현 완료
- **비디오 선택**: PHPicker를 통한 라이브러리 접근
- **비디오 재생**: AVPlayer 기반 재생 컨트롤
- **필터 적용**: CIFilter를 활용한 4가지 필터
  - 원본 (Original)
  - 세피아 (Sepia)
  - 흑백 (Noir)
  - 선명 (Vivid)
- **Export**: 편집된 비디오를 사진 앱에 저장

### 🚧 향후 구현 예정
- 트림 슬라이더 UI (비디오 구간 선택)
- 텍스트 오버레이 (CATextLayer)
- 필터 실시간 프리뷰
- 더 많은 필터 옵션

<br>

## 🛠 기술 스택

### Architecture & Design Pattern
- **Clean Architecture** (Domain - Data - Presentation 3계층)
- **MVVM Pattern** (ViewModel + Combine)
- **Repository Pattern** (데이터 추상화)
- **Dependency Inversion Principle** (Protocol 기반 의존성)

### iOS Frameworks
- **UIKit** (UI 구성)
- **AVFoundation** (비디오 처리)
  - AVPlayer, AVMutableComposition
  - AVAssetExportSession
  - CIFilter (이미지 필터)
- **Combine** (반응형 프로그래밍)
- **PhotosUI** (PHPicker)

### Third-party
- **SnapKit** (Auto Layout DSL)
- **Swinject** (DI Container - 준비됨)

### Language & Concurrency
- **Swift 5.9+**
- **async/await** (비동기 처리)

<br>

## 🏗 아키텍처

### Clean Architecture 3계층 구조
```
┌─────────────────────────────────────────┐
│         Presentation Layer              │
│  ┌─────────────────────────────────┐    │
│  │  ViewController - ViewModel     │    │
│  │  (MVVM + Combine)               │    │
│  └─────────────────────────────────┘    │
└──────────────┬──────────────────────────┘
               │ Protocol
┌──────────────▼──────────────────────────┐
│           Domain Layer                  │
│  ┌─────────────────────────────────┐    │
│  │  Entities (VideoProject, etc)   │    │
│  │  UseCases (Business Logic)      │    │
│  │  Interfaces (Protocols)         │    │
│  └─────────────────────────────────┘    │
└──────────────┬──────────────────────────┘
               │ Protocol Implementation
┌──────────────▼──────────────────────────┐
│            Data Layer                   │
│  ┌─────────────────────────────────┐    │
│  │  Repositories (FileManager)     │    │
│  │  Services (AVFoundation)        │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

### 핵심 설계 원칙

**1. Dependency Inversion Principle**
```swift
// Domain Layer (고수준)
protocol VideoEditingService {
    func export(project: VideoProject) async throws -> URL
}

// Data Layer (저수준)
final class AVFoundationVideoEditingService: VideoEditingService {
    // 구현...
}
```

**2. Repository Pattern**
```swift
// Interface (Domain)
protocol VideoProjectRepository {
    func save(_ project: VideoProject) async throws
    func load(id: UUID) async throws -> VideoProject?
}

// Implementation (Data)
final class FileManagerVideoProjectRepository: VideoProjectRepository {
    // JSON 기반 영속성
}
```

**3. YAGNI (You Aren't Gonna Need It)**
- UseCase는 concrete class (Protocol 불필요)
- 필요한 추상화만 적용

<br>

## 📁 프로젝트 구조
```
ClipKit/
├── Application/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   └── Info.plist
│
├── Domain/                           # 비즈니스 로직
│   ├── Entities/
│   │   ├── FilterType.swift         # 필터 타입 enum
│   │   ├── TextOverlay.swift        # 텍스트 오버레이 (Entity만 구현)
│   │   └── VideoProject.swift       # 비디오 프로젝트
│   ├── Interfaces/
│   │   ├── Repositories/
│   │   │   └── VideoProjectRepository.swift
│   │   └── Services/
│   │       └── VideoEditingService.swift
│   └── UseCases/
│       ├── TrimVideoUseCase.swift
│       ├── ApplyFilterUseCase.swift
│       ├── AddTextOverlayUseCase.swift    # UseCase만 구현
│       └── ExportVideoUseCase.swift
│
├── Data/                             # 데이터 처리
│   ├── Repositories/
│   │   └── FileManagerVideoProjectRepository.swift
│   └── Services/
│       └── AVFoundationVideoEditingService.swift
│
├── Presentation/                     # UI
│   ├── VideoSelection/
│   │   ├── ViewController/
│   │   │   └── VideoSelectionViewController.swift
│   │   └── ViewModel/
│   │       └── VideoSelectionViewModel.swift
│   └── VideoEditor/
│       ├── ViewController/
│       │   └── VideoEditorViewController.swift
│       └── ViewModel/
│           └── VideoEditorViewModel.swift
│
└── Core/
    ├── DI/
    │   └── DIContainer.swift         # DI Container (준비됨, 미사용)
    └── Extensions/
        └── UIColor+Hex.swift         # Codable 지원
```

<br>

## 💡 주요 구현 내용

### 1. 비디오 트림 (AVMutableComposition)
```swift
let composition = AVMutableComposition()
let timeRange = CMTimeRange(
    start: CMTime(seconds: project.trimStart, preferredTimescale: 600),
    duration: CMTime(seconds: project.trimEnd - project.trimStart, preferredTimescale: 600)
)
try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
```

### 2. 필터 적용 (CIFilter)
```swift
let videoComposition = AVMutableVideoComposition(
    asset: composition,
    applyingCIFiltersWithHandler: { [weak self] request in
        let source = request.sourceImage.clampedToExtent()
        guard let filteredImage = self?.applyFilter(to: source, filterType: filter) else {
            request.finish(with: source, context: nil)
            return
        }
        request.finish(with: filteredImage, context: nil)
    }
)
```

### 3. JSON 기반 영속성
```swift
struct VideoProject: Codable {
    let id: UUID
    var videoURL: URL
    var trimStart: Double
    var trimEnd: Double
    var selectedFilter: FilterType?
    var textOverlays: [TextOverlay]
}

// FileManager + JSONEncoder/Decoder 사용
```

### 4. async/await 비동기 처리
```swift
func exportVideo() async throws -> URL {
    isExporting = true
    defer { isExporting = false }
    return try await exportVideoUseCase.execute(project: project)
}
```

<br>

## 🔄 개선 사항 (WAY → ClipKit)

이전 프로젝트(WAY)에서 받은 피드백을 반영하여 개선했습니다.

| 피드백 | 문제점 | ClipKit 개선 |
|--------|--------|--------------|
| **DI Container 부재** | 의존성 관리 어려움 | Protocol 기반 설계 + DI 준비 |
| **싱글톤 과다 사용** | 테스트 어려움, 결합도 증가 | Repository Pattern |
| **클로저 기반 콜백** | 콜백 지옥, 에러 처리 복잡 | async/await 전면 적용 |
| **ViewController 비대화** | 책임 과다, 테스트 어려움 | MVVM + UseCase 분리 |

### Before (WAY)
```swift
// 싱글톤
LocationManager.shared.startTracking { result in
    switch result {
    case .success(let location):
        // 처리
    case .failure(let error):
        // 에러 처리
    }
}
```

### After (ClipKit)
```swift
// Protocol + async/await
protocol VideoEditingService {
    func export(project: VideoProject) async throws -> URL
}

let url = try await editingService.export(project: project)
```

<br>

## 🧪 기술적 도전과 학습

### 💪 성공한 것
- ✅ Clean Architecture 완벽 구현
- ✅ Repository Pattern 적용
- ✅ MVVM + Combine 활용
- ✅ async/await 비동기 처리
- ✅ Protocol 기반 확장 가능 설계
- ✅ CIFilter를 활용한 4가지 필터 구현

### 🚧 도전했으나 보류한 것

#### DI Container (Swinject)

**배경:**
- 의존성 주입 자동화로 테스트 용이성 향상
- Protocol 기반 설계를 DI로 확장

**구현:**
- `DIContainer.swift` 작성 완료
- Repository, Service, UseCase 등록
- ViewModel Factory 메서드 구현

**발생한 문제:**
```
Thread 68: EXC_BAD_ACCESS (code=1, address=0x...)
```
- CIFilter 클로저에서 Service 접근 시 메모리 오류
- AVFoundation의 비동기 Export 중 Service 생명주기 충돌
- 싱글톤/transient 스코프 모두 동일한 크래시

**시도한 해결책:**
1. `[weak self]` 캡처 제거 → 실패
2. Service를 transient 스코프로 변경 → 실패
3. 클로저 외부에서 필터 미리 생성 → 시도 전 시간 고려하여 보류

**결정:**
- **안정성 우선**: 수동 의존성 생성으로 유지
- **확장성 보장**: Protocol 기반이라 언제든 DI 적용 가능
- **Technical Debt 관리**: 코드 보존, 이슈 문서화

**배운 것:**
1. **아키텍처 vs 안정성 트레이드오프**
   - 이상적인 설계보다 작동하는 코드가 우선
   - Technical Debt를 명시하고 관리하는 법

2. **AVFoundation의 복잡도**
   - 저수준 프레임워크는 메모리 관리가 critical
   - 클로저 생명주기와 비동기 처리의 어려움

3. **시간 관리의 중요성**
   - 11시간 투입 → 메모리 이슈 미해결
   - 완벽보다 완성이 중요

**향후 계획 (Phase 2):**
- Filter 로직 재설계 (클로저 외부 생성)
- Metal 기반 필터링 검토
- 실제 기기에서 메모리 프로파일링 후 재시도

#### 텍스트 오버레이 (CATextLayer)

**배경:**
- 비디오에 텍스트 추가 기능 구현 시도

**구현 상태:**
- Entity, UseCase 구현 완료
- ViewModel 메서드 주석 처리
- Service 레이어 미구현

**발생한 문제:**
- CATextLayer + AVFoundation 조합 시 메모리 관리 복잡도 증가
- CIFilter와 AnimationTool 동시 사용 시 충돌

**결정:**
- Entity와 UseCase 코드 보존
- Service 구현은 Phase 2로 연기

<br>

## 🎯 향후 개선 계획

### Phase 1: 안정성 & 필수 기능
- [ ] 트림 슬라이더 UI 구현
- [ ] 필터 실시간 프리뷰
- [ ] Export 진행률 표시

### Phase 2: 고도화
- [ ] DI Container 적용 (Filter 로직 재설계 후)
- [ ] 텍스트 오버레이 (CATextLayer 또는 Core Graphics)
- [ ] Unit Test 작성 (UseCase, Repository)
- [ ] 더 많은 필터 옵션

### Phase 3: UX 개선
- [ ] 편집 히스토리 (Undo/Redo)
- [ ] 프로젝트 저장/불러오기
- [ ] 트랜지션 효과

<br>

## 🚀 실행 방법

### 요구사항
- Xcode 15.0+
- iOS 16.0+
- Swift 5.9+

### 설치 및 실행
```bash
# 1. 저장소 클론
git clone https://github.com/your-username/ClipKit.git

# 2. 프로젝트 열기
cd ClipKit
open ClipKit.xcodeproj

# 3. 패키지 다운로드 (Xcode에서 자동)
File → Packages → Resolve Package Versions

# 4. 시뮬레이터 또는 실제 기기에서 실행
Cmd + R
```

### 주의사항
- **권한**: Info.plist에 사진 라이브러리 접근 권한 설정됨
- **테스트**: 시뮬레이터에 비디오 추가 필요 (드래그앤드롭)

<br>

## 📝 학습 노트

### 1. struct vs class (VideoProject)
- `VideoProject`를 struct로 설계 → 불변성 보장
- UseCase에서 수정된 project 반환 → ViewModel에서 재할당
- 값 타입의 안전성 활용

### 2. Protocol 사용 기준
- Repository/Service: Protocol 사용 (구현체 교체 가능)
- UseCase: Concrete class (비즈니스 로직, 단일 구현)
- YAGNI 원칙 적용

### 3. AVFoundation 메모리 관리
- CIFilter 클로저에서 `[weak self]` 필수
- 비동기 Export와 Service 생명주기 관리의 복잡도
- CALayer는 시뮬레이터에서 불안정 (실제 기기 권장)

### 4. Technical Debt 관리
- 미완성 기능을 삭제하지 않고 문서화
- 이슈, 원인, 해결 방안 명시
- 실무적 우선순위 판단 증명

<br>

## 👨‍💻 개발자

**오정석**
- GitHub: [@jungseok-corine](https://github.com/jungseok-corine)
- Email: fiverights99@gmail.com

<br>

## 📄 라이센스

This project is licensed under the MIT License.

---

**Made with ❤️ for iOS Portfolio**
