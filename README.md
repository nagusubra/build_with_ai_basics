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

## Next session

Open this folder in Cursor or OpenCode and say:

```text
run 1-start
```

Read [hackathon/00-start-here.md](hackathon/00-start-here.md) first if you want the map. That file links the rules, eligibility, project requirements, submission checklist, judging rubric, prizes, schedule, method, video notes, organizer updates, and this workspace's setup.

## Mascot animations

Jack and Jill animate with code-generated Rive files built from image-model parts:

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
