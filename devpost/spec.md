---
doc: spec
status: approved
---

# BakeOut — Technical Spec

## How This Works, In Plain Language

BakeOut has three parts.

1. **The app on your iPhone (Flutter).** Every screen people see: welcome, sign-up, the food quiz, photos and the selfie check, Discover, the match moment, the chat, Recipes, and My profile. It also runs the selfie verification itself, entirely on the phone.
2. **Firebase, Google's ready-made backend.**
   - **Authentication** handles email sign-up and login.
   - **Firestore** is the database: a live, shared spreadsheet in the cloud. When one phone writes a chat message, the other phone sees it within a second. Profiles, likes, matches, chats, and date plans all live here.
   - **Storage** holds profile photos.
3. **Cherry's brain (Cloud Functions + Gemini).** Small pieces of server code that run on Firebase whenever something happens, plus one that runs every minute on a timer. When a message is saved, a function reads the chat and both food profiles, asks Gemini "should Cherry say something, and what?", and writes Cherry's reply into the chat. Because this runs on the server, there is only ever one Cherry per chat, and the Gemini key never sits inside the app.

Walk one moment through it: Vinamra types "I'm terrible at pasta 😅" → the app saves it to Firestore → the other phone shows it instantly → a Cloud Function wakes up, sends the recent chat and both profiles to Gemini, and gets back "stay quiet" because they're chatting happily → nothing happens. Two minutes of silence later, the timer function notices the stall, asks Gemini again, and Cherry posts a question about their shared love of Italian food.

**Why this shape:** Firebase covers login, database, live updates, files, and server code in one place you've chosen, with no separate server to run. The only outside service is Gemini. Verification stays on the phone, so selfies never leave it.

## The Core Journey Through the System
PRD ref: `prd.md > The Core Journey`.

