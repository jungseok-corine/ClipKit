//
//  TextOverlay.swift
//  ClipKit
//
//  Created by 오정석 on 21/1/2026.
//

import Foundation
import UIKit

struct TextOverlay: Codable {
    let id: UUID
    var text: String
    var position: CGPoint
    var color: UIColor
    var fontSize: CGFloat
    
    init(text: String,
         position: CGPoint = CGPoint(x: 0.5, y: 0.5),
         color: UIColor = .white,
         fontSize: CGFloat = 40) {
        self.id = UUID()
        self.text = text
        self.position = position
        self.color = color
        self.fontSize = fontSize
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, text, position, colorHex, fontSize
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        position = try container.decode(CGPoint.self, forKey: .position)
        fontSize = try container.decode(CGFloat.self, forKey: .fontSize)
        
        // Hex 문자열 → UIColor
        let colorHex = try container.decode(String.self, forKey: .colorHex)
        color = UIColor(hex: colorHex)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(position, forKey: .position)
        try container.encode(fontSize, forKey: .fontSize)
        
        // UIColor -> Hex 문자열
        let colorHex = color.toHex ?? "FFFFFF"
        try container.encode(colorHex, forKey: .colorHex)
    }
}
