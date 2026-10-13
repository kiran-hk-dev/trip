# Manual QA checklist

Automated coverage is in `flutter test` (114 tests) and `flutter analyze`
(clean). This checklist covers what automation cannot: real devices, real
network, real gestures, and honest content review.

---

## How to run

```bash
# Offline, no Supabase needed. Fictional data, no network calls.
flutter run --dart-define=DEMO_MODE=true

# Against a real project.
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key> \
  --dart-define=APP_ENV=development
```

---

## Every screen, every platform

Run each of these on **Android, iOS and web**, at 390dp width and again at
320dp.

- [ ] No yellow-and-black overflow stripes anywhere
- [ ] No `RenderFlex` or layout exceptions in the console
- [ ] Nothing clipped or unreadable at 320dp
- [ ] Every screen reachable, and every back gesture returns where expected
- [ ] Bottom navigation and any drawer behave correctly on each platform

---

## Financial correctness

The engine is unit tested. Confirm it end to end through the UI.

- [ ] Enter `1,250.75` — parsed as the right minor units, not 125075.00
- [ ] Split 100.00 three ways: shares sum to **exactly** 100.00, never
      33.33 + 33.33 + 33.33
- [ ] Split an amount that does not divide evenly by 3 or 7 — no minor unit is
      created or lost
- [ ] Enter a foreign-currency expense, then change the FX rate: the original
      amount and the snapshotted rate do **not** silently change
- [ ] Balances reconcile: what each person paid minus their share equals what
      they owe, to the cent
- [ ] Suggested settlements move the fewest possible transfers
- [ ] A settlement marked "recorded" is visibly distinguishable from one the
      bank actually confirmed

## Security, as a non-member

Sign in as a user who is **not** on the trip.

- [ ] The trip is not visible in any list
- [ ] Deep-linking to the trip shows a refusal, not the data
- [ ] Opening the same trip directly in the browser returns nothing
- [ ] The service-role key does not appear in the web bundle:
      `grep -r "service_role" build/web/`

---

## Emergency Center

The most safety-critical screens in the app. Do these slowly.

- [ ] Works with **no account** and **no network** (airplane mode)
- [ ] Emergency number is visible without scrolling or tapping anything
- [ ] Every contact shows its source organisation and a "last checked" state
- [ ] Nothing is labelled "Verified" unless it genuinely was
- [ ] Every contact has a working "open the official source" action
- [ ] The lost-passport guide walks one step at a time, and the help phrases
      are selectable and copyable
- [ ] A Chinese phrase is reachable for the Hong Kong flow, so a traveller can
      hold up the screen instead of trying to speak Cantonese
- [ ] The Hong Kong page says plainly that **not every country has a resident
      consulate in the Hong Kong SAR**, and points to a foreign-ministry
      directory rather than guessing
- [ ] Nothing in the app promises boarding, or claims it can issue documents
- [ ] Read the disclaimers as a non-native English speaker. If any sentence
      could be misread in a crisis, rewrite it

---

## Offline

- [ ] Kill the network mid-session; the app does not crash
- [ ] Previously viewed trips, guides and contacts are still readable
- [ ] Writes made offline either queue or fail with an honest message —
      never report success for something that was not saved
- [ ] "Save for offline use" completes and actually persists

---

## Content honesty

Not a QA step so much as a review step, but it is the one most likely to be
skipped and the one that matters most.

- [ ] No emergency contact lacks a source
- [ ] No visa requirement is stated as fact by the app. It links to official
      pages and lets the user decide
- [ ] Demo data is visibly fictional and never resembles a real person
- [ ] No screenshot, seed row or comment implies a real user

---

## Accessibility

- [ ] Screen-reader labels on icon-only buttons
- [ ] Text scales to the largest system font size without clipping
- [ ] Contrast is readable in both light and dark
- [ ] Every action is reachable without a gesture-only path
- [ ] Tap targets meet the platform minimum

---

## Known gaps

Do not mark these off without doing the work.

- [ ] **Android has never been run on a device.** The SDK cmdline tools are not
      installed and licences are unaccepted.
- [ ] **iOS has never been built.** Requires macOS and a signing team.
- [ ] **No migration has ever been executed.** See `docs/supabase.md` step 3.
- [ ] **No Edge Function has been deployed or type checked.**
- [ ] **No emergency contact has been human-verified.** All rows say
      "Not yet verified", which is correct, not a defect.
- [ ] Push notifications and invitation email are scaffolded, never tested end
      to end.