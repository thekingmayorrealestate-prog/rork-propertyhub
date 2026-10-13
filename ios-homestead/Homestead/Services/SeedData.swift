import Foundation

/// Starter marketplace content so every flow (user, agent, admin) is explorable on first launch.
enum SeedData {
    static let version = 2
    static let demoPassword = "password123"

    static let demoUserEmail = "ada@homestead.ng"
    static let demoAgentEmail = "adeola@homestead.ng"
    static let demoAdminEmail = "admin@homestead.ng"
    static let demoHotelEmail = "kemi@homestead.ng"

    static let cityCenters: [String: (Double, Double)] = [
        "Lagos": (6.4550, 3.4200),
        "Abuja": (9.0765, 7.3986),
        "Port Harcourt": (4.8156, 7.0498)
    ]

    static var cities: [String] { ["Lagos", "Abuja", "Port Harcourt"] }

    static func make() -> AppData {
        let now = Date()
        func days(_ n: Int, hour: Int = 12) -> Date {
            let d = Calendar.current.date(byAdding: .day, value: n, to: now) ?? now
            return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: d) ?? d
        }

        func account(_ name: String, _ email: String, _ phone: String, _ role: UserRole, agency: String? = nil, bio: String = "", avatar: String? = nil, verified: Bool = false, joined: Int) -> Account {
            let salt = PasswordHasher.makeSalt()
            return Account(
                id: UUID(), name: name, email: email, phone: phone,
                passwordHash: PasswordHasher.hash(demoPassword, salt: salt), salt: salt,
                role: role, agencyName: agency, bio: bio, avatarName: avatar,
                isVerified: verified, isSuspended: false, favoriteIDs: [], createdAt: days(-joined)
            )
        }

        var ada = account("Ada Nwosu", demoUserEmail, "+234 803 555 0142", .user, joined: 120)
        let tunde = account("Tunde Bakare", "tunde@homestead.ng", "+234 806 555 0199", .user, joined: 40)
        let funmi = account("Funmi Adeyemi", "funmi@homestead.ng", "+234 809 555 0110", .user, joined: 12)
        let adeola = account("Adeola Ogunleye", demoAgentEmail, "+234 802 555 0177", .agent, agency: "Ogunleye Realty", bio: "Lagos & Abuja residential specialist with 9 years of experience.", verified: true, joined: 300)
        let amara = account("Amara Okafor", "amara@homestead.ng", "+234 805 555 0123", .agent, agency: "Okafor Homes", bio: "Luxury shortlets and premium sales across Lekki, Ikoyi and Banana Island.", avatar: "professional_headshot_portrait", verified: true, joined: 410)
        let chinedu = account("Chinedu Eze", "chinedu@homestead.ng", "+234 807 555 0165", .agent, agency: "Independent landlord", bio: "Owner of residential flats in Yaba and Gbagada.", verified: false, joined: 6)
        let admin = account("Homestead Admin", demoAdminEmail, "+234 800 000 0000", .admin, verified: true, joined: 500)
        let kemi = account("Kemi Adebayo", demoHotelEmail, "+234 801 555 0188", .hotelOwner, agency: "Adebayo Hospitality Group", bio: "Operator of boutique hotels and resorts in Lagos, Abuja and Port Harcourt.", verified: true, joined: 260)
        let ibrahim = account("Ibrahim Musa", "ibrahim@homestead.ng", "+234 808 555 0134", .hotelOwner, agency: "Garki Guesthouse", bio: "Family-run guesthouse in Garki, Abuja.", verified: false, joined: 2)

        func listing(
            _ title: String, _ category: ListingCategory, _ type: PropertyType, _ unit: PriceUnit, _ price: Int,
            city: String = "Lagos", area: String, lat: Double, lon: Double, beds: Int, baths: Int, sleeps: Int = 0,
            size: Int, facilities: [Facility], summary: String, terms: String, images: [String], agent: Account,
            status: ListingStatus = .live, featured: Bool = false, rating: Double = 0, reviews: Int = 0,
            views: [Int], created: Int
        ) -> Listing {
            Listing(
                id: UUID(), title: title, category: category, propertyType: type, priceUnit: unit, price: price,
                city: city, area: area, address: "\(area), \(city)", latitude: lat, longitude: lon,
                bedrooms: beds, bathrooms: baths, sleeps: sleeps, sizeSqm: size, facilities: facilities,
                summary: summary, terms: terms, imageNames: images, agentID: agent.id, status: status,
                rejectionReason: nil, isFeatured: featured, rating: rating, reviewCount: reviews,
                weeklyViews: views, createdAt: days(-created)
            )
        }