1. **Welcome** → the app shows the duo mascot image and buttons. Nothing is loaded from the network.
2. **Sign up** → Firebase Authentication creates the account → the app writes the public profile to Firestore `users/{uid}` and the date of birth to `users/{uid}/private/account`. Under 18 is blocked in the app before the account is created.
3. **Food quiz** → answers are saved to `users/{uid}.food` as each card is answered, so nothing is lost if the app closes.
4. **Photos** → uploaded to Storage under `users/{uid}/photos/`; their paths are saved on the profile.
5. **Verification** → on the phone only: Apple's Vision framework watches the camera for a blink and a head turn, then the face-recognition model compares the selfie with the main profile photo → on success the app sets `verified: true`. The selfie is never uploaded or saved.
6. **Profile preview and Meet Cherry** → the profile is read from Firestore and shown; `onboardingComplete: true` is set.
7. **Discover** → the app reads profiles with the same `lookingFor` value, verified and onboarded, and skips anyone already liked or passed. It works out "something in common" by comparing the two food profiles.
8. **Like** → the app writes `likes/{me}_{them}` → a Cloud Function checks whether `likes/{them}_{me}` exists → if so, it creates `matches/{id}` and assigns each person's cherry → both phones see the new match and play the "It's a BakeOut!" moment.
9. **Cherry opens the chat** → a Cloud Function triggered by the new match asks Gemini for a welcome that names something they share, plus an icebreaker, and writes it as a Cherry message.
10. **Getting to know each other** → each human message triggers Cherry's brain, which usually decides to stay quiet. The every-minute timer catches stalls and sends the one gentle reminder.
11. **The date** → when Gemini decides the moment is right, or someone asks, Cherry posts a **date card** with dish, day, and time. Each person taps **Confirm**, which calls a Cloud Function that records it → when both have confirmed, a function asks Gemini for the recipe (respecting both people's diets and allergies) and a song, then posts them.
12. **Cherry leaves** → the same function posts the goodbye and sets `cherryState: "left"`. From then on, every Cherry function ignores this chat. The two keep chatting through Firestore as before.

## Stack

| Piece | Choice | Version (checked Oct 2026) | Docs |
| --- | --- | --- | --- |
| App framework | Flutter (Dart), iOS only | Flutter 3.47.7 (installed) | https://docs.flutter.dev |
| Firebase setup | `firebase_core`, FlutterFire CLI | 5.0.0 | https://firebase.google.com/docs/flutter/setup |
| Login | `firebase_auth`, email and password | 7.0.0 | https://firebase.google.com/docs/auth/flutter/start |
| Database | `cloud_firestore` | 7.0.0 | https://firebase.google.com/docs/firestore |
| Photos | `firebase_storage` | 14.0.0 | https://firebase.google.com/docs/storage/flutter/start |
| Calling server functions | `cloud_functions` | 7.0.0 | https://firebase.google.com/docs/functions/callable |
| Camera and photo picking | `camera`, `image_picker` | 0.12.1, 1.2.4 | https://pub.dev/packages/camera |
| Live face check | Apple Vision (built into iOS), through a small Swift channel in `AppDelegate.swift` | iOS 15.5+ | https://developer.apple.com/documentation/vision |
| Face comparison | `tflite_flutter` running Qualcomm AI Hub's MobileFaceNet (Apache-2.0) | 0.12.1 | https://pub.dev/packages/tflite_flutter, https://huggingface.co/qualcomm/MobileFaceNet |
| Swipe cards | `flutter_card_swiper` | 7.2.0 | https://pub.dev/packages/flutter_card_swiper |
| Animations | `flutter_animate` | 4.5.2 | https://pub.dev/packages/flutter_animate |
| Fonts | Nunito static TTFs bundled as app fonts (SIL OFL) | — | https://fonts.google.com/specimen/Nunito |
| Cherry's brain | Cloud Functions for Firebase (2nd gen), TypeScript on Node.js | `firebase-functions` 7.4.0 | https://firebase.google.com/docs/functions |
| AI model | Gemini API via `@google/genai`, paid tier | 2.30.0 | https://ai.google.dev/gemini-api/docs |
| Command-line tools | Firebase CLI | 15.34.0 | https://firebase.google.com/docs/cli |

Why each learner choice:
- **Flutter:** the team's preferred framework; already installed.
- **Firebase Auth, Firestore, Storage:** the team's choice ("auth set-up is super easy"). Firestore's live updates are what make a two-person chat work.
- **Cloud Functions for Cherry:** agreed so there's exactly one Cherry per chat and the AI key stays off the phones. Accepted tradeoff: the Blaze pay-as-you-go plan, which needs a card.
- **Gemini, paid tier:** the team's choice ("for now let's use Gemini"). Paid so chats and profiles aren't used to improve Google's products, in line with "we respect data privacy for people." Accepted tradeoff: small usage cost, with a budget alert.
- **On-device verification (Apple Vision + face model):** the team's choice. Selfies never leave the phone. Accepted tradeoff: more setup, less accuracy than a cloud service, and the phone reports its own result. Originally ML Kit; swapped to Vision during slice 1 (see `checklist.md > Revisions`).
- **Gemini writes recipes:** the team's choice ("not the main thing for the app"). Accepted tradeoff: an AI-written recipe could get an allergy wrong.

**Unverified, check early in the build:**
- The exact current Gemini model name. Use the current fast "Flash" model; confirm the name on the Gemini models page.
- Which Node.js versions Cloud Functions currently accept. Node 20.15 is installed here.
- Whether `tflite_flutter` 0.12.1 builds cleanly for iOS with Xcode 26.4.

## Where It Runs and How Someone Tries It

**Runs on:** iPhones. Each teammate builds from their own Mac with Xcode over a cable, signed with a free Apple account. Free-account installs expire after 7 days: reinstall shortly before recording the demo. Cherry's functions run on Firebase's servers.

**One-time setup** (once per project, by one teammate unless noted):
1. Create a Firebase project. Upgrade it to **Blaze** and set a budget alert.
2. Turn on **Authentication → Email/Password**, **Firestore**, and **Storage**.
3. Get a **paid-tier Gemini API key** from Google AI Studio. Store it as a secret, never in code: `firebase functions:secrets:set GEMINI_API_KEY`.
4. Install the tools: `npm install -g firebase-tools`, `dart pub global activate flutterfire_cli`, then `firebase login`. The local emulators need **Java 21+** (`brew install openjdk@21`, then put `/opt/homebrew/opt/openjdk@21/bin` first on `PATH`), and `functions/` uses **Node 22** (`nvm use` reads `functions/.nvmrc`).
5. In `app/`, run `flutterfire configure`. This writes `lib/firebase_options.dart`. It holds the app's public Firebase identifiers, not secrets.
6. Deploy the server side from the repo root: `firebase deploy --only functions,firestore,storage`.

**Each teammate, to run it:**
```
cd app
flutter pub get
flutter run -d <your iPhone>
```
To list connected iPhones: `flutter devices`. The phone must be unlocked, trusted, and in Developer Mode.

**Local development against the emulators** (no real data touched):
```
cd functions && nvm use && npm install
npm run test:rules                         # security-rules tests
SIM=<simulator id> npm run check:chat      # two-person live chat, end to end
cd ../app && flutter run --dart-define=USE_EMULATORS=true   # with emulators running: firebase emulators:start
```

**For the demo recording:** create both demo accounts beforehand, so the video can jump quickly past onboarding to Discover, the match, and Cherry. Record both phones; Discover will run out quickly with only two users, which shows off the Recipes page. Submission needs the short video and the public GitHub repo. No deployment beyond the above.

## Look and Feel
From `prd.md > Look and Feel`. Lives in `app/lib/theme/`.

- **Colours as theme constants:**
  - `cherryRed #E83D55`: primary buttons, likes, hearts, highlights
  - `warmCream #FFF9F3`: scaffold background
  - `softPink #FFF0F2`: cards, Cherry's chat bubbles, the quiz option background
  - `deepCherry #A71938`: headings, accents
  - `charcoal #29252A`: body text
  - `leafGreen #73984A`: small accents, the verified badge, progress fill
- **Typography:** Nunito, bundled as static TTFs in `app/assets/fonts/` so it doesn't depend on the network. Headings weight 800–900, slightly larger and playful. Body weight 400–600.
- **Shapes and space:** corners 20–24 px on cards and 16 px on buttons, soft low-opacity shadows tinted toward deep cherry, generous padding. One idea per screen.
- **Motion with `flutter_animate`:** mascots gently bob or sway when idle; pop in with scale and fade during the quiz; the two cherries slide together for the match moment, with a heart and confetti burst drawn as separate animated pieces. Cherry's goodbye slides and fades out. Keep every animation short and subtle; never block a tap.
- **Tone of copy:** warm, playful food language with the emojis written in the PRD. Never pushy.
- **References:** Hinge's simplicity, Duolingo's personality, Airbnb's polish.
- **Constraint:** Flutter can honour all of the above. Mascots are still images that move as a whole (bob, slide, scale, fade); arms and faces don't animate.

### Mascot Assets
Generated from the team's reference images. Transparent PNGs are in `design/mascots/`, originals with floating hearts and extras in `design/mascots/source/`, and `design/cutout.swift` is the tool that made the cutouts. They're copied into `app/assets/mascots/` during the build.

| Asset | Where it's used |
| --- | --- |
| `cherry_duo_welcome` | Welcome screen |
| `cherry_boy_cheer` / `cherry_girl_cheer` | Quiz pop-ins, profile preview |
| `cherry_duo_verify` | Verification intro |
| `cherry_boy_tryagain` / `cherry_girl_tryagain` | Verification failed |
| `cherry_boy_hello` / `cherry_girl_hello` | Meet Cherry; Cherry's chat avatar |
| `cherry_duo_match` | "It's a BakeOut!" |
| `cherry_boy_planning` / `cherry_girl_planning` | The date card |
| `cherry_boy_goodbye` / `cherry_girl_goodbye` | Cherry's exit |
| `cherry_duo_cooking` | Recipes page |
| `app_icon` | iOS app icon |

**Which cherry a person sees:** stored as `cherryAvatar` on their profile and in the match. A man gets the boy cherry and a woman the girl cherry. Other genders get one at random at sign-up. In a same-gender match, each person's cherry is picked at random when the match is created (`prd.md > Look and Feel`).

## Components

### App Shell and Navigation
Starts Firebase, listens for login state, and routes: logged out → Welcome; logged in but onboarding unfinished → the next unfinished onboarding step; finished → Discover, with a bottom bar for Discover, Chats, and My profile.
PRD ref: `prd.md > Screens and Layout`, `prd.md > States and Boundaries`.

### Welcome Screen
Static screen with the duo mascot, headline, subline, "Let's BakeOut" and "Log in".
PRD ref: `prd.md > Welcome Screen`.

### Sign-Up and Login
Email and password through Firebase Auth. Basics form: name, date of birth, gender, interested in, city, and looking for (Friends or Partner). Blocks under 18 before creating the account. Writes `users/{uid}` and `users/{uid}/private/account`.
PRD ref: `prd.md > Sign-Up and Login`.

### Food Quiz
One card per question from the PRD table, with a progress bar and the person's cherry popping in every three cards. Required questions block "Next"; optional ones have "Skip". Each answer is saved to `users/{uid}.food` as it's given.
PRD ref: `prd.md > Food Profile Quiz`.

### Photos and Verification
- **Photos:** pick or take 1–4 photos with `image_picker`, upload to Storage, and save the paths.
- **Live check:** the `camera` stream feeds Apple Vision face detection (`FaceVision` in `face_vision.dart`, backed by `AppDelegate.swift`). Eye openness comes from each eye's height-to-width ratio in Vision's landmarks. The person is asked to look at the camera, blink, turn their head (yaw passes about ±20°), and look back. Exactly one face must be visible throughout.
- **Match:** take the final frame and the main profile photo, find the face in each with Vision, and align it by the eyes to the model's 112×112 training layout. Real landmark eyes are used when they look plausible; otherwise the eyes are estimated from the face box. Compute both embeddings with the TFLite model in one call, and compare them with cosine similarity against a threshold kept in one constant (`faceMatchThreshold`, 0.5). Pass → `verified: true` and `verifiedAt`. Fail → the try-again screen explains why ("we couldn't see one clear face" or "this didn't match your photo") and retries.
- **Privacy:** the selfie frames live only in memory and are discarded after the check. Nothing is uploaded.

PRD ref: `prd.md > Photos and Verification`.

### Profile Preview and My Profile
One profile view used three ways: your own preview during onboarding, a full profile from Discover, and **My profile** (preview, Edit, Delete). Builds the headline from food personality, then the "My Food Personality" and "Our Kitchen Could Look Like" cards, and the optional prompts. Skipped fields are hidden.
- **Edit** reuses the quiz cards and basics form on existing values.
- **Delete** asks for confirmation, then calls `deleteAccount`.

PRD ref: `prd.md > Profile Preview`, `prd.md > My Profile: Preview, Edit, Delete`.

### Meet Cherry
One-time animated intro with the person's own cherry.
PRD ref: `prd.md > Meet Cherry`.

### Discover
- **Query:** `users` where `lookingFor` equals mine, `onboardingComplete == true`, and `verified == true`.
- **Filter in the app:** remove self, people I've liked or passed (`users/{me}/passes`, my `likes`), and people whose gender doesn't fit my "interested in", or whose "interested in" doesn't fit me.
- **Cards:** shown with `flutter_card_swiper`, with Like and Pass buttons that do the same as swiping.
- **"Something in common":** the first overlap found, checking top cuisines, then food type, ideal date, and cooking personality.
- **Nobody left:** the screen shows the **Recipes** component instead.

PRD ref: `prd.md > Discover`.

### Recipes
*Changed at final review:* recipes now come from the bundled library (see Final-Review Additions), with no network call. The page features the Dish of the Day, then about six more recipes suited to this person's diet, restrictions, cuisines, and cooking time. Each recipe has a title, time, ingredients, steps, and an allergy note. Tapping one opens its detail. "New ideas" shows the next set. Discover is checked again whenever the tab is opened.
PRD ref: `prd.md > Recipes`.

### Matching (server)
`onLikeCreated`, a Firestore trigger on `likes/{likeId}`, checks for the reverse like. If it exists and no match exists yet, it creates `matches/{a_b}` (the two IDs sorted, so it can only be created once), with `users`, both cherry assignments, and `cherryState: "active"`.
PRD ref: `prd.md > Discover`, `prd.md > The Match Moment`.

### Match Moment
Each phone listens for new matches it hasn't celebrated (`seenBy` doesn't include me) and shows the full-screen celebration once, then "Let's Break the Ice!" opens the chat.
PRD ref: `prd.md > The Match Moment`.

