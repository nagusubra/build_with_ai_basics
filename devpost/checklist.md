---
doc: checklist
status: approved
---

# Build Checklist

Build mode: fast

## Slices

- [x] **1. The app runs on an iPhone and can tell whether a selfie matches a photo**
  Becomes usable: The BakeOut Flutter app, already in BakeOut's colours, Nunito, and app icon, runs on an iPhone and opens a temporary "Verification lab" screen. You pick a profile photo, pass the live check (blink, then turn your head), and see a match score with pass or fail. Two photos can also be compared directly, without the camera.
  Why now: On-device face matching is the biggest unknown (`spec.md > Decisions and Open Issues > The useful unknown`), and the spec agreed to test it first. It needs no Firebase, so it can run while the Firebase project is being set up. Starting the app here also bootstraps the project.
  PRD ref: `prd.md > Photos and Verification`
  Spec ref: `spec.md > Photos and Verification`, `spec.md > Stack`, `spec.md > Look and Feel`, `spec.md > Mascot Assets`, `spec.md > File Structure`, `spec.md > External Services and Dependencies > Face embedding model (on device)`
  Build: Create the Flutter project in `app/` (iOS only) following the spec's file structure. Add the camera, photo picker, `tflite_flutter`, `image`, and `flutter_animate` packages, bundle Nunito, and add Apple Vision face detection through a Swift channel (revised from ML Kit; see Revisions). Add the theme (colours, type, shapes), copy the mascot PNGs, set the app icon, and add camera and photo permission text. Choose a MobileFaceNet-style `.tflite` model and record its source and license. Build `verification_service.dart`: the live check (one face, a blink, a head turn), face crop, embedding, cosine similarity, and a single threshold constant. Add the temporary lab screen, clearly labelled dev-only; it's removed in slice 5. Add unit tests for the similarity and threshold logic.
  Verify (mechanical): `flutter analyze` reports no errors; `flutter test` passes; the app builds and launches on an iOS simulator. A photo-to-photo comparison on the team's own local test photos (kept in a git-ignored folder) gives same-person scores clearly above different-person scores, and the chosen threshold separates them.
  Learner check: On your iPhone, open the lab, pick your own profile photo, follow the blink and head-turn prompts, and see "Match" with a score. Repeat using a photo of Subu as the profile photo and see "No match". Say whether the prompts felt clear and quick.
  Commit: `Scaffold BakeOut app and on-device verification trial`

