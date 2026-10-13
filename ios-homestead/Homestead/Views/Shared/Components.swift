import SwiftUI

/// Fills its frame with a listing photo (bundled or uploaded), cropping as needed.
struct ListingPhoto: View {
    let name: String?

    var body: some View {
        Theme.sand
            .overlay {
                if let image = ImageStore.shared.image(named: name) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .allowsHitTesting(false)
                } else {
                    Image(systemName: "house")
                        .font(.title)
                        .foregroundStyle(Theme.muted.opacity(0.5))
                }
            }
            .clipped()
    }
}

struct AvatarView: View {
    let account: Account?
    var size: CGFloat = 44

    var body: some View {
        Circle()
            .fill(Theme.primarySoft)
            .frame(width: size, height: size)
            .overlay {
                if let image = ImageStore.shared.image(named: account?.avatarName) {
                    Image(uiImage: image).resizable().scaledToFill().allowsHitTesting(false)
                } else {
                    Text(account?.initials ?? "?")
                        .font(.system(size: size * 0.36, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }
            }
            .clipShape(.circle)
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(Theme.ink)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 3) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right").font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

struct VerifiedPill: View {
    var text: String = "Verified agent"

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.primary)
            Text(text).foregroundStyle(Theme.ink)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.94), in: .capsule)
    }
}

struct PriceText: View {
    let listing: Listing
    var font: Font = .title3.bold()

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if listing.isHotel {
                Text("From")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            Text(listing.priceText)
                .font(font)
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            if !listing.priceUnit.suffix.isEmpty {
                Text(listing.priceUnit.suffix)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}

struct FavoriteButton: View {
    let listingID: UUID
    var size: CGFloat = 36

    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let isFavorite = store.isFavorite(listingID)
        Button {
            guard store.isSignedIn else {
                router.presentAuth()
                return
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                store.toggleFavorite(listingID)
            }
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(isFavorite ? Theme.accent : Theme.ink)
                .symbolEffect(.bounce, value: isFavorite)
                .frame(width: size, height: size)
                .background(.white, in: .circle)
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                .frame(width: max(size, 44), height: max(size, 44))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isFavorite)
        .accessibilityLabel(isFavorite ? "Remove from saved" : "Save listing")
    }
}

struct RatingLabel: View {
    let listing: Listing

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill").foregroundStyle(Theme.accent)
            Text(listing.rating, format: .number.precision(.fractionLength(1)))
                .foregroundStyle(Theme.ink)
            Text("·").foregroundStyle(Theme.muted)
            Text(listing.area).foregroundStyle(Theme.muted).lineLimit(1)
        }
        .font(.subheadline)
    }
}

struct StarRow: View {
    let count: Int
    var size: Font = .caption

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<max(count, 0), id: \.self) { _ in
                Image(systemName: "star.fill")
            }
        }
        .font(size)
        .foregroundStyle(Theme.accent)
        .accessibilityLabel("\(count) star")
    }
}

/// Pill-shaped selectable chip used for filters.
struct FilterChip: View {
    let title: String
    let selected: Bool
    var symbol: String?
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.caption) }
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(selected ? .white : Theme.ink)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(selected ? Theme.primary : Theme.surface, in: .capsule)
            .overlay(Capsule().strokeBorder(selected ? .clear : Theme.hairline))
        }
        .buttonStyle(PressableButtonStyle())
        .sensoryFeedback(.selection, trigger: selected)
    }
}

/// Large photo card used in the Featured Homes carousel.
struct FeaturedListingCard: View {
    let listing: Listing
    var width: CGFloat = 300

    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(height: 180)
                .overlay { ListingPhoto(name: listing.imageNames.first) }
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    if store.isAgentVerified(listing) {
                        VerifiedPill(text: listing.isHotel ? "Verified hotel" : "Verified agent").padding(12)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    FavoriteButton(listingID: listing.id).padding(4)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                PriceText(listing: listing)
                Text(listing.specLine)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            .padding(14)
        }
        .frame(width: width)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cardRadius))
        .shadow(color: Theme.ink.opacity(0.06), radius: 14, y: 5)
    }
}

/// Compact card used in the Popular Shortlets carousel.
struct ShortletCard: View {
    let listing: Listing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(height: 128)
                .overlay { ListingPhoto(name: listing.imageNames.first) }
                .clipped()
                .overlay(alignment: .topTrailing) {
                    FavoriteButton(listingID: listing.id, size: 30).padding(2)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                PriceText(listing: listing, font: .headline)
                if listing.reviewCount > 0 {
                    RatingLabel(listing: listing).font(.caption)
                } else {
                    Text(listing.locationLine).font(.caption).foregroundStyle(Theme.muted)
                }
            }
            .padding(12)
        }
        .frame(width: 212)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: Theme.ink.opacity(0.06), radius: 12, y: 4)
    }
}

/// Horizontal row used in search results, saved homes and dashboards.
struct ListingRow: View {
    let listing: Listing
    var showsStatus: Bool = false
    var showsFavorite: Bool = true

    var body: some View {
        HStack(spacing: 14) {
            ListingPhoto(name: listing.imageNames.first)
                .frame(width: 96, height: 96)
                .clipShape(.rect(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(listing.category.title.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.accent)
                    if showsStatus {
                        StatusBadge(text: listing.status.title, tone: listing.status.tone, showsDot: true)
                            .scaleEffect(0.9, anchor: .leading)
                    }
                }
                Text(listing.title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(listing.specLine)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                PriceText(listing: listing, font: .headline)
            }
            Spacer(minLength: 0)
            if showsFavorite {
                FavoriteButton(listingID: listing.id, size: 32)
            }
        }
        .padding(12)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.cardRadius))
        .shadow(color: Theme.ink.opacity(0.05), radius: 10, y: 3)
    }
}

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(Theme.muted)
            Spacer()
            Text(value)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

struct FieldBox<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.muted)
            content
                .padding(.horizontal, 14)
                .frame(minHeight: 50)
                .background(Theme.surface, in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.hairline))
        }
    }
}

struct SignInPrompt: View {
    let title: String
    let message: String
    var symbol: String = "person.crop.circle"

    @Environment(AppRouter.self) private var router

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        } actions: {
            Button("Sign in or create account") { router.presentAuth() }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 300)
        }
        .foregroundStyle(Theme.ink)
    }
}

extension Date {
    var relativeText: String {
        formatted(.relative(presentation: .named))
    }
}
