import SwiftUI
import Charts

struct AgentListingManageView: View {
    let listingID: UUID

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showEditor = false
    @State private var showDelete = false

    var body: some View {
        Group {
            if let listing = store.listing(listingID) {
                content(listing)
            } else {
                ContentUnavailableView("Listing removed", systemImage: "house.slash")
            }
        }
        .screenBackground()
        .navigationTitle("Manage listing")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func content(_ listing: Listing) -> some View {
        let requests = store.bookings(for: listing.id)
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Color.clear
                    .frame(height: 200)
                    .overlay { ListingPhoto(name: listing.imageNames.first) }
                    .clipShape(.rect(cornerRadius: Theme.cardRadius))
                    .overlay(alignment: .topLeading) {
                        StatusBadge(text: listing.status.title, tone: listing.status.tone, showsDot: true).padding(12)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.title).font(.title.bold()).foregroundStyle(Theme.ink)
                    Text(listing.locationLine).font(.subheadline).foregroundStyle(Theme.muted)
                    PriceText(listing: listing)
                }

                if let reason = listing.rejectionReason, listing.status == .rejected {
                    Label(reason, systemImage: "xmark.octagon.fill")
                        .font(.subheadline)
                        .foregroundStyle(BadgeTone.danger.foreground)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BadgeTone.danger.background, in: .rect(cornerRadius: 14))
                } else if listing.status == .pending {
                    Label("Under review — usually approved within 24 hours.", systemImage: "clock.fill")
                        .font(.subheadline)
                        .foregroundStyle(BadgeTone.warning.foreground)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BadgeTone.warning.background, in: .rect(cornerRadius: 14))
                }

                HStack(spacing: 0) {
                    metric(listing.totalViews, "views")
                    Divider().frame(height: 40)
                    if listing.isHotel {
                        metric(store.roomsBooked(listing: listing, on: Date()), "booked tonight")
                        Divider().frame(height: 40)
                        metric(requests.filter { $0.kind == .hotelReservation && $0.status != .cancelled }.count, "reservations")
                    } else {
                        metric(requests.filter { !$0.kind.isStay }.count, "inquiries")
                        Divider().frame(height: 40)
                        metric(requests.filter { $0.kind == .shortletBooking }.count, "bookings")
                    }
                }
                .card(padding: 14)

                if listing.totalViews > 0 {
                    Chart(weekPoints(listing.weeklyViews)) { p in
                        LineMark(x: .value("Day", p.label), y: .value("Views", p.value))
                            .foregroundStyle(Theme.primary)
                            .interpolationMethod(.catmullRom)
                        AreaMark(x: .value("Day", p.label), y: .value("Views", p.value))
                            .foregroundStyle(Theme.primary.opacity(0.12))
                            .interpolationMethod(.catmullRom)
                    }
                    .frame(height: 130)
                    .card()
                }

                if listing.status == .live || listing.status == .unavailable {
                    Toggle(isOn: Binding(
                        get: { listing.status == .live },
                        set: { store.setAvailability(listing.id, available: $0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Available").font(.headline).foregroundStyle(Theme.ink)
                            Text(listing.isHotel ? "Turn off to pause all new reservations for this hotel." : "Turn off to hide from search while it's occupied or under offer.")
                                .font(.footnote)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .tint(Theme.primary)
                    .card()
                }

                VStack(spacing: 0) {
                    NavigationLink(value: Route.listing(listing.id)) {
                        manageRow("eye", "Preview listing")
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 52)
                    if listing.isHotel {
                        NavigationLink(value: Route.hotelRooms(listing.id)) {
                            manageRow("bed.double", "Rooms, rates & availability")
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 52)
                    }
                    Button { showEditor = true } label: { manageRow("pencil", listing.isHotel ? "Edit hotel profile & photos" : "Edit details & photos") }
                        .buttonStyle(.plain)
                    Divider().padding(.leading, 52)
                    NavigationLink(value: Route.agentRequests) {
                        manageRow("tray.full", listing.isHotel ? "Reservations" : "Inquiries & bookings")
                    }
                    .buttonStyle(.plain)
                }
                .card(padding: 4)

                if listing.status != .pending {
                    Text(listing.isHotel ? "Room rates and availability update instantly. Hotel profile edits are re-reviewed before going live again." : "Edits are re-reviewed by our team before going live again.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }

                Button("Delete listing", role: .destructive) { showDelete = true }
                    .font(.headline)
                    .foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .padding(16)
        }
        .sheet(isPresented: $showEditor) { ListingEditorView(existing: listing) }
        .confirmationDialog("Delete this listing?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                dismiss()
                store.deleteListing(listing.id)
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    private func metric(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value.formatted()).font(.title2.bold()).monospacedDigit().foregroundStyle(Theme.ink)
            Text(label).font(.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func manageRow(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).foregroundStyle(Theme.primary).frame(width: 26)
            Text(title).foregroundStyle(Theme.ink)
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
        .contentShape(.rect)
    }
}