        let ikoyiDuplex = listing(
            "Ikoyi Terrace Duplex", .rent, .duplex, .month, 4_500_000, area: "Ikoyi", lat: 6.4520, lon: 3.4350,
            beds: 4, baths: 4, size: 380, facilities: [.power, .security, .parking, .kitchen, .bq, .ac, .water],
            summary: "A contemporary 4-bedroom terrace duplex in a gated Ikoyi estate. Double-height living room, fitted kitchen, private terrace and a staff quarters. Minutes from Falomo and the Lekki–Ikoyi link bridge.",
            terms: "Minimum 12-month lease. 2 months refundable caution deposit. Service charge ₦350,000/month covers security, power backup and waste.",
            images: ["luxury_duplex_terrace", "modern_kitchen_island", "highrise_apartment_living_room"], agent: adeola, featured: true,
            views: [120, 160, 240, 190, 140, 210, 260], created: 18
        )
        let viApartment = listing(
            "Victoria Island Apartment", .rent, .apartment, .month, 3_200_000, area: "Victoria Island", lat: 6.4281, lon: 3.4219,
            beds: 2, baths: 2, size: 160, facilities: [.wifi, .gym, .pool, .power, .security, .ac],
            summary: "High-floor 2-bedroom apartment with floor-to-ceiling windows and sweeping city views. Residents' gym, pool and 24-hour concierge.",
            terms: "Minimum 12 months. 1 month caution deposit. Agency and legal fees 10% each.",
            images: ["highrise_apartment_living_room", "luxury_bedroom_city_view", "modern_kitchen_island"], agent: adeola, featured: true,
            views: [80, 110, 150, 120, 90, 140, 170], created: 25
        )
        let skyLoft = listing(
            "Lekki Sky Loft", .shortlet, .apartment, .night, 120_000, area: "Lekki Phase 1", lat: 6.4474, lon: 3.4723,
            beds: 2, baths: 2, sleeps: 4, size: 140, facilities: [.wifi, .pool, .power, .parking, .ac, .furnished, .kitchen, .security],
            summary: "A stylish 2-bedroom apartment in the heart of Lekki Phase 1. Modern interiors, great city views and easy access to restaurants, beaches and nightlife.",
            terms: "Check-in from 2pm, check-out by 12pm. Refundable caution fee ₦50,000. No parties.",
            images: ["loft_interior_sofa_tv", "luxury_bedroom_city_view", "beach_house_infinity_pool", "modern_kitchen_island"], agent: amara, featured: false,
            rating: 4.9, reviews: 142, views: [210, 230, 260, 240, 280, 320, 350], created: 60
        )
        let ekoBeach = listing(
            "Eko Beach House", .shortlet, .house, .night, 95_000, area: "Oniru", lat: 6.4357, lon: 3.4440,
            beds: 3, baths: 3, sleeps: 6, size: 220, facilities: [.pool, .wifi, .power, .parking, .garden, .furnished],
            summary: "Breezy beach house with an infinity pool facing the Atlantic. Perfect for family getaways and sunset dinners.",
            terms: "Check-in 3pm, check-out 11am. Minimum 2 nights on weekends.",
            images: ["beach_house_infinity_pool", "luxury_bedroom_city_view", "modern_kitchen_island"], agent: amara,
            rating: 4.8, reviews: 96, views: [140, 120, 160, 150, 190, 260, 280], created: 75
        )
        let abujaSuite = listing(
            "Abuja City Suite", .shortlet, .apartment, .night, 80_000, city: "Abuja", area: "Maitama", lat: 9.0882, lon: 7.4934,
            beds: 1, baths: 1, sleeps: 2, size: 75, facilities: [.wifi, .power, .ac, .furnished, .security, .gym],
            summary: "Elegant serviced suite in serene Maitama, close to embassies and Jabi Lake Mall. Ideal for business travellers.",
            terms: "Check-in 2pm, check-out 12pm. Valid ID required at check-in.",
            images: ["serviced_suite_bedroom", "modern_kitchen_island"], agent: adeola,
            rating: 4.7, reviews: 58, views: [60, 70, 90, 80, 75, 95, 110], created: 30
        )
        let viStudio = listing(
            "Victoria Island Studio", .shortlet, .studio, .night, 45_000, area: "Victoria Island", lat: 6.4300, lon: 3.4180,
            beds: 1, baths: 1, sleeps: 2, size: 48, facilities: [.wifi, .power, .ac, .furnished],
            summary: "Compact, bright studio steps from Eko Atlantic and Bar Beach. Smart TV, fast Wi-Fi and a kitchenette.",
            terms: "Check-in 2pm, check-out 12pm.",
            images: ["highrise_apartment_living_room", "serviced_suite_bedroom"], agent: amara,
            rating: 4.6, reviews: 37, views: [40, 50, 60, 55, 70, 80, 90], created: 45
        )
        let bananaVilla = listing(
            "Banana Island Villa", .sale, .villa, .total, 850_000_000, area: "Banana Island", lat: 6.4667, lon: 3.4500,
            beds: 6, baths: 7, size: 1100, facilities: [.pool, .gym, .power, .security, .parking, .bq, .garden, .ac],
            summary: "Architect-designed 6-bedroom villa with lagoon frontage, private pool, cinema room and smart-home automation. Governor's consent title.",
            terms: "Title: Governor's consent. Viewing by appointment only. Proof of funds required for second viewing.",
            images: ["luxury_villa_dusk", "highrise_apartment_living_room", "modern_kitchen_island", "luxury_bedroom_city_view"], agent: amara, featured: true,
            views: [90, 70, 110, 95, 85, 130, 150], created: 20
        )
        let landPlot = listing(
            "Ibeju-Lekki Estate Plot", .sale, .land, .total, 25_000_000, area: "Ibeju-Lekki", lat: 6.4520, lon: 3.6800,
            beds: 0, baths: 0, size: 600, facilities: [.security],
            summary: "Dry, fenced 600 sqm residential plot in a fast-growing estate near the Lekki Free Trade Zone and Dangote Refinery.",
            terms: "Title: Registered survey & deed of assignment. Instalment plans available over 12 months.",
            images: ["residential_land_plot"], agent: amara,
            views: [30, 45, 40, 50, 35, 60, 70], created: 14
        )
        let gbagadaFlat = listing(
            "Gbagada 3-Bed Flat", .rent, .apartment, .year, 3_500_000, area: "Gbagada", lat: 6.5531, lon: 3.3889,
            beds: 3, baths: 3, size: 150, facilities: [.parking, .security, .water, .kitchen],
            summary: "Newly built 3-bedroom flat in a quiet, gated compound off Gbagada Expressway. All rooms en-suite with ample parking.",
            terms: "1 year upfront. Caution fee ₦300,000. Agency 10%, legal 10%.",
            images: ["modern_apartment_building", "modern_kitchen_island"], agent: chinedu,
            views: [20, 25, 30, 22, 28, 35, 40], created: 5
        )
        let maitamaHome = listing(
            "Maitama Family Home", .sale, .duplex, .total, 320_000_000, city: "Abuja", area: "Maitama", lat: 9.0950, lon: 7.4850,
            beds: 5, baths: 6, size: 650, facilities: [.garden, .power, .security, .parking, .bq, .water],
            summary: "Detached 5-bedroom family duplex on a tree-lined Maitama street with a large garden and two staff quarters.",
            terms: "Title: Certificate of Occupancy. Negotiable.",
            images: ["luxury_duplex_terrace", "serviced_suite_bedroom", "modern_kitchen_island"], agent: adeola, featured: true,
            views: [50, 40, 70, 60, 55, 80, 90], created: 33
        )
        let ikoyiGarden = listing(
            "Ikoyi Garden Terrace", .sale, .house, .total, 450_000_000, area: "Ikoyi", lat: 6.4580, lon: 3.4410,
            beds: 4, baths: 5, size: 520, facilities: [.garden, .pool, .power, .security, .parking, .ac],
            summary: "Elegant 4-bedroom terrace with a private garden, shared pool and 24/7 security in Old Ikoyi.",
            terms: "Title: Governor's consent.",
            images: ["luxury_duplex_terrace", "luxury_bedroom_city_view", "highrise_apartment_living_room"], agent: amara,
            views: [45, 55, 65, 50, 60, 75, 85], created: 40
        )
        let penthouse = listing(
            "Lekki Phase 1 Penthouse", .shortlet, .apartment, .night, 180_000, area: "Lekki Phase 1", lat: 6.4440, lon: 3.4790,
            beds: 3, baths: 3, sleeps: 6, size: 210, facilities: [.wifi, .pool, .power, .gym, .ac, .furnished, .parking],
            summary: "Top-floor 3-bedroom penthouse with a rooftop terrace, jacuzzi and lagoon views.",
            terms: "Check-in 2pm, check-out 12pm. Caution fee ₦100,000.",
            images: ["loft_interior_sofa_tv", "beach_house_infinity_pool", "luxury_bedroom_city_view"], agent: adeola, status: .pending,
            views: [0, 0, 0, 0, 0, 0, 0], created: 1
        )
        let yabaFlat = listing(
            "Yaba Mini Flat", .rent, .apartment, .year, 1_800_000, area: "Yaba", lat: 6.5095, lon: 3.3711,
            beds: 1, baths: 1, size: 55, facilities: [.water, .security],
            summary: "Clean 1-bedroom mini flat close to UNILAG and the tech hub on Herbert Macaulay Way.",
            terms: "1 year upfront. Caution ₦150,000.",
            images: ["modern_apartment_building"], agent: chinedu, status: .pending,
            views: [0, 0, 0, 0, 0, 0, 0], created: 0
        )

