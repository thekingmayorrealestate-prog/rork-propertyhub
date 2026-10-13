import SwiftUI

/// Rental/purchase inquiry or viewing request sent to the listing's agent.
struct InquirySheet: View {
    let listing: Listing
    let initialKind: RequestKind

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var kind: RequestKind = .rentalInquiry
    @State private var message = ""
    @State private var viewingDate: Date = {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
        return Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }()
    @State private var sent = false
    @State private var errorMessage: String?

    private var inquiryKind: RequestKind {
        listing.category == .sale ? .purchaseInquiry : .rentalInquiry
    }

    var body: some View {
        NavigationStack {
            Group {
                if sent {
                    BookingSuccessView(
                        title: kind == .viewing ? "Viewing requested" : "Inquiry sent",
                        message: "\(store.account(listing.agentID)?.firstName ?? "The agent") usually replies within a few hours. Track it in Bookings.",
                        detail: kind == .viewing ? viewingDate.formatted(.dateTime.weekday(.wide).day().month().hour().minute()) : nil
                    ) { dismiss() }
                } else {
                    form
                }
            }
            .navigationTitle(sent ? "" : (kind == .viewing ? "Request a viewing" : "Send an inquiry"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !sent {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                }
            }
            .alert("Couldn't send", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onAppear {
            kind = initialKind == .viewing ? .viewing : inquiryKind
            if message.isEmpty { message = defaultMessage }
        }
    }

    private var defaultMessage: String {
        listing.category == .sale
            ? "Hello, I'm interested in \(listing.title). Is the price negotiable and what documents are available?"
            : "Hello, I'm interested in renting \(listing.title). Is it still available?"
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    ListingPhoto(name: listing.imageNames.first)
                        .frame(width: 72, height: 72)
                        .clipShape(.rect(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(listing.title).font(.headline).foregroundStyle(Theme.ink)
                        Text(listing.locationLine).font(.subheadline).foregroundStyle(Theme.muted)
                        PriceText(listing: listing, font: .subheadline.bold())
                    }
                }

                Picker("Type", selection: $kind) {
                    Text("Inquiry").tag(inquiryKind)
                    Text("Viewing").tag(RequestKind.viewing)
                }
                .pickerStyle(.segmented)

                if kind == .viewing {
                    DatePicker("Preferred date & time", selection: $viewingDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .foregroundStyle(Theme.ink)
                        .card(padding: 14)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Message").font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
                    TextField("Your message", text: $message, axis: .vertical)
                        .lineLimit(4...8)
                        .padding(14)
                        .background(Theme.surface, in: .rect(cornerRadius: 14))
                }

                if let phone = store.currentUser?.phone, !phone.isEmpty {
                    Label("The agent will see your phone number: \(phone)", systemImage: "phone.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }

                Button(kind == .viewing ? "Request viewing" : "Send inquiry") {
                    do {
                        try store.submitInquiry(listing: listing, kind: kind, message: message, viewingDate: viewingDate)
                        withAnimation(.spring) { sent = true }
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
        }
        .screenBackground()
    }
}
