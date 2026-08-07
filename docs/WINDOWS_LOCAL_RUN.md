# n8n 本地视频生成运行说明（Windows / npm n8n）

本项目当前方案不使用 Docker，不使用 n8n Execute Command 节点。

## 当前闭环

1. n8n 读取本地产品资料并上传到 GitHub。
2. n8n 读取 GitHub 产品资料、Skill、历史记录。
3. n8n 调 OpenAI 生成并查重脚本。
4. n8n 调 Moyin Create Video，拿到 task id。
5. n8n 写入本地 inbox job：`E:/n8n-video-gemini/video_jobs/inbox/{job_id}.json`。
6. 本地 Node watcher 自动领取 inbox job。
7. Node worker 轮询 Moyin，下载视频到：`E:/n8n-video-gemini/video_output/{product_id}/{job_id}/`。
8. worker 写 `status.json`、`done.json` 或 `failed.json` 后退出。

worker 不回调 n8n，不写 GitHub，不保存 API Key。

## 必填环境变量

复制 `.env.example` 为 `.env`，只在本机 `.env` 里填写真实密钥：

```env
GITHUB_TOKEN=
OPENAI_API_KEY=
MOYIN_API_KEY=
MOYIN_API_BASE_URL=https://memefast.top
N8N_LOCAL_PRODUCTS_DIR=E:/n8n-video-gemini/local_products
N8N_LOCAL_JOBS_DIR=E:/n8n-video-gemini/video_jobs
N8N_LOCAL_OUTPUT_DIR=E:/n8n-video-gemini/video_output
```

不要把真实密钥写进 workflow、config、docs 或 GitHub。

## 启动 n8n

双击：

```text
E:\n8n-video-gemini\start.bat
```

它会启动本地 npm 版 n8n：

```text
http://localhost:5678
```

## 导入 workflow

在 n8n 页面里导入并发布这两个文件：

```text
E:\n8n-video-gemini\workflows\local_product_upload_to_github.workflow.json
E:\n8n-video-gemini\workflows\main_generate_video.workflow.json
```

导入后两个 workflow 都要 Publish。

## 批量运行

Skill C：

```text
E:\n8n-video-gemini\start_and_run_all_skill_c.bat
```

Skill B：

```text
E:\n8n-video-gemini\start_and_run_all_skill_b.bat
```

Custom Skill：

```text
E:\n8n-video-gemini\start_and_run_all_custom.bat
```

Dry run：

```text
E:\n8n-video-gemini\start_and_run_all_dryrun.bat
```

非 dry run 的批处理会启动：

```text
node workers\worker_watcher.js
```

所以不需要 Python，也不需要 Docker。

## 单产品测试

把产品目录放到：

```text
E:\n8n-video-gemini\local_products\{product_id}\
```

目录里至少要有：

```text
product_profile.yaml
```

然后运行 `start_and_run_all_skill_c.bat`。n8n 返回 submitted 后，查看：

```text
E:\n8n-video-gemini\video_jobs\{job_id}\status.json
E:\n8n-video-gemini\video_jobs\{job_id}\worker.log
E:\n8n-video-gemini\video_output\{product_id}\{job_id}\
```