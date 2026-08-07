# TikTok AI 带货自动化最终工作流

## 1. 目标与边界

目标是运行一套可部署在本地 Windows 主机或云端工作节点的自动化系统：持续发现美国 TikTok Shop 中仍处于增长窗口的 AI 带货内容，并在**手机端一次业务授权**后自动完成产品资料锁定、原创视频生产和待审成片交付。

系统不做品牌建设或原视频搬运；复用的是内容机制、产品呈现方式与节奏，不复制原台词、人物、素材、音乐或完整镜头排列。

人的唯一业务动作：在手机 ChatGPT Remote 中回复 `复刻`、`观察`、`淘汰` 或处理故障。

## 2. 总体状态机

```text
DISCOVERED
  → T0_SNAPSHOTTED
  → T1_CONFIRMED
  → RECONCILED
  → AWAITING_DECISION
  → PRODUCT_LOCKED
  → PRODUCTION_QUEUED
  → GENERATED
  → READY_FOR_REVIEW
  → APPROVED / REJECTED / EXPIRED
```

任何 API 不一致、资料缺失、生成失败或重试耗尽都进入 `ATTENTION_REQUIRED`，不允许猜测后继续。

## 3. 每日 15:05（北京时间）内容雷达

Kalodata 美国日榜按美国时间 T+1 更新，因此每日北京时间 15:05 运行一次完整任务，严格按以下顺序：

1. **复核旧 T0**：只读取上一轮固定 Video ID，不重新按榜单替换对象；
2. **筛选增长**：比较相邻美国数据日 `lastDay` 的播放、销量、收入、GPM 与广告结构；
3. **扫描新榜单**：建立新一轮 T0，供下一日复核；
4. **双源对账**：FastMoss 以精确 Video ID 补齐视频链接、商品链接和商品主图 URL；
5. **事件输出**：产生“待你决策”或“需要你处理”事件，并回传手机端。

不得先创建当天 T0 再复核，否则会造成当天数据自比。

## 4. 发现与入池规则

### 4.1 Kalodata：唯一 AI 视频发现源

使用 `tiktok/video/rank`：

```json
{
  "region": "US",
  "date_range": "lastDay",
  "page_size": 100,
  "is_ai_video": 1
}
```

使用 TikTok Video ID 高 32 位反推发布时间；不使用 `creator_debut`。

| 条件 | 规则 |
|---|---|
| 视频年龄 | 24–48 小时进入 T0；0–24 小时仅孵化观察 |
| AI | `ai_video=1` |
| 挂车 | `product_number>=1` |
| 时长 | `duration<=30 秒` |
| 自然池 | `ad=0` |
| 高效轻广告池 | `ad=1`、`ad_view_ratio<=25`、`ads_roas>=2.6` |

高效轻广告池可作为“投放辅助红利”候选，但必须在通知中与自然池明确区分。

### 4.2 T+1 增长确认

同一 Video ID 在相邻美国数据日按相同 `lastDay` 口径读取：

```text
view_velocity    = T1.views / T0.views
sales_velocity   = T1.sales_volumn / T0.sales_volumn
revenue_velocity = T1.revenue / T0.revenue
```

当前阶段不设置未经验证的固定涨幅阈值。先要求至少一项核心指标增长、其余指标未明显衰减，并积累 14 天样本后按各类目前 20% 自然增长分布校准阈值。

## 5. FastMoss 双源对账

FastMoss 不承担 AI 发现；只通过 `filter.video_id` 精确补齐：

- TikTok 视频链接；
- 商品 ID、商品标题、品类、价格；
- 商品详情链接；
- 商品白底/封面主图 URL。

对账通过的条件：Kalodata 确认 AI 与挂车，FastMoss 精确匹配同一 Video ID 且提供电商商品信息。

数据口径不同，不要求两平台播放、GMV 或销量数值相等。视频 ID、AI 状态、挂商品状态和商品资料完整性才是硬校验项。

## 6. 手机端强提醒与决策

提醒通道：ChatGPT/Codex Remote 手机端；不依赖飞书。

### 待你决策