        func room(_ name: String, _ kind: RoomKind, _ price: Int, capacity: Int, count: Int, bed: String, size: Int, amenities: [Facility], image: String?) -> RoomType {
            RoomType(id: UUID(), name: name, kind: kind, pricePerNight: price, capacity: capacity, totalRooms: count, bedInfo: bed, sizeSqm: size, amenities: amenities, imageName: image, isOpen: true)
        }

        func hotel(
            _ title: String, _ type: PropertyType, city: String = "Lagos", area: String, lat: Double, lon: Double,
            stars: Int, policy: CancellationPolicy, checkIn: String = "2:00 PM", checkOut: String = "12:00 PM",
            requirements: String, rooms: [RoomType], facilities: [Facility], summary: String, images: [String], owner: Account,
            status: ListingStatus = .live, featured: Bool = false, rating: Double = 0, reviews: Int = 0, views: [Int], created: Int
        ) -> Listing {
            let details = HotelDetails(starRating: stars, checkInTime: checkIn, checkOutTime: checkOut, policy: policy, checkInRequirements: requirements, rooms: rooms)
            return Listing(
                id: UUID(), title: title, category: .hotel, propertyType: type, priceUnit: .night, price: details.lowestRate,
                city: city, area: area, address: "\(area), \(city)", latitude: lat, longitude: lon,
                bedrooms: details.totalRooms, bathrooms: 0, sleeps: details.maxCapacity, sizeSqm: 0, facilities: facilities,
                summary: summary, terms: policy.summary, imageNames: images, agentID: owner.id, status: status,
                rejectionReason: nil, isFeatured: featured, rating: rating, reviewCount: reviews,
                weeklyViews: views, createdAt: days(-created), hotel: details
            )
        }

