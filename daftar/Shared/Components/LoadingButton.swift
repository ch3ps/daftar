//
//  LoadingButton.swift
//  daftar
//
//  Reusable button with loading state
//

import SwiftUI

struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    
    var style: ButtonStyle = .primary
    
    enum ButtonStyle {
        case primary
        case secondary
        case destructive
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .accentColor
            case .secondary: return .secondary.opacity(0.2)
            case .destructive: return .red
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .primary
            case .destructive: return .white
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(style.foregroundColor)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(style.backgroundColor)
            .foregroundStyle(style.foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isLoading)
    }
}

// MARK: - Style Modifier
extension LoadingButton {
    func buttonStyle(_ style: ButtonStyle) -> LoadingButton {
        var button = self
        button.style = style
        return button
    }
}

#Preview {
    VStack(spacing: 16) {
        LoadingButton(title: "Submit", isLoading: false) {}
        LoadingButton(title: "Loading...", isLoading: true) {}
        LoadingButton(title: "Secondary", isLoading: false) {}
            .buttonStyle(.secondary)
        LoadingButton(title: "Delete", isLoading: false) {}
            .buttonStyle(.destructive)
    }
    .padding()
}
