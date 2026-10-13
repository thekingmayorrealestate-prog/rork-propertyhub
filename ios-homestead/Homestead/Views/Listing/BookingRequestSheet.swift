import SwiftUI

/// Shortlet booking: choose dates and guests, check availability, then pay securely.
struct BookingRequestSheet: View {
    let listing: Listing

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var checkIn: Date = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    @State private var checkOut: Date = Calendar.current.date(byAdding: .day, value: 3, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    @State private var guests: Int = 2
    @State private var message: String = ""
    @State private var showCheckout = false
    @State private var confirmedBooking: Booking?
    @State private var errorMessage: String?

    private var nights: Int {
        let cal = Calendar.current
        return max(cal.dateComponents([.day], from: cal.startOfDay(for: checkIn), to: cal.startOfDay(for: checkOut)).day ?? 0, 0)
    }

    private var isAvailable: Bool {
        nights > 0 && store.isAvailable(listingID: listing.id, from: checkIn, to: checkOut)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let confirmedBooking {
                    BookingSuccessView(
                        title: "Request sent!",
                        message: "Your payment is secured. \(store.account(listing.agentID)?.firstName ?? "The host") will confirm your stay shortly — we'll notify you.",
                        detail: confirmedBooking.dateSummary
                    ) { dismiss() }
                } else {
                    form
                }
            }
            .navigationTitle(confirmedBooking == nil ? "Request to book" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if confirmedBooking == nil {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                }
            }
            .navigationDestination(isPresented: $showCheckout) {
                CheckoutView(title: listing.title, amount: listing.quote(nights: nights).total) { method, last4 in
                    do {
                        let booking = try store.bookShortlet(listing: listing, checkIn: checkIn, checkOut: checkOut, guests: guests, message: message, method: method, cardLast4: last4)
                        showCheckout = false
                        withAnimation(.spring) { confirmedBooking = booking }
                        return true
                    } catch {
                        errorMessage = error.localizedDescription
                        return false
                    }
                }
            }
            .alert("Couldn't complete booking", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled(showCheckout)
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

                VStack(spacing: 0) {
                    DatePicker("Check in", selection: $checkIn, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                        .padding(.vertical, 10)
                    Divider()
                    DatePicker("Check out", selection: $checkOut, in: (Calendar.current.date(byAdding: .day, value: 1, to: checkIn) ?? checkIn)..., displayedComponents: .date)
                        .padding(.vertical, 10)
                    Divider()
                    Stepper(value: $guests, in: 1...max(listing.sleeps, 1)) {
                        HStack {
                            Text("Guests")
                            Spacer()
                            Text("\(guests)").monospacedDigit().foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(.vertical, 10)
                }
                .foregroundStyle(Theme.ink)
                .card(padding: 14)
                .onChange(of: checkIn) { _, newValue in
                    if checkOut <= newValue {
                        checkOut = Calendar.current.date(byAdding: .day, value: 1, to: newValue) ?? newValue
                    }
                }

                availabilityBanner

                VStack(alignment: .leading, spacing: 6) {
                    Text("Message to host").font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
                    TextField("Arrival time, special requests…", text: $message, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(14)
                        .background(Theme.surface, in: .rect(cornerRadius: 14))
                }

                priceBreakdown

                Button("Continue to payment") { showCheckout = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!isAvailable)

                Label("You won't be charged if the host declines — payments are refunded automatically.", systemImage: "lock.shield.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            .padding(16)
        }
        .screenBackground()
    }

    @ViewBuilder
    private var availabilityBanner: some View {
        let available = isAvailable
        HStack(spacing: 8) {
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
            Text(available ? "Available for \(nights) night\(nights == 1 ? "" : "s")" : (nights == 0 ? "Choose at least one night" : "Not available for these dates"))
                .font(.subheadline.weight(.medium))
            Spacer()
        }
        .foregroundStyle(available ? BadgeTone.success.foreground : BadgeTone.danger.foreground)
        .padding(12)
        .background(available ? BadgeTone.success.background : BadgeTone.danger.background, in: .rect(cornerRadius: 12))
        .animation(.snappy, value: available)
    }

    private var priceBreakdown: some View {
        let quote = listing.quote(nights: max(nights, 1))
        return VStack(spacing: 10) {
            InfoRow(title: "\(Money.naira(listing.price)) × \(max(nights, 1)) night\(nights == 1 ? "" : "s")", value: Money.naira(quote.subtotal))
            InfoRow(title: "Service fee (5%)", value: Money.naira(quote.fee))
            Divider()
            HStack {
                Text("Total").font(.headline)
                Spacer()
                Text(Money.naira(quote.total)).font(.headline).monospacedDigit()
            }
            .foregroundStyle(Theme.ink)
        }
        .card()
    }
}

struct BookingSuccessView: View {
    let title: String
    let message: String
    var detail: String?
    let onDone: () -> Void

    @State private var animate = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle().fill(Theme.primarySoft).frame(width: 120, height: 120).scaleEffect(animate ? 1 : 0.6)
                Image(systemName: "checkmark")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(Theme.primary)
                    .symbolEffect(.bounce, value: animate)
            }
            Text(title).font(.title.bold()).foregroundStyle(Theme.ink)
            Text(message)
                .font(.body)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            if let detail {
                Text(detail)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.primarySoft, in: .capsule)
            }
            Spacer()
            Button("Done", action: onDone)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 16)
        }
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .screenBackground()
        .sensoryFeedback(.success, trigger: animate)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { animate = true }
        }
    }
}