只在候选已增长确认、双源对账通过时提醒。内容必须含：

- Video ID、视频链接、发布时间、时长；
- 商品 ID、商品标题、商品链接、主图 URL；
- 自然/高效轻广告标签；
- T0/T+1 播放、销量、收入及速度变化；
- 可用指令。

```text
复刻 <video_id>
观察 <video_id>
淘汰 <video_id>
```

### 需要你处理

在以下情况强提醒：

- Kalodata 与 FastMoss 无法按同一 Video ID 对齐；
- 商品链接、SKU 或主图缺失；
- API 调用重试耗尽；
- 商品状态复检失败；
- 视频生成、配音、拼接或审核包生成失败。

内容必须包含任务 ID、失败阶段、重试次数和建议动作。

## 7. “复刻”后的产品锁定

收到复刻授权后，不直接生成视频。先自动建立不可变产品资料包：

```text
product_manifest
├─ source video_id
├─ product_id / SKU / TikTok Shop URL
├─ product title / category / price / commission / availability
├─ product white-background hero image (required)
├─ product detail and lifestyle references (optional by format)
├─ allowed claims
├─ prohibited claims
└─ asset checksums and download timestamp
```

主图、SKU、挂车商品必须一致；缺任一项则转 `ATTENTION_REQUIRED`。生成前重新检查库存、价格、佣金和可挂车状态。

## 8. 内容路由与原创生产

不强制所有内容都使用钩子、口播或 10 秒段落。系统先判断内容类型，选择模板：

| 内容类型 | 关键生产条件 |
|---|---|
| 服装上身/镜子展示 | 上身参考、模特设定、版型/纹理准确性、配乐 |
| 纯产品氛围展示 | 白底主图、细节图、灯光、构图、可商用音乐 |
| 产品演示口播 | 产品动作、卖点白名单、英文口播与字幕 |
| 问题解决/前后对比 | 可验证演示、合规措辞、结果可信度 |
| 剧情/反应型 | 原创角色、场景、节奏、产品自然植入 |

10 秒切片只是视频生成的工程策略：长叙事或连续镜头才使用“上一段末帧作为下一段首帧参考”；单镜头展示片按完整镜头生成，不强制切段。

音频仅使用可商用/平台允许音乐；不得复用源视频音轨。

## 9. 队列、重试与审计

### 任务队列

每个任务以 `video_id + product_id + decision_id` 为唯一键，防止重复生产、重复提醒或挂错商品。

### 重试

| 失败类型 | 自动动作 |
|---|---|
| 临时 API/网络失败 | 指数退避重试 3 次 |
| 双源资料不一致 | 停止并强提醒 |
| 商品资料缺失 | 停止并强提醒 |
| 生成/拼接失败 | 保留中间产物，重试 3 次后强提醒 |
| 合规校验失败 | 不重试，进入人工处理 |

所有状态转换、请求时间、来源快照、素材版本、生成参数和失败信息都写入本地/云端状态库。

## 10. 成片与审核

生产完成后自动生成本地审核包：

- 成片、封面、关键帧；
- 商品资料包和挂车链接；
- 原创机制说明；
- 英文口播、字幕、音乐来源；
- 合规提示与任务追踪 ID。

审核通过后，才进入后续发布接口；当前阶段不自动发布。

## 11. 部署形态

| 模块 | 本地优先方案 | 云端替代方案 |
|---|---|---|
| 定时器/编排 | Codex 自动任务或 n8n 本地 | n8n 云端/VM scheduler |
| 数据与状态 | 本地 JSON → SQLite/Postgres | Postgres + 对象存储 |
| 视频处理 | 本机 FFmpeg/GPU | GPU worker + 对象存储 |
| 手机决策 | ChatGPT/Codex Remote | ChatGPT App/MCP 决策接口 |

当前已验证：Kalodata AI 发现、Video ID 发布时间反推、T+1 时效、FastMoss 精确 Video ID 商品补齐、手机远程连接。

待建设：手机文本指令自动写入任务队列、商品资料自动下载与锁定、视频生成/配音/拼接 worker、审核包与发布模块。
