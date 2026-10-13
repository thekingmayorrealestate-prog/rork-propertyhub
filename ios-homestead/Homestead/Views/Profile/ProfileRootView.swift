import SwiftUI

/// Profile tab: guest welcome, user dashboard, agent dashboard, or admin panel depending on role.
struct ProfileRootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        switch store.currentUser?.role {
        case .none: GuestProfileView()
        case .user: UserProfileView()
        case .agent: AgentDashboardView()
        case .hotelOwner: HotelOwnerDashboardView()
        case .admin: AdminDashboardView()
        }
    }
}

struct GuestProfileView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Color.clear
                    .frame(height: 240)
                    .overlay { ListingPhoto(name: "luxury_duplex_terrace") }
                    .overlay { Color.black.opacity(0.35) }
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Welcome to Homestead")
                                .font(.title.bold())
                            Text("Rent apartments, book shortlets and hotels, and buy property from verified partners across Nigeria.")
                                .font(.subheadline)
                                .opacity(0.9)
                        }
                        .foregroundStyle(.white)
                        .padding(20)
                    }
                    .clipShape(.rect(cornerRadius: 24))

                Button("Sign in or create account") { router.presentAuth() }
                    .buttonStyle(PrimaryButtonStyle())

                VStack(alignment: .leading, spacing: 14) {
                    feature("heart.fill", "Save favourites", "Build a shortlist and compare homes side by side.")
                    feature("calendar", "Book & track", "Hotel rooms, shortlets, viewings and inquiries in one place.")
                    feature("lock.shield.fill", "Pay securely", "Card, transfer or USSD with instant receipts.")
                }
                .card()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Agent, landlord, seller or hotel owner?").font(.headline).foregroundStyle(Theme.ink)
                    Text("Create a professional profile, list properties or hotels, and manage inquiries, rooms and reservations from your own dashboard.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                    Button("List your property") { router.presentAuth() }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .card()
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("Profile")
    }

    private func feature(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.primary)
                .frame(width: 36, height: 36)
                .background(Theme.primarySoft, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(text).font(.subheadline).foregroundStyle(Theme.muted)
            }
        }
    }
}

struct UserProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var showEdit = false
    @State private var showBecomeAgent = false
    @State private var showBecomeHotel = false

    var body: some View {
        let user = store.currentUser
        let bookings = store.myBookings
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    AvatarView(account: user, size: 68)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(user?.name ?? "").font(.title2.bold()).foregroundStyle(Theme.ink)
                        Text(user?.email ?? "").font(.subheadline).foregroundStyle(Theme.muted)
                        Text("Member since \(user?.createdAt.formatted(.dateTime.month(.wide).year()) ?? "")")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                }

                HStack(spacing: 0) {
                    stat("\(store.favoriteListings.count)", "Saved")
                    Divider().frame(height: 40)
                    stat("\(bookings.filter { $0.kind.isStay && $0.isUpcoming }.count)", "Upcoming stays")
                    Divider().frame(height: 40)
                    stat("\(bookings.filter { !$0.kind.isStay && $0.status.isOpen }.count)", "Open inquiries")
                }
                .card(padding: 14)

                VStack(spacing: 0) {
                    row("calendar", "Reservations, bookings & inquiries") { router.selectedTab = .bookings }
                    Divider().padding(.leading, 52)
                    row("heart", "Saved homes & hotels") { router.selectedTab = .saved }
                    Divider().padding(.leading, 52)
                    row("bubble.left.and.bubble.right", "Messages", badge: store.unreadMessageCount) { router.push(.messages) }
                    Divider().padding(.leading, 52)
                    row("bell", "Notifications", badge: store.unreadNotificationCount) { router.push(.notifications) }
                    Divider().padding(.leading, 52)
                    row("creditcard", "Payments & receipts") { router.push(.payments) }
                }
                .card(padding: 4)

                VStack(spacing: 0) {
                    row("person.text.rectangle", "Edit profile") { showEdit = true }
                    Divider().padding(.leading, 52)
                    row("building.2", "Become an agent, landlord or seller") { showBecomeAgent = true }
                    Divider().padding(.leading, 52)
                    row("bed.double", "List your hotel") { showBecomeHotel = true }
                }
                .card(padding: 4)

                Button("Sign out", role: .destructive) { store.signOut() }
                    .font(.headline)
                    .foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("Profile")
        .sheet(isPresented: $showEdit) { EditProfileSheet() }
        .sheet(isPresented: $showBecomeAgent) { BecomeAgentSheet() }
        .sheet(isPresented: $showBecomeHotel) { BecomeHotelOwnerSheet() }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.bold()).monospacedDigit().foregroundStyle(Theme.ink)
            Text(label).font(.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ symbol: String, _ title: String, badge: Int = 0, action: @escaping () -> Void) -> some View {
        ProfileRow(symbol: symbol, title: title, badge: badge, action: action)
    }
}

