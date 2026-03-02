//
//  PaymentView.swift
//  daftar
//
//  Payment feature - Coming Soon placeholder
//

import SwiftUI

struct PaymentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    let storeName: String
    let storeId: UUID
    let customerId: UUID
    let totalOwed: Decimal
    let onPaymentComplete: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentColor)
                }
                
                // Title
                Text(appState.localized("Coming Soon", arabic: "قريباً"))
                    .font(.title.bold())
                
                // Subtitle
                VStack(spacing: 8) {
                    Text(appState.localized(
                        "In-app payments will be available soon.",
                        arabic: "سيتوفر الدفع داخل التطبيق قريباً."
                    ))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    
                    Text(appState.localized(
                        "For now, please pay directly at the store.",
                        arabic: "في الوقت الحالي، يرجى الدفع مباشرة في المتجر."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                
                // Store info
                VStack(spacing: 12) {
                    HStack {
                        Text(appState.localized("Store", arabic: "المتجر"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(storeName)
                            .fontWeight(.semibold)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text(appState.localized("Amount Due", arabic: "المبلغ المستحق"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("QR \(totalOwed.formatted(.number.precision(.fractionLength(2))))")
                            .font(.headline.monospacedDigit())
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Dismiss button
                Button {
                    dismiss()
                } label: {
                    Text(appState.localized("Got It", arabic: "فهمت"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(appState.localized("Pay Tab", arabic: "سداد الحساب"))
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
            }
        }
    }
}

#Preview {
    PaymentView(
        storeName: "Al Meera",
        storeId: UUID(),
        customerId: UUID(),
        totalOwed: 320,
        onPaymentComplete: nil
    )
    .environmentObject(AppState())
}
