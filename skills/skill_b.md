---
name: ucg-omini-production-runner
description: Generate UGC/Omini ad plans and execute Moyin/Omini video production from a Skill A product reference pack. Use after product-reference-standardizer has produced product_profile.yaml plus images/product_white_bg.png, images/product_detail_side.png, and images/product_function.png; also use when the user asks to upload these references to GitHub/jsDelivr, write the Markdown plan, create hooks and Omini prompts, submit Moyin/Omini video jobs, poll, download MP4 files, save final videos under E:\视频, and save prompt history back into the product_reference_pack SKU folder.
---

# UCG Omini Production Runner

Use this as Skill B in the two-skill pipeline. Skill A standardizes product references. Skill B reads those fixed references, plans the ad, uploads image references, submits video jobs, polls, and downloads final MP4 files.

## Required Input

Accept a Skill A product reference pack:

```text
product_reference_pack/<sku_id>/
├─ product_profile.yaml
└─ images/
   ├─ product_white_bg.png
   ├─ product_detail_side.png
   └─ product_function.png
```

If the user provides only a raw product folder, stop and ask to run `product-reference-standardizer` first unless the user explicitly says to bypass Skill A.

Do not modify Skill A outputs unless the user explicitly asks. Skill B may create only:

- `history/prompt_payloads_<batch_id>.json` inside the Skill A product folder;
- optional working files outside `E:\视频`;
- final MP4 files and `polling_log.json` inside `E:\视频\<sku_id>_<batch_id>\`.

## Bundled Resources

Use:

- `config.yaml` for fixed video saving rules, batch naming, and output patterns.

## Fixed Production Defaults

Use these defaults unless the user changes them:

- Market: US market.
- Platform context: TikTok media buying and audience context.
- Final video duration: 30 seconds.
- Main video structure: 3 main segments, about 10 seconds each.
- Fourth B-roll: independent coverage clip, not counted in final 30 seconds.
- Aspect ratio: 9:16 vertical.
- Visual style: realistic phone-shot UGC review, natural creator content.
- Spoken/script language: American English.
- Planning language: Chinese.
- Omini/Moyin prompt language: Chinese.

In direct video prompts, do not write TikTok, TikTok style, platform UI, watermark, app UI, generated subtitles, sticker overlays, or on-screen text. Use platform-neutral wording such as `真实手机手持UGC短视频广告质感`. State that subtitles are added in post-production.

## Confirmation Gate

Before generating a full plan, check whether the Skill A reference pack and production context are enough:

1. Required Skill A files exist.
2. Fixed production defaults are acceptable.
3. Video form is known or can be selected from the product category: real-person talking head, voiceover + B-roll, hand demo, review reaction, scripted dialogue, problem-solution scene, ASMR product demo, vlog-style review, or mixed form.
4. Talent status is known: fixed creator exists or Skill B should design a virtual creator.
5. Main selling point or product function to prioritize is clear.
6. Forbidden scenes, compliance limitations, and claim limitations are captured.

If the Skill A files are missing, stop and ask to run Skill A. If only creative choices are missing and the user says `你来定`, `跳过确认`, `直接按默认做`, or equivalent wording, use the fixed defaults and select a suitable video form.

## Read Product Profile

Read `product_profile.yaml` and use it as the single product truth source.

Use:

- `sku_id`
- `product_name`
- `category`
- `source_info.title`
- `source_info.description`
- `visual_identity`
- `key_visual_features`
- `selling_points`
- `usage_scenes`
- `must_keep`
- `must_avoid`
- `reference_images`
- `source_image_audit`

Never invent product structure beyond `product_profile.yaml` and the three Skill A images.

Include `must_keep` and `must_avoid` constraints in all product-sensitive image and video prompts.

## Product Accuracy Rules

- Never guess product shape, size, materials, buttons, ports, color, packaging, mechanism, before/after effect, or performance.
- If only text supports a claim, phrase it conservatively and mark it as a claim in the plan.
- If a required view is absent from Skill A images, write prompts conservatively: `参考图未明确展示该视角，保持已知外观逻辑一致，不新增未展示结构`.
- When comparing before/after, show realistic organization, comfort, convenience, or user feeling instead of unverifiable transformation.
- The fourth B-roll clip may only show functions visible, stated, or reasonably supported by `product_profile.yaml`.
- For pet, washable, foldable, soft, fabric, or deformable products, avoid complex stuffing, twisting, rolling, pulling, machine insertion, or extreme deformation shots unless Skill A explicitly provides that function reference.

## Reference Image Handling

Before submitting any Moyin/Omini video job:

1. Upload these local Skill A images to GitHub repo `fye2552/moyin-images`:
   - `images/product_white_bg.png`
   - `images/product_detail_side.png`
   - `images/product_function.png`
2. Generate jsDelivr URLs:

```text
https://cdn.jsdelivr.net/gh/fye2552/moyin-images@main/<path>
```

3. Verify each URL returns an image response.
4. Use public HTTPS URLs in Moyin/Omini `images`. Do not send local paths.

Recommended GitHub repo path:

```text
ucg-assets/<ascii-product-slug>/<batch_id>/product-white-bg.png
ucg-assets/<ascii-product-slug>/<batch_id>/product-detail-side.png
ucg-assets/<ascii-product-slug>/<batch_id>/product-function.png
```

If a creator/scene image is generated, upload it too:

```text
ucg-assets/<ascii-product-slug>/<batch_id>/creator-scene.png
```

## Reference Image Diagnosis

When a generated video result is poor, diagnose reference images before rewriting prompts.

Flag these issues:

- multi-view product boards, dimension diagrams, comparison collages, arrows, labels, titles, measurement lines, UI elements, or many product angles are poor direct video references;
- product images with text overlays or multiple panels can cause the model to copy words, diagram lines, or mix several product angles;
- a creator portrait that does not match the target environment can force the model to change too many things at once;
- creator, scene, and product references with mismatched lighting, perspective, or environment can weaken consistency.

Preferred direct reference set:

- one creator/scene image without product;
- `product_white_bg.png` for product identity;
- `product_function.png` or `product_detail_side.png` only when a specific use relationship or detail is needed.

If image references are the likely problem, create or request cleaner references before increasing prompt complexity.

## Creator / Scene Rules

If no fixed creator exists, design one virtual creator:

- non-Asian ethnicity;
- stable age, gender presentation if relevant, hair, wardrobe, environment, expression, camera framing;
- no celebrity likeness;
- no branch words such as `or`, `maybe`, `if`, `could`, `可选`, `或者`, `如果`;
- no product, packaging, or host object in the creator/scene reference image.

Creator/scene references define person and environment only. Product consistency comes from Skill A images.

## Required Markdown Plan

Generate one editable Markdown plan in the product review/work folder, not in `E:\视频`.

Sections:

1. `【默认制作参数确认表】`
2. `【Skill A 标准参考资产读取结果】`
3. `【本次视频反重复策略】`
4. `【产品与受众判断】`
5. `【视频形式与创意逻辑】`
6. `【虚拟达人设定】`
7. `【达人/场景参考图提示词】`
8. `【10条 Hook】`
9. `【30秒正片：口播脚本 + B-roll镜头清单 + Omini可直接粘贴的视频生成提示词】`
10. `【独立第4段：产品功能展示补位素材（不计入成片时长）】`
11. `【成片检查清单】`
12. `【本次视频指纹记录（追加到 video_fingerprint_memory.md）】`
13. `【视频提交配置JSON】`
14. `【执行记录】`

Do not repeat the full Skill A source image audit. Summarize product facts, constraints, and reference URLs.

`【Skill A 标准参考资产读取结果】` must include:

- product profile path;
- three local image paths;
- three jsDelivr URLs after upload;
- key visual facts;
- `must_keep`;
- `must_avoid`;
- any unresolved or user-editable facts.

## Hooks And Script Rules

Generate 10 hooks in American English with Chinese translations.

Use varied hook types:

- pain point;
- curiosity;
- social proof;
- contradiction;
- mistake;
- scenario;
- challenge;
- comparison;
- confession;
- direct benefit.

For each 10-second main segment:

- English voiceover must be 30 words or fewer.
- Include Chinese B-roll shot list.
- Include one directly pasteable Chinese Omini/Moyin video prompt.
- Start each segment timeline at `00:00`.
- Break down the first 3 seconds of segment 01 at 0.5-second rhythm.

Use truthful wording such as `helps`, `designed for`, `makes it easier`, `what I noticed`. Avoid guaranteed results, medical claims, legal/financial claims, extreme before/after transformations, and unsupported comparisons.

## Anti-Duplication Strategy

This memory is not for tracking isolated hooks, CTAs, or every line of copy. Its purpose is to reduce repeated video-material fingerprints across multiple generations for the same product.

Read these signals from `history/prompt_payloads_*.json` and `video_fingerprint_memory.md`:

- talent identity: age range, gender presentation if relevant, hairstyle, wardrobe, personality, accent, creator type;
- scene and set: room type, background, surface/tabletop, lighting, props, camera distance, layout;
- opening visual: first 1-3 seconds of screen action;
- script angle: narrative route, not exact wording only;
- shot structure: selfie vs POV vs tabletop vs reaction, order of shots, close-up rhythm;
- product action sequence: which product actions happen and in what order;
- result/ending visual;
- independent fourth B-roll action.

Rules:

- Do not repeat the same talent + scene + opening visual + shot structure combination for the same SKU.
- If the script angle is similar to history, change talent identity, scene, opening visual, and camera structure.
- If the same talent must be reused, change scene, wardrobe, opening visual, camera style, and product action order.
- If the same scene must be reused, change talent identity, tabletop layout, lighting mood, opening visual, and shot structure.
- If the same product action sequence must be reused, change narrative framing, camera distance, hand/demo composition, and result/ending visual.
- The first second must not visually match a previous video fingerprint for the same SKU.
- The independent fourth B-roll should not repeat the previous fourth-clip coverage action unless explicitly required.

Include this section in the Markdown plan:

```markdown
【本次视频反重复策略】
- 历史相似风险：
- 本次达人变化：
- 本次场景变化：
- 本次开头画面变化：
- 本次镜头结构变化：
- 本次产品动作顺序变化：
- 本次第4段补位素材变化：
```

## Video Prompt Rules

Each prompt must include:

- duration and 9:16 vertical format;
- realistic phone-shot UGC wording;
- creator identity and scene continuity;
- product facts from `product_profile.yaml`;
- reference image roles and URLs;
- `must_keep` and `must_avoid` constraints;
- no platform names, UI, watermark, sticker, generated subtitle, packaging, text overlay, dimension line, poster layout, or comparison graphic;
- `字幕后期添加，不由视频模型生成文字`.

Submit four jobs in fixed order:

1. `segment_01`
2. `segment_02`
3. `segment_03`
4. `broll_coverage`

The fourth B-roll prompt must:

- be 8-10 seconds;
- not count toward the 30-second final video;
- cover one isolated product function or relationship;
- use only product facts confirmed in Skill A;
- avoid repeating a historical fourth-clip action unless required.

## Stable Main Segment Format

Use this directly pasteable structure for each 10-second main prompt. Preserve user-provided successful rhythm if present.

```text
画面中不得出现任何平台水印、TikTok水印、App界面、账号栏、点赞评论分享按钮、平台Logo、自动字幕、贴纸文字或边框UI。
生成一段9:16竖屏美国社交媒体短视频广告，真实手机手持UGC测评质感。参考图1中的固定达人/虚拟达人在[场景]，使用参考图2中的[产品]。产品只参考Skill A标准参考图，保持[关键外观特征]一致，不参考原始海报、尺寸图、文字卖点图或对比图，不生成尺寸线，不生成说明文字，不改变产品结构。画面自然真实，像创作者用手机随手拍摄。

