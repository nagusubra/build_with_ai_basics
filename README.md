# Build With AI: Basics

Workspace for the Devpost Learn hackathon. Our app is **BakeOut**, a food-first dating app (Flutter in `app/`, Firebase and Cloud Functions in `functions/`). It runs on iPhone, Android, and the web. The plan lives in `devpost/`.

**Deadline:** Monday, October 26, 2026, 5:00 pm Eastern Time.

## Run BakeOut on your Mac and iPhone

You need Xcode (signed in to your Apple ID under Xcode > Settings > Accounts), Flutter, and the Firebase CLI (`npm install -g firebase-tools`). Your Google account must be a member of the Firebase project; ask a teammate to add you under Project settings > Users and permissions.

```sh
firebase login
sh app/scripts/setup.sh      # Firebase config + your own Apple signing (all git-ignored)
cd app && flutter run --release
```

The setup script downloads the app's Firebase config and finds your Apple team, giving your copy its own bundle ID so it signs under your account. Run it once per Mac; `--refresh` redoes it. The first time the app is installed, trust your developer certificate on the iPhone under Settings > General > VPN & Device Management.

The same script writes the Android and web Firebase settings, so `flutter run -d <android device>` and `flutter run -d chrome` work with no extra setup and no signing. See [app/README.md](app/README.md) for what each platform uses for the selfie check.

To try the web version in any browser: `cd app && flutter run -d web-server --release --web-port 5050`, then open http://localhost:5050. (Port 8080 is taken by the Firestore emulator during tests.) Profile photos load on the web because the Storage bucket allows browser reads; that setting lives in `storage.cors.json` and is applied once per project with `gcloud storage buckets update gs://studio-1391080484-497cf.firebasestorage.app --cors-file=storage.cors.json`.

## Judge access (web)

On the web, a "Judging BakeOut?" card beside the phone (or a "Judging? Quick access" button on narrow screens) lets judges skip sign-up:

- **Log in as Maya** (Jill is her wingwoman) or **Arjun** (Jack is his wingman): ready-made profiles, matched with each other with Cherry's opening message waiting, and each with a "liked you" from the sample crowd. Open one in a private window and the other in a normal window to chat as both.
- **Start fresh**: a throwaway account that goes through sign-up from the first question, with a placeholder-photo option and the skippable selfie check.

Discover has six sample profiles (`functions/scripts/judge-demo.mjs`) that like a judge back, so any like becomes a match. `cd functions && npm run seed:judges` creates everything on the real project and resets Maya and Arjun to a clean slate; run it again after judges have been through. Build with `--dart-define=JUDGE_ACCESS=false` to hide the shortcuts.

## Next session

Open this folder in Cursor or OpenCode and say:

```text
run 1-start
```

Read [hackathon/00-start-here.md](hackathon/00-start-here.md) first if you want the map. That file links the rules, eligibility, project requirements, submission checklist, judging rubric, prizes, schedule, method, video notes, organizer updates, and this workspace's setup.

## Mascot animations

Jack and Jill animate with code-generated Rive files built from image-model parts:

- [Animation workshop README](app/tool/README.md): isolation audit, safe authoring boundaries, tools and cross-editor setup. **New animations do not require Flutter changes; deployment is a separate task.**
- [Reusable starter prompt](docs/mascot-animation-starter-prompt.md): paste into Cursor, OpenCode, Copilot or another write-capable agent.
- [docs/mascot-animation-pipeline.md](docs/mascot-animation-pipeline.md): tech stack, tools, MCP setup and how it all works.
- [docs/new-mascot-animation-playbook.md](docs/new-mascot-animation-playbook.md): step-by-step checklist to make a new animation.
- [design/mascots/jack_rig/](design/mascots/jack_rig/README.md): Jack's character bible, prompts and parts.
- [app/tool/mascot_rive_jack/](app/tool/mascot_rive_jack/README.md): the Jack wingman rig. Preview it with `.\app\tool\preview_mascot_jack.ps1`.

## Links

- Hackathon: https://learn-ai-basics.devpost.com/
- Rules: https://learn-ai-basics.devpost.com/rules
- Resources: https://learn-ai-basics.devpost.com/resources
- Skill pack: https://github.com/challengepost/learn-ai-basics
- Live build recording: https://www.youtube.com/watch?v=sooC4QGFUUs
