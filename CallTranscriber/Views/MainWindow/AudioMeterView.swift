import SwiftUI

struct AudioMeterView: View {
    let systemLevel: Float
    let micLevel: Float

    var body: some View {
        HStack(spacing: 16) {
            LevelMeter(label: "System Audio", level: systemLevel, tint: .blue)
            LevelMeter(label: "Microphone", level: micLevel, tint: .green)
        }
    }
}

struct LevelMeter: View {
    let label: String
    let level: Float
    let tint: Color

    private let barCount = 20

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)

            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { i in
                    let threshold = Float(i) / Float(barCount)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(index: i, level: level))
                        .frame(width: 6, height: 16)
                        .opacity(level > threshold ? 1.0 : 0.2)
                        .animation(.linear(duration: 0.05), value: level)
                }
            }
        }
    }

    private func barColor(index: Int, level: Float) -> Color {
        let ratio = Float(index) / Float(barCount)
        if ratio > 0.85 { return .red }
        if ratio > 0.65 { return .yellow }
        return tint
    }
}
