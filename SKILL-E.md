---
name: wrong-use-amplification-ugc-video-creative
description: Design realistic TikTok/UGC product-video concepts that amplify a familiar wrong, inefficient, or frustrating use method before introducing the product as a credible solution. Use as Skill E when the user provides product copy, images, a Skill A product reference pack, or an existing campaign and wants hooks, pain amplification, shot design, voiceover, natural product entry, visible before/after results, light CTA, product-consistency rules, or a creative-only prompt for a downstream video generator. Do not use it to upload assets, call Moyin/Omini APIs, poll jobs, download videos, or perform other technical execution.
---

# Wrong-Use Amplification UGC Video Creative

Use this as Skill E in the product-video pipeline. Produce the creative direction only.

Core path:

```text
familiar wrong use -> pain detail -> audience recognition -> natural product entry
-> visible product action -> credible result -> light CTA
```

## Hard Boundary

Do:

- design the opening hook, pain amplification, product entry, use action, result, shots, voiceover, and CTA;
- preserve product identity and real capabilities from the supplied references;
- produce a Markdown creative package that can be handed to a downstream generation or production skill.

Do not:

- upload files to GitHub or create CDN URLs;
- submit Moyin/Omini tasks, poll jobs, or download MP4 files;
- invent product features, accessories, certifications, or unsupported outcomes;
- describe API endpoints, payload transport, credentials, or implementation commands.

## Inputs

Accept any combination of:

- a Skill A pack containing `product_profile.yaml` and product reference images;
- product title, description, selling points, and limitations;
- white-background, detail, function, or real-use images;
- target duration, aspect ratio, audience, platform, language, or concept count;
- prior campaign concepts for deduplication.

When a Skill A pack is supplied, treat `product_profile.yaml` and its reference images as the product truth. If the input does not prove a capability, do not claim or show it.

If product truth is too incomplete to design a credible demonstration, identify the missing fact instead of guessing. Otherwise proceed with conservative assumptions.

## Workflow

1. Extract product identity, real functions, usable actions, visible outcomes, likely environments, and prohibited claims.
2. Decide whether the product can produce a camera-verifiable result. If not, explain that this creative pattern is a poor fit and choose a less outcome-dependent concept.
3. List familiar wrong or inefficient methods that naturally precede using this product.
4. Select one wrong method with an immediate visual signal, strong audience recognition, and a physically credible product solution.
5. Build the timeline: hook, pain detail, natural product entry, use action, result, and light CTA.
6. Lock product identity across every shot.
7. Write concise spoken English for US-market UGC unless the user requests another language.
8. Check realism, continuity, claim safety, and visual clarity before returning the creative package.

Read [creative-rules.md](references/creative-rules.md) when selecting the wrong-use scenario, visual hook, shot language, narration, or negative constraints.

Read [output-schema.md](references/output-schema.md) before formatting the final deliverable.

## Hook Selection

Default to `wrong_use_amplification`:

- show a real person using a familiar but inefficient method;
- use a close-up that makes the failure instantly legible;
- emphasize smearing, scattering, repeated effort, residue, rework, bending, fatigue, or a blocked/unfinished result;
- avoid making the person look foolish or dangerously negligent.

Use `satisfying_result_preview` only when the user asks for a result-first opening or when the product has an unusually strong, credible visual transformation. After the preview, return to the underlying pain before showing the full solution.

Never begin with a static pack shot, parameter list, polished product pedestal, or direct sales pitch.

## Timeline

Adapt to the requested duration. If none is provided, use 10 seconds:

```text
0-3s: wrong-use amplification hook
3-5s: pain detail and recognition
5-8.5s: product enters naturally and performs one clear action
8.5-10s: stable result proof and light CTA
```

For longer videos, extend the problem and solution demonstration without adding unrelated story beats. Keep one primary problem and one primary product action per concept.

## Product Entry And Action

Connect product entry to an ordinary action: reach from a counter, cleaning basket, toolbox, garage shelf, storage area, or nearby work surface after the old method fails.

Show the product clearly before or during its first action. The action must be simple, understandable without explanation, and physically consistent with the real function. Show the transition from problem to improvement; do not jump directly from before to after.

## Product Consistency Lock

Carry these verified attributes into every shot and downstream prompt:

- color and material;
- body shape and proportions;
- logo or label placement;
- handle, nozzle, brush, blade, outlet, control, connector, and other visible structures;
- package or main-unit appearance when present.

Forbid category changes, color shifts, shape drift, extra controls, invented lights or screens, nonexistent accessories, floating products, and function expansion.

## UGC Style

Use realistic phone-shot language:

- real home, garage, driveway, yard, car, pet, or storage environment;
- natural household light and plausible materials;
- close-ups for the failure and result, medium shots for product use;
- slight handheld movement without chaotic framing;
- restrained reactions and natural environmental sound;
- no platform UI, watermarks, auto-captions, stickers, promotional banners, or television-commercial polish.

The user may be visible, but the product and the problem-solving action remain the focus. Do not build an elaborate influencer persona unless explicitly requested.

## Voiceover And CTA

Use short, conversational lines that add information the image cannot show. Prefer reactions such as:

- `I used to do this over and over.`
- `It just kept spreading everywhere.`
- `Then I switched to this.`
- `That was way easier than I expected.`
- `Simple, but it works.`

Avoid absolute promises, hard-sell language, parameter dumping, and repeating the visible action word for word.

## Quality Gate

Before finalizing, verify:

- the first three seconds are understandable without audio;
- the wrong method is familiar, safe to depict, and not absurd;
- the pain is shown through a visible detail rather than exposition;
- the product enters through a plausible life action;
- the complete solution action appears on screen;
- the result is visible from a stable, comparable angle;
- every claim and action is supported by product truth;
- the product remains the same object in every shot;
- the CTA is light and credible;
- the output contains no technical execution steps.
