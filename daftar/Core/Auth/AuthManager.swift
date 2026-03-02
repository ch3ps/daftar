//
//  AuthManager.swift
//  daftar
//
//  Authentication manager - supports real API auth and demo mode
//

import SwiftUI
import Combine

enum AuthError: LocalizedError {
    case invalidCredentials
    case networkError(String)
    case serverError(String)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid phone number or code"
        case .networkError(let message):
            return message
        case .serverError(let message):
            return message
        case .unknown:
            return "An unknown error occurred"
        }
    }
    
    var errorDescriptionArabic: String? {
        switch self {
        case .invalidCredentials:
            return "رقم الهاتف أو الرمز غير صحيح"
        case .networkError(let message):
            return message
        case .serverError(let message):
            return message
        case .unknown:
            return "حدث خطأ غير معروف"
        }
    }
}

@MainActor
final class AuthManager: ObservableObject {
    // MARK: - Published State
    @Published var isAuthenticated = false
    @Published var userType: UserType?
    @Published var storeProfile: StoreProfile?
    @Published var customerProfile: CustomerProfile?
    @Published var isLoading = false
    @Published var error: String?
    
    /// Whether we're using demo mode (no real backend) or live mode
    @Published var isDemoMode = false
    
    private let keychain = KeychainService.shared
    private let api = APIClient.shared
    
    init() {
        checkAuthState()
    }
    
    // MARK: - Check Existing Auth
    private func checkAuthState() {
        // Check if we have a stored token
        if let _ = keychain.getToken(),
           let typeString = UserDefaults.standard.string(forKey: "user_type"),
           let type = UserType(rawValue: typeString) {
            
            self.userType = type
            self.isDemoMode = UserDefaults.standard.bool(forKey: "is_demo_mode")
            
            // Load saved profile
            if type == .store {
                loadStoredStoreProfile()
            } else {
                loadStoredCustomerProfile()
            }
            
            self.isAuthenticated = true
        }
    }
    
    // MARK: - Store Authentication
    