00:00-00:00.5，[镜头类型]，[痛点/情绪/场景证据]。
00:00.5-00:01.0，[镜头类型]，[痛点继续或反差细节]。
00:01.0-00:01.5，[镜头类型]，[产品出现或解决方案出现]。
00:01.5-00:03.0，[镜头类型]，[自然口播/产品特写/情绪转折]。
00:03.0-00:06.0，[镜头类型]，[1个简单清楚的手部或使用动作]。
00:06.0-00:10.0，[镜头类型]，[产品产生真实结果或场景改善，不夸张]。

同步美式英语口播：“[对应本段的口播脚本]”
保留自然环境声、轻微产品声音和真实手机手持感。字幕后期添加，不由视频模型生成文字。
```

For segment 02 and segment 03, the first 3 seconds do not need 0.5-second beats unless useful. Internal time still starts at `00:00`.

Keep each 10-second prompt to 2-3 main actions when the product involves hands, pets, fabric deformation, precise object shape, face performance, or moving parts.

## Independent Fourth Clip Format

Always generate an independent fourth clip prompt after the three main prompts.

Use this format:

```text
独立第4段：产品功能展示补位素材（不计入成片时长，仅用于后期覆盖前三段中的穿模、穿帮、产品变形、手部异常或嘴型异常画面）

