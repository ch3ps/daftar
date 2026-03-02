//
//  WelcomeView.swift
//  daftar
//
//  Clean minimal welcome screen - choose Store or Customer
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer()
                
                // Logo & Title
                VStack(spacing: 20) {
                    // App icon style logo
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.accentColor)
                            .frame(width: 100, height: 100)
                        
                        Text("د")
                            .font(.system(size: 52, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 16, y: 8)
                    
                    VStack(spacing: 8) {
                        Text("Daftar")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        
                        Text(appState.localized(
                            "Your Digital Ledger",
                            arabic: "دفتر حسابك الرقمي"
                        ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Role selection
                VStack(spacing: 16) {
                    Text(appState.localized("I am a...", arabic: "أنا..."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Store button
                    Button {
                        Task {
                            await authManager.enterAsDemoStore()
                        }
                    } label: {
                        RoleCard(
                            icon: "storefront.fill",
                            title: appState.localized("Store Owner", arabic: "صاحب متجر"),
                            subtitle: appState.localized(
                                "Track what customers owe you",
                                arabic: "تتبع ما يدين به العملاء"
                            ),
                            isLoading: authManager.isLoading && authManager.userType == nil,
                            color: .accentColor
                        )
                    }
                    .disabled(authManager.isLoading)
                    
                    // Customer button
                    Button {
                        authManager.enterAsDemoCustomer()
                    } label: {
                        RoleCard(
                            icon: "person.fill",
                            title: appState.localized("Customer", arabic: "عميل"),
                            subtitle: appState.localized(
                                "See what you owe at stores",
                                arabic: "شاهد ما تدين به للمتاجر"
                            ),
                            isLoading: false,
                            color: .green
                        )
                    }
                    .disabled(authManager.isLoading)
                    
                    // Error message
                    if let error = authManager.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                    .frame(height: 40)
                
                // Language toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.language = appState.language == .arabic ? .english : .arabic
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.caption)
                        Text(appState.language == .arabic ? "English" : "العربية")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
                }
                .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? 20 : 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
        .environment(\.layoutDirection, appState.layoutDirection)
    }
}

// MARK: - Role Card
struct RoleCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isLoading: Bool
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 52, height: 52)
                
                if isLoading {
                    ProgressView()
                        .tint(color)
                } else {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                }
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Hex Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AppState())
        .environmentObject(AuthManager())
}