### Chat
Live list of `matches/{id}/messages`, ordered by time. Human messages are on the right or left. Cherry's messages use soft-pink bubbles with the viewer's own cherry avatar. Special message types:
- **`dateCard`:** dish, day, and time, with a Confirm button per person and a tick when confirmed. Confirm calls `confirmDatePlan`.
- **`recipe`:** title, ingredients, steps, and the allergy note.
- **`song`:** song and artist.
- **`cherryGoodbye`:** shown with the goodbye mascot.

A small "Ask Cherry to leave" action in the chat header calls `dismissCherry`.
PRD ref: `prd.md > Cherry in the Chat`, `prd.md > After Cherry Leaves`.

### Cherry's Brain (server)
All in `functions/src/cherry/`. Every function first checks `cherryState`; if it's `"left"`, it does nothing.

#### Cherry Opening
`onMatchCreated` sends both food profiles to Gemini and asks for a short welcome that names one real shared detail, plus a fun icebreaker. It writes the result as a Cherry message.
PRD ref: `prd.md > Opening the Chat`.

#### Cherry Decides
`onMessageCreated`, triggered by each human message, does the following:
1. Updates `lastHumanMessageAt` and `lastMessageBy`.
2. If the message asks Cherry to leave, runs the leave flow.
3. Otherwise sends Gemini the last ~20 messages, both food profiles, the date-plan state, and Cherry's rules, and asks for a JSON answer: `{ action: "stay_quiet" | "speak" | "propose_date" | "update_plan", message?, plan? }`.

