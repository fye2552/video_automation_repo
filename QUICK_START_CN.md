# 一键生成视频：最简单用法

## 每次只做三步

### 1. 放入产品文件夹

把一个完整产品文件夹放进：

`E:\n8n-video-gemini\local_products\`

例如：

`E:\n8n-video-gemini\local_products\my_new_product\`

产品文件夹至少应包含：

```text
my_new_product/
  skill_a/
    product_profile.yaml
  images/
    product_white_bg.png
    product_detail_side.jpeg
    product_function.png
```

图片也可以放在 `reference_images` 或 `skill_a/reference_images`。支持 `.jpg`、`.jpeg`、`.png`、`.webp`。

### 2. 双击一个启动文件

根据你想使用的脚本风格，双击项目根目录中的其中一个文件：

```text
start_and_run_all_skill_b.bat
start_and_run_all_skill_c.bat
start_and_run_all_skill_e.bat
start_and_run_all_skill_h.bat
start_and_run_all_skill_shelf_single_sample.bat
start_and_run_all_skill_target_shelf_v6.bat
```

不要同时双击两个启动文件。黑色窗口打开后，不要关闭 n8n 和 watcher 窗口。

### 3. 等待视频完成

启动文件会自动完成：

```text
上传产品到 GitHub
-> 生成视频脚本
-> 提交视频任务
-> 本地轮询任务
-> 下载 MP4
```

视频完成后在这里找：

`E:\n8n-video-gemini\video_output\产品ID\任务ID\`

里面的 `.mp4` 就是生成的视频。

## 第一次使用前只检查一次

确认 `E:\n8n-video-gemini\.env` 已填写有效值：

```env
GITHUB_TOKEN=
OPENAI_API_KEY=
OPENAI_CHAT_COMPLETIONS_URL=https://api.aiyxgaw.com/v1/chat/completions
OPENAI_MODEL=gemini-3.5-flash
MOYIN_API_BASE_URL=https://aihubcc.cc/v1
MOYIN_API_KEY=
MOYIN_VIDEO_MODEL=omni-fast
```

不要把真实 Key 发到聊天、GitHub 或截图中。

## 看到报错时看哪里

- 脚本生成失败：`E:\n8n-video-gemini\openai_jobs\...\openai.log`
- 视频任务和下载失败：`E:\n8n-video-gemini\video_jobs\任务ID\worker.log`
- 视频状态：`E:\n8n-video-gemini\video_jobs\任务ID\status.json`

## 一个重要规则

同一个产品正在生成时，不要重复启动。等该产品视频完成或失败后，再运行下一次。
