//
//  FilterType.swift
//  ClipKit
//
//  Created by 오정석 on 21/1/2026.
//

import Foundation
import AVFoundation
import CoreImage

enum FilterType: String, Codable {
    case original
    case sepia
    case noir
    case vivid
    
    var filterName: String? {
        switch self {
        case .original:
            return nil
        case .sepia:
            return "CISepiaTone"
        case .noir:
            return "CIPhotoEffectNoir"
        case .vivid:
            return "CIColorControls"
        }
    }
    
    var displayName: String {
        switch self {
        case .original:
            return "원본"
        case .sepia:
            return "세피아"
        case .noir:
            return "흑백"
        case .vivid:
            return "선명"
        }
    }
}
