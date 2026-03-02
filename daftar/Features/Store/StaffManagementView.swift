//
//  StaffManagementView.swift
//  daftar
//
//  Multi-staff & multi-branch management (mock)
//

import SwiftUI

struct StaffManagementView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var staff: [StaffMember] = []
    @State private var branches: [StoreBranch] = []
    @State private var showingAddStaff = false
    @State private var showingAddBranch = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("", selection: $selectedTab) {
                    Text(appState.localized("Staff", arabic: "الموظفين")).tag(0)
                    Text(appState.localized("Branches", arabic: "الفروع")).tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if selectedTab == 0 {
                    staffList
                } else {
                    branchList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(appState.localized("Team", arabic: "الفريق"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.localized("Done", arabic: "تم")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if selectedTab == 0 { showingAddStaff = true }
                        else { showingAddBranch = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear { loadData() }
            .sheet(isPresented: $showingAddStaff) {
                AddStaffSheet { newStaff in
                    staff.append(newStaff)
                }
            }
            .sheet(isPresented: $showingAddBranch) {
                AddBranchSheet { newBranch in
                    branches.append(newBranch)
                }
            }
        }
    }
    
    // MARK: - Staff List
    private var staffList: some View {
        Group {
            if staff.isEmpty {
                emptyState(
                    icon: "person.3.fill",
                    title: appState.localized("No staff added", arabic: "لا يوجد موظفين"),
                    subtitle: appState.localized("Add team members to manage your store", arabic: "أضف أعضاء الفريق لإدارة متجرك")
                )
            } else {
                List {
                    ForEach(staff) { member in
                        HStack(spacing: 14) {
                            Circle()
                                .fill(member.isActive ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: member.role.icon)
                                        .foregroundStyle(member.isActive ? Color.accentColor : .gray)
                                )
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(member.displayName)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(member.isActive ? .primary : .secondary)
                                
                                HStack(spacing: 6) {
                                    Text(appState.language == .arabic ? member.role.displayNameAr : member.role.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    if !member.isActive {
                                        Text(appState.localized("Inactive", arabic: "غير نشط"))
                                            .font(.caption2.bold())
                                            .foregroundStyle(.orange)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            if let phone = member.phone {
                                Text(phone)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
    
    // MARK: - Branch List
    private var branchList: some View {
        Group {
            if branches.isEmpty {
                emptyState(
                    icon: "building.2.fill",
                    title: appState.localized("No branches", arabic: "لا توجد فروع"),
                    subtitle: appState.localized("Add branches for multi-location stores", arabic: "أضف فروع للمتاجر متعددة المواقع")
                )
            } else {
                List {
                    ForEach(branches) { branch in
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: branch.isMain ? "star.fill" : "mappin.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                )
                            
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(branch.displayName)
                                        .font(.subheadline.bold())
                                    
                                    if branch.isMain {
                                        Text(appState.localized("Main", arabic: "رئيسي"))
                                            .font(.caption2.bold())
                                            .foregroundStyle(Color.accentColor)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                }
                                
                                if let address = branch.address {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
    
    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
    
    private func loadData() {
        guard let storeId = authManager.storeProfile?.id else { return }
        staff = DemoData.shared.getMockStaff(storeId: storeId)
        branches = DemoData.shared.getMockBranches(storeId: storeId)
    }
}

// MARK: - Add Staff Sheet
struct AddStaffSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    
    let onAdd: (StaffMember) -> Void
    
    @State private var name = ""
    @State private var phone = ""
    @State private var role: StaffRole = .cashier
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(appState.localized("Name", arabic: "الاسم"), text: $name)
                    TextField(appState.localized("Phone", arabic: "الهاتف"), text: $phone)
                        .keyboardType(.phonePad)
                }
                
                Section(appState.localized("Role", arabic: "الدور")) {
                    Picker(appState.localized("Role", arabic: "الدور"), selection: $role) {
                        ForEach(StaffRole.allCases, id: \.self) { r in
                            Label(
                                appState.language == .arabic ? r.displayNameAr : r.displayName,
                                systemImage: r.icon
                            ).tag(r)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle(appState.localized("Add Staff", arabic: "إضافة موظف"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.localized("Cancel", arabic: "إلغاء")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.localized("Add", arabic: "إضافة")) {
                        let member = StaffMember(
                            id: UUID(),
                            storeId: authManager.storeProfile?.id ?? UUID(),
                            name: name,
                            nameAr: nil,
                            phone: phone.isEmpty ? nil : phone,
                            role: role,
                            isActive: true,
                            createdAt: Date()
                        )
                        onAdd(member)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Add Branch Sheet
struct AddBranchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    
    let onAdd: (StoreBranch) -> Void
    
    @State private var name = ""
    @State private var address = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField(appState.localized("Branch Name", arabic: "اسم الفرع"), text: $name)
                TextField(appState.localized("Address", arabic: "العنوان"), text: $address)
            }
            .navigationTitle(appState.localized("Add Branch", arabic: "إضافة فرع"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.localized("Cancel", arabic: "إلغاء")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.localized("Add", arabic: "إضافة")) {
                        let branch = StoreBranch(
                            id: UUID(),
                            storeId: authManager.storeProfile?.id ?? UUID(),
                            name: name,
                            nameAr: nil,
                            address: address.isEmpty ? nil : address,
                            isMain: false
                        )
                        onAdd(branch)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

#Preview {
    StaffManagementView()
        .environmentObject(AppState())
        .environmentObject(AuthManager())
}
