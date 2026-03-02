//
//  CustomerMainView.swift
//  daftar
//
//  Main customer interface - see stores, bills, notifications, discover, pay
//

import SwiftUI
import Combine

struct CustomerMainView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = CustomerViewModel()
    
    @State private var showingSettings = false
    @State private var showingJoinStore = false
    @State private var showingDiscovery = false
    @State private var selectedStore: CustomerLedger?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Total owed header
                    totalHeader
                    
                    // Notifications banner
                    if viewModel.pendingCount > 0 {
                        notificationBanner
                    }
                    
                    // Stores list
                    if viewModel.stores.isEmpty && !viewModel.isLoading {
                        emptyState
                    } else {
                        storesList
                    }
                }
            }
            .navigationTitle(appState.localized("My Accounts", arabic: "حساباتي"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        // Discover stores
                        Button {
                            showingDiscovery = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                        }
                        
                        // Join by code
                        Button {
                            showingJoinStore = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            .refreshable {
                viewModel.loadData(customerId: authManager.customerProfile?.id)
            }
            .onAppear {
                viewModel.loadData(customerId: authManager.customerProfile?.id)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingJoinStore) {
                JoinStoreView { _ in
                    viewModel.loadData(customerId: authManager.customerProfile?.id)
                }
            }
            .sheet(isPresented: $showingDiscovery) {
                StoreDiscoveryView { _ in
                    viewModel.loadData(customerId: authManager.customerProfile?.id)
                }
            }
            .sheet(item: $selectedStore) { store in
                StoreAccountView(ledger: store) {
                    viewModel.loadData(customerId: authManager.customerProfile?.id)
                }
            }
        }
        .environment(\.layoutDirection, appState.layoutDirection)
    }
    
    // MARK: - Total Header
    private var totalHeader: some View {
        VStack(spacing: 8) {
            Text(appState.localized("Total You Owe", arabic: "إجمالي المستحق عليك"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("QR")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                Text(viewModel.totalOwed.formatted(.number.precision(.fractionLength(0))))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(viewModel.totalOwed > 0 ? .primary : .green)
            }
            
            Text("\(viewModel.stores.count) " +
                 appState.localized("stores", arabic: "متجر"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Notification Banner
    private var notificationBanner: some View {
        Button {
            // Show recent bills
        } label: {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(.white)
                
                Text("\(viewModel.pendingCount) " +
                     appState.localized("new bills added", arabic: "فواتير جديدة"))
                    .font(.subheadline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding()
            .background(Color.accentColor)
        }
    }
    
    // MARK: - Stores List
    private var storesList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(viewModel.stores) { store in
                    StoreRow(ledger: store)
                        .onTapGesture {
                            selectedStore = store
                        }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding()
            
            // Discover more stores button
            Button {
                showingDiscovery = true
            } label: {
                HStack {
                    Image(systemName: "compass.drawing")
                    Text(appState.localized("Discover More Stores", arabic: "اكتشف متاجر أخرى"))
                }
                .font(.subheadline.bold())
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "storefront")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text(appState.localized("No stores connected", arabic: "لا توجد متاجر متصلة"))
                .font(.headline)
            
            Text(appState.localized(
                "Join a store using their code or discover nearby stores",
                arabic: "انضم لمتجر باستخدام الرمز أو اكتشف المتاجر القريبة"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            
            HStack(spacing: 16) {
                Button {
                    showingJoinStore = true
                } label: {
                    HStack {
                        Image(systemName: "qrcode")
                        Text(appState.localized("Enter Code", arabic: "أدخل رمز"))
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                }
                
                Button {
                    showingDiscovery = true
                } label: {
                    HStack {
                        Image(systemName: "compass.drawing")
                        Text(appState.localized("Discover", arabic: "اكتشف"))
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Store Row
struct StoreRow: View {
    let ledger: CustomerLedger
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 16) {
            // Store logo or placeholder
            storePlaceholder
            
            // Name & last activity
            VStack(alignment: .leading, spacing: 4) {
                Text(ledger.store?.displayName ?? "Unknown")
                    .font(.headline)
                
                Text(ledger.lastActivityAt.relativeFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Amount owed
            VStack(alignment: .trailing, spacing: 2) {
                Text("QR \(ledger.totalOwed.formatted(.number.precision(.fractionLength(0))))")
                    .font(.headline.monospacedDigit())
                    .foregroundColor(ledger.totalOwed > 0 ? .primary : .green)
                
                if ledger.totalOwed > 0 {
                    Text(appState.localized("owed", arabic: "مستحق"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(appState.localized("settled", arabic: "مسدد"))
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
    }
    
    private var storePlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.accentColor.opacity(0.15))
            .frame(width: 48, height: 48)
            .overlay(
                Image(systemName: "storefront.fill")
                    .foregroundStyle(Color.accentColor)
            )
    }
}

// MARK: - Customer View Model
@MainActor
final class CustomerViewModel: ObservableObject {
    @Published var stores: [CustomerLedger] = []
    @Published var totalOwed: Decimal = 0
    @Published var pendingCount = 0
    @Published var isLoading = false
    @Published var error: String?
    
    private var isDemoMode: Bool {
        UserDefaults.standard.bool(forKey: "is_demo_mode")
    }
    
    func loadData(customerId: UUID?) {
        if isDemoMode {
            loadDemoData(customerId: customerId)
        } else {
            loadFromAPI()
        }
    }
    
    private func loadDemoData(customerId: UUID?) {
        isLoading = true
        defer { isLoading = false }
        
        stores = DemoData.shared.joinedStores
        totalOwed = stores.reduce(0) { $0 + $1.totalOwed }
        
        if let id = customerId {
            pendingCount = DemoData.shared.getPendingBillsCount(customerId: id)
        }
    }
    
    private func loadFromAPI() {
        isLoading = true
        error = nil
        
        Task {
            do {
                async let ledgerTask = APIClient.shared.getCustomerLedger()
                async let pendingTask = APIClient.shared.getPendingBillsCount()
                
                let (ledger, pending) = try await (ledgerTask, pendingTask)
                
                await MainActor.run {
                    self.stores = ledger
                    self.totalOwed = ledger.reduce(0) { $0 + $1.totalOwed }
                    self.pendingCount = pending
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                    print("API error loading customer data: \(error)")
                }
            }
        }
    }
}

#Preview {
    CustomerMainView()
        .environmentObject(AppState())
        .environmentObject(AuthManager())
}
