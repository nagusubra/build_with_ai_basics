# Jack rig: character bible

Jack is BakeOut's boy chef cherry and the wingman shown on top of a chat with a guy's profile. Every pixel
of this rig came from Gemini image edits of **one master pose**, split into parts that line up exactly.
This means Jack can be rebuilt and re-animated at the same fidelity without redrawing anything by hand.

How the whole pipeline works, and how to do it yourself, is in
[`docs/mascot-animation-pipeline.md`](../../../docs/mascot-animation-pipeline.md).

## Look

| Trait | Spec |
|---|---|
| Body | Glossy deep-red cherry, heart-ish silhouette, slightly squashed sphere, soft studio highlight upper-left |
| Face | Big glossy brown eyes with two white catch-lights, thick dark-brown brows, rosy pink cheeks, tiny nose bump |
| Hat | Cream puffy chef's toque tilted to his right (viewer-left), sitting on the head *beside* the stem |
| Stem | Olive-green stem from the top dimple, one green leaf to the viewer-right, brown tip |
| Outfit | Cream apron with two small red cherries, red long sleeves, white cartoon gloves |
| Legs | Short red legs, red high-top sneakers with white soles and laces |
| Render | Soft 3D, Pixar-ish, smooth glossy plastic, no outline, no text |

Brand palette used around him: cherry `#E83D55`, deep cherry `#A71938`, cream `#FFF9F3`, pink
`#FFF0F2`, charcoal `#29252A`, leaf `#73984A`, idea gold `#FFC94D`.

## Files

```
master.png          canonical 1024x1024 front pose on #0CF50C; every part registers to it
raw/                untouched Gemini outputs (never edit these; regenerate instead)
parts/              keyed, registered full-res RGBA parts in master space (written by build_jack.py)
jack_rig.json       part list: bounding box, pivot and draw order in master space
```

| Raw render | Made from | Used for |
|---|---|---|
| `master_v1` | original Jack art + prompt | registration canvas |
| `body_v1` | master | body, apron, legs (head blanked, cut at y 470) |
| `head_v1` | master | neutral head; geometry for all faces (`HEAD_T`) |
| `hatstem_v1` | master | hat (x < 505) and stem + leaf (x >= 505) |
| `pose_think_v1`, `arms_think_v1` | master | finger-on-chin hand, notepad (pose = colour, arms = matte) |
| `pose_idea_v1` | master | raised "eureka" arm |
| `pose_write_v1`, `arms_write_v1` | master | pencil hand, slanted notepad |
| `face_think/idea/write/smile/blink_v1` | `head_v1` | expressions (silhouette IoU 0.998 vs `head_v1`) |
| `bulb_v1` | master as style reference | idea bulb prop |

Every pose render registered at offset 0 against the master (head NCC 0.99, feet 0.98). That's why all
edits are "keep everything else pixel-identical" edits of the same image, never fresh generations.

## Pivots (master px)

| Pivot | Point | Drives |
|---|---|---|
| ROOT | (512, 930) | squash/stretch, hops (between the shoes) |
| NECK | (520, 592) | head bob and tilt |
| HAT | (372, 318) | hat follow-through |
| STEM | (536, 300) | stem/leaf follow-through |
| L_SHOULDER | (398, 636) | thinking hand, pencil arm |
| R_SHOULDER | (650, 626) | notepad arm |
| IDEA_SHOULDER | (402, 628) | raised idea arm |
| BULB | (178, 188), h 178 | idea bulb |

## Prompts

All prompts end with the same background clause, so keying is trivial:
**"on a flat pure green background (#0CF50C), 1:1 square, no shadow."**

Pose and part edits are sent **with `master.png` attached in a fresh chat**. Expression edits are sent with
`raw/head_v1.png` attached. The bulb prompt below is verbatim; the others are the templates they were
written from. Swap the bracketed part.

- **Master**: "Recreate this exact cherry chef character as a clean character-sheet master: front facing,
  standing, arms relaxed slightly away from the body so the gloves don't overlap it, closed gentle smile,
  same hat, stem, leaf, apron, gloves and sneakers, same glossy 3D render style. Centered, full body…"
- **Isolate a part**: "Keep this exact image pixel-identical, but remove everything except [the hat and
  the stem with its leaf]. Do not move, resize or redraw what remains. Fill everything removed with flat
  pure green (#0CF50C)…"
- **Body without head**: "Keep this exact image identical, but remove the head, hat and stem entirely; keep
  the body, apron, arms stubs, legs and shoes exactly where they are…"
- **New pose**: "Keep this exact character, camera, scale, position, head, hat, legs and feet pixel-identical.
  Only change the arms: [his viewer-left hand holds a yellow pencil across his chest as if writing, his
  viewer-right hand holds a small cream spiral notepad tilted toward the pencil]…"
- **Arms-only matte** (same chat, right after the pose): "Now keep only the arms, hands, pencil and notepad
  exactly as drawn in the previous image; make everything else flat pure green (#0CF50C)…"
- **Expression** (on `head_v1`): "Keep this exact head, hat, stem, size and position identical. Only change
  the face to [eyes looking up and to the side, a small puckered 'hmm' mouth, one brow raised]…"
  The faces used were: think (eyes up, "hmm" pucker), idea (sparkly star eyes, open smile), write (eyes down
  to the pad, tongue poking out in concentration), smile (closed happy arcs, big open smile), blink (closed
  lashes, gentle smile).
- **Bulb (verbatim)**: "In the exact same glossy, soft 3D cartoon render style as this cherry chef character,
  create a SEPARATE prop image: a single cute glowing light bulb (the 'I have an idea!' bulb). Warm
  golden-yellow glowing glass with a soft white highlight, a tiny cute filament, a cream/silver screw base. No
  face, no character, no rays, no text. Centered, filling about 45% of the frame, upright, on a flat pure
  green background (#0CF50C), 1:1 square, no shadow."

## Rebuild

From the repo root:

```powershell
python app\tool\mascot_rive_jack\build_jack.py    # raw -> parts -> runtime assets -> scene.rml
python app\tool\mascot_rive_jack\verify_jack.py   # rive verify + build, captures, review sheet, preview
```
