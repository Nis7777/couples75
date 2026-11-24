# Prompt: add the paywall's 38% off offer in App Store Connect

Paste everything below the line into the Claude on the Mac (Cowork), signed in to appstoreconnect.apple.com in its
browser.

---

You're helping me add a new subscription to my iPhone app **Pact** in App Store Connect. Rules: never press
Submit for Review / Add for Review, never accept agreements or enter payment details; if a page looks different from
what's described, stop and tell me what you see.

1. App Store Connect → Apps → **Pact** → **Monetization → Subscriptions** → the subscription group **Pact**.
2. Create a new auto-renewable subscription:
   - Reference Name: `Pact Yearly Offer` (if it already exists, open it and just check steps 3–5)
   - Product ID: `com.tomasbeja.pact.yearlyoffer` (exactly this; the app looks for it)
   - Subscription Duration: **1 Year**
   - Family Sharing: off
3. Price: base country **United States**, **$24.99**. Let Apple fill in the other countries, then open the full
   price list and set by hand: every **eurozone** country (Portugal, Spain, France, Germany, Italy, Netherlands,
   Ireland and the rest) to **24,99 €**, and the **United Kingdom** to **£24.99**. Tell me which ones you changed.
4. **No introductory offer** (no free trial) for this one. If one was added, delete it.
5. Localization (English U.S.): Display Name `Pact Yearly (38% off)`, Description
   `Pact for both of you, 38% off, billed yearly`.
6. Review Information → Review Screenshot: leave it empty and tell me (I'll upload a screenshot of the offer
   screen). Review Notes: `Shown once, when the user closes the paywall during onboarding. 38% off the regular
   yearly plan.`
7. Ranking (levels) in the group: keep **Pact Yearly** and **Pact Yearly 7-day trial** on separate levels, as they
   are. Put **Pact Yearly Offer** on the same level as Pact Yearly, or on its own level right below it if that's not
   possible. **Pact Monthly** stays at the bottom. The app doesn't depend on the levels.
8. App Store → the **1.0** version page → **In-App Purchases and Subscriptions**: make sure all four are added (Pact
   Yearly, Pact Yearly 7-day trial, Pact Monthly, Pact Yearly Offer). Keep the 7-day trial: the offer screen uses it.
   Save.
9. Tell me: that it was created and its status, the prices you set by hand, and what's still missing (the review
   screenshot).