        let ekoKing = room("Deluxe King", .deluxe, 140_000, capacity: 2, count: 12, bed: "1 king bed", size: 34, amenities: [.wifi, .ac, .roomService, .breakfast], image: "hotel_king_room")
        let ekoSingle = room("Classic Single", .single, 85_000, capacity: 1, count: 10, bed: "1 queen bed", size: 22, amenities: [.wifi, .ac], image: "serviced_suite_bedroom")
        let ekoTwin = room("Superior Twin", .twin, 120_000, capacity: 2, count: 8, bed: "2 single beds", size: 30, amenities: [.wifi, .ac, .breakfast], image: "guesthouse_twin_room")
        let ekoSuite = room("Executive Suite", .suite, 290_000, capacity: 3, count: 2, bed: "1 king bed + sofa bed", size: 68, amenities: [.wifi, .ac, .roomService, .breakfast, .spa], image: "hotel_suite_living_area")
        let ekoGrand = hotel(
            "The Eko Grand", .hotel, area: "Victoria Island", lat: 6.4265, lon: 3.4230, stars: 5, policy: .moderate,
            requirements: "Government-issued ID or passport required. Refundable incidentals deposit of ₦50,000 at check-in. Minimum check-in age 18.",
            rooms: [ekoSingle, ekoKing, ekoTwin, ekoSuite],
            facilities: [.wifi, .pool, .restaurant, .breakfast, .gym, .spa, .parking, .ac, .roomService, .airportShuttle, .power, .security],
            summary: "A five-star landmark on Ahmadu Bello Way with a rooftop pool, three restaurants, a full-service spa and sweeping Atlantic views. Minutes from Eko Atlantic and the business district.",
            images: ["luxury_hotel_exterior_dusk", "hotel_lobby_interior", "hotel_king_room", "hotel_suite_living_area"], owner: kemi, featured: true,
            rating: 4.8, reviews: 214, views: [180, 210, 260, 240, 300, 340, 380], created: 90
        )
        let lagoonGarden = room("Garden Double", .double, 110_000, capacity: 2, count: 10, bed: "1 queen bed", size: 30, amenities: [.wifi, .ac, .breakfast], image: "hotel_king_room")
        let lagoonCabana = room("Lagoon Cabana", .suite, 180_000, capacity: 3, count: 6, bed: "1 king bed + daybed", size: 45, amenities: [.wifi, .ac, .breakfast, .roomService], image: "tropical_beach_resort_lagoon")
        let lagoonVilla = room("Family Villa", .family, 350_000, capacity: 5, count: 2, bed: "2 king beds + bunk", size: 110, amenities: [.wifi, .ac, .breakfast, .kitchen], image: "luxury_bedroom_city_view")
        let lagoonResort = hotel(
            "Lagoon Breeze Resort", .resort, area: "Lekki", lat: 6.4660, lon: 3.6100, stars: 4, policy: .flexible, checkIn: "3:00 PM", checkOut: "11:00 AM",
            requirements: "Valid ID for every adult guest. Children under 12 stay free with parents.",
            rooms: [lagoonGarden, lagoonCabana, lagoonVilla],
            facilities: [.wifi, .pool, .restaurant, .breakfast, .spa, .parking, .ac, .airportShuttle, .security],
            summary: "Thatched cabanas and villas set around a turquoise lagoon pool on the Lekki peninsula. Kayaking, a beach bar and weekend live music.",
            images: ["tropical_beach_resort_lagoon", "hotel_king_room", "luxury_bedroom_city_view"], owner: kemi, featured: true,
            rating: 4.7, reviews: 128, views: [120, 140, 150, 170, 220, 300, 320], created: 70
        )
        let maitamaSingle = room("Standard Single", .single, 70_000, capacity: 1, count: 8, bed: "1 double bed", size: 20, amenities: [.wifi, .ac], image: "serviced_suite_bedroom")
        let maitamaDouble = room("Business Double", .double, 95_000, capacity: 2, count: 14, bed: "1 king bed", size: 28, amenities: [.wifi, .ac, .breakfast], image: "hotel_king_room")
        let maitamaSuite = room("Ambassador Suite", .suite, 210_000, capacity: 3, count: 3, bed: "1 king bed + lounge", size: 60, amenities: [.wifi, .ac, .breakfast, .roomService], image: "hotel_suite_living_area")
        let maitamaCourt = hotel(
            "Maitama Court Hotel", .hotel, city: "Abuja", area: "Maitama", lat: 9.0850, lon: 7.4950, stars: 4, policy: .strict,
            requirements: "Government-issued ID required. Corporate guests may present a company letter for invoicing.",
            rooms: [maitamaSingle, maitamaDouble, maitamaSuite],
            facilities: [.wifi, .restaurant, .breakfast, .gym, .parking, .ac, .roomService, .power, .security],
            summary: "Quiet, business-friendly hotel near the embassies with meeting rooms, an all-day restaurant and fast fibre Wi-Fi.",
            images: ["hotel_lobby_interior", "hotel_king_room", "hotel_suite_living_area"], owner: kemi,
            rating: 4.6, reviews: 87, views: [70, 80, 90, 95, 100, 85, 110], created: 50
        )
        let phDouble = room("Garden Double", .double, 75_000, capacity: 2, count: 10, bed: "1 queen bed", size: 26, amenities: [.wifi, .ac, .breakfast], image: "guesthouse_twin_room")
        let phSuite = room("Junior Suite", .suite, 150_000, capacity: 3, count: 4, bed: "1 king bed + sofa", size: 48, amenities: [.wifi, .ac, .breakfast, .roomService], image: "hotel_suite_living_area")
        let gardenCity = hotel(
            "Garden City Suites", .hotel, city: "Port Harcourt", area: "Old GRA", lat: 4.8000, lon: 7.0100, stars: 4, policy: .moderate,
            requirements: "Valid ID required at check-in.",
            rooms: [phDouble, phSuite],
            facilities: [.wifi, .pool, .restaurant, .breakfast, .parking, .ac, .power, .security],
            summary: "Leafy all-suite hotel in Old GRA with an outdoor pool, grill restaurant and airport transfers on request.",
            images: ["hotel_suite_living_area", "hotel_lobby_interior", "guesthouse_twin_room"], owner: kemi,
            rating: 4.5, reviews: 41, views: [30, 40, 35, 50, 45, 60, 70], created: 25
        )
        let garkiGuesthouse = hotel(
            "Garki Guesthouse", .guesthouse, city: "Abuja", area: "Garki", lat: 9.0300, lon: 7.4900, stars: 3, policy: .flexible,
            requirements: "Valid ID required.",
            rooms: [
                room("Twin Room", .twin, 35_000, capacity: 2, count: 4, bed: "2 single beds", size: 20, amenities: [.wifi, .ac], image: "guesthouse_twin_room"),
                room("Double Room", .double, 45_000, capacity: 2, count: 4, bed: "1 double bed", size: 22, amenities: [.wifi, .ac, .breakfast], image: "serviced_suite_bedroom")
            ],
            facilities: [.wifi, .breakfast, .parking, .ac, .security],
            summary: "Clean, affordable rooms a short walk from Area 11 shopping centre. Home-cooked breakfast every morning.",
            images: ["guesthouse_twin_room", "serviced_suite_bedroom"], owner: ibrahim, status: .pending,
            views: [0, 0, 0, 0, 0, 0, 0], created: 1
        )