Guards in code, not just in the prompt:
- Cherry never posts twice in a row.
- After a declined date, Cherry won't propose again until at least N more human messages from both people.
- A lock field (`cherryBusyUntil`, set in a transaction) stops two triggers making Cherry speak at once.

`propose_date` and `update_plan` write or replace the date card, which needs a dish, a day, and a time. Gemini is told both diets and restrictions, and both people's cooking time.

How the PRD's "what if" cases map to Cherry's actions:
- **Dish rejected** → `speak` with 2–3 alternatives that fit both people, then `update_plan` with the one they pick.
- **Time doesn't work** → `speak` asking both for availability, then `update_plan` with an overlapping day and time.
- **Someone isn't ready** → record `dateDeclinedAt` and go back to casual conversation.

Any change to the card clears both confirmations.
PRD ref: `prd.md > When Cherry Speaks and When It Stays Quiet`, `prd.md > Suggesting the Date`, `prd.md > When the Plan Doesn't Come Together`.

#### Cherry Timer
`cherryTick` runs every minute (scheduled function). For each active match:
- **Stalled:** if the last message is a human's and older than `STUCK_MINUTES`, and Cherry hasn't spoken since, it asks Gemini for a gentle prompt.
- **One person gone quiet:** if one person hasn't replied for `REMINDER_MINUTES` and no reminder has been sent since their last message, it posts the single in-chat reminder and records `reminderSentAt`.

