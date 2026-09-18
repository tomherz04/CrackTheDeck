import SwiftUI

struct CardView: View {
    let state: CellState
    let isSelected: Bool
    let deckStyle: DeckStyle

    @State private var displayedState: CellState
    @State private var rotation: Double = 0
    @State private var shakeOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0

    init(state: CellState, isSelected: Bool, deckStyle: DeckStyle) {
        self.state = state
        self.isSelected = isSelected
        self.deckStyle = deckStyle
        _displayedState = State(initialValue: state)
    }

    private enum FrontVariant { case framed, standard, ornate, foil, oceanic, blaze, galaxy }

    private var frontVariant: FrontVariant {
        switch deckStyle.id {
        case "classic": return .standard
        case "royal": return .ornate
        case "gold": return .foil
        case "ocean": return .oceanic
        case "crimson": return .blaze
        case "prismatic": return .galaxy
        default: return .framed
        }
    }

    private var isFaceUp: Bool {
        if case .faceUp = displayedState { return true }
        return false
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundStyle)
            if isFaceUp && frontVariant == .framed {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .padding(9)
                cornerEmblems
            }
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.yellow : borderColor, lineWidth: isSelected ? 3 : borderWidth)
            content
        }
        .aspectRatio(0.7, contentMode: .fit)
        .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
        .scaleEffect((isSelected ? 1.05 : 1.0) * pulseScale)
        .offset(x: shakeOffset)
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
        .onChange(of: state) { _, newValue in
            animateChange(to: newValue)
        }
    }

    private static let creamColor = Color(red: 0.97, green: 0.955, blue: 0.925)

    private static let emberColor = Color(red: 1.0, green: 0.55, blue: 0.15)

    private var backgroundStyle: AnyShapeStyle {
        guard isFaceUp else { return AnyShapeStyle(deckStyle.gradient) }
        switch frontVariant {
        case .standard: return AnyShapeStyle(Color.white)
        case .ornate: return AnyShapeStyle(Self.creamColor)
        case .oceanic: return AnyShapeStyle(Color.white)
        case .blaze, .foil, .framed, .galaxy: return AnyShapeStyle(deckStyle.gradient)
        }
    }

    private var borderColor: Color {
        guard isFaceUp else { return Color.white.opacity(0.3) }
        switch frontVariant {
        case .standard: return Color.black.opacity(0.55)
        case .ornate: return deckStyle.topColor.opacity(0.55)
        case .oceanic: return deckStyle.topColor.opacity(0.6)
        case .blaze: return Self.emberColor.opacity(0.8)
        case .galaxy: return Color.white.opacity(0.4)
        case .foil: return deckStyle.bottomColor.opacity(0.6)
        case .framed: return Color.black.opacity(0.25)
        }
    }

    private var borderWidth: CGFloat {
        guard isFaceUp else { return 1 }
        switch frontVariant {
        case .standard, .ornate, .oceanic, .blaze, .galaxy: return 1.3
        case .foil, .framed: return 1
        }
    }

    private var cornerEmblems: some View {
        VStack {
            HStack {
                Image(systemName: deckStyle.emblem)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.95))
                Spacer()
            }
            Spacer()
            HStack {
                Spacer()
                Image(systemName: deckStyle.emblem)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.95))
                    .rotationEffect(.degrees(180))
            }
        }
        .padding(3)
    }

    @ViewBuilder
    private var content: some View {
        switch displayedState {
        case .faceUp(let card):
            switch frontVariant {
            case .framed: cardFace(card, dimmed: false)
            case .standard: standardFace(card)
            case .ornate: ornateFace(card)
            case .foil: foilFace(card)
            case .oceanic: oceanicFace(card)
            case .blaze: blazeFace(card)
            case .galaxy: galaxyFace(card)
            }
        case .faceDown(let card):
            cardFace(card, dimmed: true)
        }
    }

    private func cardFace(_ card: Card, dimmed: Bool) -> some View {
        VStack(spacing: 4) {
            Text(card.rankLabel)
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text(card.suit.rawValue)
                .font(.system(size: 20))
        }
        .foregroundColor(dimmed ? .white.opacity(0.55) : (card.suit.isRed ? .red : .black))
    }

    // MARK: - Classic: a standard deck of cards

    private func standardFace(_ card: Card) -> some View {
        let ink: Color = card.suit.isRed ? .red : .black
        return ZStack {
            cardFace(card, dimmed: false)
            indices(card, color: ink, rankFont: .system(size: 12, weight: .bold, design: .rounded), suitSize: 10, inset: 8)
        }
    }

    /// The big centered rank + suit used by every bespoke face design below.
    private func rankSuitText(_ card: Card, font: Font, suitSize: CGFloat, color: Color, spacing: CGFloat = 2) -> some View {
        VStack(spacing: spacing) {
            Text(card.rankLabel).font(font)
            Text(card.suit.rawValue).font(.system(size: suitSize))
        }
        .foregroundColor(color)
    }

    // MARK: - Royal Velvet: cream field, fine line-art emblem, serif indices

    private func ornateFace(_ card: Card) -> some View {
        let ink = card.suit.isRed ? Color(red: 0.62, green: 0.08, blue: 0.2) : Color(red: 0.16, green: 0.08, blue: 0.24)
        return ZStack {
            GeometricEmblem(color: deckStyle.topColor.opacity(0.5))
                .frame(width: 74, height: 74)
            rankSuitText(card, font: .system(size: 28, weight: .bold, design: .serif), suitSize: 17, color: ink)
            indices(card, color: ink, rankFont: .system(size: 11, weight: .semibold, design: .serif), suitSize: 8, inset: 9)
        }
    }

    // MARK: - Golden: full metallic field, bold contrasting numerals

    private func foilFace(_ card: Card) -> some View {
        let ink = card.suit.isRed ? Color(red: 0.5, green: 0.04, blue: 0.08) : Color(red: 0.14, green: 0.1, blue: 0.02)
        return ZStack {
            rankSuitText(card, font: .system(size: 27, weight: .heavy, design: .rounded), suitSize: 19, color: ink, spacing: 4)
                .shadow(color: .white.opacity(0.35), radius: 0.5, y: 0.5)
            indices(card, color: ink, rankFont: .system(size: 11, weight: .bold, design: .rounded), suitSize: 9, inset: 8)
        }
    }

    // MARK: - Deep Sea: white field, line-art octopus, monochrome ink

    private func oceanicFace(_ card: Card) -> some View {
        let ink = Color(red: 0.04, green: 0.22, blue: 0.32)
        return ZStack {
            VStack(spacing: 5) {
                OctopusShape()
                    .stroke(ink.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(width: 52, height: 60)
                rankSuitText(card, font: .system(size: 22, weight: .bold, design: .rounded), suitSize: 15, color: ink)
            }
            indices(card, color: ink, rankFont: .system(size: 11, weight: .bold, design: .rounded), suitSize: 9, inset: 8)
        }
    }

    // MARK: - Crimson Blaze: angular flame geometry, embers, glowing numerals

    private func blazeFace(_ card: Card) -> some View {
        ZStack {
            FlameShape()
                .stroke(Self.emberColor, lineWidth: 2)
                .frame(width: 60, height: 72)
                .offset(y: -4)
            FlameShape()
                .stroke(Color(red: 1.0, green: 0.85, blue: 0.35), lineWidth: 1.3)
                .frame(width: 34, height: 42)
                .offset(y: 10)
            embers
            rankSuitText(card, font: .system(size: 26, weight: .heavy, design: .rounded), suitSize: 17, color: .white)
                .shadow(color: .black.opacity(0.55), radius: 2)
            indices(card, color: .white, rankFont: .system(size: 11, weight: .bold, design: .rounded), suitSize: 9, inset: 8)
        }
    }

    private var embers: some View {
        ZStack {
            emberDot.offset(x: -24, y: -40)
            emberDot.offset(x: 26, y: -28)
            emberDot.offset(x: -18, y: 34)
            emberDot.offset(x: 22, y: 42)
        }
    }

    private var emberDot: some View {
        Circle()
            .fill(Color(red: 1.0, green: 0.75, blue: 0.3))
            .frame(width: 3, height: 3)
            .opacity(0.85)
    }

    // MARK: - Galaxy: nebula haze, starfield, spiral core

    private func galaxyFace(_ card: Card) -> some View {
        ZStack {
            NebulaCloud(colors: (deckStyle.topColor, deckStyle.bottomColor))
            Starfield()
            GalaxySwirl()
                .stroke(Color.white.opacity(0.45), lineWidth: 1.1)
                .frame(width: 62, height: 62)
            Circle()
                .fill(RadialGradient(colors: [.white, deckStyle.topColor.opacity(0.7), .clear], center: .center, startRadius: 0, endRadius: 12))
                .frame(width: 14, height: 14)
            rankSuitText(card, font: .system(size: 26, weight: .heavy, design: .rounded), suitSize: 17, color: .white)
                .shadow(color: deckStyle.topColor.opacity(0.9), radius: 3)
            indices(card, color: .white, rankFont: .system(size: 11, weight: .bold, design: .rounded), suitSize: 9, inset: 8)
        }
    }

    private func indices(_ card: Card, color: Color, rankFont: Font, suitSize: CGFloat, inset: CGFloat) -> some View {
        func index() -> some View {
            VStack(spacing: 0) {
                Text(card.rankLabel).font(rankFont)
                Text(card.suit.rawValue).font(.system(size: suitSize))
            }
            .foregroundColor(color)
        }
        return VStack {
            HStack { index(); Spacer() }
            Spacer()
            HStack { Spacer(); index().rotationEffect(.degrees(180)) }
        }
        .padding(inset)
    }

    private func animateChange(to newValue: CellState) {
        guard newValue != displayedState else { return }

        let isNowFaceUp: Bool
        if case .faceUp = newValue { isNowFaceUp = true } else { isNowFaceUp = false }

        Task { @MainActor in
            withAnimation(.easeIn(duration: 0.15)) {
                rotation = 90
            }
            try? await Task.sleep(nanoseconds: 150_000_000)

            displayedState = newValue
            rotation = -90
            withAnimation(.easeOut(duration: 0.15)) {
                rotation = 0
            }
            try? await Task.sleep(nanoseconds: 150_000_000)

            if isNowFaceUp {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                    pulseScale = 1.1
                }
                try? await Task.sleep(nanoseconds: 120_000_000)
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    pulseScale = 1.0
                }
            } else {
                for offset: CGFloat in [-8, 8, -5, 5, 0] {
                    withAnimation(.easeInOut(duration: 0.06)) {
                        shakeOffset = offset
                    }
                    try? await Task.sleep(nanoseconds: 60_000_000)
                }
            }
        }
    }
}

