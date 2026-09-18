import SwiftUI
import UIKit

struct ShareCardView: View {
    let totalCorrect: Int
    let bestStreak: Int
    let decksBeaten: Int

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.18, blue: 0.38),
                    Color(red: 0.03, green: 0.07, blue: 0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 28) {
                Text("🎉")
                    .font(.system(size: 64))
                Text("I beat the deck!")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                VStack(spacing: 16) {
                    statRow(label: "Correct guesses", value: "\(totalCorrect)")
                    statRow(label: "Best streak", value: "🔥 \(bestStreak)")
                    statRow(label: "Decks beaten (all-time)", value: "\(decksBeaten)")
                }
                .padding(28)
                .background(Color.white.opacity(0.08))
                .cornerRadius(20)

                Text("CRACK THE DECK")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .tracking(3)
            }
            .padding(44)
        }
        .frame(width: 600, height: 760)
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
            Spacer()
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(.orange)
        }
    }
}

@MainActor
func renderShareImageFile(totalCorrect: Int, bestStreak: Int, decksBeaten: Int) -> URL? {
    let view = ShareCardView(totalCorrect: totalCorrect, bestStreak: bestStreak, decksBeaten: decksBeaten)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 3

    guard let image = renderer.uiImage, let pngData = image.pngData() else { return nil }

    let url = FileManager.default.temporaryDirectory.appendingPathComponent("CrackTheDeckResult-\(UUID().uuidString).png")
    do {
        try pngData.write(to: url)
        return url
    } catch {
        return nil
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