Both thresholds live in one config file and can be tuned during the build, with short values for the demo.
PRD ref: `prd.md > When Cherry Speaks and When It Stays Quiet`, `prd.md > When the Plan Doesn't Come Together`.

#### Locking In the Date
`confirmDatePlan` is a callable function that marks the caller as confirmed on the current card. When both have confirmed:
1. Sets the plan to `confirmed`.
2. Asks Gemini for a recipe (structured: title, time, ingredients, steps; told both diets and allergies) and a song suggestion based on both music answers.
3. Posts the recipe and song messages.
4. Posts the goodbye "Now it's on you two how you bake this out further! 🍒".
5. Sets `cherryState: "left"`.

Until step 1, the card simply shows who has confirmed.
PRD ref: `prd.md > Locking In the Date`, `prd.md > Cherry Leaves`.

#### Dismiss Cherry
`dismissCherry` is a callable function. Either member can call it; Cherry posts a short goodbye and sets `cherryState: "left"`.
PRD ref: `prd.md > Cherry Leaves`.

### Account Deletion (server)
`deleteAccount` is a callable function. Using admin access, it deletes:
- the user's profile document and its subcollections (private, passes, recipes);
- their photos in Storage;
- every like to or from them;
- every match they're in, with all its messages;
- finally, their Auth account.

The app then returns to Welcome.
PRD ref: `prd.md > My Profile: Preview, Edit, Delete`.

### Security Rules
- **`users/{uid}`:** readable by any signed-in user; writable only by its owner, including the `verified` flag. That's the accepted on-device simplification (see **What Was Simplified and Why**).
- **`users/{uid}/private/**`, `passes`, `recipes`:** owner only.
- **`likes/{id}`:** create only with `from == my uid`; no reads of other people's likes.
- **`matches/{id}`:** readable only by its two `users`; clients may only update their own `seenBy` entry.
- **Messages:** readable by members; creatable by members only with `sender == my uid` and `type == "text"`. Cherry and special messages are written by functions, which bypass the rules.
- **Storage `users/{uid}/photos/*`:** readable by signed-in users; writable only by the owner; images only, under 10 MB.

PRD ref: `prd.md > States and Boundaries` (who sees what).

## Data Model

All Firestore unless noted.

**`users/{uid}`**: the public profile.
- `name`, `age` (computed from date of birth at sign-up and on edit), `gender`, `interestedIn` (list), `city`, `lookingFor` (`"friends"` or `"partner"`)
- `photos` (list of Storage paths; first is main), `verified` (bool), `verifiedAt`
- `cherryAvatar` (`"boy"` or `"girl"`), `onboardingComplete` (bool), `createdAt`
- `food`:
  - `cookingRelationship`, `foodType`, `foodTypeOther`, `restrictions` (list), `cuisines` (list), `topCuisines` (list of 3)
  - `signatureDish`, `adventure` (0–10, optional), `idealDate`, `cookingPersonality` (1–2)
  - `comfortFood` (optional), `cookingTime`, `musicGenres` (optional), `favouriteSong` (optional)
