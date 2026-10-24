# BakeOut agent entry point

## Animation tasks

- Read [the animation workshop README](app/tool/README.md) before creating,
  extending, fixing or auditing mascot animations. Load the
  [mascot-animation skill](.agents/skills/mascot-animation/SKILL.md) when supported.
- Default to **animation-only**: write only the selected rig's design/workshop
  folders and directly relevant docs. Flutter integration is a separate,
  explicitly approved task; do not edit runtime code, shipped assets or pubspecs.
- Do not run [the legacy Dart builder](app/tool/build_mascot_rive.dart) during
  isolated authoring: it automatically overwrites the shipped shared asset.
- Inspect current Git status; preserve unrelated edits and prefer a separate
  worktree for concurrent app work. Never stage everything indiscriminately.
- Confirm write/build/image-view permissions. Read-only mode cannot complete a
  build; report blockers instead of claiming an unperformed verification.
- Keep the shared skill canonical in `.agents/skills/`; discover actual MCP tools
  and configure secrets locally rather than copying editor-specific assumptions.
- Use [the starter prompt](docs/mascot-animation-starter-prompt.md) for a fresh
  session and save progress, commands and evidence in the rig README.

These instructions concern animation work; they do not prohibit Flutter changes
when the user explicitly requests app development or approved integration.
