import SwiftUI
import UIKit

/// "Leave {partner}?" (6.5). First offers to save my own photos, then leaves.
struct LeaveCoupleSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var myPhotos: [Image] = []
    @State private var confirm = false
    @State private var leaving = false

    var body: some View {
        VStack(spacing: 16) {
            Capsule().fill(Color.cardBorder).frame(width: 40, height: 5).padding(.top, 10)
            TitleText("Leave \(model.partnerName)?", size: 26)
                .padding(.top, 8)
            BodyText("Your run ends, and everything you shared is deleted from iCloud. \(model.partnerName) stops seeing anything new from you.")
            Text(model.iAmPayer
                 ? "You're the one paying: leaving doesn't cancel your subscription. You can keep it for a new pact, or cancel it in Settings → your name → Subscriptions."
                 : "\(model.payerName) pays for your pact, so after you leave you'd need your own subscription to start a new one.")
                .font(.app(14, .medium))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if !myPhotos.isEmpty {
                ShareLink(items: myPhotos, preview: { _ in SharePreview("My \(Brand.appName) photo") }) {
                    Text("Save my photos")
                        .font(.app(17, .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Capsule().fill(Color.white))
                        .overlay(Capsule().stroke(Color.buttonBorder, lineWidth: 1))
                }
            }
            Button(role: .destructive) {
                confirm = true
            } label: {
                Text("Leave couple")
                    .font(.app(18, .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Capsule().fill(Color.red))
            }
            .disabled(leaving)
            TextLinkButton("Cancel") { dismiss() }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .screenBackground()
        .presentationDetents([.medium, .large])
        .task { await loadPhotos() }
        .confirmationDialog("Leave the couple?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Leave couple", role: .destructive) {
                Task {
                    leaving = true
                    let ok = await model.leaveCouple()
                    leaving = false
                    if ok { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func loadPhotos() async {
        var images: [Image] = []
        for c in model.checkIns(of: model.meID) where c.hasPhoto {
            var data = model.cachedPhoto(c.id)
            if data == nil { data = await model.photoData(for: c) }
            if let data, let ui = UIImage(data: data) { images.append(Image(uiImage: ui)) }
        }
        myPhotos = images
    }
}
