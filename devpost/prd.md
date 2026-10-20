---
doc: prd
status: approved
---

# BakeOut — Product Requirements

A Flutter dating app for people who find dating apps overwhelming and small talk hard: profiles are built around how you cook and eat, and after a match, Cherry — an AI wingman — turns an awkward first chat into a confirmed virtual cooking date, then leaves the two of you to it.
Source: `scope.md > The Unique Kernel`, `scope.md > Who It's For`.

## The Core Journey
Implements `scope.md > The Core Loop` and `scope.md > What "Working" Looks Like`. Two real people, two phones.

1. **Welcome.** They open BakeOut and see the two 3D cherries holding hands, a short headline, and a big "Let's BakeOut" button.
2. **Sign up.** They create an account with email and enter their basics: name, date of birth (18+ only), gender, who they want to meet, location, and whether they're looking for friends or a partner.
3. **Food quiz.** They answer quick, colourful card questions about how they cook and eat. Only the essentials are required; the whole thing takes about 3–5 minutes.
4. **Photos and verification.** They add one required profile photo (plus up to three more), then take a live selfie. When it matches their photo, they get a verified badge. If it fails, they retry.
5. **Profile preview.** They see their profile the way others will: food is the personality.
6. **Meet Cherry.** A short animated intro explains who Cherry is and what it will do after a match.
7. **Discover.** They see real profiles on large swipeable cards and like or pass. When there's nobody new, they get the Recipes page until someone new is available.
8. **Match.** When both like each other, a full-screen "It's a BakeOut! 🍒❤️" moment appears with a "Let's Break the Ice!" button.
9. **Cherry opens the chat.** Cherry welcomes both, names something they have in common, and asks a fun icebreaker.
10. **Getting to know each other.** The two chat. Cherry stays quiet while they're talking and steps in only when the conversation stalls or there's a natural opening.
11. **The date.** When both are comfortable and interested, or either one asks, Cherry suggests a dish that fits both, confirms a day and time with both, shares the recipe, and suggests a song.
12. **Cherry leaves.** With everything confirmed, Cherry says "Now it's on you two how you bake this out further! 🍒" and permanently leaves. The two keep chatting on their own.

**Success:** a fresh match ends with a dish, day, and time both people confirmed, the recipe and song in the chat, and Cherry gone.

## Screens and Layout

| Screen | What's on it |
| --- | --- |
| Welcome | Cherry mascots, headline, subline, "Let's BakeOut" button, small "Already have an account? Log in" link. Nothing else. |
| Sign-up / Log in | Email account creation or login, then basic details. |
| Food quiz | One question per card, a progress indicator, Cherry popping in every few steps. |
| Photos and verification | Photo upload, then live selfie, then result. |
| Profile preview | The finished profile with a "Looks Delicious! Let's Meet Someone" button. |
| Meet Cherry | Short animated intro. |
| Discover | One large swipeable card at a time, with Like and Pass buttons. Tapping a card opens the full profile. |
| Recipes | Shown when Discover has nobody new: recipes to browse and cook. |
| Full profile | Someone else's full food profile. |
| My profile | Preview your own profile as others see it; edit it; delete your account. |
| Edit profile | Change profile details and answer optional questions skipped during onboarding. |
| Match moment | Full-screen celebration with both photos and "Let's Break the Ice!" |
| Chat | The two users and, until it leaves, Cherry. |

Movement is linear through onboarding, then Discover → Match → Chat.

## Look and Feel
- **Mood:** warm, playful, modern, and premium, never childish or overwhelming. "A cosy little space where meeting someone new is exciting rather than intimidating." The interface should look beautiful but never distract from the conversation.
- **Identity:** the two 3D cherry mascots are the main visual identity. A male cherry on his side, a female cherry on hers (`scope.md > Inspiration & Identity`). For same-gender matches and other genders, each person's cherry is randomly male or female.
- **Colours:**
  - Cherry Red `#E83D55`: primary brand colour, buttons, hearts, highlights
  - Warm Cream `#FFF9F3`: main background
  - Soft Pink `#FFF0F2`: cards, chat bubbles, subtle backgrounds
  - Deep Cherry `#A71938`: important headings and accents
  - Dark Charcoal `#29252A`: main text
  - Leaf Green `#73984A`: small accents inspired by the cherry stems
