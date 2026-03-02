//
//  DemoData.swift
//  daftar
//
//  Demo data for testing without backend
//

import Foundation

/// Manages demo data for testing
final class DemoData {
    static let shared = DemoData()
    
    private init() {
        loadData()
        loadReminders()
    }
    
    // MARK: - Demo Stores
    
    /// Pre-configured demo stores that can be joined
    let demoStores: [String: StoreProfile] = [
        "BAQALA": StoreProfile(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Baqala",
            nameAr: "بقالة",
            phone: "+974 5555 1234",
            address: "Al Sadd, Doha",
            logoUrl: nil,
            joinCode: "BAQALA",
            createdAt: Date()
        ),
        "MEERA1": StoreProfile(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "Al Meera",
            nameAr: "الميرة",
            phone: "+974 5555 5678",
            address: "West Bay, Doha",
            logoUrl: nil,
            joinCode: "MEERA1",
            createdAt: Date()
        ),
        "LULU01": StoreProfile(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "LuLu Hypermarket",
            nameAr: "لولو هايبرماركت",
            phone: "+974 5555 9012",
            address: "Al Gharafa, Doha",
            logoUrl: nil,
            joinCode: "LULU01",
            createdAt: Date()
        )
    ]
    
    // MARK: - Customer's Joined Stores
    
    private let joinedStoresKey = "customer_joined_stores"
    private(set) var joinedStores: [CustomerLedger] = []
    
    // MARK: - Store's Customers
    
    private let storeCustomersKey = "store_customers"
    private(set) var storeCustomers: [LedgerEntry] = []
    
    // MARK: - Bills
    
    private let billsKey = "demo_bills"
    private(set) var bills: [Bill] = []
    
    // MARK: - Load/Save
    
    private func loadData() {
        // Load joined stores
        if let data = UserDefaults.standard.data(forKey: joinedStoresKey),
           let stores = try? JSONDecoder().decode([CustomerLedger].self, from: data) {
            joinedStores = stores
        }
        
        // Load store customers
        if let data = UserDefaults.standard.data(forKey: storeCustomersKey),
           let customers = try? JSONDecoder().decode([LedgerEntry].self, from: data) {
            storeCustomers = customers
        }
        
        // Load bills
        if let data = UserDefaults.standard.data(forKey: billsKey),
           let loadedBills = try? JSONDecoder().decode([Bill].self, from: data) {
            bills = loadedBills
        }
    }
    
    private func saveJoinedStores() {
        if let data = try? JSONEncoder().encode(joinedStores) {
            UserDefaults.standard.set(data, forKey: joinedStoresKey)
        }
    }
    
    private func saveStoreCustomers() {
        if let data = try? JSONEncoder().encode(storeCustomers) {
            UserDefaults.standard.set(data, forKey: storeCustomersKey)
        }
    }
    
    private func saveBills() {
        if let data = try? JSONEncoder().encode(bills) {
            UserDefaults.standard.set(data, forKey: billsKey)
        }
    }
    
    // MARK: - Customer Actions
    
    /// Join a store by code
    func joinStore(code: String, customerId: UUID) -> StoreProfile? {
        guard let store = demoStores[code.uppercased()] else {
            return nil
        }
        
        // Check if already joined
        if joinedStores.contains(where: { $0.storeId == store.id }) {
            return store
        }
        
        // Add to joined stores
        let ledger = CustomerLedger(
            storeId: store.id,
            customerId: customerId,
            totalOwed: 0,
            lastActivityAt: Date(),
            store: store
        )
        joinedStores.append(ledger)
        saveJoinedStores()
        
        return store
    }
    
    /// Get bills from a specific store for customer
    func getBillsForCustomer(storeId: UUID, customerId: UUID) -> [Bill] {
        return bills.filter { $0.storeId == storeId && $0.customerId == customerId }
    }
    
    /// Get pending bills count for customer
    func getPendingBillsCount(customerId: UUID) -> Int {
        return bills.filter { $0.customerId == customerId && $0.status == .pending }.count
    }
    
    // MARK: - Store Actions
    
    /// Add a customer to the store
    func addCustomer(name: String, phone: String, storeId: UUID) -> LedgerEntry {
        let customer = CustomerProfile(
            id: UUID(),
            name: name,
            nameAr: nil,
            phone: phone,
            createdAt: Date()
        )
        
        let entry = LedgerEntry(
            storeId: storeId,
            customerId: customer.id,
            totalOwed: 0,
            lastActivityAt: Date(),
            customer: customer
        )
        
        storeCustomers.append(entry)
        saveStoreCustomers()
        
        return entry
    }
    
