//
//  SettingsView.swift
//  daftar
//
//  Settings with appearance, language, data management, and account options
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var pushManager: PushNotificationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingStaff = false
    @State private var showingAnalytics = false
    @State private var showingExport = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDataExport = false
    @State private var isExportingData = false
    @State private var isDeletingAccount = false
    @State private var exportedDataURL: URL?
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationStack {
            List {
                // Profile section
                profileSection
                
                // Store management (store users only)
                if authManager.userType == .store {
                    storeManagementSection
                }
                
                // Notifications
                notificationsSection
                
                // Language & Appearance
                preferencesSection
                
                // Data & Privacy
                dataPrivacySection
                
                // About & Legal
                aboutSection
                
                // Logout
                logoutSection
            }
            .navigationTitle(appState.localized("Settings", arabic: "الإعدادات"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.localized("Done", arabic: "تم")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingStaff) {
                StaffManagementView()
            }
            .sheet(isPresented: $showingAnalytics) {
                AnalyticsView()
            }
            .sheet(isPresented: $showingExport) {
                ExportView(customers: [])
            }
            .sheet(isPresented: $showingDataExport) {
                if let url = exportedDataURL {
                    ShareSheet(items: [url])
                }
            }
            .confirmationDialog(
                appState.localized("Delete Account", arabic: "حذف الحساب"),
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(appState.localized("Delete Permanently", arabic: "حذف نهائياً"), role: .destructive) {
                    deleteAccount()
                }
                Button(appState.localized("Cancel", arabic: "إلغاء"), role: .cancel) {}
            } message: {
                Text(appState.localized(
                    "This will permanently delete your account and all associated data. This action cannot be undone.",
                    arabic: "سيؤدي هذا إلى حذف حسابك وجميع البيانات المرتبطة به نهائياً. لا يمكن التراجع عن هذا الإجراء."
                ))
            }
            .alert(appState.localized("Error", arabic: "خطأ"), isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .environment(\.layoutDirection, appState.layoutDirection)
    }
    
    // MARK: - Profile Section
    
    @ViewBuilder
    private var profileSection: some View {
        Section {
            if authManager.userType == .store {
                if let store = authManager.storeProfile {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "storefront.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.accentColor)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.displayName)
                                .font(.headline)
                            
                            if let phone = store.phone {
                                Text(phone)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack(spacing: 4) {
                                Text(appState.localized("Code:", arabic: "الرمز:"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(store.joinCode)
                                    .font(.caption.monospaced().bold())
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else {
                if let customer = authManager.customerProfile {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Text(customer.name.prefix(1).uppercased())
                                    .font(.title2.bold())
                                    .foregroundStyle(Color.accentColor)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(customer.displayName)
                                .font(.headline)
                            
                            if let phone = customer.phone {
                                Text(phone)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    // MARK: - Store Management Section
    
    @ViewBuilder
    private var storeManagementSection: some View {
        Section(appState.localized("Store Management", arabic: "إدارة المتجر")) {
            Button {
                showingStaff = true
            } label: {
                Label(
                    appState.localized("Staff & Branches", arabic: "الموظفين والفروع"),
                    systemImage: "person.3.fill"
                )
            }
            
            Button {
                showingAnalytics = true
            } label: {
                Label(
                    appState.localized("Analytics", arabic: "التحليلات"),
                    systemImage: "chart.bar.fill"
                )
            }
            
            Button {
                showingExport = true
            } label: {
                Label(
                    appState.localized("Export Ledger", arabic: "تصدير الدفتر"),
                    systemImage: "square.and.arrow.up"
                )
            }
        }
    }
    
    // MARK: - Notifications Section
    
    @ViewBuilder
    private var notificationsSection: some View {
        Section(appState.localized("Notifications", arabic: "الإشعارات")) {
            if pushManager.isAuthorized {
                HStack {
                    Label(
                        appState.localized("Push Notifications", arabic: "إشعارات الدفع"),
                        systemImage: "bell.badge.fill"
                    )
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            } else {
                Button {
                    Task {
                        await pushManager.requestAuthorization()
                    }
                } label: {
                    HStack {
                        Label(
                            appState.localized("Enable Notifications", arabic: "تفعيل الإشعارات"),
                            systemImage: "bell.fill"
                        )
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Preferences Section
    
    @ViewBuilder
    private var preferencesSection: some View {
        Section(appState.localized("Preferences", arabic: "التفضيلات")) {
            Picker(appState.localized("Language", arabic: "اللغة"), selection: $appState.language) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            
            Picker(selection: $appState.appearance) {
                ForEach(AppAppearance.allCases, id: \.self) { mode in
                    Label(
                        mode.displayName(localized: appState.localized),
                        systemImage: mode.icon
                    )
                    .tag(mode)
                }
            } label: {
                Label(
                    appState.localized("Appearance", arabic: "المظهر"),
                    systemImage: appState.appearance.icon
                )
            }
        }
    }
    
    // MARK: - Data & Privacy Section
    
    @ViewBuilder
    private var dataPrivacySection: some View {
        Section(appState.localized("Data & Privacy", arabic: "البيانات والخصوصية")) {
            Button {
                exportData()
            } label: {
                HStack {
                    Label(
                        appState.localized("Export My Data", arabic: "تصدير بياناتي"),
                        systemImage: "arrow.down.doc.fill"
                    )
                    Spacer()
                    if isExportingData {
                        ProgressView()
                    }
                }
            }
            .disabled(isExportingData)
            
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Label(
                        appState.localized("Delete Account", arabic: "حذف الحساب"),
                        systemImage: "trash.fill"
                    )
                    Spacer()
                    if isDeletingAccount {
                        ProgressView()
                    }
                }
            }
            .disabled(isDeletingAccount)
        }
    }
    
    // MARK: - About Section
    
    @ViewBuilder
    private var aboutSection: some View {
        Section(appState.localized("About", arabic: "حول")) {
            HStack {
                Text(appState.localized("Version", arabic: "الإصدار"))
                Spacer()
                Text("2.1.0")
                    .foregroundStyle(.secondary)
            }
            
            Link(destination: URL(string: "https://daftar.app/privacy")!) {
                HStack {
                    Text(appState.localized("Privacy Policy", arabic: "سياسة الخصوصية"))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Link(destination: URL(string: "https://daftar.app/terms")!) {
                HStack {
                    Text(appState.localized("Terms of Service", arabic: "شروط الخدمة"))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Logout Section
    
    @ViewBuilder
    private var logoutSection: some View {
        Section {
            Button(role: .destructive) {
                authManager.logout()
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Text(appState.localized("Log Out", arabic: "تسجيل الخروج"))
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func exportData() {
        isExportingData = true
        
        Task {
            do {
                let data: Data
                if authManager.userType == .store {
                    data = try await APIClient.shared.exportStoreData()
                } else {
                    data = try await APIClient.shared.exportCustomerData()
                }
                
                let filename = "daftar-export-\(Date().ISO8601Format()).json"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                try data.write(to: tempURL)
                
                await MainActor.run {
                    exportedDataURL = tempURL
                    isExportingData = false
                    showingDataExport = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isExportingData = false
                }
            }
        }
    }
    
    private func deleteAccount() {
        isDeletingAccount = true
        
        Task {
            do {
                if authManager.userType == .store {
                    try await APIClient.shared.deleteStoreAccount()
                } else {
                    try await APIClient.shared.deleteCustomerAccount()
                }
                
                await MainActor.run {
                    authManager.logout()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isDeletingAccount = false
                }
            }
        }
    }
}


#Preview {
    SettingsView()
        .environmentObject(AppState())
        .environmentObject(AuthManager())
        .environmentObject(PushNotificationManager.shared)
}
