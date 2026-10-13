import SwiftUI

struct AuthView: View {
    private enum Mode: String, CaseIterable { case signIn = "Sign in", signUp = "Create account" }

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var role: UserRole = .user
    @State private var agency = ""
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if mode == .signUp {
                        rolePicker
                        FieldBox(label: "Full name") {
                            TextField("Ada Nwosu", text: $name).textContentType(.name)
                        }
                    }
                    FieldBox(label: "Email") {
                        TextField("you@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    if mode == .signUp {
                        FieldBox(label: "Phone") {
                            TextField("+234 800 000 0000", text: $phone)
                                .keyboardType(.phonePad)
                                .textContentType(.telephoneNumber)
                        }
                        if role.isProvider {
                            FieldBox(label: role == .hotelOwner ? "Hotel or company name" : "Agency or business name") {
                                TextField(role == .hotelOwner ? "e.g. The Eko Grand" : "e.g. Okafor Homes", text: $agency)
                            }
                            Label(role == .hotelOwner ? "Hotel-owner accounts are reviewed by our team before hotels are published." : "Agent and landlord profiles are verified by our team. Every listing is reviewed before it goes live.", systemImage: "checkmark.shield")
                                .font(.footnote)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    FieldBox(label: "Password") {
                        SecureField("At least 6 characters", text: $password)
                            .textContentType(mode == .signIn ? .password : .newPassword)
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Theme.danger)
                            .transition(.opacity)
                    }

                    Button(action: submit) {
                        if isWorking { ProgressView().tint(.white) } else { Text(mode.rawValue) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isWorking || email.isEmpty || password.isEmpty)

                    demoSection
                }
                .padding(20)
                .animation(.snappy, value: mode)
                .animation(.snappy, value: role)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .onChange(of: mode) { _, _ in errorMessage = nil }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "house.fill")
                .font(.title2)
                .foregroundStyle(Theme.canvas)
                .frame(width: 56, height: 56)
                .background(Theme.primary, in: .rect(cornerRadius: 16))
            Text(mode == .signIn ? "Welcome back" : "Join Homestead")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.ink)
            Text(mode == .signIn ? "Sign in to manage bookings, reservations, saved places and listings." : "Find a home, book a stay, or list your properties and hotels.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
    }

    private var rolePicker: some View {
        HStack(spacing: 8) {
            roleCard(.user, symbol: "magnifyingglass", title: "Find & book")
            roleCard(.agent, symbol: "building.2.fill", title: "List property")
            roleCard(.hotelOwner, symbol: "bed.double.fill", title: "List a hotel")
        }
    }

    private func roleCard(_ value: UserRole, symbol: String, title: String) -> some View {
        let selected = role == value
        return Button {
            role = value
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol).font(.title3)
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                Text(value.label).font(.caption2).opacity(0.8).lineLimit(2)
            }
            .foregroundStyle(selected ? .white : Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .padding(12)
            .background(selected ? Theme.primary : Theme.surface, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(PressableButtonStyle())
        .sensoryFeedback(.selection, trigger: selected)
    }

    private var demoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Explore with a demo account")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.muted)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                demoButton("Customer", SeedData.demoUserEmail)
                demoButton("Agent / Landlord", SeedData.demoAgentEmail)
                demoButton("Hotel owner", SeedData.demoHotelEmail)
                demoButton("Admin", SeedData.demoAdminEmail)
            }
        }
        .padding(.top, 8)
    }

    private func demoButton(_ title: String, _ demoEmail: String) -> some View {
        Button {
            mode = .signIn
            email = demoEmail
            password = SeedData.demoPassword
            submit()
        } label: {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Theme.primarySoft, in: .capsule)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func submit() {
        errorMessage = nil
        isWorking = true
        do {
            if mode == .signIn {
                try store.signIn(email: email, password: password)
            } else {
                if role.isProvider && agency.trimmingCharacters(in: .whitespaces).isEmpty {
                    isWorking = false
                    errorMessage = role == .hotelOwner ? "Please enter your hotel or company name." : "Please enter your agency or business name."
                    return
                }
                try store.signUp(name: name, email: email, phone: phone, password: password, role: role, agencyName: agency)
            }
            isWorking = false
            dismiss()
        } catch {
            isWorking = false
            withAnimation { errorMessage = error.localizedDescription }
        }
    }
}
