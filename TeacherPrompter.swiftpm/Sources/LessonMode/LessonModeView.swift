import SwiftUI
import UIKit

/// Lesson Mode – the main screen. Current block large in the centre, next block small below.
///
/// Controls (all lead to the same `LessonSession` actions):
/// - Tap / Apple Pencil tap on the current block → done, next block becomes current
/// - Swipe left → done / next, swipe right → back
/// - Keyboard: Space or → next, ← back, ⌘Z undo, P pause
/// - Long press on the current block → Edit · Skip · Move to later · Mark as important
struct LessonModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.loc) private var loc
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(SettingsKey.fontSize) private var fontSize: Double = SettingsDefaults.fontSize
    @AppStorage(SettingsKey.previewNext) private var previewNext = true
    @AppStorage(SettingsKey.hideCompleted) private var hideCompleted = false
    @AppStorage(SettingsKey.strikeCompleted) private var strikeCompleted = true
    @AppStorage(SettingsKey.showPrevious) private var showPrevious = true
    @AppStorage(SettingsKey.focusMode) private var focusMode = false

    @State private var session: LessonSession
    @State private var showOverview = false
    @State private var editingBlock: LessonBlock?
    @State private var chromeVisible = true
    @State private var chromeToken = UUID()
    @State private var confirmReset = false

    init(lesson: Lesson) {
        _session = State(initialValue: LessonSession(lesson: lesson))
    }

    private var size: CGFloat { CGFloat(fontSize) }
    private var showChrome: Bool { !focusMode || chromeVisible }

    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            ZStack {
                VStack(spacing: 0) {
                    header
                    currentZone
                    if previewNext {
                        nextZone
                            .frame(height: geometry.size.height * (landscape ? 0.24 : 0.22))
                    }
                    if showChrome {
                        bottomBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, landscape ? 64 : 36)
                .padding(.bottom, 8)

                overlays
            }
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .simultaneousGesture(swipeGesture)
            .background { keyboardShortcuts }
        }
        .inspector(isPresented: $showOverview) {
            LessonOverviewView(session: session, hideCompleted: hideCompleted) { block in
                perform(.forward) { session.jump(to: block) }
            }
            .inspectorColumnWidth(min: 300, ideal: 380, max: 520)
        }
        .sheet(item: $editingBlock) { block in
            BlockEditorView(block: block)
                .appEnvironment()
        }
        .confirmationDialog(loc(.resetLessonQuestion), isPresented: $confirmReset, titleVisibility: .visible) {
            Button(loc(.resetProgress), role: .destructive) {
                withAnimation { session.reset() }
            }
            Button(loc(.cancel), role: .cancel) {}
        }
        .statusBarHidden(focusMode)
        .persistentSystemOverlays(focusMode ? .hidden : .automatic)
        .onAppear {
            chromeVisible = !focusMode
            session.startClock()
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            session.stopClock()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { session.startClock() } else { session.stopClock() }
        }
        .onChange(of: focusMode) { _, isOn in
            withAnimation { chromeVisible = !isOn }
        }
        .task(id: chromeToken) {
            guard focusMode, chromeVisible else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, focusMode else { return }
            withAnimation { chromeVisible = false }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 18) {
                if showChrome {
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.semibold))
                    }
                    .accessibilityLabel(loc(.close))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.lesson.title)
                            .font(.headline)
                            .lineLimit(1)
                        if let title = session.currentSectionTitle {
                            Text(title)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 12)
                if let timer = session.timer {
                    TimerPill(timer: timer, onFinish: { session.timerDidFinish($0) }, onCancel: { session.cancelTimer() })
                }
                statusText
                if showChrome { controlButtons }
            }
            .frame(minHeight: 44)
            ThinProgressBar(value: session.progress)
        }
        .padding(.top, 12)
        .contentShape(Rectangle())
        .onTapGesture { revealChrome() }
    }

    private var statusText: some View {
        HStack(spacing: 14) {
            Text(loc(.position(session.position, session.total)))
            TimelineView(.periodic(from: .now, by: 15)) { context in
                Text(loc(.minutesProgress(Int(session.elapsed(at: context.date) / 60), session.lesson.plannedMinutes)))
            }
        }
        .font(.subheadline.monospacedDigit())
        .foregroundStyle(.secondary)
    }

    private var controlButtons: some View {
        HStack(spacing: 6) {
            Button { changeFont(by: -SettingsDefaults.fontStep) } label: {
                Image(systemName: "textformat.size.smaller")
            }
            .accessibilityLabel(loc(.textSmaller))
            Button { changeFont(by: SettingsDefaults.fontStep) } label: {
                Image(systemName: "textformat.size.larger")
            }
            .accessibilityLabel(loc(.textLarger))
            Button {
                withAnimation { focusMode.toggle() }
            } label: {
                Image(systemName: focusMode ? "eye.slash" : "eye")
            }
            .accessibilityLabel(loc(.focusMode))
            Button {
                showOverview.toggle()
            } label: {
                Image(systemName: "sidebar.right")
            }
            .accessibilityLabel(loc(.overview))
            Button {
                withAnimation { session.pause() }
            } label: {
                Image(systemName: "pause.circle")
            }
            .accessibilityLabel(loc(.pause))
            Menu {
                Toggle(loc(.previewNext), isOn: $previewNext)
                Toggle(loc(.hideCompleted), isOn: $hideCompleted)
                Toggle(loc(.focusMode), isOn: $focusMode)
                Divider()
                Button(role: .destructive) { confirmReset = true } label: {
                    Label(loc(.resetProgress), systemImage: "arrow.counterclockwise")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel(loc(.moreOptions))
        }
        .font(.title3)
        .buttonStyle(.borderless)
        .labelStyle(.iconOnly)
    }

    // MARK: Current

    private var currentZone: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showPrevious, !hideCompleted, let previous = session.previousDone {
                previousLine(previous)
                    .padding(.top, 16)
            }
            ZStack {
                if let block = session.current {
                    GeometryReader { zone in
                        ScrollView(.vertical, showsIndicators: false) {
                            CurrentBlockView(
                                block: block,
                                slide: session.effectiveSlide(of: block),
                                fontSize: size,
                                onStartTimer: { session.startTimer(duration: $0) }
                            )
                            .frame(maxWidth: .infinity, minHeight: zone.size.height, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture { perform(.forward) { session.completeCurrent() } }
                            .contextMenu { quickMenu(for: block) }
                        }
                    }
                    .id(block.id)
                    .transition(blockTransition)
                } else {
                    finishedView
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
    }

    private func previousLine(_ block: LessonBlock) -> some View {
        HStack(spacing: 10) {
            Image(systemName: block.isSkipped ? "forward" : "checkmark")
            Text(block.text.isEmpty ? block.type.label(loc.language) : block.text)
                .lineLimit(1)
                .strikethrough(strikeCompleted)
        }
        .font(.system(size: max(15, size * 0.34)))
        .foregroundStyle(.tertiary)
        .onTapGesture { perform(.backward) { session.goBack() } }
    }

    private var blockTransition: AnyTransition {
        switch session.direction {
        case .forward:
            return .asymmetric(insertion: .opacity.combined(with: .offset(y: 80)),
                               removal: .opacity.combined(with: .offset(y: -80)))
        case .backward:
            return .asymmetric(insertion: .opacity.combined(with: .offset(y: -80)),
                               removal: .opacity.combined(with: .offset(y: 80)))
        }
    }

    @ViewBuilder
    private func quickMenu(for block: LessonBlock) -> some View {
        Button { editingBlock = block } label: {
            Label(loc(.edit), systemImage: "pencil")
        }
        Button { perform(.forward) { session.skipCurrent() } } label: {
            Label(loc(.skip), systemImage: "forward")
        }
        Button { perform(.forward) { session.moveCurrentToLater() } } label: {
            Label(loc(.moveToLater), systemImage: "arrow.down.to.line")
        }
        Button { session.toggleImportant(block) } label: {
            Label(block.isImportant ? loc(.unmarkImportant) : loc(.markImportant),
                  systemImage: block.isImportant ? "star.slash" : "star")
        }
    }

    private var finishedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(.green)
            Text(loc(.lessonFinished))
                .font(.system(size: 44, weight: .bold))
            Text(loc(.lessonFinishedHint))
                .font(.title3)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Button { perform(.backward) { session.goBack() } } label: {
                    Label(loc(.back), systemImage: "chevron.left")
                }
                Button { showOverview = true } label: {
                    Label(loc(.overview), systemImage: "sidebar.right")
                }
                Button(action: close) {
                    Label(loc(.close), systemImage: "xmark")
                }
                .buttonStyle(.borderedProminent)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Next

    private var nextZone: some View {
        VStack(spacing: 0) {
            Divider()
            NextBlockView(block: session.next, slideChange: session.upcomingSlideChange, fontSize: size)
                .padding(.top, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
                .onTapGesture { revealChrome() }
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button { perform(.backward) { session.goBack() } } label: {
                Label(loc(.back), systemImage: "chevron.left")
            }
            .disabled(!session.canGoBack)

            Spacer()
            Text(loc(.tapHint))
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Spacer()

            Button { perform(.forward) { session.skipCurrent() } } label: {
                Label(loc(.skip), systemImage: "forward")
            }
            .disabled(session.isFinished)

            Button { perform(.forward) { session.completeCurrent() } } label: {
                Label(loc(.markDone), systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .disabled(session.isFinished)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .padding(.top, 10)
    }

    // MARK: Overlays

    @ViewBuilder
    private var overlays: some View {
        VStack {
            Spacer()
            if let undo = session.undo {
                UndoToast(message: undoMessage(undo.kind), undoTitle: loc(.undo)) {
                    perform(.backward) { session.performUndo() }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, previewNext ? 110 : 90)
                .task(id: undo.token) {
                    try? await Task.sleep(for: .seconds(6))
                    guard !Task.isCancelled else { return }
                    withAnimation { session.expireUndo(undo.token) }
                }
            }
        }

        if let banner = session.sectionBanner {
            SectionBannerView(title: banner.title, fontSize: size)
                .transition(.opacity)
                .onTapGesture { withAnimation { session.sectionBanner = nil } }
                .task(id: banner.id) {
                    try? await Task.sleep(for: .seconds(1.6))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.4)) {
                        if session.sectionBanner?.id == banner.id { session.sectionBanner = nil }
                    }
                }
        }

        if session.isPaused {
            PauseOverlay { withAnimation { session.resume() } }
                .transition(.opacity)
        }
    }

    private func undoMessage(_ kind: LessonSession.UndoKind) -> String {
        switch kind {
        case .completed: return loc(.undoCompleted)
        case .skipped: return loc(.undoSkipped)
        case .movedLater: return loc(.undoMovedLater)
        case .jumped: return loc(.undoJumped)
        case .wentBack: return loc(.undoWentBack)
        }
    }

    // MARK: Input

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > 90, abs(dx) > abs(dy) * 1.5, !session.isPaused else { return }
                if dx < 0 {
                    perform(.forward) { session.completeCurrent() }
                } else {
                    perform(.backward) { session.goBack() }
                }
            }
    }

    /// Hidden buttons that carry hardware-keyboard shortcuts (also work with page-turner pedals
    /// that send arrow keys).
    private var keyboardShortcuts: some View {
        Group {
            Group {
                Button("") { perform(.forward) { session.completeCurrent() } }
                .keyboardShortcut(.space, modifiers: [])
                Button("") { perform(.forward) { session.completeCurrent() } }
                .keyboardShortcut(.rightArrow, modifiers: [])
            Button("") { perform(.backward) { session.goBack() } }
                .keyboardShortcut(.leftArrow, modifiers: [])
            Button("") { perform(.backward) { session.performUndo() } }
                .keyboardShortcut("z", modifiers: .command)
            }
            .disabled(session.isPaused)
            Button("") { withAnimation { session.isPaused ? session.resume() : session.pause() } }
                .keyboardShortcut("p", modifiers: [])
        }
        .disabled(editingBlock != nil)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    // MARK: Helpers

    /// Sets the animation direction first, then changes the block on the next run-loop turn,
    /// so the outgoing card already knows which way to leave.
    private func perform(_ direction: LessonSession.Direction, _ action: @escaping () -> Void) {
        session.direction = direction
        Task { @MainActor in
            withAnimation(.smooth(duration: 0.35)) { action() }
        }
    }

    private func changeFont(by delta: Double) {
        let range = SettingsDefaults.fontRange
        fontSize = min(max(fontSize + delta, range.lowerBound), range.upperBound)
    }

    private func revealChrome() {
        guard focusMode else { return }
        withAnimation { chromeVisible = true }
        chromeToken = UUID()
    }

    private func close() {
        session.stopClock()
        dismiss()
    }
}