        ada.favoriteIDs = [skyLoft.id, ekoGrand.id, bananaVilla.id, viApartment.id]

        let b1 = Booking(id: UUID(), listingID: skyLoft.id, userID: ada.id, agentID: amara.id, category: .shortlet, kind: .shortletBooking, checkIn: days(20, hour: 14), checkOut: days(23, hour: 12), guests: 2, viewingDate: nil, message: "Looking forward to the stay!", status: .confirmed, agentNote: "Confirmed — see you soon. Concierge will meet you at the lobby.", createdAt: days(-6))
        let b2 = Booking(id: UUID(), listingID: viStudio.id, userID: ada.id, agentID: amara.id, category: .shortlet, kind: .shortletBooking, checkIn: days(28, hour: 14), checkOut: days(31, hour: 12), guests: 2, viewingDate: nil, message: "Is early check-in possible?", status: .pending, agentNote: nil, createdAt: days(-1))
        let b3 = Booking(id: UUID(), listingID: bananaVilla.id, userID: ada.id, agentID: amara.id, category: .sale, kind: .viewing, checkIn: nil, checkOut: nil, guests: 1, viewingDate: days(4, hour: 10), message: "I'd like to view the property this weekend.", status: .viewingScheduled, agentNote: "Viewing confirmed for 10am. Please bring a valid ID.", createdAt: days(-3))
        let b4 = Booking(id: UUID(), listingID: ikoyiDuplex.id, userID: ada.id, agentID: adeola.id, category: .rent, kind: .rentalInquiry, checkIn: nil, checkOut: nil, guests: 1, viewingDate: nil, message: "Is the service charge negotiable for a 2-year lease?", status: .pending, agentNote: nil, createdAt: days(-2))
        let b5 = Booking(id: UUID(), listingID: gbagadaFlat.id, userID: ada.id, agentID: chinedu.id, category: .rent, kind: .rentalInquiry, checkIn: nil, checkOut: nil, guests: 1, viewingDate: nil, message: "I'd like to rent from next month.", status: .confirmed, agentNote: "Approved. You can pay the first year's rent in the app to secure the flat.", createdAt: days(-4))
        let b6 = Booking(id: UUID(), listingID: ekoBeach.id, userID: ada.id, agentID: amara.id, category: .shortlet, kind: .shortletBooking, checkIn: days(-40, hour: 15), checkOut: days(-38, hour: 11), guests: 4, viewingDate: nil, message: "", status: .completed, agentNote: nil, createdAt: days(-50))
        let b7 = Booking(id: UUID(), listingID: ikoyiDuplex.id, userID: tunde.id, agentID: adeola.id, category: .rent, kind: .viewing, checkIn: nil, checkOut: nil, guests: 1, viewingDate: days(3, hour: 11), message: "Can I view the duplex on Saturday morning?", status: .pending, agentNote: nil, createdAt: now.addingTimeInterval(-7200))
        let b8 = Booking(id: UUID(), listingID: abujaSuite.id, userID: funmi.id, agentID: adeola.id, category: .shortlet, kind: .shortletBooking, checkIn: days(9, hour: 14), checkOut: days(12, hour: 12), guests: 1, viewingDate: nil, message: "Business trip — need a quiet room.", status: .pending, agentNote: nil, createdAt: now.addingTimeInterval(-18000))
        let b9 = Booking(id: UUID(), listingID: maitamaHome.id, userID: funmi.id, agentID: adeola.id, category: .sale, kind: .purchaseInquiry, checkIn: nil, checkOut: nil, guests: 1, viewingDate: nil, message: "Is the price negotiable? I'm a cash buyer.", status: .confirmed, agentNote: "Yes, there's some room. Let's talk.", createdAt: days(-5))

