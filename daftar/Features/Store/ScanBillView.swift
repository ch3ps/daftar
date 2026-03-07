//
//  ScanBillView.swift
//  daftar
//
//  Quick bill entry - optimized for speed. 2 taps to add a bill!
//

import SwiftUI
import PhotosUI
import Combine

struct ScanBillView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    let preselectedCustomer: LedgerEntry?
    let onBillCreated: ((Bill?) -> Void)?
    
    @StateObject private var viewModel = ScanBillViewModel()
    @State private var showingCustomerPicker = false
    @State private var showingDetailedEntry = false
    @State private var showSuccess = false
    @State private var createdBill: Bill?
    
    init(preselectedCustomer: LedgerEntry?, onBillCreated: ((Bill?) -> Void)? = nil) {
        self.preselectedCustomer = preselectedCustomer
        self.onBillCreated = onBillCreated
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                if showSuccess {
                    successView
                } else {
                    quickEntryView
                }
            }
            .navigationTitle(appState.localized("New Bill", arabic: "فاتورة جديدة"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.localized("Cancel", arabic: "إلغاء")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingDetailedEntry = true
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showingCustomerPicker) {
                CustomerPickerView(
                    selectedCustomer: $viewModel.selectedCustomer,
                    storeId: authManager.storeProfile?.id ?? UUID()
                )
            }
            .sheet(isPresented: $showingDetailedEntry) {
                DetailedBillEntryView(viewModel: viewModel) {
                    saveBill()
                }
            }
            .onChange(of: viewModel.items) { oldValue, newValue in
                // Keep amount display in sync when items change
                if !newValue.isEmpty {
                    let itemsTotal = newValue.reduce(FlexDecimal.zero) { $0 + $1.totalPrice }
                    viewModel.amountString = "\(itemsTotal)"
                }
            }
            .onAppear {
                if let customer = preselectedCustomer {
                    viewModel.selectedCustomer = customer
                }
                viewModel.loadRecentCustomers(storeId: authManager.storeProfile?.id)
            }
        }
    }
    
    // MARK: - Quick Entry View (Main)
    private var quickEntryView: some View {
        VStack(spacing: 0) {
            // Amount display
            amountDisplay
            
            // Recent customers (horizontal scroll)
            recentCustomersSection
            
            // Number pad
            numberPad
            
            // Add button
            addButton
        }
    }
    
    // MARK: - Amount Display
    private var amountDisplay: some View {
        VStack(spacing: 8) {
            Text(appState.localized("Amount", arabic: "المبلغ"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("QR")
                    .font(.title)
                    .foregroundStyle(.secondary)
                
                Text(viewModel.amountString.isEmpty ? "0" : viewModel.amountString)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Recent Customers Section
    private var recentCustomersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(appState.localized("Customer", arabic: "العميل"))
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    showingCustomerPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                        Text(appState.localized("Search", arabic: "بحث"))
                    }
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal)
            
            // Selected customer or recent customers grid
            if let selected = viewModel.selectedCustomer {
                // Show selected customer
                selectedCustomerCard(selected)
            } else {
                // Show recent customers as grid
                recentCustomersGrid
            }
        }
        .padding(.vertical, 12)
    }
    
    private func selectedCustomerCard(_ customer: LedgerEntry) -> some View {
        Button {
            viewModel.selectedCustomer = nil
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(customer.customer?.name.prefix(1).uppercased() ?? "?")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(customer.customer?.displayName ?? "Unknown")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    if let phone = customer.customer?.phone {
                        Text(phone)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
    }
    
    private var recentCustomersGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Add new customer button
                Button {
                    showingCustomerPicker = true
                } label: {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.title2.bold())
                                    .foregroundStyle(Color.accentColor)
                            )
                        
                        Text(appState.localized("New", arabic: "جديد"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 72)
                }
                
                // Recent customers
                ForEach(viewModel.recentCustomers.prefix(6)) { customer in
                    Button {
                        viewModel.selectedCustomer = customer
                    } label: {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Text(customer.customer?.name.prefix(1).uppercased() ?? "?")
                                        .font(.headline.bold())
                                        .foregroundStyle(Color.accentColor)
                                )
                            
                            Text(customer.customer?.name.components(separatedBy: " ").first ?? "")
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        .frame(width: 72)
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 90)
    }
    
    // MARK: - Number Pad
    private var numberPad: some View {
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
        
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "⌫"], id: \.self) { key in
                Button {
                    handleKeyPress(key)
                } label: {
                    Text(key)
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    private func handleKeyPress(_ key: String) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        if key == "⌫" {
            if !viewModel.amountString.isEmpty {
                viewModel.amountString.removeLast()
            }
        } else if key == "." {
            if !viewModel.amountString.contains(".") {
                viewModel.amountString += viewModel.amountString.isEmpty ? "0." : "."
            }
        } else {
            // Limit decimal places to 2
            if let dotIndex = viewModel.amountString.firstIndex(of: ".") {
                let decimals = viewModel.amountString.distance(from: dotIndex, to: viewModel.amountString.endIndex) - 1
                if decimals >= 2 { return }
            }
            // Limit total length
            if viewModel.amountString.count >= 8 { return }
            
            viewModel.amountString += key
        }
    }
    
    // MARK: - Add Button
    private var addButton: some View {
        Button {
            saveBill()
        } label: {
            HStack(spacing: 12) {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                    
                    Text(appState.localized("Add to Ledger", arabic: "أضف للدفتر"))
                        .font(.headline)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(canSave ? Color.accentColor : Color(.systemGray4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(!canSave || viewModel.isSaving)
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var canSave: Bool {
        viewModel.selectedCustomer != nil && viewModel.total > 0
    }
    
    // MARK: - Success View
    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Success checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            
            Text(appState.localized("Added!", arabic: "تمت الإضافة!"))
                .font(.title.bold())
            
            if let bill = createdBill {
                VStack(spacing: 8) {
                    Text("QR \(bill.totalAmount.formatted(.number.precision(.fractionLength(0))))")
                        .font(.title2.monospacedDigit())
                    
                    Text(viewModel.selectedCustomer?.customer?.displayName ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 12) {
                // WhatsApp share button
                if let phone = viewModel.selectedCustomer?.customer?.phone {
                    Button {
                        shareViaWhatsApp(phone: phone)
                    } label: {
                        HStack {
                            Image(systemName: "message.fill")
                            Text(appState.localized("Send via WhatsApp", arabic: "إرسال عبر واتساب"))
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                
                // Add another button
                Button {
                    resetForNewBill()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(appState.localized("Add Another", arabic: "إضافة أخرى"))
                    }
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Done button
                Button {
                    onBillCreated?(createdBill)
                    dismiss()
                } label: {
                    Text(appState.localized("Done", arabic: "تم"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
            .padding()
        }
        .transition(.opacity.combined(with: .scale))
    }
    
    // MARK: - Actions
    
    private func saveBill() {
        guard let customer = viewModel.selectedCustomer,
              let storeId = authManager.storeProfile?.id,
              viewModel.total > 0 else { return }
        
        viewModel.isSaving = true
        
        let billTotal = viewModel.total
        
        // Check if demo mode - use local storage
        if authManager.isDemoMode {
            let bill = DemoData.shared.createBill(
                storeId: storeId,
                customerId: customer.customerId,
                items: viewModel.items.isEmpty ? [] : viewModel.items,
                total: billTotal,
                store: authManager.storeProfile
            )
            
            viewModel.isSaving = false
            createdBill = bill
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showSuccess = true
            }
        } else {
            // Use real API
            Task {
                do {
                    let bill: Bill
                    if viewModel.items.isEmpty {
                        // Quick bill - just amount
                        bill = try await APIClient.shared.createQuickBill(
                            customerId: customer.customerId,
                            total: billTotal
                        )
                    } else {
                        // Detailed bill with items
                        bill = try await APIClient.shared.createBill(
                            customerId: customer.customerId,
                            items: viewModel.items,
                            total: billTotal
                        )
                    }
                    
                    await MainActor.run {
                        viewModel.isSaving = false
                        createdBill = bill
                        
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showSuccess = true
                        }
                    }
                } catch {
                    await MainActor.run {
                        viewModel.isSaving = false
                        viewModel.error = error.localizedDescription
                    }
                }
            }
        }
    }
    
    private func shareViaWhatsApp(phone: String) {
        let storeName = authManager.storeProfile?.displayName ?? "Store"
        let amount = viewModel.amount.formatted(.number.precision(.fractionLength(2)))
        let message = """
        New bill from \(storeName)
        Amount: QR \(amount)
        
        فاتورة جديدة من \(storeName)
        المبلغ: \(amount) ر.ق
        """
        
        // Clean phone number
        let cleanPhone = phone.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "+", with: "")
            .replacingOccurrences(of: "-", with: "")
        
        if let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://wa.me/\(cleanPhone)?text=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func resetForNewBill() {
        viewModel.amountString = ""
        viewModel.items = []
        viewModel.selectedCustomer = nil
        createdBill = nil
        showSuccess = false
    }
}

// MARK: - Scan Bill View Model
@MainActor
final class ScanBillViewModel: ObservableObject {
    @Published var amountString = ""
    @Published var items: [BillItem] = []
    @Published var selectedCustomer: LedgerEntry?
    @Published var recentCustomers: [LedgerEntry] = []
    @Published var isSaving = false
    @Published var isLoadingCustomers = false
    @Published var error: String?
    
    private var isDemoMode: Bool {
        UserDefaults.standard.bool(forKey: "is_demo_mode")
    }
    
    var amount: FlexDecimal {
        FlexDecimal(string: amountString)
    }
    
    var total: FlexDecimal {
        if items.isEmpty {
            return amount
        }
        return items.reduce(0) { $0 + $1.totalPrice }
    }
    
    func loadRecentCustomers(storeId: UUID?) {
        guard let storeId else { return }
        
        if isDemoMode {
            recentCustomers = DemoData.shared.getCustomersForStore(storeId: storeId)
        } else {
            loadFromAPI()
        }
    }
    
    private func loadFromAPI() {
        isLoadingCustomers = true
        
        Task {
            do {
                let entries = try await APIClient.shared.getStoreLedger()
                await MainActor.run {
                    // Sort by last activity to show most recent first
                    self.recentCustomers = entries.sorted { $0.lastActivityAt > $1.lastActivityAt }
                    self.isLoadingCustomers = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingCustomers = false
                    // Fall back to demo data on error
                    print("API error loading customers, using demo data: \(error)")
                }
            }
        }
    }
    
    func addNewCustomer(name: String, phone: String, storeId: UUID) async -> LedgerEntry? {
        if isDemoMode {
            return DemoData.shared.addCustomer(name: name, phone: phone, storeId: storeId)
        } else {
            do {
                let entry = try await APIClient.shared.addCustomerToStore(name: name, phone: phone)
                await MainActor.run {
                    self.recentCustomers.insert(entry, at: 0)
                }
                return entry
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
                return nil
            }
        }
    }
}

// MARK: - Detailed Bill Entry View
struct DetailedBillEntryView: View {
    @ObservedObject var viewModel: ScanBillViewModel
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var showingAddItem = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Total header
                VStack(spacing: 4) {
                    Text(appState.localized("Total", arabic: "المجموع"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("QR \(viewModel.total.formatted(.number.precision(.fractionLength(2))))")
                        .font(.title.bold().monospacedDigit())
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))
                
                if viewModel.items.isEmpty {
                    emptyState
                } else {
                    itemsList
                }
            }
            .navigationTitle(appState.localized("Bill Items", arabic: "عناصر الفاتورة"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.localized("Cancel", arabic: "إلغاء")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(appState.localized("Save", arabic: "حفظ")) {
                        // Sync the amount string to reflect items total
                        if !viewModel.items.isEmpty {
                            let itemsTotal = viewModel.items.reduce(FlexDecimal.zero) { $0 + $1.totalPrice }
                            viewModel.amountString = "\(itemsTotal)"
                        }
                        dismiss()
                        // Delay onSave slightly so the sheet dismisses first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSave()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.items.isEmpty && viewModel.amount == 0)
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemSheet { item in
                    let billItem = BillItem(
                        id: UUID(),
                        productId: nil,
                        name: item.name,
                        nameAr: nil,
                        imageUrl: nil,
                        quantity: item.quantity,
                        unitPrice: item.unitPrice,
                        totalPrice: item.totalPrice,
                        product: nil
                    )
                    viewModel.items.append(billItem)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "basket")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text(appState.localized("No items added", arabic: "لم تتم إضافة عناصر"))
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Button {
                showingAddItem = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(appState.localized("Add Item", arabic: "إضافة عنصر"))
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .clipShape(Capsule())
            }
            
            Spacer()
        }
    }
    
    private var itemsList: some View {
        List {
            ForEach(viewModel.items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.subheadline)
                        
                        Text("× \(item.quantity.formatted()) @ QR \(item.unitPrice.formatted())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("QR \(item.totalPrice.formatted(.number.precision(.fractionLength(2))))")
                        .font(.subheadline.monospacedDigit())
                }
            }
            .onDelete { indexSet in
                viewModel.items.remove(atOffsets: indexSet)
            }
            
            Button {
                showingAddItem = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                    Text(appState.localized("Add Item", arabic: "إضافة عنصر"))
                }
            }
        }
    }
}

// MARK: - Customer Picker View
struct CustomerPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @Binding var selectedCustomer: LedgerEntry?
    let storeId: UUID
    
    @State private var searchText = ""
    @State private var customers: [LedgerEntry] = []
    @State private var showingAddCustomer = false
    @State private var newCustomerName = ""
    @State private var newCustomerPhone = ""
    
    var body: some View {
        NavigationStack {
            List {
                // Add new customer
                Section {
                    Button {
                        showingAddCustomer = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                            
                            Text(appState.localized("Add new customer", arabic: "إضافة عميل جديد"))
                        }
                    }
                }
                
                // Existing customers
                Section {
                    ForEach(filteredCustomers) { customer in
                        Button {
                            selectedCustomer = customer
                            dismiss()
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(customer.customer?.name.prefix(1).uppercased() ?? "?")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(Color.accentColor)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(customer.customer?.displayName ?? "Unknown")
                                        .foregroundStyle(.primary)
                                    
                                    if let phone = customer.customer?.phone {
                                        Text(phone)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if selectedCustomer?.customerId == customer.customerId {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: appState.localized("Search customers", arabic: "بحث عن عميل"))
            .navigationTitle(appState.localized("Select Customer", arabic: "اختر العميل"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.localized("Cancel", arabic: "إلغاء")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                customers = DemoData.shared.getCustomersForStore(storeId: storeId)
            }
            .alert(appState.localized("New Customer", arabic: "عميل جديد"), isPresented: $showingAddCustomer) {
                TextField(appState.localized("Name", arabic: "الاسم"), text: $newCustomerName)
                TextField(appState.localized("Phone", arabic: "الهاتف"), text: $newCustomerPhone)
                    .keyboardType(.phonePad)
                
                Button(appState.localized("Add", arabic: "إضافة")) {
                    addNewCustomer()
                }
                Button(appState.localized("Cancel", arabic: "إلغاء"), role: .cancel) {}
            }
        }
    }
    
    private var filteredCustomers: [LedgerEntry] {
        if searchText.isEmpty {
            return customers
        }
        return customers.filter {
            $0.customer?.name.localizedCaseInsensitiveContains(searchText) ?? false ||
            $0.customer?.phone?.contains(searchText) ?? false
        }
    }
    
    private func addNewCustomer() {
        let entry = DemoData.shared.addCustomer(
            name: newCustomerName,
            phone: newCustomerPhone,
            storeId: storeId
        )
        customers.append(entry)
        selectedCustomer = entry
        newCustomerName = ""
        newCustomerPhone = ""
        dismiss()
    }
}

// MARK: - Bill Item Row
struct BillItemRow: View {
    let item: BillItem
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 12) {
            // Product image or placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "basket.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                )
            
            // Name & quantity
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.language == .arabic ? (item.nameAr ?? item.name) : item.name)
                    .font(.subheadline)
                    .lineLimit(2)
                
                Text("× \(item.quantity.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Price
            Text("QR \(item.totalPrice.formatted(.number.precision(.fractionLength(2))))")
                .font(.subheadline.monospacedDigit())
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Quick Item
struct QuickItem: Identifiable {
    let id = UUID()
    var name: String
    var quantity: FlexDecimal
    var unitPrice: FlexDecimal
    var totalPrice: FlexDecimal { quantity * unitPrice }
}

// MARK: - Add Item Sheet
struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    let onAdd: (QuickItem) -> Void
    
    @State private var name = ""
    @State private var quantity = "1"
    @State private var price = ""
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, quantity, price
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(appState.localized("Item name", arabic: "اسم العنصر"), text: $name)
                        .focused($focusedField, equals: .name)
                    
                    HStack {
                        Text(appState.localized("Quantity", arabic: "الكمية"))
                        Spacer()
                        TextField("1", text: $quantity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .focused($focusedField, equals: .quantity)
                    }
                    
                    HStack {
                        Text(appState.localized("Price (QR)", arabic: "السعر (ر.ق)"))
                        Spacer()
                        TextField("0.00", text: $price)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .focused($focusedField, equals: .price)
                    }
                }
                
                // Quick amounts
                Section(appState.localized("Quick amounts", arabic: "مبالغ سريعة")) {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach([5, 10, 25, 50, 100, 200, 500, 1000], id: \.self) { amount in
                            Button {
                                price = "\(amount)"
                            } label: {
                                Text("\(amount)")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(appState.localized("Add Item", arabic: "إضافة عنصر"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.localized("Cancel", arabic: "إلغاء")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(appState.localized("Add", arabic: "إضافة")) {
                        addItem()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty || price.isEmpty)
                }
            }
            .onAppear {
                focusedField = .name
            }
        }
    }
    
    private func addItem() {
        let priceValue = FlexDecimal(string: price)
        let quantityValue = FlexDecimal(string: quantity)
        
        onAdd(QuickItem(
            name: name,
            quantity: quantityValue,
            unitPrice: priceValue
        ))
        dismiss()
    }
}

#Preview {
    ScanBillView(preselectedCustomer: nil)
        .environmentObject(AppState())
        .environmentObject(AuthManager())
}
