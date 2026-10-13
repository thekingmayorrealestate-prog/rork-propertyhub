import SwiftUI

struct BookingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var segment: BookingSegment = .shortlets

    var body: some View {
        Group {
            if store.isSignedIn {
                content
            } else {
                SignInPrompt(title: "Your bookings live here", message: "Track hotel reservations, shortlet stays, rental inquiries, viewings and payment receipts in one place.", symbol: "calendar")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
        .navigationTitle("Bookings")
        .toolbar {
            if store.isSignedIn {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Route.notifications) {
                        Image(systemName: store.unreadNotificationCount > 0 ? "bell.badge" : "bell")
                    }
                    .accessibilityLabel("Notifications")
                }
            }
        }
    }

    private var bookings: [Booking] {
        store.myBookings.filter { $0.category == segment.category }
    }

    private var payments: [Payment] {
        let ids = Set(store.myBookings.filter { $0.category == segment.category }.map(\.id))
        return store.myPayments.filter { ids.contains($0.bookingID) }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Track reservations, bookings, inquiries and payments.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 16)

                Picker("Type", selection: $segment) {
                    ForEach(BookingSegment.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                if segment == .shortlets || segment == .hotels {
                    let upcoming = bookings.filter(\.isUpcoming)
                    let past = bookings.filter { !$0.isUpcoming }
                    bookingList(title: segment == .hotels ? "Upcoming Reservations" : "Upcoming Stays", items: upcoming,
                                empty: segment == .hotels ? "No upcoming hotel reservations. Find a hotel from the Home tab." : "No upcoming shortlet stays.")
                    if !past.isEmpty {
                        bookingList(title: "Past & Cancelled", items: past, empty: "")
                    }
                } else {
                    bookingList(title: "My Inquiries", items: bookings, empty: "No inquiries yet. Send one from any listing.")
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Payments", actionTitle: store.myPayments.isEmpty ? nil : "All receipts") {
                        router.push(.payments)
                    }
                    if payments.isEmpty {
                        emptyCard("No payments for \(segment.title.lowercased()).")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(payments) { payment in
                                NavigationLink(value: Route.receipt(payment.id)) {
                                    PaymentRow(payment: payment)
                                }
                                .buttonStyle(.plain)
                                if payment.id != payments.last?.id {
                                    Divider().padding(.leading, 76)
                                }
                            }
                        }
                        .card(padding: 4)
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.bottom, 16)
            .animation(.snappy, value: segment)
        }
    }

    private func bookingList(title: String, items: [Booking], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title)
            if items.isEmpty {
                emptyCard(empty)
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { booking in
                        NavigationLink(value: Route.booking(booking.id)) {
                            BookingRow(booking: booking)
                        }
                        .buttonStyle(.plain)
                        if booking.id != items.last?.id {
                            Divider().padding(.leading, 104)
                        }
                    }
                }
                .card(padding: 4)
                .padding(.horizontal, 16)
            }
        }
    }

    private func emptyCard(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .padding(.horizontal, 16)
    }
}

struct BookingRow: View {
    let booking: Booking
    var showsRequester: Bool = false

    @Environment(AppStore.self) private var store

    var body: some View {
        let listing = store.listing(booking.listingID)
        HStack(spacing: 14) {
            ListingPhoto(name: listing?.imageNames.first)
                .frame(width: 78, height: 78)
                .clipShape(.rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(listing?.title ?? "Removed listing")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if showsRequester {
                    Text("\(store.account(booking.userID)?.shortName ?? "User") · \(booking.kind.title)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink.opacity(0.8))
                        .lineLimit(1)
                }
                Text(booking.dateSummary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                if let room = listing?.room(booking.roomTypeID) {
                    Text("\(booking.rooms) × \(room.name)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink.opacity(0.8))
                        .lineLimit(1)
                } else if !showsRequester {
                    Text(booking.detailSummary)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            StatusBadge(text: booking.status.title, tone: booking.status.tone)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(10)
        .contentShape(.rect)
    }
}

struct PaymentRow: View {
    let payment: Payment
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.text")
                .font(.title3)
                .foregroundStyle(Theme.ink)
                .frame(width: 50, height: 50)
                .background(payment.status == .paid ? Theme.primarySoft : Theme.sand, in: .circle)
            VStack(alignment: .leading, spacing: 3) {
                Text(Money.naira(payment.total))
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Text("\(store.listing(payment.listingID)?.title ?? "Listing") · \(payment.createdAt.formatted(.dateTime.day().month(.abbreviated).year()))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                Text("Receipt #\(payment.reference)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 4)
            StatusBadge(text: payment.status.title, tone: payment.status.tone)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(12)
        .contentShape(.rect)
    }
}
