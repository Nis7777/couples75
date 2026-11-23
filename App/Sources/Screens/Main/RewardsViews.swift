import SwiftUI

/// Progress → "Badges": earned ones in colour, the rest greyed out with what unlocks them.
struct BadgesCard: View {
    @Environment(AppModel.self) private var model
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10),
                           GridItem(.flexible(), spacing: 10)]

    var body: some View {
        let badges = model.badges
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Badges").font(.app(20, .semibold)).foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(badges.filter(\.earned).count) of \(badges.count)")
                    .font(.app(13, .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(badges) { b in
                    VStack(spacing: 6) {
                        Image(systemName: b.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(b.earned ? Color.white : Color.textSecondary.opacity(0.45))
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(b.earned ? Color.coral : Color.faint))
                        Text(b.title)
                            .font(.app(12, .semibold))
                            .foregroundStyle(b.earned ? Color.textPrimary : Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(b.title), \(b.earned ? "earned" : "locked: \(b.detail)")")
                }
            }
        }
        .padding(18)
        .card()
    }
}

/// Progress → "Our bucket list": shared, either partner can add or tick off. Also the shared reward
/// when a round ends with nobody owing.
struct BucketListCard: View {
    @Environment(AppModel.self) private var model
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Our bucket list").font(.app(20, .semibold)).foregroundStyle(Color.textPrimary)
            Text("Things to do together. Finish a challenge with nobody owing and one becomes your shared reward.")
                .font(.app(13))
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(model.bucketList) { item in
                HStack(spacing: 10) {
                    Button {
                        guard item.doneAt == nil else { return }
                        Task { await model.markBucketItemDone(item) }
                    } label: {
                        CheckCircle(isOn: item.doneAt != nil, size: 22)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.doneAt == nil ? "Mark \(item.text) done" : "\(item.text), done")
                    Text(item.text)
                        .font(.app(15, .medium))
                        .foregroundStyle(item.doneAt == nil ? Color.textPrimary : Color.textSecondary)
                        .strikethrough(item.doneAt != nil, color: Color.textSecondary)
                    Spacer(minLength: 4)
                    if item.rewardRound != nil {
                        Pill(text: "Reward", fill: .gold, size: 11)
                    }
                }
            }
            HStack(spacing: 10) {
                TextField("Add something to do together", text: $text)
                    .font(.app(15))
                    .submitLabel(.done)
                    .onSubmit { add() }
                Button("Add") { add() }
                    .font(.app(15, .semibold))
                    .foregroundStyle(Color.coral)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.peach.opacity(0.6)))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func add() {
        let t = text
        text = ""
        Task { await model.addBucketItem(t) }
    }
}

/// End of a round with nobody owing: pick a shared reward from the bucket list.
struct RewardPickerCard: View {
    @Environment(AppModel.self) private var model
    var round: RoundState
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nobody owes. Treat yourselves.").font(.app(18, .bold)).foregroundStyle(Color.textPrimary)
            if let chosen = model.reward(for: round.number) {
                HStack {
                    Image(systemName: "star.fill").foregroundStyle(Color.gold)
                    Text("Your reward: \(chosen.text)").font(.app(16, .semibold)).foregroundStyle(Color.textPrimary)
                }
            } else {
                let open = model.bucketList.filter { $0.doneAt == nil }
                if open.isEmpty {
                    Text("Add something you'd both love to do. It becomes your shared reward.")
                        .font(.app(14)).foregroundStyle(Color.textSecondary)
                } else {
                    ForEach(open.prefix(5)) { item in
                        Button { Task { await model.chooseReward(item, round: round.number) } } label: {
                            HStack {
                                Text(item.text).font(.app(15, .medium)).foregroundStyle(Color.textPrimary)
                                Spacer()
                                Text("Pick ›").font(.app(14, .semibold)).foregroundStyle(Color.coral)
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 46)
                            .card(radius: 14, shadow: false)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                HStack(spacing: 10) {
                    TextField("Something new…", text: $text).font(.app(15))
                    Button("Add") {
                        let t = text
                        text = ""
                        Task { await model.addBucketItem(t) }
                    }
                    .font(.app(15, .semibold))
                    .foregroundStyle(Color.coral)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .card(radius: 14, shadow: false)
            }
        }
        .padding(16)
        .peachBox(radius: 18)
    }
}