- [x] **2. Two signed-in people can chat live in a shared match**
  Becomes usable: You can sign up or log in with email and a name. Two test accounts are linked into a match by a dev-only seed script, clearly labelled and removed in slice 6. Messages typed on one phone appear on the other within a second, in BakeOut-styled chat bubbles.
  Why now: Cherry needs a real two-person chat to live in. This is also the first contact with Firebase, so setup problems (project, Blaze, FlutterFire config, rules, emulators) surface now rather than later.
  PRD ref: `prd.md > Sign-Up and Login` (email account only), `prd.md > After Cherry Leaves` (two people chatting), `prd.md > States and Boundaries` (who sees what)
  Spec ref: `spec.md > Components > App Shell and Navigation`, `spec.md > Components > Sign-Up and Login`, `spec.md > Components > Chat`, `spec.md > Components > Security Rules`, `spec.md > Data Model`, `spec.md > External Services and Dependencies > Firebase (Blaze plan)`, `spec.md > Where It Runs and How Someone Tries It`
  Build: You create the Firebase project (Blaze plus a budget alert; Email/Password, Firestore, and Storage turned on). Then run `flutterfire configure` and `firebase init` (Firestore, Storage, Functions in TypeScript, Emulators). Build `auth_service.dart`, `chat_service.dart`, the chat screen, and the first `firestore.rules` for `users`, `matches`, and `messages`. Add `functions/scripts/seed-dev-match.ts`, which creates two labelled test users and a match between them.
  Verify (mechanical): `flutter analyze` and `flutter test` pass. Rules tests in the Firestore emulator confirm that a non-member can't read a match or its messages, and that a member can't send a message as someone else. The app running on two iOS simulators against the emulators shows a message from one appearing on the other (confirmed by simulator screenshots).
  Learner check: On two devices (your iPhone and Subu's, or your iPhone and a simulator), log in as the two test accounts and send messages both ways. Do they appear instantly, and does the chat look like BakeOut?
  Commit: `Add email login and live two-person chat`

- [x] **3. Cherry opens the chat and knows when to speak**
  Becomes usable: When a match starts, Cherry posts a welcome that names something the two really share, plus a fun icebreaker, with each person seeing their own cherry avatar. While the two are chatting, Cherry stays quiet. After a stall, Cherry steps in. If one person goes quiet, Cherry sends one gentle in-chat reminder and then pauses. Either person can ask Cherry to leave. Until the quiz exists, the two test accounts carry clearly labelled sample food profiles from the seed script, replaced in slice 5.
  Why now: This is the kernel (`scope.md > The Unique Kernel`). Build it early, so every later slice builds around a working Cherry rather than generic dating-app scaffolding.
  PRD ref: `prd.md > Opening the Chat`, `prd.md > When Cherry Speaks and When It Stays Quiet`, `prd.md > Cherry Leaves` (asking Cherry to leave), `prd.md > When the Plan Doesn't Come Together` (one person stops replying)
  Spec ref: `spec.md > Components > Cherry's Brain (server)`, `spec.md > Components > Cherry Opening`, `spec.md > Components > Cherry Decides`, `spec.md > Components > Cherry Timer`, `spec.md > Components > Dismiss Cherry`, `spec.md > External Services and Dependencies > Gemini API (paid tier)`, `spec.md > Important Failure Modes`
  Build: You add the paid Gemini key as a secret, plus a git-ignored local copy for the emulator. Confirm the current Gemini model name and Node.js runtime. Build `gemini.ts` (structured JSON output), `cherry/prompts.ts` (Cherry's personality and rules from the PRD), `opening.ts`, `decide.ts` (never twice in a row, the `cherryBusyUntil` lock, and the stop once `cherryState` is "left"), `tick.ts` (stall and reminder, thresholds in `config.ts` set short for the demo), and `dismissCherry`. Add Cherry's chat bubble and avatar using `cherryFor`.
  Verify (mechanical): Functions compile (`npm run build`), and unit tests for the guards pass. In the emulators, against real Gemini: a new match gets exactly one opening message that names a real shared detail. Several quick back-and-forth messages produce no Cherry message. Running the timer after a stall produces exactly one Cherry message. After dismissing Cherry, nothing more is posted.
  Learner check: Start a fresh test match on two devices and read Cherry's welcome. Does it sound like a friend, and does it mention something you share? Chat for a bit and notice Cherry staying quiet, then go silent and wait for its nudge. In a second test chat, ask Cherry to leave.
  Commit: `Add Cherry's opening, judgement, and stall timer`

- [x] **4. Cherry plans a cooking date both confirm, then leaves for good**
  Becomes usable: When both people seem keen, or either one asks, Cherry posts a date card with a dish that fits both diets and allergies, plus a day and time. Each person taps Confirm and sees ticks appear. If someone rejects the dish, Cherry offers 2–3 alternatives. If the time doesn't work, Cherry finds another. If someone isn't ready, Cherry backs off. Any change to the card clears the confirmations. When both have confirmed, Cherry posts the recipe (with an allergy note) and a song, says "Now it's on you two how you bake this out further! 🍒", and never posts again. The two keep chatting.
  Why now: This completes the kernel end to end, the demo's "oh, that's cool" moment, while there's plenty of time to tune Cherry from real feedback.
  PRD ref: `prd.md > Suggesting the Date`, `prd.md > Locking In the Date`, `prd.md > Cherry Leaves`, `prd.md > When the Plan Doesn't Come Together`, `prd.md > After Cherry Leaves`
  Spec ref: `spec.md > Components > Locking In the Date`, `spec.md > Components > Cherry Decides` (`propose_date` and `update_plan` cases), `spec.md > Components > Chat` (special message types), `spec.md > Data Model` (`datePlan`), `spec.md > Look and Feel` (planning and goodbye mascots)
  Build: Add `propose_date` and `update_plan` handling with decline tracking; `cherry/plan.ts` with `confirmDatePlan` and the leave flow; recipe and song generation in `recipes.ts`, using both people's restrictions; and the `dateCard`, `recipe`, `song`, and `cherryGoodbye` chat widgets with the planning and goodbye mascots.
  Verify (mechanical): Functions compile; unit tests for plan state pass (a change clears confirmations; "confirmed" only once both have confirmed; no Cherry action once it has left). In the emulators: a scripted conversation leads to a date card; a rejection produces alternatives; one confirmation leaves the plan "proposed"; two confirmations produce the recipe, song, and goodbye, with `cherryState` "left"; a later human message gets no Cherry reply.
  Learner check: On two devices, tell Cherry you'd like to plan something. Reject the first dish, pick an alternative, and have both of you tap Confirm. Read the recipe and song, watch Cherry say goodbye, then keep chatting with no more Cherry. Does the flow feel natural, never pushy?
  Commit: `Add date card, confirmations, recipe, song, and Cherry's goodbye`

- [x] **5. A new person can sign up, build their food profile, and get verified**
  Becomes usable: The real onboarding: Welcome with the duo mascot, then sign-up basics (18+ check, Friends or Partner), the ten-card food quiz (required and optional, progress bar, cherry pop-ins), photo upload to Storage, live verification (slice 1's service with the try-again screens), the profile preview, and the Meet Cherry intro. Answers are saved as you go. Cherry now uses real quiz answers; the seed script's sample food profiles and the verification lab are removed.
  Why now: With the kernel working, Cherry needs real profiles to talk about, and Discover (next) needs verified, onboarded people to show.
  PRD ref: `prd.md > Welcome Screen`, `prd.md > Sign-Up and Login`, `prd.md > Food Profile Quiz`, `prd.md > Photos and Verification`, `prd.md > Profile Preview`, `prd.md > Meet Cherry`
  Spec ref: `spec.md > Components > Welcome Screen`, `spec.md > Components > Sign-Up and Login`, `spec.md > Components > Food Quiz`, `spec.md > Components > Photos and Verification`, `spec.md > Components > Profile Preview and My Profile`, `spec.md > Components > Meet Cherry`, `spec.md > Data Model` (`users`, `private/account`), `spec.md > Components > Security Rules` (Storage), `spec.md > Look and Feel`
  Build: Welcome screen; basics form with the age check writing the public and private profile documents; quiz flow with one widget per question type, saving each answer; photo upload and `storage.rules`; the verification flow wired to `verification_service.dart`; the profile view; Meet Cherry; routing by onboarding state; `cherryAvatar` assignment. Remove the lab screen and the seed's sample food data.
  Verify (mechanical): `flutter analyze` and `flutter test` pass, including unit tests for the age check, required-question gating, and the profile headline. Storage and Firestore rules tests pass. On a simulator against the emulators, a scripted run through sign-up and the quiz writes the expected `users/{uid}` fields, and the private document holds the date of birth. Verification itself is checked on device.
  Learner check: On your iPhone, create a brand-new account from the Welcome screen, answer the quiz (skip a couple of optional questions), add photos, verify, and look at your profile preview. Did it feel fun and take about 3–5 minutes? Does the profile feel like you?
  Commit: `Add onboarding: welcome, sign-up, food quiz, photos, verification, profile preview`

- [ ] **6. People find each other in Discover and match**
  Becomes usable: Discover shows verified people looking for the same thing (friends or a partner) on swipeable cards, with Like and Pass buttons, a "something in common" line, and a tap-through to the full profile. A mutual like creates the match on the server, assigns each person's cherry, and plays "It's a BakeOut!" on both phones. "Let's Break the Ice!" opens the chat, where Cherry is waiting. The dev seed match is removed.
  Why now: This replaces the seeded match with the real way people meet. It comes after onboarding because it needs real verified profiles.
  PRD ref: `prd.md > Discover`, `prd.md > The Match Moment`
  Spec ref: `spec.md > Components > Discover`, `spec.md > Components > Matching (server)`, `spec.md > Components > Match Moment`, `spec.md > Data Model` (`likes`, `passes`, `matches`), `spec.md > External Services and Dependencies > Firebase (Blaze plan)` (composite index)
  Build: `discover_service.dart` (query, in-app filters, likes and passes, common ground); swipe cards with `flutter_card_swiper`; the full-profile view; `onLikeCreated` with sorted-ID matches and cherry assignment; the match-moment screen with the duo match mascot and a heart and confetti burst; the composite index; rules for likes and passes. Remove `seed-dev-match.ts`.
  Verify (mechanical): Unit tests for the common-ground and filter logic pass (a friend-seeker never sees a partner-seeker). Rules tests for likes pass. In the emulators: a one-sided like creates no match; a mutual like creates exactly one match with both cherry assignments; the opening Cherry message follows.
  Learner check: With two freshly onboarded accounts (you and Subu), find each other in Discover, check the "something in common" line, both swipe right, and watch "It's a BakeOut!" on both phones, then break the ice. Does matching feel exciting and quick?
  Commit: `Add Discover, mutual-like matching, and the match moment`

- [ ] **7. Discover never dead-ends: Recipes to cook while you wait**
  Becomes usable: When Discover has nobody new, the Recipes page appears with the cooking-cherries mascot and about six recipes written for your diet, restrictions, cuisines, and cooking time, each with an allergy note. You can open a recipe or ask for new ideas. Discover comes back when someone new shows up.
  Why now: With only two demo accounts, Discover runs out immediately after matching, so this is what the demo shows next.
  PRD ref: `prd.md > Recipes`
  Spec ref: `spec.md > Components > Recipes`, `spec.md > Data Model` (`users/{uid}/recipes`), `spec.md > Important Failure Modes` (allergy risk)
  Build: The `getMyRecipes` callable (cache in `users/{uid}/recipes`, regenerate on request); the Recipes list and detail screens; Discover switching to Recipes when it's empty and checking again when the tab opens.
  Verify (mechanical): Functions compile. In the emulators, `getMyRecipes` for a vegetarian profile with a nut allergy returns recipes with no meat and no nuts listed, each with an allergy note, and a second call returns the cached set. `flutter analyze` and `flutter test` pass.
  Learner check: After matching, swipe until Discover is empty. Browse the recipes, open one, and tap "New ideas". Do they fit your food profile?
  Commit: `Add Recipes page for when Discover runs out`

- [ ] **8. You can preview, edit, and delete your profile**
  Becomes usable: My profile shows your profile as others see it, lets you edit any answer (including optional questions you skipped), and lets you delete your account. Deleting removes your profile, photos, likes, matches, and chats, then returns you to Welcome.
  Why now: These are the last PRD behaviors, and deletion depends on every kind of data the earlier slices create.
  PRD ref: `prd.md > My Profile: Preview, Edit, Delete`, `prd.md > States and Boundaries` (account deleted)
  Spec ref: `spec.md > Components > Profile Preview and My Profile`, `spec.md > Components > Account Deletion (server)`, `spec.md > Components > App Shell and Navigation` (bottom bar)
  Build: The My profile tab; edit mode reusing the quiz widgets and basics form (recomputing `age`); the `deleteAccount` callable deleting every user-owned document, the Storage photos, likes, matches with their messages, and the Auth user; the delete confirmation and return to Welcome.
  Verify (mechanical): Unit tests for edit mapping pass. In the emulators: after `deleteAccount`, no document, Storage file, like, match, or message referencing that user remains, and the Auth user is gone.
  Learner check: Edit your signature dish and answer a skipped question, and see both on your profile. Then create a throwaway account, match it with your main one, delete the throwaway, and confirm it and its chat are gone.
  Commit: `Add My profile: preview, edit, and delete everything`

## Hands-on Checkpoints

- [x] Early usable behavior explored — after slice 4: the whole kernel (chat, Cherry's judgement, the date card, and Cherry leaving) tried on two real phones, with feedback that can still reshape Cherry before onboarding and Discover are built. Also run slice 1's verification lab on a real iPhone: the live check (blink, turn, look back) plus a selfie matching your own photo and not Subu's.
  Outcome: Vinamra tried the kernel on two simulators (Tester One and Tester Two against the real project) and reported "It seems good", with no changes requested. The real-iPhone verification check moves to slice 5's learner check, where verification runs inside real onboarding (see Revisions).
- [ ] Final kick-the-tires exploration and feedback completed

## Final Review

- [ ] Final review complete — feedback resolved and learner confirms ready to ship

## Code Tour and App Map

- [ ] Learning activity complete — guided route, focused alternative, prior practice connected, or brief recap
- [ ] Optional edit and transfer reflection addressed — offered/declined/already covered/not applicable as appropriate
- [ ] `devpost/app-map.html` generated from finished code, checked, and shown, including a project-grounded practice to reuse

Activity and evidence:
Route and stops:
Edit outcome:
Reflection:
Activity mode:

## Revisions

- **The live check uses Apple Vision (a small Swift channel in `AppDelegate.swift`) instead of Google ML Kit.** ML Kit ships no arm64-simulator build, and Xcode 26's iPhone simulators are arm64-only, so with ML Kit BakeOut could not run on any simulator. That would have blocked mechanical checks in every later slice. The learner chose the swap.
- **Face crops are aligned by the eyes before matching.** Plain box crops squeezed different people up to about 0.6 similarity. Vision's landmarks are unreliable on the simulator's CPU-only path, so the app uses landmark eyes only when they look plausible, and otherwise estimates the eyes from the face box. Measured on the simulator: same person 0.77–0.79, different people ≤0.18, cutoff 0.5.
- **The face model is Qualcomm AI Hub's MobileFaceNet export (Apache-2.0).** It takes two faces per call. The mechanical check uses public-domain official portraits (downloaded at test time, never committed) instead of the team's own photos; the team's selfies are checked by hand at the slice-4 checkpoint.
- **Nunito is bundled as static TTFs through `pubspec.yaml` instead of the `google_fonts` package,** which turned out to be unnecessary.
- **The tooling needs Java 21 and Node 22.** The current Firebase CLI's emulators need Java 21+ (Homebrew `openjdk@21` installed alongside Java 17), and `firebase-admin` 14 needs Node 22, so `functions/` pins Node 22 with `.nvmrc`. Cloud Functions will also run on Node 22. Recorded in `spec.md > Where It Runs and How Someone Tries It`.
- **The chat check pairs the app with a scripted second person.** One simulator can't type as two people, so `functions/scripts/dev-replier.mjs` plays Tester Two against the emulators while an integration test drives Tester One through the real login and chat screens. Firestore and Storage rules are deployed to the real project.
- **Cherry runs on `gemini-3.8-flash` with low thinking**, the current GA Flash model (checked October 2026). The emulator doesn't run scheduled functions, so the timer's logic (`runCherryTick`) is exercised directly with simulated clock times in `test/cherry.emulator.test.mjs`. Thresholds are 2 minutes for a stall and 10 for the reminder, and Cherry stays quiet for 3 human messages after speaking unless named. Real-Gemini check passed: the opening named shared details, Cherry stayed quiet in a flowing chat, sent one stall prompt then one reminder, and left on request.
- **Cherry is deployed to the real project**, with the Gemini key in Firebase Secret Manager and a 7-day cleanup policy for function images. Test accounts are seeded there with `npm run seed:real`, using the `gcloud` login; the testers' password lives in git-ignored `functions/.dev-testers.local`. A tester account recreated through sign-up got a new account ID and was dropped from the match, so the seed was rerun.
- **TensorFlow Lite's Swift wrapper is vendored** in `app/ios/LocalPods/TensorFlowLiteSwift`: the 11 unmodified v2.12.0 files plus the Apache-2.0 license. The upstream pod clones the whole TensorFlow repository, which filled the disk and stalled builds.
- **Each developer signs with their own Apple team** through git-ignored `app/ios/Flutter/Signing.xcconfig` (template: `Signing.xcconfig.example`).
- **The date card has a version number.** Each new or changed card bumps it, and Confirm sends the version the person saw, so a tap on an outdated card can't confirm a plan that has since changed. "Not ready" sets a 6-message cooldown before Cherry may propose again, unless someone asks. If finishing a confirmed date fails, the timer retries it. Real-Gemini check passed: Cherry backed off when someone wasn't ready, proposed nut-free vegetarian ravioli, offered three alternatives when it was rejected, updated the card to enchiladas, waited for both confirmations, posted a meat- and nut-free recipe with an allergy note and a lo-fi song, said "It's a date! 🎉 Now it's on you two how you bake this out further! 🍒", and stayed gone.
- **Onboarding routes by where each person stopped.** It goes basics → quiz → photos → verify → preview → Meet Cherry, with a `quizDone` flag so optional quiz cards aren't skipped over automatically. The dev seed's sample food profiles stay, now marked as fully onboarded, because the emulator Cherry checks still use them; the seed is removed with real matching in slice 6. The dev lab is gone. The verify screen has a "DEV ONLY: mark verified" button that appears only in debug builds on devices without a camera (simulators), so later screens can be checked there. A person can't skip verification. Checks passed: onboarding integration (an under-18 birthday refused; quiz answers saved; birthday only in the private document), 16 Firestore and Storage rules tests, and chat regression. Storage rules are deployed.
- **The dev seed match is gone; matching is real.** `seed-testers.mjs` makes only the two labelled tester profiles. In emulator checks they like each other (`--match`), so the real `onLikeCreated` creates the match and Cherry opens it; on the real project they find each other in Discover. Matching also checks both people are looking for the same thing. Likes can only be read by the liker, so nobody learns who liked them before a match. Checks passed: 4 matching emulator checks, 21 rules tests, 8 Discover logic tests, and 26 function unit tests. `onLikeCreated` and the rules are deployed.
- **The phone runs release builds.** Debug builds installed but Flutter's debugger never connected (iOS Local Network and trust prompts), so the phone uses `flutter run --release`, which runs on its own. Simulators keep debug builds.
- **The live check on a real iPhone camera (blink and turn thresholds) moves to the slice-4 hands-on checkpoint, and then to slice 5's learner check.** At the checkpoint the phone was disconnected and the disk was nearly full, so the on-device check happens in real onboarding instead of the dev lab. It's covered by unit tests, but a simulator has no camera.