//
//  StoreDiscoveryView.swift
//  daftar
//
//  Discover nearby stores that use Daftar (mock directory)
//

import SwiftUI

struct StoreDiscoveryView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    let onJoined: ((StoreProfile) -> Void)?
    
    @State private var searchText = ""
    @State private var stores: [DirectoryStore] = []
    @State private var selectedCategory: String? = nil
    @State private var joiningCode: String?
    @State private var joinedStore: StoreProfile?
    @State private var joinError: String?
    
    private let categories = ["All", "Baqala", "Supermarket", "Hypermarket"]
    private let categoriesAr = ["الكل", "بقالة", "سوبرماركت", "هايبرماركت"]
    
    init(onJoined: ((StoreProfile) -> Void)? = nil) {
        self.onJoined = onJoined
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(categories.enumerated()), id: \.offset) { index, category in
                            let isSelected = (selectedCategory == nil && index == 0) ||
                                             (selectedCategory == category && index != 0)
                            
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCategory = index == 0 ? nil : category
                                }
                                loadStores()
                            } label: {
                                Text(appState.language == .arabic ? categoriesAr[index] : category)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(isSelected ? .white : .primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        isSelected ?
                                        AnyShapeStyle(LinearGradient(
                                            colors: [Color.accentColor, Color(hex: "764ba2")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )) : AnyShapeStyle(Color(.systemGray5))
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                
                // Store list
                if filteredStores.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredStores) { store in
                                DirectoryStoreCard(store: store) {
                                    joinStore(code: store.joinCode)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .searchable(text: $searchText, prompt: appState.localized("Search stores...", arabic: "بحث عن متاجر..."))
            .onChange(of: searchText) { oldValue, newValue in loadStores() }
            .navigationTitle(appState.localized("Discover Stores", arabic: "اكتشف المتاجر"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.localized("Cancel", arabic: "إلغاء")) {
                        dismiss()
                    }
                }
            }
            .onAppear { loadStores() }
            .alert(appState.localized("Joined!", arabic: "تم الانضمام!"), isPresented: .constant(joinedStore != nil)) {
                Button(appState.localized("OK", arabic: "حسناً")) {
                    if let store = joinedStore {
                        onJoined?(store)
                    }
                    joinedStore = nil
                    dismiss()
                }
            } message: {
                if let store = joinedStore {
                    Text(appState.localized(
                        "You've joined \(store.displayName)",
                        arabic: "انضممت إلى \(store.displayName)"
                    ))
                }
            }
            .alert(appState.localized("Error", arabic: "خطأ"), isPresented: .constant(joinError != nil)) {
                Button(appState.localized("OK", arabic: "حسناً")) { joinError = nil }
            } message: {
                Text(joinError ?? "")
            }
        }
    }
    
    private var filteredStores: [DirectoryStore] {
        if let cat = selectedCategory {
            return stores.filter { $0.category == cat }
        }
        return stores
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(appState.localized("No stores found", arabic: "لم يتم العثور على متاجر"))
                .font(.headline)
            Text(appState.localized("Try a different search", arabic: "جرب بحث مختلف"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
    
    private func loadStores() {
        stores = DemoData.shared.getDirectoryStores(query: searchText)
    }
    
    private func joinStore(code: String) {
        joiningCode = code
        let customerId = authManager.customerProfile?.id ?? UUID()
        
        if let store = DemoData.shared.joinStore(code: code, customerId: customerId) {
            joinedStore = store
        } else {
            joinError = appState.localized("Could not join store", arabic: "لا يمكن الانضمام للمتجر")
        }
        joiningCode = nil
    }
}

// MARK: - Directory Store Card
struct DirectoryStoreCard: View {
    let store: DirectoryStore
    let onJoin: () -> Void
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "storefront.fill")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.displayName)
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        if let category = store.category {
                            Text(category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let distance = store.distance {
                            HStack(spacing: 2) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 9))
                                Text("\(distance, specifier: "%.1f") km")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let address = store.address {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    if let rating = store.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                            Text("\(rating, specifier: "%.1f")")
                                .font(.caption.bold())
                        }
                    }
                    
                    Text("\(store.customerCount) " + appState.localized("users", arabic: "مستخدم"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            
            Divider().padding(.leading)
            
            Button {
                onJoin()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(appState.localized("Join", arabic: "انضم"))
                }
                .font(.subheadline.bold())
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    StoreDiscoveryView()
        .environmentObject(AppState())
        .environmentObject(AuthManager())
}