        func stay(_ listing: Listing, _ room: RoomType, _ user: Account, from: Int, nights: Int, rooms: Int = 1, guests: Int, status: BookingStatus = .confirmed, booked: Int) -> Booking {
            Booking(id: UUID(), listingID: listing.id, userID: user.id, agentID: listing.agentID, category: .hotel, kind: .hotelReservation, checkIn: days(from, hour: 14), checkOut: days(from + nights, hour: 12), guests: guests, viewingDate: nil, message: "", status: status, agentNote: nil, createdAt: days(-booked), roomTypeID: room.id, rooms: rooms)
        }
        let h1 = stay(ekoGrand, ekoKing, ada, from: 12, nights: 2, guests: 2, booked: 3)
        let h2 = stay(lagoonResort, lagoonCabana, ada, from: -25, nights: 3, guests: 2, status: .completed, booked: 40)
        let h3 = stay(maitamaCourt, maitamaDouble, tunde, from: 6, nights: 4, guests: 1, booked: 1)
        let h4 = stay(ekoGrand, ekoSuite, funmi, from: 11, nights: 3, guests: 3, booked: 2)
        let h5 = stay(ekoGrand, ekoKing, tunde, from: 1, nights: 2, rooms: 2, guests: 4, booked: 5)

        func payment(_ b: Booking, _ amount: Int, _ fee: Int, _ ref: String, status: PaymentStatus = .paid, ago: Int) -> Payment {
            Payment(id: UUID(), bookingID: b.id, userID: b.userID, listingID: b.listingID, amount: amount, serviceFee: fee, method: .card, status: status, reference: ref, cardLast4: "4081", createdAt: days(-ago))
        }

