import SwiftUI

/// Secure checkout supporting card, bank transfer and USSD.
/// `onComplete` records the payment and returns whether it succeeded.
struct CheckoutView: View {
    let title: String
    let amount: Int
    let onComplete: (PaymentMethod, String?) -> Bool

    @State private var method: PaymentMethod = .card
    @State private var cardName = ""
    @State private var cardNumber = ""
    @State private var expiry = ""
    @State private var cvv = ""
    @State private var isProcessing = false
    @State private var transferConfirmed = false

    private let virtualAccount = "9920 4417 85"

    private var digits: String { cardNumber.filter(\.isNumber) }

    private var isCardValid: Bool {
        let exp = expiry.filter(\.isNumber)
        return !cardName.trimmingCharacters(in: .whitespaces).isEmpty && (15...19).contains(digits.count) &&
            exp.count == 4 && (Int(exp.prefix(2)) ?? 0) >= 1 && (Int(exp.prefix(2)) ?? 0) <= 12 &&
            (3...4).contains(cvv.filter(\.isNumber).count)
    }

    private var canPay: Bool {
        switch method {
        case .card: isCardValid
        case .transfer, .ussd: transferConfirmed
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Amount due").font(.subheadline).foregroundStyle(Theme.muted)
                    Text(Money.naira(amount))
                        .font(.system(size: 38, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    Text(title).font(.subheadline).foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                Picker("Method", selection: $method) {
                    ForEach(PaymentMethod.allCases) { m in
                        Text(m.title).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: method) { _, _ in transferConfirmed = false }

                switch method {
                case .card: cardForm
                case .transfer: transferPanel
                case .ussd: ussdPanel
                }

                Button {
                    pay()
                } label: {
                    if isProcessing {
                        ProgressView().tint(.white)
                    } else {
                        Label("Pay \(Money.naira(amount))", systemImage: "lock.fill")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canPay || isProcessing)

                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill").foregroundStyle(Theme.primary)
                    Text("Payments are encrypted and held securely until your booking is confirmed.")
                }
                .font(.footnote)
                .foregroundStyle(Theme.muted)
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("Secure checkout")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isProcessing)
        .sensoryFeedback(.selection, trigger: method)
    }

    private var cardForm: some View {
        VStack(spacing: 14) {
            FieldBox(label: "Name on card") {
                TextField("Ada Nwosu", text: $cardName)
                    .textContentType(.name)
            }
            FieldBox(label: "Card number") {
                HStack {
                    TextField("5399 8300 0000 4081", text: $cardNumber)
                        .keyboardType(.numberPad)
                        .textContentType(.creditCardNumber)
                        .onChange(of: cardNumber) { _, newValue in
                            let d = String(newValue.filter(\.isNumber).prefix(19))
                            let grouped = stride(from: 0, to: d.count, by: 4).map { i -> String in
                                let start = d.index(d.startIndex, offsetBy: i)
                                let end = d.index(start, offsetBy: min(4, d.count - i))
                                return String(d[start..<end])
                            }.joined(separator: " ")
                            if grouped != newValue { cardNumber = grouped }
                        }
                    Image(systemName: "creditcard").foregroundStyle(Theme.muted)
                }
            }
            HStack(spacing: 12) {
                FieldBox(label: "Expiry") {
                    TextField("MM/YY", text: $expiry)
                        .keyboardType(.numberPad)
                        .onChange(of: expiry) { _, newValue in
                            let d = String(newValue.filter(\.isNumber).prefix(4))
                            let formatted = d.count > 2 ? "\(d.prefix(2))/\(d.dropFirst(2))" : d
                            if formatted != newValue { expiry = formatted }
                        }
                }
                FieldBox(label: "CVV") {
                    SecureField("123", text: $cvv)
                        .keyboardType(.numberPad)
                        .onChange(of: cvv) { _, newValue in
                            let d = String(newValue.filter(\.isNumber).prefix(4))
                            if d != newValue { cvv = d }
                        }
                }
            }
        }
    }

    private var transferPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transfer exactly \(Money.naira(amount)) to:").font(.subheadline).foregroundStyle(Theme.muted)
            InfoRow(title: "Bank", value: "Homestead Escrow · Wema Bank")
            InfoRow(title: "Account number", value: virtualAccount)
            InfoRow(title: "Account name", value: "Homestead Payments Ltd")
            Button {
                UIPasteboard.general.string = virtualAccount.replacingOccurrences(of: " ", with: "")
            } label: {
                Label("Copy account number", systemImage: "doc.on.doc")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Theme.accent)
            Toggle("I've sent the money", isOn: $transferConfirmed)
                .tint(Theme.primary)
        }
        .foregroundStyle(Theme.ink)
        .card()
    }

    private var ussdPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dial this code from the phone linked to your bank account:")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            Text("*737*000*\(amount)#")
                .font(.title3.monospaced().bold())
                .foregroundStyle(Theme.ink)
                .textSelection(.enabled)
            Toggle("I've completed the USSD payment", isOn: $transferConfirmed)
                .tint(Theme.primary)
        }
        .foregroundStyle(Theme.ink)
        .card()
    }

    private func pay() {
        isProcessing = true
        let last4 = method == .card ? String(digits.suffix(4)) : nil
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            let success = onComplete(method, last4)
            if !success { isProcessing = false }
        }
    }
}