- `prompts` (optional map)

Updated by the owner as they go through onboarding and edits. Kept until the account is deleted.

**`users/{uid}/private/account`**: `dateOfBirth`, `email`. Owner only.

**`users/{uid}/passes/{otherUid}`**: `createdAt`. Hides that person from Discover.

**`users/{uid}/recipes/{id}`**: cached Recipes-page recipes. `title`, `minutes`, `ingredients`, `steps`, `allergyNote`, `createdAt`.

**`likes/{fromUid}_{toUid}`**: `from`, `to`, `createdAt`.

**`matches/{uidA}_{uidB}`** (IDs sorted):
- `users` [a, b], `createdAt`, `cherryFor` { uid: `"boy"` | `"girl"` }, `seenBy` (list)
- `cherryState` (`"active"` or `"left"`), `cherryBusyUntil`
- `lastHumanMessageAt`, `lastMessageBy`, `lastCherryMessageAt`, `reminderSentAt`, `dateDeclinedAt`, `humanMessagesSinceDecline`
- `datePlan`: { `status`: `"none"` | `"proposed"` | `"confirmed"`, `dish`, `dishWhy`, `day`, `time`, `confirmedBy` { uid: bool } }

**`matches/{id}/messages/{id}`**:
- `sender` (uid or `"cherry"`), `type` (`"text"` | `"dateCard"` | `"recipe"` | `"song"` | `"cherryGoodbye"`), `text`, `payload` (for the special types), `createdAt`

**Storage:** `users/{uid}/photos/{n}.jpg`.

**Never stored:** verification selfies.

**Leaving and coming back:** everything above lives in Firestore and Storage, so after logging in on any phone the profile, matches, chats, and the date-plan state are exactly as they were.

## File Structure

```
build_with_ai_basics/
├── app/                          # Flutter app (iOS)
│   ├── lib/
│   │   ├── main.dart             # Firebase init, app shell, routing by login/onboarding state
│   │   ├── firebase_options.dart # generated by flutterfire configure
│   │   ├── theme/                # colours, Nunito text styles, shared shapes and shadows
│   │   ├── models/               # UserProfile, FoodProfile, Match, Message, DatePlan, Recipe
│   │   ├── services/
│   │   │   ├── auth_service.dart          # sign up, log in, age check
│   │   │   ├── profile_service.dart       # read/write profile, photos upload
│   │   │   ├── discover_service.dart      # candidate query, filters, likes/passes, common ground
│   │   │   ├── chat_service.dart          # match + message streams, send message
│   │   │   ├── verification_service.dart  # eye-aligned face crops + MobileFaceNet compare
│   │   │   ├── face_vision.dart           # Apple Vision channel: faces, yaw, eye openness, eye centres
│   │   │   ├── face_math.dart             # similarity, threshold, eye alignment
│   │   │   ├── liveness_tracker.dart      # face → blink → turn → look back
│   │   │   └── functions_service.dart     # confirmDatePlan, dismissCherry, getMyRecipes, deleteAccount
│   │   ├── screens/
│   │   │   ├── welcome/
│   │   │   ├── auth/              # sign up, log in, basics form
│   │   │   ├── quiz/              # quiz flow + one widget per question type
│   │   │   ├── photos/            # photo picker + verification + try again
│   │   │   ├── profile/           # profile view (preview / full / mine), edit, delete
│   │   │   ├── meet_cherry/
│   │   │   ├── discover/
│   │   │   ├── recipes/           # list + detail
│   │   │   ├── match/             # "It's a BakeOut!" moment
│   │   │   └── chat/              # chat list + chat screen
│   │   └── widgets/               # Mascot (animated), QuizCard, SwipeCard, DateCard, ChatBubble, ProgressBar, HeartBurst
│   ├── assets/
│   │   ├── mascots/               # copied from design/mascots/*.png
│   │   ├── fonts/                 # bundled Nunito
│   │   └── models/                # face embedding .tflite
│   ├── ios/                       # Xcode project, app icon, camera permission text
│   └── pubspec.yaml
├── functions/                     # Cherry's brain + server logic (TypeScript)
│   ├── src/
│   │   ├── index.ts               # exports every function
│   │   ├── config.ts              # STUCK_MINUTES, REMINDER_MINUTES, model name
│   │   ├── gemini.ts              # Gemini client, JSON-output helper, secret binding
│   │   ├── matching.ts            # onLikeCreated, cherry assignment
│   │   ├── account.ts             # deleteAccount
│   │   ├── recipes.ts             # getMyRecipes, recipe generation shared with Cherry
│   │   └── cherry/
│   │       ├── prompts.ts         # Cherry's personality and rules
│   │       ├── opening.ts         # onMatchCreated
│   │       ├── decide.ts          # onMessageCreated + guards + lock
│   │       ├── tick.ts            # cherryTick (stalls, reminder)
│   │       └── plan.ts            # confirmDatePlan, dismissCherry, leave flow
│   ├── package.json
│   └── tsconfig.json
├── firestore.rules
├── firestore.indexes.json
├── storage.rules
├── firebase.json
├── .firebaserc
├── design/
│   ├── mascots/                   # transparent mascot PNGs + preview.html
│   │   └── source/                # original generated images and the team's references
│   └── cutout.swift               # background removal tool used for the PNGs
├── devpost/                       # planning documents
└── README.md                      # setup and run instructions
```