        let payments = [
            payment(b1, 360_000, 18_000, "RC-2041", ago: 6),
            payment(b2, 135_000, 6_750, "RC-1987", ago: 1),
            payment(b6, 190_000, 9_500, "RC-1650", ago: 50),
            payment(b8, 240_000, 12_000, "RC-2055", ago: 0),
            payment(h1, 280_000, 14_000, "RC-2102", ago: 3),
            payment(h2, 540_000, 27_000, "RC-1720", ago: 40),
            payment(h3, 380_000, 19_000, "RC-2120", ago: 1),
            payment(h4, 870_000, 43_500, "RC-2114", ago: 2),
            payment(h5, 560_000, 28_000, "RC-2096", ago: 5)
        ]

        func review(_ listing: Listing, _ user: Account, _ rating: Int, _ text: String, ago: Int) -> Review {
            Review(id: UUID(), listingID: listing.id, userID: user.id, authorName: user.shortName, rating: rating, text: text, createdAt: days(-ago))
        }
        let reviews = [
            review(ekoGrand, tunde, 5, "Impeccable service from the moment we arrived. The rooftop pool at sunset is unreal.", ago: 9),
            review(ekoGrand, funmi, 4, "Beautiful rooms and a great breakfast spread. Check-in took a little long on a busy Friday.", ago: 21),
            review(lagoonResort, funmi, 5, "The cabana was spotless and the lagoon pool is perfect for kids. We'll be back.", ago: 14),
            review(maitamaCourt, ada, 5, "Quiet, fast Wi-Fi and staff who remember your name. Ideal for work trips.", ago: 33),
            review(skyLoft, tunde, 5, "Exactly like the photos. Amara was super responsive.", ago: 18),
            review(ekoBeach, funmi, 5, "Woke up to the ocean every morning. Perfect family weekend.", ago: 45)
        ]

