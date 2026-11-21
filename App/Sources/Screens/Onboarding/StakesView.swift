import SwiftUI

/// Step 15 (12): "Set the stakes" + hold to sign.
struct StakesView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void

    var body: some View {
        @Bindable var model = model
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    TitleText("Set the stakes")
                        .padding(.top, 12)
                    Text("\(model.draft.partnerName) accepts this when they join.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textSecondary)
                        .padding(.bottom, 8)
                    BetPicker(bet: $model.draft.bet, customBet: $model.draft.customBet)
                    VStack(spacing: 6) {
                        Text("Hold to sign")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        Text("We finish this together")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                        HoldToSignButton(enabled: !model.draft.betText.isEmpty) { next() }
                            .padding(.top, 8)
                    }
                    .padding(.top, 16)
                }
                .padding(.bottom, 12)
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
                OptionCard(title: o.title, isSelected: bet == o) {
                    bet = o
                    customFocused = o == .custom
                }
            }
            if bet == .custom {
                TextField("Loser…", text: $customBet)
                    .font(.system(size: 17))
                    .focused($customFocused)
                    .padding(16)
                    .card(radius: 14)
                    .onChange(of: customBet) { _, new in
                        if new.count > BetOption.customMaxLength {
                            customBet = String(new.prefix(BetOption.customMaxLength))
                        }
                    }
                    .accessibilityLabel("Custom bet, up to 40 characters")
                Text("\(customBet.count)/\(BetOption.customMaxLength)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

/// Fingerprint button: hold for 1.5 s with a filling coral ring, success haptic, then advance.
struct HoldToSignButton: View {
    var enabled: Bool
    var onSigned: () -> Void
    @State private var progress: CGFloat = 0
    @State private var holding = false
    @State private var signed = false
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Circle().fill(Color.white)
            Circle().stroke(Color.peach, lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.coral, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: signed ? "checkmark" : "touchid")
                .font(.system(size: 38, weight: .regular))
                .foregroundStyle(enabled ? Color.coral : Color.coral.opacity(0.4))
        }
        .frame(width: 96, height: 96)
        .scaleEffect(holding ? 0.94 : 1)
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
        Haptics.success()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            onSigned()
        }
    }
}
