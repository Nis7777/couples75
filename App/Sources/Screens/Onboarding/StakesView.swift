import SwiftUI

/// Step 15 (12): "Set the stakes": option cards, then "Hold to sign" with the fingerprint inside
/// concentric coral rings.
struct StakesView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        @Bindable var model = model
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    TitleText("Set the stakes", size: 30)
                        .padding(.top, 22)
                    Text("\(model.draft.partnerName) accepts this when they join.")
                        .font(.app(15))
                        .foregroundStyle(Color.textSecondary)
                        .padding(.bottom, 10)
                    BetPicker(bet: $model.draft.bet, customBet: $model.draft.customBet)
                    VStack(spacing: 4) {
                        Text("Hold to sign")
                            .font(.app(20, .bold))
                            .foregroundStyle(Color.textPrimary)
                        Text("We finish this together")
                            .font(.app(15))
                            .foregroundStyle(Color.textSecondary)
                        HoldToSignButton(enabled: !model.draft.betText.isEmpty) { next() }
                            .padding(.top, 14)
                    }
                    .padding(.top, 34)
                }
                .padding(.bottom, 18)
            }
            .scrollDismissesKeyboard(.interactively)
        } actions: {
            EmptyView()
        }
    }
}

/// The four bet options (Custom opens a one-line field, max 40 characters).
struct BetPicker: View {
    @Binding var bet: BetOption
    @Binding var customBet: String
    @FocusState private var customFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            ForEach(BetOption.allCases) { o in
                OptionCard(title: o.title, isSelected: bet == o, minHeight: 56) {
                    bet = o
                    customFocused = o == .custom
                }
            }
            if bet == .custom {
                TextField("Loser…", text: $customBet)
                    .font(.app(17, .medium))
                    .focused($customFocused)
                    .padding(16)
                    .card(radius: 16, shadow: false)
                    .onChange(of: customBet) { _, new in
                        if new.count > BetOption.customMaxLength {
                            customBet = String(new.prefix(BetOption.customMaxLength))
                        }
                    }
                    .accessibilityLabel("Custom bet, up to 40 characters")
                Text("\(customBet.count)/\(BetOption.customMaxLength)")
                    .font(.app(12))
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

/// Fingerprint inside concentric coral rings: hold for 1.5 s while a coral ring fills,
/// success haptic, then advance.
struct HoldToSignButton: View {
    var enabled: Bool
    var onSigned: () -> Void
    @State private var progress: CGFloat = 0
    @State private var holding = false
    @State private var signed = false
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Circle().fill(Color.peach)
            Circle().fill(Color.white).padding(9)
            Circle()
                .stroke(Color.coral.opacity(0.25), lineWidth: 5)
                .padding(16)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.coral, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(16)
            Image(systemName: signed ? "checkmark" : "touchid")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(enabled ? Color.coral : Color.coral.opacity(0.4))
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: 124, height: 124)
        .scaleEffect(holding ? 0.95 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: holding)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !holding && enabled && !signed { start() } }
                .onEnded { _ in cancel() }
        )
        .accessibilityElement()
        .accessibilityLabel("Hold to sign")
        .accessibilityHint("Double tap to sign the bet")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { if enabled { complete() } }
    }

    private func start() {
        holding = true
        Haptics.tap()
        withAnimation(.linear(duration: 1.5)) { progress = 1 }
        holdTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled, holding else { return }
            complete()
        }
    }

    private func cancel() {
        guard !signed else { return }
        holding = false
        holdTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
    }

    private func complete() {
        signed = true
        holding = false
        progress = 1
        Haptics.heavy()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            onSigned()
        }
    }
}
