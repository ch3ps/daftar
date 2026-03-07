//
//  StoreMainView.swift
//  daftar
//
//  Speed Mode - Number pad on main screen, instant customer selection
//  Optimized for baqala owners: 3 taps to add a bill + auto WhatsApp
//

import SwiftUI
import PhotosUI
import Combine

struct StoreMainView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = StoreViewModel()
    
    @State private var showingSettings = false
    @State private var showingAnalytics = false
    @State private var showingExport = false
    @State private var showingStaff = false
    @State private var showingAllCustomers = false
    @State private var showingAddCustomer = false
    @State private var selectedCustomerForDetail: LedgerEntry?
    
    // Speed mode states
    @State private var amountString = ""
    @State private var selectedCustomer: LedgerEntry?
    @State private var showSuccess = false
    @State private var isSaving = false
    @State private var createdBill: Bill?
    
    // Handwriting recognition (Option A)
    @State private var showingCamera = false
    @State private var showingHandwritingResult = false
    @State private var handwritingImage: UIImage?
    @State private var isProcessingHandwriting = false
    @State private var extractedName: String = ""
    @State private var extractedAmount: String = ""
    @State private var matchedCustomer: LedgerEntry?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if showSuccess {
                    successView
                } else {
                    speedModeView
                }
            }
            .navigationTitle(authManager.storeProfile?.displayName ?? appState.localized("Store", arabic: "المتجر"))
            .navigationBarTitleDisplayMode(.inline)
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
                    HStack(spacing: 12) {
                        Button {
                            showingAnalytics = true
                        } label: {
                            Image(systemName: "chart.bar.fill")
                                .foregroundStyle(.secondary)
                        }
                        
                        Menu {
                            Button {
                                showingAllCustomers = true
                            } label: {
                                Label(
                                    appState.localized("All Customers", arabic: "جميع العملاء"),
                                    systemImage: "person.3.fill"
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
                            
                            Button {
                                showingStaff = true
                            } label: {
                                Label(
                                    appState.localized("Staff & Branches", arabic: "الموظفين والفروع"),
                                    systemImage: "building.2.fill"
                                )
                            }
                            
                            if let code = authManager.storeProfile?.joinCode {
                                Button {
                                    UIPasteboard.general.string = code
                                    HapticManager.success()
                                } label: {
                                    Label(
                                        appState.localized("Copy Code: \(code)", arabic: "نسخ الرمز: \(code)"),
                                        systemImage: "doc.on.doc"
                                    )
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onAppear {
                viewModel.loadData(storeId: authManager.storeProfile?.id)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingAnalytics) {
                AnalyticsView()
            }
            .sheet(isPresented: $showingExport) {
                ExportView(customers: viewModel.customers)
            }
            .sheet(isPresented: $showingStaff) {
                StaffManagementView()
            }
            .sheet(isPresented: $showingAllCustomers) {
                AllCustomersView(
                    customers: viewModel.customers,
                    overdueCustomers: viewModel.overdueCustomers,
                    onSelectCustomer: { customer in
                        selectedCustomer = customer
                        showingAllCustomers = false
                    },
                    onViewDetail: { customer in
                        selectedCustomerForDetail = customer
                    }
                )
            }
            .sheet(isPresented: $showingAddCustomer) {
                AddCustomerSheet(storeId: authManager.storeProfile?.id ?? UUID()) { entry in
                    viewModel.loadData(storeId: authManager.storeProfile?.id)
                    selectedCustomer = entry
                }
            }
            .sheet(item: $selectedCustomerForDetail) { customer in
                CustomerDetailView(entry: customer) {
                    viewModel.loadData(storeId: authManager.storeProfile?.id)
                }
            }
            .sheet(isPresented: $showingCamera) {
                HandwritingCameraView { image in
                    handwritingImage = image
                    processHandwriting(image)
                }
            }
            .sheet(isPresented: $showingHandwritingResult) {
                HandwritingResultView(
                    image: handwritingImage,
                    extractedName: $extractedName,
                    extractedAmount: $extractedAmount,
                    matchedCustomer: $matchedCustomer,
                    customers: viewModel.customers,
                    isProcessing: isProcessingHandwriting,
                    onConfirm: {
                        if let customer = matchedCustomer {
                            selectedCustomer = customer
                            amountString = extractedAmount
                        }
                        showingHandwritingResult = false
                    },
                    onAddNewCustomer: {
                        showingHandwritingResult = false
                        showingAddCustomer = true
                    }
                )
            }
        }
        .environment(\.layoutDirection, appState.layoutDirection)
    }
    
    // MARK: - Speed Mode View (Main Interface)
    private var speedModeView: some View {
        VStack(spacing: 0) {
            // Total header (compact)
            totalHeaderCompact
            
            // Customer selection row
            customerSelectionRow
            
            // Amount display
            amountDisplay
            
            // Number pad
            numberPad
            
            // Action buttons
            actionButtons
        }
    }
    
    // MARK: - Total Header (Compact)
    private var totalHeaderCompact: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.localized("Total Owed", arabic: "إجمالي المستحق"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("QR")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(viewModel.totalOwed.formatted(.number.precision(.fractionLength(0))))
                        .font(.title2.bold().monospacedDigit())
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(viewModel.customers.count)")
                    .font(.title2.bold().monospacedDigit())
                Text(appState.localized("customers", arabic: "عميل"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Customer Selection Row
    private var customerSelectionRow: some View {
        VStack(spacing: 8) {
            // Selected customer or prompt
            if let customer = selectedCustomer {
                selectedCustomerBanner(customer)
            } else {
                // Quick select recent customers
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        // Camera button for handwriting
                        Button {
                            HapticManager.mediumTap()
                            showingCamera = true
                        } label: {
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.title3)
                                            .foregroundStyle(.orange)
                                    )
                                Text(appState.localized("Photo", arabic: "صورة"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Add new customer
                        Button {
                            HapticManager.lightTap()
                            showingAddCustomer = true
                        } label: {
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.15))
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        Image(systemName: "plus")
                                            .font(.title3.bold())
                                            .foregroundStyle(Color.accentColor)
                                    )
                                Text(appState.localized("New", arabic: "جديد"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Recent customers (top 8)
                        ForEach(viewModel.customers.prefix(8)) { customer in
                            Button {
                                HapticManager.selectionChanged()
                                selectedCustomer = customer
                            } label: {
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.15))
                                        .frame(width: 56, height: 56)
                                        .overlay(
                                            Text(customer.customer?.name.prefix(1).uppercased() ?? "?")
                                                .font(.headline.bold())
                                                .foregroundStyle(Color.accentColor)
                                        )
                                    
                                    Text(customer.customer?.name.components(separatedBy: " ").first ?? "")
                                        .font(.caption2)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                                .frame(width: 60)
                            }
                        }
                        
                        // Show all button
                        if viewModel.customers.count > 8 {
                            Button {
                                showingAllCustomers = true
                            } label: {
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(.systemGray5))
                                        .frame(width: 56, height: 56)
                                        .overlay(
                                            Text("+\(viewModel.customers.count - 8)")
                                                .font(.subheadline.bold())
                                                .foregroundStyle(.secondary)
                                        )
                                    Text(appState.localized("More", arabic: "المزيد"))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .frame(height: 100)
        .background(Color(.systemBackground))
    }
    
    private func selectedCustomerBanner(_ customer: LedgerEntry) -> some View {
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
                
                if customer.totalOwed > 0 {
                    Text("QR \(customer.totalOwed.formatted(.number.precision(.fractionLength(0)))) " + appState.localized("owed", arabic: "مستحق"))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            
            Spacer()
            
            Button {
                HapticManager.lightTap()
                selectedCustomer = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    // MARK: - Amount Display
    private var amountDisplay: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("QR")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                
                Text(amountString.isEmpty ? "0" : amountString)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Number Pad
    private var numberPad: some View {
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
        
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "⌫"], id: \.self) { key in
                Button {
                    handleKeyPress(key)
                } label: {
                    Text(key)
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    private func handleKeyPress(_ key: String) {
        HapticManager.lightTap()
        
        if key == "⌫" {
            if !amountString.isEmpty {
                amountString.removeLast()
            }
        } else if key == "." {
            if !amountString.contains(".") {
                amountString += amountString.isEmpty ? "0." : "."
            }
        } else {
            if let dotIndex = amountString.firstIndex(of: ".") {
                let decimals = amountString.distance(from: dotIndex, to: amountString.endIndex) - 1
                if decimals >= 2 { return }
            }
            if amountString.count >= 8 { return }
            amountString += key
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 8) {
            // Main add button (Add + Send WhatsApp)
            Button {
                saveBillAndSendWhatsApp()
            } label: {
                HStack(spacing: 12) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "plus.message.fill")
                            .font(.title3)
                        Text(appState.localized("Add + Send", arabic: "إضافة وإرسال"))
                            .font(.headline)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(canSave ? Color.accentColor : Color(.systemGray4))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canSave || isSaving)
            
            // Secondary: Add only (no WhatsApp)
            if canSave {
                Button {
                    saveBillOnly()
                } label: {
                    Text(appState.localized("Add without sending", arabic: "إضافة بدون إرسال"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var canSave: Bool {
        selectedCustomer != nil && (FlexDecimal(string: amountString)) > 0
    }
    
    // MARK: - Success View
    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            
            Text(appState.localized("Added!", arabic: "تمت الإضافة!"))
                .font(.title.bold())
            
            if let bill = createdBill {
                VStack(spacing: 8) {
                    Text("QR \(bill.totalAmount.formatted(.number.precision(.fractionLength(0))))")
                        .font(.title2.monospacedDigit())
                    
                    Text(selectedCustomer?.customer?.displayName ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button {
                    resetForNewBill()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(appState.localized("Add Another", arabic: "إضافة أخرى"))
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                
                Button {
                    resetForNewBill()
                } label: {
                    Text(appState.localized("Done", arabic: "تم"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .transition(.opacity.combined(with: .scale))
    }
    
    // MARK: - Actions
    
    private func saveBillAndSendWhatsApp() {
        let amount = FlexDecimal(string: amountString)
        guard let customer = selectedCustomer,
              let storeId = authManager.storeProfile?.id,
              amount > 0 else { return }
        
        isSaving = true
        
        if authManager.isDemoMode {
            let bill = DemoData.shared.createBill(
                storeId: storeId,
                customerId: customer.customerId,
                items: [],
                total: amount,
                store: authManager.storeProfile
            )
            
            isSaving = false
            createdBill = bill
            HapticManager.success()
            
            // Send WhatsApp
            sendWhatsApp(amount: amount, customer: customer)
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showSuccess = true
            }
        } else {
            Task {
                do {
                    let bill = try await APIClient.shared.createQuickBill(
                        customerId: customer.customerId,
                        total: amount
                    )
                    
                    await MainActor.run {
                        isSaving = false
                        createdBill = bill
                        HapticManager.success()
                        
                        sendWhatsApp(amount: amount, customer: customer)
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showSuccess = true
                        }
                    }
                } catch {
                    await MainActor.run {
                        isSaving = false
                    }
                }
            }
        }
    }
    
    private func saveBillOnly() {
        let amount = FlexDecimal(string: amountString)
        guard let customer = selectedCustomer,
              let storeId = authManager.storeProfile?.id,
              amount > 0 else { return }
        
        isSaving = true
        
        if authManager.isDemoMode {
            let bill = DemoData.shared.createBill(
                storeId: storeId,
                customerId: customer.customerId,
                items: [],
                total: amount,
                store: authManager.storeProfile
            )
            
            isSaving = false
            createdBill = bill
            HapticManager.success()
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showSuccess = true
            }
        } else {
            Task {
                do {
                    let bill = try await APIClient.shared.createQuickBill(
                        customerId: customer.customerId,
                        total: amount
                    )
                    
                    await MainActor.run {
                        isSaving = false
                        createdBill = bill
                        HapticManager.success()
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showSuccess = true
                        }
                    }
                } catch {
                    await MainActor.run {
                        isSaving = false
                    }
                }
            }
        }
    }
    
    private func sendWhatsApp(amount: FlexDecimal, customer: LedgerEntry) {
        let storeName = authManager.storeProfile?.displayName ?? "Store"
        let formattedAmount = amount.formatted(.number.precision(.fractionLength(2)))
        
        let message = """
        📋 \(appState.localized("New bill from", arabic: "فاتورة جديدة من")) \(storeName)
        💰 QR \(formattedAmount)
        
        \(appState.localized("View in Daftar app", arabic: "شاهد في تطبيق دفتر"))
        """
        
        if let phone = customer.customer?.phone {
            let cleanPhone = phone.replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "+", with: "")
                .replacingOccurrences(of: "-", with: "")
            
            if let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "https://wa.me/\(cleanPhone)?text=\(encoded)") {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func resetForNewBill() {
        amountString = ""
        selectedCustomer = nil
        createdBill = nil
        showSuccess = false
        viewModel.loadData(storeId: authManager.storeProfile?.id)
    }
    
    // MARK: - Handwriting Processing (Option A)
    
    private func processHandwriting(_ image: UIImage) {
        isProcessingHandwriting = true
        showingHandwritingResult = true
        
        // Use GPT-4 Vision to extract text from handwriting
        Task {
            do {
                // Upload image first
                let imageUrl = try await APIClient.shared.uploadImage(image)
                
                // Process with handwriting OCR endpoint
                let result = try await APIClient.shared.processHandwritingOCR(imageUrl: imageUrl)
                
                await MainActor.run {
                    extractedName = result.customerName ?? ""
                    extractedAmount = result.amount != nil ? "\(result.amount!)" : ""
                    
                    // Try to match customer
                    matchedCustomer = viewModel.customers.first { customer in
                        guard let name = customer.customer?.name.lowercased() else { return false }
                        return name.contains(extractedName.lowercased()) ||
                               extractedName.lowercased().contains(name)
                    }
                    
                    isProcessingHandwriting = false
                }
            } catch {
                await MainActor.run {
                    // Fallback: just show the image without extraction
                    extractedName = ""
                    extractedAmount = ""
                    matchedCustomer = nil
                    isProcessingHandwriting = false
                }
            }
        }
    }
}

// MARK: - All Customers View
struct AllCustomersView: View {
    let customers: [LedgerEntry]
    let overdueCustomers: [LedgerEntry]
    let onSelectCustomer: (LedgerEntry) -> Void
    let onViewDetail: (LedgerEntry) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            List {
                // Overdue section
                if !overdueCustomers.isEmpty {
                    Section {
                        ForEach(overdueCustomers) { customer in
                            customerRow(customer, isOverdue: true)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(appState.localized("Needs Attention", arabic: "يحتاج اهتمام"))
                        }
                    }
                }
                
                // All customers
                Section {
                    ForEach(filteredCustomers) { customer in
                        customerRow(customer, isOverdue: false)
                    }
                } header: {
                    Text(appState.localized("All Customers", arabic: "جميع العملاء"))
                }
            }
            .searchable(text: $searchText, prompt: appState.localized("Search", arabic: "بحث"))
            .navigationTitle(appState.localized("Customers", arabic: "العملاء"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.localized("Done", arabic: "تم")) {
                        dismiss()
                    }
                }
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
    
    private func customerRow(_ customer: LedgerEntry, isOverdue: Bool) -> some View {
        HStack {
            Button {
                onSelectCustomer(customer)
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill((isOverdue ? Color.orange : Color.accentColor).opacity(0.15))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(customer.customer?.name.prefix(1).uppercased() ?? "?")
                                .font(.headline)
                                .foregroundStyle(isOverdue ? .orange : Color.accentColor)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(customer.customer?.displayName ?? "Unknown")
                            .font(.body)
                            .foregroundStyle(.primary)
                        
                        Text("QR \(customer.totalOwed.formatted(.number.precision(.fractionLength(0))))")
                            .font(.caption)
                            .foregroundStyle(customer.totalOwed > 0 ? .orange : .green)
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            Button {
                onViewDetail(customer)
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Add Customer Sheet
struct AddCustomerSheet: View {
    let storeId: UUID
    let onAdd: (LedgerEntry) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    
    @State private var name = ""
    @State private var phone = "+974 "
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(appState.localized("Name", arabic: "الاسم"), text: $name)
                        .textContentType(.name)
                    
                    TextField(appState.localized("Phone", arabic: "الهاتف"), text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }
                
                Section {
                    Text(appState.localized(
                        "Add customer's name and phone to track their purchases",
                        arabic: "أضف اسم العميل ورقم هاتفه لتتبع مشترياته"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(appState.localized("New Customer", arabic: "عميل جديد"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.localized("Cancel", arabic: "إلغاء")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        addCustomer()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(appState.localized("Add", arabic: "إضافة"))
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }
    
    private func addCustomer() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else { return }
        
        isSaving = true
        
        if authManager.isDemoMode {
            let entry = DemoData.shared.addCustomer(
                name: trimmedName,
                phone: trimmedPhone,
                storeId: storeId
            )
            onAdd(entry)
            dismiss()
        } else {
            Task {
                do {
                    let entry = try await APIClient.shared.addCustomerToStore(
                        name: trimmedName,
                        phone: trimmedPhone
                    )
                    await MainActor.run {
                        onAdd(entry)
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        isSaving = false
                    }
                }
            }
        }
    }
}

// MARK: - Handwriting Camera View
struct HandwritingCameraView: View {
    let onCapture: (UIImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "pencil.and.scribble")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)
                
                Text(appState.localized(
                    "Take a photo of your handwritten note",
                    arabic: "التقط صورة لملاحظتك المكتوبة بخط اليد"
                ))
                .font(.headline)
                .multilineTextAlignment(.center)
                
                Text(appState.localized(
                    "Write the customer name and amount, we'll read it automatically",
                    arabic: "اكتب اسم العميل والمبلغ، سنقرأه تلقائياً"
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                
                // Example
                VStack(spacing: 8) {
                    Text(appState.localized("Example:", arabic: "مثال:"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("أحمد - ٥٠ ريال")
                        .font(.title2)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Spacer()
                
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text(appState.localized("Take Photo", arabic: "التقط صورة"))
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .onChange(of: selectedItem) { oldValue, newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            onCapture(image)
                            dismiss()
                        }
                    }
                }
            }
            .padding()
            .navigationTitle(appState.localized("Handwriting", arabic: "خط اليد"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.localized("Cancel", arabic: "إلغاء")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Handwriting Result View
struct HandwritingResultView: View {
    let image: UIImage?
    @Binding var extractedName: String
    @Binding var extractedAmount: String
    @Binding var matchedCustomer: LedgerEntry?
    let customers: [LedgerEntry]
    let isProcessing: Bool
    let onConfirm: () -> Void
    let onAddNewCustomer: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Image preview
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    if isProcessing {
                        VStack(spacing: 16) {
                            ProgressView()
                            Text(appState.localized("Reading handwriting...", arabic: "جاري قراءة الخط..."))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    } else {
                        // Extracted data
                        VStack(alignment: .leading, spacing: 16) {
                            // Customer name
                            VStack(alignment: .leading, spacing: 8) {
                                Text(appState.localized("Customer Name", arabic: "اسم العميل"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                TextField(appState.localized("Name", arabic: "الاسم"), text: $extractedName)
                                    .textFieldStyle(.roundedBorder)
                                
                                // Customer match
                                if let matched = matchedCustomer {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                        Text(appState.localized("Matched: ", arabic: "تطابق: ") + (matched.customer?.displayName ?? ""))
                                            .font(.caption)
                                    }
                                } else if !extractedName.isEmpty {
                                    HStack {
                                        Image(systemName: "questionmark.circle")
                                            .foregroundStyle(.orange)
                                        Text(appState.localized("Customer not found", arabic: "العميل غير موجود"))
                                            .font(.caption)
                                        
                                        Spacer()
                                        
                                        Button(appState.localized("Add New", arabic: "إضافة جديد")) {
                                            onAddNewCustomer()
                                        }
                                        .font(.caption)
                                    }
                                }
                            }
                            
                            // Amount
                            VStack(alignment: .leading, spacing: 8) {
                                Text(appState.localized("Amount", arabic: "المبلغ"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                HStack {
                                    Text("QR")
                                        .foregroundStyle(.secondary)
                                    TextField("0", text: $extractedAmount)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                            
                            // Customer picker if no match
                            if matchedCustomer == nil && !customers.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(appState.localized("Or select customer:", arabic: "أو اختر العميل:"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(customers.prefix(10)) { customer in
                                                Button {
                                                    matchedCustomer = customer
                                                    if extractedName.isEmpty {
                                                        extractedName = customer.customer?.name ?? ""
                                                    }
                                                } label: {
                                                    VStack(spacing: 4) {
                                                        Circle()
                                                            .fill(Color.accentColor.opacity(0.15))
                                                            .frame(width: 44, height: 44)
                                                            .overlay(
                                                                Text(customer.customer?.name.prefix(1).uppercased() ?? "?")
                                                                    .font(.subheadline.bold())
                                                                    .foregroundStyle(Color.accentColor)
                                                            )
                                                        
                                                        Text(customer.customer?.name.components(separatedBy: " ").first ?? "")
                                                            .font(.caption2)
                                                            .foregroundStyle(.primary)
                                                            .lineLimit(1)
                                                    }
                                                    .frame(width: 56)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(appState.localized("Handwriting Result", arabic: "نتيجة الخط"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.localized("Cancel", arabic: "إلغاء")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.localized("Use", arabic: "استخدم")) {
                        onConfirm()
                    }
                    .fontWeight(.semibold)
                    .disabled(isProcessing || (matchedCustomer == nil && extractedName.isEmpty))
                }
            }
        }
    }
}

// MARK: - Store View Model
@MainActor
final class StoreViewModel: ObservableObject {
    @Published var customers: [LedgerEntry] = []
    @Published var overdueCustomers: [LedgerEntry] = []
    @Published var totalOwed: FlexDecimal = 0
    @Published var isLoading = false
    @Published var error: String?
    
    private var isDemoMode: Bool {
        UserDefaults.standard.bool(forKey: "is_demo_mode")
    }
    
    func loadData(storeId: UUID?) {
        guard let storeId else { return }
        
        if isDemoMode {
            loadDemoData(storeId: storeId)
        } else {
            loadFromAPI(storeId: storeId)
        }
    }
    
    private func loadDemoData(storeId: UUID) {
        isLoading = true
        defer { isLoading = false }
        
        customers = DemoData.shared.getCustomersForStore(storeId: storeId)
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
        totalOwed = customers.reduce(0) { $0 + $1.totalOwed }
        overdueCustomers = DemoData.shared.getOverdueCustomers(storeId: storeId)
    }
    
    private func loadFromAPI(storeId: UUID) {
        isLoading = true
        error = nil
        
        Task {
            do {
                let entries = try await APIClient.shared.getStoreLedger()
                await MainActor.run {
                    self.customers = entries.sorted { $0.lastActivityAt > $1.lastActivityAt }
                    self.totalOwed = entries.reduce(0) { $0 + $1.totalOwed }
                    let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                    self.overdueCustomers = entries.filter { $0.totalOwed > 0 && $0.lastActivityAt < cutoff }
                        .sorted { $0.totalOwed > $1.totalOwed }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    StoreMainView()
        .environmentObject(AppState())
        .environmentObject(AuthManager())
}
