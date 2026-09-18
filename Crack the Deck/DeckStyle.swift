import SwiftUI

struct DeckStyle: Identifiable, Equatable {
    let id: String
    let name: String
    let winsRequired: Int
    let topColor: Color
    let bottomColor: Color
    let emblem: String
    let isPrismatic: Bool

    var gradient: LinearGradient {
        LinearGradient(colors: [topColor, bottomColor], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let classic = DeckStyle(
        id: "classic", name: "Classic", winsRequired: 0,
        topColor: Color(red: 0.16, green: 0.32, blue: 0.62),
        bottomColor: Color(red: 0.06, green: 0.14, blue: 0.36),
        emblem: "suit.spade.fill", isPrismatic: false
    )

    static let all: [DeckStyle] = [
        .classic,
        DeckStyle(
            id: "ocean", name: "Deep Sea", winsRequired: 1,
            topColor: Color(red: 0.0, green: 0.62, blue: 0.66),
            bottomColor: Color(red: 0.0, green: 0.28, blue: 0.4),
            emblem: "water.waves", isPrismatic: false
        ),
        DeckStyle(
            id: "crimson", name: "Crimson Blaze", winsRequired: 3,
            topColor: Color(red: 0.85, green: 0.18, blue: 0.18),
            bottomColor: Color(red: 0.35, green: 0.02, blue: 0.06),
            emblem: "flame.fill", isPrismatic: false
        ),
        DeckStyle(
            id: "royal", name: "Royal Velvet", winsRequired: 5,
            topColor: Color(red: 0.52, green: 0.14, blue: 0.72),
            bottomColor: Color(red: 0.2, green: 0.03, blue: 0.32),
            emblem: "crown.fill", isPrismatic: false
        ),
        DeckStyle(
            id: "gold", name: "Golden", winsRequired: 10,
            topColor: Color(red: 0.95, green: 0.78, blue: 0.25),
            bottomColor: Color(red: 0.6, green: 0.42, blue: 0.04),
            emblem: "star.fill", isPrismatic: false
        ),
        DeckStyle(
            id: "prismatic", name: "Galaxy", winsRequired: 100,
            topColor: Color(red: 0.1, green: 0.62, blue: 0.72),
            bottomColor: Color(red: 0.32, green: 0.08, blue: 0.52),
            emblem: "sparkles", isPrismatic: true
        ),
    ]

    static func isUnlocked(_ style: DeckStyle, decksBeaten: Int) -> Bool {
        decksBeaten >= style.winsRequired
    }
}

/// Renders a card's back face for the given deck style — reused by the grid's
/// dead cells, the shuffle animation, and the deck-style picker's thumbnails.
struct CardBackView: View {
    let style: DeckStyle
    var cornerRadius: CGFloat = 10

    @State private var hueRotation: Double = -25

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(style.gradient)
            if style.isPrismatic {
                NebulaCloud(colors: (style.topColor, style.bottomColor))
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                Starfield()
            }
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                .padding(4)
            Image(systemName: style.emblem)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white.opacity(0.45))
        }
        .hueRotation(.degrees(style.isPrismatic ? hueRotation : 0))
        .onAppear {
            guard style.isPrismatic else { return }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                hueRotation = 25
            }
        }
    }
}

/// A soft two-tone nebula haze — reused behind the Galaxy deck's back and front.
struct NebulaCloud: View {
    let colors: (Color, Color)

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [colors.0.opacity(0.6), .clear], center: .center, startRadius: 0, endRadius: 40))
                .frame(width: 72, height: 72)
                .offset(x: -14, y: -10)
                .blur(radius: 6)
            Circle()
                .fill(RadialGradient(colors: [colors.1.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 40))
                .frame(width: 72, height: 72)
                .offset(x: 16, y: 14)
                .blur(radius: 6)
        }
    }
}

/// A scattering of twinkling stars — reused behind the Galaxy deck's back and front.
struct Starfield: View {
    private let stars: [(CGFloat, CGFloat, CGFloat, Double)] = [
        (-30, -42, 2, 0.9), (26, -36, 1.4, 0.7), (-38, 18, 1.6, 0.8),
        (34, 28, 2, 0.9), (4, -50, 1.4, 0.6), (-10, 44, 1.8, 0.85),
        (40, -8, 1.4, 0.7), (-44, -4, 1.6, 0.8), (14, 6, 1.2, 0.6),
        (-18, -20, 1.4, 0.75),
    ]

    @State private var twinkle = false

    var body: some View {
        ZStack {
            ForEach(0..<stars.count, id: \.self) { i in
                let star = stars[i]
                Circle()
                    .fill(Color.white.opacity(star.3))
                    .frame(width: star.2, height: star.2)
                    .offset(x: star.0, y: star.1)
                    .opacity(i % 3 == 0 ? (twinkle ? 1 : 0.35) : 1)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                twinkle = true
            }
        }
    }
}
