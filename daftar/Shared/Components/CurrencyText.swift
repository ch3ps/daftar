//
//  CurrencyText.swift
//  daftar
//
//  Formatted currency display
//

import SwiftUI

struct CurrencyText: View {
    let amount: Decimal
    var currencyCode: String = "QAR"
    var showSign: Bool = false
    var size: Size = .medium
    
    enum Size {
        case small
        case medium
        case large
        case extraLarge
        
        var font: Font {
            switch self {
            case .small: return .caption
            case .medium: return .body
            case .large: return .title2
            case .extraLarge: return .largeTitle
            }
        }
        
        var weight: Font.Weight {
            switch self {
            case .small: return .regular
            case .medium: return .medium
            case .large: return .semibold
            case .extraLarge: return .bold
            }
        }
    }
    
    var body: some View {
        Text(formattedAmount)
            .font(size.font)
            .fontWeight(size.weight)
    }
    
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        
        // Use QR symbol for QAR
        if currencyCode == "QAR" {
            formatter.currencySymbol = "QR "
        }
        
        let value = amount as NSDecimalNumber
        var result = formatter.string(from: value) ?? "QR \(amount)"
        
        if showSign && amount > 0 {
            result = "+" + result
        }
        
        return result
    }
}

// MARK: - Convenience Initializers
extension CurrencyText {
    init(_ amount: Decimal) {
        self.amount = amount
    }
    
    func size(_ size: Size) -> CurrencyText {
        var text = self
        text.size = size
        return text
    }
    
    func showSign(_ show: Bool) -> CurrencyText {
        var text = self
        text.showSign = show
        return text
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        CurrencyText(245.50).size(.small)
        CurrencyText(245.50).size(.medium)
        CurrencyText(245.50).size(.large)
        CurrencyText(1245.50).size(.extraLarge)
        CurrencyText(-50.00).size(.medium)
        CurrencyText(50.00).size(.medium).showSign(true)
    }
    .padding()
}
