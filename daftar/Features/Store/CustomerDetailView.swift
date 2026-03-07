//
//  CustomerDetailView.swift
//  daftar
//
//  Store's view of a customer's bills - with WhatsApp share & reminders
//

import SwiftUI
import Combine

struct CustomerDetailView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    let entry: LedgerEntry
    let onUpdate: (() -> Void)?
    
    @StateObject private var viewModel = CustomerDetailViewModel()
    @State private var showingAddBill = false
    @State private var showingReminderSheet = false
    
    init(entry: LedgerEntry, onUpdate: (() -> Void)? = nil) {
        self.entry = entry
        self.onUpdate = onUpdate
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Customer header
                    customerHeader
                    
                    // Action buttons row
                    actionButtons
                    
                    // Bills list
                    if viewModel.bills.isEmpty && !viewModel.isLoading {
                        emptyState
                    } else {
                        billsList
                    }
                }
                
                // Quick add button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showingAddBill = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.accentColor)
                                .clipShape(Circle())
                                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 4)
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
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
                    Menu {
                        Button {
                            // Call customer
                            if let phone = entry.customer?.phone,
                               let url = URL(string: "tel:\(phone)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label(
                                appState.localized("Call", arabic: "اتصال"),
                                systemImage: "phone.fill"
                            )
                        }
                        
                        Button {
                            // Send full statement via WhatsApp
                            WhatsAppShare.shareStatement(
                                customerName: entry.customer?.displayName ?? "",
                                totalOwed: entry.totalOwed,
                                bills: viewModel.bills,
                                storeName: authManager.storeProfile?.displayName ?? "",
                                phone: entry.customer?.phone
                            )
                        } label: {
                            Label(
                                appState.localized("Send Statement", arabic: "إرسال كشف حساب"),
                                systemImage: "message.fill"
                            )
                        }
                        
                        Button {
                            showingReminderSheet = true
                        } label: {
                            Label(
                                appState.localized("Set Reminder", arabic: "تعيين تذكير"),
                                systemImage: "bell.badge.fill"
                            )
                        }
                        
                        Button {
                            // Mark all as paid
                            HapticManager.success()
                            viewModel.markAllPaid()
                            onUpdate?()
                        } label: {
                            Label(
                                appState.localized("Mark All Paid", arabic: "تحديد الكل مدفوع"),
                                systemImage: "checkmark.circle.fill"
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                viewModel.loadBills(
                    storeId: authManager.storeProfile?.id ?? entry.storeId,
                    customerId: entry.customerId
                )
            }
            .sheet(isPresented: $showingAddBill) {
                ScanBillView(preselectedCustomer: entry) { _ in
                    viewModel.loadBills(
                        storeId: authManager.storeProfile?.id ?? entry.storeId,
                        customerId: entry.customerId
                    )
                    onUpdate?()
                }
            }
            .sheet(isPresented: $showingReminderSheet) {
                ReminderSheet(
                    storeId: authManager.storeProfile?.id ?? entry.storeId,
                    customerId: entry.customerId,
                    customerName: entry.customer?.displayName ?? "",
                    currentBalance: entry.totalOwed
                )
            }
        }
    }
    
    // MARK: - Customer Header
    private var customerHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 72, height: 72)
                .overlay(
                    Text(entry.customer?.name.prefix(1).uppercased() ?? "?")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.accentColor)
                )
            
            // Name
            Text(entry.customer?.displayName ?? "Unknown")
                .font(.title2.bold())
            
            // Phone
            if let phone = entry.customer?.phone {
                Text(phone)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Total owed
            VStack(spacing: 4) {
                Text(appState.localized("Total Owed", arabic: "إجمالي المستحق"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("QR")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text(entry.totalOwed.formatted(.number.precision(.fractionLength(0))))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(entry.totalOwed > 0 ? .primary : .green)
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // WhatsApp remind
            ActionButton(
                icon: "message.fill",
                label: appState.localized("Remind", arabic: "تذكير"),
                color: .green
            ) {
                WhatsAppShare.shareReminder(
                    customerName: entry.customer?.displayName ?? "",
                    totalOwed: entry.totalOwed,
                    storeName: authManager.storeProfile?.displayName ?? "",
                    phone: entry.customer?.phone
                )
            }
            
            // Send statement
            ActionButton(
                icon: "doc.text.fill",
                label: appState.localized("Statement", arabic: "كشف حساب"),
                color: Color.accentColor
            ) {
                WhatsAppShare.shareStatement(
                    customerName: entry.customer?.displayName ?? "",
                    totalOwed: entry.totalOwed,
                    bills: viewModel.bills,
                    storeName: authManager.storeProfile?.displayName ?? "",
                    phone: entry.customer?.phone
                )
            }
            
            // Set reminder
            ActionButton(
                icon: "bell.fill",
                label: appState.localized("Schedule", arabic: "جدولة"),
                color: .orange
            ) {
                showingReminderSheet = true
            }
        }
        .padding()
    }
    
    // MARK: - Bills List
    private var billsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.bills) { bill in
                    BillCard(
                        bill: bill,
                        storeName: authManager.storeProfile?.displayName ?? "",
                        customerPhone: entry.customer?.phone,
                        onTogglePaid: {
                            viewModel.toggleBillStatus(bill)
                            onUpdate?()
                        }
                    )
                }
            }
            .padding()
            .padding(.bottom, 80)
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
                "Tap + to add the first bill",
                arabic: "اضغط + لإضافة أول فاتورة"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            
            Spacer()
        }
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Bill Card (with WhatsApp share)
struct BillCard: View {
    let bill: Bill
    var storeName: String = ""
    var customerPhone: String? = nil
    let onTogglePaid: () -> Void
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
                            Text(appState.language == .arabic ? (item.nameAr ?? item.name) : item.name)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text("× \(item.quantity.formatted())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text("QR \(item.totalPrice.formatted(.number.precision(.fractionLength(2))))")
                                .font(.subheadline.monospacedDigit())
                                .frame(width: 80, alignment: .trailing)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        if item.id != bill.items.last?.id {
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
                
                Divider()
                
                // Action buttons
                HStack(spacing: 0) {
                    // WhatsApp share
                    Button {
                        WhatsAppShare.shareBill(
                            bill: bill,
                            storeName: storeName,
                            phone: customerPhone
                        )
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "message.fill")
                                .font(.caption)
                            Text(appState.localized("Share", arabic: "مشاركة"))
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    
                    Divider()
                        .frame(height: 30)
                    
                    // Mark as paid/unpaid
                    Button {
                        HapticManager.success()
                        onTogglePaid()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: bill.status == .paid ? "arrow.uturn.backward" : "checkmark.circle.fill")
                                .font(.caption)
                            Text(bill.status == .paid ?
                                appState.localized("Unpaid", arabic: "غير مدفوع") :
                                appState.localized("Paid", arabic: "مدفوع")
                            )
                            .font(.caption.bold())
                        }
                        .foregroundStyle(bill.status == .paid ? .orange : .green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: BillStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption2)
            Text(status.rawValue.capitalized)
                .font(.caption.bold())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
    
    private var color: Color {
        switch status {
        case .pending: return .orange
        case .paid: return .green
        case .disputed: return .red
        }
    }
}

// MARK: - Reminder Sheet
struct ReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    let storeId: UUID
    let customerId: UUID
    let customerName: String
    let currentBalance: Decimal
    
    @State private var reminderType: ReminderType = .scheduled
    @State private var daysInterval = 7
    @State private var balanceThreshold = ""
    @State private var existingReminder: Reminder?
    @State private var saved = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(appState.localized("Customer", arabic: "العميل"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(customerName)
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Text(appState.localized("Balance", arabic: "الرصيد"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("QR \(currentBalance.formatted(.number.precision(.fractionLength(2))))")
                            .fontWeight(.semibold)
                    }
                }
                
                Section(appState.localized("Reminder Type", arabic: "نوع التذكير")) {
                    Picker("", selection: $reminderType) {
                        ForEach(ReminderType.allCases, id: \.self) { type in
                            Label(
                                appState.language == .arabic ? type.displayNameAr : type.displayName,
                                systemImage: type.icon
                            ).tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                
                if reminderType == .scheduled {
                    Section(appState.localized("Repeat every", arabic: "كرر كل")) {
                        Picker(appState.localized("Days", arabic: "أيام"), selection: $daysInterval) {
                            Text("3 " + appState.localized("days", arabic: "أيام")).tag(3)
                            Text("7 " + appState.localized("days", arabic: "أيام")).tag(7)
                            Text("14 " + appState.localized("days", arabic: "يوم")).tag(14)
                            Text("30 " + appState.localized("days", arabic: "يوم")).tag(30)
                        }
                    }
                }
                
                if reminderType == .threshold {
                    Section(appState.localized("When balance exceeds", arabic: "عندما يتجاوز الرصيد")) {
                        HStack {
                            Text("QR")
                                .foregroundStyle(.secondary)
                            TextField("0", text: $balanceThreshold)
                                .keyboardType(.decimalPad)
                        }
                    }
                }
                
                if existingReminder != nil {
                    Section {
                        Button(role: .destructive) {
                            DemoData.shared.removeReminder(storeId: storeId, customerId: customerId)
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text(appState.localized("Remove Reminder", arabic: "إزالة التذكير"))
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(appState.localized("Set Reminder", arabic: "تعيين تذكير"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.localized("Cancel", arabic: "إلغاء")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.localized("Save", arabic: "حفظ")) {
                        saveReminder()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                existingReminder = DemoData.shared.getReminderForCustomer(storeId: storeId, customerId: customerId)
                if let existing = existingReminder {
                    reminderType = existing.type
                    daysInterval = existing.daysInterval ?? 7
                    if let threshold = existing.balanceThreshold {
                        balanceThreshold = "\(threshold)"
                    }
                }
            }
        }
    }
    
    private func saveReminder() {
        let threshold: FlexDecimal? = balanceThreshold.isEmpty ? nil : FlexDecimal(string: balanceThreshold)
        _ = DemoData.shared.setReminder(
            storeId: storeId,
            customerId: customerId,
            type: reminderType,
            daysInterval: reminderType == .scheduled ? daysInterval : nil,
            balanceThreshold: reminderType == .threshold ? threshold : nil,
            customerName: customerName
        )
        dismiss()
    }
}

// MARK: - Customer Detail View Model
@MainActor
final class CustomerDetailViewModel: ObservableObject {
    @Published var bills: [Bill] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private var storeId: UUID?
    private var customerId: UUID?
    
    private var isDemoMode: Bool {
        UserDefaults.standard.bool(forKey: "is_demo_mode")
    }
    
    func loadBills(storeId: UUID, customerId: UUID) {
        self.storeId = storeId
        self.customerId = customerId
        
        if isDemoMode {
            loadDemoBills(storeId: storeId, customerId: customerId)
        } else {
            loadFromAPI(customerId: customerId)
        }
    }
    
    private func loadDemoBills(storeId: UUID, customerId: UUID) {
        isLoading = true
        defer { isLoading = false }
        
        bills = DemoData.shared.getBillsForStoreCustomer(storeId: storeId, customerId: customerId)
    }
    
    private func loadFromAPI(customerId: UUID) {
        isLoading = true
        error = nil
        
        Task {
            do {
                let fetchedBills = try await APIClient.shared.getCustomerBills(customerId: customerId)
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
    
    func toggleBillStatus(_ bill: Bill) {
        let newStatus: BillStatus = bill.status == .paid ? .pending : .paid
        
        if isDemoMode {
            if let updated = DemoData.shared.updateBillStatus(billId: bill.id, status: newStatus) {
                if let index = bills.firstIndex(where: { $0.id == bill.id }) {
                    bills[index] = updated
                }
            }
        } else {
            Task {
                do {
                    let updated = try await APIClient.shared.updateBillStatus(billId: bill.id, status: newStatus)
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
    
    func markAllPaid() {
        for bill in bills where bill.status == .pending {
            toggleBillStatus(bill)
        }
    }
}

#Preview {
    CustomerDetailView(entry: LedgerEntry(
        storeId: UUID(),
        customerId: UUID(),
        totalOwed: 450,
        lastActivityAt: Date(),
        customer: CustomerProfile(
            id: UUID(),
            name: "Ahmed Al-Thani",
            nameAr: "أحمد الثاني",
            phone: "+974 5555 1234",
            createdAt: Date()
        )
    ))
    .environmentObject(AppState())
    .environmentObject(AuthManager())
}
