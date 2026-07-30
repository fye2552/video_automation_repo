---
name: low-ri<REDACTED_API_KEY>
description: "Generate 20-second low-risk-rescuer fast-cut UGC/Omini ad videos from a Skill A product reference pack. Use after product-reference-standardizer has produced product_profile.yaml and images/product_white_bg.jpeg, when the user wants Skill H: a real pain-point hook, an absurd adult family rescuer entering with the correct product, quick product solution, three fast-cut usage scenes, short CTA, two 10-second Moyin/Omini segment submissions per video, artifact upload, MP4 downloads, and saved prompt history."
---

## Environment Config (.env)

Load provider endpoints, API keys, model names, GitHub credentials, repository details, and CDN base URL from the local `.env` file. Do not put real API keys, GitHub tokens, or credentials in this Skill.

Required names:

```env
VIDEO_PROVIDER=
MOYIN_API_BASE_URL=
MOYIN_API_KEY=
MOYIN_VIDEO_MODEL=
MOYIN_VIDEO_SIZE=
MOYIN_POLL_INTERVAL_SECONDS=
MOYIN_TIMEOUT_SECONDS=
TEXT_PROVIDER=
TEXT_API_BASE_URL=
TEXT_API_KEY=
TEXT_MODEL=
IMAGE_PROVIDER=
IMAGE_API_BASE_URL=
IMAGE_API_KEY=
IMAGE_MODEL=
GITHUB_TOKEN=
GITHUB_REPO_OWNER=
GITHUB_REPO_NAME=
GITHUB_BRANCH=
CDN_BASE=
```

# Low-Risk Rescuer Fast-Cut Video Generator

Use this as Skill H in the product-video pipeline. Skill A creates standardized product references. Skill H creates 20-second fast-cut ads and executes video generation as two 10-second segments per complete video.

Skill H reuses Skill B's execution layer: read Skill A output, generate prompt payloads, upload to GitHub, submit Moyin/Omini tasks, poll, download MP4s, and save prompt history. Its creative direction is: real pain-point hook -> absurd adult family rescuer carries the correct product into the pain point -> product quick solution -> multi-scene fast cuts -> CTA.

## Hard Boundary

Skill H does not:

- generate product white-background images;
- generate product detail images;
- generate product function images;
- create complex influencer personas;
- perform influencer dedupe;
- run post-generation visual consistency checks;
- perform manual review status flow;
- stitch the two 10-second segments into one 20-second video.

Current scope: generate two 10-second segments per complete 20-second ad, submit them, poll them, download them, and save files according to the rules below.

## Required Input

Read a Skill A product reference pack:

```text
product_reference_pack/<sku_id>/
├─ product_profile.yaml
└─ images/
   ├─ product_white_bg.jpeg
   ├─ product_detail_side.jpeg
   └─ product_function.jpeg
```

Required files:

- `product_profile.yaml`
- `images/product_white_bg.jpeg`

Optional files:

- `images/product_detail_side.jpeg`
- `images/product_function.jpeg`

Stop only for missing required files:

```text
ERROR: missing required file: product_profile.yaml
ERROR: missing required file: images/product_white_bg.jpeg
```

Do not stop if optional images are missing. If an optional image is absent, set that manifest field to `null` and omit it from `reference_images`.

## Bundled Resources

Use:

- `config.yaml`: paths, duration, batch, provider, and saving rules.
- `prompts/pain_points_prompt.md`: generate pain points.
- `prompts/conflict_hooks_prompt.md`: generate low-risk pain hooks.
- `prompts/scene_sequence_prompt.md`: build the fixed 20-second sequence.
- `prompts/script_prompt.md`: generate scripts and CTA.
- `prompts/segment_prompt_builder.md`: build two 10-second segment prompts.

Read only the prompt file needed for the current step.

## Asset Manifest

At startup, generate:

```text
campaign_output/<sku_id>_skill_h/asset_manifest.generated.json
```

Shape:

```json
{
  "sku_id": "",
  "profile": "product_profile.yaml",
  "required_assets": {"white_bg": "images/product_white_bg.jpeg"},
  "optional_assets": {
    "detail_side": "images/product_detail_side.jpeg",
    "function": "images/product_function.jpeg"
  }
}
```

If an optional image does not exist, set the value to `null`.

## Campaign Output Folder

Create intermediate files under:

```text
campaign_output/<sku_id>_skill_h/
├─ asset_manifest.generated.json
├─ strategy/
│  ├─ pain_points.yaml
│  ├─ conflict_hooks.yaml
│  ├─ scene_sequences.yaml
│  └─ scripts.yaml
├─ prompts/
│  └─ prompt_payloads.json
├─ github/
│  └─ github_upload_log.json
└─ api/
   └─ polling_log.json
```