        let threads = [
            ChatThread(id: UUID(), listingID: skyLoft.id, userID: ada.id, agentID: amara.id, messages: [
                ChatMessage(id: UUID(), senderID: ada.id, text: "Hi Amara, is parking available for two cars?", sentAt: days(-5, hour: 10)),
                ChatMessage(id: UUID(), senderID: amara.id, text: "Hi Ada! Yes, there are two dedicated spots in the basement.", sentAt: days(-5, hour: 11))
            ], lastReadByUser: days(-5, hour: 12), lastReadByAgent: days(-5, hour: 12)),
            ChatThread(id: UUID(), listingID: ikoyiDuplex.id, userID: tunde.id, agentID: adeola.id, messages: [
                ChatMessage(id: UUID(), senderID: tunde.id, text: "Good afternoon. Is the duplex still available?", sentAt: now.addingTimeInterval(-9000)),
                ChatMessage(id: UUID(), senderID: tunde.id, text: "Also, does the rent include service charge?", sentAt: now.addingTimeInterval(-8800))
            ], lastReadByUser: now, lastReadByAgent: days(-1))
        ]

        func note(_ user: Account, _ kind: NotificationKind, _ title: String, _ body: String, hoursAgo: Double, read: Bool = false) -> AppNotification {
            AppNotification(id: UUID(), userID: user.id, kind: kind, title: title, body: body, createdAt: now.addingTimeInterval(-hoursAgo * 3600), isRead: read)
        }

        let notifications = [
            note(ada, .booking, "Booking confirmed", "Lekki Sky Loft confirmed your stay.", hoursAgo: 140, read: true),
            note(ada, .booking, "Viewing scheduled", "Banana Island Villa viewing is set for 10am.", hoursAgo: 60),
            note(ada, .inquiry, "Rental approved", "Gbagada 3-Bed Flat approved your inquiry. Pay to secure it.", hoursAgo: 90),
            note(adeola, .booking, "New viewing request", "Tunde B. wants to view Ikoyi Terrace Duplex.", hoursAgo: 2),
            note(adeola, .booking, "New booking request", "Funmi A. requested 3 nights at Abuja City Suite.", hoursAgo: 5),
            note(adeola, .listing, "Listing under review", "Lekki Phase 1 Penthouse was submitted for approval.", hoursAgo: 24, read: true),
            note(admin, .listing, "New listing to review", "Lekki Phase 1 Penthouse by Adeola Ogunleye.", hoursAgo: 24),
            note(admin, .listing, "New listing to review", "Yaba Mini Flat by Chinedu Eze.", hoursAgo: 3),
            note(admin, .system, "Agent verification", "Chinedu Eze registered as a landlord.", hoursAgo: 140),
            note(admin, .system, "Listing reported", "Abuja City Suite was reported by a user.", hoursAgo: 30),
            note(admin, .system, "Hotel-owner application", "Ibrahim Musa applied to list Garki Guesthouse.", hoursAgo: 40),
            note(admin, .listing, "New listing to review", "Garki Guesthouse by Ibrahim Musa.", hoursAgo: 20),
            note(ada, .booking, "Reservation confirmed", "The Eko Grand · Deluxe King. Confirmation \(h1.confirmationCode).", hoursAgo: 72),
            note(kemi, .booking, "New reservation", "Tunde B. booked 1 × Business Double at Maitama Court Hotel for 4 nights.", hoursAgo: 20),
            note(kemi, .booking, "New reservation", "Funmi A. booked 1 × Executive Suite at The Eko Grand for 3 nights.", hoursAgo: 46),
            note(kemi, .listing, "New 5★ review", "Tunde B. reviewed The Eko Grand.", hoursAgo: 200, read: true)
        ]

        let reports = [
            ListingReport(id: UUID(), listingID: abujaSuite.id, reporterID: tunde.id, reason: "Photos don't match", details: "The kitchen photo looks like a different apartment.", createdAt: now.addingTimeInterval(-30 * 3600), isResolved: false)
        ]

        return AppData(
            version: version,
            accounts: [ada, tunde, funmi, adeola, amara, chinedu, kemi, ibrahim, admin],
            listings: [ikoyiDuplex, viApartment, skyLoft, ekoBeach, abujaSuite, viStudio, bananaVilla, landPlot, gbagadaFlat, maitamaHome, ikoyiGarden, penthouse, yabaFlat, ekoGrand, lagoonResort, maitamaCourt, gardenCity, garkiGuesthouse],
            bookings: [b1, b2, b3, b4, b5, b6, b7, b8, b9, h1, h2, h3, h4, h5],
            payments: payments,
            threads: threads,
            notifications: notifications,
            reports: reports,
            reviews: reviews
        )
    }
}
