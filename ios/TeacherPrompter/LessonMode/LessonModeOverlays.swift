import SwiftUI

/// Big phase title shown briefly when the lesson enters a new section ("ERARBEITUNG").
struct SectionBannerView: View {
    let title: String
    let fontSize: CGFloat

    var body: some View {
        ZStack {
            Rectangle().fill(.regularMaterial).ignoresSafeArea()
            Text(title.uppercased())
                .font(.system(size: fontSize * 1.3, weight: .heavy))
                .tracking(fontSize * 0.08)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .padding(40)
        }
    }
}

struct UndoToast: View {
    let message: String
    let undoTitle: String
    var onUndo: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "checkmark.circle")
            Text(message)
            Button(undoTitle, action: onUndo)
                .fontWeight(.semibold)
        }
        .font(.title3)
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(.thickMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }
}

struct PauseOverlay: View {
    var onResume: () -> Void
    @Environment(\.loc) private var loc

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThickMaterial).ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "pause.circle")
                    .font(.system(size: 80, weight: .light))
                    .foregroundStyle(.secondary)
                Text(loc(.paused))
                    .font(.system(size: 56, weight: .bold))
                Text(loc(.pausedHint))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Button(action: onResume) {
                    Label(loc(.resume), systemImage: "play.fill")
                        .font(.title2.weight(.semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.space, modifiers: [])
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onResume)
    }
}

/// Small countdown pill in the header. Finishing is signalled quietly (pulse + haptic if available).
struct TimerPill: View {
    let timer: LessonSession.RunningTimer
    var onFinish: (UUID) -> Void
    var onCancel: () -> Void

    @Environment(\.loc) private var loc
    @State private var pulse = false

    var body: some View {
        Menu {
            Button(role: .destructive, action: onCancel) {
                Label(loc(.cancelTimer), systemImage: "xmark")
            }
        } label: {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = timer.end.timeIntervalSince(context.date)
                HStack(spacing: 6) {
                    Image(systemName: timer.finished ? "bell.fill" : "timer")
                    Text(timer.finished ? loc(.timerDone) : DurationFormat.clock(remaining))
                        .monospacedDigit()
                }
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundStyle(timer.finished ? Color.white : Color.primary)
                .background(timer.finished ? Color.red.opacity(pulse ? 0.9 : 0.55) : Color.secondary.opacity(0.15),
                            in: Capsule())
            }
        }
        .task(id: timer.id) {
            let remaining = timer.end.timeIntervalSinceNow
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            guard !Task.isCancelled else { return }
            onFinish(timer.id)
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
