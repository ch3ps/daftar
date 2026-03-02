//
//  ExportView.swift
//  daftar
//
//  PDF / CSV export of store ledger
//

import SwiftUI

struct ExportView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    let customers: [LedgerEntry]
    
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportedURL: URL?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "doc.richtext")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.accentColor)
                
                Text(appState.localized("Export Ledger", arabic: "تصدير الدفتر"))
                    .font(.title2.bold())
                
                Text(appState.localized(
                    "Generate a PDF report of your ledger with all customer balances.",
                    arabic: "أنشئ تقرير PDF للدفتر مع جميع أرصدة العملاء."
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                
                // Summary
                VStack(spacing: 8) {
                    HStack {
                        Text(appState.localized("Customers", arabic: "العملاء"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(customers.count)")
                            .fontWeight(.semibold)
                    }
                    Divider()
                    HStack {
                        Text(appState.localized("Total Outstanding", arabic: "إجمالي المستحق"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("QR \(customers.reduce(Decimal.zero) { $0 + $1.totalOwed }.formatted(.number.precision(.fractionLength(2))))")
                            .fontWeight(.semibold)
                    }
                }
                .font(.subheadline)
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Export button
                Button {
                    exportPDF()
                } label: {
                    HStack(spacing: 10) {
                        if isExporting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(appState.localized("Export PDF", arabic: "تصدير PDF"))
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor, Color(hex: "764ba2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(isExporting)
                .padding(.horizontal, 24)
                
                // CSV option
                Button {
                    exportCSV()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "tablecells")
                        Text(appState.localized("Export CSV", arabic: "تصدير CSV"))
                            .font(.headline)
                    }
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(appState.localized("Export", arabic: "تصدير"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.localized("Cancel", arabic: "إلغاء")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
    
    private func exportPDF() {
        isExporting = true
        let storeName = authManager.storeProfile?.displayName ?? "Store"
        let bills = DemoData.shared.bills
        
        DispatchQueue.global(qos: .userInitiated).async {
            let data = PDFExporter.generateLedgerPDF(
                storeName: storeName,
                customers: customers,
                bills: bills
            )
            
            let tmpURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("daftar_ledger_\(Date().formatted(.dateTime.year().month().day())).pdf")
            try? data.write(to: tmpURL)
            
            DispatchQueue.main.async {
                isExporting = false
                exportedURL = tmpURL
                showShareSheet = true
            }
        }
    }
    
    private func exportCSV() {
        var csv = "Customer,Phone,Balance (QR),Last Activity\n"
        for customer in customers {
            let name = customer.customer?.displayName ?? "Unknown"
            let phone = customer.customer?.phone ?? "-"
            let balance = customer.totalOwed.formatted(.number.precision(.fractionLength(2)))
            let date = customer.lastActivityAt.formatted(date: .abbreviated, time: .omitted)
            csv += "\"\(name)\",\"\(phone)\",\(balance),\(date)\n"
        }
        
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("daftar_ledger_\(Date().formatted(.dateTime.year().month().day())).csv")
        try? csv.write(to: tmpURL, atomically: true, encoding: .utf8)
        exportedURL = tmpURL
        showShareSheet = true
    }
}

// MARK: - UIKit Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ExportView(customers: [])
        .environmentObject(AppState())
        .environmentObject(AuthManager())
}