    /// Register a new store with the backend
    func registerStore(name: String, nameAr: String?, phone: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let response = try await api.registerStore(name: name, nameAr: nameAr, phone: phone)
            
            // Save token and profile
            keychain.saveToken(response.token)
            saveStoreProfile(response.store)
            
            UserDefaults.standard.set(UserType.store.rawValue, forKey: "user_type")
            UserDefaults.standard.set(false, forKey: "is_demo_mode")
            
            self.storeProfile = response.store
            self.userType = .store
            self.isDemoMode = false
            self.isAuthenticated = true
        } catch let apiError as APIError {
            self.error = apiError.errorDescription
            throw AuthError.serverError(apiError.errorDescription ?? "Registration failed")
        }
    }
    
    /// Login as store with phone + verification code
    func loginStore(phone: String, code: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let response = try await api.loginStore(phone: phone, code: code)
            
            // Save token and profile
            keychain.saveToken(response.token)
            saveStoreProfile(response.store)
            
            UserDefaults.standard.set(UserType.store.rawValue, forKey: "user_type")
            UserDefaults.standard.set(false, forKey: "is_demo_mode")
            
            self.storeProfile = response.store
            self.userType = .store
            self.isDemoMode = false
            self.isAuthenticated = true
        } catch let apiError as APIError {
            self.error = apiError.errorDescription
            throw AuthError.serverError(apiError.errorDescription ?? "Login failed")
        }
    }
    
    // MARK: - Customer Authentication
    
    /// Register a new customer with the backend
    func registerCustomer(name: String, nameAr: String?, phone: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let response = try await api.registerCustomer(name: name, nameAr: nameAr, phone: phone)
            
            // Save token and profile
            keychain.saveToken(response.token)
            saveCustomerProfile(response.customer)
            
            UserDefaults.standard.set(UserType.customer.rawValue, forKey: "user_type")
            UserDefaults.standard.set(false, forKey: "is_demo_mode")
            
            self.customerProfile = response.customer
            self.userType = .customer
            self.isDemoMode = false
            self.isAuthenticated = true
        } catch let apiError as APIError {
            self.error = apiError.errorDescription
            throw AuthError.serverError(apiError.errorDescription ?? "Registration failed")
        }
    }
    
    /// Login as customer with phone + verification code
    func loginCustomer(phone: String, code: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let response = try await api.loginCustomer(phone: phone, code: code)
            
            // Save token and profile
            keychain.saveToken(response.token)
            saveCustomerProfile(response.customer)
            
            UserDefaults.standard.set(UserType.customer.rawValue, forKey: "user_type")
            UserDefaults.standard.set(false, forKey: "is_demo_mode")
            
            self.customerProfile = response.customer
            self.userType = .customer
            self.isDemoMode = false
            self.isAuthenticated = true
        } catch let apiError as APIError {
            self.error = apiError.errorDescription
            throw AuthError.serverError(apiError.errorDescription ?? "Login failed")
        }
    }
    
    // MARK: - Demo Mode (Quick Entry)
    
    /// Enter as demo store - connects to backend demo store if available, otherwise uses local demo
    func enterAsDemoStore() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            // Try to connect to demo store on backend
            let response = try await api.demoLogin()
            
            keychain.saveToken(response.token)
            saveStoreProfile(response.store)
            
            UserDefaults.standard.set(UserType.store.rawValue, forKey: "user_type")
            UserDefaults.standard.set(false, forKey: "is_demo_mode")
            
            self.storeProfile = response.store
            self.userType = .store
            self.isDemoMode = false
            self.isAuthenticated = true
            
            print("✅ Connected to demo store: \(response.store.name)")
        } catch {
            print("⚠️ Could not connect to backend, using local demo mode: \(error)")
            // Fall back to local demo mode
            enterAsLocalDemoStore()
        }
    }
    
    /// Enter as local demo store (no backend)
    func enterAsLocalDemoStore() {
        let store = StoreProfile(
            id: UUID(),
            name: "My Store",
            nameAr: "متجري",
            phone: "+974 5555 0001",
            address: "Doha, Qatar",
            logoUrl: nil,
            joinCode: generateJoinCode(),
            createdAt: Date()
        )
        
        // No token needed for demo mode
        UserDefaults.standard.set(UserType.store.rawValue, forKey: "user_type")
        UserDefaults.standard.set(true, forKey: "is_demo_mode")
        saveStoreProfile(store)
        
        self.storeProfile = store
        self.userType = .store
        self.isDemoMode = true
        self.isAuthenticated = true
    }
    
    /// Enter as demo customer (no backend connection)
    func enterAsDemoCustomer() {
        let customer = CustomerProfile(
            id: UUID(),
            name: "Demo Customer",
            nameAr: "عميل تجريبي",
            phone: "+974 5555 0002",
            createdAt: Date()
        )
        
        UserDefaults.standard.set(UserType.customer.rawValue, forKey: "user_type")
        UserDefaults.standard.set(true, forKey: "is_demo_mode")
        saveCustomerProfile(customer)
        
        self.customerProfile = customer
        self.userType = .customer
        self.isDemoMode = true
        self.isAuthenticated = true
    }
    
    // MARK: - Legacy Quick Entry (for compatibility)
    
    func enterAsStore() {
        Task {
            await enterAsDemoStore()
        }
    }
    
    func enterAsCustomer() {
        enterAsDemoCustomer()
    }
    
    // MARK: - Logout
    func logout() {
        keychain.deleteToken()
        UserDefaults.standard.removeObject(forKey: "user_type")
        UserDefaults.standard.removeObject(forKey: "store_profile")
        UserDefaults.standard.removeObject(forKey: "customer_profile")
        UserDefaults.standard.removeObject(forKey: "is_demo_mode")
        
        isAuthenticated = false
        userType = nil
        storeProfile = nil
        customerProfile = nil
        isDemoMode = false
        error = nil
    }
    
    // MARK: - Refresh Profile
    
    func refreshStoreProfile() async {
        guard !isDemoMode else { return }
        
        do {
            let profile = try await api.getStoreProfile()
            saveStoreProfile(profile)
            self.storeProfile = profile
        } catch {
            print("Failed to refresh store profile: \(error)")
        }
    }
    
    func refreshCustomerProfile() async {
        guard !isDemoMode else { return }
        
        do {
            let profile = try await api.getCustomerProfile()
            saveCustomerProfile(profile)
            self.customerProfile = profile
        } catch {
            print("Failed to refresh customer profile: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private func generateJoinCode() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in letters.randomElement()! })
    }
    
    private func saveStoreProfile(_ store: StoreProfile) {
        if let data = try? JSONEncoder().encode(store) {
            UserDefaults.standard.set(data, forKey: "store_profile")
        }
    }
    
    private func loadStoredStoreProfile() {
        if let data = UserDefaults.standard.data(forKey: "store_profile"),
           let store = try? JSONDecoder().decode(StoreProfile.self, from: data) {
            self.storeProfile = store
        }
    }
    
    private func saveCustomerProfile(_ customer: CustomerProfile) {
        if let data = try? JSONEncoder().encode(customer) {
            UserDefaults.standard.set(data, forKey: "customer_profile")
        }
    }
    
    private func loadStoredCustomerProfile() {
        if let data = UserDefaults.standard.data(forKey: "customer_profile"),
           let customer = try? JSONDecoder().decode(CustomerProfile.self, from: data) {
            self.customerProfile = customer
        }
    }
}
