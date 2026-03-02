//
//  OnboardingView.swift
//  daftar
//
//  Onboarding flow for new users (store or customer)
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    
    let userType: UserType
    let onComplete: () -> Void
    
    @State private var currentPage = 0
    
    var pages: [OnboardingPage] {
        userType == .store ? storePages : customerPages
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button {
                    onComplete()
                } label: {
                    Text(appState.localized("Skip", arabic: "تخطي"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            
            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Page indicator + button
            VStack(spacing: 24) {
                // Dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color(.systemGray4))
                            .frame(width: 8, height: 8)
                    }
                }
                
                // Continue / Get Started button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        onComplete()
                    }
                } label: {
                    Text(currentPage == pages.count - 1 ?
                         appState.localized("Get Started", arabic: "ابدأ") :
                         appState.localized("Continue", arabic: "متابعة"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Store Onboarding Pages
    private var storePages: [OnboardingPage] {
        [
            OnboardingPage(
                icon: "storefront.fill",
                iconColor: .accentColor,
                title: appState.localized("Welcome to Daftar", arabic: "مرحباً بك في دفتر"),
                subtitle: appState.localized(
                    "The simple way to track what your customers owe you.",
                    arabic: "الطريقة البسيطة لتتبع ما يدين به عملاؤك."
                )
            ),
            OnboardingPage(
                icon: "person.badge.plus",
                iconColor: .blue,
                title: appState.localized("Add Your Customers", arabic: "أضف عملاءك"),
                subtitle: appState.localized(
                    "Add customers by name and phone. They'll get notified when you add bills.",
                    arabic: "أضف العملاء بالاسم والهاتف. سيتم إخطارهم عند إضافة الفواتير."
                )
            ),
            OnboardingPage(
                icon: "doc.text.fill",
                iconColor: .green,
                title: appState.localized("Quick Bill Entry", arabic: "إدخال فاتورة سريع"),
                subtitle: appState.localized(
                    "Just enter the amount and tap add. It's that fast.",
                    arabic: "فقط أدخل المبلغ واضغط إضافة. بهذه السرعة."
                )
            ),
            OnboardingPage(
                icon: "square.and.arrow.up",
                iconColor: .orange,
                title: appState.localized("Share Your Code", arabic: "شارك رمزك"),
                subtitle: appState.localized(
                    "Customers can join your store using your unique code. They'll see their bills too.",
                    arabic: "يمكن للعملاء الانضمام لمتجرك باستخدام رمزك الفريد. سيرون فواتيرهم أيضاً."
                )
            )
        ]
    }
    
    // MARK: - Customer Onboarding Pages
    private var customerPages: [OnboardingPage] {
        [
            OnboardingPage(
                icon: "person.fill",
                iconColor: .accentColor,
                title: appState.localized("Welcome to Daftar", arabic: "مرحباً بك في دفتر"),
                subtitle: appState.localized(
                    "See what you owe at all your shops in one place.",
                    arabic: "شاهد ما تدين به في جميع متاجرك في مكان واحد."
                )
            ),
            OnboardingPage(
                icon: "qrcode.viewfinder",
                iconColor: .blue,
                title: appState.localized("Join a Store", arabic: "انضم لمتجر"),
                subtitle: appState.localized(
                    "Ask your store for their code and join to see your bills.",
                    arabic: "اطلب الرمز من متجرك وانضم لرؤية فواتيرك."
                )
            ),
            OnboardingPage(
                icon: "bell.badge.fill",
                iconColor: .orange,
                title: appState.localized("Get Notified", arabic: "استلم الإشعارات"),
                subtitle: appState.localized(
                    "You'll be notified when stores add new bills to your account.",
                    arabic: "ستُخطر عندما تضيف المتاجر فواتير جديدة لحسابك."
                )
            ),
            OnboardingPage(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                title: appState.localized("Clear Record", arabic: "سجل واضح"),
                subtitle: appState.localized(
                    "Both you and the store see the same numbers. No more disputes.",
                    arabic: "أنت والمتجر ترون نفس الأرقام. لا مزيد من النزاعات."
                )
            )
        ]
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: page.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(page.iconColor)
            }
            
            // Title
            Text(page.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            
            // Subtitle
            Text(page.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(userType: .store) {}
        .environmentObject(AppState())
}
