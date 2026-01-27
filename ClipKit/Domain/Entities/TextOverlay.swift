//
//  TextOverlay.swift
//  ClipKit
//
//  Created by 오정석 on 21/1/2026.
//

import Foundation
import UIKit

struct TextOverlay {
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
}
