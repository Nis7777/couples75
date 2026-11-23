import SwiftUI
import UIKit

/// Step 7 (06): "What do you want to level up?": Body, Looks and Mind & money, each a 2-column grid of rounded
/// cards; selected ones are coral with a white check.
struct GoalsView: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    var back: () -> Void
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        OnboardingPage(step: model.draft.stepNumber, back: back) {
            // Three groups don't fit on one screen: this page scrolls on its own (like the plan review).
            ScrollView(showsIndicators: false) {
            VStack(spacing: 8) {
                TitleText("What do you want to level up together?", size: 30)
                    .padding(.top, 26)
                Text("Pick two or more. Each one becomes a daily habit.")
                    .font(.app(17))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 10)
                ForEach(Area.allCases) { area in
                    HStack(spacing: 8) {
                        CustomIcon(asset: area.asset, symbol: area.icon, size: 24)
                        Text(area.title).font(.app(18, .bold)).foregroundStyle(Color.textPrimary)
                        Spacer()
                    }
                    .padding(.top, 8)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Goal.allCases.filter { $0.area == area }) { g in goalChip(g) }
                    }
                }
            }
            .padding(.bottom, 16)
            }
        } actions: {
            PrimaryButton("Continue", isEnabled: model.draft.goals.count >= 2) { next() }
        }
    }

    private func goalChip(_ g: Goal) -> some View {
        let selected = model.draft.goals.contains(g)
        return Button {
            Haptics.tap()
            withAnimation(.open(0.22)) {
                if selected { model.draft.goals.removeAll { $0 == g } } else { model.draft.goals.append(g) }
                model.draft.ruleChanges = []   // the plan's rows change with the goals
            }
        } label: {
            HStack(spacing: 10) {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .bold))
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                } else if UIImage(named: g.asset) != nil {
                    Image(g.asset).resizable().scaledToFit().frame(width: 28, height: 28)
                } else {
                    Image(systemName: g.icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.coral)
                }
                Text(g.title)
                    .font(.app(18, .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(selected ? Color.white : Color.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(selected ? Color.coral : Color.white))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(selected ? Color.coral : Color.cardBorder, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(g.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
