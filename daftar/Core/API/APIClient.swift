//
//  APIClient.swift
//  daftar
//
//  Network layer for API communication
//

import Foundation
import UIKit

// MARK: - API Error
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int, String?)
    case decodingError(Error)
    case networkError(Error)
    case unauthorized
    case serverError(String)
    case noConnection
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code, let message):
            if let message { return message }
            return "Server error (\(code))"
        case .decodingError:
            return "Failed to process server response"
        case .networkError:
            return "Network error. Please check your connection."
        case .unauthorized:
            return "Session expired. Please log in again."
        case .serverError(let message):
            return message
        case .noConnection:
            return "No internet connection"
        }
    }
    
    var errorDescriptionArabic: String? {
        switch self {
        case .invalidURL:
            return "رابط غير صالح"
        case .invalidResponse:
            return "استجابة غير صالحة من الخادم"
        case .httpError(let code, let message):
            if let message { return message }
            return "خطأ في الخادم (\(code))"
        case .decodingError:
            return "فشل في معالجة استجابة الخادم"
        case .networkError:
            return "خطأ في الشبكة. يرجى التحقق من اتصالك."
        case .unauthorized:
            return "انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى."
        case .serverError(let message):
            return message
        case .noConnection:
            return "لا يوجد اتصال بالإنترنت"
        }
    }
}

// MARK: - Error Response
struct ErrorResponse: Codable {
    let detail: String?
}

// MARK: - Auth Responses
struct StoreAuthResponse: Codable {
    let token: String
    let store: StoreProfile
}

struct CustomerAuthResponse: Codable {
    let token: String
    let customer: CustomerProfile
}

// MARK: - API Client
final class APIClient {
    static let shared = APIClient()
    