- **Typography:** rounded, friendly, modern, such as Nunito or Plus Jakarta Sans. Headings slightly bold and playful; body text clean and easy to read.
- **Style:** rounded cards, soft shadows, subtle animations, expressive emojis, plenty of breathing space.
- **References:** the simplicity and smooth interactions of Hinge, the playful personality of Duolingo, the polished feel of Airbnb.

## Features and Behavior

### Welcome Screen
Calm and uncluttered: the mascots (one holding a frying pan, one holding a phone), clean warm background, subtle animation.
- Headline: "Love might just be one recipe away."
- Subline: "Meet people who share your love for food, skip the awkward small talk, and cook up something special together."
- [ ] A first-time user sees only the mascots, headline, subline, "Let's BakeOut" button, and "Log in" link.
- [ ] "Let's BakeOut" starts sign-up; "Log in" goes to login.

### Sign-Up and Login
Email-based accounts. Basics collected: name, date of birth, gender, who they're interested in meeting, location, and what they're looking for: **Friends** or a **Partner** (girlfriend/boyfriend). There is no casual or random option: "this app is for genuine and serious people."
- [ ] A new user can create an account with email and reach the food quiz.
- [ ] Someone under 18 by date of birth can't continue.
- [ ] A returning user can log in and land back in the app with their profile, matches, and chats intact.

### Food Profile Quiz
Implements `scope.md > The POC Boundary` (food-centered profile). A fun quiz, not a form: one question per card, mostly multiple choice, colourful cards with emojis and illustrations. A progress indicator shows what's left; Cherry appears every few steps with a playful comment or small animation. Target: about 3–5 minutes.

| # | Question | Format | Required |
| --- | --- | --- | --- |
| 1 | What's your relationship with cooking? (cook daily / when I have time / a few basics / mostly takeaways / can't cook but would love to learn) | single choice | yes |
| 2 | What kind of food person are you? (vegetarian / vegan / non-vegetarian / pescatarian / eat everything / other, specify) plus separate dietary restrictions and allergies | single choice + multi-select | yes |
| 3 | What cuisines make you happy? Pick any, then your top three | multi-select cards with food illustrations | yes |
| 4 | What's your signature dish? | short free text | yes (signature dish or favourite food) |
| 5 | How adventurous are you with food? ("I order the same thing every time" to "I'll try anything at least once") | slider | optional |
| 6 | What's your ideal cooking date? (cook something simple / try a new recipe / friendly competition / bake something sweet / one cooks, one helps / I'd rather eat than cook) | single choice | yes |
| 7 | What's your cooking personality? Pick one or two (organised / experimental / chaotic / perfectionist / lazy chef / food critic) | multi-select, max 2 | yes (cooking ability or style) |
| 8 | What's your comfort food? | short free text | optional |
| 9 | How much time would you happily spend cooking? (15 min or less / about 30 min / about an hour / the whole evening) | single choice | yes |
| 10 | What music would you cook to? Genres plus one favourite song | multi-select + optional text | optional |

Also optional: one or two fun prompts, such as "Win me over with…", "The dish I could eat every day is…", "My most embarrassing cooking disaster…".

Why it matters: "can't cook but would love to learn" keeps BakeOut open to non-cooks. Someone who can't cook may enjoy meeting someone who loves teaching. Questions 2, 3, 9, and 10 feed Cherry's dish, time, and song choices.
- [ ] A user can finish the required questions and skip the optional ones.
- [ ] The progress indicator reflects how much is left.
- [ ] Cherry appears at least once mid-quiz with a playful comment.
- [ ] Answers appear correctly on the profile preview.

