//
//  Item.swift
//  kotobase-iOS
//
//  Created by m.li on 2026/04/07.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