Do not create `influencers.yaml`, `manual_review.json`, or `consistency_review.json`.

## Creative Positioning

Skill H is not a classic creator seeding video.

Core story:

```text
real pain-point hook
↓
absurd adult family rescuer carries the correct product into the pain point
↓
product quick solution
↓
fast-cut multi-scene usage
↓
CTA
```

The person on screen, if any, is only a natural user, hand demonstrator, pet owner, or ordinary home user. Do not create complex creator profiles such as age-range influencer identity, occupation persona, creator style, follower profile, or detailed influencer positioning.

## Fixed 20-Second Structure

Every complete ad is 20 seconds:

```text
0-1.5s: real pain-point hook
1.5-3s: absurd adult family rescuer enters with the correct product and says one short line
3-6s: product solution
6-10s: fast-cut scene 1
10-14s: fast-cut scene 2
14-18s: fast-cut scene 3
18-20s: CTA
```

### 0-1.5s: Real Pain-Point Hook

Show one real everyday problem that is understood in the first frame.

Focus:

- a concrete problem object in its real household setting;
- one wrong, inefficient, messy, uncomfortable, or inconvenient moment;
- a close-up detail that makes the pain instantly legible;
- one physically credible cause for the later product solution.

Do not:

- show the product;
- show the rescuer;
- show a perfect result;
- use slow setup;
- turn the problem into an accident, collapse, injury, panic, danger, unreasonable damage, or exaggerated disaster.

### 1.5-3s: Absurd Adult Family Rescuer With Product

Role B must be a clear adult family member of Role A: grandmother, grandfather, adult son, husband, wife, or another explicit adult relative.

The rescuer must have all three:

1. one identity or stage outfit that is visibly wrong for the household task;
2. two strong visual anchors visible in a paused frame;
3. one safe short abnormal entrance movement that does not interfere with holding the product.

Role B must carry the exact product from the first frame of entry. The product must be complete, correct, and clearly visible. Role B moves directly into the preceding pain-point position, places or holds the product at its real use location by 3.0 seconds, and says one short 2-5 word English line related to the action. Role A may use one short family call during 1.1-1.5 seconds, such as `Grandma!`

Do not let Role B enter empty-handed, independently perform comedy, use magic, make threats, use children, imitate a celebrity, use a non-human head, use sexualized behavior, show horror, or use an unsafe action.

### 3-6s: Product Solution

Bring in the product quickly and directly solve the previous pain.

Use:

- product placed into the problem scene;
- product replacing the wrong behavior;
- scene becoming cleaner, softer, easier, more organized, or more comfortable.

Do not:

- give a long product intro;
- explain parameters;
- let people overpower the product.

### 6-10s, 10-14s, 14-18s: Fast-Cut Scenes

Use three fast-cut result/usage scenes.

Scene 1: first clear result after using the product.
Scene 2: different real-life usage environment or different angle.
Scene 3: final result, comfort, cleanliness, organization, or improved usage.

Each scene must keep the product visible and central.

### 18-20s: CTA

Short, light CTA in English. Avoid hard sell.

Examples:

- `Make your space cleaner and cozier.`
- `A simple upgrade for everyday use.`
- `Your cozy spot starts here.`
- `Check it out today.`

## Two-Segment Omini Rule

Do not submit a 20-second prompt directly. Split each complete ad into two 10-second segments:

```text
video_001
├─ video_001_part_01: 0-10s
└─ video_001_part_02: 10-20s
```

### Segment 1

`video_001_part_01` covers global 0-10s:

- 0-1.5s: real pain-point hook;
- 1.5-3s: absurd adult family rescuer with the correct product and one short line;
- 3-6s: product solution;
- 6-10s: fast-cut scene 1.

Prompt must include:

```text
Create a 10-second vertical UGC ad video.
Timeline:
0-1.5s: Show one real daily pain point through a close-up detail. No product and no rescuer.
1.5-3s: An absurd adult family rescuer enters carrying the exact product from the first frame, takes it directly to the pain-point position, and says one short 2-5 word English line.
3-6s: Quickly show the product as the direct solution and show the issue being fixed through one clear action.
6-10s: Fast-cut scene 1 showing the first clear result.
Do not start with a perfect product shot.
Do not end with a CTA in this segment.
Keep the pacing fast, clear, low-risk, and product-focused.
```

### Segment 2

`video_001_part_02` covers global 10-20s:

- 0-4s: fast-cut scene 2;
- 4-8s: fast-cut scene 3;
- 8-10s: CTA.

Prompt must include:

```text
Create a 10-second vertical UGC ad video.
Timeline:
0-4s: Fast-cut scene 2 in a different real-life usage environment.
4-8s: Fast-cut scene 3 showing final result, comfort, cleanliness, or improved usage.
8-10s: Short CTA.
This segment should feel like the continuation of the previous 10-second segment.
Keep the same product identity, visual style, pacing, and usage logic.
```

## Product Consistency Rules

Every prompt must include:

```text
Use the provided product reference images as the exact product identity.
Do not change the product color, shape, material, size ratio, logo position, texture, or visible structure.
Do not invent extra accessories, buttons, lights, packaging, or exaggerated functions.
```

If `images/product_detail_side.jpeg` exists, add:

```text
Use the detail and side reference image to preserve product material, side structure, edge shape, texture, and visible details.
```

If `images/product_function.jpeg` exists, add:

```text
Use the function reference image only to understand the real product usage. Do not invent new functions.
```

## Strategy Files

### `strategy/pain_points.yaml`

```yaml
pain_points:
  - pain_point_id: "pain_001"
    pain_point: ""
    wrong_behavior: ""
    close_up_detail: ""
    emotional_trigger: ""
```

### `strategy/conflict_hooks.yaml`

```yaml
conflict_hooks:
  - conflict_id: "conflict_001"
    opening_scene: ""
    wrong_behavior: ""
    amplified_detail: ""
    conflict_type: "low_risk_pain_rescuer"
```

### `strategy/scene_sequences.yaml`

```yaml
scene_sequences:
  - sequence_id: "sequence_001"
    total_duration: 20
    structure:
      - time: "0-1.5s"
        segment: "pain_hook"
        description: ""
      - time: "1.5-3s"
        segment: "absurd_adult_family_rescuer"
        description: ""
      - time: "3-6s"
        segment: "product_solution"
        description: ""
      - time: "6-10s"
        segment: "fast_cut_scene_1"
        description: ""
      - time: "10-14s"
        segment: "fast_cut_scene_2"
        description: ""
      - time: "14-18s"
        segment: "fast_cut_scene_3"
        description: ""
      - time: "18-20s"
        segment: "cta"
        description: ""
```

### `strategy/scripts.yaml`

```yaml
scripts:
  - script_id: "script_h_001"
    duration: 20
    style: "low_risk_rescuer_fast_cut"
    pain_point: ""
    conflict_hook: ""
    product_solution: ""
    timeline:
      - time: "0-1.5s"
        purpose: "真实痛点钩子"
        scene: ""
      - time: "1.5-3s"
        purpose: "荒诞成年亲属携产品入场"
        scene: ""
      - time: "3-6s"
        purpose: "产品解决"
        scene: ""
      - time: "6-10s"
        purpose: "快切场景 1"
        scene: ""
      - time: "10-14s"
        purpose: "快切场景 2"
        scene: ""
      - time: "14-18s"
        purpose: "快切场景 3"
        scene: ""
      - time: "18-20s"
        purpose: "CTA"
        scene: ""
    cta: ""
    dedupe_key: ""
```

## Dedupe Rules

Skill H does not do influencer dedupe.

Dedupe these:

- pain points;
- conflict hooks;
- scripts.

Read history from:

```text
product_reference_pack/<sku_id>/history/prompt_payloads_H_batch_*.json
```

If similarity is greater than 50%, regenerate. If similarity is 50% or lower, allow it.

## Prompt Payloads

Generate:

```text
campaign_output/<sku_id>_skill_h/prompts/prompt_payloads.json
```

Structure by complete video and two segments:

```json
{
  "sku_id": "",
  "skill": "H",
  "provider": "omini",
  "videos": [
    {
      "video_id": "video_001",
      "total_duration": 20,
      "aspect_ratio": "9:16",
      "language": "English",
      "style": "low_risk_rescuer_fast_cut",
      "segments": [
        {
          "segment_id": "video_001_part_01",
          "segment_index": 1,
          "duration": 10,
          "global_time_range": "0-10s",
          "timeline": ["0-1.5s: pain hook", "1.5-3s: absurd adult family rescuer", "3-6s: product solution", "6-10s: fast-cut scene 1"],
          "reference_images": ["images/product_white_bg.jpeg"],
          "prompt": "",
          "negative_prompt": ""
        },
        {
          "segment_id": "video_001_part_02",
          "segment_index": 2,
          "duration": 10,
          "global_time_range": "10-20s",
          "timeline": ["0-4s: fast-cut scene 2", "4-8s: fast-cut scene 3", "8-10s: CTA"],
          "reference_images": ["images/product_white_bg.jpeg"],
          "prompt": "",
          "negative_prompt": ""
        }
      ]
    }
  ]
}
```

