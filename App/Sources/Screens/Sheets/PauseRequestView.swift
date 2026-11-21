import SwiftUI

/// 4.9 requester side: "Life happens".
struct PauseRequestView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var days = 1
    @State private var startTomorrow = false
    @State private var reason = "Travelling"
    @State private var custom = ""
    @State private var sending = false

    private let presets = ["Travelling", "Sick", "Custom"]
    private var finalReason: String { reason == "Custom" ? custom.trimmingCharacters(in: .whitespaces) : reason }
    private var canRequest: Bool {
        !model.pauseUsedThisRound && model.currentRound?.status == .active
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SmallLabel(text: "Life happens")
                    TitleText("Pause the run", size: 26)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !canRequest {
                        Banner(text: model.pauseUsedThisRound
                               ? "You've already used this round's pause. One per round."
                               : "You can pause once Day 1 has started.",
                               fill: .peach, foreground: .coral, icon: "info.circle")
                    }
                    BodyText("Once per round. Paused days don't count for either of you and don't use a save. \(model.partnerName) can agree or say not now; no answer in \(Int(Brand.pauseAutoAcceptHours)) hours means yes.",
                             alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        label("How many days?")
                        Picker("Days", selection: $days) {
                            ForEach(1...Brand.maxPauseDays, id: \.self) { d in Text("\(d) day\(d == 1 ? "" : "s")").tag(d) }
                        }
                        .pickerStyle(.segmented)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        label("Starting")
                        Picker("Starting", selection: $startTomorrow) {
                            Text("Today").tag(false)
                            Text("Tomorrow").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        label("Reason")
                        HStack(spacing: 8) {
                            ForEach(presets, id: \.self) { p in
                                Button {
                                    reason = p
                                } label: {
                                    Text(p)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(reason == p ? .white : Color.textPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 9)
                                        .background(Capsule().fill(reason == p ? Color.coral : Color.white))
                                        .overlay(Capsule().stroke(reason == p ? Color.coral : Color.cardBorder, lineWidth: 1))
                                }
                                .accessibilityAddTraits(reason == p ? .isSelected : [])
                            }
                        }
                        if reason == "Custom" {
                            TextField("What's going on?", text: $custom)
                                .padding(14)
                                .card(radius: 14)
                                .onChange(of: custom) { _, new in if new.count > 60 { custom = String(new.prefix(60)) } }
                        }
                    }
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                BottomActions {
                    PrimaryButton("Send request", isEnabled: canRequest && !finalReason.isEmpty, isLoading: sending) {
                        Task {
                            sending = true
                            let ok = await model.requestPause(days: days, startTomorrow: startTomorrow, reason: finalReason)
                            sending = false
                            if ok {
                                model.toast = "Pause request sent."
                                dismiss()
                            }
                        }
                    }
                }
                .background(Color.ivory)
            }
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Color.textPrimary)
    }
}
