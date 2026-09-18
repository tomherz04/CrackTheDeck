import SwiftUI

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: CGFloat
    let delay: Double
    let duration: Double
    let rotation: Double
    let color: Color
    let width: CGFloat
    let height: CGFloat
}

struct ConfettiView: View {
    @State private var animate = false

    private let pieces: [ConfettiPiece] = (0..<70).map { _ in
        ConfettiPiece(
            x: CGFloat.random(in: 0...1),
            delay: Double.random(in: 0...0.5),
            duration: Double.random(in: 1.8...3.2),
            rotation: Double.random(in: 240...720) * (Bool.random() ? 1 : -1),
            color: [.yellow, .pink, .green, .cyan, .orange, .purple, .white].randomElement()!,
            width: CGFloat.random(in: 6...11),
            height: CGFloat.random(in: 8...16)
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: piece.width, height: piece.height)
                        .rotationEffect(.degrees(animate ? piece.rotation : 0))
                        .position(
                            x: piece.x * geo.size.width,
                            y: animate ? geo.size.height + 40 : -40
                        )
                        .animation(
                            .easeIn(duration: piece.duration).delay(piece.delay),
                            value: animate
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}
