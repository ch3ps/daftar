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
    @State private var selectedRole: UserType?
    
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
                        selectedRole = .store
                    } label: {
                        RoleCard(
                            icon: "storefront.fill",
                            title: appState.localized("Store Owner", arabic: "صاحب متجر"),
                            subtitle: appState.localized(
                                "Track what customers owe you",
                                arabic: "تتبع ما يدين به العملاء"
                            ),
                            isLoading: false,
                            color: .accentColor
                        )
                    }
                    
                    // Customer button
                    Button {
                        selectedRole = .customer
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
                    
                    Text(appState.localized(
                        "Sign in or create an account with your phone number.",
                        arabic: "سجّل الدخول أو أنشئ حساباً برقم هاتفك."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                    
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
        .sheet(item: $selectedRole) { role in
            AuthSheetView(role: role)
                .environmentObject(appState)
                .environmentObject(authManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
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

extension UserType: Identifiable {
    var id: String { rawValue }
}

private enum AuthMode: String, CaseIterable, Identifiable {
    case signIn
    case signUp
    
    var id: String { rawValue }
}

private struct AuthSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    
    let role: UserType
    
    @State private var mode: AuthMode = .signIn
    @State private var phone = ""
    @State private var name = ""
    @State private var nameAr = ""
    @State private var code = ""
    @State private var isSendingOTP = false
    @State private var otpSent = false
    @State private var infoMessage: String?
    @State private var localError: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("", selection: $mode) {
                        Text(appState.localized("Sign In", arabic: "تسجيل الدخول"))
                            .tag(AuthMode.signIn)
                        Text(appState.localized("Create Account", arabic: "إنشاء حساب"))
                            .tag(AuthMode.signUp)
                    }
                    .pickerStyle(.segmented)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(roleTitle)
                            .font(.title2.weight(.bold))
                        Text(appState.localized(
                            "Use your phone number and a one-time code.",
                            arabic: "استخدم رقم هاتفك ورمز التحقق لمرة واحدة."
                        ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    
                    if mode == .signUp {
                        VStack(spacing: 12) {
                            textField(
                                title: appState.localized("Full Name", arabic: "الاسم الكامل"),
                                text: $name
                            )
                            textField(
                                title: appState.localized("Arabic Name (optional)", arabic: "الاسم بالعربية (اختياري)"),
                                text: $nameAr
                            )
                        }
                    }
                    
                    VStack(spacing: 12) {
                        textField(
                            title: appState.localized("Phone Number", arabic: "رقم الهاتف"),
                            text: $phone,
                            keyboard: .phonePad
                        )
                        
                        HStack(alignment: .top, spacing: 12) {
                            textField(
                                title: appState.localized("OTP Code", arabic: "رمز التحقق"),
                                text: $code,
                                keyboard: .numberPad
                            )
                            
                            Button {
                                Task { await sendOTP() }
                            } label: {
                                HStack {
                                    if isSendingOTP {
                                        ProgressView()
                                    } else {
                                        Text(otpSent
                                            ? appState.localized("Resend", arabic: "إعادة الإرسال")
                                            : appState.localized("Send Code", arabic: "إرسال الرمز"))
                                    }
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .frame(minWidth: 110)
                                .background(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(isSendingOTP || normalizedPhone.isEmpty)
                        }
                    }
                    
                    if let infoMessage {
                        Text(infoMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let errorMessage = localError ?? authManager.error {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(primaryButtonTitle)
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .background(
                            canSubmit
                                ? Color.accentColor
                                : Color.gray.opacity(0.45)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit || authManager.isLoading)
                }
                .padding(24)
            }
            .navigationTitle(mode == .signIn
                ? appState.localized("Sign In", arabic: "تسجيل الدخول")
                : appState.localized("Create Account", arabic: "إنشاء حساب"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(appState.localized("Cancel", arabic: "إلغاء")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var roleTitle: String {
        role == .store
            ? appState.localized("Store account", arabic: "حساب متجر")
            : appState.localized("Customer account", arabic: "حساب عميل")
    }
    
    private var primaryButtonTitle: String {
        if mode == .signIn {
            return role == .store
                ? appState.localized("Sign In as Store", arabic: "دخول كمتجر")
                : appState.localized("Sign In as Customer", arabic: "دخول كعميل")
        }
        
        return role == .store
            ? appState.localized("Create Store Account", arabic: "إنشاء حساب متجر")
            : appState.localized("Create Customer Account", arabic: "إنشاء حساب عميل")
    }
    
    private var normalizedPhone: String {
        phone.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var canSubmit: Bool {
        let baseValid = !normalizedPhone.isEmpty && !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if mode == .signIn {
            return baseValid
        }
        return baseValid && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    @ViewBuilder
    private func textField(title: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
            TextField(title, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func sendOTP() async {
        localError = nil
        infoMessage = nil
        
        guard !normalizedPhone.isEmpty else {
            localError = appState.localized("Enter your phone number first.", arabic: "أدخل رقم الهاتف أولاً.")
            return
        }
        
        isSendingOTP = true
        defer { isSendingOTP = false }
        
        do {
            let response = try await APIClient.shared.sendOTP(phone: normalizedPhone)
            otpSent = true
            infoMessage = response.message
            if let devOTP = response.devOtp, !devOTP.isEmpty {
                infoMessage = "\(response.message) (\(devOTP))"
            }
        } catch let apiError as APIError {
            localError = apiError.errorDescription
        } catch {
            localError = error.localizedDescription
        }
    }
    
    private func submit() async {
        localError = nil
        
        do {
            if mode == .signIn {
                if role == .store {
                    try await authManager.loginStore(phone: normalizedPhone, code: code)
                } else {
                    try await authManager.loginCustomer(phone: normalizedPhone, code: code)
                }
            } else {
                if role == .store {
                    try await authManager.registerStore(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        nameAr: nameAr.nilIfBlank,
                        phone: normalizedPhone,
                        code: code
                    )
                } else {
                    try await authManager.registerCustomer(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        nameAr: nameAr.nilIfBlank,
                        phone: normalizedPhone,
                        code: code
                    )
                }
            }
        } catch let authError as AuthError {
            localError = authError.errorDescription
        } catch {
            localError = error.localizedDescription
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
