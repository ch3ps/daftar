//
//  JoinStoreView.swift
//  daftar
//
//  Customer joins a store using their code
//

import SwiftUI

struct JoinStoreView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    let onJoined: ((StoreProfile) -> Void)?
    
    @State private var storeCode = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var joinedStore: StoreProfile?
    
    @FocusState private var isCodeFocused: Bool
    
    init(onJoined: ((StoreProfile) -> Void)? = nil) {
        self.onJoined = onJoined
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if let store = joinedStore {
                    // Success state
                    successView(store: store)
                } else {
                    // Code entry
                    codeEntryView
                }
            }
            .navigationTitle(appState.localized("Join Store", arabic: "انضم لمتجر"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if joinedStore == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(appState.localized("Cancel", arabic: "إلغاء")) {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Code Entry View
    private var codeEntryView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
            
            // Instructions
            VStack(spacing: 8) {
                Text(appState.localized("Enter Store Code", arabic: "أدخل رمز المتجر"))
                    .font(.title2.bold())
                
                Text(appState.localized(
                    "Try: BAQALA, MEERA1, or LULU01",
                    arabic: "جرب: BAQALA أو MEERA1 أو LULU01"
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            
            // Code input
            TextField("", text: $storeCode)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 48)
                .focused($isCodeFocused)
                .onChange(of: storeCode) { _, newValue in
                    storeCode = String(newValue.uppercased().prefix(6))
                }
                .onSubmit {
                    joinStore()
                }
            
            // Join button
            Button {
                joinStore()
            } label: {
                Text(appState.localized("Join", arabic: "انضم"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        storeCode.count >= 4 ?
                        LinearGradient(
                            colors: [Color.accentColor, Color(hex: "764ba2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            colors: [Color.gray, Color.gray],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(storeCode.count < 4)
            .padding(.horizontal, 48)
            
            // Error message
            if let error {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
            
            // Loading
            if isLoading {
                ProgressView()
                    .padding()
            }
            
            Spacer()
            Spacer()
        }
        .padding()
        .onAppear {
            isCodeFocused = true
        }
    }
    
    // MARK: - Success View
    private func successView(store: StoreProfile) -> some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Success animation
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            
            VStack(spacing: 8) {
                Text(appState.localized("Connected!", arabic: "تم الربط!"))
                    .font(.title.bold())
                
                Text(store.displayName)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            
            Text(appState.localized(
                "You'll now see bills from this store",
                arabic: "ستشاهد الآن فواتير هذا المتجر"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            
            Spacer()
            
            Button {
                onJoined?(store)
                dismiss()
            } label: {
                Text(appState.localized("Done", arabic: "تم"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor, Color(hex: "764ba2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
    
    private var isDemoMode: Bool {
        UserDefaults.standard.bool(forKey: "is_demo_mode")
    }
    
    private func joinStore() {
        guard storeCode.count >= 4 else { return }
        
        isLoading = true
        error = nil
        
        if isDemoMode {
            joinStoreDemoMode()
        } else {
            joinStoreAPI()
        }
    }
    
    private func joinStoreDemoMode() {
        let customerId = authManager.customerProfile?.id ?? UUID()
        
        if let store = DemoData.shared.joinStore(code: storeCode, customerId: customerId) {
            withAnimation(.spring(duration: 0.5)) {
                joinedStore = store
            }
        } else {
            error = appState.localized(
                "Store not found. Try: BAQALA",
                arabic: "المتجر غير موجود. جرب: BAQALA"
            )
            storeCode = ""
        }
        
        isLoading = false
    }
    
    private func joinStoreAPI() {
        Task {
            do {
                let store = try await APIClient.shared.joinStore(code: storeCode)
                await MainActor.run {
                    withAnimation(.spring(duration: 0.5)) {
                        joinedStore = store
                    }
                    isLoading = false
                }
            } catch let apiError as APIError {
                await MainActor.run {
                    error = apiError.errorDescription ?? appState.localized(
                        "Store not found",
                        arabic: "المتجر غير موجود"
                    )
                    storeCode = ""
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    storeCode = ""
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    JoinStoreView()
        .environmentObject(AppState())
        .environmentObject(AuthManager())
}
