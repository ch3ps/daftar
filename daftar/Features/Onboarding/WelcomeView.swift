//
//  WelcomeView.swift
//  daftar
//
//  Modern onboarding – choose Store or Customer, then sign in / register.
//

import SwiftUI

// MARK: - Welcome Screen

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedRole: UserType?
    @State private var logoAppeared = false
    @State private var cardsAppeared = false

    private let gradient = LinearGradient(
        colors: [Color(hex: "667EEA"), Color(hex: "5A67D8")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                Color(.systemBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Hero ──────────────────────────────────
                    heroSection(geo: geo)

                    // ── Cards ─────────────────────────────────
                    VStack(spacing: 14) {
                        roleButton(.store,
                            icon: "storefront.fill",
                            title: appState.localized("Store Owner", arabic: "صاحب متجر"),
                            subtitle: appState.localized("Track what customers owe you", arabic: "تتبع ما يدين به العملاء"),
                            tint: Color(hex: "667EEA")
                        )
                        roleButton(.customer,
                            icon: "person.fill",
                            title: appState.localized("Customer", arabic: "عميل"),
                            subtitle: appState.localized("See what you owe at stores", arabic: "شاهد ما تدين به للمتاجر"),
                            tint: .green
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .opacity(cardsAppeared ? 1 : 0)
                    .offset(y: cardsAppeared ? 0 : 30)

                    Spacer(minLength: 16)

                    // ── Footer ────────────────────────────────
                    VStack(spacing: 14) {
                        if let error = authManager.error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .transition(.opacity)
                        }

                        languageToggle
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? 16 : 28)
                }
            }
        }
        .environment(\.layoutDirection, appState.layoutDirection)
        .sheet(item: $selectedRole) { role in
            AuthSheetView(role: role)
                .environmentObject(appState)
                .environmentObject(authManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                logoAppeared = true
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.35)) {
                cardsAppeared = true
            }
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private func heroSection(geo: GeometryProxy) -> some View {
        ZStack {
            gradient
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 16) {
                Spacer(minLength: geo.safeAreaInsets.top + 24)

                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 108, height: 108)
                        .blur(radius: 1)

                    Text("د")
                        .font(.system(size: 54, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                }
                .scaleEffect(logoAppeared ? 1 : 0.5)
                .opacity(logoAppeared ? 1 : 0)

                VStack(spacing: 6) {
                    Text("Daftar")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(appState.localized("Your Digital Ledger", arabic: "دفتر حسابك الرقمي"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .opacity(logoAppeared ? 1 : 0)

                // Feature pills
                HStack(spacing: 10) {
                    featurePill(icon: "doc.text.magnifyingglass", text: appState.localized("Scan", arabic: "مسح"))
                    featurePill(icon: "chart.line.uptrend.xyaxis", text: appState.localized("Track", arabic: "تتبع"))
                    featurePill(icon: "bell.fill", text: appState.localized("Notify", arabic: "تنبيه"))
                }
                .padding(.top, 4)
                .opacity(logoAppeared ? 1 : 0)

                Spacer(minLength: 20)
            }
        }
        .frame(height: geo.size.height * 0.46)
        .clipShape(RoundedCornerShape(radius: 36, corners: [.bottomLeft, .bottomRight]))
    }

    private func featurePill(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.white.opacity(0.2))
        .clipShape(Capsule())
    }

    // MARK: - Role Button

    private func roleButton(_ role: UserType, icon: String, title: String, subtitle: String, tint: Color) -> some View {
        Button { selectedRole = role } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(tint.opacity(0.12))
                        .frame(width: 52, height: 52)

                    Image(systemName: icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Language Toggle

    private var languageToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.language = appState.language == .arabic ? .english : .arabic
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 13))
                Text(appState.language == .arabic ? "English" : "العربية")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(Color(.tertiarySystemBackground))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Custom Corner Shape

private struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Auth Sheet

private enum AuthMode: String, CaseIterable, Identifiable {
    case signIn, signUp
    var id: String { rawValue }
}

extension UserType: Identifiable {
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
    @State private var localError: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case phone, name, nameAr }

    private let accentGradient = LinearGradient(
        colors: [Color(hex: "667EEA"), Color(hex: "5A67D8")],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // ── Mode Picker ──────────────────
                    modeSelector

                    // ── Header ───────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        Text(roleTitle)
                            .font(.title2.weight(.bold))
                        Text(appState.localized(
                            "Enter your phone number to continue.",
                            arabic: "أدخل رقم هاتفك للمتابعة."
                        ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // ── Fields ───────────────────────
                    VStack(spacing: 16) {
                        if mode == .signUp {
                            styledField(
                                icon: "person",
                                placeholder: appState.localized("Full Name", arabic: "الاسم الكامل"),
                                text: $name,
                                keyboard: .default,
                                field: .name
                            )
                            styledField(
                                icon: "character.textbox",
                                placeholder: appState.localized("Arabic Name (optional)", arabic: "الاسم بالعربية (اختياري)"),
                                text: $nameAr,
                                keyboard: .default,
                                field: .nameAr
                            )
                        }

                        styledField(
                            icon: "phone",
                            placeholder: appState.localized("Phone Number", arabic: "رقم الهاتف"),
                            text: $phone,
                            keyboard: .phonePad,
                            field: .phone
                        )
                    }

                    // ── Error ────────────────────────
                    if let errorMessage = localError ?? authManager.error {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text(errorMessage)
                                .font(.caption)
                        }
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // ── Submit ───────────────────────
                    Button {
                        focusedField = nil
                        Task { await submit() }
                    } label: {
                        HStack(spacing: 8) {
                            if authManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(primaryButtonTitle)
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .foregroundStyle(.white)
                        .background(
                            canSubmit
                                ? AnyShapeStyle(accentGradient)
                                : AnyShapeStyle(Color.gray.opacity(0.35))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: canSubmit ? Color(hex: "667EEA").opacity(0.35) : .clear, radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit || authManager.isLoading)
                    .animation(.easeInOut(duration: 0.2), value: canSubmit)
                }
                .padding(24)
                .padding(.top, 4)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: 0) {
            ForEach(AuthMode.allCases) { m in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        mode = m
                        localError = nil
                        authManager.error = nil
                    }
                } label: {
                    Text(m == .signIn
                         ? appState.localized("Sign In", arabic: "تسجيل الدخول")
                         : appState.localized("Create Account", arabic: "إنشاء حساب"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(mode == m ? Color.accentColor : Color.clear)
                        .foregroundStyle(mode == m ? .white : .secondary)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemBackground))
        )
    }

    // MARK: - Styled Field

    @ViewBuilder
    private func styledField(icon: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType, field: Field) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .phonePad ? .never : .words)
                .autocorrectionDisabled()
                .focused($focusedField, equals: field)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(focusedField == field ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.15), value: focusedField)
    }

    // MARK: - Helpers

    private var roleTitle: String {
        role == .store
            ? appState.localized("Store Account", arabic: "حساب متجر")
            : appState.localized("Customer Account", arabic: "حساب عميل")
    }

    private var primaryButtonTitle: String {
        mode == .signIn
            ? appState.localized("Sign In", arabic: "تسجيل الدخول")
            : appState.localized("Create Account", arabic: "إنشاء حساب")
    }

    private var normalizedPhone: String {
        phone.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        let phoneOK = !normalizedPhone.isEmpty
        if mode == .signIn { return phoneOK }
        return phoneOK && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Submit

    private func submit() async {
        localError = nil

        do {
            if mode == .signIn {
                if role == .store {
                    try await authManager.loginStore(phone: normalizedPhone)
                } else {
                    try await authManager.loginCustomer(phone: normalizedPhone)
                }
            } else {
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if role == .store {
                    try await authManager.registerStore(
                        name: trimmedName,
                        nameAr: nameAr.nilIfBlank,
                        phone: normalizedPhone
                    )
                } else {
                    try await authManager.registerCustomer(
                        name: trimmedName,
                        nameAr: nameAr.nilIfBlank,
                        phone: normalizedPhone
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

// MARK: - Utility Extensions

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

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
