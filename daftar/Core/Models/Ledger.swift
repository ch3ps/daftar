//
//  Ledger.swift
//  daftar
//
//  Core ledger models - the digital دفتر
//

import Foundation

// MARK: - User Type
enum UserType: String, Codable {
    case store = "store"
    case customer = "customer"
}

// MARK: - Bill Status
enum BillStatus: String, Codable, CaseIterable {
    case pending = "pending"      // Awaiting payment
    case paid = "paid"            // Settled
    case disputed = "disputed"    // Customer flagged an issue
    
    var color: String {
        switch self {
        case .pending: return "orange"
        case .paid: return "green"
        case .disputed: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .paid: return "checkmark.circle.fill"
        case .disputed: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Product
struct Product: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var nameAr: String?
    var description: String?
    var imageUrl: String?
    var category: String?
    var defaultPrice: Decimal?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case nameAr = "name_ar"
        case description
        case imageUrl = "image_url"
        case category
        case defaultPrice = "default_price"
    }
}

// MARK: - Bill Item
struct BillItem: Codable, Identifiable, Equatable {
    let id: UUID
    var productId: UUID?
    var name: String
    var nameAr: String?
    var imageUrl: String?
    var quantity: Decimal
    var unitPrice: Decimal
    var totalPrice: Decimal
    
    // Populated from product lookup
    var product: Product?
    
    enum CodingKeys: String, CodingKey {
        case id
        case productId = "product_id"
        case name
        case nameAr = "name_ar"
        case imageUrl = "image_url"
        case quantity
        case unitPrice = "unit_price"
        case totalPrice = "total_price"
        case product
    }
    
    var displayName: String {
        nameAr ?? name
    }
}

// MARK: - Bill
struct Bill: Codable, Identifiable, Equatable {
    let id: UUID
    let storeId: UUID
    let customerId: UUID
    var items: [BillItem]
    var totalAmount: Decimal
    var status: BillStatus
    var receiptImageUrl: String?
    var notes: String?
    let createdAt: Date
    var paidAt: Date?
    
    // Populated from joins
    var store: StoreProfile?
    var customer: CustomerProfile?
    
    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case customerId = "customer_id"
        case items
        case totalAmount = "total_amount"
        case status
        case receiptImageUrl = "receipt_image_url"
        case notes
        case createdAt = "created_at"
        case paidAt = "paid_at"
        case store, customer
    }
}

// MARK: - Store Profile
struct StoreProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var nameAr: String?
    var phone: String?
    var address: String?
    var logoUrl: String?
    var joinCode: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case nameAr = "name_ar"
        case phone, address
        case logoUrl = "logo_url"
        case joinCode = "join_code"
        case createdAt = "created_at"
    }
    
    var displayName: String {
        nameAr ?? name
    }
}

// MARK: - Customer Profile
struct CustomerProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var nameAr: String?
    var phone: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case nameAr = "name_ar"
        case phone
        case createdAt = "created_at"
    }
    
    var displayName: String {
        nameAr ?? name
    }
}

// MARK: - Ledger Entry (Store's view of a customer)
struct LedgerEntry: Codable, Identifiable, Equatable {
    var id: UUID { customerId }
    let storeId: UUID
    let customerId: UUID
    var totalOwed: Decimal
    var lastActivityAt: Date
    var customer: CustomerProfile?
    
    enum CodingKeys: String, CodingKey {
        case storeId = "store_id"
        case customerId = "customer_id"
        case totalOwed = "total_owed"
        case lastActivityAt = "last_activity_at"
        case customer
    }
}

// MARK: - Customer Ledger (Customer's view of stores they owe)
struct CustomerLedger: Codable, Identifiable, Equatable {
    var id: UUID { storeId }
    let storeId: UUID
    let customerId: UUID
    var totalOwed: Decimal
    var lastActivityAt: Date
    var store: StoreProfile?
    
    enum CodingKeys: String, CodingKey {
        case storeId = "store_id"
        case customerId = "customer_id"
        case totalOwed = "total_owed"
        case lastActivityAt = "last_activity_at"
        case store
    }
}

// MARK: - OCR Result
struct OCRResult: Codable {
    var storeName: String?
    var storeNameAr: String?
    var items: [OCRItem]
    var total: Decimal
    var confidence: Double
    
    enum CodingKeys: String, CodingKey {
        case storeName = "store_name"
        case storeNameAr = "store_name_ar"
        case items, total, confidence
    }
}

struct OCRItem: Codable, Identifiable {
    let id = UUID()
    var name: String
    var nameAr: String?
    var quantity: Decimal
    var unitPrice: Decimal
    var totalPrice: Decimal
    var matchedProductId: UUID?
    var matchedProduct: Product?
    
    enum CodingKeys: String, CodingKey {
        case name
        case nameAr = "name_ar"
        case quantity
        case unitPrice = "unit_price"
        case totalPrice = "total_price"
        case matchedProductId = "matched_product_id"
        case matchedProduct = "matched_product"
    }
}

