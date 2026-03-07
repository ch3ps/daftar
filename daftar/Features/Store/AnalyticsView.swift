//
//  AnalyticsView.swift
//  daftar
//
//  Store analytics dashboard - revenue, customers, collection rate
//

import SwiftUI
import Combine

struct AnalyticsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = AnalyticsViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // KPI Cards
                    kpiGrid
                    
                    // Revenue chart
                    revenueChart
                    
                    // Collection rate
                    collectionRateCard
                    
                    // Top customers
                    topCustomersCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(appState.localized("Analytics", arabic: "التحليلات"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.localized("Done", arabic: "تم")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.load(storeId: authManager.storeProfile?.id)
            }
        }
    }
    
    // MARK: - KPI Grid
    private var kpiGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            KPICard(
                title: appState.localized("Revenue", arabic: "الإيرادات"),
                value: "QR \(viewModel.analytics?.totalRevenue.formatted(.number.precision(.fractionLength(0))) ?? "0")",
                icon: "chart.line.uptrend.xyaxis",
                color: .green
            )
            KPICard(
                title: appState.localized("Outstanding", arabic: "المستحق"),
                value: "QR \(viewModel.analytics?.totalOutstanding.formatted(.number.precision(.fractionLength(0))) ?? "0")",
                icon: "hourglass",
                color: .orange
            )
            KPICard(
                title: appState.localized("Customers", arabic: "العملاء"),
                value: "\(viewModel.analytics?.totalCustomers ?? 0)",
                icon: "person.3.fill",
                color: Color.accentColor
            )
            KPICard(
                title: appState.localized("Avg Bill", arabic: "متوسط الفاتورة"),
                value: "QR \(viewModel.analytics?.averageBillSize.formatted(.number.precision(.fractionLength(0))) ?? "0")",
                icon: "doc.text.fill",
                color: .purple
            )
        }
    }
    
    // MARK: - Revenue Chart
    private var revenueChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(appState.localized("Revenue (7 days)", arabic: "الإيرادات (7 أيام)"))
                .font(.headline)
            
            if let analytics = viewModel.analytics {
                let maxAmount = analytics.revenueByDay.map { $0.amount }.max() ?? 1
                
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(analytics.revenueByDay) { day in
                        VStack(spacing: 6) {
                            // Bar
                            let height = maxAmount > 0 ? CGFloat(truncating: (day.amount / maxAmount).value as NSDecimalNumber) * 120 : 0
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor)
                                .frame(height: max(8, height))
                            
                            // Day label
                            Text(day.date)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 150)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Collection Rate
    private var collectionRateCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text(appState.localized("Collection Rate", arabic: "معدل التحصيل"))
                    .font(.headline)
                Spacer()
                Text("\(viewModel.analytics?.collectionRate ?? 0, specifier: "%.1f")%")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(collectionColor)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(collectionColor)
                        .frame(width: geo.size.width * CGFloat((viewModel.analytics?.collectionRate ?? 0) / 100.0))
                }
            }
            .frame(height: 12)
            
            HStack {
                Text(appState.localized("Bills paid vs total", arabic: "الفواتير المدفوعة من الإجمالي"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var collectionColor: Color {
        let rate = viewModel.analytics?.collectionRate ?? 0
        if rate >= 80 { return .green }
        if rate >= 50 { return .orange }
        return .red
    }
    
    // MARK: - Top Customers
    private var topCustomersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appState.localized("Top Customers", arabic: "أفضل العملاء"))
                .font(.headline)
            
            if let analytics = viewModel.analytics {
                ForEach(analytics.topCustomers) { customer in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(customer.name.prefix(1).uppercased())
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.accentColor)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(customer.name)
                                .font(.subheadline.bold())
                            Text("\(customer.billCount) " + appState.localized("bills", arabic: "فواتير"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("QR \(customer.totalSpent.formatted(.number.precision(.fractionLength(0))))")
                            .font(.subheadline.monospacedDigit().bold())
                    }
                    
                    if customer.id != analytics.topCustomers.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - KPI Card
struct KPICard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(color)
                }
                Spacer()
            }
            
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - ViewModel
@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var analytics: AnalyticsSummary?
    
    func load(storeId: UUID?) {
        guard let storeId else { return }
        analytics = DemoData.shared.getAnalytics(storeId: storeId)
    }
}

#Preview {
    AnalyticsView()
        .environmentObject(AppState())
        .environmentObject(AuthManager())
}
