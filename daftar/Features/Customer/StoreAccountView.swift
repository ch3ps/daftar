//
//  StoreAccountView.swift
//  daftar
//
//  Customer's view of their account with a specific store - with pay button
//

import SwiftUI
import Combine

struct StoreAccountView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    let ledger: CustomerLedger
    let onUpdate: (() -> Void)?
    
    @StateObject private var viewModel = StoreAccountViewModel()
    @State private var showingPayment = false
    
    init(ledger: CustomerLedger, onUpdate: (() -> Void)? = nil) {
        self.ledger = ledger
        self.onUpdate = onUpdate
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Store header
                    storeHeader
                    
                    // Pay button (if balance > 0)
                    if ledger.totalOwed > 0 {
                        payButton
                    }
                    
                    // Bills list
                    if viewModel.bills.isEmpty && !viewModel.isLoading {
                        emptyState
                    } else {
                        billsList
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if let phone = ledger.store?.phone {
                        Button {
                            if let url = URL(string: "tel:\(phone)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Image(systemName: "phone.fill")
                        }
                    }
                }
            }
            .onAppear {
                viewModel.loadBills(
                    storeId: ledger.storeId,
                    customerId: authManager.customerProfile?.id ?? ledger.customerId
                )
            }
            .sheet(isPresented: $showingPayment) {
                PaymentView(
                    storeName: ledger.store?.displayName ?? "Store",
                    storeId: ledger.storeId,
                    customerId: authManager.customerProfile?.id ?? ledger.customerId,
                    totalOwed: ledger.totalOwed,
                    onPaymentComplete: {
                        viewModel.loadBills(
                            storeId: ledger.storeId,
                            customerId: authManager.customerProfile?.id ?? ledger.customerId
                        )
                        onUpdate?()
                    }
                )
            }
        }
    }
    
    // MARK: - Store Header
    private var storeHeader: some View {
        VStack(spacing: 16) {
            // Store logo or placeholder
            storePlaceholder
            
            // Store name
            Text(ledger.store?.displayName ?? "Unknown")
                .font(.title2.bold())
            
            // Address
            if let address = ledger.store?.address {
                Text(address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Total owed
            VStack(spacing: 4) {
                Text(appState.localized("You Owe", arabic: "المستحق عليك"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("QR")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text(ledger.totalOwed.formatted(.number.precision(.fractionLength(0))))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(ledger.totalOwed > 0 ? .primary : .green)
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
    }
    
    private var storePlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.accentColor.opacity(0.15))
            .frame(width: 72, height: 72)
            .overlay(
                Image(systemName: "storefront.fill")
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
            )
    }
    
    // MARK: - Pay Button
    private var payButton: some View {
        Button {
            showingPayment = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "creditcard.fill")
                Text(appState.localized("Pay Now", arabic: "ادفع الآن"))
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.green)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Bills List
    private var billsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.bills) { bill in
                    CustomerBillCard(bill: bill) {
                        viewModel.disputeBill(bill)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text(appState.localized("No bills yet", arabic: "لا توجد فواتير بعد"))
                .font(.headline)
            
            Text(appState.localized(
                "Bills from this store will appear here",
                arabic: "ستظهر هنا فواتير هذا المتجر"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            
            Spacer()
        }
    }
}

// MARK: - Customer Bill Card
struct CustomerBillCard: View {
    let bill: Bill
    let onDispute: () -> Void
    @EnvironmentObject var appState: AppState
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bill.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                    
                    Text("\(bill.items.count) " + appState.localized("items", arabic: "عنصر"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Status badge
                StatusBadge(status: bill.status)
                
                // Total
                Text("QR \(bill.totalAmount.formatted(.number.precision(.fractionLength(0))))")
                    .font(.headline.monospacedDigit())
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            
            // Expanded items
            if isExpanded {
                Divider()
                
                VStack(spacing: 0) {
                    ForEach(bill.items) { item in
                        HStack {
                            itemPlaceholder
                            
                            Text(appState.language == .arabic ? (item.nameAr ?? item.name) : item.name)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text("× \(item.quantity.formatted())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text("QR \(item.totalPrice.formatted(.number.precision(.fractionLength(2))))")
                                .font(.subheadline.monospacedDigit())
                                .frame(width: 70, alignment: .trailing)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        if item.id != bill.items.last?.id {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
                
                // Dispute button (only for pending bills)
                if bill.status == .pending {
                    Divider()
                    
                    Button {
                        onDispute()
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(appState.localized("Report Issue", arabic: "الإبلاغ عن مشكلة"))
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
    
    private var itemPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray5))
            .frame(width: 40, height: 40)
            .overlay(
                Image(systemName: "basket.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            )
    }
}

// MARK: - Store Account View Model
@MainActor
final class StoreAccountViewModel: ObservableObject {
    @Published var bills: [Bill] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private var storeId: UUID?
    
    private var isDemoMode: Bool {
        UserDefaults.standard.bool(forKey: "is_demo_mode")
    }
    
    func loadBills(storeId: UUID, customerId: UUID) {
        self.storeId = storeId
        
        if isDemoMode {
            loadDemoBills(storeId: storeId, customerId: customerId)
        } else {
            loadFromAPI(storeId: storeId)
        }
    }
    
    private func loadDemoBills(storeId: UUID, customerId: UUID) {
        isLoading = true
        defer { isLoading = false }
        
        bills = DemoData.shared.getBillsForCustomer(storeId: storeId, customerId: customerId)
    }
    
    private func loadFromAPI(storeId: UUID) {
        isLoading = true
        error = nil
        
        Task {
            do {
                let fetchedBills = try await APIClient.shared.getStoreBillsForCustomer(storeId: storeId)
                await MainActor.run {
                    self.bills = fetchedBills
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                    print("API error loading bills: \(error)")
                }
            }
        }
    }
    
    func disputeBill(_ bill: Bill) {
        if isDemoMode {
            _ = DemoData.shared.updateBillStatus(billId: bill.id, status: .disputed)
            if let index = bills.firstIndex(where: { $0.id == bill.id }) {
                bills[index].status = .disputed
            }
        } else {
            Task {
                do {
                    let updated = try await APIClient.shared.updateBillStatus(billId: bill.id, status: .disputed)
                    await MainActor.run {
                        if let index = self.bills.firstIndex(where: { $0.id == bill.id }) {
                            self.bills[index] = updated
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.error = error.localizedDescription
                    }
                }
            }
        }
    }
}

#Preview {
    StoreAccountView(ledger: CustomerLedger(
        storeId: UUID(),
        customerId: UUID(),
        totalOwed: 320,
        lastActivityAt: Date(),
        store: StoreProfile(
            id: UUID(),
            name: "Al Meera",
            nameAr: "الميرة",
            phone: "+974 5555 1234",
            address: "Al Sadd, Doha",
            logoUrl: nil,
            joinCode: "ABC123",
            createdAt: Date()
        )
    ))
    .environmentObject(AppState())
    .environmentObject(AuthManager())
}