private struct GeometricEmblem: View {
    let color: Color

    var body: some View {
        ZStack {
            ring(offset: CGSize(width: -13, height: -9))
            ring(offset: CGSize(width: 13, height: -9))
            ring(offset: CGSize(width: 0, height: 13))
        }
    }

    private func ring(offset: CGSize) -> some View {
        ZStack {
            Circle().stroke(color, lineWidth: 1.1)
            Circle().stroke(color.opacity(0.6), lineWidth: 0.8).padding(7)
        }
        .frame(width: 38, height: 38)
        .offset(offset)
    }
}

private struct OctopusShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }

        // Dome head
        path.move(to: pt(0.26, 0.40))
        path.addCurve(to: pt(0.74, 0.40), control1: pt(0.28, 0.02), control2: pt(0.72, 0.02))
        path.addCurve(to: pt(0.26, 0.40), control1: pt(0.84, 0.56), control2: pt(0.16, 0.56))

        // Eyes
        path.addEllipse(in: CGRect(x: pt(0.37, 0.22).x, y: pt(0.37, 0.22).y, width: 0.07 * w, height: 0.07 * h))
        path.addEllipse(in: CGRect(x: pt(0.56, 0.22).x, y: pt(0.56, 0.22).y, width: 0.07 * w, height: 0.07 * h))

        // Six wavy tentacles trailing from the base of the head
        let starts: [CGFloat] = [0.24, 0.34, 0.44, 0.56, 0.66, 0.76]
        for (i, sx) in starts.enumerated() {
            let dir: CGFloat = sx < 0.5 ? -1 : 1
            let reach = 0.10 + CGFloat(i % 3) * 0.03
            path.move(to: pt(sx, 0.42))
            path.addCurve(
                to: pt(sx + dir * reach, 0.94),
                control1: pt(sx + dir * 0.06, 0.62),
                control2: pt(sx - dir * 0.04, 0.80)
            )
        }

        return path
    }
}

private struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }

        let points: [CGPoint] = [
            pt(0.30, 0.97), pt(0.18, 0.72), pt(0.36, 0.58),
            pt(0.25, 0.32), pt(0.50, 0.02), pt(0.66, 0.34),
            pt(0.80, 0.56), pt(0.62, 0.68), pt(0.76, 0.86),
            pt(0.60, 0.97),
        ]

        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

private struct GalaxySwirl: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) / 2
        let turns: CGFloat = 2.0
        let steps = 90

        var path = Path()
        for arm in 0..<2 {
            var first = true
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let angle = t * turns * 2 * .pi + CGFloat(arm) * .pi
                let radius = t * maxRadius
                let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                if first {
                    path.move(to: point)
                    first = false
                } else {
                    path.addLine(to: point)
                }
            }
        }
        return path
    }
}