    private var baseURL: String {
        if let override = ProcessInfo.processInfo.environment["API_BASE_URL"],
           !override.isEmpty {
            return override
        }

        return "https://daftar-production-3865.up.railway.app/api/v1"
    }
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try ISO8601 with fractional seconds first
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(dateString)")
        }
        
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - Private Helpers
    
    private func request<T: Decodable>(
        _ method: String,
        path: String,
        body: Encodable? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if authenticated, let token = KeychainService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body {
            request.httpBody = try encoder.encode(body)
        }
        
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            if error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                throw APIError.noConnection
            }
            throw APIError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // Handle errors
        if !(200..<300 ~= httpResponse.statusCode) {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            
            // Try to parse error message from response
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data),
               let detail = errorResponse.detail {
                throw APIError.httpError(httpResponse.statusCode, detail)
            }
            
            throw APIError.httpError(httpResponse.statusCode, nil)
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Response JSON: \(jsonString)")
            }
            throw APIError.decodingError(error)
        }
    }
    
    // MARK: - Demo Login (for testing without SMS)
    
    func demoLogin() async throws -> StoreAuthResponse {
        try await request("GET", path: "/demo/login", authenticated: false)
    }
    
    func seedDemoData() async throws {
        struct SeedResponse: Codable {
            let message: String
        }
        let _: SeedResponse = try await request("POST", path: "/seed", authenticated: false)
    }
    
    // MARK: - Store Auth
    
    func loginStore(phone: String, code: String) async throws -> StoreAuthResponse {
        struct Body: Codable {
            let phone: String
            let code: String
        }
        return try await request("POST", path: "/auth/store/login", body: Body(phone: phone, code: code), authenticated: false)
    }
    
    func registerStore(name: String, nameAr: String?, phone: String, code: String) async throws -> StoreAuthResponse {
        struct Body: Codable {
            let name: String
            let name_ar: String?
            let phone: String
            let code: String
        }
        return try await request(
            "POST",
            path: "/auth/store/register",
            body: Body(name: name, name_ar: nameAr, phone: phone, code: code),
            authenticated: false
        )
    }
    
    func getStoreProfile() async throws -> StoreProfile {
        try await request("GET", path: "/store/profile")
    }
    
    // MARK: - Customer Auth
    
    func loginCustomer(phone: String, code: String) async throws -> CustomerAuthResponse {
        struct Body: Codable {
            let phone: String
            let code: String
        }
        return try await request("POST", path: "/auth/customer/login", body: Body(phone: phone, code: code), authenticated: false)
    }
    
    func registerCustomer(name: String, nameAr: String?, phone: String, code: String) async throws -> CustomerAuthResponse {
        struct Body: Codable {
            let name: String
            let name_ar: String?
            let phone: String
            let code: String
        }
        return try await request(
            "POST",
            path: "/auth/customer/register",
            body: Body(name: name, name_ar: nameAr, phone: phone, code: code),
            authenticated: false
        )
    }
    
    func getCustomerProfile() async throws -> CustomerProfile {
        try await request("GET", path: "/customer/profile")
    }
    
    // MARK: - Store Ledger (Store's view)
    
    func getStoreLedger() async throws -> [LedgerEntry] {
        try await request("GET", path: "/store/ledger")
    }
    
    func getCustomerBills(customerId: UUID) async throws -> [Bill] {
        try await request("GET", path: "/store/customers/\(customerId.uuidString)/bills")
    }
    
    func addCustomerToStore(name: String, phone: String) async throws -> LedgerEntry {
        struct Body: Codable {
            let name: String
            let phone: String
        }
        return try await request("POST", path: "/store/customers", body: Body(name: name, phone: phone))
    }
    
    // MARK: - Customer Ledger (Customer's view)
    
    func getCustomerLedger() async throws -> [CustomerLedger] {
        try await request("GET", path: "/customer/ledger")
    }
    
    func getStoreBillsForCustomer(storeId: UUID) async throws -> [Bill] {
        try await request("GET", path: "/customer/stores/\(storeId.uuidString)/bills")
    }
    
    func joinStore(code: String) async throws -> StoreProfile {
        struct Body: Codable {
            let code: String
        }
        return try await request("POST", path: "/customer/join", body: Body(code: code))
    }
    
    func getPendingBillsCount() async throws -> Int {
        struct Response: Codable {
            let count: Int
        }
        let response: Response = try await request("GET", path: "/customer/bills/pending/count")
        return response.count
    }
    
    // MARK: - Bills
    
    struct BillItemBody: Codable {
        let name: String
        let name_ar: String?
        let quantity: Decimal
        let unit_price: Decimal
        let total_price: Decimal
        let product_id: UUID?
    }
    
    struct CreateBillBody: Codable {
        let customer_id: UUID
        let items: [BillItemBody]
        let total: Decimal
        let notes: String?
        let receipt_image_url: String?
    }
    
    /// Create a bill with items
    func createBill(customerId: UUID, items: [BillItem], total: Decimal, notes: String? = nil) async throws -> Bill {
        let itemBodies = items.map { item in
            BillItemBody(
                name: item.name,
                name_ar: item.nameAr,
                quantity: item.quantity,
                unit_price: item.unitPrice,
                total_price: item.totalPrice,
                product_id: item.productId
            )
        }
        
        return try await request("POST", path: "/bills", body: CreateBillBody(
            customer_id: customerId,
            items: itemBodies,
            total: total,
            notes: notes,
            receipt_image_url: nil
        ))
    }
    
    /// Create a "quick bill" with just a total amount (no items) - for baqalas that don't itemize
    func createQuickBill(customerId: UUID, total: Decimal, notes: String? = nil) async throws -> Bill {
        // Create a single "Purchase" item with the total
        let singleItem = BillItemBody(
            name: "Purchase",
            name_ar: "مشتريات",
            quantity: 1,
            unit_price: total,
            total_price: total,
            product_id: nil
        )
        
        return try await request("POST", path: "/bills", body: CreateBillBody(
            customer_id: customerId,
            items: [singleItem],
            total: total,
            notes: notes,
            receipt_image_url: nil
        ))
    }
    
    /// Create a bill from OCR items
    func createBill(customerId: UUID, items: [OCRItem], total: Decimal) async throws -> Bill {
        let itemBodies = items.map { item in
            BillItemBody(
                name: item.name,
                name_ar: item.nameAr,
                quantity: item.quantity,
                unit_price: item.unitPrice,
                total_price: item.totalPrice,
                product_id: item.matchedProductId
            )
        }
        
        return try await request("POST", path: "/bills", body: CreateBillBody(
            customer_id: customerId,
            items: itemBodies,
            total: total,
            notes: nil,
            receipt_image_url: nil
        ))
    }
    
    func updateBillStatus(billId: UUID, status: BillStatus) async throws -> Bill {
        struct Body: Codable {
            let status: String
        }
        return try await request("PATCH", path: "/bills/\(billId.uuidString)", body: Body(status: status.rawValue))
    }
    
    // MARK: - OCR
    
    func uploadImage(_ image: UIImage) async throws -> String {
        guard let url = URL(string: baseURL + "/upload") else {
            throw APIError.invalidURL
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw APIError.invalidResponse
        }
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let token = KeychainService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"receipt.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw APIError.invalidResponse
        }
        
        struct UploadResponse: Codable {
            let url: String
        }
        
        let uploadResponse = try decoder.decode(UploadResponse.self, from: data)
        return uploadResponse.url
    }
    
    func processReceiptOCR(imageUrl: String) async throws -> OCRResult {
        struct Body: Codable {
            let image_url: String
        }
        return try await request("POST", path: "/ocr/receipt", body: Body(image_url: imageUrl))
    }
    
    // MARK: - Handwriting OCR (Option A)
    
    struct HandwritingResult: Codable {
        let customerName: String?
        let amount: Decimal?
        let rawText: String?
        let confidence: Double
        
        enum CodingKeys: String, CodingKey {
            case customerName = "customer_name"
            case amount
            case rawText = "raw_text"
            case confidence
        }
    }
    
    func processHandwritingOCR(imageUrl: String) async throws -> HandwritingResult {
        struct Body: Codable {
            let image_url: String
        }
        return try await request("POST", path: "/ocr/handwriting", body: Body(image_url: imageUrl))
    }
    
    // MARK: - Products
    
    func searchProducts(query: String) async throws -> [Product] {
        try await request("GET", path: "/products?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)")
    }
    
    // MARK: - OTP
    
    struct OTPResponse: Codable {
        let message: String
        let phone: String
        let devOtp: String?
        
        enum CodingKeys: String, CodingKey {
            case message, phone
            case devOtp = "dev_otp"
        }
    }
    
    func sendOTP(phone: String) async throws -> OTPResponse {
        struct Body: Codable {
            let phone: String
        }
        return try await request("POST", path: "/auth/otp/send", body: Body(phone: phone), authenticated: false)
    }
    
    // MARK: - Push Notifications
    
    func registerStorePushToken(_ token: String) async throws {
        struct Body: Codable {
            let token: String
        }
        struct Response: Codable {
            let message: String
        }
        let _: Response = try await request("POST", path: "/store/push-token", body: Body(token: token))
    }
    
    func registerCustomerPushToken(_ token: String) async throws {
        struct Body: Codable {
            let token: String
        }
        struct Response: Codable {
            let message: String
        }
        let _: Response = try await request("POST", path: "/customer/push-token", body: Body(token: token))
    }
    
    // MARK: - Data Export & Account Deletion (GDPR)
    
    func exportStoreData() async throws -> Data {
        guard let url = URL(string: baseURL + "/store/export") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = KeychainService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw APIError.invalidResponse
        }
        
        return data
    }
    
    func exportCustomerData() async throws -> Data {
        guard let url = URL(string: baseURL + "/customer/export") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = KeychainService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw APIError.invalidResponse
        }
        
        return data
    }
    
    func deleteStoreAccount() async throws {
        struct Response: Codable {
            let message: String
        }
        let _: Response = try await request("DELETE", path: "/store/account")
    }
    
    func deleteCustomerAccount() async throws {
        struct Response: Codable {
            let message: String
        }
        let _: Response = try await request("DELETE", path: "/customer/account")
    }
}
