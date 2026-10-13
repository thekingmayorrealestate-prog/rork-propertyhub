import SwiftUI

/// Booking/inquiry detail. Adapts its actions for the requester, the agent, or an administrator.
struct BookingDetailView: View {
    let bookingID: UUID

    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    @State private var showCancel = false
    @State private var showDecline = false
    @State private var showAccept = false
    @State private var agentNote = ""
    @State private var showPayment = false
    @State private var paymentAmount = ""
    @State private var showHotelCancel = false

    var body: some View {
        Group {
            if let booking = store.booking(bookingID) {
                content(booking)
            } else {
                ContentUnavailableView("Booking not found", systemImage: "calendar.badge.exclamationmark")
            }
        }
        .screenBackground()
        .navigationTitle("Request details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func content(_ booking: Booking) -> some View {
        let listing = store.listing(booking.listingID)
        let isAgent = booking.agentID == store.currentUserID
        let isRequester = booking.userID == store.currentUserID
        let payments = store.payments(for: booking.id)
        let hasPaid = payments.contains { $0.status == .paid }

        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let listing {
                    NavigationLink(value: Route.listing(listing.id)) {
                        HStack(spacing: 14) {
                            ListingPhoto(name: listing.imageNames.first)
                                .frame(width: 88, height: 88)
                                .clipShape(.rect(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(listing.title).font(.headline).foregroundStyle(Theme.ink)
                                Text(listing.locationLine).font(.subheadline).foregroundStyle(Theme.muted)
                                PriceText(listing: listing, font: .subheadline.bold())
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                        }
                        .card(padding: 12)
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(booking.kind.title).font(.title3.bold()).foregroundStyle(Theme.ink)
                        Spacer()
                        StatusBadge(text: booking.status.title, tone: booking.status.tone, showsDot: true)
                    }
                    Divider()
                    if booking.kind == .hotelReservation {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Confirmation").font(.caption).foregroundStyle(Theme.muted)
                                Text(booking.confirmationCode).font(.title3.monospaced().bold()).foregroundStyle(Theme.primary).textSelection(.enabled)
                            }
                            Spacer()
                            Image(systemName: "qrcode").font(.system(size: 40)).foregroundStyle(Theme.ink.opacity(0.8))
                        }
                        .padding(12)
                        .background(Theme.primarySoft, in: .rect(cornerRadius: 12))
                        if let room = listing?.room(booking.roomTypeID) {
                            InfoRow(title: "Room", value: "\(booking.rooms) × \(room.name)")
                            InfoRow(title: "Beds", value: room.bedInfo)
                        }
                    }
                    if let checkIn = booking.checkIn, let checkOut = booking.checkOut {
                        InfoRow(title: "Check in", value: checkIn.formatted(.dateTime.weekday(.abbreviated).day().month().year()) + (listing?.hotel.map { " · from \($0.checkInTime)" } ?? ""))
                        InfoRow(title: "Check out", value: checkOut.formatted(.dateTime.weekday(.abbreviated).day().month().year()) + (listing?.hotel.map { " · by \($0.checkOutTime)" } ?? ""))
                        InfoRow(title: "Stay", value: booking.detailSummary)
                    }
                    if let hotel = listing?.hotel, booking.kind == .hotelReservation {
                        InfoRow(title: "Cancellation", value: hotel.policy.title)
                    }
                    if let viewing = booking.viewingDate {
                        InfoRow(title: "Viewing", value: viewing.formatted(.dateTime.weekday(.abbreviated).day().month().hour().minute()))
                    }
                    InfoRow(title: "Requested", value: booking.createdAt.formatted(.dateTime.day().month().year().hour().minute()))
                    if isAgent || store.isAdmin {
                        InfoRow(title: "Requested by", value: store.account(booking.userID)?.name ?? "User")
                        InfoRow(title: "Phone", value: store.account(booking.userID)?.phone ?? "—")
                    }
                    if !booking.message.isEmpty {
                        Divider()
                        Text("Message").font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
                        Text(booking.message).font(.body).foregroundStyle(Theme.ink)
                    }
                    if let note = booking.agentNote {
                        Divider()
                        Text("Note from agent").font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
                        Text(note).font(.body).foregroundStyle(Theme.ink)
                    }
                }
                .card()

                if !payments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Payments").font(.title3.bold()).foregroundStyle(Theme.ink)
                        VStack(spacing: 0) {
                            ForEach(payments) { payment in
                                NavigationLink(value: Route.receipt(payment.id)) { PaymentRow(payment: payment) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .card(padding: 4)
                    }
                }

                contactSection(booking, isAgent: isAgent)

                if isRequester, let listing, booking.kind.isStay, store.canReview(listing.id) {
                    ReviewsSection(listing: listing)
                }

                actions(booking, listing: listing, isAgent: isAgent, isRequester: isRequester, hasPaid: hasPaid)
            }
            .padding(16)
        }
        .confirmationDialog(booking.kind == .hotelReservation ? "Cancel this reservation?" : "Cancel this request?", isPresented: $showCancel, titleVisibility: .visible) {
            Button(booking.kind == .hotelReservation ? "Cancel reservation" : "Cancel request", role: .destructive) {
                if store.isAdmin && !isRequester { store.adminCancelBooking(booking.id) } else { store.cancelBooking(booking.id) }
            }
        } message: {
            Text(cancelMessage(booking, hasPaid: hasPaid, isRequester: isRequester))
        }
        .confirmationDialog("Cancel this guest's reservation?", isPresented: $showHotelCancel, titleVisibility: .visible) {
            Button("Cancel & refund guest", role: .destructive) { store.respond(to: booking.id, accept: false, note: "Cancelled by the hotel.") }
        } message: {
            Text("The guest is refunded in full and the rooms are released.")
        }
        .alert(booking.kind == .viewing ? "Confirm viewing" : "Accept request", isPresented: $showAccept) {
            TextField("Optional note to the requester", text: $agentNote)
            Button("Accept") { store.respond(to: booking.id, accept: true, note: agentNote) }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Decline request", isPresented: $showDecline) {
            TextField("Reason (optional)", text: $agentNote)
            Button("Decline", role: .destructive) { store.respond(to: booking.id, accept: false, note: agentNote) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(hasPaid ? "The guest's payment will be refunded automatically." : "")
        }
        .sheet(isPresented: $showPayment) {
            NavigationStack {
                CheckoutView(title: listing?.title ?? "Payment", amount: Int(paymentAmount) ?? listing?.price ?? 0) { method, last4 in
                    store.payForBooking(booking.id, amount: Int(paymentAmount) ?? listing?.price ?? 0, method: method, cardLast4: last4)
                    showPayment = false
                    return true
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Close") { showPayment = false } }
                }
            }
        }
    }

    @ViewBuilder
    private func contactSection(_ booking: Booking, isAgent: Bool) -> some View {
        let otherID = isAgent ? booking.userID : booking.agentID
        if let other = store.account(otherID), !store.isAdmin || isAgent {
            HStack(spacing: 12) {
                AvatarView(account: other, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(other.name).font(.headline).foregroundStyle(Theme.ink)
                    Text(isAgent ? (booking.kind == .hotelReservation ? "Guest" : "Requester") : (other.agencyName ?? "Agent")).font(.subheadline).foregroundStyle(Theme.muted)
                }
                Spacer()
                if let url = URL(string: "tel:\(other.phone.filter { $0.isNumber || $0 == "+" })") {
                    Link(destination: url) {
                        Image(systemName: "phone.fill")
                            .frame(width: 44, height: 44)
                            .background(Theme.primarySoft, in: .circle)
                    }
                    .accessibilityLabel("Call")
                }
                Button {
                    openChat(booking, isAgent: isAgent)
                } label: {
                    Image(systemName: "bubble.left.fill")
                        .frame(width: 44, height: 44)
                        .background(Theme.primarySoft, in: .circle)
                }
                .accessibilityLabel("Message")
            }
            .foregroundStyle(Theme.primary)
            .card(padding: 14)
        }
    }

    @ViewBuilder
    private func actions(_ booking: Booking, listing: Listing?, isAgent: Bool, isRequester: Bool, hasPaid: Bool) -> some View {
        VStack(spacing: 12) {
            if isAgent && booking.status == .pending {
                HStack(spacing: 12) {
                    Button("Decline") { agentNote = ""; showDecline = true }
                        .buttonStyle(SecondaryButtonStyle(tint: Theme.danger))
                    Button(booking.kind == .viewing ? "Confirm viewing" : "Accept") { agentNote = ""; showAccept = true }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            if isAgent && (booking.status == .confirmed || booking.status == .viewingScheduled) {
                Button(booking.kind == .hotelReservation ? "Mark as checked out" : "Mark as completed") { store.markCompleted(booking.id) }
                    .buttonStyle(SecondaryButtonStyle())
            }
            if isAgent && booking.kind == .hotelReservation && booking.status == .confirmed {
                Button("Cancel reservation", role: .destructive) { showHotelCancel = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            if isRequester && booking.status == .confirmed && !booking.kind.isStay && !hasPaid, let listing {
                Button {
                    paymentAmount = String(listing.category == .sale ? max(listing.price / 10, 1) : listing.price)
                    showPayment = true
                } label: {
                    Text(listing.category == .sale ? "Pay 10% deposit" : "Pay rent · \(listing.priceText)")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            if (isRequester || store.isAdmin) && booking.status.isOpen && (booking.checkOut ?? .distantFuture) > Date() {
                Button(booking.kind == .hotelReservation ? "Cancel reservation" : "Cancel request", role: .destructive) { showCancel = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    private func cancelMessage(_ booking: Booking, hasPaid: Bool, isRequester: Bool) -> String {
        guard hasPaid else { return "The agent will be notified." }
        guard booking.kind == .hotelReservation, isRequester else { return "Any payment will be refunded to the original method." }
        let preview = store.refundPreview(for: booking)
        let policy = store.listing(booking.listingID)?.hotel?.policy
        if preview.fraction >= 1 { return "Free cancellation: you'll be refunded \(Money.naira(preview.amount)) in full." }
        if preview.amount == 0 { return "Under the \(policy?.title.lowercased() ?? "hotel's") policy this reservation is non-refundable now." }
        return "Under the \(policy?.title.lowercased() ?? "hotel's") policy you'll be refunded \(Money.naira(preview.amount)) (\(Int(preview.fraction * 100))%)."
    }

    private func openChat(_ booking: Booking, isAgent: Bool) {
        if let existing = store.data.threads.first(where: { $0.listingID == booking.listingID && $0.userID == booking.userID }) {
            router.push(.chat(existing.id))
        } else if !isAgent, let listing = store.listing(booking.listingID), let id = try? store.openThread(for: listing) {
            router.push(.chat(id))
        } else if isAgent {
            router.push(.messages)
        }
    }
}

struct ReceiptView: View {
    let paymentID: UUID
    @Environment(AppStore.self) private var store

    var body: some View {
        Group {
            if let payment = store.payment(paymentID) {
                receipt(payment)
            } else {
                ContentUnavailableView("Receipt not found", systemImage: "doc.text")
            }
        }
        .screenBackground()
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func receipt(_ payment: Payment) -> some View {
        let listing = store.listing(payment.listingID)
        let payer = store.account(payment.userID)
        let text = """
        Homestead receipt #\(payment.reference)
        \(listing?.title ?? "Listing")
        Amount: \(Money.naira(payment.amount))
        Service fee: \(Money.naira(payment.serviceFee))
        Total: \(Money.naira(payment.total))
        Status: \(payment.status.title)
        Date: \(payment.createdAt.formatted(.dateTime.day().month().year().hour().minute()))
        """
        return ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    Image(systemName: payment.status == .paid ? "checkmark.seal.fill" : "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(payment.status == .paid ? Theme.primary : BadgeTone.info.foreground)
                    Text(Money.naira(payment.total))
                        .font(.system(size: 36, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    StatusBadge(text: payment.status.title, tone: payment.status.tone)
                }
                .padding(.top, 8)

                VStack(spacing: 12) {
                    InfoRow(title: "Receipt", value: "#\(payment.reference)")
                    InfoRow(title: listing?.isHotel == true ? "Hotel" : "Property", value: listing?.title ?? "—")
                    if let booking = store.booking(payment.bookingID), booking.kind == .hotelReservation {
                        InfoRow(title: "Confirmation", value: booking.confirmationCode)
                    }
                    InfoRow(title: "Paid by", value: payer?.name ?? "—")
                    InfoRow(title: "Date", value: payment.createdAt.formatted(.dateTime.day().month().year().hour().minute()))
                    InfoRow(title: "Method", value: payment.method.title + (payment.cardLast4.map { " •••• \($0)" } ?? ""))
                    Divider()
                    InfoRow(title: "Amount", value: Money.naira(payment.amount))
                    InfoRow(title: "Service fee", value: Money.naira(payment.serviceFee))
                    HStack {
                        Text("Total").font(.headline)
                        Spacer()
                        Text(Money.naira(payment.total)).font(.headline).monospacedDigit()
                    }
                    .foregroundStyle(Theme.ink)
                    if payment.status == .refunded {
                        InfoRow(title: "Refunded", value: Money.naira(payment.refundedAmount ?? payment.total))
                    }
                }
                .card()

                ShareLink(item: text) {
                    Label("Share receipt", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(16)
        }
    }
}

struct PaymentsListView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(store.myPayments) { payment in
                    NavigationLink(value: Route.receipt(payment.id)) { PaymentRow(payment: payment) }
                        .buttonStyle(.plain)
                    if payment.id != store.myPayments.last?.id { Divider().padding(.leading, 76) }
                }
            }
            .card(padding: 4)
            .padding(16)
            if store.myPayments.isEmpty {
                ContentUnavailableView("No payments yet", systemImage: "creditcard")
            }
        }
        .screenBackground()
        .navigationTitle("Payments & receipts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
