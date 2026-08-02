---
name: silent-ab-20s-video
description: Create silent 20-second vertical product-video plans from a product YAML profile and reference images. Use for Omni Fast image-to-video prompts that require a 10-second creator segment A, a 10-second product segment B, FFmpeg assembly, and visual-only deduplication without narration, captions, or lip-sync.
---

# Silent A/B 20-second product video

Create a silent vertical product ad with this fixed edit order:

`A[0-5s] + B[0-10s] + A[5-10s] = 20s`

Generate exactly two independent 10-second image-to-video jobs. Do not generate or request dialogue, narration, captions, lip-sync, text overlays, UI, or a spoken CTA.

## Read the product evidence

Read the supplied product YAML and inspect the supplied reference images before writing prompts.

- Treat `instructions_for_use`, `must_keep`, `must_avoid`, and visible product details as authoritative.
- Use only confirmed physical actions. If a mechanism, direction, or state change is not confirmed, replace it with a neutral product display.
- Choose one public reference image URL per job. Prefer a natural lifestyle image for A and the clearest functional image for B. Never concatenate multiple URLs.
- Preserve product colour, shape, proportions, material, distinctive parts, and confirmed state rules.

## Build the two jobs

### Job A: creator continuity, 10 seconds

Generate A as one video, never two five-second jobs.

- `0.0-5.0s`: show one relatable visible problem with one simple action.
- `5.0-10.0s`: show the same creator using or living with the product naturally; reserve detailed product operation for B.
- Lock continuity explicitly: same adult creator, face, hair, wardrobe, room, camera height, lens feeling, and lighting in both time blocks.
- Use a wider handheld lifestyle frame. Allow mild natural movement only.

### Job B: product proof, 10 seconds

Keep B product-led. Show only hands if a confirmed action requires them; do not show the creator's face.

- `0.0-3.5s`: one confirmed core operation, starting state to visible finished state.
- `3.5-7.0s`: one visible value proof supported by the product evidence.
- `7.0-10.0s`: stable complete-product hero view; do not introduce another function.
- Use a stable close product camera. Limit B to two real hand actions in total.

## Enforce visual-only deduplication

Do not use dialogue, copy, voice, price, or semantic marketing claims for deduplication. Use only visible cinematic variables.

Create one `visual_fingerprint` for every plan:

```json
{
  "environment_id": "laundry_room_blue_wall",
  "a_opening_problem_id": "broom_falls_to_floor",
  "a_creator_camera_id": "side_medium_handheld",
  "a_lifestyle_ending_id": "neat_wall_wide",
  "b_core_action_id": "handle_pressed_into_grip_side",
  "b_value_proof_id": "tool_stays_off_floor",
  "b_hero_angle_id": "three_quarter_closeup",
  "prop_variant_id": "wood_handle_broom",
  "hand_style_id": "right_hand_front_approach"
}
```

Compare this fingerprint with the supplied product history. Use the following hard rules:

1. Reject an exact fingerprint match.
2. Compared with each of the latest three accepted videos, change at least two A fields from `a_opening_problem_id`, `a_creator_camera_id`, and `a_lifestyle_ending_id`.
3. Compared with each of the latest five accepted videos, change at least two B fields from `b_core_action_id`, `b_value_proof_id`, `b_hero_angle_id`, `prop_variant_id`, and `hand_style_id`.
4. If a product has only one safe core operation, keep that operation but change at least three of environment, A camera, A ending, B proof, B hero angle, prop variant, and hand style.
5. Never invent an action solely to make the fingerprint different.

Vary only verified, visually meaningful elements:

- environment or placement scene;
- problem state;
- creator framing and camera angle;
- hand approach and visible supporting prop;
- confirmed value proof;
- product hero angle and ending composition.

Always keep A and B visually distinct: A is creator-led and wider; B is hands/product-led and close/stable.

## Write prompts for Omni Fast

Write compact English prompt text, normally 120-220 words per job.

- Begin with `Create one 10-second vertical 9:16 realistic ... video.`
- State exact time blocks before general style rules.
- Describe observable movement and the final physical state.
- State only required exclusions, including `no dialogue, no lip-sync, no subtitles, no text overlays, no UI, no watermark`.
- Do not request a voice, spoken CTA, readable labels, or audio synchronization.

## Return shape

Return valid JSON only with one `selected_script` object:

```json
{
  "selected_script": {
    "product_id": "<product id>",
    "structure_signature": "silent_ab20_a5_b10_a5",
    "silent_video": true,
    "opening_visual": "<visible A opening only>",
    "visual_fingerprint": {},
    "deduplication_check": {
      "history_checked": true,
      "exact_match": false,
      "a_fields_changed": 2,
      "b_fields_changed": 2,
      "accepted": true
    },
    "scene_order": ["video_A", "video_B"],
    "final_moyin_jobs": [
      {
        "scene_id": "video_A",
        "promptImage": "<one public image URL>",
        "promptText": "<silent A prompt>",
        "duration": "10",
        "ratio": "9:16",
        "watermark": false
      },
      {
        "scene_id": "video_B",
        "promptImage": "<one public image URL>",
        "promptText": "<silent B prompt>",
        "duration": "10",
        "ratio": "9:16",
        "watermark": false
      }
    ],
    "assembly_plan": {
      "input_order": ["video_A", "video_B", "video_A"],
      "source_ranges": ["0-5", "0-10", "5-10"],
      "output_duration_seconds": 20,
      "video_only": true,
      "ffmpeg_required_after_download": true,
      "output_file_name": "final_20s.mp4"
    }
  }
}
```

## Validate before returning

- Return exactly two jobs, each at 10 seconds and 9:16.
- Confirm A contains both five-second blocks in one prompt.
- Confirm B contains 3.5s, 3.5s, and 3s blocks.
- Confirm all actions and product states are supported by evidence.
- Confirm each job uses one image URL only.
- Confirm no audio or text request appears in either prompt.
- Reject a plan that fails the visual fingerprint rules instead of silently reusing a prior composition.

## Assembly

After both jobs are downloaded, the local Worker trims A into `0-5s` and `5-10s`, keeps all of B, then concatenates `A_head + B_full + A_tail` with FFmpeg. Normalize video settings before concatenation. Do not add audio in this skill.
