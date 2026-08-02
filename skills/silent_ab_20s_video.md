---
name: silent-ab-20s-video
description: Create silent 20-second vertical product-video plans from a product YAML profile and reference images. Use for Omni Fast image-to-video prompts that require a 10-second creator segment A, a 10-second product segment B, FFmpeg assembly, and visual-only deduplication without narration, captions, or lip-sync.
---

# Silent A/B 20-second product video

Create a silent vertical product ad with this fixed edit order:

`A[0-5s] + B[0-10s] + A[5-10s] = 20s`

Generate exactly two independent 10-second image-to-video jobs. Do not generate or request dialogue, narration, captions, lip-sync, text overlays, UI, a spoken CTA, or background music. Keep natural room ambience and genuine product-use sounds in both videos.

## Read the product evidence

Read the supplied product YAML and inspect the supplied reference images before writing prompts.

- Treat `instructions_for_use`, `must_keep`, `must_avoid`, and visible product details as authoritative.
- Use only confirmed physical actions. If a mechanism, direction, or state change is not confirmed, replace it with a neutral product display.
- Treat the reference image's **apparent product size and aspect ratio** as authoritative. If the YAML lists multiple purchasable sizes, do not select or state a centimetre/inch measurement unless the user explicitly selects that variant.
- Choose one public reference image URL per job. Prefer a natural lifestyle image for A and the clearest functional image for B. Never concatenate multiple URLs.
- Preserve product colour, shape, proportions, material, distinctive parts, confirmed state rules, and physical scale.

## Lock physical size and scale

Before writing either prompt, create an internal `product_scale_lock` from the supplied reference image:

```json
{
  "reference_size_mode": "apparent_size_and_aspect_ratio",
  "absolute_dimension_claim": "not_used",
  "approved_scale_anchors": ["adult_hand", "confirmed_use_object", "work_surface"],
  "cross_job_rule": "same product width, depth, thickness, and key-part scale in A and B"
}
```

Use only anchors that are natural to the verified scene. For example: adult hands, a confirmed knife, a confirmed food item, a shelf compartment, a drawer opening, a car cup holder, or a countertop. Do not invent an anchor just to specify scale.

Every A and B prompt must contain one compact physical-scale lock sentence that:

- keeps the reference image's apparent width-to-depth ratio and thickness;
- keeps key visible parts at the same relative scale;
- keeps the product's size consistent relative to approved anchors in all time blocks;
- forbids shrinking, enlarging, stretching, flattening, or changing the product into another category.

Do not use an unsupported exact dimension. Do not use vague size words such as `oversized`, `mini`, `large`, or `small` unless the chosen reference image and user request make that comparison unambiguous.

## Build the two jobs

### Job A: creator continuity, 10 seconds

Generate A as one video, never two five-second jobs.

- `0.0-5.0s`: show one relatable visible problem with one simple action.
- `5.0-10.0s`: show the same creator using or living with the product naturally; reserve detailed product operation for B.
- Lock continuity explicitly: same adult creator, face, hair, wardrobe, room, camera height, lens feeling, and lighting in both time blocks.
- Use a wider handheld lifestyle frame. Allow mild natural movement only.
- When the product appears in A, apply the same `product_scale_lock` used in B. Creator continuity never permits the product to change scale between A's two time blocks.

### Job B: product proof, 10 seconds

Keep B product-led. Show only hands if a confirmed action requires them; do not show the creator's face.

- `0.0-3.5s`: one confirmed core operation, starting state to visible finished state.
- `3.5-7.0s`: one visible value proof supported by the product evidence.
- `7.0-10.0s`: stable complete-product hero view; do not introduce another function.
- Use a stable close product camera. Limit B to two real hand actions in total.
- Use the approved scale anchors in the close product composition, so a camera-angle change cannot make the product look like a different size.

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
  "hand_style_id": "right_hand_front_approach",
  "product_scale_lock_id": "reference_ratio_hand_prop_counter"
}
```

Compare this fingerprint with the supplied product history. Use the following hard rules:

1. Reject an exact fingerprint match.
2. Compared with each of the latest three accepted videos, change at least two A fields from `a_opening_problem_id`, `a_creator_camera_id`, and `a_lifestyle_ending_id`.
3. Compared with each of the latest five accepted videos, change at least two B fields from `b_core_action_id`, `b_value_proof_id`, `b_hero_angle_id`, `prop_variant_id`, and `hand_style_id`.
4. If a product has only one safe core operation, keep that operation but change at least three of environment, A camera, A ending, B proof, B hero angle, prop variant, and hand style.
5. Never invent an action solely to make the fingerprint different.
6. `product_scale_lock_id` is an identity constraint, not a de-duplication variable. Do not change product scale to create a visually different video.

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
- Include one short `Physical scale lock:` sentence using the reference aspect ratio and only verified scene anchors.
- State only required exclusions, including `no dialogue, no lip-sync, no subtitles, no text overlays, no UI, no watermark`.
- Request natural ambient sound and real product-use sounds only. Do not request a voice, spoken CTA, background music, readable labels, or audio synchronization.

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
    "product_scale_lock": {
      "reference_size_mode": "apparent_size_and_aspect_ratio",
      "absolute_dimension_claim": "not_used",
      "approved_scale_anchors": [],
      "cross_job_rule": "same product width, depth, thickness, and key-part scale in A and B"
    },
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
      "video_only": false,
      "preserve_source_audio": true,
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
- Confirm both prompts contain the same evidence-based physical-scale lock and do not state an unconfirmed exact product dimension.
- Confirm product scale is not used as a de-duplication variable.
- Confirm each job uses one image URL only.
- Confirm each prompt requests natural ambience and product-use sound only, with no dialogue, narration, background music, or text.
- Reject a plan that fails the visual fingerprint rules instead of silently reusing a prior composition.

## Assembly

After both jobs are downloaded, the local Worker trims the original video **and audio** tracks into A `0-5s`, B `0-10s`, and A `5-10s`, then concatenates `A_head + B_full + A_tail` with FFmpeg. Preserve only each source clip's natural ambience and product-use sounds; do not add narration, background music, or a new audio track. If either source video has no audio stream, stop and report it instead of silently exporting a mute final video.