    /// Get all customers for a store
    func getCustomersForStore(storeId: UUID) -> [LedgerEntry] {
        return storeCustomers.filter { $0.storeId == storeId }
    }
    
    /// Get bills for a customer (store view)
    func getBillsForStoreCustomer(storeId: UUID, customerId: UUID) -> [Bill] {
        return bills.filter { $0.storeId == storeId && $0.customerId == customerId }
    }
    
    /// Create a new bill
    func createBill(storeId: UUID, customerId: UUID, items: [BillItem], total: Decimal, store: StoreProfile?) -> Bill {
        let bill = Bill(
            id: UUID(),
            storeId: storeId,
            customerId: customerId,
            items: items,
            totalAmount: total,
            status: .pending,
            receiptImageUrl: nil,
            notes: nil,
            createdAt: Date(),
            paidAt: nil,
            store: store,
            customer: nil
        )
        
        bills.append(bill)
        saveBills()
        
        // Update ledger totals
        if let index = storeCustomers.firstIndex(where: { $0.storeId == storeId && $0.customerId == customerId }) {
            storeCustomers[index].totalOwed += total
            storeCustomers[index].lastActivityAt = Date()
            saveStoreCustomers()
        }
        
        if let index = joinedStores.firstIndex(where: { $0.storeId == storeId && $0.customerId == customerId }) {
            joinedStores[index].totalOwed += total
            joinedStores[index].lastActivityAt = Date()
            saveJoinedStores()
        }
        
        return bill
    }
    
    /// Update bill status
    func updateBillStatus(billId: UUID, status: BillStatus) -> Bill? {
        guard let index = bills.firstIndex(where: { $0.id == billId }) else {
            return nil
        }
        
        let oldStatus = bills[index].status
        bills[index].status = status
        
        if status == .paid {
            bills[index].paidAt = Date()
        } else {
            bills[index].paidAt = nil
        }
        
        // Update ledger totals
        let bill = bills[index]
        if oldStatus == .pending && status == .paid {
            // Reduce owed amount
            if let idx = storeCustomers.firstIndex(where: { $0.storeId == bill.storeId && $0.customerId == bill.customerId }) {
                storeCustomers[idx].totalOwed -= bill.totalAmount
                saveStoreCustomers()
            }
            if let idx = joinedStores.firstIndex(where: { $0.storeId == bill.storeId && $0.customerId == bill.customerId }) {
                joinedStores[idx].totalOwed -= bill.totalAmount
                saveJoinedStores()
            }
        } else if oldStatus == .paid && status == .pending {
            // Increase owed amount
            if let idx = storeCustomers.firstIndex(where: { $0.storeId == bill.storeId && $0.customerId == bill.customerId }) {
                storeCustomers[idx].totalOwed += bill.totalAmount
                saveStoreCustomers()
            }
            if let idx = joinedStores.firstIndex(where: { $0.storeId == bill.storeId && $0.customerId == bill.customerId }) {
                joinedStores[idx].totalOwed += bill.totalAmount
                saveJoinedStores()
            }
        }
        
        saveBills()
        return bills[index]
    }
    
    // MARK: - Reminders
    
    private let remindersKey = "demo_reminders"
    private(set) var reminders: [Reminder] = []
    
    func getReminders(storeId: UUID) -> [Reminder] {
        return reminders.filter { $0.storeId == storeId }
    }
    
    func getReminderForCustomer(storeId: UUID, customerId: UUID) -> Reminder? {
        return reminders.first { $0.storeId == storeId && $0.customerId == customerId }
    }
    
    func setReminder(storeId: UUID, customerId: UUID, type: ReminderType, daysInterval: Int?, balanceThreshold: Decimal?, customerName: String?) -> Reminder {
        // Remove existing reminder for this pair
        reminders.removeAll { $0.storeId == storeId && $0.customerId == customerId }
        
        let nextDate: Date
        if let days = daysInterval {
            nextDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        } else {
            nextDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        }
        
        let reminder = Reminder(
            id: UUID(),
            storeId: storeId,
            customerId: customerId,
            type: type,
            daysInterval: daysInterval,
            balanceThreshold: balanceThreshold,
            nextReminderDate: nextDate,
            isActive: true,
            customerName: customerName
        )
        reminders.append(reminder)
        saveReminders()
        return reminder
    }
    
    func removeReminder(storeId: UUID, customerId: UUID) {
        reminders.removeAll { $0.storeId == storeId && $0.customerId == customerId }
        saveReminders()
    }
    