// MARK: - Reminder
enum ReminderType: String, Codable, CaseIterable {
    case scheduled = "scheduled"
    case threshold = "threshold"
    case manual = "manual"
    
    var displayName: String {
        switch self {
        case .scheduled: return "Every X days"
        case .threshold: return "Balance threshold"
        case .manual: return "One-time"
        }
    }
    
    var displayNameAr: String {
        switch self {
        case .scheduled: return "كل X يوم"
        case .threshold: return "حد الرصيد"
        case .manual: return "مرة واحدة"
        }
    }
    
    var icon: String {
        switch self {
        case .scheduled: return "calendar.badge.clock"
        case .threshold: return "exclamationmark.arrow.circlepath"
        case .manual: return "bell.fill"
        }
    }
}

struct Reminder: Codable, Identifiable {
    let id: UUID
    let storeId: UUID
    let customerId: UUID
    var type: ReminderType
    var daysInterval: Int?
    var balanceThreshold: Decimal?
    var nextReminderDate: Date
    var isActive: Bool
    var customerName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case customerId = "customer_id"
        case type
        case daysInterval = "days_interval"
        case balanceThreshold = "balance_threshold"
        case nextReminderDate = "next_reminder_date"
        case isActive = "is_active"
        case customerName = "customer_name"
    }
}

// MARK: - Staff
enum StaffRole: String, Codable, CaseIterable {
    case manager = "manager"
    case cashier = "cashier"
    case viewer = "viewer"
    
    var displayName: String {
        switch self {
        case .manager: return "Manager"
        case .cashier: return "Cashier"
        case .viewer: return "Viewer"
        }
    }
    
    var displayNameAr: String {
        switch self {
        case .manager: return "مدير"
        case .cashier: return "كاشير"
        case .viewer: return "مشاهد"
        }
    }
    
    var icon: String {
        switch self {
        case .manager: return "person.badge.key.fill"
        case .cashier: return "banknote.fill"
        case .viewer: return "eye.fill"
        }
    }
}

struct StaffMember: Codable, Identifiable {
    let id: UUID
    let storeId: UUID
    var name: String
    var nameAr: String?
    var phone: String?
    var role: StaffRole
    var isActive: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case name
        case nameAr = "name_ar"
        case phone, role
        case isActive = "is_active"
        case createdAt = "created_at"
    }
    
    var displayName: String { nameAr ?? name }
}

struct StoreBranch: Codable, Identifiable {
    let id: UUID
    let storeId: UUID
    var name: String
    var nameAr: String?
    var address: String?
    var isMain: Bool
    
    var displayName: String { nameAr ?? name }
}

// MARK: - Payments
enum PaymentMethod: String, Codable, CaseIterable {
    case card = "card"
    case wallet = "wallet"
    case bankTransfer = "bank_transfer"
    
    var displayName: String {
        switch self {
        case .card: return "Credit/Debit Card"
        case .wallet: return "Digital Wallet"
        case .bankTransfer: return "Bank Transfer"
        }
    }
    
    var displayNameAr: String {
        switch self {
        case .card: return "بطاقة ائتمان/خصم"
        case .wallet: return "محفظة رقمية"
        case .bankTransfer: return "تحويل بنكي"
        }
    }
    
    var icon: String {
        switch self {
        case .card: return "creditcard.fill"
        case .wallet: return "wallet.pass.fill"
        case .bankTransfer: return "building.columns.fill"
        }
    }
}

enum PaymentStatus: String, Codable {
    case pending = "pending"
    case completed = "completed"
    case failed = "failed"
}

struct Payment: Codable, Identifiable {
    let id: UUID
    let storeId: UUID
    let customerId: UUID
    let amount: Decimal
    var method: PaymentMethod
    var status: PaymentStatus
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case customerId = "customer_id"
        case amount, method, status
        case createdAt = "created_at"
    }
}

// MARK: - Analytics
struct AnalyticsSummary {
    let totalRevenue: Decimal
    let totalOutstanding: Decimal
    let totalCustomers: Int
    let totalBills: Int
    let averageBillSize: Decimal
    let topCustomers: [TopCustomer]
    let revenueByDay: [DailyRevenue]
    let collectionRate: Double
}

struct TopCustomer: Identifiable {
    let id: UUID
    let name: String
    let totalSpent: Decimal
    let billCount: Int
}

struct DailyRevenue: Identifiable {
    var id: String { date }
    let date: String
    let amount: Decimal
}

// MARK: - Store Directory (Discovery)
struct DirectoryStore: Codable, Identifiable {
    let id: UUID
    let name: String
    let nameAr: String?
    let address: String?
    let category: String?
    let distance: Double?
    let joinCode: String
    let customerCount: Int
    let rating: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case nameAr = "name_ar"
        case address, category, distance
        case joinCode = "join_code"
        case customerCount = "customer_count"
        case rating
    }
    
    var displayName: String { nameAr ?? name }
}