### Photos and Verification
Implements `scope.md > The POC Boundary` (picture verification). One mandatory profile photo, plus the option to add two or three more. Then a live selfie: the system checks there's a real face and compares it with the profile photo using an appropriate verification service. The screen explains why: so people feel comfortable knowing they're talking to a genuine person.
- [ ] A user can't continue without at least one profile photo.
- [ ] A live selfie that matches the profile photo results in a verified badge on the profile.
- [ ] If the selfie doesn't match or no face is found, the user sees why and can retry. They can't continue unverified, following `scope.md > The POC Boundary` ("no fake people or profiles").
- [ ] The verification selfie never appears on any profile or to any other user.
- [ ] Sensitive verification data is kept only as long as needed.

### Profile Preview
A real dating profile where food is the personality, not ten stacked answers.
- **Top:** main photo; name and age; city; verified badge; a short headline from their food personality, for example "Vinamra, 25 🍒 — The experimental chef who believes good conversations happen over good food."
- **My Food Personality card:** cooking style, food preference, favourite cuisines (top three), signature dish, comfort food, food adventure level (e.g. 8/10).
- **Our Kitchen Could Look Like card:** ideal date, cooking time, cooking soundtrack.
- **Optional prompts** if answered.
- Button: "Looks Delicious! Let's Meet Someone."
- [ ] The preview shows answers as profile cards, not a list of questions.
- [ ] Optional sections the user skipped don't appear as empty slots.

### Meet Cherry
A short animated intro before Discover, not a tutorial: "Hey, I'm Cherry! 🍒 I'm here to help you skip the awkward hellos. When you find someone you like, I'll help you two break the ice and plan something delicious. Once you're ready, I'll leave the rest to you."
- [ ] Shown once after the profile preview, then the user lands on Discover.

### Discover
One large swipeable card at a time. No complex filters and no recommendation algorithm: real profiles appearing correctly is enough. People looking for friends only see others looking for friends; people looking for a partner only see others looking for a partner.
- **Card shows:** profile photo, name, age, verified badge; food personality (e.g. "The Experimental Chef"); dietary preference; favourite cuisines and signature dish; cooking date preference; something in common, e.g. "You both love Italian food!"
- Swipe right or tap Like to like; swipe left or tap Pass to pass; tap the card to open the full food profile.
- [ ] Another real user's profile appears as a card with all the fields above.
- [ ] The "something in common" line reflects a real overlap between the two profiles.
- [ ] Like and Pass buttons do the same as swiping.
- [ ] Liking someone who hasn't liked you back yet creates no match.
- [ ] A friend-seeker never sees a partner-seeker in Discover, and the reverse.

### Recipes
When Discover has no one new to show, the user sees a Recipes page instead of a dead end: recipes they can browse and cook while they wait. When someone new becomes available, Discover shows them again.
- [ ] With no new profiles, the user sees the Recipes page rather than an empty Discover screen.
- [ ] The user can open a recipe and see what they need to cook it.
- [ ] When a new profile becomes available, Discover shows it.

### My Profile: Preview, Edit, Delete
The account basics in this version are exactly three.
- **Preview:** at any time, see your own profile the way others see it (same layout as **Profile Preview**).
- **Edit:** change profile details, including answering optional questions skipped during onboarding.
- **Delete:** delete your account.
- [ ] A user can open their own profile preview from inside the app at any time.
- [ ] A user can edit their food profile answers and see the change on their profile.
- [ ] A user can answer a previously skipped optional question, and it then appears on their profile.
- [ ] A user can delete their account; afterwards they're back at the Welcome screen, and their profile no longer appears in Discover for anyone.
- [ ] Deleting an account deletes everything belonging to it: profile, photos, verification data, matches, and chats. "Once deleted, everything is deleted, so we respect data privacy."