struct ProfileRow: View {
    let symbol: String
    let title: String
    var badge: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.body)
                    .foregroundStyle(Theme.primary)
                    .frame(width: 26)
                Text(title).font(.body).foregroundStyle(Theme.ink)
                Spacer()
                if badge > 0 {
                    Text("\(badge)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.accent, in: .capsule)
                }
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 52)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

struct EditProfileSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phone = ""
    @State private var bio = ""
    @State private var agency = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal") {
                    TextField("Full name", text: $name).textContentType(.name)
                    TextField("Phone", text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber)
                    LabeledContent("Email", value: store.currentUser?.email ?? "")
                }
                if store.currentUser?.role.isProvider == true {
                    Section("Professional profile") {
                        TextField(store.isHotelOwner ? "Hotel / company" : "Agency / company", text: $agency)
                        TextField("Bio", text: $bio, axis: .vertical).lineLimit(3...6)
                    }
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateProfile(name: name, phone: phone, bio: bio, agencyName: agency)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            name = store.currentUser?.name ?? ""
            phone = store.currentUser?.phone ?? ""
            bio = store.currentUser?.bio ?? ""
            agency = store.currentUser?.agencyName ?? ""
        }
    }
}

struct BecomeAgentSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var agency = ""
    @State private var phone = ""
    @State private var accepted = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("List rentals, shortlets and properties for sale. Your profile is verified by our team and every listing is reviewed before it goes live.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
                Section("Business details") {
                    TextField("Agency or business name", text: $agency)
                    TextField("Business phone", text: $phone).keyboardType(.phonePad)
                }
                Section {
                    Toggle("I confirm I'm authorised to advertise the properties I list", isOn: $accepted)
                        .tint(Theme.primary)
                }
            }
            .navigationTitle("Become an agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        store.becomeAgent(agencyName: agency, phone: phone)
                        dismiss()
                    }
                    .disabled(agency.trimmingCharacters(in: .whitespaces).isEmpty || phone.count < 7 || !accepted)
                }
            }
        }
        .onAppear { phone = store.currentUser?.phone ?? "" }
    }
}

/// Compact account menu used by agents and admins from their dashboards.
struct AccountSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        AvatarView(account: store.currentUser, size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.currentUser?.name ?? "").font(.headline)
                            Text(store.currentUser?.email ?? "").font(.subheadline).foregroundStyle(Theme.muted)
                            Text(store.currentUser?.role.label ?? "").font(.caption).foregroundStyle(Theme.accent)
                        }
                    }
                }
                Section {
                    Button { showEdit = true } label: { Label("Edit profile", systemImage: "person.text.rectangle") }
                    Button { go(.messages) } label: { Label("Messages", systemImage: "bubble.left.and.bubble.right") }
                    Button { go(.notifications) } label: { Label("Notifications", systemImage: "bell") }
                    Button { go(.payments) } label: { Label("My payments", systemImage: "creditcard") }
                }
                .foregroundStyle(Theme.ink)
                Section {
                    Button("Sign out", role: .destructive) {
                        dismiss()
                        store.signOut()
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showEdit) { EditProfileSheet() }
        }
        .presentationDetents([.medium, .large])
    }

    private func go(_ route: Route) {
        dismiss()
        router.push(route)
    }
}
