//
//  KeyHintView.swift
//  NotionBuddySwift
//
//  Created by Harry Alexandroff on 18.08.2024.
//

import Foundation
import SwiftUI

struct KeyHint: Identifiable {
    let id = UUID()
    let key: String
    let action: String
}

struct KeyHintView: View {
    let hints: [KeyHint]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(hints) { hint in
                HStack(spacing: 4) {
                    Text(hint.key)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(hint.action)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}