// MARK: - WhatsApp Share Helper
struct WhatsAppShare {
    static func shareBill(bill: Bill, storeName: String, phone: String?) {
        let amount = bill.totalAmount.formatted(.number.precision(.fractionLength(2)))
        let date = bill.createdAt.formatted(date: .abbreviated, time: .shortened)
        let itemsList = bill.items.map { "  \($0.name) × \($0.quantity.formatted()): QR \($0.totalPrice.formatted(.number.precision(.fractionLength(2))))" }.joined(separator: "\n")
        
        let message = """
        📋 Bill from \(storeName)
        💰 Amount: QR \(amount)
        📅 \(date)
        \(bill.items.isEmpty ? "" : "\n\(itemsList)")
        ---
        فاتورة من \(storeName)
        المبلغ: \(amount) ر.ق
        """
        
        openWhatsApp(phone: phone, message: message)
    }
    
    static func shareStatement(customerName: String, totalOwed: Decimal, bills: [Bill], storeName: String, phone: String?) {
        let amount = totalOwed.formatted(.number.precision(.fractionLength(2)))
        let pendingBills = bills.filter { $0.status == .pending }
        let billSummary = pendingBills.prefix(5).map {
            "  QR \($0.totalAmount.formatted(.number.precision(.fractionLength(2)))) - \($0.createdAt.formatted(date: .abbreviated, time: .omitted))"
        }.joined(separator: "\n")
        
        let message = """
        📋 Statement from \(storeName)
        👤 \(customerName)
        💰 Total: QR \(amount)
        📝 \(pendingBills.count) pending bill(s)
        \(billSummary.isEmpty ? "" : "\n\(billSummary)")
        ---
        كشف حساب من \(storeName)
        الإجمالي: \(amount) ر.ق
        """
        
        openWhatsApp(phone: phone, message: message)
    }
    
    static func shareReminder(customerName: String, totalOwed: Decimal, storeName: String, phone: String?) {
        let amount = totalOwed.formatted(.number.precision(.fractionLength(2)))
        
        let message = """
        🔔 Reminder from \(storeName)
        Hi \(customerName), you have an outstanding balance of QR \(amount).
        ---
        تذكير من \(storeName)
        مرحباً \(customerName)، لديك رصيد مستحق بقيمة \(amount) ر.ق
        """
        
        openWhatsApp(phone: phone, message: message)
    }
    
    private static func openWhatsApp(phone: String?, message: String) {
        guard let encoded = message.trimmingCharacters(in: .whitespacesAndNewlines)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        
        var urlString = "https://wa.me/"
        if let phone = phone {
            let clean = phone.replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "+", with: "")
                .replacingOccurrences(of: "-", with: "")
            urlString += clean
        }
        urlString += "?text=\(encoded)"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - PDF Export Helper
import UIKit

struct PDFExporter {
    static func generateLedgerPDF(
        storeName: String,
        customers: [LedgerEntry],
        bills: [Bill]
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        return renderer.pdfData { context in
            context.beginPage()
            let margin: CGFloat = 40
            var y: CGFloat = margin
            
            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.label
            ]
            let title = "Daftar - \(storeName)"
            title.draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += 40
            
            // Date
            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let dateStr = "Generated: \(Date().formatted(date: .abbreviated, time: .shortened))"
            dateStr.draw(at: CGPoint(x: margin, y: y), withAttributes: dateAttrs)
            y += 30
            
            // Summary
            let totalOwed = customers.reduce(Decimal.zero) { $0 + $1.totalOwed }
            let summaryAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.label
            ]
            "Total Outstanding: QR \(totalOwed.formatted(.number.precision(.fractionLength(2))))".draw(at: CGPoint(x: margin, y: y), withAttributes: summaryAttrs)
            y += 20
            "Total Customers: \(customers.count)".draw(at: CGPoint(x: margin, y: y), withAttributes: summaryAttrs)
            y += 35
            
            // Divider
            let dividerPath = UIBezierPath()
            dividerPath.move(to: CGPoint(x: margin, y: y))
            dividerPath.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
            UIColor.separator.setStroke()
            dividerPath.stroke()
            y += 15
            
            // Column headers
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: UIColor.label
            ]
            "Customer".draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttrs)
            "Phone".draw(at: CGPoint(x: 220, y: y), withAttributes: headerAttrs)
            "Balance (QR)".draw(at: CGPoint(x: 380, y: y), withAttributes: headerAttrs)
            y += 22
            
            // Customer rows
            let rowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.label
            ]
            
            for customer in customers {
                if y > pageRect.height - 60 {
                    context.beginPage()
                    y = margin
                }
                
                let name = customer.customer?.displayName ?? "Unknown"
                let phone = customer.customer?.phone ?? "-"
                let balance = customer.totalOwed.formatted(.number.precision(.fractionLength(2)))
                
                name.draw(at: CGPoint(x: margin, y: y), withAttributes: rowAttrs)
                phone.draw(at: CGPoint(x: 220, y: y), withAttributes: rowAttrs)
                balance.draw(at: CGPoint(x: 380, y: y), withAttributes: rowAttrs)
                y += 20
            }
        }
    }
}