If optional reference images exist, add them to `reference_images`. If absent, omit them.

## GitHub Upload Rules

GitHub upload is mandatory before any video task submission. Two-phase upload:

### Phase 1: Reference Images

Upload the product reference images from the Skill A reference pack to GitHub. These become the CDN URLs used in every segment prompt:

| Local File | GitHub Path | CDN URL |
|---|---|---|
| `images/product_white_bg.jpeg` | `<sku_id>/product_white_bg.jpeg` | `https://cdn.jsdelivr.net/gh/<owner>/<repo>@<branch>/<sku_id>/product_white_bg.jpeg` |
| `images/product_detail_side.jpeg` | `<sku_id>/product_detail_side.jpeg` | `https://cdn.jsdelivr.net/gh/<owner>/<repo>@<branch>/<sku_id>/product_detail_side.jpeg` |
| `images/product_function.jpeg` | `<sku_id>/product_function.jpeg` | `https://cdn.jsdelivr.net/gh/<owner>/<repo>@<branch>/<sku_id>/product_function.jpeg` |

Skip optional images that are missing. After upload, all `reference_images` in `prompt_payloads.json` must contain CDN URLs, not local paths.

### Phase 2: Campaign Artifacts

Upload these files to GitHub:

- `asset_manifest.generated.json`
- `strategy/pain_points.yaml`
- `strategy/conflict_hooks.yaml`
- `strategy/scene_sequences.yaml`
- `strategy/scripts.yaml`
- `prompts/prompt_payloads.json`

Save upload log to:

```text
campaign_output/<sku_id>_skill_h/github/github_upload_log.json
```

The upload log must list every file uploaded with its CDN URL. Video API image references in prompts must be public HTTPS URLs, never local file paths.

## Provider Adapter

Reuse Skill B's video-generation adapter pattern.

```text
submit_task(payload) -> task_id
poll_task(task_id) -> task_status
download_video(task_id, output_path) -> video_path
```

Skill H submits by segment, not by full 20-second video.

## Deferred Polling

Video generation tasks are long-running. After submitting all segment tasks:

1. Write all task metadata (sku_id, video_id, segment_id, task_id, output path) to `E:\marvis\skill\tasks.json`.
2. Launch an independent cmd window to poll and download:
   ```powershell
   Start-Process cmd -ArgumentList '/c', 'python E:\marvis\skill\poll_videos.py'
   ```
3. The polling script runs locally, downloads MP4s to the video output folder, and writes `polling_log.json`. Do not block the main session waiting for polling results.

## Video Saving Rules

Final segment MP4s must be saved under:

```text
E:\视频\<sku_id>_H_<batch_id>\
```

Only save segment MP4 files and `polling_log.json` in that folder. Do not save prompt payloads, strategy files, manifests, or upload logs there.

## Polling Log

`polling_log.json` must include complete video ID and segment ID:

```json
{
  "logs": [
    {
      "video_id": "video_001",
      "segment_id": "video_001_part_01",
      "task_id": "task_xxx_001",
      "status": "succeeded",
      "checked_at": "2026-06-23T00:03:00Z"
    }
  ]
}
```

## Prompt History

Do not save `prompt_payloads.json` to `E:\视频`.

Save prompt history to:

```text
product_reference_pack/<sku_id>/history/prompt_payloads_H_<batch_id>.json
```

Create `history/` if it does not exist.

## Batch ID Rules

If the user provides `batch_id`, use it. If not, generate `batch_001`, `batch_002`, `batch_003`, and so on.

Check `E:\视频\<sku_id>_H_batch_001\`. If it exists, increment until an unused folder is found.

## Execution Workflow

1. Read Skill A product reference pack.
2. Validate required files.
3. Generate `asset_manifest.generated.json`.
4. Generate `pain_points.yaml`.
5. Generate `conflict_hooks.yaml`.
6. Generate `scene_sequences.yaml`.
7. Generate `scripts.yaml`.
8. Dedupe against `history/prompt_payloads_H_batch_*.json`.
9. Generate `prompts/prompt_payloads.json`.
10. Upload campaign artifacts to GitHub and save `github_upload_log.json`.
11. Submit every segment task.
12. Write task metadata to `E:\marvis\skill\tasks.json`, launch independent cmd window to poll and download MP4s locally. Do not block the main session.
13. Save prompt history to Skill A `history/`.
14. Report outputs.

## Final Report

Report:

- Skill A reference pack path;
- campaign output folder;
- batch id;
- video output folder;
- prompt history path;
- GitHub upload log path;
- polling log path;
- each segment MP4 path;
- failed segment IDs and failure stage if any.

