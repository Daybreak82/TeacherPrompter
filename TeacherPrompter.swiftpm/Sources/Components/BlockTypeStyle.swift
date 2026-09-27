import SwiftUI

extension BlockType {
    var symbol: String {
        switch self {
        case .say: return "quote.bubble"
        case .question: return "questionmark.circle"
        case .expectedAnswer: return "text.bubble"
        case .action: return "hand.point.up.left"
        case .experiment: return "testtube.2"
        case .slide: return "rectangle.on.rectangle"
        case .note: return "note.text"
        case .timer: return "timer"
        case .transition: return "arrow.turn.down.right"
        }
    }

    /// Muted accents – colour only on the small type label, never on the text itself.
    var tint: Color {
        switch self {
        case .say: return .primary
        case .question: return .blue
        case .expectedAnswer: return .green
        case .action: return .orange
        case .experiment: return .purple
        case .slide: return .teal
        case .note: return .gray
        case .timer: return .red
        case .transition: return .indigo
        }
    }

    func label(_ language: UILanguage) -> String {
        let pair: (de: String, en: String)
        switch self {
        case .say: pair = ("Sagen", "Say")
        case .question: pair = ("Frage", "Question")
        case .expectedAnswer: pair = ("Erwartete Antwort", "Expected Answer")
        case .action: pair = ("Aktion", "Action")
        case .experiment: pair = ("Experiment", "Experiment")
        case .slide: pair = ("Folie", "Slide")
        case .note: pair = ("Notiz", "Note")
        case .timer: pair = ("Timer", "Timer")
        case .transition: pair = ("Überleitung", "Transition")
        }
        return language == .de ? pair.de : pair.en
    }
}

struct BlockTypeLabel: View {
    let type: BlockType
    var size: CGFloat = 15
    @Environment(\.loc) private var loc

    var body: some View {
        HStack(spacing: size * 0.4) {
            Image(systemName: type.symbol)
            Text(type.label(loc.language).uppercased())
                .tracking(size * 0.08)
        }
        .font(.system(size: size, weight: .semibold))
        .foregroundStyle(type.tint)
        .accessibilityElement(children: .combine)
    }
}

struct SlideBadge: View {
    let number: Int
    var size: CGFloat = 15
    @Environment(\.loc) private var loc

    var body: some View {
        Text(loc(.slideBadge(number)))
            .font(.system(size: size, weight: .bold))
            .monospacedDigit()
            .padding(.horizontal, size * 0.6)
            .padding(.vertical, size * 0.25)
            .overlay(Capsule().stroke(Color.secondary.opacity(0.5), lineWidth: 1))
            .foregroundStyle(.secondary)
    }
}

struct ImportantMark: View {
    var size: CGFloat = 15

    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(size: size))
            .foregroundStyle(.yellow)
            .accessibilityLabel("★")
    }
}

struct ThinProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(Color.accentColor.opacity(0.7))
                    .frame(width: geometry.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 4)
        .animation(.smooth, value: value)
    }
}

enum DurationFormat {
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func minutes(_ seconds: TimeInterval) -> String {
        let minutes = seconds / 60
        return minutes == minutes.rounded() ? "\(Int(minutes)) min" : clock(seconds)
    }
}
