import SwiftUI

struct ShuffleView: View {
    let deckStyle: DeckStyle

    @State private var animate = false

    private let cardCount = 5

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                ForEach(0..<cardCount, id: \.self) { i in
                    CardBackView(style: deckStyle, cornerRadius: 10)
                        .frame(width: 70, height: 100)
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                        .offset(x: animate ? offsetX(for: i) : 0, y: CGFloat(i) * 1.5)
                        .rotationEffect(.degrees(animate ? rotation(for: i) : 0))
                        .zIndex(Double(cardCount - i))
                        .animation(
                            .easeInOut(duration: 0.28)
                                .repeatCount(6, autoreverses: true)
                                .delay(Double(i) * 0.05),
                            value: animate
                        )
                }
            }
            .frame(height: 110)

            Text("Shuffling…")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
        .onAppear { animate = true }
    }

    private func offsetX(for index: Int) -> CGFloat {
        index % 2 == 0 ? 18 : -18
    }

    private func rotation(for index: Int) -> Double {
        index % 2 == 0 ? 8 : -8
    }
}