## External Services and Dependencies

### Firebase (Blaze plan)
- **Authentication:** email/password; `createUserWithEmailAndPassword`, `signInWithEmailAndPassword`, and admin `deleteUser` in `deleteAccount`.
- **Firestore:** reads and writes as in **Data Model**; live listeners for chats and matches. Needs a composite index on `users` (`lookingFor`, `onboardingComplete`, `verified`).
- **Storage:** profile photos.
- **Cloud Functions (2nd gen):** Firestore triggers (`onLikeCreated`, `onMatchCreated`, `onMessageCreated`), callable functions (`confirmDatePlan`, `dismissCherry`, `getMyRecipes`, `deleteAccount`), and one scheduled function (`cherryTick`, every minute, using Cloud Scheduler).
- **Keys:** the app uses the public Firebase config from `flutterfire configure`.
- **Cost:** Blaze includes a monthly free allowance that hackathon use is expected to stay inside; the every-minute timer adds about 43,000 runs a month, also within it. Set a budget alert. *Verify current free-tier limits early.*
- **Docs:** https://firebase.google.com/docs/functions/firestore-events, https://firebase.google.com/docs/functions/schedule-functions, https://firebase.google.com/docs/functions/config-env (secrets), https://firebase.google.com/pricing

### Gemini API (paid tier)
- **Called only from Cloud Functions** through `@google/genai`: `ai.models.generateContent({ model, contents, config: { responseMimeType: "application/json", responseSchema } })`.
- **Calls:** Cherry's opening, Cherry decides, the stall prompt, the reminder, the date recipe and song, and Recipes-page recipes.
- **Key:** `GEMINI_API_KEY` in Firebase secrets.
- **Cost:** small per call; Cherry decides runs once per human message.
- **Data use:** paid-tier content isn't used to improve Google's products, per the Gemini API terms. *Re-read the current terms when creating the key.*
- **Docs:** https://ai.google.dev/gemini-api/docs, https://ai.google.dev/gemini-api/docs/structured-output, https://ai.google.dev/gemini-api/terms

### Apple Vision Face Detection (on device)
- Free, no key, no network.
- Used with classification (eye-open probabilities) and head angles.
- **Docs:** https://developers.google.com/ml-kit/vision/face-detection

### Face embedding model (on device)
- `app/assets/models/mobile_facenet.tflite`, Qualcomm AI Hub's MobileFaceNet export (release v0.64.0, Apache-2.0). Takes two 112×112 faces at once and returns a 128-number embedding for each. Source and shapes are in `app/assets/models/README.md`.
- Free, no key.
- *Source file and license to be chosen and checked in the first build step.*

### Apple
- Free Apple account in Xcode for cable installs; 7-day expiry.
- `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` text in `ios/Runner/Info.plist`.

## Important Failure Modes

- **Gemini is slow, errors, or returns invalid JSON** → Cherry stays quiet; the function logs the problem and the next message or timer tick tries again. Cherry never posts a half-made plan. If recipe generation fails after both confirm, the plan still shows "confirmed", and Cherry retries the recipe and song on the next tick before leaving.
- **Face match fails for a genuine person** (lighting, angle, old photo) → the try-again screen gives tips (face the light, remove sunglasses, use a clearer main photo) and retries. The threshold is a single constant to tune during the first build step.
- **Both phones trigger Cherry at once** → the `cherryBusyUntil` lock in a transaction lets only one function speak; the other exits.
- **Discover has no one left** → the Recipes page appears.
- **A Gemini-written recipe ignores an allergy** → mitigated by sending both people's restrictions with every recipe request and showing an allergy note on every recipe. Not eliminated.

## What Was Simplified and Why