### The Match Moment
When both people have liked each other: full-screen "It's a BakeOut! 🍒❤️" animation. The two cherries come together holding hands, with both users' photos alongside. Message: "Looks like you've found your cooking partner!" Button: "Let's Break the Ice!"
- [ ] A mutual like shows the match moment for both users.
- [ ] "Let's Break the Ice!" opens the chat for that match.

### Cherry in the Chat
Implements `scope.md > The Unique Kernel`. Cherry behaves like a natural mutual friend, not a chatbot that responds to every message. It never forces the conversation or the date.

#### Opening the Chat
Cherry welcomes both, introduces something they have in common from their food profiles, and asks a fun icebreaker. Example: "Well, well! Looks like we've got two pasta lovers here. 🍝 So, who's actually better at cooking it?"
- [ ] When the chat first opens, Cherry's opening message refers to a real shared detail from both profiles.

#### When Cherry Speaks and When It Stays Quiet
- Speaks when the conversation gets stuck, someone struggles to reply, or there's a natural opening to bring up something interesting.
- Stays quiet while both people are actively talking.
- [ ] During a steady back-and-forth between the two users, Cherry sends no messages.
- [ ] After the conversation stalls, Cherry steps in with something relevant to their profiles or chat.

#### Suggesting the Date
Cherry suggests a date once both are participating comfortably and showing interest, or when either person asks to plan one.
- [ ] If either user asks to plan a date, Cherry starts planning.

#### Locking In the Date
Cherry helps them agree on a dish that fits both people's dietary preferences, restrictions, and cooking time, confirms a day and time with both, shares the recipe in the chat, and suggests a song based on their music answers.
- [ ] The suggested dish respects both people's dietary preferences and restrictions.
- [ ] The date counts as confirmed only after both users agree to the dish, day, and time.
- [ ] The recipe and a song suggestion appear in the chat.

#### Cherry Leaves
Once dish, day, and time are confirmed by both and the recipe and song are shared, Cherry says "Now it's on you two how you bake this out further! 🍒" and permanently leaves.
- [ ] Cherry's goodbye message appears, and Cherry never posts in that chat again.
- [ ] Either user can ask Cherry to leave at any time, and it does.

### When the Plan Doesn't Come Together
Cherry is flexible and understanding, never pushy.
- **One person isn't ready:** Cherry respects it, goes back to casual conversation, and only suggests a date again when both seem interested.
- **They disagree on the dish:** Cherry offers 2–3 alternatives that fit both people's food preferences and restrictions, and they choose together.
- **They can't agree on a time:** Cherry asks both for availability, finds overlapping slots, and suggests another day if needed.
- **One person stops replying:** Cherry stays quiet, sends one gentle reminder after a reasonable period as an in-chat message (not a push notification), then pauses until they return.
- **The date still doesn't happen:** Cherry stops pushing. It steps back and lets them chat, or leaves if either person wants it gone.
- **Hard rule:** Cherry never pretends a date is arranged. Until both confirm everything, the plan stays pending.
- [ ] When one user declines the date, Cherry doesn't suggest it again right away.
- [ ] When a user rejects the dish, Cherry offers 2–3 alternatives that fit both.
- [ ] When the times don't match, no date is confirmed.
- [ ] After one reminder, Cherry sends nothing more until the quiet user returns.

### After Cherry Leaves
The two users keep chatting in the same chat on their own.
- [ ] Both users can still message each other after Cherry has left.