画面中不得出现任何平台水印、TikTok水印、App界面、账号栏、点赞评论分享按钮、平台Logo、自动字幕、贴纸文字或边框UI。
生成一段8-10秒9:16竖屏产品功能展示B-roll，延续前三段正片的[场景]、[光线]、[达人/手部风格]、[服装或环境细节]和真实手机手持UGC质感。产品只参考Skill A标准参考图，保持[关键外观特征]一致，不新增产品结构，不新增未确认功能，不生成说明文字。

00:00-00:02.0，[镜头类型]，[产品稳定特写或手部拿起，动作简单]。
00:02.0-00:04.0，[镜头类型]，[展示主推功能的一个清晰动作]。
00:04.0-00:06.0，[镜头类型]，[展示功能细节/材质/使用状态，仅限已知信息]。
00:06.0-00:08.0，[镜头类型]，[展示真实使用结果或场景改善，不夸张]。
00:08.0-00:10.0，[可选镜头类型]，[备用产品美观特写或自然收尾，可剪掉]。

不需要同步口播，不展示完整口型表演。保留自然环境声、轻微产品操作声和真实手机手持感。字幕后期添加，不由视频模型生成文字。
```

## Moyin/Omini Execution

Use local `.env` values:

- `MOYIN_API_BASE_URL`
- `MOYIN_API_KEY`
- `MOYIN_VIDEO_MODEL`
- `MOYIN_VIDEO_SIZE`
- `MOYIN_POLL_INTERVAL_SECONDS`
- `MOYIN_TIMEOUT_SECONDS`

Images array rules:

- Use only public HTTPS URLs.
- Prefer 2-3 references per video job:
  1. creator/scene URL if available;
  2. `product_white_bg` URL;
  3. `product_function` or `product_detail_side` URL when needed.
- Do not upload or submit raw posters, size charts, before/after images, marketplace screenshots, or text-heavy references.

## Batch ID Rules

If the user provides `batch_id`, use it.

If not, auto-generate:

```text
batch_001
batch_002
batch_003
...
```

Generation rule:

1. Sanitize `sku_id` for Windows folder names by replacing unsupported characters with `_`.
2. Check whether `E:\视频\<sku_id>_batch_001\` exists.
3. If it does not exist, use `batch_001`.
4. If it exists, increment to `batch_002`, then `batch_003`, and so on.

Use the same `batch_id` for prompt history:

```text
product_reference_pack/<sku_id>/history/prompt_payloads_<batch_id>.json
```

## Final Video Saving Rules

Final videos must be saved under:

```text
E:\视频
```

Each generated video group gets one folder:

```text
E:\视频\<sku_id>_<batch_id>\
```

Example:

```text
E:\视频\宠物毯子_batch_001\
├─ video_001.mp4
├─ video_002.mp4
├─ video_003.mp4
├─ video_004.mp4
└─ polling_log.json
```

Only save two kinds of files in that folder:

- generated MP4 files;
- `polling_log.json`.

Do not save these files in the video folder:

- `prompt_payloads.json`;
- `submitted_tasks.json`;
- `download_log.json`;
- `asset_manifest.generated.json`;
- strategy files;
- hooks files;
- scripts files;
- influencer files;
- Markdown plan files;
- raw payload dumps.

## Prompt Payload History

Do not save prompt payload history to `E:\视频`.

Save it inside the Skill A product reference folder:

```text
product_reference_pack/<sku_id>/history/prompt_payloads_<batch_id>.json
```

If `history/` does not exist, create it.

Purpose:

- avoid repeating scripts, prompts, creator identities, and video fingerprints for the same SKU;
- keep product assets and generation history together;
- keep `E:\视频` clean.

`prompt_payloads_<batch_id>.json` should include:

- batch id;
- sku id;
- timestamp;
- product profile path;
- reference image URLs used;
- creator/scene prompt;
- hooks selected/generated;
- four video prompt payloads;
- task IDs after submission;
- final status summary.

## Polling Log

Save `polling_log.json` only in:

```text
E:\视频\<sku_id>_<batch_id>\polling_log.json
```

It should include:

- submitted task IDs;
- target video filenames;
- poll timestamps;
- status transitions;
- progress if available;
- final video URL;
- local MP4 path;
- failure stage and provider error if any.

Report failure stage clearly:

- `submit_failed`: request rejected or bad payload.
- `generation_failed`: task accepted but provider/model failed.
- `processing_timeout`: still processing at timeout.
- `download_failed`: video URL returned but local download failed.
- `completed`: MP4 downloaded.

## Finished Video Checklist

Include this checklist in the Markdown plan and satisfy it before submission:

- product appearance follows Skill A `product_white_bg.png`;
- detail/function shots follow Skill A `product_detail_side.png` and `product_function.png`;
- no raw poster, size chart, before/after image, collage, or text-heavy source is used as direct video reference;
- no exaggerated claims, guaranteed results, medical/legal/financial promises, or unsupported comparisons;
- no packaging/unfolding/open-box scene unless Skill A explicitly supports it;
- no invented product shape, hidden mechanism, buttons, ports, screens, labels, cords, accessories, or electronic parts;
- first three seconds have a clear retention hook;
- audio/visual timing matches the segment script;
- no platform watermark/UI, generated subtitles, stickers, text overlays, labels, or measurement lines;
- subtitles are handled in post-production;
- main video still totals 30 seconds across three segments;
- fourth clip is only coverage B-roll and does not extend final duration;
- each 10-second English voiceover segment is 30 words or fewer.

## Download Flow

Use this exact saving flow:

```text
poll task status
↓
task succeeds
↓
create E:\视频\<sku_id>_<batch_id>\
↓
download MP4 files as video_001.mp4, video_002.mp4, video_003.mp4, video_004.mp4
↓
save polling_log.json in the same video folder
↓
save prompt payloads to product_reference_pack/<sku_id>/history/prompt_payloads_<batch_id>.json
↓
end
```

## Fingerprint Memory

Before generating prompts, read prior `history/prompt_payloads_*.json` and `video_fingerprint_memory.md` if present.

Avoid repeating the same combination of:

- talent identity;
- scene;
- opening visual;
- script angle;
- shot structure;
- product action sequence;
- ending visual;
- fourth B-roll action.

Always output a concise fingerprint block ready to append to `video_fingerprint_memory.md`.

## Final Report

End by reporting:

- Skill A reference pack path;
- batch id;
- Markdown plan path;
- prompt history path;
- video output folder path;
- MP4 paths;
- `polling_log.json` path;
- any failed task IDs and failure stages.