- **The phone reports its own verification result** instead of a server-side check, so selfies never leave the device. A tampered app could fake `verified`. The fuller version would add a server-side or attested check.
- **Discover filters in the app** instead of with a matching algorithm, because a few users don't need one (`prd.md > Deferred From the POC`). The fuller version would query and rank on the server.
- **A one-minute timer for stalls and reminders** instead of per-chat scheduled tasks. It's simpler, and a minute of delay is fine. The fuller version would schedule a check per chat with Cloud Tasks.
- **`age` is stored on the public profile** while the exact date of birth stays private, so other users never see the birthday. It's recomputed on edit, not on birthdays.
- **No push notifications**, with Cherry's reminder sent in-chat (`prd.md > Product Decisions`).
- **iPhone only**, since that's what the team has to build on and demo with.

## Final-Review Additions
Implements `prd.md > Added at Final Review`.
- **Recipe library:** `app/assets/recipes/library.json`, generated once with Gemini by `functions/scripts/build-recipe-library.mjs`. The tags are then double-checked by keyword rules (a meat word means not vegetarian; nut words add the nuts allergen, and so on) and committed. `RecipeLibrary` in the app filters by diet and restrictions and ranks by cuisines and cooking time. "Dish of the Day" is a stable daily pick from the suitable set. The `getMyRecipes` function and `users/{uid}/recipes` are retired.
- **Cities:** a fixed list in `app/lib/data/cities.dart` with a searchable picker; `users/{uid}.city` holds one list entry.
- **Filters:** `users/{uid}.filters = { foodTypes: [], minAge, maxAge, cities: [] }`, where empty means no limit. They're applied in `DiscoverService.candidates` by a pure `passesFilters`. The mode switch updates `users/{uid}.lookingFor`.
- **Jack & Jill:** `Wingman` in `app/lib/widgets/mascot.dart` gives the name and poses for a person's cherry. Cherry's system prompt tells the wingman never to name itself, and `mentionsCherry` also matches "jack" and "jill", except a name that belongs to one of the two people in the chat (so "bye Jack" to a person called Jack doesn't dismiss the wingman).
- **Daily touches:** `app/lib/data/daily.dart` gives a time-of-day greeting with one line per day; Discover shows it with the Dish of the Day, and the Recipes page features the Dish of the Day.
- **Chats list:** each match stores `readAt.{uid}` (members may update only their own entry, and only to the server time). Each tile streams its own last message, so no server change is needed; tiles show the preview, wingman or date status, and an unread dot.

## Decisions and Open Issues

### Decisions

**Learner decisions:**
- Flutter app on iPhones; each teammate builds from their own Mac.
- Firebase Auth, Firestore, and Storage.
- Cherry runs in Cloud Functions on Blaze.
- Gemini, paid tier.
- On-device live check plus on-device face comparison; the live check uses Apple Vision instead of ML Kit (agreed in slice 1, so the app still runs on simulators).
- Gemini writes the recipes.
- Date card with Confirm buttons.
- Mascots as generated 3D-style images based on the team's reference art, animated as whole images in Flutter.

**Implementation details that follow from those** (agent-derived, not separately chosen by the team):
- TypeScript for functions.
- Sorted-ID match documents.
- The `cherryBusyUntil` lock.
- A one-minute scheduled timer.
- Public and private profile split.
- `flutter_card_swiper` and `flutter_animate`; Nunito bundled directly instead of through `google_fonts`.
- Eye alignment for face crops, with a box-based eye estimate as fallback.

### The useful unknown
**On-device face verification.** In `2-scope` the team expected it "should not be very hard as there are a lot of libraries." In this session we separated it into two jobs: the live check, which a face detector covers well, and matching the selfie to the profile photo, which needs a face-recognition model that no single Flutter library packages up. **Agreed investigation:** the first build step is a small trial on the team's own photos, before the screens are built around it.

Evidence needed from the trial:
1. The face detector picks up a blink and a head turn on an iPhone.
2. The chosen `.tflite` model loads and runs on iOS.
3. Same-person pairs score clearly above different-person pairs, so a threshold can be picked.

If (3) fails, that's a plan revision the team decides on.

### Still open
- **"Stuck" and reminder timings:** the exact `STUCK_MINUTES` and `REMINDER_MINUTES` values. Tune during the build (carried from `prd.md > Open Questions`).
- **Gemini model name and Node.js runtime version:** confirm at the start of the build.
- **Live check on a real iPhone:** blink and turn thresholds are verified in unit tests but not yet on a device camera. Check at the slice-4 hands-on checkpoint.
- **Where `design/` assets live long-term:** copied into `app/assets/mascots/` in the build; `design/` stays as the source.
