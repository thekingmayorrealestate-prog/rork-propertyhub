import SwiftUI

struct MessagesView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Group {
            if store.myThreads.isEmpty {
                ContentUnavailableView("No conversations yet", systemImage: "bubble.left.and.bubble.right", description: Text("Message an agent from any listing to start a conversation."))
            } else {
                List(store.myThreads) { thread in
                    NavigationLink(value: Route.chat(thread.id)) {
                        ThreadRow(thread: thread)
                    }
                    .listRowBackground(Theme.surface)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

struct ThreadRow: View {
    let thread: ChatThread
    @Environment(AppStore.self) private var store

    var body: some View {
        let other = store.counterpart(in: thread)
        let unread = store.isUnread(thread)
        HStack(spacing: 12) {
            AvatarView(account: other, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(other?.name ?? "User").font(.headline).foregroundStyle(Theme.ink)
                    Spacer()
                    Text(thread.lastActivity.relativeText).font(.caption).foregroundStyle(Theme.muted)
                }
                Text(store.listing(thread.listingID)?.title ?? "Listing")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text(thread.messages.last?.text ?? "Start the conversation")
                    .font(.subheadline)
                    .foregroundStyle(unread ? Theme.ink : Theme.muted)
                    .fontWeight(unread ? .semibold : .regular)
                    .lineLimit(1)
            }
            if unread {
                Circle().fill(Theme.accent).frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ChatView: View {
    let threadID: UUID

    @Environment(AppStore.self) private var store
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if let thread = store.thread(threadID) {
                chat(thread)
            } else {
                ContentUnavailableView("Conversation not found", systemImage: "bubble.left")
            }
        }
        .screenBackground()
        .toolbar(.hidden, for: .tabBar)
    }

    private func chat(_ thread: ChatThread) -> some View {
        let other = store.counterpart(in: thread)
        let listing = store.listing(thread.listingID)
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if let listing {
                        NavigationLink(value: Route.listing(listing.id)) {
                            HStack(spacing: 10) {
                                ListingPhoto(name: listing.imageNames.first)
                                    .frame(width: 44, height: 44)
                                    .clipShape(.rect(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(listing.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                                    PriceText(listing: listing, font: .caption.bold())
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted)
                            }
                            .card(padding: 10)
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 8)
                    }
                    if thread.messages.isEmpty {
                        Text("Say hello to \(other?.firstName ?? "the agent") — ask about availability, pricing or a viewing.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                            .padding(.top, 40)
                            .padding(.horizontal, 30)
                    }
                    ForEach(thread.messages) { message in
                        MessageBubble(message: message, isMine: message.senderID == store.currentUserID)
                            .id(message.id)
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onChange(of: thread.messages.count) { _, _ in
                if let last = thread.messages.last {
                    withAnimation(.snappy) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                TextField("Message", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($isFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.surface, in: .rect(cornerRadius: 22))
                Button {
                    store.send(draft, in: thread.id)
                    draft = ""
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.muted.opacity(0.4) : Theme.primary, in: .circle)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .sensoryFeedback(.impact(weight: .light), trigger: thread.messages.count)
                .accessibilityLabel("Send")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.canvas)
        }
        .navigationTitle(other?.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.markThreadRead(thread.id) }
        .onDisappear { store.markThreadRead(thread.id) }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 50) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(isMine ? .white : Theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isMine ? Theme.primary : Theme.surface, in: .rect(cornerRadius: 18))
                Text(message.sentAt.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
            if !isMine { Spacer(minLength: 50) }
        }
    }
}

struct NotificationsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Group {
            if store.myNotifications.isEmpty {
                ContentUnavailableView("You're all caught up", systemImage: "bell", description: Text("Booking updates, inquiries and approvals will appear here."))
            } else {
                List(store.myNotifications) { note in
                    Button {
                        store.markNotificationRead(note.id)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: note.kind.symbol)
                                .font(.body)
                                .foregroundStyle(Theme.primary)
                                .frame(width: 40, height: 40)
                                .background(Theme.primarySoft, in: .circle)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(note.title)
                                        .font(.subheadline.weight(note.isRead ? .medium : .bold))
                                        .foregroundStyle(Theme.ink)
                                    Spacer()
                                    Text(note.createdAt.relativeText).font(.caption).foregroundStyle(Theme.muted)
                                }
                                Text(note.body).font(.subheadline).foregroundStyle(Theme.muted)
                            }
                            if !note.isRead {
                                Circle().fill(Theme.accent).frame(width: 8, height: 8).padding(.top, 6)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Theme.surface)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if store.unreadNotificationCount > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark all read") { store.markAllNotificationsRead() }
                }
            }
        }
    }
}