## States and Boundaries
- **First use:** Welcome, then sign-up, quiz, photos and verification, preview, Meet Cherry, Discover.
- **Returning user:** logs in; profile, matches, and chats are as they left them.
- **Under 18:** can't create an account.
- **Optional questions skipped:** those profile sections simply don't appear.
- **Liked but not matched:** nothing happens until the other person likes back.
- **Date pending:** the plan stays pending until both confirm everything; Cherry stays in the chat.
- **Date confirmed:** Cherry leaves permanently; the chat continues between the two people.
- **Account deleted:** back to Welcome; everything belonging to the account is deleted, including profile, photos, verification data, matches, and chats.
- **Who sees what:** profiles are visible in Discover only to people looking for the same thing (friends or a partner); a chat is visible only to its two people (and Cherry while present); the verification selfie is never visible to anyone.
- **Verification fails:** the user sees why and retries; they can't continue unverified.
- **Discover runs out of profiles:** the Recipes page appears until someone new is available.

## Product Decisions
- **Food is the personality.** Profiles lead with cooking and eating habits instead of a written bio, because "food habits tell us a lot about their lifestyle, personality, and even how they might spend time with someone."
- **Non-cooks are welcome.** "We don't want BakeOut to be limited to people who are good at cooking."
- **Quiz, not form.** It has to feel fun and take 3–5 minutes, so only essentials are required.
- **Profile data serves Cherry first.** No personality algorithm; the answers mainly need to give Cherry enough to start a real conversation and suggest a date both will enjoy.
- **Real email accounts with login.** The team wants "a full functioning app" rather than a stripped-down demo; Firebase is their preferred tool (for `4-spec`). Chosen after the cost of an account system was discussed.
- **Real picture verification**, decided in `scope.md > The POC Boundary`.
- **Cherry is a mutual friend, not a chatbot.** It doesn't reply to every message and never forces the date.
- **A date is only real when both confirm.** Cherry never pretends.
- **Music is a suggestion, not playback.** Ask about music taste; no Spotify or music integration.
- **Friends or a partner, nothing casual.** "This app is for genuine and serious people." Friend-seekers only see friend-seekers, and partner-seekers only see partner-seekers. Cherry always plans a cooking date, with the same flow for both.
- **No dead end in Discover.** When nobody new is available, show recipes to cook instead.
- **Verification can be retried**, but it can't be skipped.
- **Cherry's look per person:** male or female cherry by gender; randomly chosen for same-gender matches and other genders.
- **Cherry's reminder is in-chat**, not a push notification.
- **Account basics are preview, edit, and delete.** Other common basics are deferred.
- **Delete means delete everything**, out of respect for people's data privacy.

## What We're Building
Everything in **The Core Journey**, with the behaviors and acceptance criteria under **Features and Behavior**: welcome, email sign-up and login with an 18+ check, the food quiz, photos and real verification, profile preview, Meet Cherry, Discover with like/pass and real profiles, the Recipes page when Discover runs out, my profile (preview, edit, delete), mutual-like matching with the match moment, and Cherry's full chat behavior through to its permanent exit.

## Deferred From the POC
- **Food filters and normal dating filters** in Discover. `scope.md > Later`; may return once the core path works.
- **Recommendation or matching algorithm.** Real profiles appearing is enough for now.
- **Push notifications.** Cherry's reminder is an in-chat message instead.
- **Other account basics:** log out, unmatch, block or report, and settings. Only preview, edit, and delete were chosen for this version. Block/report matters for a real launch's safety.
- **The virtual cooking date itself**, such as an in-app video call. `scope.md > Later`.
- **Playing music in the app or Spotify integration.** `scope.md > Later`.

## Possible Later Enhancements
- A personality-based compatibility score built from all the quiz answers.

## Non-Goals
- **Cherry replying to every message.** It would make Cherry a chatbot instead of a friend.
- **Pressuring anyone into a date.** Breaks the trust the product depends on.
- **Showing or keeping the verification selfie.** Privacy.
- **Long bios.** The quiz replaces them.

## Open Questions
- **What "stuck" means.** How long a silence before Cherry steps in. *Can be tuned during the build.*
- **How both people confirm.** Tapping a confirm button or replying in chat. *Can be decided in `4-spec`.*