    private func saveReminders() {
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: remindersKey)
        }
    }
    
    private func loadReminders() {
        if let data = UserDefaults.standard.data(forKey: remindersKey),
           let loaded = try? JSONDecoder().decode([Reminder].self, from: data) {
            reminders = loaded
        }
    }
    
    // MARK: - Staff (Mock)
    
    func getMockStaff(storeId: UUID) -> [StaffMember] {
        return [
            StaffMember(id: UUID(), storeId: storeId, name: "Mohammed", nameAr: "محمد", phone: "+974 5551 0001", role: .manager, isActive: true, createdAt: Date().addingTimeInterval(-86400 * 30)),
            StaffMember(id: UUID(), storeId: storeId, name: "Ali", nameAr: "علي", phone: "+974 5551 0002", role: .cashier, isActive: true, createdAt: Date().addingTimeInterval(-86400 * 14)),
            StaffMember(id: UUID(), storeId: storeId, name: "Fatima", nameAr: "فاطمة", phone: "+974 5551 0003", role: .viewer, isActive: false, createdAt: Date().addingTimeInterval(-86400 * 7)),
        ]
    }
    
    func getMockBranches(storeId: UUID) -> [StoreBranch] {
        return [
            StoreBranch(id: UUID(), storeId: storeId, name: "Main Branch", nameAr: "الفرع الرئيسي", address: "Al Sadd, Doha", isMain: true),
            StoreBranch(id: UUID(), storeId: storeId, name: "West Bay", nameAr: "الخليج الغربي", address: "West Bay, Doha", isMain: false),
        ]
    }
    
    // MARK: - Store Discovery (Mock)
    
    func getDirectoryStores(query: String = "") -> [DirectoryStore] {
        let allStores: [DirectoryStore] = [
            DirectoryStore(id: UUID(), name: "Al Meera", nameAr: "الميرة", address: "Al Sadd, Doha", category: "Supermarket", distance: 0.5, joinCode: "MEERA1", customerCount: 342, rating: 4.5),
            DirectoryStore(id: UUID(), name: "LuLu Hypermarket", nameAr: "لولو هايبرماركت", address: "Al Gharafa, Doha", category: "Hypermarket", distance: 2.1, joinCode: "LULU01", customerCount: 1205, rating: 4.3),
            DirectoryStore(id: UUID(), name: "Baqala Corner", nameAr: "بقالة الزاوية", address: "Bin Mahmoud, Doha", category: "Baqala", distance: 0.2, joinCode: "BAQALA", customerCount: 87, rating: 4.8),
            DirectoryStore(id: UUID(), name: "Family Food Centre", nameAr: "مركز غذاء العائلة", address: "Al Wakrah", category: "Supermarket", distance: 8.3, joinCode: "FFC001", customerCount: 521, rating: 4.1),
            DirectoryStore(id: UUID(), name: "Spar Market", nameAr: "سبار ماركت", address: "The Pearl, Doha", category: "Supermarket", distance: 3.7, joinCode: "SPAR01", customerCount: 198, rating: 4.4),
            DirectoryStore(id: UUID(), name: "Abu Khalil Baqala", nameAr: "بقالة أبو خليل", address: "Old Airport Rd, Doha", category: "Baqala", distance: 1.8, joinCode: "ABU001", customerCount: 45, rating: 4.9),
            DirectoryStore(id: UUID(), name: "Carrefour Express", nameAr: "كارفور إكسبريس", address: "Lusail, Doha", category: "Supermarket", distance: 5.2, joinCode: "CRF001", customerCount: 890, rating: 4.2),
        ]
        
        if query.isEmpty { return allStores.sorted { ($0.distance ?? 99) < ($1.distance ?? 99) } }
        return allStores.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.nameAr?.localizedCaseInsensitiveContains(query) == true ||
            $0.category?.localizedCaseInsensitiveContains(query) == true ||
            $0.address?.localizedCaseInsensitiveContains(query) == true
        }.sorted { ($0.distance ?? 99) < ($1.distance ?? 99) }
    }
    
    // MARK: - Analytics (Mock)
    
    func getAnalytics(storeId: UUID) -> AnalyticsSummary {
        let customers = getCustomersForStore(storeId: storeId)
        let storeBills = bills.filter { $0.storeId == storeId }
        let paidBills = storeBills.filter { $0.status == .paid }
        let totalRevenue = paidBills.reduce(Decimal.zero) { $0 + $1.totalAmount }
        let totalOutstanding = customers.reduce(Decimal.zero) { $0 + $1.totalOwed }
        let avgBill = storeBills.isEmpty ? Decimal.zero : storeBills.reduce(Decimal.zero) { $0 + $1.totalAmount } / Decimal(storeBills.count)
        let collectionRate = storeBills.isEmpty ? 0.0 : Double(paidBills.count) / Double(storeBills.count) * 100.0
        
        let topCusts: [TopCustomer] = customers.prefix(5).map { entry in
            let custBills = storeBills.filter { $0.customerId == entry.customerId }
            return TopCustomer(
                id: entry.customerId,
                name: entry.customer?.displayName ?? "Unknown",
                totalSpent: custBills.reduce(Decimal.zero) { $0 + $1.totalAmount },
                billCount: custBills.count
            )
        }.sorted { $0.totalSpent > $1.totalSpent }
        
        // Generate mock daily revenue for last 7 days
        let calendar = Calendar.current
        let revenueByDay: [DailyRevenue] = (0..<7).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
            let dateStr = date.formatted(.dateTime.month(.abbreviated).day())
            // Mock: distribute revenue across days
            let dayAmount = totalRevenue > 0 ? totalRevenue / 7 * Decimal(Double.random(in: 0.5...1.5)) : Decimal(Double.random(in: 50...500))
            return DailyRevenue(date: dateStr, amount: dayAmount)
        }
        
        return AnalyticsSummary(
            totalRevenue: totalRevenue > 0 ? totalRevenue : Decimal(2450),
            totalOutstanding: totalOutstanding,
            totalCustomers: customers.count > 0 ? customers.count : 12,
            totalBills: storeBills.count > 0 ? storeBills.count : 47,
            averageBillSize: avgBill > 0 ? avgBill : Decimal(52),
            topCustomers: topCusts.isEmpty ? [
                TopCustomer(id: UUID(), name: "Ahmed", totalSpent: 820, billCount: 15),
                TopCustomer(id: UUID(), name: "Mohammed", totalSpent: 650, billCount: 12),
                TopCustomer(id: UUID(), name: "Fatima", totalSpent: 410, billCount: 8),
            ] : topCusts,
            revenueByDay: revenueByDay,
            collectionRate: collectionRate > 0 ? collectionRate : 73.5
        )
    }
    
    // MARK: - Mock Payment
    
    func processPayment(storeId: UUID, customerId: UUID, amount: Decimal, method: PaymentMethod) -> Payment {
        let payment = Payment(
            id: UUID(),
            storeId: storeId,
            customerId: customerId,
            amount: amount,
            method: method,
            status: .completed,
            createdAt: Date()
        )
        
        // Reduce outstanding balance
        if let idx = storeCustomers.firstIndex(where: { $0.storeId == storeId && $0.customerId == customerId }) {
            storeCustomers[idx].totalOwed = max(0, storeCustomers[idx].totalOwed - amount)
            saveStoreCustomers()
        }
        if let idx = joinedStores.firstIndex(where: { $0.storeId == storeId && $0.customerId == customerId }) {
            joinedStores[idx].totalOwed = max(0, joinedStores[idx].totalOwed - amount)
            saveJoinedStores()
        }
        
        // Mark bills as paid up to the amount
        var remaining = amount
        let pendingBills = bills.filter { $0.storeId == storeId && $0.customerId == customerId && $0.status == .pending }
            .sorted { $0.createdAt < $1.createdAt }
        for bill in pendingBills {
            if remaining <= 0 { break }
            if bill.totalAmount <= remaining {
                _ = updateBillStatus(billId: bill.id, status: .paid)
                remaining -= bill.totalAmount
            }
        }
        
        return payment
    }
    
    // MARK: - Overdue Customers
    
    func getOverdueCustomers(storeId: UUID, overdueDays: Int = 7) -> [LedgerEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -overdueDays, to: Date()) ?? Date()
        return getCustomersForStore(storeId: storeId).filter {
            $0.totalOwed > 0 && $0.lastActivityAt < cutoff
        }.sorted { $0.totalOwed > $1.totalOwed }
    }
    
    // MARK: - Reset
    
    func resetAllData() {
        joinedStores = []
        storeCustomers = []
        bills = []
        reminders = []
        UserDefaults.standard.removeObject(forKey: joinedStoresKey)
        UserDefaults.standard.removeObject(forKey: storeCustomersKey)
        UserDefaults.standard.removeObject(forKey: billsKey)
        UserDefaults.standard.removeObject(forKey: remindersKey)
    }
}
